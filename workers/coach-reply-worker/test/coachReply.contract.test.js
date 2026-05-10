import assert from "node:assert/strict";
import test from "node:test";
import { SignJWT, exportJWK, generateKeyPair } from "jose";

const projectId = "optivus-test";

let worker;
let authPrivateKey;
let authJwk;

test.before(async () => {
  const authKeys = await generateKeyPair("RS256");
  authPrivateKey = authKeys.privateKey;
  authJwk = await exportJWK(authKeys.publicKey);
  authJwk.kid = "test-key";
  authJwk.alg = "RS256";
  authJwk.use = "sig";

  worker = (await import("../src/index.js")).default;
});

test("returns authenticated preview-only coach reply", async () => {
  const state = mockFetchState("Start with one small reset.");
  globalThis.fetch = createMockFetch(state);

  const response = await callWorker({
    uid: "coach_success_uid",
    body: {
      userId: "coach_success_uid",
      threadId: "main",
      mode: "chat",
      text: "I missed my morning plan"
    }
  });
  const body = await response.json();

  assert.equal(response.status, 200, JSON.stringify(body));
  assert.equal(body.ok, true);
  assert.equal(body.reply, "Start with one small reset.");
  assert.equal(body.text, "Start with one small reset.");
  assert.equal(body.userId, "coach_success_uid");
  assert.equal(body.threadId, "main");
  assert.equal(body.previewOnly, true);
  assert.equal(body.safetyBranch, "standard");
  assert.equal(body.source, "gemini");
  assert.equal(state.geminiCalls, 1);
});

test("requires Firebase Authorization before Gemini call", async () => {
  const state = mockFetchState("No call");
  globalThis.fetch = createMockFetch(state);

  const response = await worker.fetch(
    new Request("https://coach-reply.test", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ userId: "coach_no_auth_uid", text: "hello" })
    }),
    env()
  );
  const body = await response.json();

  assert.equal(response.status, 401);
  assertErrorShape(body, "AUTH_MISSING", "Missing Authorization Bearer token", 401);
  assert.equal(state.geminiCalls, 0);
});

test("rejects invalid Firebase token before Gemini call", async () => {
  const state = mockFetchState("No call");
  globalThis.fetch = createMockFetch(state);

  const response = await worker.fetch(
    new Request("https://coach-reply.test", {
      method: "POST",
      headers: {
        "Authorization": "Bearer invalid-token",
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ userId: "coach_invalid_uid", text: "hello" })
    }),
    env()
  );
  const body = await response.json();

  assert.equal(response.status, 401);
  assertErrorShape(body, "AUTH_INVALID", "Invalid Firebase ID token", 401);
  assert.equal(state.geminiCalls, 0);
});

test("rejects mismatched userId", async () => {
  const state = mockFetchState("No call");
  globalThis.fetch = createMockFetch(state);

  const response = await callWorker({
    uid: "coach_token_uid",
    body: {
      userId: "different_uid",
      text: "hello"
    }
  });
  const body = await response.json();

  assert.equal(response.status, 403, JSON.stringify(body));
  assertErrorShape(body, "AUTH_USER_MISMATCH", "userId does not match Firebase token", 403);
  assert.equal(state.geminiCalls, 0);
});

test("rate-limits before Gemini call", async () => {
  const state = mockFetchState("First reply");
  globalThis.fetch = createMockFetch(state);
  const options = {
    uid: "coach_rate_uid",
    env: env({ COACH_REPLY_RATE_LIMIT_PER_MINUTE: "1", RATE_LIMIT_WINDOW_MS: "60000" }),
    body: { userId: "coach_rate_uid", text: "hello" }
  };

  const first = await callWorker(options);
  const second = await callWorker(options);
  const secondBody = await second.json();

  assert.equal(first.status, 200);
  assert.equal(second.status, 429, JSON.stringify(secondBody));
  assertErrorShape(secondBody, "RATE_LIMITED", "Coach reply rate limit reached", 429);
  assert.equal(typeof secondBody.retryAfterSeconds, "number");
  assert.equal(state.geminiCalls, 1);
});

test("routes crisis safety branch without Gemini call", async () => {
  const state = mockFetchState("No call");
  globalThis.fetch = createMockFetch(state);

  const response = await callWorker({
    uid: "coach_crisis_uid",
    body: {
      userId: "coach_crisis_uid",
      text: "I might kill myself"
    }
  });
  const body = await response.json();

  assert.equal(response.status, 200, JSON.stringify(body));
  assert.equal(body.ok, true);
  assert.equal(body.source, "safety");
  assert.equal(body.safetyBranch, "crisis");
  assert.equal(body.previewOnly, true);
  assert.ok(body.reply.includes("988"));
  assert.equal(state.geminiCalls, 0);
});

test("labels recovery safety branch while still using Gemini", async () => {
  const state = mockFetchState("Take one small reset step.");
  globalThis.fetch = createMockFetch(state);

  const response = await callWorker({
    uid: "coach_recovery_uid",
    body: {
      userId: "coach_recovery_uid",
      text: "I had a smoking relapse"
    }
  });
  const body = await response.json();

  assert.equal(response.status, 200, JSON.stringify(body));
  assert.equal(body.ok, true);
  assert.equal(body.source, "gemini");
  assert.equal(body.safetyBranch, "recovery");
  assert.deepEqual(body.suggestedActions, ["take_one_small_step", "reset_today"]);
  assert.equal(state.geminiCalls, 1);
});

async function callWorker({ uid, body, env: workerEnv }) {
  const token = await firebaseToken(uid);
  return worker.fetch(
    new Request("https://coach-reply.test", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${token}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify(body)
    }),
    workerEnv || env()
  );
}

async function firebaseToken(uid) {
  return new SignJWT({ sub: uid, user_id: uid })
    .setProtectedHeader({ alg: "RS256", kid: "test-key" })
    .setIssuer(`https://securetoken.google.com/${projectId}`)
    .setAudience(projectId)
    .setIssuedAt()
    .setExpirationTime("5m")
    .sign(authPrivateKey);
}

function env(overrides = {}) {
  return {
    GEMINI_API_KEY: "test-gemini-key",
    FIREBASE_PROJECT_ID: projectId,
    COACH_REPLY_TEST_JWKS_JSON: JSON.stringify({ keys: [authJwk] }),
    ...overrides
  };
}

function mockFetchState(reply) {
  return {
    reply,
    geminiCalls: 0
  };
}

function createMockFetch(state) {
  return async (input) => {
    const url = typeof input === "string" ? input : input.url;
    if (url.includes("generativelanguage.googleapis.com")) {
      state.geminiCalls += 1;
      return jsonResponse({
        candidates: [
          {
            content: {
              parts: [{ text: state.reply }]
            }
          }
        ]
      });
    }
    return jsonResponse({ error: { status: "NOT_FOUND", url } }, 404);
  };
}

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" }
  });
}

function assertErrorShape(body, code, message, status) {
  assert.equal(body.ok, false);
  assert.equal(body.error?.code, code);
  assert.equal(body.error?.message, message);
  assert.equal(body.code, code);
  assert.equal(body.message, message);
  assert.equal(body.status, status);
}
