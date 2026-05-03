// test/services/habit_service_contract_test.dart
//
// Contract tests for HabitService.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:optivus2/core/constants/event_names.dart';
import 'package:optivus2/core/errors/app_errors.dart';
import 'package:optivus2/models/habit_log_model.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/services/event_service.dart';
import 'package:optivus2/services/habit_service.dart';

const _kUid = 'habit_user_123';

HabitModel _goodHabit({
  String id = 'water',
  String name = 'Drink water',
  HabitState state = HabitState.active,
  num dailyGoal = 8,
}) {
  final now = DateTime(2026, 5, 2, 8);
  return HabitModel(
    id: id,
    name: name,
    kind: HabitKind.good,
    unit: 'glasses',
    trackerType: 'water',
    dailyGoal: dailyGoal,
    state: state,
    createdAt: now,
    updatedAt: now,
  );
}

HabitModel _badHabit({
  String id = 'smoking',
  String name = 'Smoking',
  HabitState state = HabitState.active,
  BadHabitGoalType goalType = BadHabitGoalType.eliminate,
  num? target,
}) {
  final now = DateTime(2026, 5, 2, 8);
  return HabitModel(
    id: id,
    name: name,
    kind: HabitKind.bad,
    unit: 'count',
    trackerType: 'smoking',
    goalType: goalType,
    target: target,
    state: state,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late EventService eventService;
  late HabitService service;

  CollectionReference<Map<String, dynamic>> habitsColl() =>
      firestore.collection('users').doc(_kUid).collection('habits');
  CollectionReference<Map<String, dynamic>> logsColl() =>
      firestore.collection('users').doc(_kUid).collection('habit_logs');
  CollectionReference<Map<String, dynamic>> eventsColl() =>
      firestore.collection('users').doc(_kUid).collection('events');

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> eventsNamed(
    String eventName,
  ) async {
    final snap =
        await eventsColl().where('eventName', isEqualTo: eventName).get();
    return snap.docs;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(mockUser: MockUser(uid: _kUid), signedIn: true);
    eventService = EventService(firestore: firestore, auth: auth);
    service = HabitService(
      eventService: eventService,
      firestore: firestore,
      auth: auth,
    );
  });

  tearDown(() => eventService.dispose());

  group('HabitService.createHabit', () {
    test('writes active habit doc and emits habit_created', () async {
      final habitId = await service.createHabit(_goodHabit());

      expect(habitId, 'water');
      final doc = await habitsColl().doc('water').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['habitId'], 'water');
      expect(doc.data()!['state'], 'active');
      expect(doc.data()!['schemaVersion'], 1);

      final events = await eventsNamed(EventNames.habitCreated);
      expect(events.length, 1);
      expect(events.first.data()['payload']['habitId'], 'water');
    });

    test('rejects blank name', () async {
      await expectLater(
        service.createHabit(_goodHabit(name: '   ')),
        throwsA(isA<InvalidHabitInputError>()),
      );
    });

    test('rejects invalid good target', () async {
      await expectLater(
        service.createHabit(_goodHabit(dailyGoal: 0)),
        throwsA(isA<InvalidHabitInputError>()),
      );
    });

    test('rejects invalid bad target', () async {
      await expectLater(
        service.createHabit(_badHabit(
          goalType: BadHabitGoalType.reduceToTarget,
        )),
        throwsA(isA<InvalidHabitInputError>()),
      );
    });

    test('throws NotAuthenticatedError when no user is signed in', () async {
      final unauth = MockFirebaseAuth(signedIn: false);
      final unauthService = HabitService(
        eventService: EventService(firestore: firestore, auth: unauth),
        firestore: firestore,
        auth: unauth,
      );

      await expectLater(
        unauthService.createHabit(_goodHabit()),
        throwsA(isA<NotAuthenticatedError>()),
      );
    });
  });

  group('HabitService.updateHabit', () {
    test('updates fields and emits habit_updated', () async {
      await service.createHabit(_goodHabit());
      await service.updateHabit(_goodHabit(name: 'Hydrate'));

      final doc = await habitsColl().doc('water').get();
      expect(doc.data()!['name'], 'Hydrate');
      expect(doc.data()!['updatedAt'], isA<Timestamp>());

      final events = await eventsNamed(EventNames.habitUpdated);
      expect(events.length, 1);
      expect(events.first.data()['payload']['habitName'], 'Hydrate');
    });

    test('throws HabitNotFoundError when missing', () async {
      await expectLater(
        service.updateHabit(_goodHabit(id: 'missing')),
        throwsA(isA<HabitNotFoundError>()),
      );
    });
  });

  group('HabitService pause/resume/archive/delete', () {
    test('pause and resume transition state and emit lifecycle events',
        () async {
      await service.createHabit(_goodHabit());
      await service.pauseHabit('water');

      var doc = await habitsColl().doc('water').get();
      expect(doc.data()!['state'], 'paused');
      expect(doc.data()!['pausedAt'], isA<Timestamp>());

      await service.resumeHabit('water');
      doc = await habitsColl().doc('water').get();
      expect(doc.data()!['state'], 'active');
      expect(doc.data()!.containsKey('pausedAt'), isFalse);

      expect((await eventsNamed(EventNames.habitPaused)).length, 1);
      expect((await eventsNamed(EventNames.habitResumed)).length, 1);
    });

    test('archive transitions state and emits habit_archived', () async {
      await service.createHabit(_goodHabit());
      await service.archiveHabit('water');

      final doc = await habitsColl().doc('water').get();
      expect(doc.data()!['state'], 'archived');
      expect(doc.data()!['archivedAt'], isA<Timestamp>());
      expect((await eventsNamed(EventNames.habitArchived)).length, 1);
    });

    test('delete requires confirmation when destructive', () async {
      await service.createHabit(_goodHabit());

      await expectLater(
        service.deleteHabit('water'),
        throwsA(isA<InvalidHabitInputError>()),
      );

      expect((await habitsColl().doc('water').get()).exists, isTrue);
    });

    test('confirmed delete removes habit doc, preserves logs, emits deleted',
        () async {
      await service.createHabit(_goodHabit());
      final logId = await service.logGood(
        'water',
        amount: 2,
        occurredAt: DateTime(2026, 5, 2, 9),
      );

      await service.deleteHabit('water', confirmDestructive: true);

      expect((await habitsColl().doc('water').get()).exists, isFalse);
      expect((await logsColl().doc(logId).get()).exists, isTrue);
      expect((await eventsNamed(EventNames.habitDeleted)).length, 1);
    });
  });

  group('HabitService reads', () {
    test('watchHabits defaults can filter active habits', () async {
      await service.createHabit(_goodHabit(id: 'active'));
      await service.createHabit(_goodHabit(id: 'paused'));
      await service.pauseHabit('paused');

      final active = await service.watchHabits(filter: HabitState.active).first;
      expect(active.map((h) => h.id), ['active']);
    });

    test('getHabit returns model or null', () async {
      await service.createHabit(_goodHabit());

      expect((await service.getHabit('water'))!.name, 'Drink water');
      expect(await service.getHabit('missing'), isNull);
    });

    test('watchHabitLogsForDate reads canonical logs for date', () async {
      await service.createHabit(_goodHabit());
      final date = DateTime(2026, 5, 2, 9);
      final logId = await service.logGood('water', amount: 2, occurredAt: date);

      final logs = await service.watchHabitLogsForDate(date).first;
      expect(logs.map((l) => l.logId), contains(logId));
      expect(logs.first, isA<HabitLog>());
    });

    test('dailyTotal sums only same-day good logs', () async {
      await service.createHabit(_goodHabit());
      await service.logGood(
        'water',
        amount: 2,
        occurredAt: DateTime(2026, 5, 2, 9),
      );
      await service.logGood(
        'water',
        amount: 3,
        occurredAt: DateTime(2026, 5, 2, 21),
      );
      await service.logGood(
        'water',
        amount: 10,
        occurredAt: DateTime(2026, 5, 3, 9),
      );

      expect(await service.dailyTotal('water', DateTime(2026, 5, 2)), 5);
    });
  });

  group('HabitService.logGood', () {
    test('writes canonical and legacy log copies and emits event', () async {
      await service.createHabit(_goodHabit());
      final occurred = DateTime(2026, 5, 2, 9, 30);

      final logId = await service.logGood(
        'water',
        amount: 2,
        unit: 'cups',
        note: 'after walk',
        occurredAt: occurred,
      );

      final canonical = await logsColl().doc(logId).get();
      expect(canonical.exists, isTrue);
      expect(canonical.data()!['logType'], 'good');
      expect(canonical.data()!['quantity'], 2);
      expect(canonical.data()!['unit'], 'cups');
      expect(canonical.data()!['schemaVersion'], 1);

      final nested = await habitsColl()
          .doc('water')
          .collection('logs')
          .doc('2026-05-02')
          .collection('items')
          .doc(logId)
          .get();
      expect(nested.exists, isTrue);

      final events = await eventsNamed(EventNames.goodHabitLogged);
      expect(events.length, 1);
      expect(events.first.data()['payload']['logId'], logId);
      expect(events.first.data()['payload']['todayTotalAfter'], 2);
    });

    test('guard errors are typed', () async {
      await service.createHabit(_badHabit());
      await expectLater(
        service.logGood('missing'),
        throwsA(isA<HabitNotFoundError>()),
      );
      await expectLater(
        service.logGood('smoking'),
        throwsA(isA<WrongHabitKindError>()),
      );

      await service.createHabit(_goodHabit(id: 'paused'));
      await service.pauseHabit('paused');
      await expectLater(
        service.logGood('paused'),
        throwsA(isA<HabitNotActiveError>()),
      );

      await expectLater(
        service.logGood('paused', amount: -1),
        throwsA(isA<HabitNotActiveError>()),
      );
    });

    test('rejects negative amount', () async {
      await service.createHabit(_goodHabit());
      await expectLater(
        service.logGood('water', amount: -1),
        throwsA(isA<InvalidAmountError>()),
      );
    });
  });

  group('HabitService.logSlip', () {
    test('writes canonical and legacy slip copies and emits event', () async {
      await service.createHabit(_badHabit());
      final occurred = DateTime(2026, 5, 2, 12);

      final logId = await service.logSlip(
        'smoking',
        count: 2,
        trigger: 'stress',
        occurredAt: occurred,
      );

      final canonical = await logsColl().doc(logId).get();
      expect(canonical.exists, isTrue);
      expect(canonical.data()!['logType'], 'slip');
      expect(canonical.data()!['quantity'], 2);
      expect(canonical.data()!['trigger'], 'stress');

      final nested = await habitsColl()
          .doc('smoking')
          .collection('logs')
          .doc('2026-05-02')
          .collection('items')
          .doc(logId)
          .get();
      expect(nested.exists, isTrue);

      final events = await eventsNamed(EventNames.badHabitSlipLogged);
      expect(events.length, 1);
      expect(events.first.data()['payload']['habitName'], 'Smoking');
      expect(events.first.data()['payload']['countTodayAfter'], 2);
    });

    test('guard errors are typed', () async {
      await service.createHabit(_goodHabit());
      await expectLater(
        service.logSlip('missing'),
        throwsA(isA<HabitNotFoundError>()),
      );
      await expectLater(
        service.logSlip('water'),
        throwsA(isA<WrongHabitKindError>()),
      );

      await service.createHabit(_badHabit(id: 'paused_bad'));
      await service.pauseHabit('paused_bad');
      await expectLater(
        service.logSlip('paused_bad'),
        throwsA(isA<HabitNotActiveError>()),
      );
    });
  });

  group('HabitService.deleteLog', () {
    test('requires confirmation for destructive delete', () async {
      await service.createHabit(_goodHabit());
      final logId = await service.logGood('water');

      await expectLater(
        service.deleteLog('water', logId),
        throwsA(isA<InvalidHabitInputError>()),
      );
      expect((await logsColl().doc(logId).get()).exists, isTrue);
    });

    test('confirmed delete removes canonical and legacy log and emits event',
        () async {
      await service.createHabit(_goodHabit());
      final logId = await service.logGood(
        'water',
        occurredAt: DateTime(2026, 5, 2, 9),
      );

      await service.deleteLog('water', logId, confirmDestructive: true);

      expect((await logsColl().doc(logId).get()).exists, isFalse);
      final nested = await habitsColl()
          .doc('water')
          .collection('logs')
          .doc('2026-05-02')
          .collection('items')
          .doc(logId)
          .get();
      expect(nested.exists, isFalse);
      expect((await eventsNamed(EventNames.habitLogDeleted)).length, 1);
    });
  });
}
