import { createLocalJWKSet, createRemoteJWKSet, jwtVerify } from "jose";

const firebaseJwks = createRemoteJWKSet(
  new URL("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com")
);

const maxUploadBytes = 1_000_000;
const jpegContentType = "image/jpeg";
const maxUploadUrlTtlSeconds = 300;
const minUploadUrlTtlSeconds = 30;

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
    const route = routeFor(request.url);
    if (route === "signedUpload") {
      return handleSignedUpload({ body, env, uid, headers: corsHeaders });
    }
    if (route === "deleteUpload") {
      return handleDeleteUpload({ body, env, uid, headers: corsHeaders });
    }

    return errorResponse("NOT_FOUND", "R2 upload endpoint not found", 404, corsHeaders);
  }
};

async function handleSignedUpload({ body, env, uid, headers }) {
  const missingEnv = requiredSignedUploadEnv(env);
  if (missingEnv.length > 0) {
    return errorResponse(
      "CONFIG_MISSING",
      "Server missing R2 signed upload configuration",
      500,
      headers,
      { missingEnv }
    );
  }

  const contentType = stringField(body.contentType).toLowerCase();
  if (contentType !== jpegContentType) {
    return errorResponse("UNSUPPORTED_CONTENT_TYPE", "contentType must be image/jpeg", 400, headers);
  }

  const sizeBytes = numberField(body.sizeBytes);
  if (!Number.isInteger(sizeBytes) || sizeBytes <= 0) {
    return errorResponse("INVALID_SIZE", "sizeBytes must be a positive integer", 400, headers);
  }
  if (sizeBytes > maxUploadBytes) {
    return errorResponse("UPLOAD_TOO_LARGE", "sizeBytes must be less than or equal to 1000000", 400, headers);
  }

  const objectKey = stringField(body.objectKey);
  const keyResult = validateObjectKey(objectKey, uid);
  if (!keyResult.ok) {
    return errorResponse(keyResult.code, keyResult.message, keyResult.status, headers);
  }

  const expiresInSeconds = uploadUrlTtlSeconds(env);
  const uploadUrl = await createSignedPutUrl({
    env,
    objectKey,
    contentType,
    sizeBytes,
    expiresInSeconds
  });

  return json(
    {
      ok: true,
      uploadUrl,
      method: "PUT",
      objectKey,
      path: objectKey,
      contentType,
      sizeBytes,
      expiresInSeconds,
      provider: "cloudflare_r2",
      userId: uid,
      requiredHeaders: {
        "Content-Type": contentType,
        "Content-Length": String(sizeBytes)
      }
    },
    200,
    headers
  );
}

async function handleDeleteUpload({ body, env, uid, headers }) {
  if (!env.R2_BUCKET || typeof env.R2_BUCKET.delete !== "function") {
    return errorResponse(
      "CONFIG_MISSING",
      "Server missing R2 bucket binding",
      500,
      headers,
      { missingEnv: ["R2_BUCKET"] }
    );
  }

  const objectKey = stringField(body.objectKey || body.path);
  const keyResult = validateObjectKey(objectKey, uid);
  if (!keyResult.ok) {
    return errorResponse(keyResult.code, keyResult.message, keyResult.status, headers);
  }

  await env.R2_BUCKET.delete(objectKey);
  return json(
    {
      ok: true,
      deleted: true,
      objectKey,
      path: objectKey,
      provider: "cloudflare_r2",
      userId: uid
    },
    200,
    headers
  );
}

function routeFor(url) {
  const pathname = new URL(url).pathname.replace(/\/+$/, "") || "/";
  if (pathname === "/signed-upload" || pathname === "/upload" || pathname === "/upload-url") {
    return "signedUpload";
  }
  if (pathname === "/delete-upload" || pathname === "/delete") {
    return "deleteUpload";
  }
  return "notFound";
}

function requiredSignedUploadEnv(env) {
  return [
    "R2_ACCOUNT_ID",
    "R2_BUCKET_NAME",
    "R2_ACCESS_KEY_ID",
    "R2_SECRET_ACCESS_KEY"
  ].filter((name) => !stringField(env[name]));
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

  if (!stringField(env.FIREBASE_PROJECT_ID)) {
    return {
      ok: false,
      status: 500,
      body: errorBody("CONFIG_MISSING", "Server missing Firebase configuration", 500, {
        missingEnv: ["FIREBASE_PROJECT_ID"]
      })
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
  const keySet = env.R2_UPLOAD_TEST_JWKS_JSON
    ? createLocalJWKSet(JSON.parse(env.R2_UPLOAD_TEST_JWKS_JSON))
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

function validateObjectKey(objectKey, uid) {
  if (!objectKey) {
    return {
      ok: false,
      code: "INVALID_OBJECT_KEY",
      message: "objectKey is required",
      status: 400
    };
  }

  if (objectKey.length > 512 || objectKey.startsWith("/") || /[?#\0\\]/.test(objectKey)) {
    return {
      ok: false,
      code: "INVALID_OBJECT_KEY",
      message: "objectKey is not allowed",
      status: 400
    };
  }

  if (hasPathTraversal(objectKey)) {
    return {
      ok: false,
      code: "PATH_TRAVERSAL_REJECTED",
      message: "objectKey must not contain path traversal",
      status: 400
    };
  }

  if (!objectKey.startsWith(`users/${uid}/`)) {
    return {
      ok: false,
      code: "OBJECT_KEY_UID_MISMATCH",
      message: "objectKey must be under users/{verifiedUid}/",
      status: 403
    };
  }

  const profileMatch = objectKey.match(/^users\/([^/]+)\/profile\/([0-9]{10,17})\.jpg$/);
  if (profileMatch) {
    return {
      ok: true,
      kind: "profile",
      uid: profileMatch[1],
      timestamp: profileMatch[2]
    };
  }

  const uploadMatch = objectKey.match(/^users\/([^/]+)\/uploads\/([a-z0-9_-]{1,64})\/([0-9]{10,17})\.jpg$/);
  if (uploadMatch) {
    return {
      ok: true,
      kind: "routineUpload",
      uid: uploadMatch[1],
      routineType: uploadMatch[2],
      timestamp: uploadMatch[3]
    };
  }

  return {
    ok: false,
    code: "UNSUPPORTED_OBJECT_KEY",
    message: "objectKey folder is not supported",
    status: 400
  };
}

function hasPathTraversal(value) {
  const candidates = [value];
  let current = value;
  for (let i = 0; i < 3; i += 1) {
    try {
      const decoded = decodeURIComponent(current);
      if (decoded === current) break;
      candidates.push(decoded);
      current = decoded;
    } catch (_) {
      break;
    }
  }

  return candidates.some((candidate) => (
    candidate.includes("../") ||
    candidate.includes("..\\") ||
    candidate.split("/").some((segment) => segment === "..")
  ));
}

async function createSignedPutUrl({ env, objectKey, contentType, sizeBytes, expiresInSeconds }) {
  const accountId = stringField(env.R2_ACCOUNT_ID);
  const bucketName = stringField(env.R2_BUCKET_NAME);
  const accessKeyId = stringField(env.R2_ACCESS_KEY_ID);
  const secretAccessKey = stringField(env.R2_SECRET_ACCESS_KEY);
  const now = new Date();
  const amzDate = iso8601Basic(now);
  const dateStamp = amzDate.slice(0, 8);
  const region = "auto";
  const service = "s3";
  const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`;
  const host = `${accountId}.r2.cloudflarestorage.com`;
  const canonicalUri = `/${encodePathSegment(bucketName)}/${encodePath(objectKey)}`;
  const signedHeaders = "content-length;content-type;host";
  const queryParams = [
    ["X-Amz-Algorithm", "AWS4-HMAC-SHA256"],
    ["X-Amz-Credential", `${accessKeyId}/${credentialScope}`],
    ["X-Amz-Date", amzDate],
    ["X-Amz-Expires", String(expiresInSeconds)],
    ["X-Amz-SignedHeaders", signedHeaders]
  ];
  const canonicalQueryString = canonicalQuery(queryParams);
  const canonicalHeaders = [
    `content-length:${sizeBytes}`,
    `content-type:${contentType}`,
    `host:${host}`
  ].join("\n") + "\n";
  const payloadHash = "UNSIGNED-PAYLOAD";
  const canonicalRequest = [
    "PUT",
    canonicalUri,
    canonicalQueryString,
    canonicalHeaders,
    signedHeaders,
    payloadHash
  ].join("\n");
  const stringToSign = [
    "AWS4-HMAC-SHA256",
    amzDate,
    credentialScope,
    await sha256Hex(canonicalRequest)
  ].join("\n");
  const signingKey = await awsSigningKey(secretAccessKey, dateStamp, region, service);
  const signature = await hmacHex(signingKey, stringToSign);

  return `https://${host}${canonicalUri}?${canonicalQueryString}&X-Amz-Signature=${signature}`;
}

function uploadUrlTtlSeconds(env) {
  const configured = Number.parseInt(stringField(env.UPLOAD_URL_TTL_SECONDS), 10);
  if (!Number.isFinite(configured)) return maxUploadUrlTtlSeconds;
  return Math.min(maxUploadUrlTtlSeconds, Math.max(minUploadUrlTtlSeconds, configured));
}

function stringField(value) {
  return typeof value === "string" ? value.trim() : "";
}

function numberField(value) {
  if (typeof value === "number") return value;
  if (typeof value === "string" && value.trim() !== "") return Number(value);
  return Number.NaN;
}

function encodePath(value) {
  return value.split("/").map(encodePathSegment).join("/");
}

function encodePathSegment(value) {
  return encodeURIComponent(value).replace(/[!'()*]/g, (char) => (
    `%${char.charCodeAt(0).toString(16).toUpperCase()}`
  ));
}

function canonicalQuery(params) {
  return params
    .map(([key, value]) => [awsEncode(key), awsEncode(value)])
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([key, value]) => `${key}=${value}`)
    .join("&");
}

function awsEncode(value) {
  return encodeURIComponent(value).replace(/[!'()*]/g, (char) => (
    `%${char.charCodeAt(0).toString(16).toUpperCase()}`
  ));
}

function iso8601Basic(date) {
  return date.toISOString().replace(/[:-]|\.\d{3}/g, "");
}

async function sha256Hex(value) {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return bytesToHex(new Uint8Array(digest));
}

async function awsSigningKey(secretAccessKey, dateStamp, region, service) {
  const dateKey = await hmacBytes(new TextEncoder().encode(`AWS4${secretAccessKey}`), dateStamp);
  const dateRegionKey = await hmacBytes(dateKey, region);
  const dateRegionServiceKey = await hmacBytes(dateRegionKey, service);
  return hmacBytes(dateRegionServiceKey, "aws4_request");
}

async function hmacBytes(keyBytes, message) {
  const key = await crypto.subtle.importKey(
    "raw",
    keyBytes,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(message)
  );
  return new Uint8Array(signature);
}

async function hmacHex(keyBytes, message) {
  return bytesToHex(await hmacBytes(keyBytes, message));
}

function bytesToHex(bytes) {
  return Array.from(bytes)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
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
