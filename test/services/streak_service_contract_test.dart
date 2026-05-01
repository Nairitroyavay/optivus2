// test/services/streak_service_contract_test.dart
//
// Contract tests for StreakService.
// All groups are skipped (TODO) — implement with fake_cloud_firestore /
// firebase_auth_mocks once those dev-dependencies are added.
//
// Public surface under test:
//   StreakService.runDayCloseRollup(date)
//   StreakService.watchAllStreaks()
//   StreakService.watchStreak(habitId)
//   StreakService.getStreak(habitId)
//
// Firestore paths:
//   /users/{uid}/habits/{habitId}
//   /users/{uid}/habit_logs/{logId}
//   /users/{uid}/streaks/{habitId}

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── runDayCloseRollup — happy path ────────────────────────────────────────────

  group('StreakService.runDayCloseRollup — happy path', () {
    test(
      'TODO: returns DayRollupResult with zeros when no active habits exist',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: increments currentCount when good habit goal is met for the day',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: resets currentCount to 0 and sets state == broken when goal is missed',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: preserves longestCount when currentCount resets to 0',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: updates longestCount when currentCount exceeds previous longestCount',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: habitsCompleted in result equals number of good habits with goal met',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: habitsBadLogged in result equals total slip count for bad habits',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── runDayCloseRollup — event emission ────────────────────────────────────────

  group('StreakService.runDayCloseRollup — event emission', () {
    test(
      'TODO: emits streak_extended when goal is met and currentCount increases',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: emits streak_broken when goal is missed and previous state was active',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: emits streak_milestone_reached when currentCount hits 7, 14, 21, 30, 60, 90, 180, or 365',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: does not emit streak_milestone_reached for non-milestone counts',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: streak doc write and event doc writes are committed in the same batch',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── runDayCloseRollup — bad habit goal logic ──────────────────────────────────

  group('StreakService.runDayCloseRollup — bad habit goal types', () {
    test(
      'TODO: eliminate goal: streak extended when slip count == 0',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: eliminate goal: streak broken when slip count > 0',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: reduceToTarget goal: extended when slips <= target',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: awarenessOnly goal: always counts as goal met regardless of slip count',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── runDayCloseRollup — error resilience ──────────────────────────────────────

  group('StreakService.runDayCloseRollup — error resilience', () {
    test(
      'TODO: does not abort entire rollup when a single habit fails',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: failed habit is counted as goalMet == false in aggregated result',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── watchAllStreaks ───────────────────────────────────────────────────────────

  group('StreakService.watchAllStreaks', () {
    test(
      'TODO: stream emits all streak docs for the user',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: stream emits updated list when a streak doc changes',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── watchStreak ───────────────────────────────────────────────────────────────

  group('StreakService.watchStreak', () {
    test(
      'TODO: stream emits the streak doc for the given habitId',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: stream emits null when no streak doc exists for the habitId',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── getStreak ─────────────────────────────────────────────────────────────────

  group('StreakService.getStreak', () {
    test(
      'TODO: returns Streak when the document exists',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: returns null when the document does not exist',
      () {},
      skip: 'Not yet implemented',
    );
  });
}
