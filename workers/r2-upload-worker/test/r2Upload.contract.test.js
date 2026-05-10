import assert from "node:assert/strict";
import test from "node:test";
import { SignJWT, exportJWK, generateKeyPair } from "jose";

const projectId = "optivus-test";
const uid = "test_uid";

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

test("rejects missing auth", async () => {
  const response = await worker.fetch(
    new Request("https://r2-upload.test/signed-upload", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(validUploadBody())
    }),
    env()
  );
  const body = await response.json();

  assert.equal(response.status, 401);
  assertErrorShape(body, "AUTH_MISSING", "Missing Authorization Bearer token", 401);
});

test("rejects invalid auth", async () => {
  const response = await worker.fetch(
    new Request("https://r2-upload.test/signed-upload", {
      method: "POST",
      headers: {
        "Authorization": "Bearer invalid-token",
        "Content-Type": "application/json"
      },
      body: JSON.stringify(validUploadBody())
    }),
    env()
  );
  const body = await response.json();

  assert.equal(response.status, 401);
  assertErrorShape(body, "AUTH_INVALID", "Invalid Firebase ID token", 401);
});

test("returns signed upload URL for verified uid and ignores body userId", async () => {
  const response = await callWorker({
    path: "/signed-upload",
    body: {
      ...validUploadBody(),
      userId: "attacker_uid"
    }
  });
  const body = await response.json();
  const uploadUrl = new URL(body.uploadUrl);

  assert.equal(response.status, 200, JSON.stringify(body));
  assert.equal(body.ok, true);
  assert.equal(body.userId, uid);
  assert.equal(body.objectKey, validUploadBody().objectKey);
  assert.equal(body.path, validUploadBody().objectKey);
  assert.equal(body.method, "PUT");
  assert.equal(body.contentType, "image/jpeg");
  assert.equal(body.sizeBytes, 240000);
  assert.equal(body.expiresInSeconds <= 300, true);
  assert.equal(body.requiredHeaders["Content-Type"], "image/jpeg");
  assert.equal(body.requiredHeaders["Content-Length"], "240000");
  assert.equal(uploadUrl.hostname, "test-account.r2.cloudflarestorage.com");
  assert.equal(uploadUrl.searchParams.get("X-Amz-Algorithm"), "AWS4-HMAC-SHA256");
  assert.equal(uploadUrl.searchParams.get("X-Amz-Expires"), "120");
  assert.equal(uploadUrl.searchParams.has("X-Amz-Signature"), true);
});

test("rejects object key for another uid", async () => {
  const response = await callWorker({
    path: "/signed-upload",
    body: {
      ...validUploadBody(),
      objectKey: "users/other_uid/uploads/skin_care/1715289300000.jpg"
    }
  });
  const body = await response.json();

  assert.equal(response.status, 403, JSON.stringify(body));
  assertErrorShape(body, "OBJECT_KEY_UID_MISMATCH", "objectKey must be under users/{verifiedUid}/", 403);
});

test("rejects path traversal", async () => {
  const response = await callWorker({
    path: "/signed-upload",
    body: {
      ...validUploadBody(),
      objectKey: `users/${uid}/uploads/../profile/1715289300000.jpg`
    }
  });
  const body = await response.json();

  assert.equal(response.status, 400, JSON.stringify(body));
  assertErrorShape(body, "PATH_TRAVERSAL_REJECTED", "objectKey must not contain path traversal", 400);
});

test("rejects encoded path traversal", async () => {
  const response = await callWorker({
    path: "/signed-upload",
    body: {
      ...validUploadBody(),
      objectKey: `users/${uid}/uploads/%2e%2e/profile/1715289300000.jpg`
    }
  });
  const body = await response.json();

  assert.equal(response.status, 400, JSON.stringify(body));
  assertErrorShape(body, "PATH_TRAVERSAL_REJECTED", "objectKey must not contain path traversal", 400);
});

test("rejects unsupported content type", async () => {
  const response = await callWorker({
    path: "/signed-upload",
    body: {
      ...validUploadBody(),
      contentType: "image/png"
    }
  });
  const body = await response.json();

  assert.equal(response.status, 400, JSON.stringify(body));
  assertErrorShape(body, "UNSUPPORTED_CONTENT_TYPE", "contentType must be image/jpeg", 400);
});

test("rejects size over 1 MB", async () => {
  const response = await callWorker({
    path: "/signed-upload",
    body: {
      ...validUploadBody(),
      sizeBytes: 1_000_001
    }
  });
  const body = await response.json();

  assert.equal(response.status, 400, JSON.stringify(body));
  assertErrorShape(body, "UPLOAD_TOO_LARGE", "sizeBytes must be less than or equal to 1000000", 400);
});

test("rejects unsupported object key folders", async () => {
  const response = await callWorker({
    path: "/signed-upload",
    body: {
      ...validUploadBody(),
      objectKey: `users/${uid}/avatars/1715289300000.jpg`
    }
  });
  const body = await response.json();

  assert.equal(response.status, 400, JSON.stringify(body));
  assertErrorShape(body, "UNSUPPORTED_OBJECT_KEY", "objectKey folder is not supported", 400);
});

test("accepts delete for own object", async () => {
  const deletedKeys = [];
  const response = await callWorker({
    path: "/delete-upload",
    body: {
      objectKey: `users/${uid}/profile/1715289300000.jpg`,
      userId: "attacker_uid"
    },
    workerEnv: env({ deletedKeys })
  });
  const body = await response.json();

  assert.equal(response.status, 200, JSON.stringify(body));
  assert.equal(body.ok, true);
  assert.equal(body.deleted, true);
  assert.equal(body.userId, uid);
  assert.deepEqual(deletedKeys, [`users/${uid}/profile/1715289300000.jpg`]);
});

test("rejects delete for another uid", async () => {
  const deletedKeys = [];
  const response = await callWorker({
    path: "/delete-upload",
    body: {
      objectKey: "users/other_uid/profile/1715289300000.jpg"
    },
    workerEnv: env({ deletedKeys })
  });
  const body = await response.json();

  assert.equal(response.status, 403, JSON.stringify(body));
  assertErrorShape(body, "OBJECT_KEY_UID_MISMATCH", "objectKey must be under users/{verifiedUid}/", 403);
  assert.deepEqual(deletedKeys, []);
});

test("rejects encoded path traversal on delete", async () => {
  const deletedKeys = [];
  const response = await callWorker({
    path: "/delete-upload",
    body: {
      objectKey: `users/${uid}/uploads/%2e%2e/profile/1715289300000.jpg`
    },
    workerEnv: env({ deletedKeys })
  });
  const body = await response.json();

  assert.equal(response.status, 400, JSON.stringify(body));
  assertErrorShape(body, "PATH_TRAVERSAL_REJECTED", "objectKey must not contain path traversal", 400);
  assert.deepEqual(deletedKeys, []);
});

test("success and error schemas are consistent", async () => {
  const success = await callWorker({
    path: "/signed-upload",
    body: validProfileUploadBody()
  });
  const successBody = await success.json();
  assert.equal(success.status, 200, JSON.stringify(successBody));
  assert.equal(successBody.ok, true);
  assert.equal(typeof successBody.uploadUrl, "string");
  assert.equal(successBody.error, undefined);

  const error = await callWorker({
    path: "/signed-upload",
    body: {
      ...validProfileUploadBody(),
      contentType: "image/gif"
    }
  });
  const errorBody = await error.json();
  assert.equal(error.status, 400, JSON.stringify(errorBody));
  assertErrorShape(errorBody, "UNSUPPORTED_CONTENT_TYPE", "contentType must be image/jpeg", 400);
});

async function callWorker({ path, body, workerEnv }) {
  const token = await firebaseToken(uid);
  return worker.fetch(
    new Request(`https://r2-upload.test${path}`, {
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

async function firebaseToken(tokenUid) {
  return new SignJWT({ sub: tokenUid, user_id: tokenUid })
    .setProtectedHeader({ alg: "RS256", kid: "test-key" })
    .setIssuer(`https://securetoken.google.com/${projectId}`)
    .setAudience(projectId)
    .setIssuedAt()
    .setExpirationTime("5m")
    .sign(authPrivateKey);
}

function env(options = {}) {
  const deletedKeys = options.deletedKeys ?? [];
  return {
    FIREBASE_PROJECT_ID: projectId,
    R2_ACCOUNT_ID: "test-account",
    R2_BUCKET_NAME: "test-bucket",
    R2_ACCESS_KEY_ID: "test-access-key",
    R2_SECRET_ACCESS_KEY: "test-secret-key",
    R2_UPLOAD_TEST_JWKS_JSON: JSON.stringify({ keys: [authJwk] }),
    UPLOAD_URL_TTL_SECONDS: "120",
    R2_BUCKET: {
      async delete(objectKey) {
        deletedKeys.push(objectKey);
      }
    }
  };
}

function validUploadBody() {
  return {
    objectKey: `users/${uid}/uploads/skin_care/1715289300000.jpg`,
    contentType: "image/jpeg",
    sizeBytes: 240000,
    routineType: "skin_care"
  };
}

function validProfileUploadBody() {
  return {
    objectKey: `users/${uid}/profile/1715289300000.jpg`,
    contentType: "image/jpeg",
    sizeBytes: 180000
  };
}

function assertErrorShape(body, code, message, status) {
  assert.equal(body.ok, false);
  assert.equal(body.error?.code, code);
  assert.equal(body.error?.message, message);
  assert.equal(body.code, code);
  assert.equal(body.message, message);
  assert.equal(body.status, status);
}
