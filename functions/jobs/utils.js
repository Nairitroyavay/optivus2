const crypto = require("crypto");
const admin = require("firebase-admin");

const SERVER_SOURCE = "server_scheduled";
const DEFAULT_TIMEZONE = "UTC";
const EVENTS_RECENT_RETENTION_DAYS = 14;
const HOURLY_JOB_OPTIONS = Object.freeze({
  schedule: "0 * * * *",
  timeZone: "UTC",
  timeoutSeconds: 540,
  memory: "512MiB",
});

function firestore() {
  return admin.firestore();
}

function normalizeTimeZone(candidate) {
  if (!candidate || typeof candidate !== "string") {
    return null;
  }

  try {
    new Intl.DateTimeFormat("en-US", { timeZone: candidate }).format(new Date());
    return candidate;
  } catch (error) {
    return null;
  }
}

function extractTimeZone(userData = {}) {
  const candidate =
    userData.timezone ||
    userData.timeZone ||
    (userData.profile && (userData.profile.timezone || userData.profile.timeZone));

  return normalizeTimeZone(candidate);
}

function safeTimeZone(userData = {}) {
  return extractTimeZone(userData) || DEFAULT_TIMEZONE;
}

async function resolveUserTimeZone(userDoc) {
  const rootTimeZone = extractTimeZone(userDoc.data());
  if (rootTimeZone) {
    return rootTimeZone;
  }

  const profileSnap = await userDoc.ref.collection("profile").doc("main").get();
  if (!profileSnap.exists) {
    return DEFAULT_TIMEZONE;
  }

  return safeTimeZone(profileSnap.data());
}

function zonedParts(date, timeZone) {
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: safeTimeZone({ timezone: timeZone }),
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
  });

  const parts = {};
  for (const part of formatter.formatToParts(date)) {
    if (part.type !== "literal") {
      parts[part.type] = parseInt(part.value, 10);
    }
  }
  return parts;
}

function pad2(value) {
  return String(value).padStart(2, "0");
}

function dateStringInTimeZone(timeZone, date = new Date()) {
  const parts = zonedParts(date, timeZone);
  return `${parts.year}-${pad2(parts.month)}-${pad2(parts.day)}`;
}

function addDaysToDateString(dateStr, days) {
  const [year, month, day] = dateStr.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day + days));
  return date.toISOString().slice(0, 10);
}

function zonedTimeToUtc(dateStr, hour, minute, second, timeZone) {
  const [year, month, day] = dateStr.split("-").map(Number);
  const targetMs = Date.UTC(year, month - 1, day, hour, minute, second);
  let utcMs = targetMs;

  for (let i = 0; i < 3; i++) {
    const parts = zonedParts(new Date(utcMs), timeZone);
    const zonedAsUtcMs = Date.UTC(
      parts.year,
      parts.month - 1,
      parts.day,
      parts.hour,
      parts.minute,
      parts.second
    );
    utcMs -= zonedAsUtcMs - targetMs;
  }

  return new Date(utcMs);
}

function getLocalDayBounds(dateStr, timeZone) {
  const start = zonedTimeToUtc(dateStr, 0, 0, 0, timeZone);
  const end = zonedTimeToUtc(addDaysToDateString(dateStr, 1), 0, 0, 0, timeZone);
  return { start, end };
}

function getUserLocalHour(timeZone, date = new Date()) {
  return zonedParts(date, timeZone).hour;
}

function getYesterdayLocalString(timeZone, date = new Date()) {
  return addDaysToDateString(dateStringInTimeZone(timeZone, date), -1);
}

function makeServerId(kind, ...parts) {
  const label = String(kind)
    .replace(/[^A-Za-z0-9_]/g, "_")
    .replace(/_+/g, "_")
    .slice(0, 72);
  const hash = crypto
    .createHash("sha256")
    .update(parts.map((part) => JSON.stringify(part)).join("|"))
    .digest("hex")
    .slice(0, 20);
  return `server_${label}_${hash}`;
}

async function listCompletedUsers() {
  return firestore()
    .collection("users")
    .where("hasCompletedOnboarding", "==", true)
    .get();
}

function eventDoc(uid, eventId) {
  return firestore().collection("users").doc(uid).collection("events").doc(eventId);
}

function recentEventDoc(uid, eventId) {
  return firestore()
    .collection("users")
    .doc(uid)
    .collection("events_recent")
    .doc(eventId);
}

function buildEventData({
  eventId,
  eventName,
  payload,
  source = SERVER_SOURCE,
  priority = "normal",
  timestamp = new Date(),
}) {
  const ts = admin.firestore.Timestamp.fromDate(timestamp);
  return {
    eventId,
    eventName,
    ts,
    deviceLocalTs: ts,
    deviceId: "server",
    source,
    priority,
    payloadVersion: 1,
    payload: payload || {},
    schemaVersion: 1,
  };
}

async function emitEvent(uid, eventName, payload = {}, options = {}) {
  const eventId =
    options.eventId || makeServerId(eventName, uid, payload, options.timestamp || new Date());
  const data = buildEventData({
    eventId,
    eventName,
    payload,
    source: options.source || SERVER_SOURCE,
    priority: options.priority || "normal",
    timestamp: options.timestamp || new Date(),
  });

  const batch = options.batch || firestore().batch();
  batch.set(eventDoc(uid, eventId), data, { merge: true });
  batch.set(recentEventDoc(uid, eventId), data, { merge: true });

  if (!options.batch) {
    await batch.commit();
  }

  return eventId;
}

async function eventExists(uid, eventId) {
  const snap = await eventDoc(uid, eventId).get();
  return snap.exists;
}

async function getEventsForLocalDay(uid, dateStr, timeZone) {
  const { start, end } = getLocalDayBounds(dateStr, timeZone);
  const snap = await firestore()
    .collection("users")
    .doc(uid)
    .collection("events_recent")
    .where("ts", ">=", admin.firestore.Timestamp.fromDate(start))
    .where("ts", "<", admin.firestore.Timestamp.fromDate(end))
    .get();

  return snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
}

async function hasEventNameForLocalDay(uid, eventName, dateStr, timeZone) {
  const events = await getEventsForLocalDay(uid, dateStr, timeZone);
  return events.some((event) => event.eventName === eventName);
}

async function pruneEventsRecent(uid, timeZone, keepDays = EVENTS_RECENT_RETENTION_DAYS) {
  const cutoffDateStr = addDaysToDateString(dateStringInTimeZone(timeZone), -keepDays);
  const { start } = getLocalDayBounds(cutoffDateStr, timeZone);
  const cutoffTs = admin.firestore.Timestamp.fromDate(start);
  const eventsRecentRef = firestore()
    .collection("users")
    .doc(uid)
    .collection("events_recent");
  let deletedCount = 0;

  while (true) {
    const oldEvents = await eventsRecentRef.where("ts", "<", cutoffTs).limit(450).get();
    if (oldEvents.empty) {
      return deletedCount;
    }

    const batch = firestore().batch();
    for (const doc of oldEvents.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
    deletedCount += oldEvents.size;
  }
}

function writeCoachMessage(uid, message, options = {}) {
  const messageId =
    options.messageId || makeServerId("coach_message", uid, message, options.messageType);
  const timestamp = admin.firestore.Timestamp.fromDate(options.timestamp || new Date());
  const data = {
    messageId,
    userId: uid,
    role: "coach",
    message,
    body: message,
    text: message,
    messageType: options.messageType || "check_in",
    priority: options.priority || "normal",
    ruleId: options.ruleId || null,
    ruleIntent: options.ruleIntent || null,
    source: options.source || SERVER_SOURCE,
    deliveryType: options.deliveryType || "server_safety_net",
    triggerEventId: options.triggerEventId || null,
    triggerEventName: options.triggerEventName || null,
    timestamp,
    createdAt: timestamp,
    aiGenerated: false,
    schemaVersion: 1,
  };

  const ref = firestore()
    .collection("users")
    .doc(uid)
    .collection("coach_messages")
    .doc(messageId);

  if (options.batch) {
    options.batch.set(ref, data, { merge: true });
  } else {
    return ref.set(data, { merge: true });
  }

  return Promise.resolve(messageId);
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

module.exports = {
  EVENTS_RECENT_RETENTION_DAYS,
  HOURLY_JOB_OPTIONS,
  SERVER_SOURCE,
  addDaysToDateString,
  clamp,
  dateStringInTimeZone,
  emitEvent,
  eventExists,
  firestore,
  getEventsForLocalDay,
  getLocalDayBounds,
  getUserLocalHour,
  getYesterdayLocalString,
  hasEventNameForLocalDay,
  listCompletedUsers,
  makeServerId,
  pruneEventsRecent,
  resolveUserTimeZone,
  safeTimeZone,
  writeCoachMessage,
};
