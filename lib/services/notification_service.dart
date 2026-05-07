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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../core/constants/event_names.dart';
import '../core/utils/device_id.dart';
import '../models/event_model.dart';
import '../models/scheduled_notification_model.dart';
import '../models/task_model.dart';
import 'event_service.dart';

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
  final FlutterLocalNotificationsPlugin _plugin;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final EventService? _eventService;

  bool _isInitialized = false;
  Future<void>? _reRegisterInFlight;
  final Set<String> _reRegisteredNotificationKeys = <String>{};

  NotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    EventService? eventService,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _eventService = eventService;

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
        notificationCategories: [
          DarwinNotificationCategory(
            'optivus_category',
            actions: [
              DarwinNotificationAction.plain('id_1', 'Action 1'),
              DarwinNotificationAction.plain('id_2', 'Action 2',
                  options: {DarwinNotificationActionOption.destructive}),
              DarwinNotificationAction.plain('id_3', 'Action 3',
                  options: {DarwinNotificationActionOption.foreground}),
            ],
            options: {DarwinNotificationCategoryOption.customDismissAction},
          ),
        ],
      );

      await _plugin.initialize(
        settings: InitializationSettings(
          android: androidSettings,
          iOS: darwinSettings,
          macOS: darwinSettings,
        ),
        onDidReceiveNotificationResponse: _handleNotificationResponse,
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

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    if (!_isInitialized) await init();

    if (Platform.isIOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return granted ?? false;
    } else if (Platform.isMacOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return granted ?? false;
    } else if (Platform.isAndroid) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return granted ?? false;
    }
    return false;
  }

  // ── V1 typed schedule helpers ─────────────────────────────────────────────

  /// Schedule a task-reminder 5 minutes before [task.plannedStart].
  Future<bool> scheduleTaskReminder(TaskModel task, String uid) async {
    final fireAt = task.plannedStart.subtract(const Duration(minutes: 5));
    final dateStr = _formatDate(fireAt);
    final timeStr = _formatTime(fireAt);
    final dedupeTemplateId = task.parentRoutine ?? task.id;

    return _scheduleAndPersist(
      uid: uid,
      notifId: _makeDeterministicId(
        dedupeTemplateId,
        dateStr,
        timeStr,
        NotifCategory.taskReminder,
      ),
      category: NotifCategory.taskReminder,
      title: '⏰ Upcoming: ${task.title}',
      body: 'Starts in 5 minutes.',
      scheduledFor: fireAt,
      details: _kTaskNotifDetails,
      taskId: task.id,
      routineTemplateId: dedupeTemplateId,
      scheduledDate: dateStr,
      scheduledTime: timeStr,
      intentDescription: 'task_reminder_${task.id}',
    );
  }

  /// Schedule a task-end reminder that fires at [task.plannedEnd].
  Future<bool> scheduleTaskEndReminder(TaskModel task, String uid) async {
    final fireAt = task.plannedEnd;
    final dateStr = _formatDate(fireAt);
    final timeStr = _formatTime(fireAt);
    final dedupeTemplateId = task.parentRoutine ?? task.id;

    return _scheduleAndPersist(
      uid: uid,
      notifId: _makeDeterministicId(
        dedupeTemplateId,
        dateStr,
        timeStr,
        NotifCategory.taskEndReminder,
      ),
      category: NotifCategory.taskEndReminder,
      title: '✅ Time\'s up: ${task.title}',
      body: 'Your scheduled block just ended — did you finish?',
      scheduledFor: fireAt,
      details: _kTaskNotifDetails,
      taskId: task.id,
      routineTemplateId: dedupeTemplateId,
      scheduledDate: dateStr,
      scheduledTime: timeStr,
      intentDescription: 'task_end_reminder_${task.id}',
    );
  }

  /// New consolidated task scheduling method.
  Future<void> scheduleForTask(TaskModel task) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // TODO: Support alarmTier logic here.
    await scheduleTaskReminder(task, uid);
    await scheduleTaskEndReminder(task, uid);
  }

  Future<void> scheduleForRoutineTemplate(
    Map<String, dynamic> template,
    DateTime date,
    String uid,
  ) async {
    final templateId = _asString(template['routineTemplateId']) ??
        _asString(template['templateId']) ??
        _asString(template['id']) ??
        'unknown';
    final startTime = _asString(template['startTime']) ??
        _asString(template['scheduledTime']) ??
        _asString(template['time']) ??
        '09:00';
    final title = _asString(template['title']) ?? 'Routine task';
    final category = _asString(template['category']) ??
        _asString(template['routineType']) ??
        'routine';

    final fireAt = _dateTimeFromRoutineTime(date, startTime);
    final dateStr = _formatDate(fireAt);
    final timeStr = _formatTime(fireAt);

    await _scheduleAndPersist(
      uid: uid,
      notifId: _makeDeterministicId(templateId, dateStr, timeStr, category),
      category: category,
      title: '🌅 $title',
      body: 'Time to start your $category block.',
      scheduledFor: fireAt,
      details: _kTaskNotifDetails,
      routineTemplateId: templateId,
      scheduledDate: dateStr,
      scheduledTime: timeStr,
      priority: _asString(template['priority']),
      intentDescription: 'routine_${category}_$templateId',
      triggerEventId: _asString(template['triggerEventId']),
      isCritical: _asBool(template['isCritical']),
    );
  }

  Future<void> scheduleCustom(Map<String, dynamic> input, String uid) async {
    final title = _asString(input['title']) ?? 'Reminder';
    final body = _asString(input['body']) ?? '';
    final scheduledFor = _asDateTime(input['scheduledFor']) ??
        _asDateTime(input['fireAt']) ??
        _asDateTime(input['at']) ??
        DateTime.now().add(const Duration(minutes: 1));
    final category = _asString(input['category']) ?? 'custom';
    final dedupeTemplateId = _asString(input['routineTemplateId']) ??
        _asString(input['templateId']) ??
        _asString(input['entityId']) ??
        _asString(input['taskId']) ??
        _asString(input['habitId']) ??
        'custom';

    final dateStr = _formatDate(scheduledFor);
    final timeStr = _formatTime(scheduledFor);

    await _scheduleAndPersist(
      uid: uid,
      notifId: _makeDeterministicId(
        dedupeTemplateId,
        dateStr,
        timeStr,
        category,
      ),
      category: category,
      title: title,
      body: body,
      scheduledFor: scheduledFor,
      details: _kTaskNotifDetails,
      taskId: _asString(input['taskId']),
      habitId: _asString(input['habitId']),
      routineTemplateId: dedupeTemplateId,
      scheduledDate: dateStr,
      scheduledTime: timeStr,
      priority: _asString(input['priority']),
      intentDescription:
          _asString(input['intentDescription']) ?? 'custom_reminder',
      triggerEventId: _asString(input['triggerEventId']),
      isCritical: _asBool(input['isCritical']),
    );
  }

  Future<void> cancel(String notifId, String uid) async {
    await _cancelAndPersist(uid: uid, notifId: notifId);
  }

  Future<void> cancelForTask(String taskId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final snapshots = await _firestore
        .collection('users')
        .doc(uid)
        .collection('scheduled_notifications')
        .where('taskId', isEqualTo: taskId)
        .where('status', isEqualTo: NotifStatus.pending)
        .get();

    for (final doc in snapshots.docs) {
      await _cancelAndPersist(uid: uid, notifId: doc.id);
    }
  }

  Future<void> reRegisterAllOnAppStart() async {
    final inFlight = _reRegisterInFlight;
    if (inFlight != null) return inFlight;

    final future = _reRegisterAllOnAppStart();
    _reRegisterInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_reRegisterInFlight, future)) {
        _reRegisterInFlight = null;
      }
    }
  }

  Future<void> _reRegisterAllOnAppStart() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    if (!_isInitialized) await init();
    if (kIsWeb) return;

    final now = DateTime.now();
    final snapshots = await _firestore
        .collection('users')
        .doc(uid)
        .collection('scheduled_notifications')
        .where('status', isEqualTo: NotifStatus.pending)
        .get();

    debugPrint(
      '[NotificationService] Re-registering ${snapshots.docs.length} '
      'pending notifications.',
    );

    for (final doc in snapshots.docs) {
      final notif = ScheduledNotification.fromFirestore(doc);
      if (notif.scheduledFor.isAfter(now)) {
        final registrationKey = _registrationKey(uid, notif.notifId);
        if (_reRegisteredNotificationKeys.contains(registrationKey)) continue;

        await _plugin.zonedSchedule(
          id: notif.notifId.hashCode & 0x7FFFFFFF,
          title: notif.title ?? '',
          body: notif.body ?? '',
          scheduledDate: tz.TZDateTime.from(notif.scheduledFor, tz.local),
          notificationDetails: _detailsForCategory(notif.category),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: json.encode({
            'notifId': notif.notifId,
            'uid': uid,
            'category': notif.category
          }),
        );
        _reRegisteredNotificationKeys.add(registrationKey);
        await _markReRegistered(uid: uid, notifId: notif.notifId);
      } else {
        // Notification was missed while app was closed.
        await recordMissed(notif.notifId, uid, notif.category);
      }
    }
  }

  // ── Restore legacy typed helpers ──────────────────────────────────────────

  /// Cancel a previously scheduled task-end reminder.
  Future<void> cancelTaskEndReminder(TaskModel task, String uid) async {
    final fireAt = task.plannedEnd;
    final dateStr = _formatDate(fireAt);
    final timeStr = _formatTime(fireAt);
    final notifId = _makeDeterministicId(task.parentRoutine ?? task.id, dateStr,
        timeStr, NotifCategory.taskEndReminder);

    await _cancelAndPersist(uid: uid, notifId: notifId);
  }

  /// Fire a congratulatory streak-milestone notification immediately.
  Future<bool> scheduleStreakMilestone({
    required String uid,
    required String habitId,
    required int milestone,
    bool isCritical = false,
  }) async {
    final fireAt = DateTime.now().add(const Duration(seconds: 1));
    final dateStr = _formatDate(fireAt);
    final timeStr = _formatTime(fireAt);

    return _scheduleAndPersist(
      uid: uid,
      notifId: _makeDeterministicId(
        habitId,
        dateStr,
        timeStr,
        NotifCategory.streakMilestone,
      ),
      category: NotifCategory.streakMilestone,
      title: '🔥 $milestone-day streak!',
      body: 'You\'re on a $milestone-day streak. Keep the momentum going!',
      scheduledFor: fireAt,
      details: _kHabitNotifDetails,
      habitId: habitId,
      routineTemplateId: habitId,
      scheduledDate: dateStr,
      scheduledTime: timeStr,
      intentDescription: 'streak_milestone_$habitId',
      isCritical: isCritical,
    );
  }

  /// Fire a slip-recovery nudge immediately after a bad-habit slip is logged.
  Future<bool> scheduleSlipRecovery({
    required String uid,
    required String habitId,
    required String habitName,
    DateTime? scheduledFor,
    String intentSuffix = '',
    String? title,
    String? body,
  }) async {
    final fireAt =
        scheduledFor ?? DateTime.now().add(const Duration(seconds: 1));
    final entityKey = intentSuffix.isEmpty ? habitId : '$habitId:$intentSuffix';
    final dateStr = _formatDate(fireAt);
    final timeStr = _formatTime(fireAt);

    return _scheduleAndPersist(
      uid: uid,
      notifId: _makeDeterministicId(
        entityKey,
        dateStr,
        timeStr,
        NotifCategory.slipRecovery,
      ),
      category: NotifCategory.slipRecovery,
      title: title ?? '💪 Slip noted — you\'ve got this',
      body: body ?? 'You logged a $habitName slip. Every day is a fresh start.',
      scheduledFor: fireAt,
      details: _kHabitNotifDetails,
      habitId: habitId,
      routineTemplateId: entityKey,
      scheduledDate: dateStr,
      scheduledTime: timeStr,
      intentDescription: intentSuffix.isEmpty
          ? 'slip_recovery_$habitId'
          : 'slip_recovery_${habitId}_$intentSuffix',
    );
  }

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

  // ── Lifecycle Recording ───────────────────────────────────────────────────

  Future<void> recordSent(String notifId, String uid, String category) async {
    await _updateStatusAndLog(
        notifId, uid, NotifStatus.sent, EventNames.notificationSent,
        category: category);
  }

  Future<void> recordTapped(String notifId, String uid, String category) async {
    await _updateStatusAndLog(
        notifId, uid, NotifStatus.tapped, EventNames.notificationTapped,
        category: category);
  }

  Future<void> recordDismissed(
      String notifId, String uid, String category) async {
    await _updateStatusAndLog(
        notifId, uid, NotifStatus.dismissed, EventNames.notificationDismissed,
        category: category);
  }

  Future<void> recordSuppressed(
    String notifId,
    String uid,
    String category,
    String reason, {
    Map<String, dynamic>? metadata,
  }) async {
    await _updateStatusAndLog(
      notifId,
      uid,
      NotifStatus.suppressed,
      EventNames.notificationSuppressed,
      category: category,
      extraPayload: {
        'reason': reason,
        if (metadata != null) ...metadata,
      },
    );
  }

  Future<void> recordMissed(String notifId, String uid, String category) async {
    await _updateStatusAndLog(
        notifId, uid, NotifStatus.missed, EventNames.notificationMissed,
        category: category);
  }

  Future<void> _updateStatusAndLog(
    String notifId,
    String uid,
    String status,
    String eventName, {
    required String category,
    Map<String, dynamic>? extraPayload,
  }) async {
    final now = DateTime.now();
    final batch = _firestore.batch();

    // 1. Update scheduled_notifications
    final notifRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('scheduled_notifications')
        .doc(notifId);
    batch.set(
        notifRef,
        {
          'notifId': notifId,
          'category': category,
          'status': status,
          'lastLifecycleEvent': eventName,
          'lastLifecycleAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          if (extraPayload != null) 'lastLifecycleMetadata': extraPayload,
          if (extraPayload?['reason'] != null)
            'suppressionReason': extraPayload?['reason'],
          if (status == NotifStatus.sent)
            'sentAt': FieldValue.serverTimestamp(),
          if (status == NotifStatus.tapped)
            'tappedAt': FieldValue.serverTimestamp(),
          if (status == NotifStatus.dismissed)
            'dismissedAt': FieldValue.serverTimestamp(),
          if (status == NotifStatus.suppressed)
            'suppressedAt': FieldValue.serverTimestamp(),
          if (status == NotifStatus.missed)
            'missedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));

    // 2. Write to notificationLog
    final logId = _makeLogId(notifId, status, now);
    final logRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('notificationLog')
        .doc(logId);
    batch.set(logRef, {
      'notifId': notifId,
      'eventName': eventName,
      'status': status,
      'category': category,
      'uid': uid,
      'source': 'notification_service',
      'timestamp': FieldValue.serverTimestamp(),
      if (extraPayload != null) ...extraPayload,
    });

    await batch.commit();

    await _emitLifecycleEvent(
      uid: uid,
      eventName: eventName,
      payload: {
        'notifId': notifId,
        'category': category,
        'status': status,
        if (extraPayload != null) ...extraPayload,
      },
    );
  }

  Future<void> _writeLifecycleLog({
    required String uid,
    required String notifId,
    required String status,
    required String eventName,
    required String category,
    Map<String, dynamic>? payload,
  }) async {
    final now = DateTime.now();
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('notificationLog')
        .doc(_makeLogId(notifId, status, now))
        .set({
      'notifId': notifId,
      'eventName': eventName,
      'status': status,
      'category': category,
      'uid': uid,
      'source': 'notification_service',
      'timestamp': FieldValue.serverTimestamp(),
      if (payload != null) ...payload,
    });
  }

  Future<void> _emitLifecycleEvent({
    required String uid,
    required String eventName,
    required Map<String, dynamic> payload,
  }) async {
    if (_eventService != null && _auth.currentUser?.uid == uid) {
      try {
        await _eventService.emit(
          eventName: eventName,
          payload: payload,
          source: 'notification_service',
        );
        return;
      } catch (e) {
        debugPrint(
          '[NotificationService] EventService emit failed for $eventName: $e',
        );
      }
    }

    await _writeEventDocuments(
      uid: uid,
      eventName: eventName,
      payload: payload,
    );
  }

  Future<void> _writeEventDocuments({
    required String uid,
    required String eventName,
    required Map<String, dynamic> payload,
    String? eventId,
    DateTime? timestamp,
  }) async {
    final now = timestamp ?? DateTime.now();
    final resolvedEventId = eventId ??
        _makeEventId(
          uid: uid,
          eventName: eventName,
          payload: payload,
          now: now,
        );
    final event = EventModel(
      eventId: resolvedEventId,
      eventName: eventName,
      uid: uid,
      timestamp: now,
      deviceId: await getDeviceId(),
      source: 'notification_service',
      payload: payload,
      schemaVersion: 1,
    );

    final eventDoc = event.toFirestore();
    final userRef = _firestore.collection('users').doc(uid);
    final batch = _firestore.batch();
    batch.set(userRef.collection('events').doc(resolvedEventId), eventDoc);
    batch.set(
      userRef.collection('events_recent').doc(resolvedEventId),
      eventDoc,
    );
    await batch.commit();
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final decoded = json.decode(payload);
      if (decoded is! Map<String, dynamic>) return;

      final notifId = decoded['notifId'] as String?;
      final uid = decoded['uid'] as String?;
      final category = decoded['category'] as String?;
      if (notifId == null || uid == null || category == null) return;

      final actionId = response.actionId;
      final isDismissAction = actionId == 'dismiss' ||
          actionId == 'UNNotificationDismissActionIdentifier' ||
          actionId == 'com.apple.UNNotificationDismissActionIdentifier';
      if (isDismissAction) {
        unawaited(recordDismissed(notifId, uid, category));
      } else {
        unawaited(recordTapped(notifId, uid, category));
      }
    } catch (e) {
      debugPrint('[NotificationService] Invalid notification payload: $e');
    }
  }

  // ── Existing helpers ──────────────────────────────────────────────────────

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
    DateTime? scheduledFor,
    String? triggerEventId,
    String? notifId,
    String? taskId,
    String? habitId,
    bool isCritical = false,
  }) async {
    final targetDate = scheduledFor ?? DateTime.now();
    final today = _formatDate(targetDate);
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

      // ── Quiet Hours Check ────────────────────────────────────────────────
      bool inQuietHours = false;
      if (!isCritical) {
        final bodyBasics = data['bodyBasics'] as Map<String, dynamic>?;
        final wakeTime = bodyBasics?['wakeTime'] as String?;
        final sleepTime = bodyBasics?['sleepTime'] as String?;
        if (wakeTime != null && sleepTime != null) {
          inQuietHours = _isInQuietHours(wakeTime, sleepTime, targetDate);
        }
      }

      String? reason;
      if (!isCritical && quietDayMode) {
        reason = 'quiet_day_mode';
      } else if (!isCritical && inQuietHours) {
        reason = 'quiet_hours';
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
      final suppressionPayload = <String, dynamic>{
        'intent': intentDescription,
        if (triggerEventId != null) 'triggerEventId': triggerEventId,
        if (taskId != null) 'taskId': taskId,
        if (habitId != null) 'habitId': habitId,
        'dailyNotificationBudget': decision.dailyNotificationBudget,
        'notificationsSentToday': decision.notificationsSentToday,
        'quietDayMode': decision.quietDayMode,
      };
      if (notifId != null) {
        await recordSuppressed(
          notifId,
          uid,
          category,
          decision.reason ?? 'unknown',
          metadata: suppressionPayload,
        );
      }
      if (_eventService == null || notifId == null) {
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

    await _writeEventDocuments(
      uid: uid,
      eventId: eventId,
      eventName: EventNames.notificationSuppressed,
      timestamp: now,
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
    );

    debugPrint(
      '[NotificationService] notification_suppressed reason=$reason '
      'intent=$intentDescription',
    );
  }

  // ── Low-level schedule + persist ──────────────────────────────────────────

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findPendingDuplicate({
    required String uid,
    required String notifId,
    required String category,
    String? routineTemplateId,
    String? scheduledDate,
    String? scheduledTime,
  }) async {
    final notificationsRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('scheduled_notifications');

    final existing = await notificationsRef.doc(notifId).get();
    if (existing.exists && existing.data()?['status'] == NotifStatus.pending) {
      return existing;
    }

    if (routineTemplateId == null ||
        scheduledDate == null ||
        scheduledTime == null) {
      return null;
    }

    final duplicate = await notificationsRef
        .where('routineTemplateId', isEqualTo: routineTemplateId)
        .where('scheduledDate', isEqualTo: scheduledDate)
        .where('scheduledTime', isEqualTo: scheduledTime)
        .where('category', isEqualTo: category)
        .where('status', isEqualTo: NotifStatus.pending)
        .limit(1)
        .get();

    return duplicate.docs.isEmpty ? null : duplicate.docs.first;
  }

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
    String? routineTemplateId,
    String? scheduledDate,
    String? scheduledTime,
    String? priority,
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
      await recordMissed(notifId, uid, category);
      return false;
    }

    final duplicate = await _findPendingDuplicate(
      uid: uid,
      notifId: notifId,
      category: category,
      routineTemplateId: routineTemplateId,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
    );
    if (duplicate != null) {
      debugPrint(
        '[NotificationService] $category: duplicate pending notification '
        '${duplicate.id}; skipping local enqueue.',
      );
      return true;
    }

    final budgetDecision = await reserveNotificationSlot(
      uid: uid,
      intentDescription: intentDescription,
      category: category,
      scheduledFor: scheduledFor,
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
      payload:
          json.encode({'notifId': notifId, 'uid': uid, 'category': category}),
    );

    // ── 2. Persist intent doc to Firestore (best-effort) ───────────────────
    try {
      final notif = ScheduledNotification(
        notifId: notifId,
        category: category,
        scheduledFor: scheduledFor.toUtc(),
        taskId: taskId,
        habitId: habitId,
        routineTemplateId: routineTemplateId,
        scheduledDate: scheduledDate,
        scheduledTime: scheduledTime,
        priority: priority,
        intentDescription: intentDescription,
        triggerEventId: triggerEventId,
        title: title,
        body: body,
        createdAt: DateTime.now(),
      );
      final notifDoc = notif.toFirestore();
      notifDoc['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('scheduled_notifications')
          .doc(notifId)
          .set(notifDoc, SetOptions(merge: true));

      final scheduledPayload = _scheduledEventPayload(notif);
      await _writeLifecycleLog(
        uid: uid,
        notifId: notifId,
        status: NotifStatus.pending,
        eventName: EventNames.notificationScheduled,
        category: category,
        payload: scheduledPayload,
      );

      await _emitLifecycleEvent(
        uid: uid,
        eventName: EventNames.notificationScheduled,
        payload: scheduledPayload,
      );
    } catch (e) {
      debugPrint(
        '[NotificationService] Failed to persist Firestore doc for $notifId: $e',
      );
    }

    return true;
  }

  Map<String, dynamic> _scheduledEventPayload(ScheduledNotification notif) {
    return {
      'notifId': notif.notifId,
      'category': notif.category,
      'status': notif.status,
      'scheduledFor': notif.scheduledFor.toUtc().toIso8601String(),
      if (notif.taskId != null) 'taskId': notif.taskId,
      if (notif.habitId != null) 'habitId': notif.habitId,
      if (notif.routineTemplateId != null)
        'routineTemplateId': notif.routineTemplateId,
      if (notif.scheduledDate != null) 'scheduledDate': notif.scheduledDate,
      if (notif.scheduledTime != null) 'scheduledTime': notif.scheduledTime,
      if (notif.priority != null) 'priority': notif.priority,
      if (notif.intentDescription != null) 'intent': notif.intentDescription,
      if (notif.triggerEventId != null) 'triggerEventId': notif.triggerEventId,
      if (notif.title != null) 'title': notif.title,
      if (notif.body != null) 'body': notif.body,
      'schemaVersion': notif.schemaVersion,
    };
  }

  Future<void> _cancelAndPersist({
    required String uid,
    required String notifId,
  }) async {
    if (!_isInitialized) await init();

    if (!kIsWeb) {
      await _plugin.cancel(id: notifId.hashCode & 0x7FFFFFFF);
      _reRegisteredNotificationKeys.remove(_registrationKey(uid, notifId));
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

  Future<void> _markReRegistered({
    required String uid,
    required String notifId,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('scheduled_notifications')
        .doc(notifId)
        .set({
      'reRegisteredAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  static NotificationDetails _detailsForCategory(String category) {
    switch (category) {
      case NotifCategory.streakMilestone:
      case NotifCategory.slipRecovery:
        return _kHabitNotifDetails;
      case NotifCategory.taskReminder:
      case NotifCategory.taskEndReminder:
      default:
        return _kTaskNotifDetails;
    }
  }

  static String _makeDeterministicId(
      String templateId, String date, String time, String category) {
    final seed = '$templateId:$date:$time:$category';
    return sha256.convert(utf8.encode(seed)).toString();
  }

  static String _makeLogId(String notifId, String status, DateTime at) {
    final seed = '$notifId:$status:${at.toUtc().microsecondsSinceEpoch}';
    return sha256.convert(utf8.encode(seed)).toString();
  }

  static String _makeEventId({
    required String uid,
    required String eventName,
    required Map<String, dynamic> payload,
    required DateTime now,
  }) {
    final seed = [
      uid,
      eventName,
      now.toUtc().microsecondsSinceEpoch,
      json.encode(payload),
    ].join(':');
    return sha256.convert(utf8.encode(seed)).toString();
  }

  static String _registrationKey(String uid, String notifId) {
    return '$uid:$notifId';
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

  static String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  static String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static bool _isInQuietHours(
      String wakeTime, String sleepTime, DateTime checkTime) {
    final nowMinutes = checkTime.hour * 60 + checkTime.minute;

    final wakeParts = wakeTime.split(':');
    final sleepParts = sleepTime.split(':');
    if (wakeParts.length < 2 || sleepParts.length < 2) return false;

    final wakeHour = int.tryParse(wakeParts[0]);
    final wakeMinute = int.tryParse(wakeParts[1]);
    final sleepHour = int.tryParse(sleepParts[0]);
    final sleepMinute = int.tryParse(sleepParts[1]);
    if (wakeHour == null ||
        wakeMinute == null ||
        sleepHour == null ||
        sleepMinute == null) {
      return false;
    }

    final wakeMinutes = wakeHour * 60 + wakeMinute;
    final sleepMinutes = sleepHour * 60 + sleepMinute;

    if (sleepMinutes > wakeMinutes) {
      // Quiet hours are wakeTime -> sleepTime ? No, usually quiet hours are sleepTime -> wakeTime.
      // If wake=07:00, sleep=22:00, quiet hours are 22:00 -> 07:00.
      return nowMinutes < wakeMinutes || nowMinutes >= sleepMinutes;
    } else {
      // Sleep time is after midnight (rare but possible).
      return nowMinutes >= sleepMinutes && nowMinutes < wakeMinutes;
    }
  }

  DateTime _dateTimeFromRoutineTime(DateTime date, String time,
      {String fallback = '09:00'}) {
    try {
      final parts = time.split(':');
      return DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    } catch (_) {
      final parts = fallback.split(':');
      return DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    }
  }

  static String _todayString() {
    return _formatDate(DateTime.now());
  }

  static int _asNonNegativeInt(Object? value, {int fallback = 0}) {
    if (value is int) return value < 0 ? 0 : value;
    if (value is num) {
      final rounded = value.round();
      return rounded < 0 ? 0 : rounded;
    }
    return fallback;
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String? _asString(Object? value) {
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  static bool _asBool(Object? value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    return fallback;
  }
}
