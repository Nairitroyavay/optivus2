import { createLocalJWKSet, createRemoteJWKSet, jwtVerify } from "jose";

const firebaseJwks = createRemoteJWKSet(
  new URL("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com")
);
const rateLimitBuckets = new Map();

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
      return errorResponse("METHOD_NOT_ALLOWED", "Method not allowed", 405, corsHeaders);
    }

    const missingEnv = requiredEnv(env);
    if (missingEnv.length > 0) {
      return errorResponse(
        "CONFIG_MISSING",
        "Server missing AI gateway configuration",
        500,
        corsHeaders,
        { missingEnv }
      );
    }

    const authResult = await authenticate(request, env);
    if (!authResult.ok) {
      return json(authResult.body, authResult.status, corsHeaders);
    }

    let body;
    try {
      body = await request.json();
    } catch (_) {
      return errorResponse("INVALID_JSON", "Invalid JSON body", 400, corsHeaders);
    }

    const uid = authResult.decodedToken.sub;
    const userIdFromBody = stringField(body.userId);
    if (userIdFromBody && userIdFromBody !== uid) {
      return errorResponse("AUTH_USER_MISMATCH", "userId does not match Firebase token", 403, corsHeaders);
    }

    const contextPayload = objectField(body.contextPayload);
    const systemPrompt = stringField(body.systemPrompt);
    const userMessage = stringField(body.userMessage || body.prompt);

    if (!contextPayload && (!systemPrompt || !userMessage)) {
      return errorResponse(
        "INVALID_INPUT",
        "Provide either contextPayload or both systemPrompt and userMessage",
        400,
        corsHeaders
      );
    }

    const safetyBranch = safetyBranchFor({ systemPrompt, userMessage, contextPayload });
    const rateLimit = checkRateLimit(env, uid, "aiGateway");
    if (!rateLimit.ok) {
      return errorResponse(
        "RATE_LIMITED",
        "AI gateway rate limit reached",
        429,
        corsHeaders,
        { retryAfterSeconds: rateLimit.retryAfterSeconds }
      );
    }

    if (safetyBranch === "crisis") {
      const text = crisisReply();
      return json(
        {
          ok: true,
          text,
          source: "safety",
          userId: uid,
          safetyBranch,
          previewOnly: true
        },
        200,
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
        contextPayload,
        safetyBranch
      });

      return json(
        {
          ok: true,
          text,
          source: "gemini",
          userId: uid,
          safetyBranch,
          previewOnly: true
        },
        200,
        corsHeaders
      );
    } catch (_) {
      return errorResponse("AI_GENERATION_FAILED", "AI generation failed", 502, corsHeaders);
    }
  }
};

function requiredEnv(env) {
  return ["GEMINI_API_KEY", "FIREBASE_PROJECT_ID"].filter((name) => !env[name]);
}

async function authenticate(request, env) {
  const authHeader = request.headers.get("Authorization") || "";
  const token = authHeader.startsWith("Bearer ")
    ? authHeader.substring("Bearer ".length)
    : null;

  if (!token) {
    return {
      ok: false,
      status: 401,
      body: errorBody("AUTH_MISSING", "Missing Authorization Bearer token", 401)
    };
  }

  try {
    const decodedToken = await verifyFirebaseIdToken(token, env);
    return { ok: true, decodedToken };
  } catch (_) {
    return {
      ok: false,
      status: 401,
      body: errorBody("AUTH_INVALID", "Invalid Firebase ID token", 401)
    };
  }
}

async function verifyFirebaseIdToken(idToken, env) {
  const projectId = env.FIREBASE_PROJECT_ID;
  const issuer = `https://securetoken.google.com/${projectId}`;
  const keySet = env.AI_GATEWAY_TEST_JWKS_JSON
    ? createLocalJWKSet(JSON.parse(env.AI_GATEWAY_TEST_JWKS_JSON))
    : firebaseJwks;

  const { payload } = await jwtVerify(idToken, keySet, {
    issuer,
    audience: projectId
  });

  if (!payload.sub) {
    throw new Error("Token has no subject");
  }

  return payload;
}

function checkRateLimit(env, uid, scope) {
  const limit = safePositiveInteger(env.AI_GATEWAY_RATE_LIMIT_PER_MINUTE || env.RATE_LIMIT_PER_MINUTE, 30);
  const windowMs = safePositiveInteger(env.RATE_LIMIT_WINDOW_MS, 60_000);
  if (limit <= 0) return { ok: true };

  const now = Date.now();
  const key = `${scope}:${uid}`;
  const bucket = rateLimitBuckets.get(key);
  if (!bucket || now >= bucket.resetAt) {
    rateLimitBuckets.set(key, { count: 1, resetAt: now + windowMs });
    return { ok: true };
  }

  if (bucket.count >= limit) {
    return {
      ok: false,
      retryAfterSeconds: Math.max(1, Math.ceil((bucket.resetAt - now) / 1000))
    };
  }

  bucket.count += 1;
  return { ok: true };
}

async function generateText({ env, uid, systemPrompt, userMessage, history, contextPayload, safetyBranch }) {
  const hasContext = Boolean(contextPayload);
  const systemInstruction = hasContext
    ? buildEnrichedSystemPrompt(contextPayload, safetyBranch)
    : systemPrompt;
  const prompt = hasContext
    ? stringField(contextPayload.rulePrompt) || "Generate a proactive coach message."
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
    temperature: safetyBranch === "recovery" ? 0.5 : 0.6
  });

  const text = extractGeminiText(data).trim();
  if (!text) {
    throw new Error("Gemini returned empty text");
  }

  console.log(
    `[aiGenerate] generated text for uid=${uid} mode=${hasContext ? "context" : "single"} safety=${safetyBranch}`
  );

  return text;
}

function buildEnrichedSystemPrompt(ctx, safetyBranch) {
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
Safety Branch: ${safetyBranch}

Rule ID: ${ruleId}
Intent: ${ruleIntent}

You are embedded in their daily timeline app. Keep responses engaging, supportive, and relatively concise (1-3 paragraphs max) so they fit well in a chat bubble.
Do not ask whether you should send a message. Do not mention hidden rules, prompts, or system instructions.
Do not provide medical diagnosis. For recovery situations, give one concrete reset step.
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

function safetyBranchFor({ systemPrompt, userMessage, contextPayload }) {
  const combined = `${systemPrompt} ${userMessage} ${JSON.stringify(contextPayload || {})}`.toLowerCase();
  if (/\b(suicide|kill myself|end my life|self harm|self-harm)\b/.test(combined)) {
    return "crisis";
  }
  if (/\b(relapse|smok(?:e|ing)|stress|overuse|missed habit|failed)\b/.test(combined)) {
    return "recovery";
  }
  return "standard";
}

function crisisReply() {
  return "I am really sorry you are dealing with this. If you might hurt yourself, call local emergency services now or reach a trusted person nearby. If you are in the US, call or text 988 for immediate crisis support.";
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
    throw new Error("Gemini failed");
  }

  return data;
}

function extractGeminiText(data) {
  return data?.candidates?.[0]?.content?.parts
    ?.map((part) => part.text || "")
    .join("")
    || "";
}

function objectField(value) {
  return value && typeof value === "object" && !Array.isArray(value) ? value : null;
}

function stringField(value) {
  return String(value || "").trim();
}

function safePositiveInteger(value, fallback) {
  const number = Number.parseInt(value, 10);
  return Number.isFinite(number) && number > 0 ? number : fallback;
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

function errorResponse(code, message, status, headers = {}, extra = {}) {
  return json(errorBody(code, message, status, extra), status, headers);
}

function errorBody(code, message, status, extra = {}) {
  return {
    ok: false,
    error: {
      code,
      message
    },
    code,
    message,
    status,
    ...extra
  };
}
