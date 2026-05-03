// lib/services/streak_service.dart
//
// Manages per-habit and per-routine streak state in Firestore.
//
//   /users/{uid}/streaks/{habitId}            — habit streaks (good & bad)
//   /users/{uid}/streaks/routine_<routineKey> — routine completion streaks
//
// The primary entry point is runDayCloseRollup(date), called by RoutineService
// as step 1 of the day-close sequence. It:
//
//   1. Reads the user's accountabilityMode (forgiving | strict | ruthless).
//   2. For each active habit: reads logs from /users/{uid}/habit_logs,
//      evaluates the goal, applies the accountability rule, persists the
//      streak doc, and emits streak_extended / streak_broken /
//      streak_milestone_reached as appropriate.
//   3. Groups the day's tasks by parentRoutine and updates routine streak
//      docs with the same rules.
//
// Ghost / comeback orchestration calls pauseAllActiveStreaks and
// resumeAllPausedStreaks, which emit streak_paused / streak_resumed.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/event_names.dart';
import '../core/errors/app_errors.dart';
import '../models/habit_model.dart';
import '../models/streak_model.dart';
import 'event_service.dart';

// ── Constants ────────────────────────────────────────────────────────────────

/// Streak lengths that trigger a `streak_milestone_reached` event.
const List<int> kStreakMilestones = [3, 7, 14, 30, 60, 90, 180, 365];

const String _kRoutineStreakPrefix = 'routine_';

// ── Return type ──────────────────────────────────────────────────────────────

/// Aggregated metrics from a single day-close rollup run.
/// Consumed by RoutineService to populate DaySummary.
class DayRollupResult {
  final int habitsCompleted;
  final int habitsBadLogged;
  final int streaksActive;
  final List<String> streaksMilestonesHit;

  const DayRollupResult({
    this.habitsCompleted = 0,
    this.habitsBadLogged = 0,
    this.streaksActive = 0,
    this.streaksMilestonesHit = const [],
  });
}

// ── Service ───────────────────────────────────────────────────────────────────

class StreakService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final EventService _eventService;

  StreakService({
    required EventService eventService,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _eventService = eventService,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // ── Helpers ──────────────────────────────────────────────────────────────

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw const NotAuthenticatedError();
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _habitsRef =>
      _firestore.collection('users').doc(_uid).collection('habits');

  /// Canonical flat collection written by HabitService dual-write.
  CollectionReference<Map<String, dynamic>> get _habitLogsRef =>
      _firestore.collection('users').doc(_uid).collection('habit_logs');

  CollectionReference<Map<String, dynamic>> get _streaksRef =>
      _firestore.collection('users').doc(_uid).collection('streaks');

  CollectionReference<Map<String, dynamic>> get _tasksRef =>
      _firestore.collection('users').doc(_uid).collection('tasks');

  // ── Log readers (canonical collection) ───────────────────────────────────

  /// Parses logs for [habitId] on [date] where logType == 'good' and returns
  /// the summed quantity.  Uses the canonical habit_logs collection.
  Future<num> _sumGoodLogsForDate(String habitId, String date) async {
    final (startOfDay, endOfDay) = _dayBounds(date);

    final snap = await _habitLogsRef
        .where('habitId', isEqualTo: habitId)
        .where('occurredAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('occurredAt', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    num total = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['logType'] == 'good') {
        total += (data['quantity'] as num?) ?? 1;
      }
    }
    return total;
  }

  /// Returns the slip count for [habitId] on [date].  Filters by
  /// logType == 'slip' to avoid counting non-slip entries.
  Future<int> _slipCountForDate(String habitId, String date) async {
    final (startOfDay, endOfDay) = _dayBounds(date);

    final snap = await _habitLogsRef
        .where('habitId', isEqualTo: habitId)
        .where('occurredAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('occurredAt', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    int count = 0;
    for (final doc in snap.docs) {
      if (doc.data()['logType'] == 'slip') {
        count++;
      }
    }
    return count;
  }

  /// Parses start/end DateTime bounds for a YYYY-MM-DD string.
  (DateTime, DateTime) _dayBounds(String date) {
    final start = _parseDate(date);
    return (start, start.add(const Duration(days: 1)));
  }

  static DateTime _parseDate(String date) {
    final parts = date.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// ISO 8601 week key — "YYYY-Www" — used as the bucket for forgiving-mode
  /// grace days.
  static String isoWeekKey(DateTime date) {
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final year = thursday.year;
    final firstThursday = DateTime(year, 1, 4);
    final firstWeekStart =
        firstThursday.subtract(Duration(days: firstThursday.weekday - 1));
    final week = ((thursday.difference(firstWeekStart).inDays) ~/ 7) + 1;
    return '$year-W${week.toString().padLeft(2, '0')}';
  }

  // ── Goal evaluation ──────────────────────────────────────────────────────

  /// Returns `true` if the habit's goal was met for the given day under
  /// the supplied accountability [mode].
  bool _goalMet(HabitModel habit, num logged, AccountabilityMode mode) {
    // Ruthless overrides bad-habit goal type — any slip is a break.
    if (habit.kind == HabitKind.bad &&
        mode == AccountabilityMode.ruthless &&
        logged > 0) {
      return false;
    }

    if (habit.kind == HabitKind.good) {
      final goal = habit.dailyGoal;
      if (goal == null) return logged > 0; // any log counts
      return logged >= goal;
    }
    switch (habit.goalType ?? BadHabitGoalType.awarenessOnly) {
      case BadHabitGoalType.eliminate:
        return logged == 0;
      case BadHabitGoalType.reduceToTarget:
        final target = habit.target;
        if (target == null) return true;
        return logged <= target;
      case BadHabitGoalType.awarenessOnly:
        return true;
    }
  }

  // ── User-mode resolution ─────────────────────────────────────────────────

  Future<AccountabilityMode> _resolveUserMode() async {
    try {
      final userDoc = await _firestore.collection('users').doc(_uid).get();
      final raw = userDoc.data()?['accountabilityMode'] as String?;
      return AccountabilityMode.fromString(raw);
    } catch (e) {
      debugPrint('[StreakService] Could not resolve accountability mode: $e');
      return AccountabilityMode.strict;
    }
  }

  // ── Day-close rollup ─────────────────────────────────────────────────────

  /// Iterates active habits and routines, evaluates completion for [date],
  /// writes updated streak docs, and emits the streak event family.
  ///
  /// [date] must be in `YYYY-MM-DD` format.
  ///
  /// Returns a [DayRollupResult] with aggregated metrics for the day
  /// summary.  Habit logs must already be written to the canonical
  /// `/users/{uid}/habit_logs` collection before this is called.
  Future<DayRollupResult> runDayCloseRollup(String date) async {
    debugPrint('[StreakService] runDayCloseRollup($date) — starting');

    final mode = await _resolveUserMode();

    // 1. Active habits.
    final habitsSnap = await _habitsRef
        .where('state', isEqualTo: HabitState.active.name)
        .get();

    int habitsCompleted = 0;
    int habitsBadLogged = 0;
    int streaksActive = 0;
    final List<String> milestonesHit = [];

    for (final habitDoc in habitsSnap.docs) {
      final habit = HabitModel.fromFirestore(habitDoc);
      final result = await _rollupHabit(habit, date, mode);

      if (result.goalMet && habit.kind == HabitKind.good) {
        habitsCompleted++;
      }
      if (habit.kind == HabitKind.bad && result.logged > 0) {
        habitsBadLogged += result.logged.toInt();
      }
      if (result.streakActiveAfter) {
        streaksActive++;
      }
      if (result.milestoneReached != null) {
        milestonesHit.add('${habit.id}:${result.milestoneReached}');
      }
    }

    // 2. Routine completion streaks.
    final routineResult = await _rollupRoutines(date, mode);
    streaksActive += routineResult.streaksActive;
    milestonesHit.addAll(routineResult.milestonesHit);

    debugPrint('[StreakService] runDayCloseRollup($date) — complete. '
        'completed=$habitsCompleted active=$streaksActive');

    return DayRollupResult(
      habitsCompleted: habitsCompleted,
      habitsBadLogged: habitsBadLogged,
      streaksActive: streaksActive,
      streaksMilestonesHit: milestonesHit,
    );
  }

  // ── Single-habit rollup ───────────────────────────────────────────────────

  Future<
      ({
        bool goalMet,
        num logged,
        int? milestoneReached,
        bool streakActiveAfter,
      })> _rollupHabit(
    HabitModel habit,
    String date,
    AccountabilityMode mode,
  ) async {
    try {
      final num logged = habit.kind == HabitKind.good
          ? await _sumGoodLogsForDate(habit.id, date)
          : (await _slipCountForDate(habit.id, date)).toDouble();

      final hit = _goalMet(habit, logged, mode);

      final docRef = _streaksRef.doc(habit.id);
      final snap = await docRef.get();

      final current = snap.exists
          ? Streak.fromFirestore(snap)
          : Streak.initial(habit.id, mode: mode);

      // Frozen streaks (paused) are not advanced by the daily rollup.
      if (current.state == StreakState.paused) {
        return (
          goalMet: hit,
          logged: logged,
          milestoneReached: null,
          streakActiveAfter: false,
        );
      }

      final next = _computeNextStreak(current, date, hit, mode);

      final batch = _firestore.batch();
      batch.set(docRef, next.toFirestore(), SetOptions(merge: true));

      int? milestoneReached;
      final extended = hit && next.currentCount > current.currentCount;
      final broken = !hit &&
          next.state == StreakState.broken &&
          current.state == StreakState.active;

      if (extended) {
        await _eventService.emit(
          eventName: EventNames.streakExtended,
          payload: {
            'habitId': habit.id,
            'scope': StreakScope.habit.name,
            'mode': mode.name,
            'currentCount': next.currentCount,
            'longestCount': next.longestCount,
            'date': date,
          },
          batch: batch,
        );

        if (kStreakMilestones.contains(next.currentCount)) {
          milestoneReached = next.currentCount;
          await _eventService.emit(
            eventName: EventNames.streakMilestoneReached,
            payload: {
              'habitId': habit.id,
              'scope': StreakScope.habit.name,
              'milestone': next.currentCount,
              'date': date,
            },
            batch: batch,
          );
        }
      } else if (broken) {
        await _eventService.emit(
          eventName: EventNames.streakBroken,
          payload: {
            'habitId': habit.id,
            'scope': StreakScope.habit.name,
            'mode': mode.name,
            'brokenAt': date,
            'previousCount': current.currentCount,
          },
          batch: batch,
        );
      }

      await batch.commit();

      debugPrint(
        '[StreakService] ${habit.id}: hit=$hit logged=$logged '
        'current=${next.currentCount} longest=${next.longestCount} '
        'state=${next.state.name} mode=${mode.name}',
      );

      return (
        goalMet: hit,
        logged: logged,
        milestoneReached: milestoneReached,
        streakActiveAfter: next.state == StreakState.active,
      );
    } catch (e, st) {
      debugPrint('[StreakService] Error rolling up ${habit.id}: $e\n$st');
      return (
        goalMet: false,
        logged: 0.0,
        milestoneReached: null,
        streakActiveAfter: false,
      );
    }
  }

  // ── Routine completion rollup ────────────────────────────────────────────

  Future<({int streaksActive, List<String> milestonesHit})> _rollupRoutines(
    String date,
    AccountabilityMode mode,
  ) async {
    try {
      final (start, end) = _dayBounds(date);
      final tasksSnap = await _tasksRef
          .where('plannedStart',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('plannedStart', isLessThan: Timestamp.fromDate(end))
          .get();

      final groups = <String, List<Map<String, dynamic>>>{};
      for (final doc in tasksSnap.docs) {
        final data = doc.data();
        final parent = (data['parentRoutine'] as String?)?.trim();
        if (parent == null || parent.isEmpty) continue;
        groups.putIfAbsent(parent, () => []).add(data);
      }

      int streaksActive = 0;
      final milestones = <String>[];

      for (final entry in groups.entries) {
        final hit = _routineCompleted(entry.value);
        final outcome = await _rollupRoutineKey(entry.key, date, hit, mode);
        if (outcome.streakActiveAfter) streaksActive++;
        if (outcome.milestoneReached != null) {
          milestones.add(
              '$_kRoutineStreakPrefix${entry.key}:${outcome.milestoneReached}');
        }
      }

      return (streaksActive: streaksActive, milestonesHit: milestones);
    } catch (e, st) {
      debugPrint('[StreakService] Error rolling up routines: $e\n$st');
      return (streaksActive: 0, milestonesHit: const <String>[]);
    }
  }

  bool _routineCompleted(List<Map<String, dynamic>> tasks) {
    var needed = 0;
    var completed = 0;
    for (final t in tasks) {
      final state = (t['state'] as String?) ?? 'scheduled';
      final reasonTag = ((t['reasonTag'] as String?) ?? '').toLowerCase();
      final excluded = state == 'skipped' &&
          (reasonTag == 'valid_reason' ||
              reasonTag == 'day_off' ||
              reasonTag == 'illness');
      if (excluded) continue;
      needed++;
      if (state == 'completed') completed++;
    }
    return needed > 0 && completed == needed;
  }

  Future<({int? milestoneReached, bool streakActiveAfter})> _rollupRoutineKey(
    String routineKey,
    String date,
    bool hit,
    AccountabilityMode mode,
  ) async {
    final streakId = '$_kRoutineStreakPrefix$routineKey';
    final docRef = _streaksRef.doc(streakId);
    final snap = await docRef.get();
    final current = snap.exists
        ? Streak.fromFirestore(snap)
        : Streak.initial(streakId, scope: StreakScope.routine, mode: mode);

    if (current.state == StreakState.paused) {
      return (milestoneReached: null, streakActiveAfter: false);
    }

    final next = _computeNextStreak(current, date, hit, mode);
    final batch = _firestore.batch();
    batch.set(docRef, next.toFirestore(), SetOptions(merge: true));

    int? milestoneReached;
    final extended = hit && next.currentCount > current.currentCount;
    final broken = !hit &&
        next.state == StreakState.broken &&
        current.state == StreakState.active;

    if (extended) {
      await _eventService.emit(
        eventName: EventNames.streakExtended,
        payload: {
          'habitId': streakId,
          'scope': StreakScope.routine.name,
          'routineKey': routineKey,
          'mode': mode.name,
          'currentCount': next.currentCount,
          'longestCount': next.longestCount,
          'date': date,
        },
        batch: batch,
      );

      if (kStreakMilestones.contains(next.currentCount)) {
        milestoneReached = next.currentCount;
        await _eventService.emit(
          eventName: EventNames.streakMilestoneReached,
          payload: {
            'habitId': streakId,
            'scope': StreakScope.routine.name,
            'routineKey': routineKey,
            'milestone': next.currentCount,
            'date': date,
          },
          batch: batch,
        );
      }
    } else if (broken) {
      await _eventService.emit(
        eventName: EventNames.streakBroken,
        payload: {
          'habitId': streakId,
          'scope': StreakScope.routine.name,
          'routineKey': routineKey,
          'mode': mode.name,
          'brokenAt': date,
          'previousCount': current.currentCount,
        },
        batch: batch,
      );
    }

    await batch.commit();
    return (
      milestoneReached: milestoneReached,
      streakActiveAfter: next.state == StreakState.active,
    );
  }

  // ── Pure state machine ───────────────────────────────────────────────────

  Streak _computeNextStreak(
    Streak current,
    String date,
    bool hit,
    AccountabilityMode mode,
  ) {
    final now = DateTime.now();

    if (hit) {
      final newCount = current.currentCount + 1;
      final newLongest =
          newCount > current.longestCount ? newCount : current.longestCount;
      return current.copyWith(
        currentCount: newCount,
        longestCount: newLongest,
        lastHitDate: date,
        state: StreakState.active,
        mode: mode,
        updatedAt: now,
      );
    }

    // Forgiving: spend an ISO-week grace day if we have one and there is an
    // existing streak to preserve.
    if (mode == AccountabilityMode.forgiving && current.currentCount > 0) {
      final weekKey = isoWeekKey(_parseDate(date));
      final used = current.weeklySkipsUsed[weekKey] ?? 0;
      if (used < 1) {
        final updated = Map<String, int>.from(current.weeklySkipsUsed);
        updated[weekKey] = used + 1;
        return current.copyWith(
          weeklySkipsUsed: updated,
          state: StreakState.active,
          mode: mode,
          updatedAt: now,
        );
      }
    }

    return current.copyWith(
      currentCount: 0,
      lastBreakDate: date,
      state: StreakState.broken,
      mode: mode,
      updatedAt: now,
    );
  }

  // ── Ghost pause / comeback resume ────────────────────────────────────────

  /// Freezes every active streak. Called by the orchestrator when
  /// `ghost_day_detected` fires. Idempotent — already-paused streaks are
  /// skipped.
  Future<int> pauseAllActiveStreaks({
    String reason = 'ghost',
    int? gapDays,
  }) async {
    final snap = await _streaksRef
        .where('state', isEqualTo: StreakState.active.name)
        .get();

    var pausedCount = 0;
    for (final doc in snap.docs) {
      try {
        final streak = Streak.fromFirestore(doc);
        if (streak.state != StreakState.active) continue;

        final now = DateTime.now();
        final batch = _firestore.batch();
        batch.update(doc.reference, {
          'state': StreakState.paused.name,
          'pausedAt': Timestamp.fromDate(now),
          'prePauseCount': streak.currentCount,
          'pauseReason': reason,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await _eventService.emit(
          eventName: EventNames.streakPaused,
          payload: {
            'habitId': streak.habitId,
            'scope': streak.scope.name,
            'reason': reason,
            if (gapDays != null) 'gapDays': gapDays,
            'prePauseCount': streak.currentCount,
            'currentCount': streak.currentCount,
            'longestCount': streak.longestCount,
          },
          batch: batch,
        );

        await batch.commit();
        pausedCount++;
      } catch (e, st) {
        debugPrint('[StreakService] pause failed for ${doc.id}: $e\n$st');
      }
    }
    return pausedCount;
  }

  /// Restores every paused streak to its pre-pause count. Called by the
  /// orchestrator when `comeback_initiated` fires.
  Future<int> resumeAllPausedStreaks({
    String reason = 'ghost',
    int? gapDays,
  }) async {
    final snap = await _streaksRef
        .where('state', isEqualTo: StreakState.paused.name)
        .get();

    var resumedCount = 0;
    for (final doc in snap.docs) {
      try {
        final streak = Streak.fromFirestore(doc);
        if (streak.state != StreakState.paused) continue;
        if (reason.isNotEmpty && streak.pauseReason != reason) continue;

        final restored = streak.prePauseCount ?? streak.currentCount;
        final batch = _firestore.batch();
        batch.update(doc.reference, {
          'state': StreakState.active.name,
          'currentCount': restored,
          'pausedAt': FieldValue.delete(),
          'prePauseCount': FieldValue.delete(),
          'pauseReason': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await _eventService.emit(
          eventName: EventNames.streakResumed,
          payload: {
            'habitId': streak.habitId,
            'scope': streak.scope.name,
            'reason': reason,
            if (gapDays != null) 'gapDays': gapDays,
            'prePauseCount': streak.prePauseCount,
            'restoredCount': restored,
            'currentCount': restored,
            'longestCount': streak.longestCount,
          },
          batch: batch,
        );

        await batch.commit();
        resumedCount++;
      } catch (e, st) {
        debugPrint('[StreakService] resume failed for ${doc.id}: $e\n$st');
      }
    }
    return resumedCount;
  }

  // ── Read helpers for UI ───────────────────────────────────────────────────

  /// Real-time stream of all streak docs for the user.
  Stream<List<Streak>> watchAllStreaks() {
    return _streaksRef.snapshots().map(
        (snap) => snap.docs.map((doc) => Streak.fromFirestore(doc)).toList());
  }

  /// Real-time stream of the streak doc for [habitId].
  Stream<Streak?> watchStreak(String habitId) {
    return _streaksRef.doc(habitId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return Streak.fromFirestore(snap);
    });
  }

  /// One-shot fetch of the streak doc for [habitId].
  Future<Streak?> getStreak(String habitId) async {
    final snap = await _streaksRef.doc(habitId).get();
    if (!snap.exists) return null;
    return Streak.fromFirestore(snap);
  }
}
