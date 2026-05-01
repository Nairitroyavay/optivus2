// functions/test/routineImport.contract.test.js
//
// Contract tests for the Routine Import Cloud Function endpoint.
// All tests are skipped (TODO) — implement with firebase-functions-test
// and the Firebase emulator suite once the routineImport callable is added
// to functions/index.js.
//
// Endpoint under test (planned):
//   exports.routineImport = onCall(...)
//
// Responsibilities:
//   • Accept a structured routine template payload from the client.
//   • Validate the payload shape (blocks, timing, categories).
//   • Write the parsed template to /users/{uid}/routine/current.
//   • Materialise routine tasks into /users/{uid}/tasks/ for the next 14 days.
//   • Emit routine_template_imported event.
//   • Return a RoutineImportResult {success, blocksImported, tasksCreated, errors[]}.

'use strict';

// ── auth guard ───────────────────────────────────────────────────────────────

describe('routineImport — auth guard', () => {
  it.skip('TODO: unauthenticated call throws HttpsError unauthenticated', () => {});
});

// ── input validation ─────────────────────────────────────────────────────────

describe('routineImport — input validation', () => {
  it.skip('TODO: throws invalid-argument when payload is missing the blocks array', () => {});
  it.skip('TODO: throws invalid-argument when a block has no title', () => {});
  it.skip('TODO: throws invalid-argument when a block startTime >= endTime', () => {});
  it.skip('TODO: throws invalid-argument when a block duration exceeds 480 minutes', () => {});
  it.skip('TODO: accepts an empty blocks array and writes an empty routine', () => {});
});

// ── Firestore writes ─────────────────────────────────────────────────────────

describe('routineImport — Firestore writes', () => {
  it.skip('TODO: writes parsed template to /users/{uid}/routine/current', () => {});
  it.skip('TODO: routine/current doc contains schemaVersion: 1 and updatedAt', () => {});
  it.skip('TODO: materialises task docs in /users/{uid}/tasks/ for the next 14 days', () => {});
  it.skip('TODO: each materialised task has type == routine and correct plannedStart/End', () => {});
  it.skip('TODO: does not overwrite task state fields for already-started tasks (merge: true)', () => {});
});

// ── event emission ───────────────────────────────────────────────────────────

describe('routineImport — event emission', () => {
  it.skip('TODO: emits routine_template_imported event after successful write', () => {});
  it.skip('TODO: event payload contains blocksImported count and source == upload', () => {});
});

// ── return value ─────────────────────────────────────────────────────────────

describe('routineImport — return value', () => {
  it.skip('TODO: returns {success: true, blocksImported: N, tasksCreated: M, errors: []} on success', () => {});
  it.skip('TODO: returns {success: false, errors: [...]} when validation fails', () => {});
  it.skip('TODO: tasksCreated reflects the actual number of task docs written', () => {});
});

// ── idempotency ──────────────────────────────────────────────────────────────

describe('routineImport — idempotency', () => {
  it.skip('TODO: importing the same template twice does not duplicate task docs', () => {});
  it.skip('TODO: second import overwrites routine/current but preserves in-progress task states', () => {});
});
