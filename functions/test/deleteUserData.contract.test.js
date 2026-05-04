// functions/test/deleteUserData.contract.test.js
//
// Contract tests for the Delete User Data Cloud Function.
// All tests are skipped (TODO) — implement with firebase-functions-test once
// a dedicated deleteUserData callable is added to functions/index.js.
// Currently FirestoreService.deleteUserOwnedData() + user.delete() run client-side;
// this callable moves the lifecycle to the server for safety, soft-delete window,
// and notification cancellation.
//
// Function under test (planned):
//   exports.requestAccountDeletion = onCall(...)   — initiates soft-delete
//   exports.confirmAccountDeletion = onCall(...)   — hard-deletes after window
//   exports.cancelAccountDeletion  = onCall(...)   — cancels within window
//
// Lifecycle:
//   1. requestAccountDeletion  → writes deletion_request doc; status=pending; notifies user
//   2. (optional) cancelAccountDeletion → marks status=cancelled within recovery window
//   3. After recovery window → scheduled job hard-deletes all sub-collections
//
// Firestore paths (planned):
//   /users/{uid}/deletion_requests/{requestId}
//   /users/{uid}/ (all sub-collections — deleted on confirm)
//
// Events:
//   account_deletion_requested, account_deletion_cancelled, account_deleted

'use strict';

// ── auth guard ───────────────────────────────────────────────────────────────

describe('requestAccountDeletion — auth guard', () => {
  it.skip('TODO: unauthenticated call throws HttpsError unauthenticated', () => {});
});

describe('cancelAccountDeletion — auth guard', () => {
  it.skip('TODO: unauthenticated call throws HttpsError unauthenticated', () => {});
  it.skip('TODO: cancelling a request owned by a different uid throws HttpsError permission-denied', () => {});
});

// ── requestAccountDeletion ────────────────────────────────────────────────────

describe('requestAccountDeletion — happy path', () => {
  it.skip('TODO: writes a deletion_request doc with status=pending and scheduledAt', () => {});
  it.skip('TODO: scheduledAt is set to now + recovery window duration (e.g. 30 days)', () => {});
  it.skip('TODO: emits account_deletion_requested event', () => {});
  it.skip('TODO: cancels all pending scheduled_notifications for the user', () => {});
  it.skip('TODO: returns {requestId, scheduledAt} on success', () => {});
});

describe('requestAccountDeletion — duplicate request', () => {
  it.skip('TODO: throws HttpsError already-exists when a pending deletion request already exists', () => {});
});

// ── cancelAccountDeletion ─────────────────────────────────────────────────────

describe('cancelAccountDeletion — happy path', () => {
  it.skip('TODO: updates deletion_request doc status to cancelled', () => {});
  it.skip('TODO: emits account_deletion_cancelled event', () => {});
  it.skip('TODO: returns {cancelled: true} on success', () => {});
});

describe('cancelAccountDeletion — error cases', () => {
  it.skip('TODO: throws HttpsError not-found when requestId does not exist', () => {});
  it.skip('TODO: throws HttpsError failed-precondition when status is already deleted or cancelled', () => {});
  it.skip('TODO: throws HttpsError deadline-exceeded when recovery window has already passed', () => {});
});

// ── hard delete (scheduled job / confirmAccountDeletion) ─────────────────────

describe('deleteUserData — hard delete', () => {
  it.skip('TODO: deletes all documents in /users/{uid}/tasks/', () => {});
  it.skip('TODO: deletes all documents in /users/{uid}/habits/', () => {});
  it.skip('TODO: deletes all documents in /users/{uid}/habit_logs/', () => {});
  it.skip('TODO: deletes all documents in /users/{uid}/streaks/', () => {});
  it.skip('TODO: deletes all documents in /users/{uid}/goals/', () => {});
  it.skip('TODO: deletes all documents in /users/{uid}/events/', () => {});
  it.skip('TODO: deletes all documents in /users/{uid}/coach_messages/', () => {});
  it.skip('TODO: deletes all documents in /users/{uid}/scheduled_notifications/', () => {});
  it.skip('TODO: deletes the /users/{uid} root document last', () => {});
  it.skip('TODO: emits account_deleted event before deleting the root document', () => {});
  it.skip('TODO: does not delete documents owned by other uids', () => {});
});

// ── idempotency ───────────────────────────────────────────────────────────────

describe('deleteUserData — idempotency', () => {
  it.skip('TODO: running hard delete twice for the same uid does not throw', () => {});
  it.skip('TODO: second hard delete is a no-op when sub-collections are already empty', () => {});
});
