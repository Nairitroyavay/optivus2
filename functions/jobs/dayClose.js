const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { getUserLocalHour, getYesterdayLocalString, emitEvent } = require("./utils");

/**
 * Parses start and end Date objects for a given YYYY-MM-DD string
 * @param {string} dateStr
 * @returns {{startOfDay: Date, endOfDay: Date}}
 */
function getDayBounds(dateStr) {
  const [year, month, day] = dateStr.split("-").map(Number);
  const startOfDay = new Date(Date.UTC(year, month - 1, day));
  const endOfDay = new Date(Date.UTC(year, month - 1, day + 1));
  return { startOfDay, endOfDay };
}

/**
 * Server-side replica of StreakService._goalMet
 */
function isGoalMet(habit, loggedQuantity) {
  if (habit.kind === "good") {
    const goal = habit.dailyGoal;
    if (goal === null || goal === undefined) return loggedQuantity > 0;
    return loggedQuantity >= goal;
  } else {
    // Bad habit
    const goalType = habit.goalType || "awarenessOnly";
    switch (goalType) {
      case "eliminate":
        return loggedQuantity === 0;
      case "reduceToTarget":
        const target = habit.target;
        if (target === null || target === undefined) return true;
        return loggedQuantity <= target;
      case "awarenessOnly":
        return true;
      default:
        return true;
    }
  }
}

/**
 * Server-side replica of StreakService._computeNextStreak
 */
function computeNextStreak(current, dateStr, hit) {
  const currentCount = current.currentCount || 0;
  const longestCount = current.longestCount || 0;

  if (hit) {
    const newCount = currentCount + 1;
    const newLongest = newCount > longestCount ? newCount : longestCount;
    return {
      ...current,
      currentCount: newCount,
      longestCount: newLongest,
      lastHitDate: dateStr,
      state: "active",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
  } else {
    // Missed
    return {
      ...current,
      currentCount: 0,
      lastBreakDate: dateStr,
      state: "broken",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
  }
}

exports.scheduledDayClose = onSchedule("0 * * * *", async (event) => {
  const db = admin.firestore();
  console.log("[DayClose] Starting hourly job...");

  try {
    const usersSnap = await db
      .collection("users")
      .where("hasCompletedOnboarding", "==", true)
      .get();

    let processedCount = 0;

    for (const userDoc of usersSnap.docs) {
      const userData = userDoc.data();
      const uid = userDoc.id;
      const timezone = userData.timezone;

      const currentHour = getUserLocalHour(timezone);
      // Run day close at 23:00 (11 PM) local time to catch the end of day.
      if (currentHour !== 23) {
        continue;
      }

      const yesterdayStr = getYesterdayLocalString(timezone);

      // Check if already closed
      if (
        userData.lastDayClosed &&
        userData.lastDayClosed.localeCompare(yesterdayStr) >= 0
      ) {
        // Already closed for yesterday or a future date.
        continue;
      }

      console.log(`[DayClose] Closing day ${yesterdayStr} for user ${uid}`);

      // Run Rollup
      const habitsSnap = await db
        .collection("users")
        .doc(uid)
        .collection("habits")
        .where("state", "==", "active")
        .get();

      let habitsCompleted = 0;
      let habitsBadLogged = 0;
      let streaksActive = 0;
      const milestonesHit = [];

      const { startOfDay, endOfDay } = getDayBounds(yesterdayStr);
      const startTs = admin.firestore.Timestamp.fromDate(startOfDay);
      const endTs = admin.firestore.Timestamp.fromDate(endOfDay);

      const batch = db.batch();

      for (const habitDoc of habitsSnap.docs) {
        const habit = habitDoc.data();
        habit.id = habitDoc.id;

        // Fetch logs for this habit
        const logsSnap = await db
          .collection("users")
          .doc(uid)
          .collection("habit_logs")
          .where("habitId", "==", habit.id)
          .where("occurredAt", ">=", startTs)
          .where("occurredAt", "<", endTs)
          .get();

        let loggedQuantity = 0;
        for (const logDoc of logsSnap.docs) {
          const logData = logDoc.data();
          if (habit.kind === "good" && logData.logType === "good") {
            loggedQuantity += logData.quantity !== undefined ? logData.quantity : 1;
          } else if (habit.kind === "bad" && logData.logType === "slip") {
            loggedQuantity += 1;
          }
        }

        const hit = isGoalMet(habit, loggedQuantity);

        // Fetch current streak
        const streakRef = db.collection("users").doc(uid).collection("streaks").doc(habit.id);
        const streakSnap = await streakRef.get();

        let currentStreak = {
          id: habit.id,
          habitId: habit.id,
          currentCount: 0,
          longestCount: 0,
          state: "broken",
        };
        if (streakSnap.exists) {
          currentStreak = { ...currentStreak, ...streakSnap.data() };
        }

        const nextStreak = computeNextStreak(currentStreak, yesterdayStr, hit);
        batch.set(streakRef, nextStreak, { merge: true });

        if (hit) {
          if (habit.kind === "good") habitsCompleted++;
          streaksActive++;
          
          if (nextStreak.currentCount > currentStreak.currentCount) {
             // Emit streak_extended
             const extendedRef = db.collection("users").doc(uid).collection("events").doc();
             batch.set(extendedRef, {
               id: extendedRef.id,
               uid: uid,
               eventName: "streak_extended",
               payload: {
                 habitId: habit.id,
                 currentCount: nextStreak.currentCount,
                 longestCount: nextStreak.longestCount,
                 date: yesterdayStr
               },
               occurredAt: admin.firestore.FieldValue.serverTimestamp(),
               status: "pending"
             });

             const milestones = [7, 14, 21, 30, 60, 90, 180, 365];
             if (milestones.includes(nextStreak.currentCount)) {
               milestonesHit.push(`${habit.id}:${nextStreak.currentCount}`);
               const milestoneRef = db.collection("users").doc(uid).collection("events").doc();
               batch.set(milestoneRef, {
                 id: milestoneRef.id,
                 uid: uid,
                 eventName: "streak_milestone_reached",
                 payload: {
                   habitId: habit.id,
                   milestone: nextStreak.currentCount,
                   date: yesterdayStr
                 },
                 occurredAt: admin.firestore.FieldValue.serverTimestamp(),
                 status: "pending"
               });
             }
          }
        } else if (!hit && currentStreak.state === "active") {
           // Emit streak_broken
           const brokenRef = db.collection("users").doc(uid).collection("events").doc();
           batch.set(brokenRef, {
             id: brokenRef.id,
             uid: uid,
             eventName: "streak_broken",
             payload: {
               habitId: habit.id,
               brokenAt: yesterdayStr,
               previousCount: currentStreak.currentCount
             },
             occurredAt: admin.firestore.FieldValue.serverTimestamp(),
             status: "pending"
           });
        }

        if (habit.kind === "bad" && loggedQuantity > 0) {
          habitsBadLogged += loggedQuantity;
        }
      }

      // Write daily summary
      const summaryRef = db
        .collection("users")
        .doc(uid)
        .collection("dailySummaries")
        .doc(yesterdayStr);
      
      batch.set(summaryRef, {
        date: yesterdayStr,
        habitsCompleted: habitsCompleted,
        habitsBadLogged: habitsBadLogged,
        streaksActive: streaksActive,
        streaksMilestonesHit: milestonesHit,
        computedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update lastDayClosed on user doc
      const userRef = db.collection("users").doc(uid);
      batch.update(userRef, {
        lastDayClosed: yesterdayStr,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Emit day_closed
      const eventRef = db.collection("users").doc(uid).collection("events").doc();
      batch.set(eventRef, {
        id: eventRef.id,
        uid: uid,
        eventName: "day_closed",
        payload: {
          date: yesterdayStr,
          habitsCompleted: habitsCompleted,
          streaksActive: streaksActive,
        },
        occurredAt: admin.firestore.FieldValue.serverTimestamp(),
        status: "pending"
      });

      // Emit routine_day_summarized
      const sumEventRef = db.collection("users").doc(uid).collection("events").doc();
      batch.set(sumEventRef, {
        id: sumEventRef.id,
        uid: uid,
        eventName: "routine_day_summarized",
        payload: {
          date: yesterdayStr,
          habitsCompleted: habitsCompleted,
          streaksActive: streaksActive,
          milestonesHit: milestonesHit
        },
        occurredAt: admin.firestore.FieldValue.serverTimestamp(),
        status: "pending"
      });

      await batch.commit();
      console.log(`[DayClose] Successfully processed user ${uid}`);
      processedCount++;
    }

    console.log(`[DayClose] Job complete. Processed ${processedCount} users.`);
  } catch (error) {
    console.error("[DayClose] Error executing job:", error);
  }
});
