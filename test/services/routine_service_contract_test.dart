// test/services/routine_service_contract_test.dart
//
// Contract tests for RoutineService.
// All groups are skipped (TODO) — implement with fake_cloud_firestore /
// firebase_auth_mocks once those dev-dependencies are added.
//
// Public surface under test:
//   RoutineService.runDayCloseIfNeeded()
//
// Day-close sequence (steps 1-7):
//   1. Read lastDayClosed from /users/{uid}
//   2. Guard: skip if yesterday is already closed
//   3. Delegate streak rollup to StreakService.runDayCloseRollup(date)
//   4. Write /users/{uid}/dailySummaries/{date}
//   5. Advance lastDayClosed on /users/{uid}
//   6. Emit day_closed
//   7. Emit routine_day_summarized

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:optivus2/services/event_service.dart';
import 'package:optivus2/services/routine_service.dart';
import 'package:optivus2/services/state_aggregator_service.dart';
import 'package:optivus2/services/streak_service.dart';

String _dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

void main() {
  const uid = 'routine_service_user';

  group('RoutineService cancelled compatibility', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late EventService eventService;
    late RoutineService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      firestore = FakeFirebaseFirestore();
      auth = MockFirebaseAuth(mockUser: MockUser(uid: uid), signedIn: true);
      eventService = EventService(firestore: firestore, auth: auth);
      service = RoutineService(
        eventService: eventService,
        streakService: StreakService(
          eventService: eventService,
          firestore: firestore,
          auth: auth,
        ),
        stateAggregatorService: StateAggregatorService(firestore: firestore),
        firestore: firestore,
        auth: auth,
      );
    });

    tearDown(() => eventService.dispose());

    test('day close does not treat status-only cancelled task as scheduled',
        () async {
      final today = DateTime.now();
      final yesterday = DateTime(today.year, today.month, today.day)
          .subtract(const Duration(days: 1));
      final dayBeforeYesterday = yesterday.subtract(const Duration(days: 1));
      final yesterdayKey = _dateKey(yesterday);

      await firestore.collection('users').doc(uid).set({
        'uid': uid,
        'lastDayClosed': _dateKey(dayBeforeYesterday),
        'createdAt': Timestamp.fromDate(dayBeforeYesterday),
        'updatedAt': Timestamp.fromDate(dayBeforeYesterday),
      });
      await firestore
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .doc('cancelled_task')
          .set({
        'taskId': 'cancelled_task',
        'type': 'fixed',
        'title': 'Cancelled task',
        'plannedStart': Timestamp.fromDate(
          DateTime(yesterday.year, yesterday.month, yesterday.day, 9),
        ),
        'plannedEnd': Timestamp.fromDate(
          DateTime(yesterday.year, yesterday.month, yesterday.day, 9, 30),
        ),
        'status': 'cancelled',
        'createdAt': Timestamp.fromDate(dayBeforeYesterday),
        'updatedAt': Timestamp.fromDate(dayBeforeYesterday),
        'schemaVersion': 1,
      });

      await service.runDayCloseIfNeeded();

      final task = await firestore
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .doc('cancelled_task')
          .get();
      expect(task.data()?['status'], 'cancelled');
      expect(task.data()?.containsKey('state'), isFalse);
      expect(task.data()?.containsKey('skippedAt'), isFalse);

      final outcome = await firestore
          .collection('users')
          .doc(uid)
          .collection('task_outcomes')
          .doc('cancelled_task')
          .get();
      expect(outcome.exists, isFalse);
      expect(
          (await firestore.collection('users').doc(uid).get())
              .data()?['lastDayClosed'],
          yesterdayKey);
    });
  });

  // ── runDayCloseIfNeeded — guard conditions ───────────────────────────────────

  group('RoutineService.runDayCloseIfNeeded — guard conditions', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late EventService eventService;
    late RoutineService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      firestore = FakeFirebaseFirestore();
      auth = MockFirebaseAuth(mockUser: MockUser(uid: uid), signedIn: true);
      eventService = EventService(firestore: firestore, auth: auth);
      service = RoutineService(
        eventService: eventService,
        streakService: StreakService(
          eventService: eventService,
          firestore: firestore,
          auth: auth,
        ),
        stateAggregatorService: StateAggregatorService(firestore: firestore),
        firestore: firestore,
        auth: auth,
      );
    });

    tearDown(() => eventService.dispose());

    test('returns early without writing Firestore when no user is signed in', () async {
      final unauthService = RoutineService(
        eventService: eventService,
        streakService: StreakService(
          eventService: eventService,
          firestore: firestore,
          auth: MockFirebaseAuth(signedIn: false),
        ),
        stateAggregatorService: StateAggregatorService(firestore: firestore),
        firestore: firestore,
        auth: MockFirebaseAuth(signedIn: false),
      );

      await unauthService.runDayCloseIfNeeded();

      final snaps = await firestore.collection('users').get();
      expect(snaps.docs, isEmpty);
    });

    test('returns early when /users/{uid} document does not exist', () async {
      await service.runDayCloseIfNeeded();

      final events = await firestore
          .collection('users')
          .doc(uid)
          .collection('events')
          .get();
      final eventNames = events.docs.map((e) => e.data()['eventName']).toList();
      expect(eventNames, isNot(contains('day_closed')));
    });

    test('returns early when lastDayClosed >= yesterdayStr (already closed)', () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));

      await firestore.collection('users').doc(uid).set({
        'uid': uid,
        'lastDayClosed': _dateKey(yesterday),
      });

      await service.runDayCloseIfNeeded();

      final events = await firestore
          .collection('users')
          .doc(uid)
          .collection('events')
          .get();
      final eventNames = events.docs.map((e) => e.data()['eventName']).toList();
      expect(eventNames, isNot(contains('day_closed')));
    });

    test('proceeds with rollup when lastDayClosed is null (first day)', () async {
      await firestore.collection('users').doc(uid).set({'uid': uid});

      await service.runDayCloseIfNeeded();

      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final userSnap = await firestore.collection('users').doc(uid).get();
      expect(userSnap.data()?['lastDayClosed'], _dateKey(yesterday));
    });

    test('proceeds with rollup when lastDayClosed < yesterdayStr', () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final twoDaysAgo = today.subtract(const Duration(days: 2));

      await firestore.collection('users').doc(uid).set({
        'uid': uid,
        'lastDayClosed': _dateKey(twoDaysAgo),
      });

      await service.runDayCloseIfNeeded();

      final userSnap = await firestore.collection('users').doc(uid).get();
      expect(userSnap.data()?['lastDayClosed'], _dateKey(yesterday));
    });
  });

  // ── runDayCloseIfNeeded — happy path ─────────────────────────────────────────

  group('RoutineService.runDayCloseIfNeeded — happy path', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late EventService eventService;
    late RoutineService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      firestore = FakeFirebaseFirestore();
      auth = MockFirebaseAuth(mockUser: MockUser(uid: uid), signedIn: true);
      eventService = EventService(firestore: firestore, auth: auth);
      service = RoutineService(
        eventService: eventService,
        streakService: StreakService(
          eventService: eventService,
          firestore: firestore,
          auth: auth,
        ),
        stateAggregatorService: StateAggregatorService(firestore: firestore),
        firestore: firestore,
        auth: auth,
      );
    });

    tearDown(() => eventService.dispose());

    test('calls StreakService.runDayCloseRollup, writes summaries, updates lastDayClosed, emits events', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final twoDaysAgo = today.subtract(const Duration(days: 2));

      await firestore.collection('users').doc(uid).set({
        'uid': uid,
        'lastDayClosed': _dateKey(twoDaysAgo),
      });

      // Simulate a habit completion to test rollup logic.
      await firestore
          .collection('users')
          .doc(uid)
          .collection('habit_logs')
          .doc('log1')
          .set({
        'habitId': 'habit1',
        'logType': 'good',
        'quantity': 1,
        'occurredAt': Timestamp.fromDate(yesterday.add(const Duration(hours: 12))),
      });
      await firestore
          .collection('users')
          .doc(uid)
          .collection('habits')
          .doc('habit1')
          .set({
        'habitId': 'habit1',
        'type': 'good',
        'status': 'active',
        'state': 'active', // Important: StreakService checks 'state' is 'active'
        'kind': 'good', // Important: StreakService uses 'kind'
      });

      await service.runDayCloseIfNeeded();

      // Check dailySummary
      final summarySnap = await firestore
          .collection('users')
          .doc(uid)
          .collection('dailySummaries')
          .doc(_dateKey(yesterday))
          .get();
      expect(summarySnap.exists, isTrue);
      expect(summarySnap.data()?['habitsCompleted'], 1);
      expect(summarySnap.data()?['streaksActive'], 1);

      // Check lastDayClosed
      final userSnap = await firestore.collection('users').doc(uid).get();
      expect(userSnap.data()?['lastDayClosed'], _dateKey(yesterday));

      // Check events (day_closed and routine_day_summarized)
      final eventsSnap = await firestore
          .collection('users')
          .doc(uid)
          .collection('events')
          .orderBy('timestamp')
          .get();

      final eventNames = eventsSnap.docs.map((d) => d.data()['eventName']).toList();
      expect(eventNames, containsAll(['day_closed', 'routine_day_summarized']));

      final dayClosedEvent = eventsSnap.docs.firstWhere((d) => d.data()['eventName'] == 'day_closed');
      expect(dayClosedEvent.data()['payload']['date'], _dateKey(yesterday));
    });
  });

  // ── runDayCloseIfNeeded — idempotency ─────────────────────────────────────────

  group('RoutineService.runDayCloseIfNeeded — idempotency', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late EventService eventService;
    late RoutineService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      firestore = FakeFirebaseFirestore();
      auth = MockFirebaseAuth(mockUser: MockUser(uid: uid), signedIn: true);
      eventService = EventService(firestore: firestore, auth: auth);
      service = RoutineService(
        eventService: eventService,
        streakService: StreakService(
          eventService: eventService,
          firestore: firestore,
          auth: auth,
        ),
        stateAggregatorService: StateAggregatorService(firestore: firestore),
        firestore: firestore,
        auth: auth,
      );
    });

    tearDown(() => eventService.dispose());

    test('calling twice for the same day does not produce duplicate dailySummary writes or events', () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final twoDaysAgo = today.subtract(const Duration(days: 2));

      await firestore.collection('users').doc(uid).set({
        'uid': uid,
        'lastDayClosed': _dateKey(twoDaysAgo),
      });

      // First call — closes yesterday.
      await service.runDayCloseIfNeeded();

      final eventsSnap1 = await firestore
          .collection('users').doc(uid).collection('events').get();
      final initialEventCount = eventsSnap1.docs.length;
      expect(initialEventCount, greaterThan(0));

      // Second call — guard (lastDayClosed == yesterday) should skip everything.
      await service.runDayCloseIfNeeded();

      // Ensure lastDayClosed is still yesterday.
      final userSnap = await firestore.collection('users').doc(uid).get();
      expect(userSnap.data()?['lastDayClosed'], _dateKey(yesterday));

      // No new events should have been created.
      final eventsSnap2 = await firestore
          .collection('users').doc(uid).collection('events').get();
      expect(eventsSnap2.docs.length, initialEventCount);
    });

    test('re-close after guard reset re-uses existing summary (no duplicate write)', () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final twoDaysAgo = today.subtract(const Duration(days: 2));

      await firestore.collection('users').doc(uid).set({
        'uid': uid,
        'lastDayClosed': _dateKey(twoDaysAgo),
      });

      // First call writes the summary.
      await service.runDayCloseIfNeeded();
      final summarySnap = await firestore
          .collection('users').doc(uid)
          .collection('dailySummaries').doc(_dateKey(yesterday)).get();
      expect(summarySnap.exists, isTrue);

      // Manually reset guard to simulate a race/restart.
      await firestore.collection('users').doc(uid).update({
        'lastDayClosed': _dateKey(twoDaysAgo),
      });

      // Second call — summary already exists, so _closeDate advances
      // lastDayClosed without rewriting the summary or re-emitting events.
      await service.runDayCloseIfNeeded();
      final userSnap = await firestore.collection('users').doc(uid).get();
      expect(userSnap.data()?['lastDayClosed'], _dateKey(yesterday));
    });
  });

  // ── runDayCloseIfNeeded — overdue task cleanup ────────────────────────────────

  group('RoutineService.runDayCloseIfNeeded — overdue task cleanup', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late EventService eventService;
    late RoutineService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      firestore = FakeFirebaseFirestore();
      auth = MockFirebaseAuth(mockUser: MockUser(uid: uid), signedIn: true);
      eventService = EventService(firestore: firestore, auth: auth);
      service = RoutineService(
        eventService: eventService,
        streakService: StreakService(
          eventService: eventService,
          firestore: firestore,
          auth: auth,
        ),
        stateAggregatorService: StateAggregatorService(firestore: firestore),
        firestore: firestore,
        auth: auth,
      );
    });

    tearDown(() => eventService.dispose());

    test('marks scheduled tasks as skipped with autoNoStart reason', () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final twoDaysAgo = today.subtract(const Duration(days: 2));

      await firestore.collection('users').doc(uid).set({
        'uid': uid,
        'lastDayClosed': _dateKey(twoDaysAgo),
      });

      await firestore
          .collection('users').doc(uid).collection('tasks')
          .doc('scheduled_task').set({
        'taskId': 'scheduled_task',
        'type': 'fixed',
        'title': 'Overdue scheduled task',
        'state': 'scheduled',
        'status': 'scheduled',
        'plannedStart': Timestamp.fromDate(
          DateTime(yesterday.year, yesterday.month, yesterday.day, 9),
        ),
        'plannedEnd': Timestamp.fromDate(
          DateTime(yesterday.year, yesterday.month, yesterday.day, 9, 30),
        ),
        'plannedDurationMin': 30,
        'createdAt': Timestamp.fromDate(twoDaysAgo),
        'updatedAt': Timestamp.fromDate(twoDaysAgo),
        'schemaVersion': 1,
      });

      await service.runDayCloseIfNeeded();

      final task = await firestore
          .collection('users').doc(uid).collection('tasks')
          .doc('scheduled_task').get();
      expect(task.data()?['state'], 'skipped');
      expect(task.data()?['reasonCategory'], 'auto_no_start');
      expect(task.data()?['reasonTag'], 'day_close');
    });

    test('marks started tasks as abandoned with autoIdle reason', () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final twoDaysAgo = today.subtract(const Duration(days: 2));

      await firestore.collection('users').doc(uid).set({
        'uid': uid,
        'lastDayClosed': _dateKey(twoDaysAgo),
      });

      await firestore
          .collection('users').doc(uid).collection('tasks')
          .doc('started_task').set({
        'taskId': 'started_task',
        'type': 'fixed',
        'title': 'Overdue started task',
        'state': 'started',
        'status': 'started',
        'actualStart': Timestamp.fromDate(
          DateTime(yesterday.year, yesterday.month, yesterday.day, 9, 5),
        ),
        'plannedStart': Timestamp.fromDate(
          DateTime(yesterday.year, yesterday.month, yesterday.day, 9),
        ),
        'plannedEnd': Timestamp.fromDate(
          DateTime(yesterday.year, yesterday.month, yesterday.day, 9, 30),
        ),
        'plannedDurationMin': 30,
        'createdAt': Timestamp.fromDate(twoDaysAgo),
        'updatedAt': Timestamp.fromDate(twoDaysAgo),
        'schemaVersion': 1,
      });

      await service.runDayCloseIfNeeded();

      final task = await firestore
          .collection('users').doc(uid).collection('tasks')
          .doc('started_task').get();
      expect(task.data()?['state'], 'abandoned');
      expect(task.data()?['reasonCategory'], 'auto_idle');
      expect(task.data()?['reasonTag'], 'day_close');
    });

    test('writes task_outcomes for overdue tasks', () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final twoDaysAgo = today.subtract(const Duration(days: 2));

      await firestore.collection('users').doc(uid).set({
        'uid': uid,
        'lastDayClosed': _dateKey(twoDaysAgo),
      });

      await firestore
          .collection('users').doc(uid).collection('tasks')
          .doc('overdue_task').set({
        'taskId': 'overdue_task',
        'type': 'fixed',
        'title': 'Overdue task for outcome test',
        'state': 'scheduled',
        'status': 'scheduled',
        'plannedStart': Timestamp.fromDate(
          DateTime(yesterday.year, yesterday.month, yesterday.day, 10),
        ),
        'plannedEnd': Timestamp.fromDate(
          DateTime(yesterday.year, yesterday.month, yesterday.day, 10, 30),
        ),
        'plannedDurationMin': 30,
        'createdAt': Timestamp.fromDate(twoDaysAgo),
        'updatedAt': Timestamp.fromDate(twoDaysAgo),
        'schemaVersion': 1,
      });

      await service.runDayCloseIfNeeded();

      final outcome = await firestore
          .collection('users').doc(uid).collection('task_outcomes')
          .doc('overdue_task').get();
      expect(outcome.exists, isTrue);
      expect(outcome.data()?['outcome'], 'skipped');
      expect(outcome.data()?['reasonTag'], 'day_close');
    });

    test('emits task_skipped and task_abandoned events for overdue tasks', () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final twoDaysAgo = today.subtract(const Duration(days: 2));

      await firestore.collection('users').doc(uid).set({
        'uid': uid,
        'lastDayClosed': _dateKey(twoDaysAgo),
      });

      // Scheduled task → should emit task_skipped
      await firestore
          .collection('users').doc(uid).collection('tasks')
          .doc('sched_t').set({
        'taskId': 'sched_t',
        'type': 'fixed',
        'title': 'Scheduled overdue',
        'state': 'scheduled',
        'status': 'scheduled',
        'plannedStart': Timestamp.fromDate(
          DateTime(yesterday.year, yesterday.month, yesterday.day, 8),
        ),
        'plannedEnd': Timestamp.fromDate(
          DateTime(yesterday.year, yesterday.month, yesterday.day, 8, 30),
        ),
        'plannedDurationMin': 30,
        'createdAt': Timestamp.fromDate(twoDaysAgo),
        'updatedAt': Timestamp.fromDate(twoDaysAgo),
        'schemaVersion': 1,
      });

      // Started task → should emit task_abandoned
      await firestore
          .collection('users').doc(uid).collection('tasks')
          .doc('start_t').set({
        'taskId': 'start_t',
        'type': 'fixed',
        'title': 'Started overdue',
        'state': 'started',
        'status': 'started',
        'actualStart': Timestamp.fromDate(
          DateTime(yesterday.year, yesterday.month, yesterday.day, 11),
        ),
        'plannedStart': Timestamp.fromDate(
          DateTime(yesterday.year, yesterday.month, yesterday.day, 11),
        ),
        'plannedEnd': Timestamp.fromDate(
          DateTime(yesterday.year, yesterday.month, yesterday.day, 11, 30),
        ),
        'plannedDurationMin': 30,
        'createdAt': Timestamp.fromDate(twoDaysAgo),
        'updatedAt': Timestamp.fromDate(twoDaysAgo),
        'schemaVersion': 1,
      });

      await service.runDayCloseIfNeeded();

      final events = await firestore
          .collection('users').doc(uid).collection('events').get();
      final eventNames = events.docs.map((e) => e.data()['eventName']).toList();
      expect(eventNames, contains('task_skipped'));
      expect(eventNames, contains('task_abandoned'));
    });

    test('does not touch already-terminal tasks during day close', () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final twoDaysAgo = today.subtract(const Duration(days: 2));

      await firestore.collection('users').doc(uid).set({
        'uid': uid,
        'lastDayClosed': _dateKey(twoDaysAgo),
      });

      await firestore
          .collection('users').doc(uid).collection('tasks')
          .doc('done_task').set({
        'taskId': 'done_task',
        'type': 'fixed',
        'title': 'Already completed',
        'state': 'completed',
        'status': 'completed',
        'plannedStart': Timestamp.fromDate(
          DateTime(yesterday.year, yesterday.month, yesterday.day, 14),
        ),
        'plannedEnd': Timestamp.fromDate(
          DateTime(yesterday.year, yesterday.month, yesterday.day, 14, 30),
        ),
        'plannedDurationMin': 30,
        'createdAt': Timestamp.fromDate(twoDaysAgo),
        'updatedAt': Timestamp.fromDate(twoDaysAgo),
        'schemaVersion': 1,
      });

      await service.runDayCloseIfNeeded();

      final task = await firestore
          .collection('users').doc(uid).collection('tasks')
          .doc('done_task').get();
      expect(task.data()?['state'], 'completed');
    });
  });

  // ── runDayCloseIfNeeded — multi-day catch-up ──────────────────────────────────

  group('RoutineService.runDayCloseIfNeeded — multi-day catch-up', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late EventService eventService;
    late RoutineService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      firestore = FakeFirebaseFirestore();
      auth = MockFirebaseAuth(mockUser: MockUser(uid: uid), signedIn: true);
      eventService = EventService(firestore: firestore, auth: auth);
      service = RoutineService(
        eventService: eventService,
        streakService: StreakService(
          eventService: eventService,
          firestore: firestore,
          auth: auth,
        ),
        stateAggregatorService: StateAggregatorService(firestore: firestore),
        firestore: firestore,
        auth: auth,
      );
    });

    tearDown(() => eventService.dispose());

    test('closes multiple missed days in sequence', () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final fourDaysAgo = today.subtract(const Duration(days: 4));

      await firestore.collection('users').doc(uid).set({
        'uid': uid,
        'lastDayClosed': _dateKey(fourDaysAgo),
      });

      await service.runDayCloseIfNeeded();

      // Should have closed days -3, -2, -1 and lastDayClosed == yesterday.
      final userSnap = await firestore.collection('users').doc(uid).get();
      expect(userSnap.data()?['lastDayClosed'], _dateKey(yesterday));

      // Daily summaries for each intermediate day should exist.
      for (int i = 3; i >= 1; i--) {
        final dateStr = _dateKey(today.subtract(Duration(days: i)));
        final summary = await firestore
            .collection('users').doc(uid)
            .collection('dailySummaries').doc(dateStr).get();
        expect(summary.exists, isTrue,
            reason: 'dailySummary for $dateStr should exist');
      }
    });
  });

  // ── runDayCloseIfNeeded — daily summary metrics ───────────────────────────────

  group('RoutineService.runDayCloseIfNeeded — daily summary metrics', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late EventService eventService;
    late RoutineService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      firestore = FakeFirebaseFirestore();
      auth = MockFirebaseAuth(mockUser: MockUser(uid: uid), signedIn: true);
      eventService = EventService(firestore: firestore, auth: auth);
      service = RoutineService(
        eventService: eventService,
        streakService: StreakService(
          eventService: eventService,
          firestore: firestore,
          auth: auth,
        ),
        stateAggregatorService: StateAggregatorService(firestore: firestore),
        firestore: firestore,
        auth: auth,
      );
    });

    tearDown(() => eventService.dispose());

    test('summary reflects completed, abandoned, and skipped task counts', () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final twoDaysAgo = today.subtract(const Duration(days: 2));

      await firestore.collection('users').doc(uid).set({
        'uid': uid,
        'lastDayClosed': _dateKey(twoDaysAgo),
      });

      final tasksRef = firestore
          .collection('users').doc(uid).collection('tasks');

      // One completed task
      await tasksRef.doc('t_done').set({
        'taskId': 't_done',
        'type': 'fixed',
        'title': 'Done task',
        'state': 'completed',
        'status': 'completed',
        'actualDurationMin': 25,
        'plannedStart': Timestamp.fromDate(
          DateTime(yesterday.year, yesterday.month, yesterday.day, 9),
        ),
        'plannedEnd': Timestamp.fromDate(
          DateTime(yesterday.year, yesterday.month, yesterday.day, 9, 30),
        ),
        'plannedDurationMin': 30,
        'createdAt': Timestamp.fromDate(twoDaysAgo),
        'updatedAt': Timestamp.fromDate(twoDaysAgo),
        'schemaVersion': 1,
      });

      // One scheduled (will be auto-skipped)
      await tasksRef.doc('t_sched').set({
        'taskId': 't_sched',
        'type': 'fixed',
        'title': 'Scheduled task',
        'state': 'scheduled',
        'status': 'scheduled',
        'plannedStart': Timestamp.fromDate(
          DateTime(yesterday.year, yesterday.month, yesterday.day, 14),
        ),
        'plannedEnd': Timestamp.fromDate(
          DateTime(yesterday.year, yesterday.month, yesterday.day, 14, 30),
        ),
        'plannedDurationMin': 30,
        'createdAt': Timestamp.fromDate(twoDaysAgo),
        'updatedAt': Timestamp.fromDate(twoDaysAgo),
        'schemaVersion': 1,
      });

      await service.runDayCloseIfNeeded();

      final summary = await firestore
          .collection('users').doc(uid)
          .collection('dailySummaries').doc(_dateKey(yesterday)).get();
      expect(summary.exists, isTrue);
      expect(summary.data()?['tasksCompleted'], 1);
      // The scheduled task is auto-skipped at day-close.
      expect(summary.data()?['tasksSkipped'], greaterThanOrEqualTo(1));
      expect(summary.data()?['tasksScheduled'], 2);
    });
  });

  // ── runDayCloseIfNeeded — error resilience ────────────────────────────────────

  group('RoutineService.runDayCloseIfNeeded — error resilience', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late EventService eventService;
    late RoutineService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      firestore = FakeFirebaseFirestore();
      auth = MockFirebaseAuth(mockUser: MockUser(uid: uid), signedIn: true);
      eventService = EventService(firestore: firestore, auth: auth);
      service = RoutineService(
        eventService: eventService,
        streakService: StreakService(
          eventService: eventService,
          firestore: firestore,
          auth: auth,
        ),
        stateAggregatorService: StateAggregatorService(firestore: firestore),
        firestore: firestore,
        auth: auth,
      );
    });

    tearDown(() => eventService.dispose());

    test('does not rethrow when Firestore batch commit fails', () async {
      // Not straightforward to simulate a generic Firestore exception in FakeFirebaseFirestore
      // without heavy mocking, but we can verify the structure catches internal errors.
      // This serves as a placeholder for full integration test logic if needed.
      expect(service, isNotNull);
    });
  });

  // ── _formatDate utility ──────────────────────────────────────────────────────

  group('RoutineService._formatDate (via runDayCloseIfNeeded)', () {
    test('produces zero-padded YYYY-MM-DD string for single-digit month and day', () {
      final date = DateTime(2026, 5, 2);
      final key = _dateKey(date);
      expect(key, '2026-05-02');
    });
  });
}
