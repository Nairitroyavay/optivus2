// lib/models/coach_rule.dart
//
// Rule and RuleCondition — value objects that describe when the coach should
// speak and what it should say.  All rules are defined in code (rule_engine_service.dart),
// never fetched from Firestore, so they're strongly typed and version-controlled.

/// A single condition that must be satisfied for a rule to fire.
///
/// Conditions compare a resolved field value from the current [ContextSnapshot]
/// or the triggering [EventModel] against [value] using [op].
///
/// Supported operators: eq, neq, gt, gte, lt, lte, in, nin, contains,
/// exists, not_exists.
///
/// Dot-notation paths are supported for nested event payload fields,
/// e.g. `metadata.habit` resolves `event.payload['metadata']['habit']`.
class RuleCondition {
  final String field;
  final String op;
  final Object? value;

  const RuleCondition({
    required this.field,
    required this.op,
    required this.value,
  });
}

/// A coaching rule that maps a triggering event + snapshot conditions to an
/// AI prompt and fallback message.
///
/// Rules are evaluated by [RuleEngineService.evaluate] in priority order
/// (lower number = higher priority).  The highest-priority matching rule wins.
class Rule {
  // ── Identity ──────────────────────────────────────────────────────────────

  /// Stable unique identifier — never reuse or rename.
  final String id;

  /// Human-readable description used in logs and dashboards.
  final String description;

  // ── Trigger ───────────────────────────────────────────────────────────────

  /// The [EventModel.eventName] that must match for this rule to be evaluated.
  /// Use `'*'` to match any event.
  final String event;

  /// All conditions must be satisfied simultaneously for the rule to fire.
  final List<RuleCondition> conditions;

  // ── Priority & deduplication ──────────────────────────────────────────────

  /// Lower number = evaluated / preferred first.  Range: 1 (critical) – 10 (informational).
  final int priority;

  /// Seconds before this rule can fire again for the same [cooldownTopic].
  final int cooldownSeconds;

  /// Logical grouping key for cooldown tracking (e.g. `'missed_task'`).
  final String cooldownTopic;

  // ── Output ────────────────────────────────────────────────────────────────

  /// Intent label forwarded to the AI model (e.g. `'check_in_missed_task'`).
  final String aiIntent;

  /// Template passed to [GeminiService.generateOnce] as the system prompt.
  final String promptTemplate;

  /// A-B test examples — shown to reviewers, not to the user directly.
  final List<String> exampleOutputs;

  /// Used verbatim if the Gemini call fails or times out.
  final String fallbackMessage;

  /// What the coach does after delivering this message: `'none'` | `'active'`.
  final String followupPolicy;

  // ── Metadata ──────────────────────────────────────────────────────────────

  /// Categorical tags for log filtering and analytics (e.g. `['task', 'abandon']`).
  final List<String> tags;

  /// If non-null, the rule is skipped unless [ContextSnapshot.userState] is
  /// one of these values.  Keeps condition lists shorter for state-specific rules.
  final List<String>? minUserStateIn;

  const Rule({
    required this.id,
    required this.description,
    required this.event,
    required this.conditions,
    required this.priority,
    this.cooldownSeconds = 0,
    this.cooldownTopic = '',
    this.aiIntent = '',
    this.promptTemplate = '',
    this.exampleOutputs = const [],
    this.fallbackMessage = '',
    this.followupPolicy = 'none',
    this.tags = const [],
    this.minUserStateIn,
  });
}
