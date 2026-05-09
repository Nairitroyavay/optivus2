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
    test(
      'TODO: returns early without writing Firestore when no user is signed in',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: returns early when /users/{uid} document does not exist',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: returns early when lastDayClosed >= yesterdayStr (already closed)',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: proceeds with rollup when lastDayClosed is null (first day)',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: proceeds with rollup when lastDayClosed < yesterdayStr',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── runDayCloseIfNeeded — happy path ─────────────────────────────────────────

  group('RoutineService.runDayCloseIfNeeded — happy path', () {
    test(
      'TODO: calls StreakService.runDayCloseRollup with yesterday\'s YYYY-MM-DD string',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: writes /users/{uid}/dailySummaries/{date} with rollup metrics',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: daySummary.habitsCompleted matches rollup.habitsCompleted',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: daySummary.streaksActive matches rollup.streaksActive',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: advances lastDayClosed on the user document to yesterdayStr',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: emits day_closed event with date, habitsCompleted, streaksActive',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: emits routine_day_summarized event with milestonesHit list',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── runDayCloseIfNeeded — idempotency ─────────────────────────────────────────

  group('RoutineService.runDayCloseIfNeeded — idempotency', () {
    test(
      'TODO: calling twice for the same day does not produce duplicate dailySummary writes',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: calling twice for the same day does not emit duplicate day_closed events',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── runDayCloseIfNeeded — error resilience ────────────────────────────────────

  group('RoutineService.runDayCloseIfNeeded — error resilience', () {
    test(
      'TODO: does not rethrow when StreakService.runDayCloseRollup throws',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: does not rethrow when Firestore batch commit fails',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── _formatDate utility ──────────────────────────────────────────────────────

  group('RoutineService._formatDate (via runDayCloseIfNeeded)', () {
    test(
      'TODO: produces zero-padded YYYY-MM-DD string for single-digit month and day',
      () {},
      skip: 'Not yet implemented',
    );
  });
}
