const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const {
  addDaysToDateString,
  clamp,
  emitEvent,
  firestore,
  getEventsForLocalDay,
  getLocalDayBounds,
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
  identityAlignedCompletedValue,
  nonAlignedCompletedValue,
  maxPossibleValueToday,
}) {
  if (!maxPossibleValueToday) return 0;
  return Math.round(
    clamp(
      ((identityAlignedCompletedValue + nonAlignedCompletedValue) /
        maxPossibleValueToday) *
        100,
      0,
      100
    )
  );
}

function taskState(task) {
  return task.state || task.status || "scheduled";
}

function plannedDurationMin(task) {
  const start = task.plannedStart && task.plannedStart.toDate();
  const end = task.plannedEnd && task.plannedEnd.toDate();
  if (!start || !end) return 0;
  return Math.max(0, Math.round((end.getTime() - start.getTime()) / 60000));
}

function routineKey(task) {
  return task.sourceRoutineType || task.type || task.parentRoutine || "custom";
}

function isValidReasonSkip(task) {
  const tag = String(task.reasonTag || "").toLowerCase();
  return taskState(task) === "skipped" && ["valid_reason", "day_off", "illness"].includes(tag);
}

function routineContribution(task, now = new Date()) {
  const state = taskState(task);
  if (isValidReasonSkip(task)) return null;
  if (state === "completed") return 1;
  if (state === "started" || state === "paused") {
    const start =
      (task.actualStart || task.plannedStart) &&
      (task.actualStart || task.plannedStart).toDate();
    const pausedAt = task.pausedAt && task.pausedAt.toDate();
    const end = state === "paused" && pausedAt ? pausedAt : now;
    const planned = plannedDurationMin(task);
    if (!start || planned <= 0) return 0;
    return clamp((end.getTime() - start.getTime()) / 60000 / planned, 0, 0.95);
  }
  return 0;
}

async function getTasksForLocalDay(uid, dateStr, timeZone) {
  const { start, end } = getLocalDayBounds(dateStr, timeZone);
  const snap = await firestore()
    .collection("users")
    .doc(uid)
    .collection("tasks")
    .where("plannedStart", ">=", admin.firestore.Timestamp.fromDate(start))
    .where("plannedStart", "<", admin.firestore.Timestamp.fromDate(end))
    .get();
  return snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
}

function identitySetFromProfile(profile = {}) {
  return new Set(
    (profile.identities || [])
      .map((identity) => String(identity).trim().toLowerCase())
      .filter(Boolean)
  );
}

function computeTaskMetrics(tasks, identities) {
  let tasksCompleted = 0;
  let tasksAbandoned = 0;
  let tasksSkipped = 0;
  let focusMinutes = 0;
  let identityAlignedCompletedValue = 0;
  let nonAlignedCompletedValue = 0;
  let maxPossibleValueToday = 0;
  const perRoutineContribs = {};

  for (const task of tasks) {
    const state = taskState(task);
    if (state === "completed") tasksCompleted++;
    if (state === "abandoned") tasksAbandoned++;
    if (state === "skipped") tasksSkipped++;
    focusMinutes += Number(task.actualDurationMin || 0);

    const contribution = routineContribution(task);
    if (contribution !== null) {
      const key = routineKey(task);
      perRoutineContribs[key] = perRoutineContribs[key] || [];
      perRoutineContribs[key].push(contribution);
    }

    if (isValidReasonSkip(task)) continue;
    const aligned = (task.identityTags || [])
      .map((tag) => String(tag).trim().toLowerCase())
      .some((tag) => identities.has(tag));
    const weight = aligned ? 1 : 0.5;
    maxPossibleValueToday += weight;
    if (state === "completed") {
      if (aligned) identityAlignedCompletedValue += weight;
      else nonAlignedCompletedValue += weight;
    }
  }

  const perRoutinePct = {};
  for (const [key, values] of Object.entries(perRoutineContribs)) {
    perRoutinePct[key] = values.length
      ? values.reduce((sum, value) => sum + value, 0) / values.length
      : 0;
  }
  const routineValues = Object.values(perRoutinePct);
  const overallPct = routineValues.length
    ? routineValues.reduce((sum, value) => sum + value, 0) / routineValues.length
    : 0;

  return {
    tasksCompleted,
    tasksAbandoned,
    tasksSkipped,
    tasksScheduled: tasks.length,
    focusMinutes,
    identityAlignedCompletedValue,
    nonAlignedCompletedValue,
    maxPossibleValueToday,
    perRoutinePct,
    overallPct,
    routinesCompleted: routineValues.filter((value) => value >= 0.999).length,
    routinesMissed: routineValues.filter((value) => value <= 0).length,
  };
}

function markOverdueTasks(uid, tasks, batch) {
  const now = new Date();
  const nowTs = admin.firestore.Timestamp.fromDate(now);
  for (const task of tasks) {
    const state = taskState(task);
    if (["completed", "abandoned", "skipped"].includes(state)) continue;

    const taskRef = firestore().collection("users").doc(uid).collection("tasks").doc(task.id);
    const outcomeRef = firestore()
      .collection("users")
      .doc(uid)
      .collection("task_outcomes")
      .doc(task.id);
    const planned = plannedDurationMin(task);

    if (state === "scheduled") {
      task.state = "skipped";
      task.status = "skipped";
      task.actualDurationMin = 0;
      task.reasonCategory = "auto_no_start";
      task.reasonTag = "day_close";
      batch.set(
        taskRef,
        {
          state: "skipped",
          status: "skipped",
          skippedAt: nowTs,
          actualDurationMin: 0,
          driftPct: planned > 0 ? -100 : 0,
          reasonCategory: "auto_no_start",
          reasonTag: "day_close",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      batch.set(
        outcomeRef,
        {
          taskId: task.id,
          outcome: "skipped",
          plannedStart: task.plannedStart || null,
          plannedEnd: task.plannedEnd || null,
          plannedDurationMin: planned,
          actualEnd: nowTs,
          actualDurationMin: 0,
          durationDriftPct: planned > 0 ? -100 : 0,
          reasonCategory: "auto_no_start",
          reasonTag: "day_close",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    } else {
      const actualStart = task.actualStart && task.actualStart.toDate();
      const actualDurationMin = actualStart
        ? Math.max(0, Math.round((now.getTime() - actualStart.getTime()) / 60000))
        : 0;
      const driftPct = planned > 0 ? Number((((actualDurationMin - planned) / planned) * 100).toFixed(1)) : 0;
      task.state = "abandoned";
      task.status = "abandoned";
      task.actualDurationMin = actualDurationMin;
      task.reasonCategory = "auto_idle";
      task.reasonTag = "day_close";
      batch.set(
        taskRef,
        {
          state: "abandoned",
          status: "abandoned",
          abandonedAt: nowTs,
          actualDurationMin,
          driftPct,
          reasonCategory: "auto_idle",
          reasonTag: "day_close",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      batch.set(
        outcomeRef,
        {
          taskId: task.id,
          outcome: "abandoned",
          plannedStart: task.plannedStart || null,
          plannedEnd: task.plannedEnd || null,
          plannedDurationMin: planned,
          ...(task.actualStart ? { actualStart: task.actualStart } : {}),
          actualEnd: nowTs,
          actualDurationMin,
          durationDriftPct: driftPct,
          reasonCategory: "auto_idle",
          reasonTag: "day_close",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }
  }
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

        const prunedRecentCount = await pruneEventsRecent(uid, timeZone);
        const yesterday = getYesterdayLocalString(timeZone);
        let dateStr = userDoc.data().lastDayClosed
          ? addDaysToDateString(userDoc.data().lastDayClosed, 1)
          : yesterday;

        while (dateStr <= yesterday) {
          const summaryRef = db
            .collection("users")
            .doc(uid)
            .collection("dailySummaries")
            .doc(dateStr);
          const existingSummary = await summaryRef.get();

          if (existingSummary.exists) {
            await userDoc.ref.set(
              {
                lastDayClosed: dateStr,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true }
            );
            dateStr = addDaysToDateString(dateStr, 1);
            continue;
          }

          const events = await getEventsForLocalDay(uid, dateStr, timeZone);
          const habitProgress = buildHabitProgress(events);
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

          const tasks = await getTasksForLocalDay(uid, dateStr, timeZone);
          const identitySnap = await db
            .collection("users")
            .doc(uid)
            .collection("identity_profile")
            .doc("main")
            .get();
          const identityProfile = identitySnap.exists ? identitySnap.data() : {};
          const identities = identitySetFromProfile(identityProfile);
          const batch = db.batch();

          markOverdueTasks(uid, tasks, batch);
          const { activeHabitIds, brokenHabitIds, milestonesHit } =
            await updateStreaksFromProgress(uid, dateStr, habitProgress, batch);
          for (const habitId of brokenHabitIds) activeStreakIds.delete(habitId);
          for (const habitId of activeHabitIds) activeStreakIds.add(habitId);
          const streaksActive = activeStreakIds.size;
          const taskMetrics = computeTaskMetrics(tasks, identities);
          const missionScore = deriveMissionScore(taskMetrics);
          const userState = deriveUserState({
            habitsCompleted,
            habitsBadLogged,
            tasksCompleted: taskMetrics.tasksCompleted,
            tasksAbandoned: taskMetrics.tasksAbandoned,
          });
          const identityProgress = {};
          for (const identity of identityProfile.identities || []) {
            identityProgress[String(identity)] = Number(identityProfile.progressPct || 0);
          }

          batch.set(
            summaryRef,
            {
              date: dateStr,
              missionScore,
              missionPct: missionScore / 100,
              overallPct: taskMetrics.overallPct,
              perRoutinePct: taskMetrics.perRoutinePct,
              slipCounts: Object.fromEntries(habitProgress.map((p) => [p.habitId, p.slipLogs])),
              identityProgress,
              identityAlignedCompletedValue: taskMetrics.identityAlignedCompletedValue,
              nonAlignedCompletedValue: taskMetrics.nonAlignedCompletedValue,
              maxPossibleValueToday: taskMetrics.maxPossibleValueToday,
              habitsCompleted,
              habitsBadLogged,
              tasksCompleted: taskMetrics.tasksCompleted,
              tasksAbandoned: taskMetrics.tasksAbandoned,
              tasksSkipped: taskMetrics.tasksSkipped,
              tasksScheduled: taskMetrics.tasksScheduled,
              focusMinutes: taskMetrics.focusMinutes,
              routinesCompleted: taskMetrics.routinesCompleted,
              routinesMissed: taskMetrics.routinesMissed,
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

          for (const task of tasks) {
            if (taskState(task) !== "completed" || !task.parentRoutine) continue;
            await emitEvent(
              uid,
              "routine_block_completed",
              {
                taskId: task.id,
                routineType: routineKey(task),
                routineId: task.parentRoutine,
                date: dateStr,
                source: "server_scheduled",
              },
              {
                batch,
                eventId: makeServerId("routine_block_completed", uid, dateStr, task.id),
              }
            );
          }

          await emitEvent(
            uid,
            "routine_day_summarized",
            {
              date: dateStr,
              tasksCompleted: taskMetrics.tasksCompleted,
              tasksAbandoned: taskMetrics.tasksAbandoned,
              habitsCompleted,
              habitsBadLogged,
              streaksActive,
              milestonesHit,
              missionScore,
              overallPct: taskMetrics.overallPct,
              perRoutinePct: taskMetrics.perRoutinePct,
              source: "server_scheduled",
            },
            { batch, eventId: makeServerId("routine_day_summarized", uid, dateStr) }
          );

          await emitEvent(
            uid,
            "day_closed",
            {
              date: dateStr,
              tasksCompleted: taskMetrics.tasksCompleted,
              tasksAbandoned: taskMetrics.tasksAbandoned,
              habitsCompleted,
              habitsBadLogged,
              streaksActive,
              missionScore,
              userState,
              source: "server_scheduled",
            },
            { batch, eventId: makeServerId("day_closed", uid, dateStr) }
          );

          batch.set(
            userDoc.ref,
            {
              lastDayClosed: dateStr,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );

          await batch.commit();
          processedCount++;
          console.log(
            `[DayClose] Processed user ${uid} date=${dateStr} events=${events.length} summary=${summaryRef.path} prunedRecent=${prunedRecentCount}.`
          );
          dateStr = addDaysToDateString(dateStr, 1);
        }
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
