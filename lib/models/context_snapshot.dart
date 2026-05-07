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

  /// Daily limit on notifications and coach messages.
  final int dailyNotificationBudget;

  /// Count of notifications successfully sent or scheduled today.
  final int notificationsSentToday;

  /// Whether the user has suppressed notifications for the day.
  final bool quietDayMode;

  /// Remaining proactive messages allowed today (budget resets at midnight).
  int get notificationBudgetRemaining {
    final remaining = dailyNotificationBudget - notificationsSentToday;
    return remaining < 0 ? 0 : remaining;
  }

  /// Calendar days elapsed since `profile/main.lastActiveDate`.
  /// 0 = active today, 1 = missed yesterday, 7+ = ghost territory.
  final int daysSinceLastActive;

  // ── Fitness metrics (optional) ─────────────────────────────────────────
  final int fitnessActivitiesToday;
  final double fitnessDistanceToday;
  final int fitnessCaloriesToday;

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
    this.dailyNotificationBudget = 3,
    this.notificationsSentToday = 0,
    this.quietDayMode = false,
    this.daysSinceLastActive = 0,
    this.fitnessActivitiesToday = 0,
    this.fitnessDistanceToday = 0,
    this.fitnessCaloriesToday = 0,
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
      dailyNotificationBudget: map['dailyNotificationBudget'] as int? ?? 3,
      notificationsSentToday: map['notificationsSentToday'] as int? ?? 0,
      quietDayMode: map['quietDayMode'] as bool? ?? false,
      daysSinceLastActive: map['daysSinceLastActive'] as int? ?? 0,
      fitnessActivitiesToday: map['fitnessActivitiesToday'] as int? ?? 0,
      fitnessDistanceToday: (map['fitnessDistanceToday'] as num?)?.toDouble() ?? 0,
      fitnessCaloriesToday: map['fitnessCaloriesToday'] as int? ?? 0,
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
      'dailyNotificationBudget': dailyNotificationBudget,
      'notificationsSentToday': notificationsSentToday,
      'quietDayMode': quietDayMode,
      'daysSinceLastActive': daysSinceLastActive,
      'fitnessActivitiesToday': fitnessActivitiesToday,
      'fitnessDistanceToday': fitnessDistanceToday,
      'fitnessCaloriesToday': fitnessCaloriesToday,
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
    int? dailyNotificationBudget,
    int? notificationsSentToday,
    bool? quietDayMode,
    int? daysSinceLastActive,
    int? fitnessActivitiesToday,
    double? fitnessDistanceToday,
    int? fitnessCaloriesToday,
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
      dailyNotificationBudget:
          dailyNotificationBudget ?? this.dailyNotificationBudget,
      notificationsSentToday:
          notificationsSentToday ?? this.notificationsSentToday,
      quietDayMode: quietDayMode ?? this.quietDayMode,
      daysSinceLastActive: daysSinceLastActive ?? this.daysSinceLastActive,
      fitnessActivitiesToday: fitnessActivitiesToday ?? this.fitnessActivitiesToday,
      fitnessDistanceToday: fitnessDistanceToday ?? this.fitnessDistanceToday,
      fitnessCaloriesToday: fitnessCaloriesToday ?? this.fitnessCaloriesToday,
    );
  }

  // ── Debug helpers ────────────────────────────────────────────────────────

  /// One-line summary used by the rule engine's evaluation log.
  String get debugSummary => 'state=$userState '
      'tasks(done=$tasksCompletedToday,abandoned=$tasksAbandonedToday) '
      'habits(good=$goodHabitsLoggedToday,slips=$badHabitSlipsToday) '
      'streak(longest=$longestActiveStreak,active=$activeStreakCount) '
      'mission=$missionScore '
      'ghost=${daysSinceLastActive}d '
      'budget=$notificationsSentToday/$dailyNotificationBudget '
      'quiet=$quietDayMode '
      'fitness(acts=$fitnessActivitiesToday,dist=${fitnessDistanceToday.round()}m,cal=$fitnessCaloriesToday)';

  // ── Private helpers ──────────────────────────────────────────────────────

  static DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
