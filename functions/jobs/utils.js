const admin = require("firebase-admin");

/**
 * Emits an event to the /users/{uid}/events collection
 * @param {string} uid User ID
 * @param {string} eventName Event name (e.g., 'day_closed')
 * @param {object} payload Event payload
 * @param {admin.firestore.WriteBatch} [batch] Optional batch
 */
async function emitEvent(uid, eventName, payload, batch = null) {
  const db = admin.firestore();
  const eventRef = db.collection("users").doc(uid).collection("events").doc();
  const docData = {
    id: eventRef.id,
    uid: uid,
    eventName: eventName,
    payload: payload,
    occurredAt: admin.firestore.FieldValue.serverTimestamp(),
    status: "pending", // Emits as pending so client orchestrator or server rules can process it
  };

  if (batch) {
    batch.set(eventRef, docData);
  } else {
    await eventRef.set(docData);
  }
}

/**
 * Evaluates the current local hour for a given user timezone.
 * Returns the hour (0-23) in the user's timezone.
 * Defaults to UTC if timezone is missing/invalid.
 * @param {string} timezone IANA timezone string, e.g., 'America/Los_Angeles'
 * @returns {number}
 */
function getUserLocalHour(timezone) {
  const now = new Date();
  try {
    const formatter = new Intl.DateTimeFormat("en-US", {
      timeZone: timezone || "UTC",
      hour: "numeric",
      hourCycle: "h23", // Returns 0-23
    });
    const parts = formatter.formatToParts(now);
    const hourPart = parts.find((p) => p.type === "hour");
    return parseInt(hourPart.value, 10);
  } catch (e) {
    // Fallback to UTC if timezone is invalid
    return now.getUTCHours();
  }
}

/**
 * Returns a zero-padded YYYY-MM-DD string for yesterday relative to the provided timezone.
 * @param {string} timezone IANA timezone string
 * @returns {string} 'YYYY-MM-DD'
 */
function getYesterdayLocalString(timezone) {
  const now = new Date();
  try {
    const formatter = new Intl.DateTimeFormat("en-CA", {
      timeZone: timezone || "UTC",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    });
    // Format is YYYY-MM-DD (en-CA standard)
    const localTodayString = formatter.format(now);
    
    // Parse it back as a UTC date to easily subtract 1 day
    const localTodayDate = new Date(localTodayString + "T00:00:00Z");
    localTodayDate.setUTCDate(localTodayDate.getUTCDate() - 1);
    return localTodayDate.toISOString().split("T")[0];
  } catch (e) {
    // Fallback
    const utcYesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    return utcYesterday.toISOString().split("T")[0];
  }
}

module.exports = {
  emitEvent,
  getUserLocalHour,
  getYesterdayLocalString,
};
