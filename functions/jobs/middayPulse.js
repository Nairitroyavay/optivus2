const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { getUserLocalHour, emitEvent } = require("./utils");

exports.scheduledMiddayPulse = onSchedule("0 * * * *", async (event) => {
  const db = admin.firestore();
  console.log("[MiddayPulse] Starting hourly job...");

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
      // Run midday pulse at 14:00 (2 PM) local time.
      if (currentHour !== 14) {
        continue;
      }

      console.log(`[MiddayPulse] Emitting midday_pulse for user ${uid}`);

      // Emit midday_pulse event.
      await emitEvent(uid, "midday_pulse", {
        source: "server_scheduled",
      });

      processedCount++;
    }

    console.log(`[MiddayPulse] Job complete. Processed ${processedCount} users.`);
  } catch (error) {
    console.error("[MiddayPulse] Error executing job:", error);
  }
});
