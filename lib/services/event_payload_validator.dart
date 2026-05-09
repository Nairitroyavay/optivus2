import 'package:flutter/foundation.dart';

import '../core/constants/event_names.dart';

class EventPayloadValidationResult {
  final bool isValid;
  final String? message;

  const EventPayloadValidationResult._(this.isValid, this.message);

  const EventPayloadValidationResult.valid() : this._(true, null);
  const EventPayloadValidationResult.invalid(String message)
      : this._(false, message);
}

class EventPayloadValidator {
  static EventPayloadValidationResult validate(
    String eventName,
    Map<String, dynamic> payload,
  ) {
    final rule = _rules[eventName];
    if (rule == null) {
      return EventPayloadValidationResult.invalid(
        'Unknown event "$eventName". Add it to EventNames and EventPayloadValidator.',
      );
    }

    if (rule is _StrictEventRule) {
      return rule.validateStrict(eventName, payload);
    }

    final missing = <String>[];
    for (final requirement in rule.requiredAny) {
      if (!requirement.any(payload.containsKey)) {
        missing.add(requirement.join(' or '));
      }
    }

    if (missing.isNotEmpty) {
      return EventPayloadValidationResult.invalid(
        'Invalid payload for "$eventName"; missing ${missing.join(', ')}.',
      );
    }

    return const EventPayloadValidationResult.valid();
  }

  static bool isValid(String eventName, Map<String, dynamic> payload) =>
      validate(eventName, payload).isValid;

  @visibleForTesting
  static bool hasRule(String eventName) => _rules.containsKey(eventName);

  static void logFailure(EventPayloadValidationResult result) {
    if (result.isValid) return;
    debugPrint('[EventPayloadValidator] ${result.message}');
  }

  static final Map<String, _EventRule> _rules = {
    EventNames.userSignedUp: _EventRule.any([
      ['uid', 'userId', 'user_id', 'email'],
    ]),
    EventNames.accountDeleted: _StrictEventRule(
      requiredAny: [
        ['uid', 'userId', 'user_id', 'email']
      ],
      allowedFields: {
        'uid': (v) => v is String,
        'userId': (v) => v is String,
        'user_id': (v) => v is String,
        'email': (v) => v is String,
        'deletedAt': (v) => v is String,
        'deleted_at': (v) => v is String,
        'scheduledPurgeAt': (v) => v is String,
        'scheduled_purge_at': (v) => v is String,
      },
    ),
    EventNames.onboardingCompleted: _EventRule.any([
      ['onboardingStep', 'onboarding_step'],
      ['hasCompletedOnboarding', 'has_completed_onboarding'],
    ]),
    EventNames.biometricsUpdated: _EventRule.any([
      ['old'],
      ['new'],
      ['fieldsChanged', 'fields_changed'],
    ]),
    EventNames.screenTimeSynced: _StrictEventRule(
      requiredAny: [
        ['logId', 'log_id'],
        ['totalMinutes', 'total_minutes']
      ],
      allowedFields: {
        'logId': (v) => v is String,
        'log_id': (v) => v is String,
        'totalMinutes': (v) => v is int || v is num,
        'total_minutes': (v) => v is int || v is num,
      },
    ),
    EventNames.taskScheduled: _taskRule,
    EventNames.taskStarted: _taskRule,
    EventNames.taskPaused: _taskRule,
    EventNames.taskResumed: _taskRule,
    EventNames.taskCompleted: _taskRule,
    EventNames.taskAbandoned: _taskRule,
    EventNames.taskSkipped: _taskRule,
    EventNames.taskDeleted: _EventRule.any([
      ['taskId', 'task_id'],
    ]),
    EventNames.subtaskChecked: _subtaskRule,
    EventNames.subtaskUnchecked: _subtaskRule,
    EventNames.habitCreated: _habitRule,
    EventNames.habitUpdated: _habitRule,
    EventNames.habitPaused: _habitRule,
    EventNames.habitResumed: _habitRule,
    EventNames.goodHabitLogged: _habitLogRule,
    EventNames.badHabitSlipLogged: _badHabitSlipRule,
    EventNames.habitLogDeleted: _EventRule.any([
      ['habitId', 'habit_id'],
      ['logId', 'log_id'],
    ]),
    EventNames.habitArchived: _habitRule,
    EventNames.habitDeleted: _habitRule,
    EventNames.slipStreakDetected: _EventRule.any([
      ['habitId', 'habit_id'],
      ['count'],
    ]),
    EventNames.slipLogDismissed: _StrictEventRule(
      requiredAny: [
        ['logId', 'log_id'],
        ['habitId', 'habit_id']
      ],
      allowedFields: {
        'logId': (v) => v is String,
        'log_id': (v) => v is String,
        'habitId': (v) => v is String,
        'habit_id': (v) => v is String,
        'habitName': (v) => v is String,
        'dismissedAt': (v) => v is String,
      },
    ),
    EventNames.streakExtended: _streakRule,
    EventNames.streakBroken: _streakRule,
    EventNames.streakMilestoneReached: _streakRule,
    EventNames.streakPaused: _streakRule,
    EventNames.streakResumed: _streakRule,
    EventNames.routineBlockCompleted: _EventRule.any([
      ['routineType', 'routine_type'],
      ['blockId', 'block_id', 'taskId', 'task_id', 'routineId', 'routine_id'],
    ]),
    EventNames.routineDaySummarized: _EventRule.any([
      ['date'],
    ]),
    EventNames.routineWindowMissed: _EventRule.any([
      ['routine', 'routineType', 'routine_type'],
      ['completion', 'completionPct', 'completion_pct'],
    ]),
    EventNames.routineTemplateCreated: _routineTemplateRule,
    EventNames.routineTemplateUpdated: _routineTemplateRule,
    EventNames.routineTemplateDeleted: _routineTemplateRule,
    EventNames.coachMessageSent: _EventRule.any([
      ['turnId', 'turn_id', 'text'],
    ]),
    EventNames.coachReplied: _EventRule.any([
      ['turnId', 'turn_id', 'text'],
    ]),
    EventNames.coachReEnabled: _StrictEventRule(
      requiredAny: [
        ['reason']
      ],
      allowedFields: {
        'reason': (v) => v is String,
      },
    ),
    EventNames.suggestionGenerated: _suggestionRule,
    EventNames.suggestionAccepted: _suggestionRule,
    EventNames.suggestionDismissed: _suggestionRule,
    EventNames.notificationScheduled: _notificationRule,
    EventNames.notificationSent: _notificationRule,
    EventNames.notificationTapped: _notificationRule,
    EventNames.notificationDismissed: _notificationRule,
    EventNames.notificationSuppressed: _EventRule.any([
      ['reason'],
    ]),
    EventNames.notificationMissed: _StrictEventRule(
      requiredAny: [
        ['notifId', 'notif_id', 'notificationId', 'notification_id']
      ],
      allowedFields: {
        'notifId': (v) => v is String,
        'notif_id': (v) => v is String,
        'notificationId': (v) => v is String,
        'notification_id': (v) => v is String,
        'category': (v) => v is String,
        'status': (v) => v is String,
      },
    ),
    EventNames.identityCreated: _identityRule,
    EventNames.identityUpdated: _identityRule,
    EventNames.identityPaused: _identityRule,
    EventNames.identityArchived: _identityRule,
    EventNames.identityHabitLinked: _EventRule.any([
      ['goalId', 'goal_id', 'identityId', 'identity_id'],
      ['habitId', 'habit_id'],
    ]),
    EventNames.identityProgressChanged: _EventRule.any([
      ['score', 'newPct', 'new_pct'],
      ['triggerEventId', 'trigger_event_id', 'identityId', 'identity_id'],
    ]),
    EventNames.milestoneCompleted: _EventRule.any([
      ['milestoneId', 'milestone_id'],
    ]),
    EventNames.dayStarted: _EventRule.any([
      ['date'],
    ]),
    EventNames.dayClosed: _EventRule.any([
      ['date'],
    ]),
    EventNames.badDayDetected: _StrictEventRule(
      requiredAny: [
        ['date']
      ],
      allowedFields: {
        'date': (v) => v is String,
      },
    ),
    EventNames.ghostDayDetected: _EventRule.any([
      ['uid', 'userId', 'user_id'],
      ['missedDays', 'missed_days'],
    ]),
    EventNames.comebackInitiated: _EventRule.any([
      ['uid', 'userId', 'user_id'],
      ['gapDays', 'gap_days'],
    ]),
    EventNames.comebackPathChosen: _StrictEventRule(
      requiredAny: [
        ['path'],
      ],
      allowedFields: {
        'path': (v) =>
            v == 'gentle' || v == 'easy' || v == 'half' || v == 'full',
        'gapDays': (v) => v is int || v is num,
        'gap_days': (v) => v is int || v is num,
      },
    ),
    EventNames.weeklyInsightReady: _StrictEventRule(
      requiredAny: [
        ['insightId', 'insight_id']
      ],
      allowedFields: {
        'insightId': (v) => v is String,
        'insight_id': (v) => v is String,
      },
    ),
    EventNames.fitnessActivityStarted: _fitnessActivityRule,
    EventNames.fitnessActivityPaused: _fitnessActivityRule,
    EventNames.fitnessActivityResumed: _fitnessActivityRule,
    EventNames.fitnessActivityCompleted: _fitnessActivityRule,
    EventNames.runningActivityCompleted: _fitnessActivityRule,
    EventNames.walkingActivityCompleted: _fitnessActivityRule,
    EventNames.cyclingActivityCompleted: _fitnessActivityRule,
    EventNames.hikingActivityCompleted: _fitnessActivityRule,
    EventNames.swimmingActivityCompleted: _fitnessActivityRule,
    EventNames.gymActivityCompleted: _fitnessActivityRule,
    EventNames.fitnessActivityCancelled: _fitnessActivityRule,
    EventNames.fitnessActivityDiscarded: _fitnessActivityRule,
    EventNames.routeTrackingStarted: _fitnessActivityRule,
    EventNames.routeTrackingStopped: _fitnessActivityRule,
    EventNames.routeSaved: _fitnessActivityRule,
    EventNames.routeReviewOpened: _fitnessActivityRule,
    EventNames.fitnessGoalCreated: _fitnessGoalRule,
    EventNames.fitnessGoalProgressUpdated: _fitnessGoalRule,
    EventNames.fitnessGoalCompleted: _fitnessGoalRule,
    EventNames.weeklyDistanceGoalCompleted: _EventRule.any([
      ['goalId', 'goal_id'],
    ]),
    EventNames.fitnessStreakUpdated: _EventRule.any([
      ['streakId', 'streak_id'],
    ]),
    EventNames.fitnessAiFeedbackRequested: _fitnessActivityRule,
    EventNames.fitnessAiFeedbackGenerated: _fitnessActivityRule,
    EventNames.routineFitnessStarted: _routineFitnessRule,
    EventNames.routineFitnessCompleted: _routineFitnessRule,
  };

  static final _taskRule = _EventRule.any([
    ['taskId', 'task_id'],
    ['type'],
  ]);

  static final _subtaskRule = _EventRule.any([
    ['taskId', 'task_id'],
    ['subtaskId', 'subtask_id'],
  ]);

  static final _habitRule = _EventRule.any([
    ['habitId', 'habit_id'],
  ]);

  static final _habitLogRule = _EventRule.any([
    ['habitId', 'habit_id'],
    ['logId', 'log_id', 'occurredAt', 'ts'],
  ]);

  static final _badHabitSlipRule = _EventRule.any([
    [
      'habitId',
      'habit_id',
      'packageName',
      'package_name',
      'screenTimeLogId',
      'screen_time_log_id',
    ],
    ['logId', 'log_id', 'occurredAt', 'ts'],
  ]);

  static final _streakRule = _EventRule.any([
    ['habitId', 'habit_id'],
  ]);

  static final _routineTemplateRule = _EventRule.any([
    ['templateId', 'template_id'],
    ['routineType', 'routine_type'],
  ]);

  static final _suggestionRule = _EventRule.any([
    ['suggestionId', 'suggestion_id'],
  ]);

  static final _notificationRule = _EventRule.any([
    ['notifId', 'notif_id', 'notificationId', 'notification_id'],
    ['category'],
  ]);

  static final _identityRule = _EventRule.any([
    ['goalId', 'goal_id', 'identityId', 'identity_id'],
  ]);

  static final _fitnessActivityRule = _EventRule.any([
    ['activityId', 'activity_id'],
    ['activityType', 'activity_type'],
  ]);

  static final _fitnessGoalRule = _EventRule.any([
    ['goalId', 'goal_id'],
    ['goalType', 'goal_type'],
  ]);

  static final _routineFitnessRule = _EventRule.any([
    ['activityId', 'activity_id'],
    ['activityType', 'activity_type'],
    ['routineTaskId', 'routine_task_id'],
  ]);
}

class _EventRule {
  final List<List<String>> requiredAny;

  const _EventRule({required this.requiredAny});

  factory _EventRule.any(List<List<String>> requiredAny) =>
      _EventRule(requiredAny: requiredAny);
}

class _StrictEventRule extends _EventRule {
  final Map<String, bool Function(dynamic)> allowedFields;

  const _StrictEventRule({
    required super.requiredAny,
    required this.allowedFields,
  });

  EventPayloadValidationResult validateStrict(
      String eventName, Map<String, dynamic> payload) {
    final missing = <String>[];
    final wrongType = <String>[];
    final unknown = <String>[];

    final finalAllowed = {...allowedFields.keys, 'priority'};

    for (final key in payload.keys) {
      if (!finalAllowed.contains(key)) {
        unknown.add(key);
      }
    }

    for (final requirement in requiredAny) {
      if (!requirement.any(payload.containsKey)) {
        missing.add(requirement.join(' or '));
      }
    }

    for (final entry in payload.entries) {
      final key = entry.key;
      final val = entry.value;

      if (key == 'priority') {
        if (val is! String) wrongType.add(key);
        continue;
      }

      if (allowedFields.containsKey(key)) {
        if (!allowedFields[key]!(val)) {
          wrongType.add(key);
        }
      }
    }

    final errors = <String>[];
    if (missing.isNotEmpty) {
      errors.add('missing ${missing.join(', ')}');
    }
    if (wrongType.isNotEmpty) {
      errors.add('wrong type for ${wrongType.join(', ')}');
    }

    if (errors.isNotEmpty) {
      return EventPayloadValidationResult.invalid(
        'Invalid payload for "$eventName"; ${errors.join(', ')}.',
      );
    }

    if (unknown.isNotEmpty) {
      final msg =
          'Unknown fields in payload for "$eventName": ${unknown.join(', ')}.';
      if (kDebugMode) {
        return EventPayloadValidationResult.invalid(msg);
      } else {
        debugPrint('[EventPayloadValidator] $msg');
        return const EventPayloadValidationResult.valid();
      }
    }

    return const EventPayloadValidationResult.valid();
  }
}
