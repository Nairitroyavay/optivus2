// lib/services/fitness_stats_service.dart
//
// Aggregation service for fitness stats.
// Reads completed activities, writes to:
//   /users/{uid}/fitnessStats/{periodKey}
// Period keys: daily_YYYY-MM-DD, weekly_YYYY-Www, monthly_YYYY-MM
//
// Stats are updated atomically after each activity completion.
// Cloud Functions provide a safety-net re-aggregation for missed writes.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/fitness_activity_model.dart';
import '../models/fitness_goal_model.dart';
import '../models/fitness_stats_model.dart';
import '../services/fitness_event_service.dart';
import '../services/firestore_service.dart';

class FitnessStatsService {
  final FirestoreService _firestoreService;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  FitnessStatsService({
    required FirestoreService firestoreService,
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _firestoreService = firestoreService,
        _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  // ── Period key generation ────────────────────────────────────────────────

  /// Returns `daily_2026-05-07` for a given date.
  static String dailyKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return 'daily_$y-$m-$d';
  }

  /// Returns `weekly_2026-W19` for a given date (ISO 8601 week number).
  static String weeklyKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final weekNum = _isoWeekNumber(date);
    return 'weekly_$y-W${weekNum.toString().padLeft(2, '0')}';
  }

  /// Returns `monthly_2026-05` for a given date.
  static String monthlyKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    return 'monthly_$y-$m';
  }

  /// ISO 8601 week number.
  static int _isoWeekNumber(DateTime date) {
    // Thursday of current week decides the year/week.
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
    final weekday = date.weekday; // Monday=1 .. Sunday=7
    final thursdayOrdinal = dayOfYear + (4 - weekday);
    return (thursdayOrdinal / 7).ceil();
  }

  // ── Stats update after activity completion ───────────────────────────────

  /// Incrementally updates daily, weekly, and monthly stats after an
  /// activity is completed. Uses Firestore `merge: true` so concurrent
  /// completions don't overwrite each other.
  Future<void> updateStatsAfterActivityCompleted(
    FitnessActivityModel activity,
  ) async {
    if (activity.status != FitnessActivityStatus.completed) {
      debugPrint('[FitnessStatsService] Skipping non-completed activity.');
      return;
    }

    final completedAt = activity.completedAt ?? DateTime.now();
    final keys = [
      dailyKey(completedAt),
      weeklyKey(completedAt),
      monthlyKey(completedAt),
    ];

    final periodTypes = ['daily', 'weekly', 'monthly'];
    final batch = _db.batch();

    for (var i = 0; i < keys.length; i++) {
      final ref = _firestoreService
          .userCollection(FirestoreService.kFitnessStats)
          .doc(keys[i]);

      batch.set(
        ref,
        _incrementPayload(activity, keys[i], periodTypes[i]),
        SetOptions(merge: true),
      );
    }

    await batch.commit();
    debugPrint(
      '[FitnessStatsService] Updated stats for keys: ${keys.join(', ')}',
    );
  }

  /// Client-side completion side effects for immediate UI feedback.
  ///
  /// Cloud Functions also run this as a safety net. This method marks the
  /// activity with `statsProcessedAt` in the same batch so the backend trigger
  /// can skip already-processed completions.
  Future<void> updateCompletionAggregatesAfterActivityCompleted(
    FitnessActivityModel activity, {
    FitnessEventService? eventService,
  }) async {
    if (activity.status != FitnessActivityStatus.completed) return;

    final activityRef = _firestoreService
        .userCollection(FirestoreService.kFitnessActivities)
        .doc(activity.activityId);
    final activitySnap = await activityRef.get();
    if (activitySnap.data()?['statsProcessedAt'] != null) return;

    final completedAt = activity.completedAt ?? DateTime.now();
    final keys = [
      dailyKey(completedAt),
      weeklyKey(completedAt),
      monthlyKey(completedAt),
    ];
    const periodTypes = ['daily', 'weekly', 'monthly'];

    final goalsSnap = await _firestoreService
        .userCollection(FirestoreService.kFitnessGoals)
        .where('status', isEqualTo: 'active')
        .get();

    final batch = _db.batch();
    for (var i = 0; i < keys.length; i++) {
      final ref = _firestoreService
          .userCollection(FirestoreService.kFitnessStats)
          .doc(keys[i]);
      batch.set(
        ref,
        _incrementPayload(activity, keys[i], periodTypes[i]),
        SetOptions(merge: true),
      );
    }

    final goalEvents = <_GoalEvent>[];
    for (final goalDoc in goalsSnap.docs) {
      final goal = FitnessGoalModel.fromMap(
        goalDoc.data(),
        fallbackId: goalDoc.id,
      );
      final increment = _goalIncrement(goal.goalType, activity);
      if (increment <= 0) continue;

      final nextValue = goal.currentValue + increment;
      final completed = goal.targetValue > 0 && nextValue >= goal.targetValue;
      batch.update(goalDoc.reference, {
        'currentValue': nextValue,
        if (completed) 'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      goalEvents.add(
        _GoalEvent(
          goalId: goal.goalId,
          goalType: goal.goalType,
          currentValue: nextValue,
          targetValue: goal.targetValue,
          completed: completed,
        ),
      );
    }

    batch.update(activityRef, {
      'statsProcessedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    for (final goal in goalEvents) {
      await eventService?.emitGoalProgressUpdated(
        goalId: goal.goalId,
        goalType: goal.goalType,
        currentValue: goal.currentValue,
        targetValue: goal.targetValue,
      );
      if (goal.completed) {
        await eventService?.emitGoalCompleted(
          goalId: goal.goalId,
          goalType: goal.goalType,
        );
        if (goal.goalType == 'weekly_distance') {
          await eventService?.emitWeeklyDistanceGoalCompleted(
            goalId: goal.goalId,
            distanceKm: goal.currentValue,
          );
        }
      }
    }
  }

  /// Builds the merge-safe increment payload for a single stats doc.
  Map<String, dynamic> _incrementPayload(
    FitnessActivityModel activity,
    String periodKey,
    String periodType,
  ) {
    final typeKey = activity.activityType.toJson();
    final durationMs = activity.durationMs > 0
        ? activity.durationMs
        : activity.activeDuration.inMilliseconds;

    return {
      'periodKey': periodKey,
      'periodType': periodType,
      'totalActivities': FieldValue.increment(1),
      'totalDistanceMeters': FieldValue.increment(activity.distanceMeters),
      'totalDurationMs': FieldValue.increment(durationMs),
      'totalCalories': FieldValue.increment(activity.calories ?? 0),
      'activityBreakdown.$typeKey': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
      // createdAt only written on first create via merge.
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  double _goalIncrement(String goalType, FitnessActivityModel activity) {
    switch (goalType) {
      case 'weekly_distance':
      case 'monthly_distance':
        return activity.distanceMeters / 1000;
      case 'weekly_activities':
        return 1;
      case 'weekly_duration':
        return activity.movingTimeSeconds > 0
            ? activity.movingTimeSeconds / 60
            : activity.durationSeconds / 60;
      default:
        return 0;
    }
  }

  // ── Read helpers ─────────────────────────────────────────────────────────

  /// One-shot read of stats for a given period key.
  Future<FitnessStatsModel?> fetchStats(String periodKey) async {
    final doc = await _firestoreService
        .userCollection(FirestoreService.kFitnessStats)
        .doc(periodKey)
        .get();
    if (!doc.exists) return null;
    return FitnessStatsModel.fromMap(doc.data()!, fallbackId: doc.id);
  }

  /// Real-time stream of stats for a given period key.
  Stream<FitnessStatsModel?> watchStats(String periodKey) {
    return _firestoreService
        .userCollection(FirestoreService.kFitnessStats)
        .doc(periodKey)
        .snapshots()
        .map((snap) => snap.exists
            ? FitnessStatsModel.fromMap(snap.data()!, fallbackId: snap.id)
            : null);
  }

  /// Stream of daily stats for a specific date.
  Stream<FitnessStatsModel?> watchDailyStats(DateTime date) =>
      watchStats(dailyKey(date));

  /// Stream of weekly stats for the week containing [date].
  Stream<FitnessStatsModel?> watchWeeklyStats(DateTime date) =>
      watchStats(weeklyKey(date));

  /// Stream of monthly stats for the month containing [date].
  Stream<FitnessStatsModel?> watchMonthlyStats(DateTime date) =>
      watchStats(monthlyKey(date));

  // ── Full re-aggregation (for Cloud Functions safety-net) ─────────────────

  /// Re-aggregates stats for a daily period from scratch by querying
  /// all completed activities in that date range.
  Future<FitnessStatsModel> recomputeDailyStats(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snap = await _db
        .collection('users')
        .doc(_uid)
        .collection(FirestoreService.kFitnessActivities)
        .where('status', isEqualTo: 'completed')
        .where('completedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('completedAt', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    final activities =
        snap.docs.map((d) => FitnessActivityModel.fromMap(d.data())).toList();

    final stats = _aggregate(activities, dailyKey(date), 'daily');

    await _firestoreService
        .userCollection(FirestoreService.kFitnessStats)
        .doc(stats.periodKey)
        .set(stats.toMap());

    return stats;
  }

  /// Aggregates a list of activities into a single stats model.
  FitnessStatsModel _aggregate(
    List<FitnessActivityModel> activities,
    String periodKey,
    String periodType,
  ) {
    if (activities.isEmpty) {
      return FitnessStatsModel(
        periodKey: periodKey,
        periodType: periodType,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    double totalDistance = 0;
    int totalDuration = 0;
    int totalCalories = 0;
    int longestMs = 0;
    final breakdown = <String, int>{};

    for (final a in activities) {
      totalDistance += a.distanceMeters;
      final dMs =
          a.durationMs > 0 ? a.durationMs : a.activeDuration.inMilliseconds;
      totalDuration += dMs;
      totalCalories += a.calories ?? 0;
      if (dMs > longestMs) longestMs = dMs;

      final typeKey = a.activityType.toJson();
      breakdown[typeKey] = (breakdown[typeKey] ?? 0) + 1;
    }

    // Average pace: total duration / total distance (seconds per km).
    double? avgPace;
    if (totalDistance > 0) {
      avgPace = (totalDuration / 1000) / (totalDistance / 1000);
    }

    return FitnessStatsModel(
      periodKey: periodKey,
      periodType: periodType,
      totalActivities: activities.length,
      totalDistanceMeters: totalDistance,
      totalDurationMs: totalDuration,
      totalCalories: totalCalories,
      activityBreakdown: breakdown,
      longestActivityMs: longestMs,
      averagePaceSecondsPerKm: avgPace,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

class _GoalEvent {
  final String goalId;
  final String goalType;
  final double currentValue;
  final double targetValue;
  final bool completed;

  const _GoalEvent({
    required this.goalId,
    required this.goalType,
    required this.currentValue,
    required this.targetValue,
    required this.completed,
  });
}
