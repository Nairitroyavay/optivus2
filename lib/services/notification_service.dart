// lib/services/notification_service.dart
//
// NotificationService — V1
//
// Responsibilities:
//   1. Initialise and hold the FlutterLocalNotificationsPlugin.
//   2. Expose typed schedule helpers for each V1 notification category.
//   3. Persist a ScheduledNotification doc to
//      /users/{uid}/scheduled_notifications/{notifId} for every scheduled intent.
//
// All scheduling is done via zonedSchedule so the same code path is exercised
// for immediate ("fire ASAP") and future notifications alike.  Immediate ones
// use a 1-second lead time.
//
// This service is stateless except for the plugin initialisation flag — all
// Firestore interaction goes through its own FirebaseFirestore instance.

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../core/constants/event_names.dart';
import '../core/utils/device_id.dart';
import '../models/event_model.dart';
import '../models/scheduled_notification_model.dart';
import '../models/task_model.dart';

// ── Android notification channels ──────────────────────────────────────────

const _kTaskChannel = AndroidNotificationDetails(
  'task_reminders',
  'Task Reminders',
  channelDescription: 'Reminders for upcoming and in-progress tasks',
  importance: Importance.high,
  priority: Priority.high,
);

const _kHabitChannel = AndroidNotificationDetails(
  'habit_reminders',
  'Habit & Streak Reminders',
  channelDescription: 'Streak milestones and slip-recovery nudges',
  importance: Importance.defaultImportance,
  priority: Priority.defaultPriority,
);

const _kDarwinDetails = DarwinNotificationDetails();

final _kTaskNotifDetails = NotificationDetails(
  android: _kTaskChannel,
  iOS: _kDarwinDetails,
  macOS: _kDarwinDetails,
);

final _kHabitNotifDetails = NotificationDetails(
  android: _kHabitChannel,
  iOS: _kDarwinDetails,
  macOS: _kDarwinDetails,
);

// ─────────────────────────────────────────────────────────────────────────────

class NotificationBudgetDecision {
  final bool allowed;
  final String? reason;
  final int dailyNotificationBudget;
  final int notificationsSentToday;
  final bool quietDayMode;

  const NotificationBudgetDecision({
    required this.allowed,
    this.reason,
    required this.dailyNotificationBudget,
    required this.notificationsSentToday,
    required this.quietDayMode,
  });
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore;

  bool _isInitialized = false;

  NotificationService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_isInitialized) return;

    if (!kIsWeb) {
      tz.initializeTimeZones();

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      final darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      await _plugin.initialize(
        settings: InitializationSettings(
          android: androidSettings,
          iOS: darwinSettings,
          macOS: darwinSettings,
        ),
      );

      if (Platform.isAndroid) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
    }

    _isInitialized = true;
    debugPrint('[NotificationService] Initialized.');
  }

  // ── V1 typed schedule helpers ─────────────────────────────────────────────

  /// Schedule a task-reminder 5 minutes before [task.plannedStart].
  ///
  /// Persists a `task_reminder` doc to Firestore for the authenticated user.
  Future<bool> scheduleTaskReminder(TaskModel task, String uid) async {
    final fireAt = task.plannedStart.subtract(const Duration(minutes: 5));

    return _scheduleAndPersist(
      uid: uid,
      notifId: _makeId(NotifCategory.taskReminder, task.id, fireAt),
      category: NotifCategory.taskReminder,
      title: '⏰ Upcoming: ${task.title}',
      body: 'Starts in 5 minutes.',
      scheduledFor: fireAt,
      details: _kTaskNotifDetails,
      taskId: task.id,
      intentDescription: 'task_reminder_${task.id}',
    );
  }

  /// Schedule a task-end reminder that fires at [task.plannedEnd].
  ///
  /// Intent: prompt the user to mark the task complete if it was started but
  /// not yet finished.  Persists a `task_end_reminder` doc to Firestore.
  Future<bool> scheduleTaskEndReminder(TaskModel task, String uid) async {
    final fireAt = task.plannedEnd;

    return _scheduleAndPersist(
      uid: uid,
      notifId: _makeId(NotifCategory.taskEndReminder, task.id, fireAt),
      category: NotifCategory.taskEndReminder,
      title: '✅ Time\'s up: ${task.title}',
      body: 'Your scheduled block just ended — did you finish?',
      scheduledFor: fireAt,
      details: _kTaskNotifDetails,
      taskId: task.id,
      intentDescription: 'task_end_reminder_${task.id}',
    );
  }

  /// Cancel a previously scheduled task-end reminder.
  ///
  /// Intent: clean up the notification if the user completes or abandons
  /// the task before [plannedEnd]. Updates the Firestore doc status to 'cancelled'.
  Future<void> cancelTaskEndReminder(TaskModel task, String uid) async {
    final fireAt = task.plannedEnd;
    final notifId = _makeId(NotifCategory.taskEndReminder, task.id, fireAt);

    await _cancelAndPersist(uid: uid, notifId: notifId);
  }

  /// Fire a congratulatory streak-milestone notification immediately.
  ///
  /// [milestone] is the streak day count (7, 14, 21, 30 …).
  Future<bool> scheduleStreakMilestone({
    required String uid,
    required String habitId,
    required int milestone,
    bool isCritical = false,
  }) async {
    final fireAt = DateTime.now().add(const Duration(seconds: 1));

    return _scheduleAndPersist(
      uid: uid,
      notifId: _makeId(NotifCategory.streakMilestone, habitId, fireAt),
      category: NotifCategory.streakMilestone,
      title: '🔥 $milestone-day streak!',
      body: 'You\'re on a $milestone-day streak. Keep the momentum going!',
      scheduledFor: fireAt,
      details: _kHabitNotifDetails,
      habitId: habitId,
      intentDescription: 'streak_milestone_$habitId',
      isCritical: isCritical,
    );
  }

  /// Fire a slip-recovery nudge immediately after a bad-habit slip is logged.
  Future<bool> scheduleSlipRecovery({
    required String uid,
    required String habitId,
    required String habitName,
  }) async {
    final fireAt = DateTime.now().add(const Duration(seconds: 1));

    return _scheduleAndPersist(
      uid: uid,
      notifId: _makeId(NotifCategory.slipRecovery, habitId, fireAt),
      category: NotifCategory.slipRecovery,
      title: '💪 Slip noted — you\'ve got this',
      body: 'You logged a $habitName slip. Every day is a fresh start.',
      scheduledFor: fireAt,
      details: _kHabitNotifDetails,
      habitId: habitId,
      intentDescription: 'slip_recovery_$habitId',
    );
  }

  Future<void> ensureNotificationSettings(String uid) async {
    final today = _todayString();
    final profileRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('profile')
        .doc('main');

    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(profileRef);
      final data = snap.data() ?? <String, dynamic>{};
      final lastBudgetDate = data['notificationBudgetDate'] as String?;

      transaction.set(
        profileRef,
        {
          'dailyNotificationBudget':
              _asNonNegativeInt(data['dailyNotificationBudget'], fallback: 3),
          'notificationsSentToday': lastBudgetDate == today
              ? _asNonNegativeInt(data['notificationsSentToday'])
              : 0,
          'quietDayMode': data['quietDayMode'] as bool? ?? false,
          'notificationBudgetDate': today,
          'updatedAt': FieldValue.serverTimestamp(),
          'schemaVersion': 1,
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<NotificationBudgetDecision> reserveNotificationSlot({
    required String uid,
    required String intentDescription,
    required String category,
    String? triggerEventId,
    String? notifId,
    String? taskId,
    String? habitId,
    bool isCritical = false,
  }) async {
    final today = _todayString();
    final profileRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('profile')
        .doc('main');

    final decision = await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(profileRef);
      final data = snap.data() ?? <String, dynamic>{};
      final lastBudgetDate = data['notificationBudgetDate'] as String?;
      final sentToday = lastBudgetDate == today
          ? _asNonNegativeInt(data['notificationsSentToday'])
          : 0;
      final dailyBudget =
          _asNonNegativeInt(data['dailyNotificationBudget'], fallback: 3);
      final quietDayMode = data['quietDayMode'] as bool? ?? false;

      String? reason;
      if (!isCritical && quietDayMode) {
        reason = 'quiet_day_mode';
      } else if (!isCritical && sentToday >= dailyBudget) {
        reason = 'budget_exhausted';
      }

      final basePatch = <String, dynamic>{
        'dailyNotificationBudget': dailyBudget,
        'quietDayMode': quietDayMode,
        'notificationBudgetDate': today,
        'updatedAt': FieldValue.serverTimestamp(),
        'schemaVersion': 1,
      };

      if (reason != null) {
        transaction.set(
          profileRef,
          {
            ...basePatch,
            'notificationsSentToday': sentToday,
          },
          SetOptions(merge: true),
        );

        return NotificationBudgetDecision(
          allowed: false,
          reason: reason,
          dailyNotificationBudget: dailyBudget,
          notificationsSentToday: sentToday,
          quietDayMode: quietDayMode,
        );
      }

      transaction.set(
        profileRef,
        {
          ...basePatch,
          'notificationsSentToday': sentToday + 1,
        },
        SetOptions(merge: true),
      );

      return NotificationBudgetDecision(
        allowed: true,
        dailyNotificationBudget: dailyBudget,
        notificationsSentToday: sentToday + 1,
        quietDayMode: quietDayMode,
      );
    });

    if (!decision.allowed) {
      await writeSuppressionEvent(
        uid: uid,
        reason: decision.reason ?? 'unknown',
        intentDescription: intentDescription,
        category: category,
        triggerEventId: triggerEventId,
        notifId: notifId,
        taskId: taskId,
        habitId: habitId,
        dailyNotificationBudget: decision.dailyNotificationBudget,
        notificationsSentToday: decision.notificationsSentToday,
        quietDayMode: decision.quietDayMode,
      );
    }

    return decision;
  }

  Future<void> writeSuppressionEvent({
    required String uid,
    required String reason,
    required String intentDescription,
    required String category,
    String? triggerEventId,
    String? notifId,
    String? taskId,
    String? habitId,
    int? dailyNotificationBudget,
    int? notificationsSentToday,
    bool? quietDayMode,
  }) async {
    final now = DateTime.now();
    final eventId = _makeSuppressionEventId(
      reason: reason,
      intentDescription: intentDescription,
      triggerEventId: triggerEventId,
      now: now,
    );
    final event = EventModel(
      eventId: eventId,
      eventName: EventNames.notificationSuppressed,
      uid: uid,
      ts: now,
      deviceLocalTs: now,
      deviceId: await getDeviceId(),
      source: 'notification_service',
      payload: {
        'reason': reason,
        'intent': intentDescription,
        'category': category,
        if (triggerEventId != null) 'triggerEventId': triggerEventId,
        if (notifId != null) 'notifId': notifId,
        if (taskId != null) 'taskId': taskId,
        if (habitId != null) 'habitId': habitId,
        if (dailyNotificationBudget != null)
          'dailyNotificationBudget': dailyNotificationBudget,
        if (notificationsSentToday != null)
          'notificationsSentToday': notificationsSentToday,
        if (quietDayMode != null) 'quietDayMode': quietDayMode,
      },
      schemaVersion: 1,
    );

    final eventDoc = event.toFirestore();
    final userRef = _firestore.collection('users').doc(uid);
    final batch = _firestore.batch();
    batch.set(userRef.collection('events').doc(eventId), eventDoc);
    batch.set(userRef.collection('events_recent').doc(eventId), eventDoc);
    await batch.commit();

    debugPrint(
      '[NotificationService] notification_suppressed reason=$reason '
      'intent=$intentDescription',
    );
  }

  // ── Low-level schedule + persist ──────────────────────────────────────────

  /// Enqueues the local notification and writes the Firestore doc atomically
  /// (best-effort — a Firestore failure never blocks the local notification).
  Future<bool> _scheduleAndPersist({
    required String uid,
    required String notifId,
    required String category,
    required String title,
    required String body,
    required DateTime scheduledFor,
    required NotificationDetails details,
    required String intentDescription,
    String? taskId,
    String? habitId,
    String? triggerEventId,
    bool isCritical = false,
  }) async {
    if (kIsWeb) {
      debugPrint('[NotificationService] $category: not supported on web.');
      return false;
    }

    if (scheduledFor.isBefore(DateTime.now())) {
      debugPrint(
        '[NotificationService] $category: skipping past time $scheduledFor',
      );
      return false;
    }

    final budgetDecision = await reserveNotificationSlot(
      uid: uid,
      intentDescription: intentDescription,
      category: category,
      triggerEventId: triggerEventId,
      notifId: notifId,
      taskId: taskId,
      habitId: habitId,
      isCritical: isCritical,
    );
    if (!budgetDecision.allowed) return false;

    if (!_isInitialized) await init();

    // ── 1. Enqueue local notification ───────────────────────────────────────
    await _plugin.zonedSchedule(
      id: notifId.hashCode & 0x7FFFFFFF, // positive int32 id
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledFor, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    debugPrint(
      '[NotificationService] Scheduled "$title" ($category) at $scheduledFor',
    );

    // ── 2. Persist intent doc to Firestore (best-effort) ───────────────────
    try {
      final notif = ScheduledNotification(
        notifId: notifId,
        category: category,
        scheduledFor: scheduledFor.toUtc(),
        taskId: taskId,
        habitId: habitId,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('scheduled_notifications')
          .doc(notifId)
          .set(notif.toFirestore(), SetOptions(merge: true));

      debugPrint(
        '[NotificationService] Persisted scheduled_notification $notifId '
        '($category)',
      );
    } catch (e) {
      debugPrint(
        '[NotificationService] Failed to persist Firestore doc for $notifId: $e',
      );
    }

    return true;
  }

  /// Cancels the local notification and marks the Firestore doc as 'cancelled'.
  Future<void> _cancelAndPersist({
    required String uid,
    required String notifId,
  }) async {
    if (!_isInitialized) await init();

    if (!kIsWeb) {
      await _plugin.cancel(id: notifId.hashCode & 0x7FFFFFFF);
      debugPrint('[NotificationService] Cancelled notification $notifId');
    }

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('scheduled_notifications')
          .doc(notifId)
          .set({
        'status': NotifStatus.cancelled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint(
        '[NotificationService] Marked scheduled_notification $notifId as cancelled',
      );
    } catch (e) {
      debugPrint(
        '[NotificationService] Failed to update Firestore doc for $notifId: $e',
      );
    }
  }

  // ── Low-level primitive (kept for internal use) ───────────────────────────

  /// Generic schedule primitive.  Prefer the typed helpers above.
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    NotificationDetails? details,
  }) async {
    if (!_isInitialized) await init();

    if (kIsWeb) {
      debugPrint('[NotificationService] Not supported on web.');
      return;
    }

    if (at.isBefore(DateTime.now())) {
      debugPrint('[NotificationService] Cannot schedule in the past: $at');
      return;
    }

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: details ?? _kTaskNotifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    debugPrint('[NotificationService] Scheduled "$title" at $at');
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  /// Deterministic notification ID:
  /// sha256(category + entityKey + scheduledFor.toUtc().toIso8601String())
  static String _makeId(
      String category, String entityKey, DateTime scheduledFor) {
    final seed =
        '$category:$entityKey:${scheduledFor.toUtc().toIso8601String()}';
    return sha256.convert(utf8.encode(seed)).toString();
  }

  static String _makeSuppressionEventId({
    required String reason,
    required String intentDescription,
    required DateTime now,
    String? triggerEventId,
  }) {
    final seed = [
      EventNames.notificationSuppressed,
      reason,
      intentDescription,
      triggerEventId ?? '',
      now.toUtc().toIso8601String(),
    ].join(':');
    return sha256.convert(utf8.encode(seed)).toString();
  }

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  static int _asNonNegativeInt(Object? value, {int fallback = 0}) {
    if (value is int) return value < 0 ? 0 : value;
    if (value is num) {
      final rounded = value.round();
      return rounded < 0 ? 0 : rounded;
    }
    return fallback;
  }
}
