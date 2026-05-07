// test/services/notification_service_contract_test.dart
import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus2/core/constants/event_names.dart';
import 'package:optivus2/models/scheduled_notification_model.dart';
import 'package:optivus2/models/task_model.dart';
import 'package:optivus2/services/event_service.dart';
import 'package:optivus2/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class MockLocalNotificationsPlugin extends Fake
    implements FlutterLocalNotificationsPlugin {
  bool initialized = false;
  final List<Map<String, dynamic>> scheduled = [];
  final List<int> cancelled = [];
  DidReceiveNotificationResponseCallback? onResponse;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
        onDidReceiveBackgroundNotificationResponse,
  }) async {
    initialized = true;
    onResponse = onDidReceiveNotificationResponse;
    return true;
  }

  @override
  T? resolvePlatformSpecificImplementation<
      T extends FlutterLocalNotificationsPlatform>() {
    return null;
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    scheduled.add({
      'id': id,
      'title': title,
      'body': body,
      'scheduledDate': scheduledDate,
      'payload': payload,
    });
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    cancelled.add(id);
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    return [];
  }

  void respondTo(String payload, {String? actionId}) {
    onResponse?.call(
      NotificationResponse(
        notificationResponseType: actionId == null
            ? NotificationResponseType.selectedNotification
            : NotificationResponseType.selectedNotificationAction,
        actionId: actionId,
        payload: payload,
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late MockLocalNotificationsPlugin plugin;
  late EventService eventService;
  late NotificationService service;
  const uid = 'test_uid';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tz.initializeTimeZones();
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(mockUser: MockUser(uid: uid), signedIn: true);
    plugin = MockLocalNotificationsPlugin();
    eventService = EventService(firestore: firestore, auth: auth);
    service = NotificationService(
      firestore: firestore,
      auth: auth,
      plugin: plugin,
      eventService: eventService,
    );
  });

  group('NotificationService.init', () {
    test('initializes plugin', () async {
      await service.init();
      expect(plugin.initialized, isTrue);
    });

    test('requestPermissions returns false without a platform implementation',
        () async {
      expect(await service.requestPermissions(), isFalse);
    });
  });

  group('NotificationService.scheduleTaskReminder', () {
    final task = TaskModel(
      id: 'task_1',
      title: 'Test Task',
      plannedStart: DateTime.now().add(const Duration(hours: 1)),
      plannedEnd: DateTime.now().add(const Duration(hours: 2)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test('schedules local notification and persists to Firestore', () async {
      final success = await service.scheduleTaskReminder(task, uid);
      expect(success, isTrue);

      expect(plugin.scheduled.length, 1);
      expect(plugin.scheduled.first['title'], contains('Test Task'));

      final snapshots = await firestore
          .collection('users')
          .doc(uid)
          .collection('scheduled_notifications')
          .get();
      expect(snapshots.docs.length, 1);
      expect(
          snapshots.docs.first.data()['category'], NotifCategory.taskReminder);
      expect(snapshots.docs.first.data()['status'], NotifStatus.pending);
    });

    test('deduplicates by deterministic ID', () async {
      await service.scheduleTaskReminder(task, uid);
      await service.scheduleTaskReminder(task, uid);

      final snapshots = await firestore
          .collection('users')
          .doc(uid)
          .collection('scheduled_notifications')
          .get();
      // Should only have 1 doc because of deterministic ID
      expect(snapshots.docs.length, 1);
      expect(plugin.scheduled.length, 1);
    });
  });

  group('NotificationService lifecycle recording', () {
    const notifId = 'notif_123';
    const category = 'test_cat';

    test('recordTapped updates status and writes to notificationLog', () async {
      await service.recordTapped(notifId, uid, category);

      final notifDoc = await firestore
          .collection('users')
          .doc(uid)
          .collection('scheduled_notifications')
          .doc(notifId)
          .get();
      expect(notifDoc.data()?['status'], NotifStatus.tapped);

      final logs = await firestore
          .collection('users')
          .doc(uid)
          .collection('notificationLog')
          .get();
      expect(logs.docs.length, 1);
      expect(logs.docs.first.data()['notifId'], notifId);
      expect(logs.docs.first.data()['status'], NotifStatus.tapped);
    });

    test('record methods update status, notificationLog, and events_recent',
        () async {
      await service.recordSent(notifId, uid, category);
      await service.recordTapped(notifId, uid, category);
      await service.recordDismissed(notifId, uid, category);
      await service.recordSuppressed(
        notifId,
        uid,
        category,
        'quiet_hours',
      );
      await service.recordMissed(notifId, uid, category);

      final logs = await firestore
          .collection('users')
          .doc(uid)
          .collection('notificationLog')
          .get();
      final loggedEvents =
          logs.docs.map((doc) => doc.data()['eventName']).toSet();
      expect(loggedEvents, contains(EventNames.notificationSent));
      expect(loggedEvents, contains(EventNames.notificationTapped));
      expect(loggedEvents, contains(EventNames.notificationDismissed));
      expect(loggedEvents, contains(EventNames.notificationSuppressed));
      expect(loggedEvents, contains(EventNames.notificationMissed));

      final recentEvents = await firestore
          .collection('users')
          .doc(uid)
          .collection('events_recent')
          .get();
      final recentNames =
          recentEvents.docs.map((doc) => doc.data()['eventName']).toSet();
      expect(recentNames, contains(EventNames.notificationSent));
      expect(recentNames, contains(EventNames.notificationTapped));
      expect(recentNames, contains(EventNames.notificationDismissed));
      expect(recentNames, contains(EventNames.notificationSuppressed));
      expect(recentNames, contains(EventNames.notificationMissed));
    });

    test('record methods write events_recent without EventService', () async {
      final serviceWithoutEventBus = NotificationService(
        firestore: firestore,
        auth: auth,
        plugin: plugin,
      );

      await serviceWithoutEventBus.recordSent(notifId, uid, category);

      final recentEvents = await firestore
          .collection('users')
          .doc(uid)
          .collection('events_recent')
          .where('eventName', isEqualTo: EventNames.notificationSent)
          .get();
      expect(recentEvents.docs.length, 1);
      expect(recentEvents.docs.first.data()['payload']['notifId'], notifId);
    });

    test('tap callback records notification_tapped from payload', () async {
      await service.init();
      plugin.respondTo(json.encode({
        'notifId': notifId,
        'uid': uid,
        'category': category,
      }));
      await Future<void>.delayed(Duration.zero);

      final notifDoc = await firestore
          .collection('users')
          .doc(uid)
          .collection('scheduled_notifications')
          .doc(notifId)
          .get();
      expect(notifDoc.data()?['status'], NotifStatus.tapped);
    });
  });

  group('NotificationService public scheduling methods', () {
    test('scheduleForTask schedules start and end reminders', () async {
      final task = TaskModel(
        id: 'task_for_task',
        title: 'Task API',
        parentRoutine: 'morning_template',
        plannedStart: DateTime.now().add(const Duration(hours: 2)),
        plannedEnd: DateTime.now().add(const Duration(hours: 3)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await service.scheduleForTask(task);

      expect(plugin.scheduled.length, 2);
      final snapshots = await firestore
          .collection('users')
          .doc(uid)
          .collection('scheduled_notifications')
          .get();
      final categories =
          snapshots.docs.map((doc) => doc.data()['category']).toSet();
      expect(categories, contains(NotifCategory.taskReminder));
      expect(categories, contains(NotifCategory.taskEndReminder));
    });

    test('scheduleForRoutineTemplate dedupes by template/date/time/category',
        () async {
      final date = DateTime.now().add(const Duration(days: 1));
      final template = {
        'templateId': 'morning_template',
        'startTime': '08:30',
        'title': 'Morning routine',
        'routineType': 'routine',
      };

      await service.scheduleForRoutineTemplate(template, date, uid);
      await service.scheduleForRoutineTemplate({
        ...template,
        'title': 'Morning routine renamed',
      }, date, uid);

      expect(plugin.scheduled.length, 1);
      final snapshots = await firestore
          .collection('users')
          .doc(uid)
          .collection('scheduled_notifications')
          .get();
      expect(snapshots.docs.length, 1);
      expect(
        snapshots.docs.first.data()['routineTemplateId'],
        'morning_template',
      );

      final profile = await firestore
          .collection('users')
          .doc(uid)
          .collection('profile')
          .doc('main')
          .get();
      expect(profile.data()?['notificationsSentToday'], 1);

      final logs = await firestore
          .collection('users')
          .doc(uid)
          .collection('notificationLog')
          .where('eventName', isEqualTo: EventNames.notificationScheduled)
          .get();
      expect(logs.docs.length, 1);
    });

    test('scheduleCustom persists and cancel marks cancelled', () async {
      await service.scheduleCustom({
        'entityId': 'custom_1',
        'title': 'Custom reminder',
        'body': 'Custom body',
        'category': 'custom',
        'scheduledFor': DateTime.now().add(const Duration(hours: 1)),
      }, uid);

      final snapshots = await firestore
          .collection('users')
          .doc(uid)
          .collection('scheduled_notifications')
          .get();
      expect(snapshots.docs.length, 1);

      final notifId = snapshots.docs.first.id;
      await service.cancel(notifId, uid);

      final cancelled = await firestore
          .collection('users')
          .doc(uid)
          .collection('scheduled_notifications')
          .doc(notifId)
          .get();
      expect(cancelled.data()?['status'], NotifStatus.cancelled);
      expect(plugin.cancelled, contains(notifId.hashCode & 0x7FFFFFFF));
    });
  });

  group('NotificationService.reRegisterAllOnAppStart', () {
    test('re-registers pending future notifications', () async {
      final fireAt = DateTime.now().add(const Duration(hours: 1));
      final notif = ScheduledNotification(
        notifId: 'future_notif',
        category: 'test',
        scheduledFor: fireAt,
        createdAt: DateTime.now(),
        status: NotifStatus.pending,
        title: 'Future Title',
      );

      await firestore
          .collection('users')
          .doc(uid)
          .collection('scheduled_notifications')
          .doc(notif.notifId)
          .set(notif.toFirestore());

      await service.reRegisterAllOnAppStart();

      expect(plugin.scheduled.length, 1);
      expect(plugin.scheduled.first['title'], 'Future Title');
    });

    test('re-register is idempotent during the same app run', () async {
      final fireAt = DateTime.now().add(const Duration(hours: 1));
      final notif = ScheduledNotification(
        notifId: 'future_idempotent',
        category: 'test',
        scheduledFor: fireAt,
        createdAt: DateTime.now(),
        status: NotifStatus.pending,
        title: 'Future Idempotent',
      );

      await firestore
          .collection('users')
          .doc(uid)
          .collection('scheduled_notifications')
          .doc(notif.notifId)
          .set(notif.toFirestore());

      await service.reRegisterAllOnAppStart();
      await service.reRegisterAllOnAppStart();

      expect(plugin.scheduled.length, 1);
    });

    test('marks past pending notifications as missed', () async {
      final fireAt = DateTime.now().subtract(const Duration(hours: 1));
      final notif = ScheduledNotification(
        notifId: 'past_notif',
        category: 'test',
        scheduledFor: fireAt,
        createdAt: DateTime.now(),
        status: NotifStatus.pending,
      );

      await firestore
          .collection('users')
          .doc(uid)
          .collection('scheduled_notifications')
          .doc(notif.notifId)
          .set(notif.toFirestore());

      await service.reRegisterAllOnAppStart();

      final notifDoc = await firestore
          .collection('users')
          .doc(uid)
          .collection('scheduled_notifications')
          .doc(notif.notifId)
          .get();
      expect(notifDoc.data()?['status'], NotifStatus.missed);

      final logs = await firestore
          .collection('users')
          .doc(uid)
          .collection('notificationLog')
          .where('eventName', isEqualTo: EventNames.notificationMissed)
          .get();
      expect(logs.docs.length, 1);
    });
  });

  group('NotificationService quiet hours and budget', () {
    setUp(() async {
      await firestore
          .collection('users')
          .doc(uid)
          .collection('profile')
          .doc('main')
          .set({
        'dailyNotificationBudget': 1,
        'notificationsSentToday': 0,
        'quietDayMode': false,
        'bodyBasics': {
          'wakeTime': '07:00',
          'sleepTime': '22:00',
        }
      });
    });

    test('suppresses when budget is exhausted', () async {
      // Use up the budget
      await service.reserveNotificationSlot(
          uid: uid, intentDescription: 'test1', category: 'test');

      final decision = await service.reserveNotificationSlot(
          uid: uid, intentDescription: 'test2', category: 'test');
      expect(decision.allowed, isFalse);
      expect(decision.reason, 'budget_exhausted');
    });

    test('scheduleCustom applies budget before enqueue and records suppression',
        () async {
      final now = DateTime.now();
      var allowedTime = DateTime(now.year, now.month, now.day, 12);
      if (!allowedTime.isAfter(now)) {
        allowedTime = allowedTime.add(const Duration(days: 1));
      }

      await service.scheduleCustom({
        'entityId': 'allowed',
        'title': 'Allowed reminder',
        'category': 'test',
        'scheduledFor': allowedTime,
      }, uid);

      await service.scheduleCustom({
        'entityId': 'blocked',
        'title': 'Blocked reminder',
        'category': 'test',
        'scheduledFor': allowedTime.add(const Duration(hours: 1)),
      }, uid);

      expect(plugin.scheduled.length, 1);

      final suppressed = await firestore
          .collection('users')
          .doc(uid)
          .collection('scheduled_notifications')
          .where('status', isEqualTo: NotifStatus.suppressed)
          .get();
      expect(suppressed.docs.length, 1);

      final logs = await firestore
          .collection('users')
          .doc(uid)
          .collection('notificationLog')
          .where('eventName', isEqualTo: EventNames.notificationSuppressed)
          .get();
      expect(logs.docs.length, 1);

      final recentEvents = await firestore
          .collection('users')
          .doc(uid)
          .collection('events_recent')
          .where('eventName', isEqualTo: EventNames.notificationSuppressed)
          .get();
      expect(recentEvents.docs.length, 1);
    });

    test('suppresses during quiet hours', () async {
      final quietTime = DateTime(2024, 1, 1, 2, 0); // 2 AM
      final decision = await service.reserveNotificationSlot(
        uid: uid,
        intentDescription: 'test',
        category: 'test',
        scheduledFor: quietTime,
      );
      expect(decision.allowed, isFalse);
      expect(decision.reason, 'quiet_hours');
    });

    test('scheduleCustom applies quiet hours before enqueue', () async {
      final now = DateTime.now();
      var quietTime = DateTime(now.year, now.month, now.day, 2);
      if (!quietTime.isAfter(now)) {
        quietTime = quietTime.add(const Duration(days: 1));
      }

      await service.scheduleCustom({
        'entityId': 'quiet_blocked',
        'title': 'Quiet reminder',
        'category': 'test',
        'scheduledFor': quietTime,
      }, uid);

      expect(plugin.scheduled, isEmpty);

      final suppressed = await firestore
          .collection('users')
          .doc(uid)
          .collection('scheduled_notifications')
          .where('status', isEqualTo: NotifStatus.suppressed)
          .get();
      expect(suppressed.docs.length, 1);
      expect(suppressed.docs.first.data()['status'], NotifStatus.suppressed);
    });

    test('isCritical bypasses quiet hours and budget', () async {
      // Use up budget
      await service.reserveNotificationSlot(
          uid: uid, intentDescription: 'test1', category: 'test');

      final quietTime = DateTime(2024, 1, 1, 2, 0); // 2 AM
      final decision = await service.reserveNotificationSlot(
        uid: uid,
        intentDescription: 'test',
        category: 'test',
        scheduledFor: quietTime,
        isCritical: true,
      );
      expect(decision.allowed, isTrue);
    });

    test('scheduleCustom carries metadata and critical bypass', () async {
      final now = DateTime.now();
      var quietTime = DateTime(now.year, now.month, now.day, 2);
      if (!quietTime.isAfter(now)) {
        quietTime = quietTime.add(const Duration(days: 1));
      }

      await service.scheduleCustom({
        'entityId': 'critical_custom',
        'taskId': 'task_custom',
        'habitId': 'habit_custom',
        'title': 'Critical reminder',
        'category': 'test',
        'priority': 'P1',
        'intentDescription': 'critical_custom_intent',
        'triggerEventId': 'event_custom',
        'isCritical': true,
        'scheduledFor': quietTime,
      }, uid);

      expect(plugin.scheduled.length, 1);

      final snapshots = await firestore
          .collection('users')
          .doc(uid)
          .collection('scheduled_notifications')
          .get();
      expect(snapshots.docs.length, 1);
      final data = snapshots.docs.first.data();
      expect(data['taskId'], 'task_custom');
      expect(data['habitId'], 'habit_custom');
      expect(data['priority'], 'P1');
      expect(data['intentDescription'], 'critical_custom_intent');
      expect(data['triggerEventId'], 'event_custom');
    });
  });
}
