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
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../core/constants/event_names.dart';
import '../core/utils/device_id.dart';
import '../models/event_model.dart';
import '../models/scheduled_notification_model.dart';
import '../models/task_model.dart';
import '../views/alarms/alarm_ringing_screen.dart';
import '../views/alarms/snooze_reason_sheet.dart';
import 'event_service.dart';

// ── Android notification channels ──────────────────────────────────────────

const _kTaskChannel = AndroidNotificationDetails(
  'task_reminders',
  'Task Reminders',
  channelDescription: 'Reminders for upcoming and in-progress tasks',
  importance: Importance.high,
  priority: Priority.high,
);

const _kAlarmCategory = 'task_alarm';

const _kAlarmChannel = AndroidNotificationDetails(
  'task_alarms',
  'Task Alarms',
  channelDescription: 'Full-screen alarms for priority tasks',
  importance: Importance.max,
  priority: Priority.max,
  category: AndroidNotificationCategory.alarm,
  fullScreenIntent: true,
  ongoing: true,
  autoCancel: false,
  actions: <AndroidNotificationAction>[
    AndroidNotificationAction(
      'alarm_start',
      'Start',
      showsUserInterface: true,
      semanticAction: SemanticAction.markAsRead,
    ),
    AndroidNotificationAction(
      'alarm_snooze',
      'Snooze',
      showsUserInterface: true,
      semanticAction: SemanticAction.none,
    ),
    AndroidNotificationAction(
      'alarm_skip',
      'Skip',
      showsUserInterface: true,
      semanticAction: SemanticAction.delete,
    ),
  ],
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

const _kAlarmDarwinDetails = DarwinNotificationDetails(
  presentAlert: true,
  presentBadge: true,
  presentSound: true,
  categoryIdentifier: 'optivus_alarm',
  interruptionLevel: InterruptionLevel.timeSensitive,
);

final _kAlarmNotifDetails = NotificationDetails(
  android: _kAlarmChannel,
  iOS: _kAlarmDarwinDetails,
  macOS: _kAlarmDarwinDetails,
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

class _NotificationUserSettings {
  final int dailyBudget;
  final bool quietToday;
  final Set<String> quietDays;
  final Map<String, _NotificationCategorySetting> categories;
  final List<_BlackoutWindow> blackouts;
  final List<_CustomAlarmSetting> customAlarms;
  final String sound;
  final String vibration;

  const _NotificationUserSettings({
    required this.dailyBudget,
    required this.quietToday,
    required this.quietDays,
    required this.categories,
    required this.blackouts,
    required this.customAlarms,
    required this.sound,
    required this.vibration,
  });

  factory _NotificationUserSettings.fromProfile(Map<String, dynamic> data) {
    final rawSettings =
        Map<String, dynamic>.from(data['notificationSettings'] as Map? ?? {});
    final rawCategories =
        Map<String, dynamic>.from(rawSettings['categories'] as Map? ?? {});
    final defaults = NotificationService._defaultCategorySettings();
    final categories = <String, _NotificationCategorySetting>{};
    for (final entry in defaults.entries) {
      categories[entry.key] = _NotificationCategorySetting.fromMap(
        Map<String, dynamic>.from(rawCategories[entry.key] as Map? ?? {}),
        fallback: entry.value,
      );
    }

    final quietDays = (rawSettings['quietDays'] as List? ?? const [])
        .whereType<Object>()
        .map((value) => value.toString())
        .where((value) => value.isNotEmpty)
        .toSet();

    final blackouts = (rawSettings['blackoutWindows'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => _BlackoutWindow.fromMap(
              Map<String, dynamic>.from(value),
            ))
        .toList();

    final customAlarms = (rawSettings['customAlarms'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => _CustomAlarmSetting.fromMap(
              Map<String, dynamic>.from(value),
            ))
        .toList();

    final fallbackBudget = NotificationService._asNonNegativeInt(
      data['dailyNotificationBudget'],
      fallback: 3,
    );
    final hasSettingsBudget = rawSettings.containsKey('dailyBudget');
    final dailyBudget = hasSettingsBudget
        ? NotificationService._asNonNegativeInt(
            rawSettings['dailyBudget'],
            fallback: fallbackBudget,
          )
        : fallbackBudget;

    return _NotificationUserSettings(
      dailyBudget: dailyBudget,
      quietToday: rawSettings['quietToday'] as bool? ??
          data['quietDayMode'] as bool? ??
          false,
      quietDays: quietDays,
      categories: categories,
      blackouts: blackouts,
      customAlarms: customAlarms,
      sound: NotificationService._asString(rawSettings['sound']) ?? 'default',
      vibration:
          NotificationService._asString(rawSettings['vibration']) ?? 'standard',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'dailyBudget': dailyBudget,
      'quietToday': quietToday,
      'quietDays': quietDays.toList()..sort(),
      'categories':
          categories.map((key, value) => MapEntry(key, value.toFirestore())),
      'blackoutWindows':
          blackouts.map((window) => window.toFirestore()).toList(),
      'customAlarms': customAlarms.map((alarm) => alarm.toFirestore()).toList(),
      'sound': sound,
      'vibration': vibration,
    };
  }

  bool isQuietDay(DateTime date) {
    return quietToday &&
            NotificationService._formatDate(date) ==
                NotificationService._todayString() ||
        quietDays.contains(NotificationService._formatDate(date));
  }

  bool isInBlackout(DateTime date) {
    return blackouts.any((window) => window.enabled && window.includes(date));
  }

  _NotificationCategorySetting categorySetting(String category) {
    return categories[NotificationService._categoryGroup(category)] ??
        const _NotificationCategorySetting(enabled: true, cap: 3);
  }

  bool isCustomAlarmEnabled(String id) {
    final alarm = customAlarms.cast<_CustomAlarmSetting?>().firstWhere(
          (item) => item?.id == id,
          orElse: () => null,
        );
    return alarm?.enabled ?? true;
  }
}

class _NotificationCategorySetting {
  final bool enabled;
  final int cap;

  const _NotificationCategorySetting({
    required this.enabled,
    required this.cap,
  });

  factory _NotificationCategorySetting.fromMap(
    Map<String, dynamic> data, {
    required _NotificationCategorySetting fallback,
  }) {
    return _NotificationCategorySetting(
      enabled: data['enabled'] as bool? ?? fallback.enabled,
      cap: NotificationService._asNonNegativeInt(
        data['cap'],
        fallback: fallback.cap,
      ).clamp(0, 15),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'enabled': enabled,
        'cap': cap,
      };
}

class _BlackoutWindow {
  final String id;
  final String start;
  final String end;
  final bool enabled;

  const _BlackoutWindow({
    required this.id,
    required this.start,
    required this.end,
    required this.enabled,
  });

  factory _BlackoutWindow.fromMap(Map<String, dynamic> data) {
    return _BlackoutWindow(
      id: NotificationService._asString(data['id']) ?? 'blackout',
      start: NotificationService._asString(data['start']) ?? '22:00',
      end: NotificationService._asString(data['end']) ?? '07:00',
      enabled: data['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'start': start,
        'end': end,
        'enabled': enabled,
      };

  bool includes(DateTime date) {
    final current = date.hour * 60 + date.minute;
    final startMinutes = NotificationService._minutesForTime(start);
    final endMinutes = NotificationService._minutesForTime(end);
    if (startMinutes == null || endMinutes == null) return false;
    if (startMinutes == endMinutes) return true;
    if (startMinutes < endMinutes) {
      return current >= startMinutes && current < endMinutes;
    }
    return current >= startMinutes || current < endMinutes;
  }
}

class _CustomAlarmSetting {
  final String id;
  final String label;
  final String time;
  final bool enabled;

  const _CustomAlarmSetting({
    required this.id,
    required this.label,
    required this.time,
    required this.enabled,
  });

  factory _CustomAlarmSetting.fromMap(Map<String, dynamic> data) {
    return _CustomAlarmSetting(
      id: NotificationService._asString(data['id']) ?? 'alarm',
      label: NotificationService._asString(data['label']) ?? 'Custom alarm',
      time: NotificationService._asString(data['time']) ?? '09:00',
      enabled: data['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'label': label,
        'time': time,
        'enabled': enabled,
      };
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
            'optivus_alarm',
            actions: [
              DarwinNotificationAction.plain(
                'alarm_start',
                'Start',
                options: {DarwinNotificationActionOption.foreground},
              ),
              DarwinNotificationAction.plain(
                'alarm_snooze',
                'Snooze',
                options: {DarwinNotificationActionOption.foreground},
              ),
              DarwinNotificationAction.plain(
                'alarm_skip',
                'Skip',
                options: {DarwinNotificationActionOption.foreground},
              ),
            ],
            options: {DarwinNotificationCategoryOption.customDismissAction},
          ),
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

  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb) return false;
    if (!_isInitialized) await init();

    if (Platform.isIOS) {
      // iOS doesn't have a direct synchronous getter without a different package,
      // but flutter_local_notifications doesn't expose it directly for iOS.
      // We can assume true for iOS until requested, or use another mechanism.
      return true;
    } else if (Platform.isMacOS) {
      return true;
    } else if (Platform.isAndroid) {
      final enabled = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
      return enabled ?? false;
    }
    return false;
  }

  Future<bool> sendTestNotification(String uid) async {
    if (kIsWeb) {
      debugPrint('[NotificationService] Test notification unsupported on web.');
      return false;
    }
    if (!_isInitialized) await init();

    final settings = await _loadNotificationSettings(uid);
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF,
      title: 'Optivus test notification',
      body: 'Your notification settings are ready.',
      notificationDetails:
          _detailsForCategoryWithSettings('test_notification', settings),
      payload: json.encode({
        'notifId': 'test_${DateTime.now().millisecondsSinceEpoch}',
        'uid': uid,
        'category': 'test_notification',
      }),
    );
    return true;
  }

  Future<void> reconcilePendingNotificationsWithSettings(String uid) async {
    final settings = await _loadNotificationSettings(uid);
    final snapshots = await _firestore
        .collection('users')
        .doc(uid)
        .collection('scheduled_notifications')
        .where('status', isEqualTo: NotifStatus.pending)
        .get();

    for (final doc in snapshots.docs) {
      final notif = ScheduledNotification.fromFirestore(doc);
      if (settings.categorySetting(notif.category).enabled) continue;
      await _cancelAndPersist(
        uid: uid,
        notifId: notif.notifId,
        reason: 'notification_settings_category_disabled',
      );
    }
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

  /// Schedule a full-screen P1 alarm at [task.plannedStart].
  Future<bool> scheduleTaskAlarm(TaskModel task, String uid) async {
    final fireAt = task.plannedStart;
    final dateStr = _formatDate(fireAt);
    final timeStr = _formatTime(fireAt);
    final dedupeTemplateId = task.parentRoutine ?? task.id;

    return _scheduleAndPersist(
      uid: uid,
      notifId: _makeDeterministicId(
        dedupeTemplateId,
        dateStr,
        timeStr,
        _kAlarmCategory,
      ),
      category: _kAlarmCategory,
      title: task.title,
      body: 'Ready to start?',
      scheduledFor: fireAt,
      details: _kAlarmNotifDetails,
      taskId: task.id,
      routineTemplateId: dedupeTemplateId,
      scheduledDate: dateStr,
      scheduledTime: timeStr,
      priority: 'P1',
      intentDescription: 'task_alarm_${task.id}',
      isCritical: true,
      payloadExtras: {
        'alarmTier': task.alarmTier.name,
        'sound': task.alarmSound,
        'soundAsset': task.alarmSoundAsset,
        'coachVoiceEnabled': task.alarmVoiceEnabled,
        'coachVoiceAsset': task.alarmCoachVoiceAsset,
        'vibrationPattern': task.alarmTier == AlarmTier.active
            ? 'urgent'
            : task.alarmVibrationPattern,
        'snoozeDurations': task.alarmSnoozeDurations,
      },
    );
  }

  /// New consolidated task scheduling method.
  Future<void> scheduleForTask(TaskModel task) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    if (task.alarmTier == AlarmTier.custom ||
        task.alarmTier == AlarmTier.active) {
      await scheduleTaskAlarm(task, uid);
    }
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
    final settings = await _loadNotificationSettings(uid);
    final customAlarmId = _asString(input['customAlarmId']) ??
        _asString(input['alarmId']) ??
        _asString(input['id']);
    if (customAlarmId != null &&
        !settings.isCustomAlarmEnabled(customAlarmId)) {
      final intent = _asString(input['intentDescription']) ?? 'custom_reminder';
      await writeSuppressionEvent(
        uid: uid,
        reason: 'custom_alarm_disabled',
        intentDescription: intent,
        category: _asString(input['category']) ?? 'custom',
        triggerEventId: _asString(input['triggerEventId']),
        notifId: _asString(input['notifId']),
        taskId: _asString(input['taskId']),
        habitId: _asString(input['habitId']),
      );
      return;
    }

    final title = _asString(input['title']) ?? 'Reminder';
    final body = _asString(input['body']) ?? '';
    final scheduledFor = _asDateTime(input['scheduledFor']) ??
        _asDateTime(input['fireAt']) ??
        _asDateTime(input['at']) ??
        DateTime.now().add(const Duration(minutes: 1));
    final requestedCategory = _asString(input['category']);
    final requestedPriority = _asString(input['priority']);
    final isP1Alarm = requestedCategory == _kAlarmCategory ||
        requestedPriority == 'P1' ||
        _asBool(input['fullScreenAlarm']) ||
        _asBool(input['alarmEnabled']);
    final category =
        isP1Alarm ? _kAlarmCategory : (requestedCategory ?? 'custom');
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
      details: isP1Alarm ? _kAlarmNotifDetails : _kTaskNotifDetails,
      taskId: _asString(input['taskId']),
      habitId: _asString(input['habitId']),
      routineTemplateId: dedupeTemplateId,
      scheduledDate: dateStr,
      scheduledTime: timeStr,
      priority: isP1Alarm ? 'P1' : requestedPriority,
      intentDescription:
          _asString(input['intentDescription']) ?? 'custom_reminder',
      triggerEventId: _asString(input['triggerEventId']),
      isCritical: isP1Alarm || _asBool(input['isCritical']),
      payloadExtras: isP1Alarm
          ? {
              'alarmTier': _asString(input['alarmTier']) ?? 'custom',
              'sound': _asString(input['sound']) ?? 'steady',
              'soundAsset': _asString(input['soundAsset']) ??
                  'assets/audio/ambient_atmospheric/ambient_atmospheric_01.mp3',
              'coachVoiceEnabled': _asBool(
                input['coachVoiceEnabled'],
                fallback: true,
              ),
              'coachVoiceAsset': _asString(input['coachVoiceAsset']) ??
                  'assets/audio/healing_432hz/healing_432hz_01.mp3',
              'vibrationPattern':
                  _asString(input['vibrationPattern']) ?? 'standard',
              'snoozeDurations':
                  _normalizeSnoozeDurations(input['snoozeDurations']),
            }
          : null,
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

    final settings = await _loadNotificationSettings(uid);
    for (final doc in snapshots.docs) {
      final notif = ScheduledNotification.fromFirestore(doc);
      if (notif.scheduledFor.isAfter(now)) {
        if (!settings.categorySetting(notif.category).enabled) {
          await _cancelAndPersist(
            uid: uid,
            notifId: notif.notifId,
            reason: 'notification_settings_category_disabled',
          );
          continue;
        }
        final registrationKey = _registrationKey(uid, notif.notifId);
        if (_reRegisteredNotificationKeys.contains(registrationKey)) continue;

        await _plugin.zonedSchedule(
          id: notif.notifId.hashCode & 0x7FFFFFFF,
          title: notif.title ?? '',
          body: notif.body ?? '',
          scheduledDate: tz.TZDateTime.from(notif.scheduledFor, tz.local),
          notificationDetails:
              _detailsForCategoryWithSettings(notif.category, settings),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: json.encode({
            'notifId': notif.notifId,
            'uid': uid,
            'category': notif.category,
            if (notif.taskId != null) 'taskId': notif.taskId,
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

  /// Schedule a congratulatory nudge when a streak is extended.
  Future<bool> scheduleStreakCongrats({
    required String uid,
    required String habitId,
    required int streakCount,
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
        NotifCategory.streakCongrats,
      ),
      category: NotifCategory.streakCongrats,
      title: '🔥 $streakCount days strong!',
      body: 'Your streak keeps growing. Keep it up!',
      scheduledFor: fireAt,
      details: _kHabitNotifDetails,
      habitId: habitId,
      routineTemplateId: habitId,
      scheduledDate: dateStr,
      scheduledTime: timeStr,
      intentDescription: 'streak_congrats_$habitId',
    );
  }

  /// Schedule an encouraging nudge when a streak is broken.
  Future<bool> scheduleStreakEncouragement({
    required String uid,
    required String habitId,
    required int previousStreak,
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
        NotifCategory.streakEncouragement,
      ),
      category: NotifCategory.streakEncouragement,
      title: '💪 Time to rebuild',
      body: previousStreak > 0
          ? 'Your $previousStreak-day streak ended — one step restarts it.'
          : 'Every day is a fresh start. You\'ve got this!',
      scheduledFor: fireAt,
      details: _kHabitNotifDetails,
      habitId: habitId,
      routineTemplateId: habitId,
      scheduledDate: dateStr,
      scheduledTime: timeStr,
      intentDescription: 'streak_encouragement_$habitId',
    );
  }

  /// Schedule a day-close summary notification.
  Future<bool> scheduleDaySummary({
    required String uid,
    required String date,
    required int tasksCompleted,
    required int habitsCompleted,
  }) async {
    final fireAt = DateTime.now().add(const Duration(seconds: 1));
    final timeStr = _formatTime(fireAt);

    return _scheduleAndPersist(
      uid: uid,
      notifId: _makeDeterministicId(
        'day_summary',
        date,
        timeStr,
        NotifCategory.daySummary,
      ),
      category: NotifCategory.daySummary,
      title: '📊 Day closed: $date',
      body: '$tasksCompleted tasks completed, $habitsCompleted habits logged.',
      scheduledFor: fireAt,
      details: _kHabitNotifDetails,
      routineTemplateId: 'day_summary_$date',
      scheduledDate: date,
      scheduledTime: timeStr,
      intentDescription: 'day_summary_$date',
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

  Future<void> recordTapped(
    String notifId,
    String uid,
    String category, {
    Map<String, dynamic>? metadata,
  }) async {
    await _updateStatusAndLog(
        notifId, uid, NotifStatus.tapped, EventNames.notificationTapped,
        category: category, extraPayload: metadata);
  }

  Future<void> recordDismissed(
    String notifId,
    String uid,
    String category, {
    Map<String, dynamic>? metadata,
  }) async {
    await _updateStatusAndLog(
        notifId, uid, NotifStatus.dismissed, EventNames.notificationDismissed,
        category: category, extraPayload: metadata);
  }

  Future<void> recordSnoozed({
    required String notifId,
    required String uid,
    required String category,
    required SnoozeReasonResult reason,
    required int minutes,
  }) async {
    final now = DateTime.now();
    final payload = {
      'action': 'snooze',
      'reason': reason.reason,
      'reasonLabel': reason.label,
      'snoozeMinutes': minutes,
    };

    final batch = _firestore.batch();
    final userRef = _firestore.collection('users').doc(uid);
    batch.set(
      userRef.collection('scheduled_notifications').doc(notifId),
      {
        'lastLifecycleEvent': 'notification_snoozed',
        'lastLifecycleAt': FieldValue.serverTimestamp(),
        'lastSnoozeReason': reason.reason,
        'lastSnoozeReasonLabel': reason.label,
        'lastSnoozeMinutes': minutes,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      userRef
          .collection('notificationLog')
          .doc(_makeLogId(notifId, 'snoozed', now)),
      {
        'notifId': notifId,
        'eventName': 'notification_snoozed',
        'status': 'snoozed',
        'category': category,
        'uid': uid,
        'source': 'notification_service',
        'timestamp': FieldValue.serverTimestamp(),
        ...payload,
      },
    );
    await batch.commit();
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
      if (category == _kAlarmCategory) {
        unawaited(_handleAlarmResponse(
          notifId: notifId,
          uid: uid,
          actionId: actionId,
        ));
        return;
      }

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

  Future<void> _handleAlarmResponse({
    required String notifId,
    required String uid,
    String? actionId,
  }) async {
    final action = actionId ?? '';
    if (action == 'alarm_start') {
      await recordTapped(
        notifId,
        uid,
        _kAlarmCategory,
        metadata: {'action': 'start'},
      );
      final data = await _scheduledNotificationData(uid, notifId);
      await _startTaskFromAlarm(uid: uid, notifId: notifId, data: data);
      return;
    }

    final isDismissAction = action == 'dismiss' ||
        action == 'UNNotificationDismissActionIdentifier' ||
        action == 'com.apple.UNNotificationDismissActionIdentifier';
    if (isDismissAction) {
      await recordDismissed(
        notifId,
        uid,
        _kAlarmCategory,
        metadata: {'action': 'system_dismiss'},
      );
      return;
    }

    await _openRingingScreen(uid: uid, notifId: notifId);
  }

  Future<void> simulateAlarmFire({
    required String uid,
    required String notifId,
  }) async {
    await _openRingingScreen(uid: uid, notifId: notifId);
  }

  Future<Map<String, dynamic>> _scheduledNotificationData(
    String uid,
    String notifId,
  ) async {
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('scheduled_notifications')
        .doc(notifId)
        .get();
    return doc.data() ?? <String, dynamic>{};
  }

  Future<void> _openRingingScreen({
    required String uid,
    required String notifId,
  }) async {
    final data = await _scheduledNotificationData(uid, notifId);
    final category = _asString(data['category']) ?? _kAlarmCategory;
    await recordSent(notifId, uid, category);

    final navigator = _findNavigator();
    if (navigator == null) {
      debugPrint('[NotificationService] No navigator available for alarm.');
      return;
    }

    final snoozeDurations = _normalizeSnoozeDurations(data['snoozeDurations']);

    await navigator.push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => AlarmRingingScreen(
        notifId: notifId,
        title: _asString(data['title']) ?? 'Alarm',
        body: _asString(data['body']),
        taskId: _asString(data['taskId']),
        scheduledFor: _asDateTime(data['scheduledFor']),
        soundAsset: _asString(data['soundAsset']) ??
            'assets/audio/ambient_atmospheric/ambient_atmospheric_01.mp3',
        coachVoiceEnabled: _asBool(
          data['coachVoiceEnabled'],
          fallback: true,
        ),
        coachVoiceAsset: _asString(data['coachVoiceAsset']) ??
            'assets/audio/healing_432hz/healing_432hz_01.mp3',
        vibrationPattern: _asString(data['vibrationPattern']) ?? 'standard',
        snoozeDurations: snoozeDurations,
        onStart: () async {
          await recordTapped(
            notifId,
            uid,
            category,
            metadata: {'action': 'start'},
          );
          await _startTaskFromAlarm(uid: uid, notifId: notifId, data: data);
        },
        onSnooze: (reason, minutes) async {
          await recordSnoozed(
            notifId: notifId,
            uid: uid,
            category: category,
            reason: reason,
            minutes: minutes,
          );
          await _scheduleSnoozedAlarm(
            uid: uid,
            originalNotifId: notifId,
            data: data,
            reason: reason,
            minutes: minutes,
          );
        },
        onSkip: (reason) async {
          await recordDismissed(
            notifId,
            uid,
            category,
            metadata: {
              'action': 'skip',
              'reason': reason.reason,
              'reasonLabel': reason.label,
              'feedsAiContext': true,
              'aiContext': {
                'kind': 'alarm_skip_reason',
                'reason': reason.reason,
                'reasonLabel': reason.label,
              },
            },
          );
          await _skipTaskFromAlarm(
            uid: uid,
            notifId: notifId,
            data: data,
            reason: reason,
          );
        },
      ),
    ));
  }

  NavigatorState? _findNavigator() {
    NavigatorState? result;
    void visit(Element element) {
      if (result != null) return;
      if (element is StatefulElement && element.state is NavigatorState) {
        result = element.state as NavigatorState;
        return;
      }
      element.visitChildElements(visit);
    }

    final root = WidgetsBinding.instance.rootElement;
    if (root == null) return null;
    visit(root);
    return result;
  }

  Future<void> _scheduleSnoozedAlarm({
    required String uid,
    required String originalNotifId,
    required Map<String, dynamic> data,
    required SnoozeReasonResult reason,
    required int minutes,
  }) async {
    final fireAt = DateTime.now().add(Duration(minutes: minutes));
    final newNotifId = '${originalNotifId}_snooze_'
        '${fireAt.toUtc().millisecondsSinceEpoch}';
    final taskId = _asString(data['taskId']);

    await _scheduleAndPersist(
      uid: uid,
      notifId: newNotifId,
      category: _asString(data['category']) ?? _kAlarmCategory,
      title: _asString(data['title']) ?? 'Alarm',
      body: _asString(data['body']) ?? 'Ready to start?',
      scheduledFor: fireAt,
      details: _kAlarmNotifDetails,
      taskId: taskId,
      routineTemplateId: _asString(data['routineTemplateId']) ?? taskId,
      scheduledDate: _formatDate(fireAt),
      scheduledTime: _formatTime(fireAt),
      priority: 'P1',
      intentDescription: 'snoozed_alarm_${taskId ?? originalNotifId}',
      isCritical: true,
      payloadExtras: {
        'originalNotifId': originalNotifId,
        'snoozeReason': reason.reason,
        'snoozeReasonLabel': reason.label,
        'snoozeMinutes': minutes,
        'soundAsset': _asString(data['soundAsset']) ??
            'assets/audio/ambient_atmospheric/ambient_atmospheric_01.mp3',
        'coachVoiceEnabled': _asBool(data['coachVoiceEnabled'], fallback: true),
        'coachVoiceAsset': _asString(data['coachVoiceAsset']) ??
            'assets/audio/healing_432hz/healing_432hz_01.mp3',
        'vibrationPattern': _asString(data['vibrationPattern']) ?? 'standard',
        'snoozeDurations': _normalizeSnoozeDurations(data['snoozeDurations']),
      },
    );
  }

  Future<void> _startTaskFromAlarm({
    required String uid,
    required String notifId,
    required Map<String, dynamic> data,
  }) async {
    final taskId = _asString(data['taskId']);
    if (taskId == null) return;

    final taskRef =
        _firestore.collection('users').doc(uid).collection('tasks').doc(taskId);
    final snap = await taskRef.get();
    if (!snap.exists) return;
    final task = TaskModel.fromFirestore(snap);
    if (task.state != TaskState.scheduled) return;

    final now = DateTime.now();
    await taskRef.set({
      'state': TaskState.started.toJson(),
      'actualStart': Timestamp.fromDate(now),
      'alarmStartedFromNotifId': notifId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _emitLifecycleEvent(
      uid: uid,
      eventName: EventNames.taskStarted,
      payload: {
        'taskId': task.id,
        'type': task.type.toJson(),
        'plannedStart': task.plannedStart.toIso8601String(),
        'plannedEnd': task.plannedEnd.toIso8601String(),
        'plannedDurationMin': task.plannedDurationMin,
        'actualStart': now.toIso8601String(),
        'notifId': notifId,
      },
    );
  }

  Future<void> _skipTaskFromAlarm({
    required String uid,
    required String notifId,
    required Map<String, dynamic> data,
    required SnoozeReasonResult reason,
  }) async {
    final taskId = _asString(data['taskId']);
    if (taskId == null) return;

    final taskRef =
        _firestore.collection('users').doc(uid).collection('tasks').doc(taskId);
    final snap = await taskRef.get();
    if (!snap.exists) return;
    final task = TaskModel.fromFirestore(snap);
    if (task.state.isTerminal) return;

    final now = DateTime.now();
    await taskRef.set({
      'state': TaskState.skipped.toJson(),
      'skippedAt': Timestamp.fromDate(now),
      'reasonCategory': AbandonReason.userSkipped.toJson(),
      'reasonTag': reason.reason,
      'alarmSkipReasonLabel': reason.label,
      'alarmSkippedFromNotifId': notifId,
      'aiContext': {
        'lastAlarmSkipReason': reason.reason,
        'lastAlarmSkipReasonLabel': reason.label,
        'lastAlarmSkipAt': Timestamp.fromDate(now),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _emitLifecycleEvent(
      uid: uid,
      eventName: EventNames.taskSkipped,
      payload: {
        'taskId': task.id,
        'type': task.type.toJson(),
        'plannedStart': task.plannedStart.toIso8601String(),
        'plannedEnd': task.plannedEnd.toIso8601String(),
        'plannedDurationMin': task.plannedDurationMin,
        'reasonCategory': AbandonReason.userSkipped.toJson(),
        'reasonTag': reason.reason,
        'reasonLabel': reason.label,
        'feedsAiContext': true,
        'aiContext': {
          'kind': 'alarm_skip_reason',
          'reason': reason.reason,
          'reasonLabel': reason.label,
        },
        'notifId': notifId,
      },
    );
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
      final settings = _NotificationUserSettings.fromProfile(data);
      final lastBudgetDate = data['notificationBudgetDate'] as String?;

      transaction.set(
        profileRef,
        {
          'notificationSettings': settings.toFirestore(),
          'dailyNotificationBudget': settings.dailyBudget,
          'notificationsSentToday': lastBudgetDate == today
              ? _asNonNegativeInt(data['notificationsSentToday'])
              : 0,
          'quietDayMode': settings.quietToday,
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
      final settings = _NotificationUserSettings.fromProfile(data);
      final lastBudgetDate = data['notificationBudgetDate'] as String?;
      final sentToday = lastBudgetDate == today
          ? _asNonNegativeInt(data['notificationsSentToday'])
          : 0;
      final categoryGroup = _categoryGroup(category);
      final categorySetting = settings.categorySetting(category);
      final rawCategoryCounts = Map<String, dynamic>.from(
          data['notificationCategoryCounts'] as Map? ??
              const <String, dynamic>{});
      final categoryCounts = lastBudgetDate == today
          ? rawCategoryCounts.map(
              (key, value) => MapEntry(key, _asNonNegativeInt(value)),
            )
          : <String, int>{};
      final sentForCategory = categoryCounts[categoryGroup] ?? 0;
      final quietDayMode = settings.isQuietDay(targetDate);

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
      if (!isCritical && !categorySetting.enabled) {
        reason = 'category_disabled';
      } else if (!isCritical && quietDayMode) {
        reason = 'quiet_day_mode';
      } else if (!isCritical && settings.isInBlackout(targetDate)) {
        reason = 'blackout_window';
      } else if (!isCritical && inQuietHours) {
        reason = 'quiet_hours';
      } else if (!isCritical && sentForCategory >= categorySetting.cap) {
        reason = 'category_cap_exhausted';
      } else if (!isCritical && sentToday >= settings.dailyBudget) {
        reason = 'budget_exhausted';
      }

      final basePatch = <String, dynamic>{
        'notificationSettings': settings.toFirestore(),
        'dailyNotificationBudget': settings.dailyBudget,
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
            'notificationCategoryCounts': categoryCounts,
          },
          SetOptions(merge: true),
        );

        return NotificationBudgetDecision(
          allowed: false,
          reason: reason,
          dailyNotificationBudget: settings.dailyBudget,
          notificationsSentToday: sentToday,
          quietDayMode: quietDayMode,
        );
      }

      categoryCounts[categoryGroup] = sentForCategory + 1;
      transaction.set(
        profileRef,
        {
          ...basePatch,
          'notificationsSentToday': sentToday + 1,
          'notificationCategoryCounts': categoryCounts,
        },
        SetOptions(merge: true),
      );

      return NotificationBudgetDecision(
        allowed: true,
        dailyNotificationBudget: settings.dailyBudget,
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
    Map<String, dynamic>? payloadExtras,
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
    final settings = await _loadNotificationSettings(uid);
    final resolvedDetails =
        _detailsForCategoryWithSettings(category, settings, fallback: details);

    // ── 1. Enqueue local notification ───────────────────────────────────────
    await _plugin.zonedSchedule(
      id: notifId.hashCode & 0x7FFFFFFF, // positive int32 id
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledFor, tz.local),
      notificationDetails: resolvedDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: json.encode({
        'notifId': notifId,
        'uid': uid,
        'category': category,
        if (taskId != null) 'taskId': taskId,
      }),
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
      if (payloadExtras != null) {
        notifDoc.addAll(payloadExtras);
      }

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
    String? reason,
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
        if (reason != null) 'cancellationReason': reason,
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
      case _kAlarmCategory:
        return _kAlarmNotifDetails;
      case NotifCategory.streakMilestone:
      case NotifCategory.streakCongrats:
      case NotifCategory.streakEncouragement:
      case NotifCategory.daySummary:
      case NotifCategory.slipRecovery:
        return _kHabitNotifDetails;
      case NotifCategory.taskReminder:
      case NotifCategory.taskEndReminder:
      default:
        return _kTaskNotifDetails;
    }
  }

  Future<_NotificationUserSettings> _loadNotificationSettings(
      String uid) async {
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('profile')
        .doc('main')
        .get();
    return _NotificationUserSettings.fromProfile(
      snap.data() ?? const <String, dynamic>{},
    );
  }

  static NotificationDetails _detailsForCategoryWithSettings(
    String category,
    _NotificationUserSettings settings, {
    NotificationDetails? fallback,
  }) {
    final base = fallback ?? _detailsForCategory(category);
    if (settings.sound != 'none' && settings.vibration == 'standard') {
      return base;
    }

    final baseAndroid = base.android;
    final channelPrefix = baseAndroid?.channelId ?? 'optivus';
    final channelName = baseAndroid?.channelName ?? 'Optivus Notifications';
    final silent = settings.sound == 'none';
    final vibrationPattern = switch (settings.vibration) {
      'urgent' => Int64List.fromList([0, 240, 120, 240, 120, 360]),
      'soft' => Int64List.fromList([0, 120]),
      'none' => null,
      _ => null,
    };
    final enableVibration = settings.vibration != 'none';

    final android = AndroidNotificationDetails(
      '${channelPrefix}_${settings.sound}_${settings.vibration}',
      channelName,
      channelDescription: baseAndroid?.channelDescription,
      importance: baseAndroid?.importance ?? Importance.defaultImportance,
      priority: baseAndroid?.priority ?? Priority.defaultPriority,
      playSound: !silent,
      enableVibration: enableVibration,
      vibrationPattern: vibrationPattern,
      category: baseAndroid?.category,
      fullScreenIntent: baseAndroid?.fullScreenIntent ?? false,
      autoCancel: baseAndroid?.autoCancel ?? true,
      ongoing: baseAndroid?.ongoing ?? false,
      actions: baseAndroid?.actions,
      audioAttributesUsage: baseAndroid?.audioAttributesUsage ??
          AudioAttributesUsage.notification,
    );

    final darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: !silent,
      categoryIdentifier: base.iOS?.categoryIdentifier,
      interruptionLevel: base.iOS?.interruptionLevel,
    );

    return NotificationDetails(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
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

  static Map<String, _NotificationCategorySetting> _defaultCategorySettings() {
    return const {
      'tasks': _NotificationCategorySetting(enabled: true, cap: 8),
      'coach': _NotificationCategorySetting(enabled: true, cap: 4),
      'streaks': _NotificationCategorySetting(enabled: true, cap: 4),
      'custom': _NotificationCategorySetting(enabled: true, cap: 3),
    };
  }

  static String _categoryGroup(String category) {
    final key = category.toLowerCase();
    if (key.contains('coach')) return 'coach';
    if (key.contains('streak') ||
        key.contains('slip') ||
        key.contains('habit')) {
      return 'streaks';
    }
    if (key.contains('task') || key.contains('routine')) return 'tasks';
    return 'custom';
  }

  static int? _minutesForTime(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
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

  static List<int> _normalizeSnoozeDurations(Object? value) {
    final raw = value is List ? value : const [5, 10];
    final durations = raw
        .whereType<Object>()
        .map((item) => _asNonNegativeInt(item, fallback: 5))
        .where((minutes) => minutes > 0)
        .toSet()
        .toList()
      ..sort();
    return durations.isEmpty ? const [5] : durations;
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
