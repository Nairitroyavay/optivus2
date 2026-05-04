// functions/test/aiPlanner.contract.test.js
//
// Contract tests for the AI Planner Cloud Function.
// All tests are skipped (TODO) — implement with firebase-functions-test once
// a dedicated aiPlanner callable or scheduled job is added to functions/index.js.
// The existing aiGenerate callable is a generic entry point; aiPlanner is the
// specialised path that reads context, generates a structured plan, and writes
// suggestions back to Firestore.
//
// Function under test (planned):
//   exports.aiPlanner = onCall(...)          — manual trigger
//   exports.scheduledAiPlanner = onSchedule(...)  — runs during morning/midday jobs
//
// Responsibilities:
//   • Read the most recent /users/{uid}/ai_context_snapshots entry.
//   • Call the AI backend (mocked in tests — API key must not be in response).
//   • Parse and validate the AI response shape.
//   • Write suggestions to /users/{uid}/suggestions/{suggestionId}.
//   • Emit suggestion_generated event for each written suggestion.
//   • Route crisis-level context to the safety function, not to coaching AI.
//   • Enforce usage caps from /profile/main.subscription and /usage/{monthKey}.

'use strict';

// ── auth guard ───────────────────────────────────────────────────────────────

describe('aiPlanner — auth guard', () => {
  it.skip('TODO: unauthenticated call throws HttpsError unauthenticated', () => {});
});

// ── context loading ───────────────────────────────────────────────────────────

describe('aiPlanner — context loading', () => {
  it.skip('TODO: reads the most recent ai_context_snapshots doc for the user', () => {});
  it.skip('TODO: throws HttpsError failed-precondition when no context snapshot exists', () => {});
  it.skip('TODO: context snapshot includes profile, tasks, habits, goals, and streaks', () => {});
});

// ── AI call contract ──────────────────────────────────────────────────────────

describe('aiPlanner — AI call contract', () => {
  it.skip('TODO: AI API key is not returned in any field of the Cloud Function response', () => {});
  it.skip('TODO: AI is called with a structured prompt built from the context snapshot', () => {});
  it.skip('TODO: raw AI response text is never forwarded verbatim to the client', () => {});
  it.skip('TODO: function times out gracefully and returns an error result if AI call exceeds 30s', () => {});
});

// ── safety routing ────────────────────────────────────────────────────────────

describe('aiPlanner — safety routing', () => {
  it.skip('TODO: crisis-level context (e.g. slipsToday >= 3) routes to safetyRoute instead of coaching AI', () => {});
  it.skip('TODO: does not write coaching suggestions when safety branch is crisis', () => {});
  it.skip('TODO: normal context proceeds with the coaching AI path', () => {});
});

// ── suggestion writes ─────────────────────────────────────────────────────────

describe('aiPlanner — suggestion writes', () => {
  it.skip('TODO: writes at least one suggestion to /users/{uid}/suggestions/', () => {});
  it.skip('TODO: each suggestion doc has status=pending, schemaVersion: 1, and createdAt', () => {});
  it.skip('TODO: each suggestion has a non-empty text field and a category field', () => {});
  it.skip('TODO: emits suggestion_generated event for each written suggestion', () => {});
});

// ── usage cap enforcement ─────────────────────────────────────────────────────

describe('aiPlanner — usage cap enforcement', () => {
  it.skip('TODO: throws HttpsError resource-exhausted when monthly AI usage cap is reached', () => {});
  it.skip('TODO: cap is read from /usage/{monthKey} and /profile/main.subscription, not hard-coded', () => {});
  it.skip('TODO: increments usage counter in /usage/{monthKey} after a successful AI call', () => {});
});

// ── return value ──────────────────────────────────────────────────────────────

describe('aiPlanner — return value', () => {
  it.skip('TODO: returns {success: true, suggestionsGenerated: N} on success', () => {});
  it.skip('TODO: returns {success: false, error: "..."} on AI call failure', () => {});
});

// ── idempotency ───────────────────────────────────────────────────────────────

describe('aiPlanner — idempotency', () => {
  it.skip('TODO: running twice with the same context snapshot does not create duplicate suggestions', () => {});
});
