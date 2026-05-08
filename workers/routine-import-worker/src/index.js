import { SignJWT, createRemoteJWKSet, importPKCS8, jwtVerify } from "jose";

const firebaseJwks = createRemoteJWKSet(
  new URL("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com")
);

const allowedRoutineTypes = new Set([
  "skin_care",
  "supplements",
  "classes",
  "eating"
]);

const firestoreScope = "https://www.googleapis.com/auth/datastore";

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

    const routineType = String(body.routineType || "").trim();
    const mode = String(body.mode || "").trim();
    const sourceText = String(body.sourceText || "").trim();
    const imageMetadata = body.imageMetadata && typeof body.imageMetadata === "object"
      ? body.imageMetadata
      : null;
    const providedTemplates = Array.isArray(body.templates)
      ? body.templates
      : Array.isArray(body.items)
        ? body.items
        : Array.isArray(body.blocks)
          ? body.blocks
          : null;
    const commit = body.commit === true;

    if (!allowedRoutineTypes.has(routineType)) {
      return json({ error: "Unsupported routineType" }, 400, corsHeaders);
    }

    if (!mode) {
      return json({ error: "mode is required" }, 400, corsHeaders);
    }

    if (!sourceText && !imageMetadata && !(commit && providedTemplates)) {
      return json({ error: "Provide sourceText or imageMetadata" }, 400, corsHeaders);
    }

    if (commit) {
      const missingSecrets = requiredCommitSecrets(env);
      if (missingSecrets.length > 0) {
        return json(
          {
            error: "Server missing Firestore service-account secrets",
            missingSecrets
          },
          500,
          corsHeaders
        );
      }

      try {
        const templates = providedTemplates
          ? normalizeTemplates(providedTemplates, routineType)
          : await importRoutineTemplates({
            env,
            uid,
            routineType,
            mode,
            sourceText,
            imageMetadata
          });

        if (templates.length === 0) {
          return json({ error: "No routine templates to commit" }, 400, corsHeaders);
        }

        const commitTemplates = normalizeTemplatesForFirestore(templates);
        const result = await commitRoutineImport({
          env,
          uid,
          routineType,
          mode,
          sourceText,
          imageMetadata,
          templates: commitTemplates
        });

        return json(
          {
            ...result,
            templates: commitTemplates,
            items: commitTemplates,
            blocks: commitTemplates,
            commit: true,
            source: "gemini",
            userId: uid
          },
          200,
          corsHeaders
        );
      } catch (error) {
        return json(
          {
            error: "Routine import commit failed",
            details: String(error)
          },
          502,
          corsHeaders
        );
      }
    }

    try {
      const templates = await importRoutineTemplates({
        env,
        uid,
        routineType,
        mode,
        sourceText,
        imageMetadata
      });

      return json(
        {
          templates,
          items: templates,
          blocks: templates,
          commit: false,
          source: "gemini",
          userId: uid
        },
        200,
        corsHeaders
      );
    } catch (error) {
      return json(
        {
          error: "Routine import failed",
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

async function importRoutineTemplates({ env, uid, routineType, mode, sourceText, imageMetadata }) {
  const prompt = buildRoutineImportPrompt({
    routineType,
    mode,
    sourceText,
    imageMetadata
  });

  const data = await callGemini({
    env,
    prompt,
    maxOutputTokens: 900,
    temperature: 0.2
  });

  const text = extractGeminiText(data).trim();
  const parsed = parseJsonObject(text);
  const templates = Array.isArray(parsed.templates)
    ? parsed.templates
    : Array.isArray(parsed.items)
      ? parsed.items
      : Array.isArray(parsed.blocks)
        ? parsed.blocks
        : [];

  const normalized = normalizeTemplates(templates, routineType);

  console.log(
    `[routineImport] preview generated uid=${uid} routineType=${routineType} mode=${mode} count=${normalized.length}`
  );

  return normalized;
}

function normalizeTemplates(templates, routineType) {
  return templates
    .filter((item) => item && typeof item === "object" && !Array.isArray(item))
    .map((item, index) => normalizeTemplate(item, routineType, index))
    .filter((item) => item.title);
}

function normalizeTemplatesForFirestore(templates) {
  return templates.map((template) => ({
    ...template,
    startTime: normalizeRoutineTime(template.startTime, "09:00"),
    endTime: normalizeRoutineTime(template.endTime, "09:30")
  }));
}

function requiredCommitSecrets(env) {
  return [
    "FIREBASE_CLIENT_EMAIL",
    "FIREBASE_PRIVATE_KEY"
  ].filter((name) => !env[name]);
}

async function commitRoutineImport({
  env,
  uid,
  routineType,
  mode,
  sourceText,
  imageMetadata,
  templates
}) {
  const importId = await deterministicImportId({
    uid,
    routineType,
    mode,
    sourceText,
    imageMetadata,
    templates
  });
  const accessToken = await getServiceAccountAccessToken(env);
  const existing = await getRoutineDocument({
    projectId: env.FIREBASE_PROJECT_ID,
    uid,
    accessToken
  });
  const existingImportId = existing?.imports?.[routineType]?.importId || "";

  if (existingImportId === importId) {
    return {
      ok: true,
      deduped: true,
      importId,
      routineType,
      templatesCommitted: templates.length,
      firestorePath: `/users/${uid}/routine/current`
    };
  }

  const importMetadata = {
    importId,
    mode,
    routineType,
    sourceText,
    imageMetadata: imageMetadata || null,
    templatesCommitted: templates.length,
    committedAt: new Date().toISOString(),
    source: "routine-import-worker",
    schemaVersion: 1
  };

  await writeRoutineImport({
    projectId: env.FIREBASE_PROJECT_ID,
    uid,
    routineType,
    templates,
    importMetadata,
    accessToken
  });

  console.log(
    `[routineImport] committed uid=${uid} routineType=${routineType} importId=${importId} count=${templates.length}`
  );

  return {
    ok: true,
    deduped: false,
    importId,
    routineType,
    templatesCommitted: templates.length,
    firestorePath: `/users/${uid}/routine/current`
  };
}

async function getServiceAccountAccessToken(env) {
  const now = Math.floor(Date.now() / 1000);
  const privateKey = normalizePrivateKey(env.FIREBASE_PRIVATE_KEY);
  const key = await importPKCS8(privateKey, "RS256");
  const assertion = await new SignJWT({ scope: firestoreScope })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(env.FIREBASE_CLIENT_EMAIL)
    .setSubject(env.FIREBASE_CLIENT_EMAIL)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded"
    },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion
    }).toString()
  });

  const data = await response.json();
  if (!response.ok || !data.access_token) {
    throw new Error(`OAuth token request failed: ${JSON.stringify(data)}`);
  }

  return data.access_token;
}

function normalizePrivateKey(value) {
  return String(value || "").replace(/\\n/g, "\n");
}

async function getRoutineDocument({ projectId, uid, accessToken }) {
  const response = await fetch(firestoreDocumentUrl(projectId, uid), {
    method: "GET",
    headers: {
      "Authorization": `Bearer ${accessToken}`
    }
  });

  if (response.status === 404) {
    return null;
  }

  const data = await response.json();
  if (!response.ok) {
    throw new Error(`Firestore routine read failed: ${JSON.stringify(data)}`);
  }

  return firestoreDocumentToJs(data);
}

async function writeRoutineImport({
  projectId,
  uid,
  routineType,
  templates,
  importMetadata,
  accessToken
}) {
  const documentName = firestoreDocumentName(projectId, uid);
  const setupFlag = setupFlagFor(routineType);
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/databases/(default)/documents:commit`,
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        writes: [
          {
            update: {
              name: documentName,
              fields: {
                templates: toFirestoreValue({
                  [routineType]: templates
                }),
                imports: toFirestoreValue({
                  [routineType]: importMetadata
                }),
                [setupFlag]: toFirestoreValue(templates.length > 0)
              }
            },
            updateMask: {
              fieldPaths: [
                `templates.${routineType}`,
                `imports.${routineType}`,
                setupFlag
              ]
            },
            updateTransforms: [
              {
                fieldPath: "updatedAt",
                setToServerValue: "REQUEST_TIME"
              }
            ]
          }
        ]
      })
    }
  );

  const data = await response.json();
  if (!response.ok) {
    throw new Error(`Firestore routine commit failed: ${JSON.stringify(data)}`);
  }

  return data;
}

function firestoreDocumentUrl(projectId, uid) {
  return `https://firestore.googleapis.com/v1/${firestoreDocumentName(projectId, uid)}`;
}

function firestoreDocumentName(projectId, uid) {
  return `projects/${encodeURIComponent(projectId)}/databases/(default)/documents/users/${encodeURIComponent(uid)}/routine/current`;
}

function setupFlagFor(routineType) {
  switch (routineType) {
    case "fixed_schedule":
      return "fixedScheduleSetUp";
    case "skin_care":
      return "skinCareSetUp";
    case "classes":
      return "classesSetUp";
    case "eating":
      return "eatingSetUp";
    case "supplements":
      return "supplementsSetUp";
    default:
      return `${routineType.replace(/_/g, "")}TemplatesSetUp`;
  }
}

async function deterministicImportId({
  uid,
  routineType,
  mode,
  sourceText,
  imageMetadata,
  templates
}) {
  const input = stableJson({
    uid,
    routineType,
    mode,
    sourceText,
    imageMetadata: imageMetadata || null,
    templates
  });
  const hash = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(input)
  );
  return `routine_import_${hex(hash).slice(0, 32)}`;
}

function stableJson(value) {
  return JSON.stringify(sortForStableJson(value));
}

function sortForStableJson(value) {
  if (Array.isArray(value)) {
    return value.map(sortForStableJson);
  }

  if (value && typeof value === "object") {
    return Object.keys(value)
      .sort()
      .reduce((acc, key) => {
        acc[key] = sortForStableJson(value[key]);
        return acc;
      }, {});
  }

  return value;
}

function hex(buffer) {
  return [...new Uint8Array(buffer)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function toFirestoreValue(value) {
  if (value === null || value === undefined) {
    return { nullValue: null };
  }

  if (Array.isArray(value)) {
    return {
      arrayValue: {
        values: value.map(toFirestoreValue)
      }
    };
  }

  if (typeof value === "boolean") {
    return { booleanValue: value };
  }

  if (typeof value === "number") {
    if (Number.isInteger(value)) {
      return { integerValue: String(value) };
    }
    return { doubleValue: value };
  }

  if (typeof value === "object") {
    return {
      mapValue: {
        fields: Object.fromEntries(
          Object.entries(value).map(([key, item]) => [key, toFirestoreValue(item)])
        )
      }
    };
  }

  return { stringValue: String(value) };
}

function firestoreDocumentToJs(document) {
  return Object.fromEntries(
    Object.entries(document.fields || {}).map(([key, value]) => [
      key,
      firestoreValueToJs(value)
    ])
  );
}

function firestoreValueToJs(value) {
  if ("nullValue" in value) return null;
  if ("booleanValue" in value) return value.booleanValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return Number(value.doubleValue);
  if ("timestampValue" in value) return value.timestampValue;
  if ("stringValue" in value) return value.stringValue;
  if ("arrayValue" in value) {
    return (value.arrayValue.values || []).map(firestoreValueToJs);
  }
  if ("mapValue" in value) {
    return Object.fromEntries(
      Object.entries(value.mapValue.fields || {}).map(([key, item]) => [
        key,
        firestoreValueToJs(item)
      ])
    );
  }
  return undefined;
}

function buildRoutineImportPrompt({ routineType, mode, sourceText, imageMetadata }) {
  return `You are the Optivus routine import parser.
Convert the user input into editable routine template previews.

Routine type: ${routineType}
Mode: ${mode}
Source text:
${sourceText || "(none)"}

Image metadata:
${JSON.stringify(imageMetadata || {})}

Return only valid JSON. No markdown.
Shape:
{
  "templates": [
    {
      "templateId": "stable_short_id",
      "title": "Name",
      "startTime": "8:00 AM",
      "endTime": "8:30 AM",
      "repeatRule": "daily",
      "notes": "",
      "reminderEnabled": false
    }
  ]
}

Additional fields by routine type:
- skin_care: include "steps": [{"name":"Cleanser"}]
- supplements: include "dosage"
- classes: include "room" and "professor" when available
- eating: include "mealType" such as Breakfast, Lunch, Snack, or Dinner

Use realistic times when the source does not specify them. Keep titles concise.`;
}

function normalizeTemplate(item, routineType, index) {
  const title = String(item.title || item.name || "").trim();
  const template = {
    ...item,
    templateId: String(item.templateId || `${routineType}_${index}_${slug(title || "template")}`),
    title,
    startTime: String(item.startTime || defaultStartTime(routineType, index)),
    endTime: String(item.endTime || defaultEndTime(routineType, index)),
    repeatRule: String(item.repeatRule || "daily"),
    notes: String(item.notes || ""),
    reminderEnabled: item.reminderEnabled === true
  };

  if (routineType === "skin_care" && !Array.isArray(template.steps)) {
    template.steps = template.notes
      ? template.notes.split(/,|\n/).map((name) => ({ name: name.trim() })).filter((step) => step.name)
      : [{ name: title }];
  }

  if (routineType === "supplements") {
    template.dosage = String(item.dosage || "");
  }

  if (routineType === "classes") {
    template.room = String(item.room || "");
    template.professor = String(item.professor || "");
  }

  if (routineType === "eating") {
    template.mealType = String(item.mealType || inferMealType(index));
  }

  return template;
}

function normalizeRoutineTime(value, fallback) {
  const raw = String(value || "").trim();
  const amPm = raw.match(/^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$/);
  if (amPm) {
    let hour = Number(amPm[1]);
    const minute = Number(amPm[2]);
    const suffix = amPm[3].toUpperCase();
    if (suffix === "PM" && hour !== 12) hour += 12;
    if (suffix === "AM" && hour === 12) hour = 0;
    return validTime(hour, minute) ? formatTime(hour, minute) : fallback;
  }

  const hhmm = raw.match(/^(\d{1,2}):(\d{2})$/);
  if (hhmm) {
    const hour = Number(hhmm[1]);
    const minute = Number(hhmm[2]);
    return validTime(hour, minute) ? formatTime(hour, minute) : fallback;
  }

  return fallback;
}

function validTime(hour, minute) {
  return Number.isInteger(hour)
    && Number.isInteger(minute)
    && hour >= 0
    && hour <= 23
    && minute >= 0
    && minute <= 59;
}

function formatTime(hour, minute) {
  return `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`;
}

function slug(value) {
  const clean = String(value || "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
  return clean || "template";
}

function defaultStartTime(routineType, index) {
  if (routineType === "classes") return `${9 + index}:00 AM`;
  if (routineType === "eating") return ["8:00 AM", "12:30 PM", "5:00 PM", "8:00 PM"][index] || "8:00 PM";
  if (routineType === "skin_care") return index === 0 ? "7:30 AM" : "9:30 PM";
  return "8:00 AM";
}

function defaultEndTime(routineType, index) {
  if (routineType === "classes") return `${10 + index}:00 AM`;
  if (routineType === "eating") return ["8:30 AM", "1:00 PM", "5:30 PM", "8:30 PM"][index] || "8:30 PM";
  if (routineType === "skin_care") return index === 0 ? "8:00 AM" : "10:00 PM";
  return "8:15 AM";
}

function inferMealType(index) {
  return ["Breakfast", "Lunch", "Snack", "Dinner"][index] || "Meal";
}

async function callGemini({ env, prompt, maxOutputTokens, temperature }) {
  const model = env.GEMINI_MODEL || "gemini-1.5-flash";
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
        temperature,
        maxOutputTokens,
        responseMimeType: "application/json"
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

function parseJsonObject(text) {
  try {
    return JSON.parse(text);
  } catch (_) {
    const start = text.indexOf("{");
    const end = text.lastIndexOf("}");
    if (start >= 0 && end > start) {
      return JSON.parse(text.slice(start, end + 1));
    }
    throw new Error("Gemini returned non-JSON routine import output");
  }
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
