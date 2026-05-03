const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
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

const GHOST_THRESHOLDS = Object.freeze([1, 2, 3, 7, 14, 30]);
const GHOST_PAUSE_DAY = 3;

const GHOST_MESSAGES = Object.freeze({
  1: "You were quiet today. No penalty. One tiny action is enough whenever you come back.",
  2: "Two quiet days does not erase your work. When you return, start with one easy win.",
  3: "You have been away for a few days, so your streaks are paused, not broken. Come back gently.",
});

function parseFlexibleDate(value) {
  if (!value) return null;
  if (typeof value.toDate === "function") return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === "string") {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) return parsed;
  }
  return null;
}

function dateStringFromValue(value, timeZone) {
  if (typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return value;
  }
  const parsed = parseFlexibleDate(value);
  if (parsed) return dateStringInTimeZone(timeZone, parsed);
  return null;
}

async function resolveLastSeen(userDoc, timeZone) {
  const data = userDoc.data() || {};
  const rootLastSeen =
    dateStringFromValue(data.lastSeen, timeZone) ||
    dateStringFromValue(data.lastSeenAt, timeZone);
  if (rootLastSeen) {
    return { date: rootLastSeen, source: "users_root" };
  }

  const profileSnap = await userDoc.ref.collection("profile").doc("main").get();
  const profileLastSeen = dateStringFromValue(profileSnap.data()?.lastActiveDate, timeZone);
  if (profileLastSeen) {
    return { date: profileLastSeen, source: "profile_main" };
  }

  return null;
}

function diffDateStrings(laterDateStr, earlierDateStr) {
  const [ly, lm, ld] = laterDateStr.split("-").map(Number);
  const [ey, em, ed] = earlierDateStr.split("-").map(Number);
  const later = Date.UTC(ly, lm - 1, ld);
  const earlier = Date.UTC(ey, em - 1, ed);
  return Math.max(0, Math.floor((later - earlier) / 86400000));
}

async function pauseActiveStreaks(uid, missedDays, batch) {
  const db = firestore();
  const snap = await db
    .collection("users")
    .doc(uid)
    .collection("streaks")
    .where("state", "==", "active")
    .get();

  let pausedCount = 0;
  const nowTs = admin.firestore.Timestamp.now();
  for (const doc of snap.docs) {
    const streak = doc.data() || {};
    const currentCount = Number(streak.currentCount || 0);
    batch.update(doc.ref, {
      state: "paused",
      pausedAt: nowTs,
      prePauseCount: currentCount,
      pauseReason: "ghost",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await emitEvent(
      uid,
      "streak_paused",
      {
        habitId: streak.habitId || doc.id,
        scope: streak.scope || "habit",
        reason: "ghost",
        gapDays: missedDays,
        prePauseCount: currentCount,
        currentCount,
        longestCount: Number(streak.longestCount || currentCount),
      },
      {
        batch,
        eventId: makeServerId("streak_paused", uid, doc.id, missedDays),
      }
    );
    pausedCount++;
  }
  return pausedCount;
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
        const lastSeen = await resolveLastSeen(userDoc, timeZone);
        if (!lastSeen) {
          console.log(`[InactivityCheck] Skipping user ${uid}; no last-seen field.`);
          continue;
        }

        const missedDays = diffDateStrings(dateStr, lastSeen.date);
        if (!GHOST_THRESHOLDS.includes(missedDays)) {
          continue;
        }

        const eventId = makeServerId("ghost_day_detected", uid, missedDays, dateStr);
        if (await eventExists(uid, eventId)) {
          console.log(
            `[InactivityCheck] Skipping user ${uid}; already emitted threshold ${missedDays} for ${dateStr}.`
          );
          continue;
        }

        const batch = db.batch();
        const threshold = missedDays;
        let pausedCount = 0;
        if (missedDays >= GHOST_PAUSE_DAY) {
          pausedCount = await pauseActiveStreaks(uid, missedDays, batch);
        }

        batch.set(
          userDoc.ref.collection("dailySummaries").doc(dateStr),
          {
            date: dateStr,
            ghost: {
              missedDays,
              threshold,
              lastSeenDate: lastSeen.date,
              source: lastSeen.source,
              detectedAt: admin.firestore.FieldValue.serverTimestamp(),
              streaksPaused: pausedCount,
            },
            ghostMissedDays: missedDays,
            ghostThreshold: threshold,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            schemaVersion: 1,
          },
          { merge: true }
        );

        await emitEvent(
          uid,
          "ghost_day_detected",
          {
            uid,
            missedDays,
            threshold,
            date: dateStr,
            lastSeenDate: lastSeen.date,
            lastSeenSource: lastSeen.source,
            source: "server_scheduled",
          },
          { batch, eventId }
        );

        const coachCopy = GHOST_MESSAGES[missedDays];
        let messageId = null;
        if (coachCopy) {
          messageId = makeServerId("coach_inactivity_check", uid, missedDays, dateStr);
          await writeCoachMessage(
            uid,
            coachCopy,
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
        }

        await batch.commit();
        processedCount++;
        console.log(
          `[InactivityCheck] Processed user ${uid} date=${dateStr} missedDays=${missedDays} paused=${pausedCount} messageId=${messageId}.`
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
