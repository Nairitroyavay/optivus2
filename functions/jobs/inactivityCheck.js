const { onSchedule } = require("firebase-functions/v2/scheduler");
const {
  dateStringInTimeZone,
  emitEvent,
  eventExists,
  firestore,
  getEventsForLocalDay,
  getUserLocalHour,
  HOURLY_JOB_OPTIONS,
  listCompletedUsers,
  makeServerId,
  resolveUserTimeZone,
  writeCoachMessage,
} = require("./utils");

function hasClientActivity(events) {
  return events.some((event) => event.source !== "server_scheduled");
}

exports.scheduledInactivityCheck = onSchedule(HOURLY_JOB_OPTIONS, async () => {
  const db = firestore();
  console.log("[InactivityCheck] Starting hourly safety-net job.");

  try {
    const usersSnap = await listCompletedUsers();
    let processedCount = 0;
    let errorCount = 0;

    for (const userDoc of usersSnap.docs) {
      const uid = userDoc.id;

      try {
        const timeZone = await resolveUserTimeZone(userDoc);

        if (getUserLocalHour(timeZone) !== 20) {
          continue;
        }

        const dateStr = dateStringInTimeZone(timeZone);
        const eventId = makeServerId("ghost_day_detected", uid, dateStr);
        if (await eventExists(uid, eventId)) {
          console.log(`[InactivityCheck] Skipping user ${uid}; already emitted for ${dateStr}.`);
          continue;
        }

        const events = await getEventsForLocalDay(uid, dateStr, timeZone);
        if (hasClientActivity(events)) {
          console.log(
            `[InactivityCheck] User ${uid} has ${events.length} event(s) for ${dateStr}; no action.`
          );
          continue;
        }

        const batch = db.batch();
        const messageId = makeServerId("coach_inactivity_check", uid, dateStr);
        await emitEvent(
          uid,
          "ghost_day_detected",
          {
            date: dateStr,
            reason: "No client activity detected by 20:00 local time.",
            source: "server_scheduled",
          },
          { batch, eventId }
        );

        await writeCoachMessage(
          uid,
          "You were quiet today. No penalty. If you come back later, pick one tiny reset: finish one task or log one habit.",
          {
            batch,
            messageId,
            messageType: "inactivity_check",
            priority: "normal",
            triggerEventId: eventId,
            triggerEventName: "ghost_day_detected",
          }
        );

        await emitEvent(
          uid,
          "coach_message_sent",
          {
            messageId,
            messageType: "inactivity_check",
            triggerEventId: eventId,
            triggerEventName: "ghost_day_detected",
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
          `[InactivityCheck] Processed user ${uid} date=${dateStr} events=${events.length} messageId=${messageId}.`
        );
      } catch (userError) {
        errorCount++;
        console.error(`[InactivityCheck] Error processing user ${uid}:`, userError);
      }
    }

    console.log(
      `[InactivityCheck] Safety-net job complete. Processed ${processedCount} users. Errors=${errorCount}.`
    );
  } catch (error) {
    console.error("[InactivityCheck] Error executing safety-net job:", error);
  }
});
