// lib/models/context_snapshot.dart
//
// Snapshot of the user's behavioural state, aggregated at rule-evaluation time
// from events_recent, streaks, dailySummaries, and profile/main.
//
// All fields default to safe zero-values so rules that reference missing data
// degrade gracefully rather than throwing.

import 'package:cloud_firestore/cloud_firestore.dart';

class ContextSnapshot {
  // ── From events_recent (today's window) ─────────────────────────────────
  final int tasksCompletedToday;
  final int tasksAbandonedToday;
  final int goodHabitsLoggedToday;
  final int badHabitSlipsToday;

  // ── From streaks collection ──────────────────────────────────────────────
  /// Largest `currentCount` across all active streaks.
  final int longestActiveStreak;

  /// Total number of streaks currently in `state == active`.
  final int activeStreakCount;

  // ── From dailySummaries/{today} ─────────────────────────────────────────
  /// Composite mission score 0–100 written by StreakService at day-close.
  /// 0 if today's summary hasn't been written yet (intra-day).
  final int missionScore;

  // ── From profile/main ───────────────────────────────────────────────────
  /// Derived user state: on_track | slipping | relapsing | recovering.
  final String userState;

  /// Timestamp of the last coach message sent to this user.
  final DateTime? lastCoachMessageAt;

  /// Remaining proactive messages allowed today (budget resets at midnight).
  final int notificationBudgetRemaining;

  /// Calendar days elapsed since `profile/main.lastActiveDate`.
  /// 0 = active today, 1 = missed yesterday, 7+ = ghost territory.
  final int daysSinceLastActive;

  const ContextSnapshot({
    this.tasksCompletedToday = 0,
    this.tasksAbandonedToday = 0,
    this.goodHabitsLoggedToday = 0,
    this.badHabitSlipsToday = 0,
    this.longestActiveStreak = 0,
    this.activeStreakCount = 0,
    this.missionScore = 0,
    this.userState = 'on_track',
    this.lastCoachMessageAt,
    this.notificationBudgetRemaining = 3,
    this.daysSinceLastActive = 0,
  });

  // ── Factory constructors ─────────────────────────────────────────────────

  factory ContextSnapshot.fromMap(Map<String, dynamic> map) {
    return ContextSnapshot(
      tasksCompletedToday: map['tasksCompletedToday'] as int? ?? 0,
      tasksAbandonedToday: map['tasksAbandonedToday'] as int? ?? 0,
      goodHabitsLoggedToday: map['goodHabitsLoggedToday'] as int? ?? 0,
      badHabitSlipsToday: map['badHabitSlipsToday'] as int? ?? 0,
      longestActiveStreak: map['longestActiveStreak'] as int? ?? 0,
      activeStreakCount: map['activeStreakCount'] as int? ?? 0,
      missionScore: map['missionScore'] as int? ?? 0,
      userState: map['userState'] as String? ?? 'on_track',
      lastCoachMessageAt: _asDateTime(map['lastCoachMessageAt']),
      notificationBudgetRemaining:
          map['notificationBudgetRemaining'] as int? ?? 3,
      daysSinceLastActive: map['daysSinceLastActive'] as int? ?? 0,
    );
  }

  // ── Serialisation ────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'tasksCompletedToday': tasksCompletedToday,
      'tasksAbandonedToday': tasksAbandonedToday,
      'goodHabitsLoggedToday': goodHabitsLoggedToday,
      'badHabitSlipsToday': badHabitSlipsToday,
      'longestActiveStreak': longestActiveStreak,
      'activeStreakCount': activeStreakCount,
      'missionScore': missionScore,
      'userState': userState,
      if (lastCoachMessageAt != null)
        'lastCoachMessageAt': lastCoachMessageAt!.toIso8601String(),
      'notificationBudgetRemaining': notificationBudgetRemaining,
      'daysSinceLastActive': daysSinceLastActive,
    };
  }

  // ── copyWith ─────────────────────────────────────────────────────────────

  ContextSnapshot copyWith({
    int? tasksCompletedToday,
    int? tasksAbandonedToday,
    int? goodHabitsLoggedToday,
    int? badHabitSlipsToday,
    int? longestActiveStreak,
    int? activeStreakCount,
    int? missionScore,
    String? userState,
    DateTime? lastCoachMessageAt,
    int? notificationBudgetRemaining,
    int? daysSinceLastActive,
  }) {
    return ContextSnapshot(
      tasksCompletedToday: tasksCompletedToday ?? this.tasksCompletedToday,
      tasksAbandonedToday: tasksAbandonedToday ?? this.tasksAbandonedToday,
      goodHabitsLoggedToday:
          goodHabitsLoggedToday ?? this.goodHabitsLoggedToday,
      badHabitSlipsToday: badHabitSlipsToday ?? this.badHabitSlipsToday,
      longestActiveStreak: longestActiveStreak ?? this.longestActiveStreak,
      activeStreakCount: activeStreakCount ?? this.activeStreakCount,
      missionScore: missionScore ?? this.missionScore,
      userState: userState ?? this.userState,
      lastCoachMessageAt: lastCoachMessageAt ?? this.lastCoachMessageAt,
      notificationBudgetRemaining:
          notificationBudgetRemaining ?? this.notificationBudgetRemaining,
      daysSinceLastActive: daysSinceLastActive ?? this.daysSinceLastActive,
    );
  }

  // ── Debug helpers ────────────────────────────────────────────────────────

  /// One-line summary used by the rule engine's evaluation log.
  String get debugSummary =>
      'state=$userState '
      'tasks(done=$tasksCompletedToday,abandoned=$tasksAbandonedToday) '
      'habits(good=$goodHabitsLoggedToday,slips=$badHabitSlipsToday) '
      'streak(longest=$longestActiveStreak,active=$activeStreakCount) '
      'mission=$missionScore '
      'ghost=${daysSinceLastActive}d '
      'budget=$notificationBudgetRemaining';

  // ── Private helpers ──────────────────────────────────────────────────────

  static DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
