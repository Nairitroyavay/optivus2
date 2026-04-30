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

exports.scheduledMorningBrief = onSchedule(HOURLY_JOB_OPTIONS, async () => {
  const db = firestore();
  console.log("[MorningBrief] Starting hourly safety-net job.");

  try {
    const usersSnap = await listCompletedUsers();
    let processedCount = 0;
    let errorCount = 0;

    for (const userDoc of usersSnap.docs) {
      const uid = userDoc.id;

      try {
        const timeZone = await resolveUserTimeZone(userDoc);

        if (getUserLocalHour(timeZone) !== 8) {
          continue;
        }

        const dateStr = dateStringInTimeZone(timeZone);
        const dayStartedId = makeServerId("day_started", uid, dateStr);
        if (await eventExists(uid, dayStartedId)) {
          console.log(`[MorningBrief] Skipping user ${uid}; day_started exists for ${dateStr}.`);
          continue;
        }

        const batch = db.batch();
        const messageId = makeServerId("coach_morning_brief", uid, dateStr);

        await emitEvent(
          uid,
          "day_started",
          {
            date: dateStr,
            source: "server_scheduled",
          },
          { batch, eventId: dayStartedId }
        );

        await writeCoachMessage(
          uid,
          "Morning brief: choose one task that would make today count, then protect the first focused block.",
          {
            batch,
            messageId,
            messageType: "morning_brief",
            priority: "normal",
            triggerEventId: dayStartedId,
            triggerEventName: "day_started",
          }
        );

        await emitEvent(
          uid,
          "coach_message_sent",
          {
            messageId,
            messageType: "morning_brief",
            triggerEventId: dayStartedId,
            triggerEventName: "day_started",
            source: "server_scheduled",
          },
          {
            batch,
            eventId: makeServerId("coach_message_sent", uid, dateStr, messageId),
          }
        );

        await batch.commit();
        processedCount++;
        console.log(
          `[MorningBrief] Processed user ${uid} date=${dateStr} dayStartedId=${dayStartedId} messageId=${messageId}.`
        );
      } catch (userError) {
        errorCount++;
        console.error(`[MorningBrief] Error processing user ${uid}:`, userError);
      }
    }

    console.log(
      `[MorningBrief] Safety-net job complete. Processed ${processedCount} users. Errors=${errorCount}.`
    );
  } catch (error) {
    console.error("[MorningBrief] Error executing safety-net job:", error);
  }
});
