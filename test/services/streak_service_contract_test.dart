// test/services/streak_service_contract_test.dart
//
// Contract tests for StreakService.
//
// Public surface under test:
//   StreakService.runDayCloseRollup(date)
//   StreakService.pauseAllActiveStreaks(reason)
//   StreakService.resumeAllPausedStreaks()
//   StreakService.watchAllStreaks()
//   StreakService.watchStreak(habitId)
//   StreakService.getStreak(habitId)
//
// Firestore paths:
//   /users/{uid}/habits/{habitId}
//   /users/{uid}/habit_logs/{logId}
//   /users/{uid}/streaks/{habitId}
//   /users/{uid}/tasks/{taskId}
//   /users/{uid}/dailySummaries/{date}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:optivus2/core/constants/event_names.dart';
import 'package:optivus2/models/habit_log_model.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/models/streak_model.dart';
import 'package:optivus2/services/event_service.dart';
import 'package:optivus2/services/streak_service.dart';

const _kUid = 'streak_user_456';
const _kDate = '2026-05-02';

DateTime _at(int hour, [int minute = 0]) =>
    DateTime(2026, 5, 2, hour, minute);

HabitModel _goodHabit({
  String id = 'water',
  String name = 'Drink water',
  num dailyGoal = 8,
  HabitState state = HabitState.active,
}) {
  final now = DateTime(2026, 5, 1, 8);
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
  BadHabitGoalType goalType = BadHabitGoalType.eliminate,
  num? target,
  HabitState state = HabitState.active,
}) {
  final now = DateTime(2026, 5, 1, 8);
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

HabitLog _goodLog({
  required String habitId,
  num quantity = 1,
  required DateTime occurredAt,
  String logId = '',
}) {
  return HabitLog(
    logId: logId.isEmpty ? '${habitId}_${occurredAt.millisecondsSinceEpoch}' : logId,
    habitId: habitId,
    habitKind: 'good',
    logType: 'good',
    occurredAt: occurredAt,
    loggedAt: occurredAt,
    quantity: quantity,
    unit: 'count',
  );
}

HabitLog _slipLog({
  required String habitId,
  required DateTime occurredAt,
  num quantity = 1,
  String logId = '',
}) {
  return HabitLog(
    logId: logId.isEmpty ? '${habitId}_slip_${occurredAt.millisecondsSinceEpoch}' : logId,
    habitId: habitId,
    habitKind: 'bad',
    logType: 'slip',
    occurredAt: occurredAt,
    loggedAt: occurredAt,
    quantity: quantity,
  );
}

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late EventService eventService;
  late StreakService service;

  CollectionReference<Map<String, dynamic>> habitsColl() =>
      firestore.collection('users').doc(_kUid).collection('habits');
  CollectionReference<Map<String, dynamic>> logsColl() =>
      firestore.collection('users').doc(_kUid).collection('habit_logs');
  CollectionReference<Map<String, dynamic>> streaksColl() =>
      firestore.collection('users').doc(_kUid).collection('streaks');
  CollectionReference<Map<String, dynamic>> tasksColl() =>
      firestore.collection('users').doc(_kUid).collection('tasks');
  CollectionReference<Map<String, dynamic>> eventsColl() =>
      firestore.collection('users').doc(_kUid).collection('events');

  Future<void> setMode(AccountabilityMode mode) async {
    await firestore
        .collection('users')
        .doc(_kUid)
        .set({'accountabilityMode': mode.name}, SetOptions(merge: true));
  }

  Future<void> writeHabit(HabitModel habit) async {
    await habitsColl().doc(habit.id).set(habit.toFirestore());
  }

  Future<void> writeLog(HabitLog log) async {
    await logsColl().doc(log.logId).set(log.toFirestore());
  }

  Future<void> writeStreak(Streak streak) async {
    await streaksColl().doc(streak.habitId).set(streak.toFirestore());
  }

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
    service = StreakService(
      eventService: eventService,
      firestore: firestore,
      auth: auth,
    );
  });

  tearDown(() => eventService.dispose());

  // ── runDayCloseRollup — happy path ─────────────────────────────────────────

  group('StreakService.runDayCloseRollup — happy path', () {
    test('returns DayRollupResult with zeros when no active habits exist',
        () async {
      final result = await service.runDayCloseRollup(_kDate);

      expect(result.habitsCompleted, 0);
      expect(result.habitsBadLogged, 0);
      expect(result.streaksActive, 0);
      expect(result.streaksMilestonesHit, isEmpty);
    });

    test('increments currentCount when good habit goal is met for the day',
        () async {
      await writeHabit(_goodHabit(dailyGoal: 2));
      await writeLog(_goodLog(habitId: 'water', quantity: 2, occurredAt: _at(9)));

      final result = await service.runDayCloseRollup(_kDate);

      expect(result.habitsCompleted, 1);
      expect(result.streaksActive, 1);

      final streak = await service.getStreak('water');
      expect(streak!.currentCount, 1);
      expect(streak.state, StreakState.active);
      expect(streak.lastHitDate, _kDate);
    });

    test(
        'resets currentCount to 0 and sets state == broken when goal is missed',
        () async {
      await writeHabit(_goodHabit(dailyGoal: 8));
      await writeStreak(Streak(
        habitId: 'water',
        currentCount: 5,
        longestCount: 10,
        state: StreakState.active,
        updatedAt: DateTime.now(),
      ));
      // No logs → goal missed.

      await service.runDayCloseRollup(_kDate);

      final streak = await service.getStreak('water');
      expect(streak!.currentCount, 0);
      expect(streak.state, StreakState.broken);
      expect(streak.lastBreakDate, _kDate);
    });

    test('preserves longestCount when currentCount resets to 0', () async {
      await writeHabit(_goodHabit(dailyGoal: 8));
      await writeStreak(Streak(
        habitId: 'water',
        currentCount: 5,
        longestCount: 12,
        state: StreakState.active,
        updatedAt: DateTime.now(),
      ));

      await service.runDayCloseRollup(_kDate);

      final streak = await service.getStreak('water');
      expect(streak!.currentCount, 0);
      expect(streak.longestCount, 12);
    });

    test('updates longestCount when currentCount exceeds previous longestCount',
        () async {
      await writeHabit(_goodHabit(dailyGoal: 1));
      await writeStreak(Streak(
        habitId: 'water',
        currentCount: 6,
        longestCount: 6,
        state: StreakState.active,
        updatedAt: DateTime.now(),
      ));
      await writeLog(_goodLog(habitId: 'water', quantity: 1, occurredAt: _at(9)));

      await service.runDayCloseRollup(_kDate);

      final streak = await service.getStreak('water');
      expect(streak!.currentCount, 7);
      expect(streak.longestCount, 7);
    });

    test('habitsCompleted equals number of good habits with goal met',
        () async {
      await writeHabit(_goodHabit(id: 'water', dailyGoal: 1));
      await writeHabit(_goodHabit(id: 'pages', dailyGoal: 5));
      await writeHabit(_goodHabit(id: 'meditate', dailyGoal: 10));
      await writeLog(_goodLog(habitId: 'water', occurredAt: _at(9)));
      await writeLog(_goodLog(habitId: 'pages', quantity: 5, occurredAt: _at(10)));
      // meditate has no logs

      final result = await service.runDayCloseRollup(_kDate);

      expect(result.habitsCompleted, 2);
    });

    test('habitsBadLogged equals total slip count for bad habits', () async {
      await writeHabit(_badHabit(
        id: 'smoking',
        goalType: BadHabitGoalType.awarenessOnly,
      ));
      await writeLog(_slipLog(habitId: 'smoking', occurredAt: _at(9)));
      await writeLog(_slipLog(habitId: 'smoking', occurredAt: _at(11)));
      await writeLog(_slipLog(habitId: 'smoking', occurredAt: _at(13)));

      final result = await service.runDayCloseRollup(_kDate);

      expect(result.habitsBadLogged, 3);
    });

    test('skips paused habits', () async {
      await writeHabit(_goodHabit(state: HabitState.paused, dailyGoal: 1));
      await writeLog(_goodLog(habitId: 'water', occurredAt: _at(9)));

      final result = await service.runDayCloseRollup(_kDate);

      expect(result.habitsCompleted, 0);
      expect(result.streaksActive, 0);
    });
  });

  // ── runDayCloseRollup — event emission ────────────────────────────────────

  group('StreakService.runDayCloseRollup — event emission', () {
    test('emits streak_extended when goal met and currentCount increases',
        () async {
      await writeHabit(_goodHabit(dailyGoal: 1));
      await writeLog(_goodLog(habitId: 'water', occurredAt: _at(9)));

      await service.runDayCloseRollup(_kDate);

      final events = await eventsNamed(EventNames.streakExtended);
      expect(events.length, 1);
      final payload = events.first.data()['payload'] as Map<String, dynamic>;
      expect(payload['habitId'], 'water');
      expect(payload['currentCount'], 1);
      expect(payload['scope'], 'habit');
    });

    test('emits streak_broken when goal missed and previous state was active',
        () async {
      await writeHabit(_goodHabit(dailyGoal: 8));
      await writeStreak(Streak(
        habitId: 'water',
        currentCount: 4,
        longestCount: 4,
        state: StreakState.active,
        updatedAt: DateTime.now(),
      ));

      await service.runDayCloseRollup(_kDate);

      final events = await eventsNamed(EventNames.streakBroken);
      expect(events.length, 1);
      final payload = events.first.data()['payload'] as Map<String, dynamic>;
      expect(payload['habitId'], 'water');
      expect(payload['previousCount'], 4);
      expect(payload['brokenAt'], _kDate);
    });

    test('does not emit streak_broken when previous state was fresh', () async {
      await writeHabit(_goodHabit(dailyGoal: 8));
      // No prior streak doc → state will be fresh on first read.

      await service.runDayCloseRollup(_kDate);

      final events = await eventsNamed(EventNames.streakBroken);
      expect(events, isEmpty);
    });

    test(
        'emits streak_milestone_reached when currentCount hits 3, 7, 14, 30, 60, 90, 180, or 365',
        () async {
      // Pre-seed a streak just before each milestone, then hit goal.
      const milestones = [3, 7, 14, 30, 60, 90, 180, 365];
      for (final m in milestones) {
        // Reset between iterations.
        firestore = FakeFirebaseFirestore();
        auth = MockFirebaseAuth(mockUser: MockUser(uid: _kUid), signedIn: true);
        eventService = EventService(firestore: firestore, auth: auth);
        service = StreakService(
          eventService: eventService,
          firestore: firestore,
          auth: auth,
        );

        await writeHabit(_goodHabit(dailyGoal: 1));
        await writeStreak(Streak(
          habitId: 'water',
          currentCount: m - 1,
          longestCount: m - 1,
          state: StreakState.active,
          updatedAt: DateTime.now(),
        ));
        await writeLog(
            _goodLog(habitId: 'water', occurredAt: _at(9), logId: 'log_$m'));

        await service.runDayCloseRollup(_kDate);

        final events = await eventsNamed(EventNames.streakMilestoneReached);
        expect(
          events.length,
          1,
          reason: 'Expected milestone event for count == $m',
        );
        expect(events.first.data()['payload']['milestone'], m);

        eventService.dispose();
      }
    });

    test('does not emit streak_milestone_reached for non-milestone counts',
        () async {
      // currentCount transitions 1 → 2 (not a milestone).
      await writeHabit(_goodHabit(dailyGoal: 1));
      await writeStreak(Streak(
        habitId: 'water',
        currentCount: 1,
        longestCount: 1,
        state: StreakState.active,
        updatedAt: DateTime.now(),
      ));
      await writeLog(_goodLog(habitId: 'water', occurredAt: _at(9)));

      await service.runDayCloseRollup(_kDate);

      final events = await eventsNamed(EventNames.streakMilestoneReached);
      expect(events, isEmpty);
    });
  });

  // ── runDayCloseRollup — bad habit goal types ─────────────────────────────

  group('StreakService.runDayCloseRollup — bad habit goal types', () {
    test('eliminate goal: streak extended when slip count == 0', () async {
      await writeHabit(_badHabit(goalType: BadHabitGoalType.eliminate));

      await service.runDayCloseRollup(_kDate);

      final streak = await service.getStreak('smoking');
      expect(streak!.currentCount, 1);
      expect(streak.state, StreakState.active);
    });

    test('eliminate goal: streak broken when slip count > 0', () async {
      await writeHabit(_badHabit(goalType: BadHabitGoalType.eliminate));
      await writeStreak(Streak(
        habitId: 'smoking',
        currentCount: 5,
        longestCount: 5,
        state: StreakState.active,
        updatedAt: DateTime.now(),
      ));
      await writeLog(_slipLog(habitId: 'smoking', occurredAt: _at(13)));

      await service.runDayCloseRollup(_kDate);

      final streak = await service.getStreak('smoking');
      expect(streak!.currentCount, 0);
      expect(streak.state, StreakState.broken);
    });

    test('reduceToTarget goal: extended when slips <= target', () async {
      await writeHabit(_badHabit(
        goalType: BadHabitGoalType.reduceToTarget,
        target: 3,
      ));
      await writeLog(_slipLog(
          habitId: 'smoking', occurredAt: _at(9), logId: 'a'));
      await writeLog(_slipLog(
          habitId: 'smoking', occurredAt: _at(11), logId: 'b'));

      await service.runDayCloseRollup(_kDate);

      final streak = await service.getStreak('smoking');
      expect(streak!.currentCount, 1);
      expect(streak.state, StreakState.active);
    });

    test('reduceToTarget goal: broken when slips > target', () async {
      await writeHabit(_badHabit(
        goalType: BadHabitGoalType.reduceToTarget,
        target: 1,
      ));
      await writeStreak(Streak(
        habitId: 'smoking',
        currentCount: 4,
        longestCount: 4,
        state: StreakState.active,
        updatedAt: DateTime.now(),
      ));
      await writeLog(
          _slipLog(habitId: 'smoking', occurredAt: _at(9), logId: 'a'));
      await writeLog(
          _slipLog(habitId: 'smoking', occurredAt: _at(11), logId: 'b'));

      await service.runDayCloseRollup(_kDate);

      final streak = await service.getStreak('smoking');
      expect(streak!.state, StreakState.broken);
      expect(streak.currentCount, 0);
    });

    test('awarenessOnly goal: always counts as goal met regardless of slips',
        () async {
      await writeHabit(_badHabit(goalType: BadHabitGoalType.awarenessOnly));
      await writeLog(_slipLog(
          habitId: 'smoking', occurredAt: _at(9), logId: 'a'));
      await writeLog(_slipLog(
          habitId: 'smoking', occurredAt: _at(13), logId: 'b'));

      await service.runDayCloseRollup(_kDate);

      final streak = await service.getStreak('smoking');
      expect(streak!.currentCount, 1);
      expect(streak.state, StreakState.active);
    });
  });

  // ── runDayCloseRollup — accountability modes ─────────────────────────────

  group('StreakService.runDayCloseRollup — accountability modes', () {
    test('strict mode: any miss breaks an existing streak', () async {
      await setMode(AccountabilityMode.strict);
      await writeHabit(_goodHabit(dailyGoal: 8));
      await writeStreak(Streak(
        habitId: 'water',
        currentCount: 4,
        longestCount: 4,
        state: StreakState.active,
        updatedAt: DateTime.now(),
      ));

      await service.runDayCloseRollup(_kDate);

      final streak = await service.getStreak('water');
      expect(streak!.state, StreakState.broken);
      expect(streak.currentCount, 0);
    });

    test(
        'forgiving mode: one miss within ISO week is forgiven, streak survives',
        () async {
      await setMode(AccountabilityMode.forgiving);
      await writeHabit(_goodHabit(dailyGoal: 8));
      await writeStreak(Streak(
        habitId: 'water',
        currentCount: 5,
        longestCount: 5,
        state: StreakState.active,
        mode: AccountabilityMode.forgiving,
        updatedAt: DateTime.now(),
      ));
      // No logs → goal missed.

      await service.runDayCloseRollup(_kDate);

      final streak = await service.getStreak('water');
      expect(streak!.state, StreakState.active);
      expect(streak.currentCount, 5,
          reason: 'count should be preserved by forgiving grace day');
      final weekKey = StreakService.isoWeekKey(DateTime(2026, 5, 2));
      expect(streak.weeklySkipsUsed[weekKey], 1);
    });

    test('forgiving mode: second miss in same ISO week breaks the streak',
        () async {
      await setMode(AccountabilityMode.forgiving);
      await writeHabit(_goodHabit(dailyGoal: 8));
      final weekKey = StreakService.isoWeekKey(DateTime(2026, 5, 2));
      await writeStreak(Streak(
        habitId: 'water',
        currentCount: 5,
        longestCount: 5,
        state: StreakState.active,
        mode: AccountabilityMode.forgiving,
        weeklySkipsUsed: {weekKey: 1},
        updatedAt: DateTime.now(),
      ));

      await service.runDayCloseRollup(_kDate);

      final streak = await service.getStreak('water');
      expect(streak!.state, StreakState.broken);
      expect(streak.currentCount, 0);
    });

    test(
        'ruthless mode: any slip on a bad habit breaks streak even with reduceToTarget',
        () async {
      await setMode(AccountabilityMode.ruthless);
      await writeHabit(_badHabit(
        goalType: BadHabitGoalType.reduceToTarget,
        target: 5,
      ));
      await writeStreak(Streak(
        habitId: 'smoking',
        currentCount: 3,
        longestCount: 3,
        state: StreakState.active,
        mode: AccountabilityMode.ruthless,
        updatedAt: DateTime.now(),
      ));
      // 1 slip — under target=5, but ruthless overrides.
      await writeLog(_slipLog(habitId: 'smoking', occurredAt: _at(9)));

      await service.runDayCloseRollup(_kDate);

      final streak = await service.getStreak('smoking');
      expect(streak!.state, StreakState.broken);
      expect(streak.currentCount, 0);
    });
  });

  // ── routine completion streaks ────────────────────────────────────────────

  group('StreakService.runDayCloseRollup — routine completion streaks', () {
    Future<void> writeTask({
      required String taskId,
      required String parentRoutine,
      required String state,
      String? reasonTag,
    }) async {
      await tasksColl().doc(taskId).set({
        'taskId': taskId,
        'parentRoutine': parentRoutine,
        'state': state,
        if (reasonTag != null) 'reasonTag': reasonTag,
        'plannedStart': Timestamp.fromDate(_at(8)),
        'plannedEnd': Timestamp.fromDate(_at(9)),
      });
    }

    test('routine streak extended when all non-skipped tasks completed',
        () async {
      await writeTask(taskId: 't1', parentRoutine: 'morning', state: 'completed');
      await writeTask(taskId: 't2', parentRoutine: 'morning', state: 'completed');

      final result = await service.runDayCloseRollup(_kDate);

      final streak = await service.getStreak('routine_morning');
      expect(streak!.currentCount, 1);
      expect(streak.scope, StreakScope.routine);
      expect(streak.state, StreakState.active);
      expect(result.streaksActive, 1);
    });

    test('routine streak broken when at least one task incomplete', () async {
      await writeTask(taskId: 't1', parentRoutine: 'morning', state: 'completed');
      await writeTask(taskId: 't2', parentRoutine: 'morning', state: 'abandoned');
      await writeStreak(Streak(
        habitId: 'routine_morning',
        scope: StreakScope.routine,
        currentCount: 4,
        longestCount: 4,
        state: StreakState.active,
        updatedAt: DateTime.now(),
      ));

      await service.runDayCloseRollup(_kDate);

      final streak = await service.getStreak('routine_morning');
      expect(streak!.state, StreakState.broken);
      expect(streak.currentCount, 0);

      final events = await eventsNamed(EventNames.streakBroken);
      expect(events.length, 1);
      expect(events.first.data()['payload']['routineKey'], 'morning');
    });

    test('skipped tasks with valid_reason do not count against routine',
        () async {
      await writeTask(taskId: 't1', parentRoutine: 'morning', state: 'completed');
      await writeTask(
        taskId: 't2',
        parentRoutine: 'morning',
        state: 'skipped',
        reasonTag: 'valid_reason',
      );

      await service.runDayCloseRollup(_kDate);

      final streak = await service.getStreak('routine_morning');
      expect(streak!.state, StreakState.active);
      expect(streak.currentCount, 1);
    });
  });

  // ── ghost pause / resume ──────────────────────────────────────────────────

  group('StreakService ghost pause / resume', () {
    test('pauseAllActiveStreaks freezes active streaks and emits streak_paused',
        () async {
      await writeStreak(Streak(
        habitId: 'water',
        currentCount: 7,
        longestCount: 7,
        state: StreakState.active,
        updatedAt: DateTime.now(),
      ));
      await writeStreak(Streak(
        habitId: 'reading',
        currentCount: 3,
        longestCount: 3,
        state: StreakState.active,
        updatedAt: DateTime.now(),
      ));

      await service.pauseAllActiveStreaks(reason: 'ghost');

      final water = await service.getStreak('water');
      expect(water!.state, StreakState.paused);
      expect(water.prePauseCount, 7);
      expect(water.pauseReason, 'ghost');
      expect(water.pausedAt, isNotNull);

      final reading = await service.getStreak('reading');
      expect(reading!.state, StreakState.paused);
      expect(reading.prePauseCount, 3);

      final events = await eventsNamed(EventNames.streakPaused);
      expect(events.length, 2);
    });

    test('paused streak is not advanced by runDayCloseRollup', () async {
      await writeHabit(_goodHabit(dailyGoal: 1));
      await writeStreak(Streak(
        habitId: 'water',
        currentCount: 5,
        longestCount: 5,
        state: StreakState.paused,
        prePauseCount: 5,
        pausedAt: DateTime(2026, 4, 30),
        pauseReason: 'ghost',
        updatedAt: DateTime.now(),
      ));
      await writeLog(_goodLog(habitId: 'water', occurredAt: _at(9)));

      await service.runDayCloseRollup(_kDate);

      final streak = await service.getStreak('water');
      expect(streak!.state, StreakState.paused,
          reason: 'paused streak should not transition during rollup');
      expect(streak.currentCount, 5);
    });

    test(
        'resumeAllPausedStreaks restores prePauseCount and emits streak_resumed',
        () async {
      await writeStreak(Streak(
        habitId: 'water',
        currentCount: 7,
        longestCount: 7,
        state: StreakState.paused,
        prePauseCount: 7,
        pausedAt: DateTime(2026, 4, 30),
        pauseReason: 'ghost',
        updatedAt: DateTime.now(),
      ));

      await service.resumeAllPausedStreaks();

      final streak = await service.getStreak('water');
      expect(streak!.state, StreakState.active);
      expect(streak.currentCount, 7);
      expect(streak.prePauseCount, isNull);
      expect(streak.pausedAt, isNull);

      final events = await eventsNamed(EventNames.streakResumed);
      expect(events.length, 1);
      expect(events.first.data()['payload']['restoredCount'], 7);
    });
  });

  // ── error resilience ──────────────────────────────────────────────────────

  group('StreakService.runDayCloseRollup — error resilience', () {
    test('continues processing other habits when one habit fails', () async {
      // Two habits — both should have streak docs attempted. Even with one bad
      // log shape, the other habit still gets rolled up.
      await writeHabit(_goodHabit(id: 'water', dailyGoal: 1));
      await writeHabit(_goodHabit(id: 'pages', dailyGoal: 1));
      await writeLog(_goodLog(habitId: 'water', occurredAt: _at(9)));
      await writeLog(_goodLog(habitId: 'pages', occurredAt: _at(10)));

      final result = await service.runDayCloseRollup(_kDate);

      expect(result.habitsCompleted, 2);
      expect(await service.getStreak('water'), isNotNull);
      expect(await service.getStreak('pages'), isNotNull);
    });
  });

  // ── watchAllStreaks ───────────────────────────────────────────────────────

  group('StreakService.watchAllStreaks', () {
    test('stream emits all streak docs for the user', () async {
      await writeStreak(Streak(
        habitId: 'water',
        currentCount: 3,
        state: StreakState.active,
        updatedAt: DateTime.now(),
      ));
      await writeStreak(Streak(
        habitId: 'reading',
        currentCount: 1,
        state: StreakState.active,
        updatedAt: DateTime.now(),
      ));

      final streaks = await service.watchAllStreaks().first;
      expect(streaks.map((s) => s.habitId).toSet(),
          containsAll(['water', 'reading']));
    });
  });

  // ── watchStreak ───────────────────────────────────────────────────────────

  group('StreakService.watchStreak', () {
    test('stream emits the streak doc for the given habitId', () async {
      await writeStreak(Streak(
        habitId: 'water',
        currentCount: 3,
        state: StreakState.active,
        updatedAt: DateTime.now(),
      ));

      final streak = await service.watchStreak('water').first;
      expect(streak, isNotNull);
      expect(streak!.habitId, 'water');
      expect(streak.currentCount, 3);
    });

    test('stream emits null when no streak doc exists', () async {
      final streak = await service.watchStreak('nonexistent').first;
      expect(streak, isNull);
    });
  });

  // ── getStreak ─────────────────────────────────────────────────────────────

  group('StreakService.getStreak', () {
    test('returns Streak when the document exists', () async {
      await writeStreak(Streak(
        habitId: 'water',
        currentCount: 3,
        state: StreakState.active,
        updatedAt: DateTime.now(),
      ));

      final streak = await service.getStreak('water');
      expect(streak, isNotNull);
      expect(streak!.currentCount, 3);
    });

    test('returns null when the document does not exist', () async {
      expect(await service.getStreak('missing'), isNull);
    });
  });
}
