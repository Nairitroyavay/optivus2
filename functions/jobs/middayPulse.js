const { onSchedule } = require("firebase-functions/v2/scheduler");
const {
  dateStringInTimeZone,
  emitEvent,
  eventExists,
  firestore,
  getUserLocalHour,
  HOURLY_JOB_OPTIONS,
  listCompletedUsers,
  makeServerId,
  resolveUserTimeZone,
  writeCoachMessage,
} = require("./utils");

exports.scheduledMiddayPulse = onSchedule(HOURLY_JOB_OPTIONS, async () => {
  const db = firestore();
  console.log("[MiddayPulse] Starting hourly safety-net job.");

  try {
    const usersSnap = await listCompletedUsers();
    let processedCount = 0;
    let errorCount = 0;

    for (const userDoc of usersSnap.docs) {
      const uid = userDoc.id;

      try {
        const timeZone = await resolveUserTimeZone(userDoc);

        if (getUserLocalHour(timeZone) !== 14) {
          continue;
        }

        const dateStr = dateStringInTimeZone(timeZone);
        const messageId = makeServerId("coach_midday_pulse", uid, dateStr);
        const coachEventId = makeServerId("coach_message_sent", uid, dateStr, messageId);

        if (await eventExists(uid, coachEventId)) {
          console.log(`[MiddayPulse] Skipping user ${uid}; pulse already exists for ${dateStr}.`);
          continue;
        }

        const batch = db.batch();

        await writeCoachMessage(
          uid,
          "Midday pulse: check the next smallest useful action. If the morning drifted, restart with one focused block.",
          {
            batch,
            messageId,
            messageType: "midday_pulse",
            priority: "normal",
          }
        );

        await emitEvent(
          uid,
          "coach_message_sent",
          {
            messageId,
            messageType: "midday_pulse",
            source: "server_scheduled",
          },
          {
            batch,
            eventId: coachEventId,
          }
        );

        await batch.commit();
        processedCount++;
        console.log(`[MiddayPulse] Processed user ${uid} date=${dateStr} messageId=${messageId}.`);
      } catch (userError) {
        errorCount++;
        console.error(`[MiddayPulse] Error processing user ${uid}:`, userError);
      }
    }

    console.log(
      `[MiddayPulse] Safety-net job complete. Processed ${processedCount} users. Errors=${errorCount}.`
    );
  } catch (error) {
    console.error("[MiddayPulse] Error executing safety-net job:", error);
  }
});
