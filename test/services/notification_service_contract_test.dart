// test/services/notification_service_contract_test.dart
//
// Contract tests for NotificationService.
// All groups are skipped (TODO) — implement with fake_cloud_firestore and
// mocked FlutterLocalNotificationsPlugin once those dev-dependencies are added.
//
// Public surface under test:
//   NotificationService.init()
//   NotificationService.scheduleTaskReminder(task, uid)
//   NotificationService.scheduleTaskEndReminder(task, uid)
//   NotificationService.cancelTaskEndReminder(task, uid)
//   NotificationService.scheduleStreakMilestone({uid, habitId, milestone, isCritical})
//   NotificationService.scheduleSlipRecovery({uid, habitId, habitName})
//   NotificationService.ensureNotificationSettings(uid)
//   NotificationService.reserveNotificationSlot({uid, intentDescription, category, ...})
//   NotificationService.writeSuppressionEvent({uid, reason, intentDescription, ...})
//
// Firestore paths:
//   /users/{uid}/scheduled_notifications/{notifId}
//   /users/{uid}/profile/main  (budget counters)
//   /users/{uid}/events/{eventId}
//   /users/{uid}/events_recent/{eventId}

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── init ─────────────────────────────────────────────────────────────────────

  group('NotificationService.init', () {
    test(
      'TODO: sets _isInitialized to true after first call',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: calling init() a second time is a no-op (idempotent)',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── scheduleTaskReminder ──────────────────────────────────────────────────────

  group('NotificationService.scheduleTaskReminder — happy path', () {
    test(
      'TODO: schedules a local notification 5 minutes before task.plannedStart',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: persists a task_reminder doc to /scheduled_notifications/{notifId}',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: returns true when notification is scheduled successfully',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: returns false and does not schedule when fireAt is in the past',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── scheduleTaskEndReminder ───────────────────────────────────────────────────

  group('NotificationService.scheduleTaskEndReminder — happy path', () {
    test(
      'TODO: schedules a local notification at task.plannedEnd',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: persists a task_end_reminder doc to /scheduled_notifications/{notifId}',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── cancelTaskEndReminder ─────────────────────────────────────────────────────

  group('NotificationService.cancelTaskEndReminder — happy path', () {
    test(
      'TODO: cancels the local notification by notifId',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: updates Firestore doc status to cancelled',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── scheduleStreakMilestone ───────────────────────────────────────────────────

  group('NotificationService.scheduleStreakMilestone — happy path', () {
    test(
      'TODO: schedules a local notification ~1 second from now',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: persists a streak_milestone doc to /scheduled_notifications/{notifId}',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── scheduleSlipRecovery ──────────────────────────────────────────────────────

  group('NotificationService.scheduleSlipRecovery — happy path', () {
    test(
      'TODO: schedules a slip-recovery local notification ~1 second from now',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: persists a slip_recovery doc to /scheduled_notifications/{notifId}',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── ensureNotificationSettings ────────────────────────────────────────────────

  group('NotificationService.ensureNotificationSettings', () {
    test(
      'TODO: creates profile/main doc with dailyNotificationBudget: 3 when absent',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: resets notificationsSentToday to 0 when notificationBudgetDate < today',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: preserves notificationsSentToday when notificationBudgetDate == today',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── reserveNotificationSlot ───────────────────────────────────────────────────

  group('NotificationService.reserveNotificationSlot — allowed', () {
    test(
      'TODO: returns allowed: true when sentToday < dailyBudget and quietDayMode is false',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: increments notificationsSentToday by 1 when slot is reserved',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('NotificationService.reserveNotificationSlot — suppressed', () {
    test(
      'TODO: returns allowed: false with reason budget_exhausted when sentToday >= budget',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: returns allowed: false with reason quiet_day_mode when quietDayMode is true',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: isCritical: true bypasses budget_exhausted and quiet_day_mode checks',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: writes a suppression event doc when slot is denied',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── writeSuppressionEvent ─────────────────────────────────────────────────────

  group('NotificationService.writeSuppressionEvent', () {
    test(
      'TODO: writes notification_suppressed event to /events/{eventId}',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: writes same event to /events_recent/{eventId} in the same batch',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: event payload contains reason, intent, category, and dailyNotificationBudget',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: eventId is deterministic (sha256 of reason + intent + triggerEventId + ts)',
      () {},
      skip: 'Not yet implemented',
    );
  });
}
