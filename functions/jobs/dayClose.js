const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const {
  clamp,
  emitEvent,
  firestore,
  getEventsForLocalDay,
  getUserLocalHour,
  getYesterdayLocalString,
  HOURLY_JOB_OPTIONS,
  listCompletedUsers,
  makeServerId,
  pruneEventsRecent,
  resolveUserTimeZone,
} = require("./utils");

const MILESTONES = [7, 14, 21, 30, 60, 90, 180, 365];

function eventCount(events, eventName) {
  return events.filter((event) => event.eventName === eventName).length;
}

function buildHabitProgress(events) {
  const progress = new Map();

  for (const event of events) {
    if (
      event.eventName !== "good_habit_logged" &&
      event.eventName !== "bad_habit_slip_logged"
    ) {
      continue;
    }

    const payload = event.payload || {};
    const habitId = payload.habitId || payload.id;
    if (!habitId) continue;

    const current = progress.get(habitId) || {
      habitId,
      habitName: payload.habitName || payload.name || null,
      goodLogs: 0,
      slipLogs: 0,
    };

    if (event.eventName === "good_habit_logged") {
      current.goodLogs += Number(payload.quantity || 1);
    } else {
      current.slipLogs += 1;
    }

    progress.set(habitId, current);
  }

  return [...progress.values()];
}

function deriveUserState({ habitsCompleted, habitsBadLogged, tasksCompleted, tasksAbandoned }) {
  const positives = habitsCompleted + tasksCompleted;
  const negatives = habitsBadLogged + tasksAbandoned;

  if (habitsBadLogged >= 3 && positives === 0) return "relapsing";
  if (negatives > 0 && positives > 0) return "recovering";
  if (negatives > 0) return "slipping";
  return "on_track";
}

function deriveMissionScore({
  habitsCompleted,
  habitsBadLogged,
  tasksCompleted,
  tasksAbandoned,
  streaksActive,
}) {
  return clamp(
    50 +
      tasksCompleted * 10 +
      habitsCompleted * 15 +
      streaksActive * 5 -
      tasksAbandoned * 10 -
      habitsBadLogged * 15,
    0,
    100
  );
}

async function updateStreaksFromProgress(uid, dateStr, habitProgress, batch) {
  const activeHabitIds = new Set();
  const brokenHabitIds = new Set();
  const milestonesHit = [];
  const db = firestore();

  for (const progress of habitProgress) {
    const streakRef = db.collection("users").doc(uid).collection("streaks").doc(progress.habitId);
    const streakSnap = await streakRef.get();
    const current = streakSnap.exists ? streakSnap.data() : {};
    const currentCount = Number(current.currentCount || 0);
    const longestCount = Number(current.longestCount || 0);

    if (progress.goodLogs > 0 && progress.slipLogs === 0) {
      const nextCount = current.lastHitDate === dateStr ? currentCount : currentCount + 1;
      const nextLongest = Math.max(longestCount, nextCount);

      batch.set(
        streakRef,
        {
          id: progress.habitId,
          habitId: progress.habitId,
          habitName: progress.habitName || current.habitName || null,
          currentCount: nextCount,
          longestCount: nextLongest,
          lastHitDate: dateStr,
          state: "active",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          source: "server_scheduled",
          schemaVersion: current.schemaVersion || 1,
        },
        { merge: true }
      );

      activeHabitIds.add(progress.habitId);

      await emitEvent(
        uid,
        "streak_extended",
        {
          habitId: progress.habitId,
          habitName: progress.habitName || current.habitName || null,
          currentCount: nextCount,
          longestCount: nextLongest,
          date: dateStr,
          source: "server_scheduled",
        },
        {
          batch,
          eventId: makeServerId("streak_extended", uid, dateStr, progress.habitId),
        }
      );

      if (MILESTONES.includes(nextCount)) {
        const milestone = `${progress.habitId}:${nextCount}`;
        milestonesHit.push(milestone);
        await emitEvent(
          uid,
          "streak_milestone_reached",
          {
            habitId: progress.habitId,
            habitName: progress.habitName || current.habitName || null,
            milestone: nextCount,
            date: dateStr,
            source: "server_scheduled",
          },
          {
            batch,
            eventId: makeServerId(
              "streak_milestone_reached",
              uid,
              dateStr,
              progress.habitId,
              nextCount
            ),
          }
        );
      }
    } else if (progress.slipLogs > 0 && currentCount > 0) {
      brokenHabitIds.add(progress.habitId);
      batch.set(
        streakRef,
        {
          habitId: progress.habitId,
          currentCount: 0,
          lastBreakDate: dateStr,
          state: "broken",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          source: "server_scheduled",
          schemaVersion: current.schemaVersion || 1,
        },
        { merge: true }
      );

      await emitEvent(
        uid,
        "streak_broken",
        {
          habitId: progress.habitId,
          habitName: progress.habitName || current.habitName || null,
          brokenAt: dateStr,
          previousCount: currentCount,
          source: "server_scheduled",
        },
        {
          batch,
          eventId: makeServerId("streak_broken", uid, dateStr, progress.habitId),
        }
      );
    }
  }

  return { activeHabitIds, brokenHabitIds, milestonesHit };
}

exports.scheduledDayClose = onSchedule(HOURLY_JOB_OPTIONS, async () => {
  const db = firestore();
  console.log("[DayClose] Starting hourly safety-net job.");

  try {
    const usersSnap = await listCompletedUsers();
    let processedCount = 0;
    let errorCount = 0;

    for (const userDoc of usersSnap.docs) {
      const uid = userDoc.id;

      try {
        const timeZone = await resolveUserTimeZone(userDoc);

        if (getUserLocalHour(timeZone) !== 1) {
          continue;
        }

        const dateStr = getYesterdayLocalString(timeZone);
        const prunedRecentCount = await pruneEventsRecent(uid, timeZone);
        const summaryRef = db
          .collection("users")
          .doc(uid)
          .collection("dailySummaries")
          .doc(dateStr);
        const existingSummary = await summaryRef.get();

        if (existingSummary.exists) {
          console.log(
            `[DayClose] Skipping user ${uid}; summary already exists for ${dateStr}. prunedRecent=${prunedRecentCount}.`
          );
          continue;
        }

        const events = await getEventsForLocalDay(uid, dateStr, timeZone);
        const habitProgress = buildHabitProgress(events);
        const tasksCompleted = eventCount(events, "task_completed");
        const tasksAbandoned = eventCount(events, "task_abandoned");
        const habitsCompleted = habitProgress.filter(
          (progress) => progress.goodLogs > 0 && progress.slipLogs === 0
        ).length;
        const habitsBadLogged = habitProgress.reduce(
          (total, progress) => total + progress.slipLogs,
          0
        );
        const existingActiveStreaks = await db
          .collection("users")
          .doc(uid)
          .collection("streaks")
          .where("state", "==", "active")
          .get();
        const activeStreakIds = new Set(existingActiveStreaks.docs.map((doc) => doc.id));

        const batch = db.batch();
        const { activeHabitIds, brokenHabitIds, milestonesHit } = await updateStreaksFromProgress(
          uid,
          dateStr,
          habitProgress,
          batch
        );
        for (const habitId of brokenHabitIds) {
          activeStreakIds.delete(habitId);
        }
        for (const habitId of activeHabitIds) {
          activeStreakIds.add(habitId);
        }
        const streaksActive = activeStreakIds.size;
        const userState = deriveUserState({
          habitsCompleted,
          habitsBadLogged,
          tasksCompleted,
          tasksAbandoned,
        });
        const missionScore = deriveMissionScore({
          habitsCompleted,
          habitsBadLogged,
          tasksCompleted,
          tasksAbandoned,
          streaksActive,
        });

        batch.set(
          summaryRef,
          {
            date: dateStr,
            missionScore,
            habitsCompleted,
            habitsBadLogged,
            tasksCompleted,
            tasksAbandoned,
            routinesCompleted: 0,
            routinesMissed: 0,
            streaksActive,
            streaksMilestonesHit: milestonesHit,
            screenTimeMinutes: 0,
            addictionsLoggedCount: habitsBadLogged,
            stressMarkersCount: 0,
            userState,
            computedAt: admin.firestore.FieldValue.serverTimestamp(),
            source: "server_scheduled",
            schemaVersion: 1,
          },
          { merge: true }
        );

        await emitEvent(
          uid,
          "day_closed",
          {
            date: dateStr,
            tasksCompleted,
            tasksAbandoned,
            habitsCompleted,
            habitsBadLogged,
            streaksActive,
            missionScore,
            userState,
            source: "server_scheduled",
          },
          {
            batch,
            eventId: makeServerId("day_closed", uid, dateStr),
          }
        );

        await emitEvent(
          uid,
          "routine_day_summarized",
          {
            date: dateStr,
            tasksCompleted,
            tasksAbandoned,
            habitsCompleted,
            habitsBadLogged,
            streaksActive,
            milestonesHit,
            missionScore,
            userState,
            source: "server_scheduled",
          },
          {
            batch,
            eventId: makeServerId("routine_day_summarized", uid, dateStr),
          }
        );

        await batch.commit();
        processedCount++;
        console.log(
          `[DayClose] Processed user ${uid} date=${dateStr} events=${events.length} summary=${summaryRef.path} prunedRecent=${prunedRecentCount}.`
        );
      } catch (userError) {
        errorCount++;
        console.error(`[DayClose] Error processing user ${uid}:`, userError);
      }
    }

    console.log(
      `[DayClose] Safety-net job complete. Processed ${processedCount} users. Errors=${errorCount}.`
    );
  } catch (error) {
    console.error("[DayClose] Error executing safety-net job:", error);
  }
});
