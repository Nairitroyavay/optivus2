// lib/services/streak_service.dart
//
// Manages per-habit streak state in Firestore.
// Path: /users/{uid}/streaks/{habitId}
//
// The primary entry point is runDayCloseRollup(date), which is called
// directly by RoutineService as step 1 of the day-close sequence.
// For each active habit it reads that day's logs from the canonical
// /users/{uid}/habit_logs collection, determines whether the goal was met,
// and updates the streak document accordingly.
//
// Returns a DayRollupResult so RoutineService can populate DaySummary
// with real metrics rather than zeros.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/event_names.dart';
import '../core/errors/app_errors.dart';
import '../models/habit_model.dart';
import '../models/streak_model.dart';
import 'event_service.dart';

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

  // ── Log readers (canonical collection) ───────────────────────────────────

  /// Parses logs for [habitId] on [date] where logType == 'good' and returns
  /// the summed quantity.  Uses the canonical habit_logs collection.
  Future<num> _sumGoodLogsForDate(String habitId, String date) async {
    final (startOfDay, endOfDay) = _dayBounds(date);

    final snap = await _habitLogsRef
        .where('habitId', isEqualTo: habitId)
        .where('occurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
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
        .where('occurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
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
    final parts = date.split('-');
    final startOfDay = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    return (startOfDay, startOfDay.add(const Duration(days: 1)));
  }

  // ── Goal evaluation ──────────────────────────────────────────────────────

  /// Returns `true` if the habit's goal was met for the given day.
  bool _goalMet(HabitModel habit, num logged) {
    if (habit.kind == HabitKind.good) {
      final goal = habit.dailyGoal;
      if (goal == null) return logged > 0; // any log counts
      return logged >= goal;
    } else {
      // bad habit
      switch (habit.goalType ?? BadHabitGoalType.awarenessOnly) {
        case BadHabitGoalType.eliminate:
          return logged == 0; // zero slips = success
        case BadHabitGoalType.reduceToTarget:
          final target = habit.target;
          if (target == null) return true; // no cap set, always pass
          return logged <= target;
        case BadHabitGoalType.awarenessOnly:
          return true; // tracking only — goal always "met"
      }
    }
  }

  // ── Day-close rollup ─────────────────────────────────────────────────────

  /// Iterates all active habits, evaluates goal completion for [date],
  /// writes updated streak docs to `/users/{uid}/streaks/{habitId}`, and
  /// emits `streak_extended`, `streak_broken`, and `streak_milestone_reached`
  /// as appropriate.
  ///
  /// [date] must be in `YYYY-MM-DD` format.
  ///
  /// Returns a [DayRollupResult] with aggregated metrics for the day
  /// summary.  Habit logs must already be written to the canonical
  /// `/users/{uid}/habit_logs` collection before this is called.
  Future<DayRollupResult> runDayCloseRollup(String date) async {
    debugPrint('[StreakService] runDayCloseRollup($date) — starting');

    // 1. Load all active habits.
    final habitsSnap = await _habitsRef
        .where('state', isEqualTo: HabitState.active.name)
        .get();

    if (habitsSnap.docs.isEmpty) {
      debugPrint('[StreakService] No active habits — nothing to roll up.');
      return const DayRollupResult();
    }

    // Accumulate summary metrics across all habits.
    int habitsCompleted = 0;
    int habitsBadLogged = 0;
    int streaksActive = 0;
    final List<String> milestonesHit = [];

    for (final habitDoc in habitsSnap.docs) {
      final habit = HabitModel.fromFirestore(habitDoc);
      final result = await _rollupHabit(habit, date);

      if (result.goalMet) {
        if (habit.kind == HabitKind.good) {
          habitsCompleted++;
        }
        streaksActive++;
      }
      if (habit.kind == HabitKind.bad && result.logged > 0) {
        habitsBadLogged += result.logged.toInt();
      }
      if (result.milestoneReached != null) {
        milestonesHit.add('${habit.id}:${result.milestoneReached}');
      }
    }

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

  /// Computes the new streak state for a single [habit] on [date], persists
  /// the result, and emits the appropriate streak events.
  Future<({bool goalMet, num logged, int? milestoneReached})> _rollupHabit(
    HabitModel habit,
    String date,
  ) async {
    try {
      // 2. Read logs from canonical collection (habit_logs).
      final num logged = habit.kind == HabitKind.good
          ? await _sumGoodLogsForDate(habit.id, date)
          : (await _slipCountForDate(habit.id, date)).toDouble();

      final bool hit = _goalMet(habit, logged);

      // 3. Load existing streak (or seed a fresh one).
      final streakDocRef = _streaksRef.doc(habit.id);
      final streakSnap = await streakDocRef.get();

      final Streak current = streakSnap.exists
          ? Streak.fromFirestore(streakSnap)
          : Streak.initial(habit.id);

      // 4. Compute next streak state.
      final Streak next = _computeNextStreak(current, date, hit);

      // 5. Persist + emit side-effect events atomically.
      final batch = _firestore.batch();
      batch.set(streakDocRef, next.toFirestore(), SetOptions(merge: true));

      int? milestoneReached;

      if (hit && next.currentCount > current.currentCount) {
        // Streak extended — emit event inside the batch.
        await _eventService.emit(
          eventName: EventNames.streakExtended,
          payload: {
            'habitId': habit.id,
            'currentCount': next.currentCount,
            'longestCount': next.longestCount,
            'date': date,
          },
          batch: batch,
        );

        // Milestone check: 7, 14, 21, 30, 60, 90, 180, 365-day milestones.
        const milestones = [7, 14, 21, 30, 60, 90, 180, 365];
        if (milestones.contains(next.currentCount)) {
          milestoneReached = next.currentCount;
          await _eventService.emit(
            eventName: EventNames.streakMilestoneReached,
            payload: {
              'habitId': habit.id,
              'milestone': next.currentCount,
              'date': date,
            },
            batch: batch,
          );
        }
      } else if (!hit && current.state == StreakState.active) {
        // Streak broken — emit event inside the batch.
        await _eventService.emit(
          eventName: EventNames.streakBroken,
          payload: {
            'habitId': habit.id,
            'brokenAt': date,
            'previousCount': current.currentCount,
          },
          batch: batch,
        );
      }

      // Commit streak doc + event docs in a single batch.
      await batch.commit();

      debugPrint(
        '[StreakService] ${habit.id}: hit=$hit logged=$logged '
        'current=${next.currentCount} longest=${next.longestCount} '
        'state=${next.state.name}',
      );

      return (goalMet: hit, logged: logged, milestoneReached: milestoneReached);
    } catch (e, st) {
      // Never let a single habit failure abort the entire rollup.
      debugPrint('[StreakService] Error rolling up ${habit.id}: $e\n$st');
      return (goalMet: false, logged: 0.0, milestoneReached: null);
    }
  }

  // ── State machine ─────────────────────────────────────────────────────────

  /// Pure function — derives the next [Streak] from [current], [date], and
  /// whether the goal was [hit].
  Streak _computeNextStreak(Streak current, String date, bool hit) {
    if (hit) {
      final newCount = current.currentCount + 1;
      final newLongest =
          newCount > current.longestCount ? newCount : current.longestCount;

      return current.copyWith(
        currentCount: newCount,
        longestCount: newLongest,
        lastHitDate: date,
        state: StreakState.active,
        updatedAt: DateTime.now(),
      );
    } else {
      // Missed: reset current streak but preserve longest.
      return current.copyWith(
        currentCount: 0,
        lastBreakDate: date,
        state: StreakState.broken,
        updatedAt: DateTime.now(),
      );
    }
  }

  // ── Read helpers for UI ───────────────────────────────────────────────────

  /// Real-time stream of all streak docs for the user.
  Stream<List<Streak>> watchAllStreaks() {
    return _streaksRef.snapshots().map((snap) =>
        snap.docs.map((doc) => Streak.fromFirestore(doc)).toList());
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
