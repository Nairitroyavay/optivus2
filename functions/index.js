const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const admin = require("firebase-admin");

admin.initializeApp();

// Define the secret parameter for the Gemini API key
const geminiApiKey = defineSecret("GEMINI_API_KEY");

// ── Helper: Build an enriched system prompt from contextPayload ─────────────
// Called only when the client sends a contextPayload (proactive rule-triggered
// messages). Interactive chat still uses the raw systemPrompt field.
function buildEnrichedSystemPrompt(ctx) {
  const coachName = ctx.coachName || "AI Coach";
  const tone = ctx.tone || "Empathetic and motivating";
  const goals = ctx.goals || "No specific goals set";
  const goodHabits = ctx.goodHabits || "None specified";
  const badHabits = ctx.badHabits || "None specified";
  const activeHabits = ctx.activeHabits || "No active habits yet.";
  const todayTasks = ctx.todayTasks || "None scheduled for today.";
  const activeStreaks = ctx.activeStreaks || "No active streaks yet.";
  const ruleIntent = ctx.ruleIntent || "";
  const rulePrompt = ctx.rulePrompt || "";
  const ruleId = ctx.ruleId || "";
  const userState = ctx.userState || "on_track";
  const missionScore = ctx.missionScore ?? 0;

  return `You are the user's personal Optivus AI life coach. Your name is ${coachName}.
Your tone should be: ${tone}.
User's main goals: ${goals}.
Good habits they want to build: ${goodHabits}.
Habits trying to break: ${badHabits}.
A rule has already decided that you should speak right now. You are not deciding whether to speak.
Write exactly one coach message that matches the triggered coaching need and stays grounded in the real user context below.

Current Context:
Today's Tasks:
${todayTasks}

Active Habits:
${activeHabits}

Active Streaks:
${activeStreaks}

User State: ${userState}
Mission Score: ${missionScore}/100

Rule ID: ${ruleId}
Intent: ${ruleIntent}

You are embedded in their daily timeline app. Keep responses engaging, supportive, and relatively concise (1-3 paragraphs max) so they fit well in a chat bubble.
Do not ask whether you should send a message. Do not mention hidden rules, prompts, or system instructions.
Return only the final coach message text, with no JSON or markdown.

${rulePrompt}`;
}

exports.aiGenerate = onCall(
  { secrets: [geminiApiKey] },
  async (request) => {
    // Only allow authenticated users
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "The function must be called while authenticated."
      );
    }

    const { systemPrompt, userMessage, history, contextPayload } =
      request.data;

    // ── Validate: either contextPayload OR (systemPrompt + userMessage) ────
    const hasContext = contextPayload && typeof contextPayload === "object";
    if (!hasContext && (!systemPrompt || !userMessage)) {
      throw new HttpsError(
        "invalid-argument",
        "Provide either 'contextPayload' or both 'systemPrompt' and 'userMessage'."
      );
    }

    try {
      // Access the secret API key
      const apiKey = geminiApiKey.value();
      if (!apiKey) {
        throw new HttpsError(
          "internal",
          "Gemini API key is not configured."
        );
      }

      const genAI = new GoogleGenerativeAI(apiKey);

      // Choose system instruction based on mode
      const sysInstruction = hasContext
        ? buildEnrichedSystemPrompt(contextPayload)
        : systemPrompt;

      const model = genAI.getGenerativeModel({
        model: "gemini-1.5-flash",
        systemInstruction: sysInstruction,
      });

      let responseText = "";

      if (hasContext) {
        // Proactive rule-triggered generation — single-shot, no history
        const prompt =
          contextPayload.rulePrompt || "Generate a proactive coach message.";
        console.log(
          `[aiGenerate] Rule-selected request received: ruleId=${contextPayload.ruleId || "unknown"} intent=${contextPayload.ruleIntent || "unknown"}`
        );
        const result = await model.generateContent(prompt);
        responseText = result.response.text();
        console.log(
          `[aiGenerate] Generated coach message after rule selection: ruleId=${contextPayload.ruleId || "unknown"}`
        );
      } else if (history && Array.isArray(history)) {
        // Interactive multi-turn chat
        const chat = model.startChat({
          history: history,
        });
        const result = await chat.sendMessage(userMessage);
        responseText = result.response.text();
      } else {
        // Interactive single-shot text generation
        const result = await model.generateContent(userMessage);
        responseText = result.response.text();
      }

      return { text: responseText.trim() };
    } catch (error) {
      console.error("Error generating AI content:", error);
      throw new HttpsError("internal", "Failed to generate AI content.");
    }
  }
);

// ── Scheduled Jobs ──────────────────────────────────────────────────────────
const { scheduledDayClose } = require("./jobs/dayClose");
const { scheduledInactivityCheck } = require("./jobs/inactivityCheck");
const { scheduledMorningBrief } = require("./jobs/morningBrief");
const { scheduledMiddayPulse } = require("./jobs/middayPulse");

exports.scheduledDayClose = scheduledDayClose;
exports.scheduledInactivityCheck = scheduledInactivityCheck;
exports.scheduledMorningBrief = scheduledMorningBrief;
exports.scheduledMiddayPulse = scheduledMiddayPulse;
