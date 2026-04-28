// lib/core/constants/event_names.dart
//
// Canonical event names — single source of truth.
// Per EventSystem §2: "Names are stable forever."
// Per EventSystem §2: "snake_case, no abbreviations, past tense for things
// that already happened, present tense for active states."
//
// If an event isn't in this file, it does not exist in the system.

abstract final class EventNames {
  // ── User lifecycle ──────────────────────────────────────────────────────
  static const userSignedUp = 'user_signed_up';
  static const accountDeleted = 'account_deleted';

  // ── Onboarding ──────────────────────────────────────────────────────────
  static const onboardingCompleted = 'onboarding_completed';

  // ── Biometrics ──────────────────────────────────────────────────────────
  static const biometricsUpdated = 'biometrics_updated';

  // ── Task engine ─────────────────────────────────────────────────────────
  static const taskScheduled = 'task_scheduled';
  static const taskStarted = 'task_started';
  static const taskPaused = 'task_paused';
  static const taskResumed = 'task_resumed';
  static const taskCompleted = 'task_completed';
  static const taskAbandoned = 'task_abandoned';
  static const taskDeleted = 'task_deleted';
  static const subtaskChecked = 'subtask_checked';

  // ── Habit tracking ──────────────────────────────────────────────────────
  static const habitCreated = 'habit_created';
  static const habitUpdated = 'habit_updated';
  static const goodHabitLogged = 'good_habit_logged';
  static const badHabitSlipLogged = 'bad_habit_slip_logged';
  static const habitLogDeleted = 'habit_log_deleted';
  static const slipStreakDetected = 'slip_streak_detected';

  // ── Streaks ─────────────────────────────────────────────────────────────
  static const streakExtended = 'streak_extended';
  static const streakBroken = 'streak_broken';
  static const streakMilestoneReached = 'streak_milestone_reached';
  static const streakPaused = 'streak_paused';
  static const streakResumed = 'streak_resumed';

  // ── Routine ─────────────────────────────────────────────────────────────
  static const routineBlockCompleted = 'routine_block_completed';
  static const routineDaySummarized = 'routine_day_summarized';

  // ── Coach ───────────────────────────────────────────────────────────────
  static const coachMessageSent = 'coach_message_sent';
  static const coachReplied = 'coach_replied';

  // ── Suggestions ─────────────────────────────────────────────────────────
  static const suggestionGenerated = 'suggestion_generated';
  static const suggestionAccepted = 'suggestion_accepted';
  static const suggestionDismissed = 'suggestion_dismissed';

  // ── Notifications ───────────────────────────────────────────────────────
  static const notificationScheduled = 'notification_scheduled';
  static const notificationSent = 'notification_sent';
  static const notificationTapped = 'notification_tapped';
  static const notificationDismissed = 'notification_dismissed';
  static const notificationSuppressed = 'notification_suppressed';

  // ── Identity ────────────────────────────────────────────────────────────
  static const identityProgressChanged = 'identity_progress_changed';
  static const milestoneCompleted = 'milestone_completed';

  // ── Day lifecycle ───────────────────────────────────────────────────────
  static const dayStarted = 'day_started';
  static const dayClosed = 'day_closed';

  // ── Engagement ──────────────────────────────────────────────────────────
  static const ghostDayDetected = 'ghost_day_detected';
  static const comebackInitiated = 'comeback_initiated';
}
