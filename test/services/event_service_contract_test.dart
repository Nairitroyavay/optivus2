// test/services/event_service_contract_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:optivus2/core/constants/event_names.dart';
import 'package:optivus2/core/errors/app_errors.dart';
import 'package:optivus2/core/utils/uuid_generator.dart';
import 'package:optivus2/services/event_service.dart';
import 'package:optivus2/services/event_payload_validator.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late EventService service;
  const uid = 'test_uid_123';

  final validPayload = {
    'email': 'test@example.com',
    'signup_ts': DateTime.now().toUtc().toIso8601String(),
    'signup_source': 'google',
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    firestore = FakeFirebaseFirestore();
    final mockUser = MockUser(uid: uid);
    auth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
    service = EventService(firestore: firestore, auth: auth);
  });

  tearDown(() {
    service.dispose();
  });

  // ── emit ────────────────────────────────────────────────────────────────────

  group('EventService.emit — happy path', () {
    test('writes doc to /users/{uid}/events/{eventId}', () async {
      await service.emit(
        eventName: 'user_signed_up',
        payload: validPayload,
        eventId: 'my_custom_event_id',
      );

      final doc = await firestore
          .collection('users')
          .doc(uid)
          .collection('events')
          .doc('my_custom_event_id')
          .get();

      expect(doc.exists, isTrue);
      expect(doc.data()!['eventName'], 'user_signed_up');
      expect(doc.data()!['eventId'], 'my_custom_event_id');
      expect(doc.data()!['uid'], uid);
      expect(doc.data()!['timestamp'], isA<Timestamp>());
      expect(doc.data()!['source'], 'ui');
      expect(doc.data()!['schemaVersion'], 1);
      expect(doc.data()!['payloadVersion'], 1);
      expect(doc.data()!['payload'], validPayload);
      expect(doc.data()!['deviceId'], isA<String>());
      expect(doc.data()!['appVersion'], '1.0.0');
    });

    test('writes doc to /users/{uid}/events_recent/{eventId}', () async {
      await service.emit(
        eventName: 'user_signed_up',
        payload: validPayload,
        eventId: 'my_custom_event_id',
      );

      final doc = await firestore
          .collection('users')
          .doc(uid)
          .collection('events_recent')
          .doc('my_custom_event_id')
          .get();

      expect(doc.exists, isTrue);
      expect(doc.data()!['eventName'], 'user_signed_up');

      final eventDoc = await firestore
          .collection('users')
          .doc(uid)
          .collection('events')
          .doc('my_custom_event_id')
          .get();
      expect(doc.data(), eventDoc.data());
    });

    test('publishes event on the local _eventBus stream', () async {
      final futureEvent = service.on('user_signed_up').first;

      await service.emit(
        eventName: 'user_signed_up',
        payload: validPayload,
        eventId: 'my_custom_event_id',
      );

      final event = await futureEvent;
      expect(event.eventName, 'user_signed_up');
      expect(event.eventId, 'my_custom_event_id');
    });

    test('persists eventId to SharedPreferences processed-id cache', () async {
      await service.emit(
        eventName: 'user_signed_up',
        payload: validPayload,
        eventId: 'my_custom_event_id',
      );

      await Future.delayed(
          const Duration(milliseconds: 50)); // Wait for unawaited persistence

      final prefs = await SharedPreferences.getInstance();
      final processedIds =
          prefs.getStringList('optivus_processed_events') ?? [];
      expect(processedIds, contains('my_custom_event_id'));
    });
  });

  group('EventService.emit — idempotency / deduplication', () {
    test('skips write when Firestore doc already exists for the same eventId',
        () async {
      await firestore
          .collection('users')
          .doc(uid)
          .collection('events')
          .doc('idempotent_id')
          .set({'dummy': 'data'});

      int eventsCountBefore = (await firestore
              .collection('users')
              .doc(uid)
              .collection('events')
              .get())
          .docs
          .length;

      // Should skip
      await service.emit(
        eventName: 'user_signed_up',
        payload: validPayload,
        eventId: 'idempotent_id',
      );

      int eventsCountAfter = (await firestore
              .collection('users')
              .doc(uid)
              .collection('events')
              .get())
          .docs
          .length;

      expect(eventsCountAfter, eventsCountBefore);
    });

    test('generates deterministic eventId from eventName + ts + payload',
        () async {
      final futureEvent = service.onAny().first;

      await service.emit(
        eventName: 'user_signed_up',
        payload: validPayload,
      );

      final emitted = await futureEvent;

      final expectedId = generateDeterministicId(
        eventName: 'user_signed_up',
        timestamp: emitted.timestamp,
        uid: uid,
        source: 'ui',
        payloadVersion: 1,
        payload: validPayload,
      );

      expect(emitted.eventId, expectedId);
    });

    test('caller-supplied eventId overrides deterministic ID', () async {
      await service.emit(
        eventName: 'user_signed_up',
        payload: validPayload,
        eventId: 'custom_123',
      );

      final doc = await firestore
          .collection('users')
          .doc(uid)
          .collection('events')
          .doc('custom_123')
          .get();

      expect(doc.exists, isTrue);
    });
  });

  group('EventService.emit — WriteBatch passthrough', () {
    test('when batch is provided, sets docs on batch instead of committing',
        () async {
      final batch = firestore.batch();

      await service.emit(
        eventName: 'user_signed_up',
        payload: validPayload,
        eventId: 'batched_event',
        batch: batch,
      );

      // Doc shouldn't exist before commit
      final docBefore = await firestore
          .collection('users')
          .doc(uid)
          .collection('events')
          .doc('batched_event')
          .get();
      expect(docBefore.exists, isFalse);

      await batch.commit();

      // Doc should exist after commit
      final docAfter = await firestore
          .collection('users')
          .doc(uid)
          .collection('events')
          .doc('batched_event')
          .get();
      expect(docAfter.exists, isTrue);
    });
  });

  group('EventService.emit — error cases', () {
    test('throws NotAuthenticatedError when no user is signed in', () async {
      final unauthAuth = MockFirebaseAuth(signedIn: false);
      final unauthService =
          EventService(firestore: firestore, auth: unauthAuth);

      expect(
        () => unauthService.emit(
            eventName: 'user_signed_up', payload: validPayload),
        throwsA(isA<NotAuthenticatedError>()),
      );

      unauthService.dispose();
    });

    test('throws FlutterError on invalid payload in debug builds', () async {
      expect(
        () => service
            .emit(eventName: 'user_signed_up', payload: {'invalid': 'payload'}),
        throwsA(isA<FlutterError>()),
      );
    });
  });

  group('EventPayloadValidator', () {
    test('registers validators for every canonical event name', () {
      for (final eventName in EventNames.all) {
        expect(
          EventPayloadValidator.hasRule(eventName),
          isTrue,
          reason: '$eventName must be registered in EventPayloadValidator',
        );
      }
    });

    test('accepts routine template events after constants registration', () {
      final payload = {
        'templateId': 'template_1',
        'routineType': 'fixed_schedule',
      };

      expect(
        EventPayloadValidator.isValid(
          EventNames.routineTemplateCreated,
          payload,
        ),
        isTrue,
      );
      expect(
        EventPayloadValidator.isValid(
          EventNames.routineTemplateUpdated,
          payload,
        ),
        isTrue,
      );
      expect(
        EventPayloadValidator.isValid(
          EventNames.routineTemplateDeleted,
          payload,
        ),
        isTrue,
      );
    });

    test('accepts Task 1.5 focus event payloads from emitters', () {
      final cases = <String, Map<String, dynamic>>{
        EventNames.routineWindowMissed: {
          'routine': 'gym',
          'completion': 0,
        },
        EventNames.routineBlockCompleted: {
          'taskId': 'task_1',
          'routineType': 'fixed_schedule',
          'routineId': 'routine_1',
          'date': '2026-05-09',
        },
        EventNames.screenTimeSynced: {
          'logId': 'screen_2026_05_09',
          'totalMinutes': 45,
        },
        EventNames.coachMessageSent: {
          'turnId': 'msg_user_1',
        },
        EventNames.coachReplied: {
          'turnId': 'msg_coach_1',
        },
        EventNames.suggestionGenerated: {
          'suggestionId': 'suggestion_1',
        },
        EventNames.notificationMissed: {
          'notifId': 'notif_1',
          'category': 'routine',
          'status': 'missed',
        },
        EventNames.comebackInitiated: {
          'uid': 'test_uid_123',
          'gapDays': 3,
        },
        EventNames.comebackPathChosen: {
          'path': 'gentle',
          'gapDays': 3,
        },
        EventNames.fitnessActivityCompleted: {
          'activityId': 'activity_1',
          'activityType': 'running',
        },
        EventNames.badHabitSlipLogged: {
          'packageName': 'com.example.app',
          'habitName': 'Example App',
          'logId': 'screen_time_com_example_app_daily_2026_05_09',
          'screenTimeLogId': 'daily_2026_05_09',
          'crossingCount': 2,
          'triggerTag': 'cap_crossed',
        },
      };

      for (final entry in cases.entries) {
        expect(
          EventPayloadValidator.isValid(entry.key, entry.value),
          isTrue,
          reason: '${entry.key} should accept ${entry.value}',
        );
      }
    });

    test('rejects unknown events', () {
      expect(EventPayloadValidator.isValid('unknown_event', {}), isFalse);
    });

    test('rejects malformed routine window missed payloads', () {
      final result = EventPayloadValidator.validate(
        EventNames.routineWindowMissed,
        {'routine': 'gym'},
      );

      expect(result.isValid, isFalse);
      expect(
        result.message,
        contains('completion or completionPct or completion_pct'),
      );
    });

    test('rejects malformed bad habit slip payloads', () {
      final result = EventPayloadValidator.validate(
        EventNames.badHabitSlipLogged,
        {'logId': 'slip_1'},
      );

      expect(result.isValid, isFalse);
      expect(
        result.message,
        contains(
          'habitId or habit_id or packageName or package_name or '
          'screenTimeLogId or screen_time_log_id',
        ),
      );
    });
  });

  group('EventPayloadValidator (Strict Rules)', () {
    test('accepts valid payload with default priority', () {
      expect(
        EventPayloadValidator.isValid(
            EventNames.accountDeleted, {'uid': '123', 'priority': 'high'}),
        isTrue,
      );
      expect(
        EventPayloadValidator.isValid(
            EventNames.screenTimeSynced, {'logId': 'log1', 'totalMinutes': 45}),
        isTrue,
      );
      expect(
        EventPayloadValidator.isValid(
            EventNames.slipLogDismissed, {'logId': 'log1', 'habitId': 'h1'}),
        isTrue,
      );
      expect(
        EventPayloadValidator.isValid(
            EventNames.badDayDetected, {'date': '2023-10-10'}),
        isTrue,
      );
      expect(
        EventPayloadValidator.isValid(
            EventNames.weeklyInsightReady, {'insightId': 'w1'}),
        isTrue,
      );
      expect(
        EventPayloadValidator.isValid(
            EventNames.comebackPathChosen, {'path': 'gentle'}),
        isTrue,
      );
      expect(
        EventPayloadValidator.isValid(
            EventNames.notificationMissed, {'notifId': 'n1'}),
        isTrue,
      );
      expect(
        EventPayloadValidator.isValid(
            EventNames.coachReEnabled, {'reason': 'user_tapped'}),
        isTrue,
      );
    });

    test('rejects payload with missing fields', () {
      final result = EventPayloadValidator.validate(
          EventNames.screenTimeSynced, {'logId': 'log1'});
      expect(result.isValid, isFalse);
      expect(result.message, contains('missing totalMinutes or total_minutes'));
    });

    test('rejects payload with wrong type', () {
      final result = EventPayloadValidator.validate(EventNames.screenTimeSynced,
          {'logId': 'log1', 'totalMinutes': 'not_an_int'});
      expect(result.isValid, isFalse);
      expect(result.message, contains('wrong type for totalMinutes'));
    });

    test('rejects unknown fields in debug mode', () {
      final result = EventPayloadValidator.validate(
          EventNames.comebackPathChosen,
          {'path': 'gentle', 'unknown_field': 123});
      // In tests, kDebugMode is true
      expect(result.isValid, isFalse);
      expect(result.message, contains('Unknown fields in payload'));
    });
  });

  // ── on / onAny ──────────────────────────────────────────────────────────────

  group('EventService.on', () {
    test('returns stream that emits only events matching eventName', () async {
      final events = <String>[];
      service.on('user_signed_up').listen((e) => events.add(e.eventName));

      await service.emit(
          eventName: 'user_signed_up', payload: validPayload, eventId: '1');
      await service.emit(
          eventName: 'account_deleted',
          payload: {
            'user_id': 'test_uid_123',
            'deleted_at': '123',
            'scheduled_purge_at': '123'
          },
          eventId: '2');

      await Future.delayed(Duration.zero);
      expect(events, ['user_signed_up']);
    });
  });

  group('EventService.onAny', () {
    test('emits every event regardless of eventName', () async {
      final events = <String>[];
      service.onAny().listen((e) => events.add(e.eventName));

      await service.emit(
          eventName: 'user_signed_up', payload: validPayload, eventId: '1');
      await service.emit(
          eventName: 'account_deleted',
          payload: {
            'user_id': 'test_uid_123',
            'deleted_at': '123',
            'scheduled_purge_at': '123'
          },
          eventId: '2');

      await Future.delayed(Duration.zero);
      expect(events, ['user_signed_up', 'account_deleted']);
    });
  });

  // ── replayRecentEvents ───────────────────────────────────────────────────────

  group('EventService.replayRecentEvents', () {
    test('publishes unprocessed events from events_recent on the local bus',
        () async {
      await firestore
          .collection('users')
          .doc(uid)
          .collection('events_recent')
          .doc('past_1')
          .set({
        'eventId': 'past_1',
        'eventName': 'user_signed_up',
        'uid': uid,
        'timestamp': DateTime.now()
            .subtract(const Duration(minutes: 5))
            .toUtc()
            .toIso8601String(),
        'source': 'ui',
        'deviceId': 'test_dev',
        'appVersion': '1.0.0',
        'payload': validPayload,
      });

      final events = <String>[];
      service.onAny().listen((e) => events.add(e.eventId));

      await service.replayRecentEvents();
      await Future.delayed(Duration.zero);

      expect(events, contains('past_1'));
    });

    test('skips events whose IDs are already in the processed cache', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('optivus_processed_events', ['past_skipped']);

      await firestore
          .collection('users')
          .doc(uid)
          .collection('events_recent')
          .doc('past_skipped')
          .set({
        'eventId': 'past_skipped',
        'eventName': 'user_signed_up',
        'uid': uid,
        'timestamp': DateTime.now()
            .subtract(const Duration(minutes: 5))
            .toUtc()
            .toIso8601String(),
        'source': 'ui',
        'deviceId': 'test_dev',
        'appVersion': '1.0.0',
        'payload': validPayload,
      });

      final events = <String>[];
      service.onAny().listen((e) => events.add(e.eventId));

      await service.replayRecentEvents();
      await Future.delayed(Duration.zero);

      expect(events, isNot(contains('past_skipped')));
    });

    test('limits replay to the 50 most recent documents', () async {
      for (int i = 0; i < 55; i++) {
        await firestore
            .collection('users')
            .doc(uid)
            .collection('events_recent')
            .doc('past_$i')
            .set({
          'eventId': 'past_$i',
          'eventName': 'user_signed_up',
          'uid': uid,
          'timestamp': DateTime.now()
              .subtract(Duration(minutes: 60 - i))
              .toUtc()
              .toIso8601String(),
          'source': 'ui',
          'deviceId': 'test_dev',
          'appVersion': '1.0.0',
          'payload': validPayload,
        });
      }

      final events = <String>[];
      service.onAny().listen((e) => events.add(e.eventId));

      await service.replayRecentEvents();
      await Future.delayed(Duration.zero);

      expect(events.length, 50);
    });
  });

  // ── dispose ─────────────────────────────────────────────────────────────────

  group('EventService.dispose', () {
    test('closes the internal StreamController without error', () {
      expect(() => service.dispose(), returnsNormally);
    });
  });
}
