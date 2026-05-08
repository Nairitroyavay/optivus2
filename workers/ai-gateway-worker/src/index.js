import { createRemoteJWKSet, jwtVerify } from "jose";

const firebaseJwks = createRemoteJWKSet(
  new URL("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com")
);

export default {
  async fetch(request, env) {
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization"
    };

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    if (request.method !== "POST") {
      return json({ error: "Method not allowed" }, 405, corsHeaders);
    }

    if (!env.GEMINI_API_KEY) {
      return json({ error: "Server missing GEMINI_API_KEY" }, 500, corsHeaders);
    }

    if (!env.FIREBASE_PROJECT_ID) {
      return json({ error: "Server missing FIREBASE_PROJECT_ID" }, 500, corsHeaders);
    }

    const authResult = await authenticate(request, env.FIREBASE_PROJECT_ID);
    if (!authResult.ok) {
      return json(authResult.body, authResult.status, corsHeaders);
    }

    let body;
    try {
      body = await request.json();
    } catch (_) {
      return json({ error: "Invalid JSON body" }, 400, corsHeaders);
    }

    const uid = authResult.decodedToken.sub;
    const userIdFromBody = String(body.userId || "").trim();
    if (userIdFromBody && userIdFromBody !== uid) {
      return json({ error: "userId does not match Firebase token" }, 403, corsHeaders);
    }

    const contextPayload = body.contextPayload;
    const hasContext = contextPayload && typeof contextPayload === "object" && !Array.isArray(contextPayload);
    const systemPrompt = String(body.systemPrompt || "").trim();
    const userMessage = String(body.userMessage || body.prompt || "").trim();

    if (!hasContext && (!systemPrompt || !userMessage)) {
      return json(
        { error: "Provide either contextPayload or both systemPrompt and userMessage" },
        400,
        corsHeaders
      );
    }

    try {
      const text = await generateText({
        env,
        uid,
        systemPrompt,
        userMessage,
        history: Array.isArray(body.history) ? body.history : null,
        contextPayload: hasContext ? contextPayload : null
      });

      return json(
        {
          text,
          source: "gemini",
          userId: uid
        },
        200,
        corsHeaders
      );
    } catch (error) {
      return json(
        {
          error: "AI generation failed",
          details: String(error)
        },
        502,
        corsHeaders
      );
    }
  }
};

async function authenticate(request, projectId) {
  const authHeader = request.headers.get("Authorization") || "";
  const token = authHeader.startsWith("Bearer ")
    ? authHeader.substring("Bearer ".length)
    : null;

  if (!token) {
    return {
      ok: false,
      status: 401,
      body: { error: "Missing Authorization Bearer token" }
    };
  }

  try {
    const decodedToken = await verifyFirebaseIdToken(token, projectId);
    return { ok: true, decodedToken };
  } catch (error) {
    return {
      ok: false,
      status: 401,
      body: {
        error: "Invalid Firebase ID token",
        details: String(error)
      }
    };
  }
}

async function verifyFirebaseIdToken(idToken, projectId) {
  const issuer = `https://securetoken.google.com/${projectId}`;

  const { payload } = await jwtVerify(idToken, firebaseJwks, {
    issuer,
    audience: projectId
  });

  if (!payload.sub) {
    throw new Error("Token has no subject");
  }

  return payload;
}

async function generateText({ env, uid, systemPrompt, userMessage, history, contextPayload }) {
  const hasContext = Boolean(contextPayload);
  const systemInstruction = hasContext
    ? buildEnrichedSystemPrompt(contextPayload)
    : systemPrompt;
  const prompt = hasContext
    ? String(contextPayload.rulePrompt || "Generate a proactive coach message.").trim()
    : userMessage;

  const contents = [];
  if (!hasContext && history) {
    for (const item of history) {
      const sanitized = sanitizeGeminiContent(item);
      if (sanitized) {
        contents.push(sanitized);
      }
    }
  }
  contents.push({
    role: "user",
    parts: [{ text: prompt }]
  });

  const data = await callGemini({
    env,
    contents,
    systemInstruction,
    maxOutputTokens: hasContext ? 400 : 500,
    temperature: hasContext ? 0.7 : 0.6
  });

  const text = extractGeminiText(data).trim();
  if (!text) {
    throw new Error("Gemini returned empty text");
  }

  console.log(
    `[aiGenerate] generated text for uid=${uid} mode=${hasContext ? "context" : "single"}`
  );

  return text;
}

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

function sanitizeGeminiContent(item) {
  if (!item || typeof item !== "object") return null;
  const role = item.role === "model" ? "model" : "user";
  const rawParts = Array.isArray(item.parts) ? item.parts : [];
  const parts = rawParts
    .map((part) => {
      if (typeof part === "string") return { text: part };
      if (part && typeof part.text === "string") return { text: part.text };
      return null;
    })
    .filter(Boolean)
    .filter((part) => part.text.trim().length > 0);

  if (parts.length === 0) return null;
  return { role, parts };
}

async function callGemini({ env, contents, systemInstruction, maxOutputTokens, temperature }) {
  const model = env.GEMINI_MODEL || "gemini-1.5-flash";
  const geminiUrl =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${env.GEMINI_API_KEY}`;

  const response = await fetch(geminiUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      systemInstruction: {
        parts: [{ text: systemInstruction }]
      },
      contents,
      generationConfig: {
        temperature,
        maxOutputTokens
      }
    })
  });

  const data = await response.json();
  if (!response.ok) {
    throw new Error(`Gemini failed: ${JSON.stringify(data)}`);
  }

  return data;
}

function extractGeminiText(data) {
  return data?.candidates?.[0]?.content?.parts
    ?.map((part) => part.text || "")
    .join("")
    || "";
}

function json(data, status = 200, headers = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...headers
    }
  });
}
