import { SignJWT, createLocalJWKSet, createRemoteJWKSet, importPKCS8, jwtVerify } from "jose";

const firebaseJwks = createRemoteJWKSet(
  new URL("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com")
);

const firestoreScope = "https://www.googleapis.com/auth/datastore";
const maxItemsPerMode = 12;

const modeContracts = {
  skin_care_text: {
    routineType: "skin_care",
    outputKey: "templates",
    input: "text",
    title: "skin care routine from text"
  },
  skin_care_photo: {
    routineType: "skin_care",
    outputKey: "templates",
    input: "photo",
    title: "skin care routine from product photo"
  },
  supplement_text: {
    routineType: "supplements",
    outputKey: "templates",
    input: "text",
    title: "supplement routine from text"
  },
  class_timetable_photo: {
    routineType: "classes",
    outputKey: "templates",
    input: "photo",
    title: "class timetable from photo"
  },
  eating_mess_photo: {
    routineType: "eating",
    outputKey: "templates",
    input: "photo",
    title: "mess menu from photo"
  },
  eating_goal_text: {
    routineType: "eating",
    outputKey: "templates",
    input: "text",
    title: "eating routine from goal text"
  },
  routine_goal_suggestions: {
    routineType: "routine",
    outputKey: "suggestions",
    input: "text",
    title: "routine goal suggestions"
  }
};

const modeAliases = {
  "skin_care:text_ai": "skin_care_text",
  "skin_care:photo_ai": "skin_care_photo",
  "skin_care:text": "skin_care_text",
  "skin_care:photo": "skin_care_photo",
  "supplements:text_ai": "supplement_text",
  "supplements:text": "supplement_text",
  "classes:timetable_image": "class_timetable_photo",
  "classes:photo_ai": "class_timetable_photo",
  "classes:photo": "class_timetable_photo",
  "eating:photo_ai": "eating_mess_photo",
  "eating:mess_photo": "eating_mess_photo",
  "eating:photo": "eating_mess_photo",
  "eating:text_ai": "eating_goal_text",
  "eating:text": "eating_goal_text",
  "routine:suggestions": "routine_goal_suggestions",
  "routine:goal_suggestions": "routine_goal_suggestions"
};

class UsageCapError extends Error {
  constructor(message, usage) {
    super(message);
    this.name = "UsageCapError";
    this.usage = usage;
  }
}

class AiOutputValidationError extends Error {
  constructor(message) {
    super(message);
    this.name = "AiOutputValidationError";
  }
}

class BadImageError extends Error {
  constructor(message) {
    super(message);
    this.name = "BadImageError";
  }
}

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

    const missingEnv = requiredEnv(env);
    if (missingEnv.length > 0) {
      return json(
        {
          error: "Server missing routine import configuration",
          missingEnv
        },
        500,
        corsHeaders
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
      return json({ error: "Invalid JSON body" }, 400, corsHeaders);
    }

    const uid = authResult.decodedToken.sub;
    const userIdFromBody = stringField(body.userId);
    if (userIdFromBody && userIdFromBody !== uid) {
      return json({ error: "userId does not match Firebase token" }, 403, corsHeaders);
    }

    if (body.commit === true) {
      return json(
        { error: "Worker routine commits are not supported; save reviewed previews from Flutter" },
        400,
        corsHeaders
      );
    }

    const modeResult = resolveMode(body);
    if (!modeResult.ok) {
      return json({ error: modeResult.error }, 400, corsHeaders);
    }

    const mode = modeResult.mode;
    const contract = modeContracts[mode];
    const sourceText = stringField(body.sourceText || body.text || body.prompt);
    const imageMetadata = objectField(body.imageMetadata);
    const context = objectField(body.context) || objectField(body.contextPayload) || {};

    const inputError = validateInput(contract, sourceText, imageMetadata, context);
    if (inputError) {
      return json({ error: inputError }, 400, corsHeaders);
    }

    let accessToken;
    try {
      accessToken = await getServiceAccountAccessToken(env);
    } catch (error) {
      return json(
        {
          error: "Firestore service-account authentication failed",
          details: String(error)
        },
        500,
        corsHeaders
      );
    }

    try {
      const profile = await getUserProfile({
        projectId: env.FIREBASE_PROJECT_ID,
        uid,
        accessToken
      });
      const safetyFlags = extractSafetyFlags(profile);
      const usage = await reserveUsageCall({
        env,
        uid,
        mode,
        accessToken,
        profile
      });
      const preview = await generatePreview({
        env,
        uid,
        mode,
        contract,
        sourceText,
        imageMetadata,
        context,
        safetyFlags
      });
      const safePreview = applySafetyPolicy(preview, contract, safetyFlags);
      const suggestions = await writeSuggestionGeneratedEvents({
        projectId: env.FIREBASE_PROJECT_ID,
        uid,
        mode,
        contract,
        sourceText,
        imageMetadata,
        preview: safePreview,
        accessToken
      });

      const output = {
        mode,
        routineType: contract.routineType,
        commit: false,
        source: "gemini",
        userId: uid,
        usage,
        safetyFlags: publicSafetyFlags(safetyFlags),
        suggestionIds: suggestions.map((item) => item.suggestionId)
      };

      if (contract.outputKey === "suggestions") {
        output.suggestions = safePreview;
        output.items = safePreview;
      } else {
        output.templates = safePreview;
        output.items = safePreview;
        output.blocks = safePreview;
      }

      return json(output, 200, corsHeaders);
    } catch (error) {
      if (error instanceof UsageCapError) {
        return json(
          {
            error: "AI usage cap reached",
            usage: error.usage
          },
          429,
          corsHeaders
        );
      }

      if (error instanceof AiOutputValidationError) {
        return json(
          {
            error: "Routine import AI output rejected",
            reason: "The model returned malformed or unsafe JSON for this mode"
          },
          502,
          corsHeaders
        );
      }

      if (error instanceof BadImageError) {
        return json(
          {
            error: "We could not read that photo. Try a clearer image with product labels visible."
          },
          422,
          corsHeaders
        );
      }

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

function requiredEnv(env) {
  return [
    "GEMINI_API_KEY",
    "FIREBASE_PROJECT_ID",
    "FIREBASE_CLIENT_EMAIL",
    "FIREBASE_PRIVATE_KEY"
  ].filter((name) => !env[name]);
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
      body: { error: "Missing Authorization Bearer token" }
    };
  }

  try {
    const decodedToken = await verifyFirebaseIdToken(token, env);
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

async function verifyFirebaseIdToken(idToken, env) {
  const projectId = env.FIREBASE_PROJECT_ID;
  const issuer = `https://securetoken.google.com/${projectId}`;
  const keySet = env.ROUTINE_IMPORT_TEST_JWKS_JSON
    ? createLocalJWKSet(JSON.parse(env.ROUTINE_IMPORT_TEST_JWKS_JSON))
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

function resolveMode(body) {
  const rawMode = stringField(body.mode);
  const routineType = stringField(body.routineType);

  if (modeContracts[rawMode]) {
    const expectedRoutineType = modeContracts[rawMode].routineType;
    if (routineType && expectedRoutineType !== "routine" && routineType !== expectedRoutineType) {
      return { ok: false, error: "routineType does not match mode" };
    }
    return { ok: true, mode: rawMode };
  }

  const alias = modeAliases[`${routineType}:${rawMode}`];
  if (alias) {
    return { ok: true, mode: alias };
  }

  return { ok: false, error: "Unsupported routine import mode" };
}

function validateInput(contract, sourceText, imageMetadata, context) {
  if (contract.input === "text" && !sourceText && Object.keys(context).length === 0) {
    return "Provide sourceText for this mode";
  }

  if (contract.input === "photo") {
    const hasImageUrl = !!stringField(imageMetadata?.downloadUrl || imageMetadata?.url);
    const hasTextHint = !!stringField(
      sourceText || imageMetadata?.ocrText || imageMetadata?.text || imageMetadata?.description
    );
    if (!imageMetadata && !sourceText) {
      return "Provide imageMetadata or extracted sourceText for this photo mode";
    }
    if (!hasImageUrl && !hasTextHint) {
      return "Provide an uploaded image URL or OCR text for this photo mode";
    }
  }

  return null;
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

async function getUserProfile({ projectId, uid, accessToken }) {
  const document = await getFirestoreDocument({
    projectId,
    path: `users/${uid}/profile/main`,
    accessToken
  });
  return document.exists ? document.data : {};
}

async function reserveUsageCall({ env, uid, mode, accessToken, profile }) {
  const monthKey = currentMonthKey();
  const limit = usageLimitFor(profile, env);
  const projectId = env.FIREBASE_PROJECT_ID;
  const documentPath = `users/${uid}/usage/${monthKey}`;

  for (let attempt = 0; attempt < 3; attempt += 1) {
    const usageDoc = await getFirestoreDocument({
      projectId,
      path: documentPath,
      accessToken
    });
    const aiCalls = usageDoc.exists ? safeNumber(usageDoc.data.aiCalls) : 0;
    const usage = {
      monthKey,
      aiCalls,
      limit,
      remaining: Math.max(0, limit - aiCalls)
    };

    if (aiCalls >= limit) {
      throw new UsageCapError("AI usage cap reached", usage);
    }

    const committed = await commitUsageIncrement({
      projectId,
      uid,
      monthKey,
      mode,
      accessToken,
      usageDoc
    });

    if (committed) {
      return {
        monthKey,
        aiCalls: aiCalls + 1,
        limit,
        remaining: Math.max(0, limit - aiCalls - 1)
      };
    }
  }

  throw new Error("Could not reserve AI usage after concurrent updates");
}

async function commitUsageIncrement({ projectId, uid, monthKey, mode, accessToken, usageDoc }) {
  const documentName = firestoreDocumentName(projectId, `users/${uid}/usage/${monthKey}`);
  const write = {
    update: {
      name: documentName,
      fields: {
        monthKey: toFirestoreValue(monthKey),
        source: toFirestoreValue("routine-import-worker"),
        lastAiMode: toFirestoreValue(mode),
        schemaVersion: toFirestoreValue(1)
      }
    },
    updateMask: {
      fieldPaths: ["monthKey", "source", "lastAiMode", "schemaVersion"]
    },
    updateTransforms: [
      {
        fieldPath: "aiCalls",
        increment: { integerValue: "1" }
      },
      {
        fieldPath: "lastAiCallAt",
        setToServerValue: "REQUEST_TIME"
      },
      {
        fieldPath: "updatedAt",
        setToServerValue: "REQUEST_TIME"
      }
    ]
  };

  if (usageDoc.exists) {
    write.currentDocument = { updateTime: usageDoc.updateTime };
  } else {
    write.currentDocument = { exists: false };
    write.updateTransforms.push({
      fieldPath: "createdAt",
      setToServerValue: "REQUEST_TIME"
    });
  }

  const response = await fetch(firestoreCommitUrl(projectId), {
    method: "POST",
    headers: firestoreHeaders(accessToken),
    body: JSON.stringify({ writes: [write] })
  });
  const data = await response.json();

  if (response.ok) {
    return true;
  }

  const status = data?.error?.status || "";
  if (status === "ABORTED" || status === "FAILED_PRECONDITION" || status === "ALREADY_EXISTS") {
    return false;
  }

  throw new Error(`Firestore usage write failed: ${JSON.stringify(data)}`);
}

function usageLimitFor(profile, env) {
  const subscription = objectField(profile.subscription) || {};
  const plan = stringField(subscription.plan || profile.plan || profile.subscriptionPlan).toLowerCase();
  const explicitLimit = safeNumber(subscription.aiImportMonthlyLimit ?? profile.aiImportMonthlyLimit);
  if (explicitLimit > 0) return explicitLimit;
  if (plan === "pro" || plan === "premium" || plan === "paid") {
    return safePositiveInteger(env.PRO_AI_IMPORT_MONTHLY_LIMIT, 100);
  }
  return safePositiveInteger(env.FREE_AI_IMPORT_MONTHLY_LIMIT, 20);
}

async function generatePreview({
  env,
  uid,
  mode,
  contract,
  sourceText,
  imageMetadata,
  context,
  safetyFlags
}) {
  const prompt = buildRoutineImportPrompt({
    uid,
    mode,
    contract,
    sourceText,
    imageMetadata,
    context,
    safetyFlags
  });
  const imagePart = contract.input === "photo"
    ? await imagePartFromMetadata(imageMetadata)
    : null;
  const data = await callGemini({
    env,
    prompt,
    imagePart,
    maxOutputTokens: contract.outputKey === "suggestions" ? 700 : 1000,
    temperature: 0.2
  });
  const text = extractGeminiText(data).trim();
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch (_) {
    throw new AiOutputValidationError("Gemini returned non-JSON output");
  }

  return validateAiOutput(parsed, mode, contract);
}

function validateAiOutput(parsed, mode, contract) {
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new AiOutputValidationError("AI output root must be an object");
  }

  if (contract.outputKey === "suggestions") {
    const rawSuggestions = Array.isArray(parsed.suggestions) ? parsed.suggestions : null;
    if (!rawSuggestions) {
      throw new AiOutputValidationError("Missing suggestions array");
    }

    const suggestions = rawSuggestions.slice(0, maxItemsPerMode).map((item, index) => {
      validateRawSuggestionForMode(item, index);
      const suggestion = normalizeSuggestion(item, index);
      return suggestion;
    });

    if (suggestions.length === 0) {
      throw new AiOutputValidationError("No valid suggestions returned");
    }

    return suggestions;
  }

  const rawTemplates = Array.isArray(parsed.templates)
    ? parsed.templates
    : Array.isArray(parsed.items)
      ? parsed.items
      : Array.isArray(parsed.blocks)
        ? parsed.blocks
        : null;

  if (!rawTemplates) {
    throw new AiOutputValidationError("Missing templates array");
  }

  const templates = rawTemplates.slice(0, maxItemsPerMode).map((item, index) => {
    validateRawTemplateForMode(item, mode, index);
    const template = normalizeTemplate(item, contract.routineType, index);
    validateTemplateForMode(template, mode, index);
    return template;
  });

  if (templates.length === 0 && contract.input === "photo") {
    throw new BadImageError("No templates returned for photo");
  }

  if (templates.length === 0) {
    throw new AiOutputValidationError("No valid templates returned");
  }

  return templates;
}

function validateRawTemplateForMode(item, mode, index) {
  if (!item || typeof item !== "object" || Array.isArray(item)) {
    throw new AiOutputValidationError(`Template at index ${index} must be an object`);
  }

  if (!stringField(item.title || item.name)) {
    throw new AiOutputValidationError(`Missing title at index ${index}`);
  }

  if (!isInputRoutineTime(item.startTime || item.time)) {
    throw new AiOutputValidationError(`Missing or invalid startTime at index ${index}`);
  }

  if (item.endTime !== undefined && !isInputRoutineTime(item.endTime)) {
    throw new AiOutputValidationError(`Missing or invalid endTime at index ${index}`);
  }

  if ((mode === "skin_care_text" || mode === "skin_care_photo") && !hasValidSteps(item.steps)) {
    throw new AiOutputValidationError(`Missing skin care steps at index ${index}`);
  }

  if (mode === "supplement_text" && !stringField(item.dosage || item.amount)) {
    throw new AiOutputValidationError(`Missing supplement dosage at index ${index}`);
  }

  if ((mode === "eating_mess_photo" || mode === "eating_goal_text")
    && !stringField(item.mealType || item.type)) {
    throw new AiOutputValidationError(`Missing eating mealType at index ${index}`);
  }
}

function validateRawSuggestionForMode(item, index) {
  if (!item || typeof item !== "object" || Array.isArray(item)) {
    throw new AiOutputValidationError(`Suggestion at index ${index} must be an object`);
  }

  if (!stringField(item.title || item.taskTitle)) {
    throw new AiOutputValidationError(`Missing suggestion title at index ${index}`);
  }

  if (!stringField(item.reason || item.rationale)) {
    throw new AiOutputValidationError(`Missing suggestion reason at index ${index}`);
  }

  if (!isInputRoutineTime(item.time || item.startTime)) {
    throw new AiOutputValidationError(`Missing or invalid suggestion time at index ${index}`);
  }

  const action = stringField(item.action).toLowerCase();
  if (!["add", "remove", "adjust"].includes(action)) {
    throw new AiOutputValidationError(`Invalid suggestion action at index ${index}`);
  }

  if (item.priorityScore !== undefined || item.priority !== undefined) {
    const priority = Number(item.priorityScore ?? item.priority);
    if (!Number.isFinite(priority) || priority < 0 || priority > 1) {
      throw new AiOutputValidationError(`Invalid suggestion priorityScore at index ${index}`);
    }
  }
}

function validateTemplateForMode(template, mode, index) {
  if (!template.title) {
    throw new AiOutputValidationError(`Missing title at index ${index}`);
  }
  if (!isRoutineTime(template.startTime) || !isRoutineTime(template.endTime)) {
    throw new AiOutputValidationError(`Invalid time at index ${index}`);
  }

  if ((mode === "skin_care_text" || mode === "skin_care_photo")
    && (!Array.isArray(template.steps) || template.steps.length === 0)) {
    throw new AiOutputValidationError(`Missing skin care steps at index ${index}`);
  }

  if (mode === "supplement_text" && !template.dosage) {
    throw new AiOutputValidationError(`Missing supplement dosage at index ${index}`);
  }

  if ((mode === "eating_mess_photo" || mode === "eating_goal_text") && !template.mealType) {
    throw new AiOutputValidationError(`Missing eating mealType at index ${index}`);
  }
}

function hasValidSteps(value) {
  return Array.isArray(value)
    && value.some((step) => {
      if (typeof step === "string") return stringField(step);
      if (step && typeof step === "object" && !Array.isArray(step)) {
        return stringField(step.name || step.title);
      }
      return false;
    });
}

function normalizeTemplate(item, routineType, index) {
  if (!item || typeof item !== "object" || Array.isArray(item)) {
    throw new AiOutputValidationError(`Template at index ${index} must be an object`);
  }

  const title = stringField(item.title || item.name);
  const startTime = normalizeRoutineTime(
    item.startTime || item.time || defaultStartTime(routineType, index),
    defaultStartTime(routineType, index)
  );
  const template = {
    templateId: stringField(item.templateId || item.id) || `${routineType}_${index}_${slug(title || "template")}`,
    title,
    time: startTime,
    startTime,
    endTime: normalizeRoutineTime(
      item.endTime || addMinutesToTime(startTime, routineType === "skin_care" ? 15 : 30),
      defaultEndTime(routineType, index)
    ),
    repeatRule: stringField(item.repeatRule || item.weekdayRule) || "daily",
    timingRule: stringField(item.timingRule) || timingRuleFor(startTime),
    weekdayRule: stringField(item.weekdayRule || item.repeatRule) || "daily",
    notes: stringField(item.notes || item.reason),
    confidence: clampNumber(item.confidence, 0, 1, 0.75),
    warnings: Array.isArray(item.warnings)
      ? item.warnings.map((warning) => stringField(warning)).filter(Boolean)
      : [],
    reminderEnabled: item.reminderEnabled === true
  };

  if (routineType === "skin_care") {
    const steps = Array.isArray(item.steps)
      ? item.steps
      : stringField(item.steps || item.notes).split(/,|\n/);
    template.steps = steps
      .map((step) => {
        if (typeof step === "string") return { name: step.trim() };
        if (step && typeof step === "object") {
          return {
            name: stringField(step.name || step.title),
            notes: stringField(step.notes)
          };
        }
        return null;
      })
      .filter((step) => step && step.name);
  }

  if (routineType === "supplements") {
    template.dosage = stringField(item.dosage || item.amount);
  }

  if (routineType === "classes") {
    template.room = stringField(item.room || item.location);
    template.professor = stringField(item.professor || item.teacher || item.instructor);
  }

  if (routineType === "eating") {
    template.mealType = stringField(item.mealType || item.type) || inferMealType(index);
  }

  return template;
}

function normalizeSuggestion(item, index) {
  if (!item || typeof item !== "object" || Array.isArray(item)) {
    throw new AiOutputValidationError(`Suggestion at index ${index} must be an object`);
  }

  const title = stringField(item.title || item.taskTitle);
  return {
    id: stringField(item.id || item.suggestionId) || `routine_suggestion_${index}_${slug(title || "suggestion")}`,
    title,
    reason: stringField(item.reason || item.rationale),
    emoji: stringField(item.emoji) || "spark",
    action: allowedAction(item.action),
    time: normalizeRoutineTime(item.time || item.startTime || "09:00", "09:00"),
    taskTitle: stringField(item.taskTitle || item.title),
    targetSurface: stringField(item.targetSurface) || "routine",
    priorityScore: clampNumber(item.priorityScore ?? item.priority, 0, 1, 0.5)
  };
}

function applySafetyPolicy(preview, contract, safetyFlags) {
  if (contract.routineType !== "eating" || !safetyFlags.eatingDisorderHistory) {
    return preview;
  }

  return preview.map((item) => {
    const safe = { ...item };
    for (const key of [
      "calories",
      "targetCalories",
      "calorieTarget",
      "macros",
      "proteinGrams",
      "carbGrams",
      "fatGrams",
      "weightGoal"
    ]) {
      delete safe[key];
    }
    safe.safetyAdjusted = true;
    safe.notes = removeUnsafeEatingLanguage(safe.notes);
    return safe;
  });
}

function removeUnsafeEatingLanguage(value) {
  return String(value || "")
    .replace(/\b\d+\s*k?cal(?:ories)?\b/gi, "")
    .replace(/\bweight\s*loss\b/gi, "wellbeing")
    .replace(/\bdiet\b/gi, "routine")
    .trim();
}

async function writeSuggestionGeneratedEvents({
  projectId,
  uid,
  mode,
  contract,
  sourceText,
  imageMetadata,
  preview,
  accessToken
}) {
  const suggestions = [];
  for (let index = 0; index < preview.length; index += 1) {
    const item = preview[index];
    const suggestionId = await deterministicId("suggestion", {
      uid,
      mode,
      index,
      item
    });
    const eventId = await deterministicId("event", {
      uid,
      eventName: "suggestion_generated",
      suggestionId
    });
    suggestions.push({
      suggestionId,
      eventId,
      uid,
      type: contract.outputKey === "suggestions" ? "routine_goal_suggestion" : "routine_import_preview",
      title: item.title || item.taskTitle,
      reason: item.reason || item.notes || `Generated ${contract.title}`,
      status: "pending",
      targetSurface: "routine",
      routineType: contract.routineType,
      mode,
      source: "routine-import-worker",
      eventName: "suggestion_generated",
      eventType: "suggestion_generated",
      preview: item,
      sourceText: sourceText ? sourceText.slice(0, 500) : "",
      imageMetadata: imageMetadata || null,
      schemaVersion: 1
    });
  }

  if (suggestions.length === 0) return [];

  const writes = suggestions.flatMap((suggestion) => {
    const event = {
      eventId: suggestion.eventId,
      eventName: "suggestion_generated",
      uid,
      source: "routine-import-worker",
      schemaVersion: 1,
      payloadVersion: 1,
      payload: {
        suggestionId: suggestion.suggestionId
      },
      deviceId: "server",
      appVersion: "worker"
    };

    return [
      {
        update: {
          name: firestoreDocumentName(projectId, `users/${uid}/suggestions/${suggestion.suggestionId}`),
          fields: toFirestoreValue(suggestion).mapValue.fields
        },
        updateTransforms: [
          {
            fieldPath: "createdAt",
            setToServerValue: "REQUEST_TIME"
          },
          {
            fieldPath: "updatedAt",
            setToServerValue: "REQUEST_TIME"
          }
        ]
      },
      eventWrite(projectId, uid, "events", event),
      eventWrite(projectId, uid, "events_recent", event)
    ];
  });

  const response = await fetch(firestoreCommitUrl(projectId), {
    method: "POST",
    headers: firestoreHeaders(accessToken),
    body: JSON.stringify({ writes })
  });
  const data = await response.json();
  if (!response.ok) {
    throw new Error(`Firestore suggestion write failed: ${JSON.stringify(data)}`);
  }

  return suggestions;
}

function eventWrite(projectId, uid, collectionId, event) {
  return {
    update: {
      name: firestoreDocumentName(projectId, `users/${uid}/${collectionId}/${event.eventId}`),
      fields: toFirestoreValue(event).mapValue.fields
    },
    updateTransforms: [
      {
        fieldPath: "timestamp",
        setToServerValue: "REQUEST_TIME"
      }
    ]
  };
}

async function getFirestoreDocument({ projectId, path, accessToken }) {
  const response = await fetch(firestoreDocumentUrl(projectId, path), {
    method: "GET",
    headers: {
      "Authorization": `Bearer ${accessToken}`
    }
  });

  if (response.status === 404) {
    return { exists: false, data: {}, updateTime: "" };
  }

  const data = await response.json();
  if (!response.ok) {
    throw new Error(`Firestore read failed: ${JSON.stringify(data)}`);
  }

  return {
    exists: true,
    data: firestoreDocumentToJs(data),
    updateTime: data.updateTime || ""
  };
}

function firestoreDocumentUrl(projectId, path) {
  return `https://firestore.googleapis.com/v1/${firestoreDocumentName(projectId, path)}`;
}

function firestoreDocumentName(projectId, path) {
  return `projects/${encodeURIComponent(projectId)}/databases/(default)/documents/${path
    .split("/")
    .map(encodeURIComponent)
    .join("/")}`;
}

function firestoreCommitUrl(projectId) {
  return `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/databases/(default)/documents:commit`;
}

function firestoreHeaders(accessToken) {
  return {
    "Authorization": `Bearer ${accessToken}`,
    "Content-Type": "application/json"
  };
}

function extractSafetyFlags(profile) {
  const sensitiveContext = objectField(profile.sensitiveContext) || {};
  const health = objectField(profile.health) || {};
  const eatingDisorderHistory = Boolean(
    profile.eatingDisorderFlag
    || profile.eatingDisorderHistory
    || sensitiveContext.eatingDisorderFlag
    || sensitiveContext.eatingDisorderHistory
    || health.eatingDisorderFlag
    || health.eatingDisorderHistory
  );

  return {
    eatingDisorderHistory
  };
}

function publicSafetyFlags(safetyFlags) {
  return {
    eatingDisorderHistory: safetyFlags.eatingDisorderHistory === true
  };
}

function buildRoutineImportPrompt({ uid, mode, contract, sourceText, imageMetadata, context, safetyFlags }) {
  return `You are the Optivus routine import parser.
Return only strict JSON. No markdown, comments, trailing commas, or prose.

User: ${uid}
Mode: ${mode}
Routine type: ${contract.routineType}
Task: Generate editable preview data for ${contract.title}.

Source text:
${sourceText || "(none)"}

Image metadata or OCR hints:
${JSON.stringify(imageMetadata || {})}

Context:
${JSON.stringify(context || {})}

Safety flags:
${JSON.stringify(publicSafetyFlags(safetyFlags))}

${schemaInstructionFor(mode)}

Rules:
- Use 24-hour HH:MM times.
- Keep titles concise.
- Do not invent medical claims.
- For skin care photos, identify visible product names from labels and place AM-safe products like cleanser, vitamin C, moisturizer, and SPF in morning timing; place retinoids, exfoliating acids, and night creams in evening timing unless the label clearly says otherwise.
- If a photo is unreadable or contains no skin care products, return {"templates":[]} instead of guessing.
- For eating modes, do not include calories, macros, weight-loss framing, or restrictive dieting language when eatingDisorderHistory is true.
- Return at least 1 and at most ${maxItemsPerMode} items unless an unreadable photo rule requires an empty templates array.`;
}

function schemaInstructionFor(mode) {
  switch (mode) {
    case "skin_care_text":
    case "skin_care_photo":
      return `JSON schema:
{"templates":[{"templateId":"stable_id","title":"Morning skin care","time":"07:30","startTime":"07:30","endTime":"07:45","timingRule":"morning","weekdayRule":"daily","repeatRule":"daily","steps":[{"name":"Cleanser","notes":""}],"notes":"","confidence":0.85,"warnings":[],"reminderEnabled":false}]}
For skin care text, split AM-safe products such as Vitamin C and SPF into a morning block, and PM products such as retinol into a night block when both are present. For skin care photos, use visible product names as step names and suggest morning/night timing from common label usage.`;
    case "supplement_text":
      return `JSON schema:
{"templates":[{"templateId":"stable_id","title":"Vitamin D","dosage":"1000 IU","startTime":"08:00","endTime":"08:05","repeatRule":"daily","notes":"","reminderEnabled":false}]}`;
    case "class_timetable_photo":
      return `JSON schema:
{"templates":[{"templateId":"stable_id","title":"Physics","startTime":"09:00","endTime":"10:00","repeatRule":"weekly","room":"A-101","professor":"Dr Rao","notes":"","reminderEnabled":false}]}`;
    case "eating_mess_photo":
    case "eating_goal_text":
      return `JSON schema:
{"templates":[{"templateId":"stable_id","title":"Breakfast","mealType":"Breakfast","startTime":"08:00","endTime":"08:30","repeatRule":"daily","notes":"","reminderEnabled":false}]}`;
    case "routine_goal_suggestions":
      return `JSON schema:
{"suggestions":[{"id":"stable_id","title":"Add morning planning","reason":"Supports the user's goal","emoji":"spark","action":"add","time":"09:00","taskTitle":"Morning planning","targetSurface":"routine","priorityScore":0.8}]}`;
    default:
      return "";
  }
}

async function callGemini({ env, prompt, imagePart, maxOutputTokens, temperature }) {
  const model = imagePart
    ? env.GEMINI_VISION_MODEL || env.GEMINI_MODEL || "gemini-2.5-flash"
    : env.GEMINI_MODEL || "gemini-2.5-flash";
  const geminiUrl =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${env.GEMINI_API_KEY}`;
  const parts = [{ text: prompt }];
  if (imagePart) parts.push(imagePart);

  const response = await fetch(geminiUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      contents: [
        {
          role: "user",
          parts
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

async function imagePartFromMetadata(imageMetadata) {
  const downloadUrl = stringField(imageMetadata?.downloadUrl || imageMetadata?.url);
  if (!downloadUrl) return null;

  let response;
  try {
    response = await fetch(downloadUrl);
  } catch (_) {
    throw new BadImageError("Image fetch failed");
  }

  if (!response.ok) {
    throw new BadImageError(`Image fetch failed with ${response.status}`);
  }

  const fallbackMime = stringField(imageMetadata?.mimeType) || "image/jpeg";
  const mimeType = normalizeImageMimeType(
    response.headers.get("content-type") || fallbackMime
  );
  if (!mimeType) {
    throw new BadImageError("Unsupported image content type");
  }

  const bytes = await response.arrayBuffer();
  if (bytes.byteLength === 0 || bytes.byteLength > 5 * 1000 * 1000) {
    throw new BadImageError("Invalid image size");
  }

  return {
    inline_data: {
      mime_type: mimeType,
      data: arrayBufferToBase64(bytes)
    }
  };
}

function normalizeImageMimeType(value) {
  const mimeType = stringField(value).split(";")[0].toLowerCase();
  if (["image/jpeg", "image/png", "image/webp"].includes(mimeType)) {
    return mimeType;
  }
  return "";
}

function arrayBufferToBase64(buffer) {
  let binary = "";
  const bytes = new Uint8Array(buffer);
  const chunkSize = 0x8000;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }
  return btoa(binary);
}

function extractGeminiText(data) {
  return data?.candidates?.[0]?.content?.parts
    ?.map((part) => part.text || "")
    .join("")
    || "";
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

async function deterministicId(prefix, value) {
  const input = stableJson(value);
  const hash = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(input)
  );
  return `${prefix}_${hex(hash).slice(0, 32)}`;
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

function currentMonthKey(date = new Date()) {
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, "0")}`;
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

function isRoutineTime(value) {
  return /^\d{2}:\d{2}$/.test(value) && normalizeRoutineTime(value, "") === value;
}

function isInputRoutineTime(value) {
  return normalizeRoutineTime(value, "") !== "";
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

function defaultStartTime(routineType, index) {
  if (routineType === "classes") return `${String(Math.min(9 + index, 20)).padStart(2, "0")}:00`;
  if (routineType === "eating") return ["08:00", "12:30", "17:00", "20:00"][index] || "20:00";
  if (routineType === "skin_care") return index === 0 ? "07:30" : "21:30";
  return "08:00";
}

function defaultEndTime(routineType, index) {
  if (routineType === "classes") return `${String(Math.min(10 + index, 21)).padStart(2, "0")}:00`;
  if (routineType === "eating") return ["08:30", "13:00", "17:30", "20:30"][index] || "20:30";
  if (routineType === "skin_care") return index === 0 ? "07:45" : "21:45";
  return "08:05";
}

function addMinutesToTime(time, minutes) {
  const normalized = normalizeRoutineTime(time, "");
  if (!normalized) return "";
  const [hour, minute] = normalized.split(":").map(Number);
  const total = (hour * 60 + minute + minutes) % (24 * 60);
  return formatTime(Math.floor(total / 60), total % 60);
}

function timingRuleFor(time) {
  const hour = Number(String(time || "07:30").split(":")[0]);
  if (hour < 12) return "morning";
  if (hour < 17) return "afternoon";
  return "night";
}

function inferMealType(index) {
  return ["Breakfast", "Lunch", "Snack", "Dinner"][index] || "Meal";
}

function allowedAction(value) {
  const action = stringField(value).toLowerCase();
  return ["add", "remove", "adjust"].includes(action) ? action : "add";
}

function slug(value) {
  const clean = String(value || "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
  return clean || "item";
}

function stringField(value) {
  return String(value || "").trim();
}

function objectField(value) {
  return value && typeof value === "object" && !Array.isArray(value) ? value : null;
}

function safeNumber(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : 0;
}

function safePositiveInteger(value, fallback) {
  const number = Number(value);
  return Number.isInteger(number) && number > 0 ? number : fallback;
}

function clampNumber(value, min, max, fallback) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.min(max, Math.max(min, number));
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
