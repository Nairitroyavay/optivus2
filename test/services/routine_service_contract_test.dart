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

import 'package:flutter_test/flutter_test.dart';

void main() {
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
