// functions/test/ruleEngine.contract.test.js
//
// Contract tests for the Rule Engine Cloud Function.
// All tests are skipped (TODO) — implement with firebase-functions-test once
// a server-side rule engine job is added to functions/index.js.
// The client-side RuleEngineService (lib/services/rule_engine_service.dart, 25 KB)
// defines the rules; this server function is the authoritative evaluator that
// enforces speak budgets and writes decisions to Firestore.
//
// Function under test (planned):
//   exports.evaluateRules = onCall(...)         — on-demand trigger
//   exports.scheduledRuleEngine = onSchedule(...)  — runs after day-close, inactivity, etc.
//
// Key rules (must be replicated server-side):
//   crisis_intervention_slips (priority 1): fires when slipsToday >= 3
//
// Firestore paths:
//   /users/{uid}/events_recent        (read — context input)
//   /users/{uid}/coach_speak_log      (read/write — speak budget)
//   /users/{uid}/suggestions/{id}     (write — fired rule output)
//   /users/{uid}/coach_messages/{id}  (write — crisis/support output)

'use strict';

// ── auth guard ───────────────────────────────────────────────────────────────

describe('evaluateRules — auth guard', () => {
  it.skip('TODO: unauthenticated call throws HttpsError unauthenticated', () => {});
});

// ── context loading ───────────────────────────────────────────────────────────

describe('evaluateRules — context loading', () => {
  it.skip('TODO: reads /users/{uid}/events_recent to build evaluation context', () => {});
  it.skip('TODO: handles empty events_recent gracefully — returns empty decisions list', () => {});
});

// ── decision output shape ─────────────────────────────────────────────────────

describe('evaluateRules — decision output shape', () => {
  it.skip('TODO: returns {decisions: [...]} where each decision has ruleId, fired, priority', () => {});
  it.skip('TODO: unfired decisions include a non-empty silenceReason string', () => {});
  it.skip('TODO: fired decisions include a non-null aiIntent string', () => {});
  it.skip('TODO: decisions are ordered by priority ascending', () => {});
});

// ── crisis_intervention_slips rule ────────────────────────────────────────────

describe('evaluateRules — crisis_intervention_slips rule', () => {
  it.skip('TODO: rule fires when events_recent contains >= 3 bad_habit_slip_logged events for today', () => {});
  it.skip('TODO: fired decision has aiIntent == "crisis_intervention_slips"', () => {});
  it.skip('TODO: fired decision has priority == 1', () => {});
  it.skip('TODO: rule does not fire when slip count < 3', () => {});
  it.skip('TODO: only today\'s slips are counted — older slips do not trigger the rule', () => {});
});

// ── speak budget enforcement ──────────────────────────────────────────────────

describe('evaluateRules — speak budget enforcement', () => {
  it.skip('TODO: fired rule is suppressed when coach_speak_log count for today meets the cap', () => {});
  it.skip('TODO: suppressed fired rule has silenceReason == "speak_budget_exceeded"', () => {});
  it.skip('TODO: speak budget cap is read from Remote Config, not hard-coded', () => {});
  it.skip('TODO: increments coach_speak_log when a rule fires and is not suppressed', () => {});
});

// ── Firestore writes for fired rules ─────────────────────────────────────────

describe('evaluateRules — Firestore writes', () => {
  it.skip('TODO: writes a suggestion doc for non-crisis fired rules', () => {});
  it.skip('TODO: routes crisis-intent fired rules to safetyRoute instead of writing a suggestion', () => {});
  it.skip('TODO: written suggestion doc has status=pending, schemaVersion: 1, and aiIntent field', () => {});
  it.skip('TODO: emits suggestion_generated event for each written suggestion', () => {});
});

// ── idempotency ───────────────────────────────────────────────────────────────

describe('evaluateRules — idempotency', () => {
  it.skip('TODO: evaluating the same context twice does not write duplicate suggestion docs', () => {});
  it.skip('TODO: speak log is incremented at most once per rule per day', () => {});
});
