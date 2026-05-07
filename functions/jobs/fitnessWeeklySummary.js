// functions/jobs/fitnessWeeklySummary.js
//
// Scheduled function: runs every Monday at 06:00 UTC.
// For each user, aggregates the previous week's fitness stats
// and writes/updates the weekly stats doc.
// Idempotent via lastWeeklyRun marker on user profile.

const admin = require("firebase-admin");
const { onSchedule } = require("firebase-functions/v2/scheduler");

const db = admin.firestore();

/**
 * ISO 8601 week number.
 */
function isoWeekNumber(date) {
  const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  return Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
}

exports.scheduledFitnessWeeklySummary = onSchedule(
  {
    schedule: "0 6 * * 1", // Monday 06:00 UTC
    timeZone: "UTC",
    retryCount: 2,
  },
  async () => {
    // Previous week's range: Monday 00:00 to Sunday 23:59:59
    const now = new Date();
    const mondayThisWeek = new Date(now);
    mondayThisWeek.setDate(now.getDate() - now.getDay() + 1);
    mondayThisWeek.setHours(0, 0, 0, 0);

    const mondayLastWeek = new Date(mondayThisWeek);
    mondayLastWeek.setDate(mondayLastWeek.getDate() - 7);

    const sundayLastWeek = new Date(mondayThisWeek);
    sundayLastWeek.setMilliseconds(-1);

    const lastWeekNum = isoWeekNumber(mondayLastWeek);
    const y = mondayLastWeek.getFullYear().toString().padStart(4, "0");
    const weeklyKey = `weekly_${y}-W${lastWeekNum.toString().padStart(2, "0")}`;

    console.log(`[fitnessWeeklySummary] Aggregating ${weeklyKey} (${mondayLastWeek.toISOString()} — ${sundayLastWeek.toISOString()})`);

    // Process all users (paginated).
    let lastDoc = null;
    let totalUsers = 0;

    while (true) {
      let query = db.collection("users").limit(100);
      if (lastDoc) query = query.startAfter(lastDoc);

      const usersSnap = await query.get();
      if (usersSnap.empty) break;

      for (const userDoc of usersSnap.docs) {
        const uid = userDoc.id;

        try {
          // Check idempotency marker.
          const profileRef = userDoc.ref.collection("profile").doc("main");
          const profileSnap = await profileRef.get();
          const lastRun = profileSnap.data()?.lastWeeklyFitnessRun;
          if (lastRun === weeklyKey) continue;

          // Query completed activities for last week.
          const activitiesSnap = await userDoc.ref
            .collection("fitnessActivities")
            .where("status", "==", "completed")
            .where("endedAt", ">=", admin.firestore.Timestamp.fromDate(mondayLastWeek))
            .where("endedAt", "<", admin.firestore.Timestamp.fromDate(mondayThisWeek))
            .get();

          if (activitiesSnap.empty) continue;

          // Aggregate.
          let totalActivities = 0;
          let totalDistance = 0;
          let totalDuration = 0;
          let totalCalories = 0;
          let longestMs = 0;
          const breakdown = {};

          for (const actDoc of activitiesSnap.docs) {
            const a = actDoc.data();
            totalActivities++;
            totalDistance += a.distanceMeters || 0;
            const dMs = (a.durationSeconds || 0) * 1000;
            totalDuration += dMs;
            totalCalories += a.calories || a.caloriesEstimate || 0;
            if (dMs > longestMs) longestMs = dMs;

            const type = a.type || a.activityType || "custom";
            breakdown[type] = (breakdown[type] || 0) + 1;
          }

          // Write weekly stats.
          const statsRef = userDoc.ref.collection("fitnessStats").doc(weeklyKey);
          await statsRef.set({
            periodKey: weeklyKey,
            periodType: "weekly",
            totalActivities,
            totalDistanceMeters: totalDistance,
            totalDurationMs: totalDuration,
            totalCalories,
            activityBreakdown: breakdown,
            longestActivityMs: longestMs,
            averagePaceSecondsPerKm: totalDistance > 0
              ? (totalDuration / 1000) / (totalDistance / 1000)
              : null,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Mark as processed.
          await profileRef.set(
            { lastWeeklyFitnessRun: weeklyKey },
            { merge: true }
          );

          totalUsers++;
        } catch (err) {
          console.error(`[fitnessWeeklySummary] Failed for user ${uid}:`, err);
        }
      }

      lastDoc = usersSnap.docs[usersSnap.docs.length - 1];
    }

    console.log(`[fitnessWeeklySummary] Done — ${totalUsers} users processed for ${weeklyKey}`);
  }
);
