import '../models/coach_rule.dart';
import '../models/context_snapshot.dart';
import '../models/event_model.dart';

class RuleEngineService {
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
    fallbackMessage: 'That makes 4 today. Want to talk through what is going on?',
    followupPolicy: 'none',
  );

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
        'The user missed today\'s gym session. Treat it as a one-off and ask one open question.',
    exampleOutputs: [
      'No gym today. Was it just one of those days?',
      'Missed the session today. Want to reschedule it or call it rest?',
    ],
    fallbackMessage: 'Missed today\'s gym. Want to reschedule or take it as rest?',
    followupPolicy: 'none',
  );

  static const List<Rule> rules = [
    ruleSmokingPattern4Cigs,
    ruleMissedGymOneOff,
  ];

  Rule? evaluate(ContextSnapshot snapshot, EventModel recentEvent) {
    final eligible = rules.where((rule) {
      if (rule.event != '*' && rule.event != recentEvent.eventName) {
        return false;
      }

      return rule.conditions.every(
        (condition) => _matchesCondition(condition, snapshot, recentEvent),
      );
    }).toList();

    if (eligible.isEmpty) return null;

    eligible.sort((a, b) {
      final priorityCompare = a.priority.compareTo(b.priority);
      if (priorityCompare != 0) return priorityCompare;

      final specificityCompare = b.conditions.length.compareTo(a.conditions.length);
      if (specificityCompare != 0) return specificityCompare;

      return a.id.compareTo(b.id);
    });

    return eligible.first;
  }

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
        if (actual is Iterable) return actual.contains(expected);
        if (actual is String && expected is String) return actual.contains(expected);
        return false;
      default:
        return false;
    }
  }

  Object? _resolveField(
    String field,
    ContextSnapshot snapshot,
    EventModel recentEvent,
  ) {
    final snapshotMap = snapshot.toMap();
    final eventMap = {
      'eventId': recentEvent.eventId,
      'eventName': recentEvent.eventName,
      'ts': recentEvent.ts.toIso8601String(),
      'deviceLocalTs': recentEvent.deviceLocalTs.toIso8601String(),
      'source': recentEvent.source,
      'payload': recentEvent.payload,
      'metadata': recentEvent.payload['metadata'] ?? recentEvent.payload,
    };

    final fromSnapshot = _readPath(snapshotMap, field);
    if (fromSnapshot != null) return fromSnapshot;

    return _readPath(eventMap, field);
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
    final actualNum = _asNum(actual);
    final expectedNum = _asNum(expected);
    if (actualNum != null && expectedNum != null) {
      return actualNum.compareTo(expectedNum);
    }

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
