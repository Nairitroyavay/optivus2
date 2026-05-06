// lib/services/rule_engine_service.dart
//
// All coaching rules are defined here in code — never fetched from Firestore.
// Rules are evaluated by evaluate() which returns the highest-priority matching
// Rule or null if nothing fires.
//
// Evaluation trace:
//   Every call emits [RuleEngine] log lines showing which rules were tested,
//   which conditions passed/failed, and which rule ultimately fired.
//   Filter logcat on "[RuleEngine]" to audit the decision trail.
//
// Rule priority scale:
//   1 = critical / crisis
//   2 = important / milestone
//   3 = standard check-in
//   4 = informational / end-of-day

import 'package:flutter/foundation.dart';

import '../models/coach_rule.dart';
import '../models/context_snapshot.dart';
import '../models/event_model.dart';

class RuleEngineService {
  // ══════════════════════════════════════════════════════════════════════════
  // Hardcoded rule definitions
  // ══════════════════════════════════════════════════════════════════════════

  // ── Smoking / addiction pattern ──────────────────────────────────────────

  static const Rule ruleSmokingPattern4Cigs = Rule(
    id: 'rule_smoking_pattern_4_cigs',
    description: 'User logged 4th cigarette today; pattern emerging.',
    event: 'bad_habit_slip_logged',
    conditions: [
      RuleCondition(field: 'metadata.habit', op: 'eq', value: 'cigarettes'),
      RuleCondition(field: 'metadata.count_today', op: 'gte', value: 4),
    ],
    priority: 1,
    cooldownSeconds: 7200,
    cooldownTopic: 'cigarettes',
    aiIntent: 'pattern_check_in_no_assumption',
    promptTemplate:
        'The user has smoked 4 cigarettes today. Acknowledge the pattern without assuming their feelings.',
    exampleOutputs: [
      'That makes 4 today. What has today been like for you?',
      'Four cigarettes in today. Want to look at what is feeding it?',
    ],
    fallbackMessage:
        'That makes 4 today. Want to talk through what is going on?',
    followupPolicy: 'none',
    tags: ['addiction', 'smoking', 'slip'],
  );

  // ── Missed gym ───────────────────────────────────────────────────────────

  static const Rule ruleMissedGymOneOff = Rule(
    id: 'rule_missed_gym_one_off',
    description: 'User missed one gym session without a larger pattern.',
    event: 'routine_window_missed',
    conditions: [
      RuleCondition(field: 'metadata.routine', op: 'eq', value: 'gym'),
      RuleCondition(field: 'metadata.completion', op: 'eq', value: 0),
      RuleCondition(field: 'longestActiveStreak', op: 'gte', value: 0),
    ],
    priority: 3,
    cooldownSeconds: 14400,
    cooldownTopic: 'gym',
    aiIntent: 'open_inquiry_no_assumption',
    promptTemplate:
        "The user missed today's gym session. Treat it as a one-off and ask one open question.",
    exampleOutputs: [
      'No gym today. Was it just one of those days?',
      'Missed the session today. Want to reschedule it or call it rest?',
    ],
    fallbackMessage:
        "Missed today's gym. Want to reschedule or take it as rest?",
    followupPolicy: 'none',
    tags: ['routine', 'gym', 'missed'],
  );

  // ── Missed task — first miss, no wins yet (empathetic) ───────────────────

  static const Rule ruleMissedTaskFirst = Rule(
    id: 'rule_missed_task_first',
    description:
        'User abandoned their first task of the day with no completed tasks yet.',
    event: 'task_abandoned',
    conditions: [
      RuleCondition(field: 'tasksAbandonedToday', op: 'eq', value: 1),
      RuleCondition(field: 'tasksCompletedToday', op: 'eq', value: 0),
    ],
    priority: 2,
    cooldownSeconds: 10800,
    cooldownTopic: 'missed_task',
    aiIntent: 'empathetic_check_in_first_miss',
    promptTemplate:
        'The user just abandoned their first task of the day and has not completed anything yet. '
        'Be empathetic. Ask one open question about what got in the way — no blame.',
    exampleOutputs: [
      "Dropped the first task. What got in the way — anything I should know?",
      "That one didn't land. What's making today feel heavy?",
    ],
    fallbackMessage: "Missed the first one. That's OK — what's going on?",
    followupPolicy: 'none',
    tags: ['task', 'abandon', 'first_miss'],
  );

  // ── Missed task — generic (single miss, some wins) ───────────────────────

  static const Rule ruleMissedTask = Rule(
    id: 'rule_missed_task',
    description: 'User missed a task today (generic, ≥1 completed elsewhere).',
    event: 'task_abandoned',
    conditions: [
      RuleCondition(field: 'tasksAbandonedToday', op: 'gte', value: 1),
      RuleCondition(field: 'tasksCompletedToday', op: 'gte', value: 1),
    ],
    priority: 3,
    cooldownSeconds: 14400,
    cooldownTopic: 'missed_task',
    aiIntent: 'check_in_missed_task',
    promptTemplate:
        'The user abandoned a task today but has also completed at least one other task. '
        'Acknowledge the miss without dwelling on it. Ask if they need to adjust the plan.',
    exampleOutputs: [
      'You dropped a task but kept momentum elsewhere. Need to adjust the plan?',
      'Missed a task. Was it too much for today?',
    ],
    fallbackMessage:
        'Missed a task today. Let me know if you want to reschedule.',
    followupPolicy: 'none',
    tags: ['task', 'abandon'],
  );

  // ── Missed task — pattern (≥2 today) ────────────────────────────────────

  static const Rule ruleMissedTaskPattern = Rule(
    id: 'rule_missed_task_pattern',
    description: 'User has abandoned ≥2 tasks today — pattern emerging.',
    event: 'task_abandoned',
    conditions: [
      RuleCondition(field: 'tasksAbandonedToday', op: 'gte', value: 2),
    ],
    priority: 2,
    cooldownSeconds: 10800,
    cooldownTopic: 'missed_task_pattern',
    aiIntent: 'explore_capacity',
    promptTemplate:
        'The user has abandoned two or more tasks today. This is a pattern, not a one-off. '
        'Explore whether the plan is too full, energy is low, or something else is blocking them.',
    exampleOutputs: [
      "Two tasks dropped today. Is the plan too packed, or is something else going on?",
      "That's a couple of misses. Should we simplify today's list?",
    ],
    fallbackMessage:
        "Two tasks dropped today. Want to trim the list and focus?",
    followupPolicy: 'active',
    tags: ['task', 'abandon', 'pattern'],
  );

  // ── Multiple slips — standard intervention (≥2) ──────────────────────────

  static const Rule ruleMultipleSlips = Rule(
    id: 'rule_multiple_slips',
    description: 'User had ≥2 habit slips today — early intervention.',
    event: 'bad_habit_slip_logged',
    conditions: [
      RuleCondition(field: 'badHabitSlipsToday', op: 'gte', value: 2),
    ],
    priority: 2,
    cooldownSeconds: 3600,
    cooldownTopic: 'multiple_slips',
    aiIntent: 'intervention_multiple_slips',
    promptTemplate:
        'The user has slipped twice today. Be supportive but direct — help them intercept the next urge.',
    exampleOutputs: [
      "That's a couple slips today. What's the trigger right now?",
      'Multiple slips today. Let\'s pause — what do you need to break this loop?',
    ],
    fallbackMessage:
        "That's a few slips today. Take a deep breath. We can stop it here.",
    followupPolicy: 'active',
    tags: ['habit', 'slip', 'intervention'],
  );

  // ── Multiple slips — critical intervention (≥3) ──────────────────────────

  static const Rule ruleMultipleSlipsCritical = Rule(
    id: 'rule_multiple_slips_critical',
    description: 'User had ≥3 slips today — crisis-level intervention.',
    event: 'bad_habit_slip_logged',
    conditions: [
      RuleCondition(field: 'badHabitSlipsToday', op: 'gte', value: 3),
    ],
    priority: 1,
    cooldownSeconds: 1800,
    cooldownTopic: 'multiple_slips',
    isCritical: true,
    aiIntent: 'crisis_intervention_slips',
    promptTemplate:
        'The user has slipped three or more times today. This is a critical moment. '
        'Do not minimise it. Be direct, warm, and help them identify one concrete action '
        'to break the cycle right now.',
    exampleOutputs: [
      "Three slips today — that's a signal. What's one thing you can do right now to change the environment?",
      'This is the moment to stop. Not tomorrow, now. What can we remove or change in the next 10 minutes?',
    ],
    fallbackMessage:
        'Three slips is a sign the day needs to change right now. What can you do in the next 10 minutes?',
    followupPolicy: 'active',
    tags: ['habit', 'slip', 'crisis'],
    minUserStateIn: ['slipping', 'relapsing', 'recovering'],
  );

  // ── Streak milestone — generic (any streak > 0) ──────────────────────────

  static const Rule ruleStreakMilestone = Rule(
    id: 'rule_streak_milestone',
    description: 'User hit a streak milestone (generic).',
    event: 'streak_milestone_reached',
    conditions: [
      RuleCondition(field: 'longestActiveStreak', op: 'gt', value: 0),
    ],
    priority: 3,
    cooldownSeconds: 86400,
    cooldownTopic: 'streak_milestone',
    aiIntent: 'celebrate_milestone',
    promptTemplate:
        'The user reached a streak milestone. Celebrate their consistency with genuine energy.',
    exampleOutputs: [
      'Huge milestone today! That takes serious commitment.',
      "Look at that streak! You're building incredible momentum.",
    ],
    fallbackMessage: 'Amazing work hitting that streak milestone!',
    followupPolicy: 'none',
    tags: ['streak', 'milestone'],
  );

  // ── Streak milestone — 7-day week ────────────────────────────────────────

  static const Rule ruleStreakMilestone7 = Rule(
    id: 'rule_streak_milestone_7',
    description: 'User completed a 7-day streak — one full week.',
    event: 'streak_milestone_reached',
    conditions: [
      RuleCondition(field: 'longestActiveStreak', op: 'gte', value: 7),
    ],
    priority: 2,
    cooldownSeconds: 86400,
    cooldownTopic: 'streak_milestone',
    aiIntent: 'celebrate_week_streak',
    promptTemplate:
        'The user just hit a 7-day streak — a full week of consistency. '
        'Make it feel like a real win. Keep it personal and energising.',
    exampleOutputs: [
      "A full week. That's not luck — that's a decision you made every single day.",
      '7 days straight. You just proved you can build a habit. Now let\'s see what 14 looks like.',
    ],
    fallbackMessage: 'One full week! That streak is real — keep it going.',
    followupPolicy: 'none',
    tags: ['streak', 'milestone', 'week'],
  );

  // ── Streak milestone — 30-day month ─────────────────────────────────────

  static const Rule ruleStreakMilestone30 = Rule(
    id: 'rule_streak_milestone_30',
    description: 'User completed a 30-day streak — a full month.',
    event: 'streak_milestone_reached',
    conditions: [
      RuleCondition(field: 'longestActiveStreak', op: 'gte', value: 30),
    ],
    priority: 1,
    cooldownSeconds: 86400,
    cooldownTopic: 'streak_milestone',
    aiIntent: 'celebrate_month_streak',
    promptTemplate:
        'The user has maintained a streak for 30 days — a full month. '
        'This is a significant achievement. Honour it with real weight.',
    exampleOutputs: [
      '30 days. That habit is yours now. Nobody can take that from you.',
      "A full month. You didn't just try — you built something real.",
    ],
    fallbackMessage: '30 days straight! This habit is part of who you are now.',
    followupPolicy: 'none',
    tags: ['streak', 'milestone', 'month'],
  );

  // ── Ghost return — standard ──────────────────────────────────────────────

  static const Rule ruleGhostReturn = Rule(
    id: 'rule_ghost_return',
    description: 'User returned after being inactive (short gap < 7 days).',
    event: 'comeback_initiated',
    conditions: [
      RuleCondition(field: 'daysSinceLastActive', op: 'gte', value: 2),
      RuleCondition(field: 'daysSinceLastActive', op: 'lt', value: 7),
    ],
    priority: 2,
    cooldownSeconds: 86400,
    cooldownTopic: 'ghost_return',
    aiIntent: 'welcome_back',
    promptTemplate:
        'The user is back after a short gap. Welcome them warmly, no guilt, just focus on today.',
    exampleOutputs: [
      "Glad to see you back. What's the one thing we're focusing on today?",
      "Welcome back. No looking back, just forward. Ready?",
    ],
    fallbackMessage: "Welcome back! Let's just focus on winning today.",
    followupPolicy: 'none',
    tags: ['engagement', 'ghost_return'],
  );

  // ── Ghost return — long absence (≥7 days) ───────────────────────────────

  static const Rule ruleGhostReturnLong = Rule(
    id: 'rule_ghost_return_long',
    description: 'User returned after 7+ days of inactivity.',
    event: 'comeback_initiated',
    conditions: [
      RuleCondition(field: 'daysSinceLastActive', op: 'gte', value: 7),
    ],
    priority: 1,
    cooldownSeconds: 86400,
    cooldownTopic: 'ghost_return',
    aiIntent: 'welcome_back_long_absence',
    promptTemplate:
        'The user has been away for a week or more and just opened the app. '
        'Welcome them without any guilt. Acknowledge the gap briefly, then redirect '
        'to something small they can win today.',
    exampleOutputs: [
      "You've been gone a while — and that's OK. What's one thing we can do today to get momentum back?",
      "A week away. Life happens. What's changed, and how can I help you start again?",
    ],
    fallbackMessage:
        "Welcome back after the break. Let's start with just one win today.",
    followupPolicy: 'active',
    tags: ['engagement', 'ghost_return', 'long_absence'],
  );

  // ── End of day — strong performance ─────────────────────────────────────

  static const Rule ruleEndOfDayStrong = Rule(
    id: 'rule_end_of_day_strong',
    description:
        'User closed the day with mission score ≥ 70 and ≥1 task done.',
    event: 'routine_day_summarized',
    conditions: [
      RuleCondition(field: 'missionScore', op: 'gte', value: 70),
      RuleCondition(field: 'tasksCompletedToday', op: 'gte', value: 1),
    ],
    priority: 3,
    cooldownSeconds: 43200,
    cooldownTopic: 'end_of_day',
    aiIntent: 'celebrate_strong_day',
    promptTemplate:
        'The user closed out a strong day — high mission score, at least one task completed. '
        'Give a brief, genuine wrap-up that acknowledges what they built today.',
    exampleOutputs: [
      'Solid execution today. Rest up — you earned it.',
      "Strong finish. That's the kind of day that compounds.",
    ],
    fallbackMessage: 'Great day! Rest well and go again tomorrow.',
    followupPolicy: 'none',
    tags: ['end_of_day', 'strong_performance'],
  );

  // ── End of day — rough day ───────────────────────────────────────────────

  static const Rule ruleEndOfDayRough = Rule(
    id: 'rule_end_of_day_rough',
    description: 'User closed the day with mission score < 40 — a hard day.',
    event: 'routine_day_summarized',
    conditions: [
      RuleCondition(field: 'missionScore', op: 'lt', value: 40),
    ],
    priority: 2,
    cooldownSeconds: 43200,
    cooldownTopic: 'end_of_day',
    aiIntent: 'compassionate_day_close',
    promptTemplate:
        'The user had a rough day — low mission score. Do not lecture or list what went wrong. '
        'Be brief, compassionate, and end on a forward-looking note without toxic positivity.',
    exampleOutputs: [
      'Rough one today. Rest is not giving up — it is part of the process.',
      "Today was hard. That's allowed. Tomorrow is a clean slate.",
    ],
    fallbackMessage: "Hard day. Rest, reset, and we go again tomorrow.",
    followupPolicy: 'none',
    tags: ['end_of_day', 'rough_day'],
  );

  // ── End of day — generic summary ─────────────────────────────────────────

  static const Rule ruleEndOfDaySummary = Rule(
    id: 'rule_end_of_day_summary',
    description:
        'User completed their day (generic, no strong/rough qualifier).',
    event: 'routine_day_summarized',
    conditions: [],
    priority: 4,
    cooldownSeconds: 43200,
    cooldownTopic: 'end_of_day',
    aiIntent: 'day_review',
    promptTemplate:
        'The user closed out their day. Give a brief, encouraging wrap-up based on their state.',
    exampleOutputs: [
      'Solid effort today. Rest up, we go again tomorrow.',
      'Day is done. Take whatever lessons you need and get some rest.',
    ],
    fallbackMessage: 'Day complete. Rest well!',
    followupPolicy: 'none',
    tags: ['end_of_day'],
  );

  // ── Screen time — second cap crossing ───────────────────────────────────

  static const Rule ruleScreenTimeSecondCrossing = Rule(
    id: 'rule_screen_time_second_crossing',
    description: 'User crossed a screen-time cap for the second time today.',
    event: 'bad_habit_slip_logged',
    conditions: [
      RuleCondition(field: 'metadata.crossingCount', op: 'eq', value: 2),
    ],
    priority: 1,
    cooldownSeconds: 3600,
    cooldownTopic: 'screen_time_violation',
    aiIntent: 'conversation_prompt',
    promptTemplate:
        'The user has crossed their screen-time cap for the second time today. '
        'Initiate a supportive conversation to explore what is driving the screen time '
        'and help them find a way to step away.',
    exampleOutputs: [
      "That's the second cap crossed today. What's pulling you in?",
      "Screen time is climbing. Want to talk through what's keeping you on the phone?",
    ],
    fallbackMessage:
        "That's the second cap crossed today. Want to talk about what's going on?",
    followupPolicy: 'active',
    tags: ['screen_time', 'violation', 'escalation'],
  );

  // ══════════════════════════════════════════════════════════════════════════
  // Master rule list — order does NOT matter here; priority field governs
  // selection.  More specific rules (more conditions) beat less specific ones
  // at the same priority level.
  // ══════════════════════════════════════════════════════════════════════════

  static const List<Rule> rules = [
    ruleSmokingPattern4Cigs,
    ruleMissedGymOneOff,
    ruleMissedTaskFirst,
    ruleMissedTask,
    ruleMissedTaskPattern,
    ruleMultipleSlips,
    ruleMultipleSlipsCritical,
    ruleStreakMilestone,
    ruleStreakMilestone7,
    ruleStreakMilestone30,
    ruleGhostReturn,
    ruleGhostReturnLong,
    ruleEndOfDayStrong,
    ruleEndOfDayRough,
    ruleEndOfDaySummary,
    ruleScreenTimeSecondCrossing,
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // Evaluation
  // ══════════════════════════════════════════════════════════════════════════

  /// Returns the highest-priority matching [Rule] for the given [snapshot] and
  /// [recentEvent], or `null` if no rule fires.
  ///
  /// Emits structured `[RuleEngine]` log lines for every candidate tested so
  /// the decision trail is fully auditable.
  Rule? evaluate(ContextSnapshot snapshot, EventModel recentEvent) {
    debugPrint('[RuleEngine] Evaluating ${rules.length} rules '
        'for event=${recentEvent.eventName}');
    debugPrint('[RuleEngine] Snapshot: ${snapshot.debugSummary}');

    final eligible = <Rule>[];

    for (final rule in rules) {
      // ── Event filter ───────────────────────────────────────────────────
      if (rule.event != '*' && rule.event != recentEvent.eventName) {
        debugPrint('[RuleEngine]   SKIP ${rule.id} — event mismatch '
            '(want=${rule.event})');
        continue;
      }

      // ── userState gate (minUserStateIn) ────────────────────────────────
      if (rule.minUserStateIn != null &&
          !rule.minUserStateIn!.contains(snapshot.userState)) {
        debugPrint('[RuleEngine]   SKIP ${rule.id} — '
            'userState=${snapshot.userState} not in ${rule.minUserStateIn}');
        continue;
      }

      // ── Condition evaluation ───────────────────────────────────────────
      String? failReason;
      for (final cond in rule.conditions) {
        if (!_matchesCondition(cond, snapshot, recentEvent)) {
          failReason = '${cond.field} ${cond.op} ${cond.value} FAILED '
              '(actual=${_resolveField(cond.field, snapshot, recentEvent)})';
          break;
        }
      }

      if (failReason != null) {
        debugPrint('[RuleEngine]   SKIP ${rule.id} — $failReason');
        continue;
      }

      debugPrint('[RuleEngine]   PASS ${rule.id} '
          '(priority=${rule.priority}, conditions=${rule.conditions.length})');
      eligible.add(rule);
    }

    if (eligible.isEmpty) {
      debugPrint(
          '[RuleEngine] NO RULE FIRED for event=${recentEvent.eventName}');
      return null;
    }

    // Sort: lowest priority number first; break ties by most conditions
    // (more specific); final tie-break by id for determinism.
    eligible.sort((a, b) {
      final p = a.priority.compareTo(b.priority);
      if (p != 0) return p;
      final s = b.conditions.length.compareTo(a.conditions.length);
      if (s != 0) return s;
      return a.id.compareTo(b.id);
    });

    final winner = eligible.first;
    debugPrint('[RuleEngine] FIRED: ${winner.id} '
        '(priority=${winner.priority}, '
        'intent=${winner.aiIntent}, '
        'tags=${winner.tags})');
    return winner;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Condition matching
  // ══════════════════════════════════════════════════════════════════════════

  bool _matchesCondition(
    RuleCondition condition,
    ContextSnapshot snapshot,
    EventModel recentEvent,
  ) {
    final actual = _resolveField(condition.field, snapshot, recentEvent);
    final expected = condition.value;

    switch (condition.op) {
      case 'eq':
        return actual == expected;
      case 'neq':
        return actual != expected;
      case 'gt':
        return _compare(actual, expected) > 0;
      case 'gte':
        return _compare(actual, expected) >= 0;
      case 'lt':
        return _compare(actual, expected) < 0;
      case 'lte':
        return _compare(actual, expected) <= 0;
      case 'in':
        return expected is List && expected.contains(actual);
      case 'nin':
        return expected is List && !expected.contains(actual);
      case 'contains':
        if (actual is Iterable) {
          return actual.contains(expected);
        }
        if (actual is String && expected is String) {
          return actual.contains(expected);
        }
        return false;
      case 'exists':
        return actual != null;
      case 'not_exists':
        return actual == null;
      default:
        return false;
    }
  }

  /// Resolves a dot-notation [field] path against the snapshot or event.
  /// Snapshot fields are checked first; event payload fields second.
  Object? _resolveField(
    String field,
    ContextSnapshot snapshot,
    EventModel recentEvent,
  ) {
    final snapshotMap = snapshot.toMap();
    final eventMap = <String, dynamic>{
      'eventId': recentEvent.eventId,
      'eventName': recentEvent.eventName,
      'ts': recentEvent.ts.toIso8601String(),
      'deviceLocalTs': recentEvent.deviceLocalTs.toIso8601String(),
      'source': recentEvent.source,
      'payload': recentEvent.payload,
      'metadata': recentEvent.payload['metadata'] ?? recentEvent.payload,
    };

    return _readPath(snapshotMap, field) ?? _readPath(eventMap, field);
  }

  Object? _readPath(Map<String, dynamic> root, String path) {
    Object? current = root;
    for (final segment in path.split('.')) {
      if (current is Map && current.containsKey(segment)) {
        current = current[segment];
      } else {
        return null;
      }
    }
    return current;
  }

  int _compare(Object? actual, Object? expected) {
    final a = _asNum(actual);
    final e = _asNum(expected);
    if (a != null && e != null) return a.compareTo(e);
    if (actual is Comparable && expected is Comparable) {
      try {
        return actual.compareTo(expected);
      } catch (_) {
        return -1;
      }
    }
    return -1;
  }

  num? _asNum(Object? value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }
}
