// lib/core/errors/app_errors.dart
//
// Typed error hierarchy for all Optivus services.
// Per ServiceContracts — every error has a machine-readable code
// and a human-readable message.

// ── Base ─────────────────────────────────────────────────────────────────────

/// Root of the Optivus error hierarchy.
abstract class AppError implements Exception {
  final String code;
  final String message;
  const AppError(this.code, this.message);

  @override
  String toString() => '$runtimeType($code): $message';
}

// ── Auth ─────────────────────────────────────────────────────────────────────

class NotAuthenticatedError extends AppError {
  const NotAuthenticatedError()
      : super('not_authenticated', 'No authenticated user. Redirect to login.');
}

// ── EventService (§1.5) ─────────────────────────────────────────────────────

class EventValidationError extends AppError {
  EventValidationError(String detail)
      : super('event_validation', detail);
}

class EventDuplicateError extends AppError {
  final String eventId;
  EventDuplicateError(this.eventId)
      : super('event_duplicate',
            'Event $eventId already exists. Safe to ignore — idempotent.');
}

// ── TaskService (§2.5) ──────────────────────────────────────────────────────

class TaskNotFoundError extends AppError {
  TaskNotFoundError(String taskId)
      : super('task_not_found', 'Task $taskId does not exist.');
}

class InvalidStateTransitionError extends AppError {
  InvalidStateTransitionError({
    required String taskId,
    required String currentState,
    required String attemptedAction,
  }) : super('invalid_state_transition',
            'Task $taskId is in "$currentState" — cannot $attemptedAction.');
}

class MultipleActiveTasksError extends AppError {
  final String activeTaskId;
  MultipleActiveTasksError(this.activeTaskId)
      : super('multiple_active_tasks',
            'Another task ($activeTaskId) is already active. Finish or pause it first.');
}

class InvalidTimeRangeError extends AppError {
  const InvalidTimeRangeError()
      : super('invalid_time_range',
            'plannedEnd must be after plannedStart.');
}

class TaskTooLongError extends AppError {
  const TaskTooLongError()
      : super('task_too_long', 'Task duration exceeds 8 hours.');
}

class TaskInPastError extends AppError {
  const TaskInPastError()
      : super('task_in_past',
            'plannedStart is more than 1 hour in the past.');
}

class SubtaskNotFoundError extends AppError {
  SubtaskNotFoundError(String subtaskId)
      : super('subtask_not_found',
            'Subtask $subtaskId does not exist on this task.');
}

// ── HabitService (§3.4) ─────────────────────────────────────────────────────

class HabitNotFoundError extends AppError {
  HabitNotFoundError(String habitId)
      : super('habit_not_found', 'Habit $habitId does not exist.');
}

class WrongHabitKindError extends AppError {
  WrongHabitKindError({required String expected, required String actual})
      : super('wrong_habit_kind',
            'Expected habit kind "$expected" but got "$actual".');
}

class HabitNotActiveError extends AppError {
  HabitNotActiveError(String habitId)
      : super('habit_not_active',
            'Habit $habitId is not active (paused or archived).');
}

class InvalidAmountError extends AppError {
  const InvalidAmountError()
      : super('invalid_amount', 'Amount must be > 0.');
}

class InvalidHabitInputError extends AppError {
  InvalidHabitInputError(String detail)
      : super('invalid_habit_input', detail);
}

class DuplicateHabitError extends AppError {
  DuplicateHabitError(String name)
      : super('duplicate_habit',
            'A habit named "$name" already exists for this user.');
}

// ── StreakService (§4.4) ─────────────────────────────────────────────────────

class StreakNotFoundError extends AppError {
  StreakNotFoundError(String habitId)
      : super('streak_not_found',
            'No streak record for habit $habitId. Should have been initialised on habit create.');
}

class DayCloseAlreadyRanError extends AppError {
  DayCloseAlreadyRanError(String date)
      : super('day_close_already_ran',
            'Day-close rollup for $date has already executed.');
}
