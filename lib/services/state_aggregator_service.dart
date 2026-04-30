// lib/services/state_aggregator_service.dart
//
// Aggregates 4 Firestore collections into a single ContextSnapshot.
// Collections (all under /users/{uid}/):
//   events_recent   — today's events filtered by ts
//   streaks         — active streaks (state == active)
//   dailySummaries  — today's summary doc (written at day-close)
//   profile/main    — lastCoachMessageAt, budget, lastActiveDate

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/event_names.dart';
import '../models/context_snapshot.dart';
import '../models/streak_model.dart';

class StateAggregatorService {
  final FirebaseFirestore _firestore;

  StateAggregatorService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<ContextSnapshot> buildSnapshot(String uid) async {
    final now = DateTime.now();
    final todayStr = _dateString(now);
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    debugPrint('[StateAggregator] Building snapshot uid=$uid date=$todayStr');

    final userRef = _firestore.collection('users').doc(uid);

    // ── Parallel reads ───────────────────────────────────────────────────────
    final results = await Future.wait([
      // [0] events_recent — today's window
      userRef
          .collection('events_recent')
          .where('ts', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('ts', isLessThan: Timestamp.fromDate(tomorrowStart))
          .get(),
      // [1] streaks — active only
      userRef
          .collection('streaks')
          .where('state', isEqualTo: StreakState.active.name)
          .get(),
      // [2] dailySummaries — today's doc
      userRef
          .collection('dailySummaries')
          .where('date', isEqualTo: todayStr)
          .limit(1)
          .get(),
      // [3] profile/main
      userRef.collection('profile').doc('main').get(),
    ]);

    final eventsSnap = results[0] as QuerySnapshot<Map<String, dynamic>>;
    final streaksSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final summariesSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;
    final profileSnap = results[3] as DocumentSnapshot<Map<String, dynamic>>;

    debugPrint('[StateAggregator] events_recent: ${eventsSnap.size} doc(s)');
    debugPrint('[StateAggregator] streaks(active): ${streaksSnap.size} doc(s)');
    debugPrint('[StateAggregator] dailySummaries: ${summariesSnap.size} doc(s) for $todayStr');
    debugPrint('[StateAggregator] profile/main exists=${profileSnap.exists}');

    // ── events_recent ────────────────────────────────────────────────────────
    int tasksCompletedToday = 0;
    int tasksAbandonedToday = 0;
    int goodHabitsLoggedToday = 0;
    int badHabitSlipsToday = 0;

    for (final doc in eventsSnap.docs) {
      switch (doc.data()['eventName'] as String? ?? '') {
        case EventNames.taskCompleted:
          tasksCompletedToday++;
          break;
        case EventNames.taskAbandoned:
          tasksAbandonedToday++;
          break;
        case EventNames.goodHabitLogged:
          goodHabitsLoggedToday++;
          break;
        case EventNames.badHabitSlipLogged:
          badHabitSlipsToday++;
          break;
      }
    }

    // ── streaks ──────────────────────────────────────────────────────────────
    final int activeStreakCount = streaksSnap.size;
    int longestActiveStreak = 0;
    for (final doc in streaksSnap.docs) {
      final streak = Streak.fromFirestore(doc);
      if (streak.currentCount > longestActiveStreak) {
        longestActiveStreak = streak.currentCount;
      }
    }

    // ── dailySummaries ───────────────────────────────────────────────────────
    int missionScore = 0;
    String? summaryUserState;

    if (summariesSnap.docs.isNotEmpty) {
      final d = summariesSnap.docs.first.data();
      missionScore = d['missionScore'] as int? ?? 0;
      summaryUserState = d['userState'] as String?;
      debugPrint('[StateAggregator] dailySummaries → missionScore=$missionScore userState=$summaryUserState');
    } else {
      debugPrint('[StateAggregator] dailySummaries → no doc yet (intra-day)');
    }

    // ── profile/main ─────────────────────────────────────────────────────────
    DateTime? lastCoachMessageAt;
    int notificationBudgetRemaining = 3;
    int daysSinceLastActive = 0;

    if (profileSnap.exists) {
      final d = profileSnap.data()!;

      final rawCoachTs = d['lastCoachMessageAt'];
      if (rawCoachTs is Timestamp) {
        lastCoachMessageAt = rawCoachTs.toDate();
      } else if (rawCoachTs is String) {
        lastCoachMessageAt = DateTime.tryParse(rawCoachTs);
      }

      notificationBudgetRemaining = d['notificationBudgetRemaining'] as int? ?? 3;

      final rawActive = d['lastActiveDate'];
      DateTime? lastActive;
      if (rawActive is Timestamp) {
        lastActive = rawActive.toDate();
      } else if (rawActive is String) {
        lastActive = DateTime.tryParse(rawActive);
      }
      if (lastActive != null) {
        final lastActiveDay =
            DateTime(lastActive.year, lastActive.month, lastActive.day);
        daysSinceLastActive =
            todayStart.difference(lastActiveDay).inDays.clamp(0, 9999);
      }

      debugPrint('[StateAggregator] profile/main → '
          'budget=$notificationBudgetRemaining '
          'daysSinceLastActive=$daysSinceLastActive');
    }

    // ── userState ────────────────────────────────────────────────────────────
    // Prefer the persisted state from dailySummaries (post day-close); derive
    // live from events when no summary exists yet (intra-day).
    final userState = summaryUserState ??
        _deriveUserState(
          tasksCompletedToday: tasksCompletedToday,
          tasksAbandonedToday: tasksAbandonedToday,
          goodHabitsLoggedToday: goodHabitsLoggedToday,
          badHabitSlipsToday: badHabitSlipsToday,
          longestActiveStreak: longestActiveStreak,
        );

    final snapshot = ContextSnapshot(
      tasksCompletedToday: tasksCompletedToday,
      tasksAbandonedToday: tasksAbandonedToday,
      goodHabitsLoggedToday: goodHabitsLoggedToday,
      badHabitSlipsToday: badHabitSlipsToday,
      longestActiveStreak: longestActiveStreak,
      activeStreakCount: activeStreakCount,
      missionScore: missionScore,
      userState: userState,
      lastCoachMessageAt: lastCoachMessageAt,
      notificationBudgetRemaining: notificationBudgetRemaining,
      daysSinceLastActive: daysSinceLastActive,
    );

    debugPrint('[StateAggregator] Snapshot ready: ${snapshot.debugSummary}');
    return snapshot;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _deriveUserState({
    required int tasksCompletedToday,
    required int tasksAbandonedToday,
    required int goodHabitsLoggedToday,
    required int badHabitSlipsToday,
    required int longestActiveStreak,
  }) {
    final positive = tasksCompletedToday +
        goodHabitsLoggedToday +
        (longestActiveStreak > 0 ? 1 : 0);
    final negative = badHabitSlipsToday + tasksAbandonedToday;

    if (badHabitSlipsToday >= 3 && positive == 0) return 'relapsing';
    if (negative > 0 && positive > 0) return 'recovering';
    if (negative > 0) return 'slipping';
    return 'on_track';
  }

  static String _dateString(DateTime dt) =>
      '${dt.year}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}
