// lib/services/streak_service.dart
//
// Manages per-habit streak state in Firestore.
// Path: /users/{uid}/streaks/{habitId}
//
// The primary entry point is runDayCloseRollup(date), which is triggered by
// the EventOrchestrator when a dayClosed event fires.  For each active habit
// it reads that day's logs, determines whether the goal was met, and updates
// the streak document accordingly.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/event_names.dart';
import '../core/errors/app_errors.dart';
import '../models/habit_model.dart';
import '../models/streak_model.dart';
import 'event_service.dart';

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

  CollectionReference<Map<String, dynamic>> get _streaksRef =>
      _firestore.collection('users').doc(_uid).collection('streaks');

  /// Parses log items for [habitId] on [date] and returns the summed quantity.
  Future<num> _sumLogsForDate(String habitId, String date) async {
    final snap = await _habitsRef
        .doc(habitId)
        .collection('logs')
        .doc(date)
        .collection('items')
        .get();
    num total = 0;
    for (final doc in snap.docs) {
      total += (doc.data()['quantity'] as num?) ?? 1;
    }
    return total;
  }

  /// Returns the slip count for [habitId] on [date].
  Future<int> _slipCountForDate(String habitId, String date) async {
    final snap = await _habitsRef
        .doc(habitId)
        .collection('logs')
        .doc(date)
        .collection('items')
        .count()
        .get();
    return snap.count ?? 0;
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

  /// Iterates all active habits, evaluates goal completion for [date], and
  /// writes updated streak docs to `/users/{uid}/streaks/{habitId}`.
  ///
  /// [date] must be in `YYYY-MM-DD` format.
  Future<void> runDayCloseRollup(String date) async {
    debugPrint('[StreakService] runDayCloseRollup($date) — starting');

    // 1. Load all active habits.
    final habitsSnap = await _habitsRef
        .where('state', isEqualTo: HabitState.active.name)
        .get();

    if (habitsSnap.docs.isEmpty) {
      debugPrint('[StreakService] No active habits — nothing to roll up.');
      return;
    }

    for (final habitDoc in habitsSnap.docs) {
      final habit = HabitModel.fromFirestore(habitDoc);
      await _rollupHabit(habit, date);
    }

    debugPrint('[StreakService] runDayCloseRollup($date) — complete');
  }

  /// Computes the new streak state for a single [habit] on [date] and
  /// persists the result.
  Future<void> _rollupHabit(HabitModel habit, String date) async {
    try {
      // 2. Read today's logs.
      final num logged = habit.kind == HabitKind.good
          ? await _sumLogsForDate(habit.id, date)
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

      // 5. Persist + emit side-effect events.
      final batch = _firestore.batch();
      batch.set(streakDocRef, next.toFirestore(), SetOptions(merge: true));

      if (hit && next.currentCount > current.currentCount) {
        // Streak extended — emit event.
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
        // Streak broken — emit event.
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

      await batch.commit();

      debugPrint(
        '[StreakService] ${habit.id}: hit=$hit '
        'current=${next.currentCount} longest=${next.longestCount} '
        'state=${next.state.name}',
      );
    } catch (e, st) {
      // Never let a single habit failure abort the entire rollup.
      debugPrint('[StreakService] Error rolling up ${habit.id}: $e\n$st');
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
