"use strict";

const crypto = require("crypto");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const admin = require("firebase-admin");

const geminiApiKey = defineSecret("GEMINI_API_KEY");

const MODEL_NAME = "gemini-1.5-flash";
const MAX_TEXT_LENGTH = 2000;
const MAX_REPLY_LENGTH = 1600;
const MAX_ACTIONS = 5;

const CRISIS_PATTERNS = [
  /\b(kill myself|suicide|suicidal|end my life|want to die)\b/i,
  /\b(self[-\s]?harm|hurt myself|harm myself)\b/i,
  /\b(can't go on|cannot go on|no reason to live)\b/i,
];

const CRISIS_REPLY =
  "I'm really sorry you're feeling this much pain. I can't help with anything that could put you in danger, but you do not have to handle this alone. If you might act on this, call emergency services now. In the U.S. or Canada, call or text 988 for immediate crisis support. If you can, move near another person and tell them plainly: \"I might not be safe right now.\"";

function makeId(prefix) {
  return `${prefix}_${Date.now()}_${crypto.randomBytes(6).toString("hex")}`;
}

function timestampFromDate(date) {
  return admin.firestore.Timestamp.fromDate(date);
}

function validateInput(data, authUid) {
  const userId = typeof data.userId === "string" ? data.userId.trim() : "";
  const threadId = typeof data.threadId === "string" ? data.threadId.trim() : "";
  const text = typeof data.text === "string" ? data.text.trim() : "";
  const mode = typeof data.mode === "string" ? data.mode.trim() : "";

  if (!userId || !threadId || !text || !mode) {
    throw new HttpsError(
      "invalid-argument",
      "Expected {userId, threadId, text, mode} with non-empty string values."
    );
  }

  if (userId !== authUid) {
    throw new HttpsError("permission-denied", "userId must match the authenticated user.");
  }

  if (text.length > MAX_TEXT_LENGTH) {
    throw new HttpsError("invalid-argument", `text must be ${MAX_TEXT_LENGTH} characters or fewer.`);
  }

  return { userId, threadId, text, mode };
}

function safetyBranchForText(text) {
  if (CRISIS_PATTERNS.some((pattern) => pattern.test(text))) {
    return "crisis";
  }
  return "normal";
}

function stripJsonFences(raw) {
  const text = String(raw || "").trim();
  const fenced = text.match(/^```(?:json)?\s*([\s\S]*?)\s*```$/i);
  return fenced ? fenced[1].trim() : text;
}

function validateCoachReplyJson(raw) {
  let parsed;
  try {
    parsed = JSON.parse(stripJsonFences(raw));
  } catch (error) {
    throw new HttpsError("internal", "Coach model returned invalid JSON.");
  }

  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new HttpsError("internal", "Coach model returned the wrong JSON shape.");
  }

  const text = typeof parsed.text === "string" ? parsed.text.trim() : "";
  if (!text || text.length > MAX_REPLY_LENGTH) {
    throw new HttpsError("internal", "Coach model returned an invalid text field.");
  }

  if (!Array.isArray(parsed.suggestedActions)) {
    throw new HttpsError("internal", "Coach model returned an invalid suggestedActions field.");
  }

  const suggestedActions = parsed.suggestedActions
    .map((action) => (typeof action === "string" ? action.trim() : ""))
    .filter(Boolean)
    .slice(0, MAX_ACTIONS);

  return { text, suggestedActions };
}

function summarizeSnapshot(snapshot) {
  const goals = Array.isArray(snapshot.goals)
    ? snapshot.goals.join(", ")
    : snapshot.goals || snapshot.goalSummary || "No goals found in snapshot.";

  return {
    goals,
    userState: snapshot.userState || "on_track",
    missionScore: snapshot.missionScore ?? 0,
    tasksCompletedToday: snapshot.tasksCompletedToday ?? 0,
    tasksAbandonedToday: snapshot.tasksAbandonedToday ?? 0,
    goodHabitsLoggedToday: snapshot.goodHabitsLoggedToday ?? 0,
    badHabitSlipsToday: snapshot.badHabitSlipsToday ?? 0,
    longestActiveStreak: snapshot.longestActiveStreak ?? 0,
    activeStreakCount: snapshot.activeStreakCount ?? 0,
    daysSinceLastActive: snapshot.daysSinceLastActive ?? 0,
    quietDayMode: snapshot.quietDayMode === true,
  };
}

function normalizeTextList(value) {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((item) => String(item || "").trim())
    .filter(Boolean);
}

function uniqueTexts(values) {
  const seen = new Set();
  const result = [];

  for (const value of values) {
    const key = value.toLowerCase();
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);
    result.push(value);
  }

  return result;
}

function hasGoalContext(snapshot = {}) {
  if (Array.isArray(snapshot.goals)) {
    return snapshot.goals.some((goal) => String(goal || "").trim().length > 0);
  }

  return typeof snapshot.goals === "string" && snapshot.goals.trim().length > 0;
}

function buildSystemPrompt({ snapshot, recentMessages, mode }) {
  const context = summarizeSnapshot(snapshot);
  const history = recentMessages
    .map((message) => `${message.role || "unknown"}: ${message.text || message.message || ""}`)
    .filter((line) => line.trim().length > 0)
    .slice(-12)
    .join("\n");

  return `You are the user's personal Optivus AI life coach.
Mode: ${mode}

Use the context snapshot as the source of truth. If goals are missing, do not invent goals.
Keep the reply concise, specific, and suitable for a chat bubble.
Never provide medical, legal, financial, or crisis instructions. Crisis text was already routed before this model call.

Context snapshot:
${JSON.stringify(context)}

Recent conversation:
${history || "No recent conversation loaded."}

Return only valid JSON with this exact shape:
{"text":"1-3 short paragraphs of coach reply text","suggestedActions":["optional short action label"]}`;
}

async function loadFallbackContextSnapshot(db, uid) {
  const userRef = db.collection("users").doc(uid);
  const [userSnap, goalsSnap] = await Promise.all([
    userRef.get(),
    userRef.collection("goals").get(),
  ]);
  const root = userSnap.exists ? userSnap.data() || {} : {};
  const onboarding = root.onboarding && typeof root.onboarding === "object"
    ? root.onboarding
    : {};
  const onboardingGoals = normalizeTextList(onboarding.goals);
  const goalDocTitles = goalsSnap.docs
    .map((doc) => {
      const data = doc.data() || {};
      return String(data.title || data.name || "").trim();
    })
    .filter(Boolean);
  const goals = uniqueTexts([...onboardingGoals, ...goalDocTitles]);

  return {
    id: null,
    data: {
      goals,
      coachStyle: onboarding.coachStyle || onboarding.tone || null,
      userState: "on_track",
      missionScore: 0,
      tasksCompletedToday: 0,
      tasksAbandonedToday: 0,
      goodHabitsLoggedToday: 0,
      badHabitSlipsToday: 0,
      longestActiveStreak: 0,
      activeStreakCount: 0,
      daysSinceLastActive: 0,
      quietDayMode: false,
      source: "fallback_user_profile",
      schemaVersion: 1,
    },
  };
}

async function loadLatestContextSnapshot(db, uid) {
  const fallbackPromise = loadFallbackContextSnapshot(db, uid);
  const snap = await db
    .collection("users")
    .doc(uid)
    .collection("ai_context_snapshots")
    .orderBy("createdAt", "desc")
    .limit(1)
    .get();

  if (snap.empty) {
    return fallbackPromise;
  }

  const doc = snap.docs[0];
  const data = doc.data() || {};
  if (hasGoalContext(data)) {
    return { id: doc.id, data };
  }

  const fallback = await fallbackPromise;
  return {
    id: doc.id,
    data: {
      ...fallback.data,
      ...data,
      goals: fallback.data.goals,
    },
  };
}

async function loadRecentMessages(db, uid, threadId) {
  const snap = await db
    .collection("users")
    .doc(uid)
    .collection("coach_messages")
    .orderBy("createdAt", "desc")
    .limit(20)
    .get();

  return snap.docs
    .map((doc) => ({ id: doc.id, ...(doc.data() || {}) }))
    .filter((message) => (message.threadId || message.sessionId || "main_thread") === threadId)
    .reverse();
}

async function generateReplyJson({ apiKey, systemPrompt, text }) {
  if (!apiKey) {
    throw new HttpsError("internal", "Gemini API key is not configured.");
  }

  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({
    model: MODEL_NAME,
    systemInstruction: systemPrompt,
    generationConfig: {
      responseMimeType: "application/json",
    },
  });
  const result = await model.generateContent(text);
  return result.response.text();
}

async function writeReplyAndEvent({
  db,
  uid,
  messageId,
  eventId,
  logId,
  messageData,
  eventData,
  speakLogData,
}) {
  const batch = db.batch();
  const userRef = db.collection("users").doc(uid);

  batch.set(userRef.collection("coach_messages").doc(messageId), messageData, { merge: true });
  batch.set(userRef.collection("coach_speak_log").doc(logId), speakLogData, { merge: true });
  batch.set(userRef.collection("events").doc(eventId), eventData, { merge: true });
  batch.set(userRef.collection("events_recent").doc(eventId), eventData, { merge: true });

  await batch.commit();
}

function makeMessageData({
  uid,
  messageId,
  threadId,
  mode,
  reply,
  timestamp,
  snapshotId,
  safetyBranch = "normal",
  aiGenerated = true,
}) {
  return {
    messageId,
    userId: uid,
    threadId,
    sessionId: threadId,
    role: "coach",
    isUser: false,
    message: reply.text,
    body: reply.text,
    text: reply.text,
    messageType: safetyBranch === "crisis" ? "safety_crisis" : "coach_reply",
    mode,
    source: "coachReply",
    deliveryType: "interactive_callable",
    timestamp,
    createdAt: timestamp,
    aiGenerated,
    suggestedActions: reply.suggestedActions,
    safetyBranch,
    contextSnapshotId: snapshotId || null,
    schemaVersion: 1,
  };
}

function makeEventData({ eventId, messageId, threadId, mode, safetyBranch, timestamp }) {
  return {
    eventId,
    eventName: "coach_replied",
    ts: timestamp,
    deviceLocalTs: timestamp,
    deviceId: "server",
    source: "server_callable",
    priority: safetyBranch === "crisis" ? "high" : "normal",
    payloadVersion: 1,
    payload: {
      messageId,
      threadId,
      mode,
      safetyBranch,
    },
    schemaVersion: 1,
  };
}

function makeSpeakLogData({ uid, logId, messageId, threadId, mode, safetyBranch, timestamp }) {
  return {
    logId,
    userId: uid,
    threadId,
    mode,
    decision: "spoke",
    messageId,
    messagePath: `users/${uid}/coach_messages/${messageId}`,
    ruleId: null,
    ruleIntent: null,
    source: "coachReply",
    safetyBranch,
    createdAt: timestamp,
    schemaVersion: 1,
  };
}

function makeCoachReplyHandler(deps = {}) {
  return async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "The function must be called while authenticated."
      );
    }

    const { userId, threadId, text, mode } = validateInput(request.data || {}, request.auth.uid);
    const uid = userId;
    const db = deps.db || admin.firestore();
    const now = deps.now || (() => new Date());
    const toTimestamp = deps.toTimestamp || timestampFromDate;
    const idFactory = deps.makeId || makeId;
    const timestamp = toTimestamp(now());
    const messageId = idFactory("coach_reply");
    const eventId = idFactory("coach_replied");
    const logId = idFactory("coach_speak_log");
    const loadSnapshot = deps.loadLatestContextSnapshot || loadLatestContextSnapshot;
    const loadMessages = deps.loadRecentMessages || loadRecentMessages;
    const writer = deps.writeReplyAndEvent || writeReplyAndEvent;

    const branch = safetyBranchForText(text);
    if (branch === "crisis") {
      const reply = {
        text: CRISIS_REPLY,
        suggestedActions: ["Call or text 988", "Contact someone you trust", "Move away from anything harmful"],
      };
      const messageData = makeMessageData({
        uid,
        messageId,
        threadId,
        mode,
        reply,
        timestamp,
        snapshotId: null,
        safetyBranch: branch,
        aiGenerated: false,
      });
      const eventData = makeEventData({ eventId, messageId, threadId, mode, safetyBranch: branch, timestamp });
      const speakLogData = makeSpeakLogData({ uid, logId, messageId, threadId, mode, safetyBranch: branch, timestamp });
      await writer({ db, uid, messageId, eventId, logId, messageData, eventData, speakLogData });
      return { text: reply.text, suggestedActions: reply.suggestedActions, messageId, safetyBranch: branch };
    }

    const contextSnapshot = await loadSnapshot(db, uid);
    const recentMessages = await loadMessages(db, uid, threadId);
    const systemPrompt = buildSystemPrompt({
      snapshot: contextSnapshot.data,
      recentMessages,
      mode,
    });

    const generator = deps.generateReplyJson || generateReplyJson;
    const generatorArgs = {
      systemPrompt,
      text,
    };
    if (!deps.generateReplyJson || deps.apiKey) {
      generatorArgs.apiKey = deps.apiKey || geminiApiKey.value();
    }

    const raw = await generator(generatorArgs);
    const reply = validateCoachReplyJson(raw);
    const messageData = makeMessageData({
      uid,
      messageId,
      threadId,
      mode,
      reply,
      timestamp,
      snapshotId: contextSnapshot.id,
      safetyBranch: "normal",
      aiGenerated: true,
    });
    const eventData = makeEventData({
      eventId,
      messageId,
      threadId,
      mode,
      safetyBranch: "normal",
      timestamp,
    });
    const speakLogData = makeSpeakLogData({
      uid,
      logId,
      messageId,
      threadId,
      mode,
      safetyBranch: "normal",
      timestamp,
    });

    await writer({ db, uid, messageId, eventId, logId, messageData, eventData, speakLogData });
    return { text: reply.text, suggestedActions: reply.suggestedActions, messageId, safetyBranch: "normal" };
  };
}

const coachReply = onCall(
  { secrets: [geminiApiKey] },
  makeCoachReplyHandler()
);

module.exports = {
  coachReply,
  _private: {
    buildSystemPrompt,
    loadFallbackContextSnapshot,
    loadLatestContextSnapshot,
    makeCoachReplyHandler,
    safetyBranchForText,
    validateCoachReplyJson,
    validateInput,
  },
};
