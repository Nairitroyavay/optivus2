// functions/test/exportUserData.contract.test.js
//
// Contract tests for the Export User Data Cloud Function.
// All tests are skipped (TODO) — implement with firebase-functions-test once
// a dedicated exportUserData callable is added to functions/index.js.
// Currently FirestoreService.exportUserData() runs client-side; this callable
// will move the export to the server for safety and completeness.
//
// Function under test (planned):
//   exports.exportUserData = onCall(...)
//
// Responsibilities:
//   • Read all sub-collections under /users/{uid}/.
//   • Serialize to JSON — one top-level key per collection.
//   • Return the JSON string (or a signed download URL for large exports).
//   • Record the export in /users/{uid}/data_exports/{exportId}.
//   • Never include other users' data.
//   • Respect Firestore security rules (server-side read uses Admin SDK).

'use strict';

// ── auth guard ───────────────────────────────────────────────────────────────

describe('exportUserData — auth guard', () => {
  it.skip('TODO: unauthenticated call throws HttpsError unauthenticated', () => {});
  it.skip('TODO: authenticated call for a different uid throws HttpsError permission-denied', () => {});
});

// ── output shape ─────────────────────────────────────────────────────────────

describe('exportUserData — output shape', () => {
  it.skip('TODO: returns a valid JSON-parseable string', () => {});
  it.skip('TODO: top-level JSON object contains keys for all user sub-collections', () => {});
  it.skip('TODO: expected collections present: tasks, habits, habit_logs, streaks, goals, events, coach_messages, routine, scheduled_notifications', () => {});
  it.skip('TODO: each collection key maps to an array of document objects', () => {});
});

// ── data isolation ────────────────────────────────────────────────────────────

describe('exportUserData — data isolation', () => {
  it.skip('TODO: export contains only documents owned by the authenticated uid', () => {});
  it.skip('TODO: export does not contain documents from /users/{otherUid}/', () => {});
});

// ── export record ─────────────────────────────────────────────────────────────

describe('exportUserData — export record', () => {
  it.skip('TODO: writes a doc to /users/{uid}/data_exports/{exportId} after completion', () => {});
  it.skip('TODO: export record contains requestedAt, completedAt, and status fields', () => {});
  it.skip('TODO: status is "complete" on success', () => {});
});

// ── error handling ────────────────────────────────────────────────────────────

describe('exportUserData — error handling', () => {
  it.skip('TODO: export record status is "failed" when a Firestore read throws', () => {});
  it.skip('TODO: throws HttpsError internal on unexpected server error', () => {});
});

// ── empty data ────────────────────────────────────────────────────────────────

describe('exportUserData — empty data', () => {
  it.skip('TODO: new user with no data returns an export with empty arrays per collection', () => {});
  it.skip('TODO: empty export is still valid JSON and contains the expected collection keys', () => {});
});
