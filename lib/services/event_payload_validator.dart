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

  static void logFailure(EventPayloadValidationResult result) {
    if (result.isValid) return;
    debugPrint('[EventPayloadValidator] ${result.message}');
  }

  static final Map<String, _EventRule> _rules = {
    EventNames.userSignedUp: _EventRule.any([
      ['uid', 'userId', 'user_id', 'email'],
    ]),
    EventNames.accountDeleted: _EventRule.any([
      ['uid', 'userId', 'user_id', 'email'],
    ]),
    EventNames.onboardingCompleted: _EventRule.any([
      ['onboardingStep', 'onboarding_step'],
      ['hasCompletedOnboarding', 'has_completed_onboarding'],
    ]),
    EventNames.biometricsUpdated: _EventRule.any([
      ['old'],
      ['new'],
      ['fieldsChanged', 'fields_changed'],
    ]),
    EventNames.screenTimeSynced: _EventRule.any([
      ['logId', 'log_id'],
      ['totalMinutes', 'total_minutes'],
    ]),
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
    EventNames.badHabitSlipLogged: _habitLogRule,
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
    EventNames.streakExtended: _streakRule,
    EventNames.streakBroken: _streakRule,
    EventNames.streakMilestoneReached: _streakRule,
    EventNames.streakPaused: _streakRule,
    EventNames.streakResumed: _streakRule,
    EventNames.routineBlockCompleted: _EventRule.any([
      ['routineType', 'routine_type'],
      ['blockId', 'block_id'],
    ]),
    EventNames.routineDaySummarized: _EventRule.any([
      ['date'],
    ]),
    EventNames.routineTemplateCreated: _routineTemplateRule,
    EventNames.routineTemplateUpdated: _routineTemplateRule,
    EventNames.routineTemplateDeleted: _routineTemplateRule,
    EventNames.coachMessageSent: _EventRule.any([
      ['turnId', 'turn_id'],
      ['text'],
    ]),
    EventNames.coachReplied: _EventRule.any([
      ['turnId', 'turn_id'],
      ['text'],
    ]),
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
    EventNames.ghostDayDetected: _EventRule.any([
      ['uid', 'userId', 'user_id'],
      ['missedDays', 'missed_days'],
    ]),
    EventNames.comebackInitiated: _EventRule.any([
      ['uid', 'userId', 'user_id'],
      ['gapDays', 'gap_days'],
    ]),
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
}

class _EventRule {
  final List<List<String>> requiredAny;

  const _EventRule({required this.requiredAny});

  factory _EventRule.any(List<List<String>> requiredAny) =>
      _EventRule(requiredAny: requiredAny);
}
