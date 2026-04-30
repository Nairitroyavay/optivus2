const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { getUserLocalHour, emitEvent } = require("./utils");

exports.scheduledMorningBrief = onSchedule("0 * * * *", async (event) => {
  const db = admin.firestore();
  console.log("[MorningBrief] Starting hourly job...");

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
      // Run morning brief at 08:00 (8 AM) local time.
      if (currentHour !== 8) {
        continue;
      }

      console.log(`[MorningBrief] Emitting day_started for user ${uid}`);

      // Emit day_started. The client EventOrchestrator or server-side logic
      // can then handle rule evaluation and generate a morning coach message.
      await emitEvent(uid, "day_started", {
        source: "server_scheduled",
      });

      processedCount++;
    }

    console.log(`[MorningBrief] Job complete. Processed ${processedCount} users.`);
  } catch (error) {
    console.error("[MorningBrief] Error executing job:", error);
  }
});
