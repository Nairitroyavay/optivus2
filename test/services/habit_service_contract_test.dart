// test/services/habit_service_contract_test.dart
//
// Contract tests for HabitService.
// All groups are skipped (TODO) — implement with fake_cloud_firestore /
// firebase_auth_mocks once those dev-dependencies are added.
//
// Public surface under test:
//   HabitService.habits()
//   HabitService.getHabit(habitId)
//   HabitService.dailyLogCount(habitId, date)
//   HabitService.dailyTotal(habitId, date)
//   HabitService.createHabit(habit)
//   HabitService.updateHabit(habit)
//   HabitService.deleteHabit(habitId)
//   HabitService.logGood(habitId, {...})
//   HabitService.logSlip(habitId, {...})

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── habits() ────────────────────────────────────────────────────────────────

  group('HabitService.habits — happy path', () {
    test(
      'TODO: stream returns only habits with state == active',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: does not include archived or paused habits',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── getHabit ────────────────────────────────────────────────────────────────

  group('HabitService.getHabit', () {
    test(
      'TODO: returns HabitModel when the document exists',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: returns null when the document does not exist',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── dailyLogCount ────────────────────────────────────────────────────────────

  group('HabitService.dailyLogCount', () {
    test(
      'TODO: returns 0 when no logs exist for the given date',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: returns correct count when multiple logs exist within the calendar day',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: does not count logs from an adjacent calendar day',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── dailyTotal ───────────────────────────────────────────────────────────────

  group('HabitService.dailyTotal', () {
    test(
      'TODO: returns 0 when no logs exist',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: sums quantity fields across all logs for the day',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: counts each log as 1 when quantity is absent',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── createHabit ──────────────────────────────────────────────────────────────

  group('HabitService.createHabit — happy path', () {
    test(
      'TODO: writes doc to /users/{uid}/habits/{habitId} with schemaVersion: 1',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: created doc has state == active',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('HabitService.createHabit — validation errors', () {
    test(
      'TODO: throws InvalidHabitInputError when habit.name is blank',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: throws NotAuthenticatedError when no user is signed in',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── updateHabit ──────────────────────────────────────────────────────────────

  group('HabitService.updateHabit — happy path', () {
    test(
      'TODO: merges updated fields with schemaVersion: 1 and updatedAt',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('HabitService.updateHabit — error cases', () {
    test(
      'TODO: throws HabitNotFoundError when the habit does not exist',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── deleteHabit (soft) ───────────────────────────────────────────────────────

  group('HabitService.deleteHabit — happy path', () {
    test(
      'TODO: transitions habit state to archived (not hard-deleted)',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: log sub-collections remain intact after soft-delete',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('HabitService.deleteHabit — error cases', () {
    test(
      'TODO: throws HabitNotFoundError when the habit does not exist',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── logGood ──────────────────────────────────────────────────────────────────

  group('HabitService.logGood — happy path', () {
    test(
      'TODO: writes log to nested path /habits/{habitId}/logs/{date}/items/{logId}',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: writes canonical copy to /habit_logs/{logId} in the same batch',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: log doc has logType == good and schemaVersion: 1',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: emits good_habit_logged event with habitId, logId, occurredAt, source',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('HabitService.logGood — guard errors', () {
    test(
      'TODO: throws HabitNotFoundError when habitId does not exist',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: throws WrongHabitKindError when habit is of kind bad',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: throws HabitNotActiveError when habit state is not active',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: throws InvalidAmountError when amount is provided but <= 0',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── logSlip ──────────────────────────────────────────────────────────────────

  group('HabitService.logSlip — happy path', () {
    test(
      'TODO: writes log to nested path with logType == slip',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: writes canonical copy to /habit_logs/{logId}',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: emits bad_habit_slip_logged event with habitId, habitName, logId',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('HabitService.logSlip — guard errors', () {
    test(
      'TODO: throws HabitNotFoundError when habitId does not exist',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: throws WrongHabitKindError when habit is of kind good',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: throws HabitNotActiveError when habit state is not active',
      () {},
      skip: 'Not yet implemented',
    );
  });
}
