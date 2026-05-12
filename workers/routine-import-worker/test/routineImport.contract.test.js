import assert from "node:assert/strict";
import test from "node:test";
import { SignJWT, exportJWK, exportPKCS8, generateKeyPair } from "jose";

const projectId = "optivus-test";
const uid = "test_uid";
const modeFixtures = {
  skin_care_text: {
    request: { mode: "skin_care_text", routineType: "skin_care", sourceText: "Cleanser, moisturiser at night" },
    ai: { templates: [skinCareTemplate()] },
    responseKey: "templates"
  },
  skin_care_photo: {
    request: { mode: "skin_care_photo", routineType: "skin_care", imageMetadata: { fileName: "shelf.jpg", ocrText: "cleanser serum" } },
    ai: { templates: [skinCareTemplate()] },
    responseKey: "templates"
  },
  supplement_text: {
    request: { mode: "supplement_text", routineType: "supplements", sourceText: "Vitamin D 1000 IU after breakfast" },
    ai: { templates: [supplementTemplate()] },
    responseKey: "templates"
  },
  class_timetable_photo: {
    request: { mode: "class_timetable_photo", routineType: "classes", imageMetadata: { ocrText: "Physics 9-10 A101" } },
    ai: { templates: [classTemplate()] },
    responseKey: "templates"
  },
  class_timetable_text: {
    request: { mode: "class_timetable_text", routineType: "classes", sourceText: "Mon Physics 9:00-10:00 A-101 Dr Rao" },
    ai: { templates: [classTemplate()] },
    responseKey: "templates"
  },
  eating_mess_photo: {
    request: { mode: "eating_mess_photo", routineType: "eating", imageMetadata: { ocrText: "Breakfast poha" } },
    ai: { templates: [eatingTemplate()] },
    responseKey: "templates"
  },
  eating_mess_text: {
    request: { mode: "eating_mess_text", routineType: "eating", sourceText: "Breakfast: Idli, Sambar\nLunch: Dal, Rice" },
    ai: { templates: [eatingTemplate()] },
    responseKey: "templates"
  },
  eating_goal_text: {
    request: { mode: "eating_goal_text", routineType: "eating", sourceText: "I want regular meals around class" },
    ai: { templates: [eatingTemplate()] },
    responseKey: "templates"
  },
  routine_goal_suggestions: {
    request: { mode: "routine_goal_suggestions", sourceText: "Help me study before lunch" },
    ai: {
      suggestions: [
        {
          id: "study_block",
          title: "Add study block",
          reason: "Protects focus before lunch",
          action: "add",
          time: "10:00",
          taskTitle: "Study block",
          priorityScore: 0.8
        }
      ]
    },
    responseKey: "suggestions"
  }
};

let worker;
let authPrivateKey;
let authJwk;
let servicePrivateKeyPem;

test.before(async () => {
  const authKeys = await generateKeyPair("RS256");
  authPrivateKey = authKeys.privateKey;
  authJwk = await exportJWK(authKeys.publicKey);
  authJwk.kid = "test-key";
  authJwk.alg = "RS256";
  authJwk.use = "sig";

  const serviceKeys = await generateKeyPair("RS256");
  servicePrivateKeyPem = await exportPKCS8(serviceKeys.privateKey);

  worker = (await import("../src/index.js")).default;
});

for (const [mode, fixture] of Object.entries(modeFixtures)) {
  test(`returns validated preview without Firestore writes for ${mode}`, async () => {
    const state = mockFetchState(fixture.ai);
    globalThis.fetch = createMockFetch(state);

    const response = await callWorker(fixture.request);
    const body = await response.json();

    assert.equal(response.status, 200, JSON.stringify(body));
    assert.equal(body.ok, true);
    assert.equal(body.mode, mode);
    assert.equal(body.commit, false);
    assert.equal(body.previewOnly, true);
    assert.equal(body.userId, uid);
    assert.equal(body.usage.aiCalls, 0);
    assert.equal(body.usage.previewOnly, true);
    assert.equal(body.suggestionIds.length, 0);
    assert.equal(Array.isArray(body[fixture.responseKey]), true);
    assert.equal(body[fixture.responseKey].length, 1);
    assert.equal(state.geminiCalls, 1);
    assert.equal(state.usageCommits, 0);
    assert.equal(state.suggestionCommits, 0);
  });
}

test("supports current Flutter mode aliases", async () => {
  const state = mockFetchState({ templates: [supplementTemplate()] });
  globalThis.fetch = createMockFetch(state);

  const response = await callWorker({
    mode: "text_ai",
    routineType: "supplements",
    sourceText: "Magnesium at night"
  });
  const body = await response.json();

  assert.equal(response.status, 200, JSON.stringify(body));
  assert.equal(body.ok, true);
  assert.equal(body.mode, "supplement_text");
  assert.equal(body.templates[0].dosage, "1000 IU");
});

test("supports eating mess text mode alias", async () => {
  const state = mockFetchState({ templates: [eatingTemplate()] });
  globalThis.fetch = createMockFetch(state);

  const response = await callWorker({
    mode: "eating_mess_text",
    routineType: "eating",
    sourceText: "Breakfast: Poha"
  });
  const body = await response.json();

  assert.equal(response.status, 200, JSON.stringify(body));
  assert.equal(body.ok, true);
  assert.equal(body.mode, "eating_mess_text");
});

test("supports classes text AI mode alias", async () => {
  const state = mockFetchState({ templates: [classTemplate()] });
  globalThis.fetch = createMockFetch(state);

  const response = await callWorker({
    mode: "text_ai",
    routineType: "classes",
    sourceText: "Mon Physics 9:00-10:00 A-101 Dr Rao"
  });
  const body = await response.json();

  assert.equal(response.status, 200, JSON.stringify(body));
  assert.equal(body.ok, true);
  assert.equal(body.mode, "class_timetable_text");
  assert.equal(body.templates[0].subject, "Physics");
});

test("rejects malformed AI output with a safe error", async () => {
  const state = mockFetchState("not-json");
  globalThis.fetch = createMockFetch(state);

  const response = await callWorker(modeFixtures.skin_care_text.request);
  const body = await response.json();

  assert.equal(response.status, 502, JSON.stringify(body));
  assertErrorShape(body, "AI_OUTPUT_REJECTED", "Routine import AI output rejected", 502);
  assert.equal(body.details, undefined);
  assert.equal(state.geminiCalls, 1);
  assert.equal(state.usageCommits, 0);
  assert.equal(state.suggestionCommits, 0);
});

test("rejects schema-invalid AI output with a safe error", async () => {
  const state = mockFetchState({
    templates: [
      {
        templateId: "magnesium",
        title: "Magnesium",
        startTime: "21:00",
        endTime: "21:05",
        repeatRule: "daily"
      }
    ]
  });
  globalThis.fetch = createMockFetch(state);

  const response = await callWorker(modeFixtures.supplement_text.request);
  const body = await response.json();

  assert.equal(response.status, 502, JSON.stringify(body));
  assertErrorShape(body, "AI_OUTPUT_REJECTED", "Routine import AI output rejected", 502);
  assert.equal(body.details, undefined);
  assert.equal(state.geminiCalls, 1);
  assert.equal(state.usageCommits, 0);
  assert.equal(state.suggestionCommits, 0);
});

test("applies About You eating safety flags to eating previews", async () => {
  const state = mockFetchState({
    templates: [
      {
        ...eatingTemplate(),
        notes: "500 kcal weight loss diet",
        calories: 500,
        macros: { protein: 20 }
      }
    ]
  }, {
    profileData: {
      subscription: { plan: "free" },
      sensitiveContext: {
        eatingDisorderFlag: true
      }
    }
  });
  globalThis.fetch = createMockFetch(state);

  const response = await callWorker(modeFixtures.eating_goal_text.request);
  const body = await response.json();

  assert.equal(response.status, 200, JSON.stringify(body));
  assert.equal(body.ok, true);
  assert.equal(body.safetyFlags.eatingDisorderHistory, true);
  assert.equal(body.templates[0].safetyAdjusted, true);
  assert.equal(body.templates[0].notes.includes("kcal"), false);
  assert.equal(body.templates[0].notes.includes("weight loss"), false);
  assert.equal(body.templates[0].notes.includes("diet"), false);
  assert.equal(body.templates[0].calories, undefined);
  assert.equal(body.templates[0].macros, undefined);
});

test("rejects usage cap before Gemini call", async () => {
  const state = mockFetchState({ templates: [skinCareTemplate()] }, { usageAiCalls: 20 });
  globalThis.fetch = createMockFetch(state);

  const response = await callWorker(modeFixtures.skin_care_text.request);
  const body = await response.json();

  assert.equal(response.status, 429, JSON.stringify(body));
  assertErrorShape(body, "RATE_LIMITED", "AI usage cap reached", 429);
  assert.equal(state.geminiCalls, 0);
  assert.equal(state.usageCommits, 0);
});

test("requires Firebase Authorization before Gemini call", async () => {
  const state = mockFetchState({ templates: [skinCareTemplate()] });
  globalThis.fetch = createMockFetch(state);

  const response = await worker.fetch(
    new Request("https://routine-import.test", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(modeFixtures.skin_care_text.request)
    }),
    env()
  );

  assert.equal(response.status, 401);
  const body = await response.json();
  assertErrorShape(body, "AUTH_MISSING", "Missing Authorization Bearer token", 401);
  assert.equal(state.geminiCalls, 0);
});

test("rejects invalid Firebase token before Gemini call", async () => {
  const state = mockFetchState({ templates: [skinCareTemplate()] });
  globalThis.fetch = createMockFetch(state);

  const response = await worker.fetch(
    new Request("https://routine-import.test", {
      method: "POST",
      headers: {
        "Authorization": "Bearer invalid-token",
        "Content-Type": "application/json"
      },
      body: JSON.stringify(modeFixtures.skin_care_text.request)
    }),
    env()
  );
  const body = await response.json();

  assert.equal(response.status, 401);
  assertErrorShape(body, "AUTH_INVALID", "Invalid Firebase ID token", 401);
  assert.equal(state.geminiCalls, 0);
});

test("rejects mismatched userId before Gemini call", async () => {
  const state = mockFetchState({ templates: [skinCareTemplate()] });
  globalThis.fetch = createMockFetch(state);
  const token = await firebaseToken();

  const response = await worker.fetch(
    new Request("https://routine-import.test", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${token}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ userId: "different_uid", ...modeFixtures.skin_care_text.request })
    }),
    env()
  );
  const body = await response.json();

  assert.equal(response.status, 403, JSON.stringify(body));
  assertErrorShape(body, "AUTH_USER_MISMATCH", "userId does not match Firebase token", 403);
  assert.equal(state.geminiCalls, 0);
});

test("rejects routine commits as preview-only", async () => {
  const state = mockFetchState({ templates: [skinCareTemplate()] });
  globalThis.fetch = createMockFetch(state);

  const response = await callWorker({
    ...modeFixtures.skin_care_text.request,
    commit: true
  });
  const body = await response.json();

  assert.equal(response.status, 400, JSON.stringify(body));
  assertErrorShape(
    body,
    "PREVIEW_ONLY",
    "Worker routine commits are not supported; save reviewed previews from Flutter",
    400
  );
  assert.equal(body.previewOnly, true);
  assert.equal(state.geminiCalls, 0);
});

test("rejects forbidden Firebase Storage image URLs before Gemini call", async () => {
  const state = mockFetchState({ templates: [skinCareTemplate()] });
  globalThis.fetch = createMockFetch(state);

  const response = await callWorker({
    mode: "skin_care_photo",
    routineType: "skin_care",
    imageMetadata: {
      url: "https://firebasestorage.googleapis.com/v0/b/optivus/o/photo.jpg"
    }
  });
  const body = await response.json();

  assert.equal(response.status, 422, JSON.stringify(body));
  assertErrorShape(
    body,
    "IMAGE_REJECTED",
    "We could not read that photo. Try a clearer image with product labels visible.",
    422
  );
  assert.equal(state.geminiCalls, 0);
});

test("rejects forbidden GCS direct image URLs before Gemini call", async () => {
  const state = mockFetchState({ templates: [skinCareTemplate()] });
  globalThis.fetch = createMockFetch(state);

  const response = await callWorker({
    mode: "eating_mess_photo",
    routineType: "eating",
    imageMetadata: {
      url: "https://storage.googleapis.com/optivus-bucket/photo.jpg"
    }
  });
  const body = await response.json();

  assert.equal(response.status, 422, JSON.stringify(body));
  assertErrorShape(
    body,
    "IMAGE_REJECTED",
    "We could not read that photo. Try a clearer image with product labels visible.",
    422
  );
  assert.equal(state.geminiCalls, 0);
});

test("rejects firebasestorage.app image URLs before Gemini call", async () => {
  const state = mockFetchState({ templates: [eatingTemplate()] });
  globalThis.fetch = createMockFetch(state);

  const response = await callWorker({
    mode: "eating_mess_photo",
    routineType: "eating",
    imageMetadata: {
      url: "https://optivus.firebasestorage.app/o/photo.jpg"
    }
  });
  const body = await response.json();

  assert.equal(response.status, 422, JSON.stringify(body));
  assertErrorShape(
    body,
    "IMAGE_REJECTED",
    "We could not read that photo. Try a clearer image with product labels visible.",
    422
  );
  assert.equal(state.geminiCalls, 0);
});

test("accepts R2 image metadata with ocrText for photo modes", async () => {
  const state = mockFetchState({ templates: [skinCareTemplate()] });
  globalThis.fetch = createMockFetch(state);

  const response = await callWorker({
    mode: "skin_care_photo",
    routineType: "skin_care",
    imageMetadata: {
      objectKey: "users/test_uid/uploads/skin_care/12345.jpg",
      path: "users/test_uid/uploads/skin_care/12345.jpg",
      contentType: "image/jpeg",
      sizeBytes: 45000,
      provider: "cloudflare_r2",
      ocrText: "cleanser serum moisturiser"
    }
  });
  const body = await response.json();

  assert.equal(response.status, 200, JSON.stringify(body));
  assert.equal(body.ok, true);
  assert.equal(body.mode, "skin_care_photo");
  assert.equal(body.templates.length, 1);
  assert.equal(state.geminiCalls, 1);
});

test("rejects Firebase Storage URLs for class_timetable_photo before Gemini call", async () => {
  const state = mockFetchState({ templates: [classTemplate()] });
  globalThis.fetch = createMockFetch(state);

  const response = await callWorker({
    mode: "class_timetable_photo",
    routineType: "classes",
    imageMetadata: {
      url: "https://firebasestorage.googleapis.com/v0/b/optivus/o/timetable.jpg"
    }
  });
  const body = await response.json();

  assert.equal(response.status, 422, JSON.stringify(body));
  assertErrorShape(
    body,
    "IMAGE_REJECTED",
    "We could not read that photo. Try a clearer image with product labels visible.",
    422
  );
  assert.equal(state.geminiCalls, 0);
});

test("rejects Firebase Storage URLs for eating_mess_photo before Gemini call", async () => {
  const state = mockFetchState({ templates: [eatingTemplate()] });
  globalThis.fetch = createMockFetch(state);

  const response = await callWorker({
    mode: "eating_mess_photo",
    routineType: "eating",
    imageMetadata: {
      url: "https://firebasestorage.googleapis.com/v0/b/optivus/o/mess_menu.jpg"
    }
  });
  const body = await response.json();

  assert.equal(response.status, 422, JSON.stringify(body));
  assertErrorShape(
    body,
    "IMAGE_REJECTED",
    "We could not read that photo. Try a clearer image with product labels visible.",
    422
  );
  assert.equal(state.geminiCalls, 0);
});

test("rejects GCS direct URLs for eating_mess_photo before Gemini call", async () => {
  const state = mockFetchState({ templates: [eatingTemplate()] });
  globalThis.fetch = createMockFetch(state);

  const response = await callWorker({
    mode: "eating_mess_photo",
    routineType: "eating",
    imageMetadata: {
      url: "https://storage.googleapis.com/optivus-bucket/mess_menu.jpg"
    }
  });
  const body = await response.json();

  assert.equal(response.status, 422, JSON.stringify(body));
  assertErrorShape(
    body,
    "IMAGE_REJECTED",
    "We could not read that photo. Try a clearer image with product labels visible.",
    422
  );
  assert.equal(state.geminiCalls, 0);
});

async function callWorker(body) {
  const token = await firebaseToken();
  return worker.fetch(
    new Request("https://routine-import.test", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${token}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ userId: uid, ...body })
    }),
    env()
  );
}

async function firebaseToken() {
  return new SignJWT({ sub: uid, user_id: uid })
    .setProtectedHeader({ alg: "RS256", kid: "test-key" })
    .setIssuer(`https://securetoken.google.com/${projectId}`)
    .setAudience(projectId)
    .setIssuedAt()
    .setExpirationTime("5m")
    .sign(authPrivateKey);
}

function env() {
  return {
    GEMINI_API_KEY: "test-gemini-key",
    FIREBASE_PROJECT_ID: projectId,
    FIREBASE_CLIENT_EMAIL: "worker@test.iam.gserviceaccount.com",
    FIREBASE_PRIVATE_KEY: servicePrivateKeyPem,
    ROUTINE_IMPORT_TEST_JWKS_JSON: JSON.stringify({ keys: [authJwk] }),
    FREE_AI_IMPORT_MONTHLY_LIMIT: "20"
  };
}

function mockFetchState(aiPayload, options = {}) {
  return {
    aiPayload,
    profileData: options.profileData ?? {
      subscription: {
        plan: "free"
      },
      sensitiveContext: {
        eatingDisorderHistory: false
      }
    },
    usageAiCalls: options.usageAiCalls ?? 0,
    geminiCalls: 0,
    usageCommits: 0,
    suggestionCommits: 0
  };
}

function createMockFetch(state) {
  return async (input, init = {}) => {
    const url = typeof input === "string" ? input : input.url;
    const method = init.method || "GET";

    if (url.includes("securetoken@system.gserviceaccount.com")) {
      return jsonResponse({ keys: [authJwk] });
    }

    if (url === "https://oauth2.googleapis.com/token") {
      return jsonResponse({ access_token: "firestore-access-token" });
    }

    if (url.includes("generativelanguage.googleapis.com")) {
      state.geminiCalls += 1;
      const text = typeof state.aiPayload === "string"
        ? state.aiPayload
        : JSON.stringify(state.aiPayload);
      return jsonResponse({
        candidates: [
          {
            content: {
              parts: [{ text }]
            }
          }
        ]
      });
    }

    if (method === "GET" && url.includes("/profile/main")) {
      return jsonResponse(firestoreDoc(state.profileData));
    }

    if (method === "GET" && url.includes("/usage/")) {
      if (state.usageAiCalls === 0) {
        return jsonResponse({ error: { status: "NOT_FOUND" } }, 404);
      }
      return jsonResponse(firestoreDoc({ aiCalls: state.usageAiCalls }, "2026-05-08T00:00:00.000Z"));
    }

    if (method === "POST" && url.endsWith("/documents:commit")) {
      const body = JSON.parse(init.body);
      const firstName = body.writes?.[0]?.update?.name || "";
      if (firstName.includes("/usage/")) {
        state.usageCommits += 1;
      }
      if (firstName.includes("/suggestions/")) {
        state.suggestionCommits += 1;
      }
      return jsonResponse({ writeResults: [{}], commitTime: "2026-05-08T00:00:00.000Z" });
    }

    return jsonResponse({ error: { status: "NOT_FOUND", url } }, 404);
  };
}

function firestoreDoc(data, updateTime = "2026-05-08T00:00:00.000Z") {
  return {
    name: "mock-doc",
    fields: toFirestoreFields(data),
    createTime: updateTime,
    updateTime
  };
}

function toFirestoreFields(data) {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, toFirestoreValue(value)])
  );
}

function toFirestoreValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(toFirestoreValue) } };
  }
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (typeof value === "object") {
    return { mapValue: { fields: toFirestoreFields(value) } };
  }
  return { stringValue: String(value) };
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

function skinCareTemplate() {
  return {
    templateId: "skin_morning",
    title: "Morning skin care",
    startTime: "07:30",
    endTime: "07:45",
    repeatRule: "daily",
    notes: "",
    reminderEnabled: false,
    steps: [{ name: "Cleanser" }]
  };
}

function supplementTemplate() {
  return {
    templateId: "vitamin_d",
    title: "Vitamin D",
    dosage: "1000 IU",
    startTime: "08:00",
    endTime: "08:05",
    repeatRule: "daily",
    notes: "",
    reminderEnabled: false
  };
}

function classTemplate() {
  return {
    templateId: "physics",
    title: "Physics",
    weekday: 1,
    startTime: "09:00",
    endTime: "10:00",
    repeatRule: "weekly",
    room: "A-101",
    professor: "Dr Rao",
    notes: "",
    reminderEnabled: false
  };
}

function eatingTemplate() {
  return {
    templateId: "breakfast",
    title: "Breakfast",
    weekday: 1,
    mealType: "Breakfast",
    items: ["Poha"],
    startTime: "08:00",
    endTime: "08:30",
    repeatRule: "daily",
    notes: "",
    reminderEnabled: false
  };
}
