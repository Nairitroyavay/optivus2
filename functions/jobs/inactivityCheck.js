const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { getUserLocalHour, emitEvent } = require("./utils");

exports.scheduledInactivityCheck = onSchedule("0 * * * *", async (event) => {
  const db = admin.firestore();
  console.log("[InactivityCheck] Starting hourly job...");

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
      // Run inactivity check at 20:00 (8 PM) local time.
      if (currentHour !== 20) {
        continue;
      }

      console.log(`[InactivityCheck] Checking user ${uid}`);

      // Check if there's any recent activity in the last 24 hours.
      // We look at events_recent (which only holds the last 48h based on client TTL).
      // If we find no 'day_started' or 'task_completed' or similar events today, we can emit ghost_day_detected.
      
      const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000);
      const yesterdayTs = admin.firestore.Timestamp.fromDate(yesterday);

      const recentEventsSnap = await db
        .collection("users")
        .doc(uid)
        .collection("events_recent")
        .where("occurredAt", ">=", yesterdayTs)
        .limit(1)
        .get();

      if (recentEventsSnap.empty) {
        console.log(`[InactivityCheck] User ${uid} is inactive. Emitting ghost_day_detected.`);
        await emitEvent(uid, "ghost_day_detected", {
          reason: "No events in the last 24 hours.",
        });
      }

      processedCount++;
    }

    console.log(`[InactivityCheck] Job complete. Processed ${processedCount} users.`);
  } catch (error) {
    console.error("[InactivityCheck] Error executing job:", error);
  }
});
