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

    const authHeader = request.headers.get("Authorization") || "";
    const token = authHeader.startsWith("Bearer ")
      ? authHeader.substring("Bearer ".length)
      : null;

    if (!token) {
      return json({ error: "Missing Authorization Bearer token" }, 401, corsHeaders);
    }

    let decodedToken;
    try {
      decodedToken = await verifyFirebaseIdToken(token, env.FIREBASE_PROJECT_ID);
    } catch (error) {
      return json(
        {
          error: "Invalid Firebase ID token",
          details: String(error)
        },
        401,
        corsHeaders
      );
    }

    let body;
    try {
      body = await request.json();
    } catch (_) {
      return json({ error: "Invalid JSON body" }, 400, corsHeaders);
    }

    const uidFromToken = decodedToken.sub;
    const userIdFromBody = String(body.userId || "").trim();

    if (!userIdFromBody) {
      return json({ error: "userId is required" }, 400, corsHeaders);
    }

    if (userIdFromBody !== uidFromToken) {
      return json({ error: "userId does not match Firebase token" }, 403, corsHeaders);
    }

    const text = String(body.text || body.message || "").trim();
    const mode = String(body.mode || "chat").trim();
    const threadId = String(body.threadId || "main_thread").trim();
    const context = body.context || {};

    if (!text) {
      return json({ error: "text is required" }, 400, corsHeaders);
    }

    const reply = await callGemini({
      env,
      text,
      mode,
      threadId,
      context,
      uid: uidFromToken
    });

    return json(
      {
        reply,
        source: "gemini",
        userId: uidFromToken,
        threadId
      },
      200,
      corsHeaders
    );
  }
};

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

async function callGemini({ env, text, mode, threadId, context, uid }) {
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

User ID:
${uid}

Thread:
${threadId}

Mode:
${mode}

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
        temperature: 0.7,
        maxOutputTokens: 300
      }
    })
  });

  const data = await response.json();

  if (!response.ok) {
    throw new Error(`Gemini failed: ${JSON.stringify(data)}`);
  }

  return (
    data?.candidates?.[0]?.content?.parts?.[0]?.text ||
    "I am here with you. Let us restart with one small action today."
  );
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
