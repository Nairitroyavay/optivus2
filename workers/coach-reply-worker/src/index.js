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
        "Server missing coach reply configuration",
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
    if (!userIdFromBody) {
      return errorResponse("INVALID_INPUT", "userId is required", 400, corsHeaders);
    }
    if (userIdFromBody !== uid) {
      return errorResponse("AUTH_USER_MISMATCH", "userId does not match Firebase token", 403, corsHeaders);
    }

    const text = stringField(body.text || body.message);
    const mode = stringField(body.mode) || "chat";
    const threadId = stringField(body.threadId) || "main_thread";
    const context = objectField(body.context) || {};

    if (!text) {
      return errorResponse("INVALID_INPUT", "text is required", 400, corsHeaders);
    }

    const safetyBranch = safetyBranchFor(text, context);
    const rateLimit = checkRateLimit(env, uid, "coachReply");
    if (!rateLimit.ok) {
      return errorResponse(
        "RATE_LIMITED",
        "Coach reply rate limit reached",
        429,
        corsHeaders,
        { retryAfterSeconds: rateLimit.retryAfterSeconds }
      );
    }

    if (safetyBranch === "crisis") {
      return json(
        {
          ok: true,
          reply: crisisReply(),
          text: crisisReply(),
          source: "safety",
          userId: uid,
          threadId,
          safetyBranch,
          previewOnly: true,
          suggestedActions: ["contact_support", "reach_trusted_person"]
        },
        200,
        corsHeaders
      );
    }

    try {
      const reply = await callGemini({
        env,
        text,
        mode,
        threadId,
        context,
        uid,
        safetyBranch
      });

      return json(
        {
          ok: true,
          reply,
          text: reply,
          source: "gemini",
          userId: uid,
          threadId,
          safetyBranch,
          previewOnly: true,
          suggestedActions: suggestedActionsFor(safetyBranch)
        },
        200,
        corsHeaders
      );
    } catch (_) {
      return errorResponse("AI_GENERATION_FAILED", "Coach reply generation failed", 502, corsHeaders);
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
  const keySet = env.COACH_REPLY_TEST_JWKS_JSON
    ? createLocalJWKSet(JSON.parse(env.COACH_REPLY_TEST_JWKS_JSON))
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
  const limit = safePositiveInteger(env.COACH_REPLY_RATE_LIMIT_PER_MINUTE || env.RATE_LIMIT_PER_MINUTE, 30);
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

function safetyBranchFor(text, context) {
  const combined = `${text} ${JSON.stringify(context || {})}`.toLowerCase();
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

function suggestedActionsFor(safetyBranch) {
  if (safetyBranch === "recovery") {
    return ["take_one_small_step", "reset_today"];
  }
  return [];
}

async function callGemini({ env, text, mode, threadId, context, uid, safetyBranch }) {
  const model = env.GEMINI_MODEL || "gemini-1.5-flash";

  const prompt = `
You are Optivus AI Coach.

Rules:
- Be supportive, direct, and practical.
- Keep reply short.
- Help user take one next action.
- Do not shame the user.
- Do not provide medical diagnosis.
- If user mentions smoking, stress, relapse, missed habit, or overuse, respond with empathy and one recovery step.
- Ask only one follow-up question if useful.
- Return only the final coach reply text.

User ID:
${uid}

Thread:
${threadId}

Mode:
${mode}

Safety branch:
${safetyBranch}

User message:
${text}

Context:
${JSON.stringify(context)}
`;

  const geminiUrl =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${env.GEMINI_API_KEY}`;

  const response = await fetch(geminiUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      contents: [
        {
          role: "user",
          parts: [{ text: prompt }]
        }
      ],
      generationConfig: {
        temperature: safetyBranch === "recovery" ? 0.5 : 0.7,
        maxOutputTokens: 300
      }
    })
  });

  const data = await response.json();

  if (!response.ok) {
    throw new Error("Gemini failed");
  }

  const reply = extractGeminiText(data).trim();
  if (!reply) {
    throw new Error("Gemini returned empty text");
  }
  return reply;
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
