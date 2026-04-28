// lib/models/streak_model.dart
//
// Streak record per ServiceContracts §4.3 and DB Schema §1A.5.
// One streak doc per habit — lives at users/{uid}/streaks/{habitId}.
// Written by day-close rollup, read by UI.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Streak lifecycle states.
enum StreakState {
  /// Brand new — habit was just created, no day-close has run yet.
  fresh,

  /// Actively counting consecutive days.
  active,

  /// User went ghost (3+ days no app open); streak preserved but frozen.
  paused,

  /// Streak was broken (missed target on day-close).
  broken;

  static StreakState fromString(String value) {
    switch (value) {
      case 'active':
        return StreakState.active;
      case 'paused':
        return StreakState.paused;
      case 'broken':
        return StreakState.broken;
      case 'fresh':
      default:
        return StreakState.fresh;
    }
  }
}

class Streak {
  final String habitId;
  final int currentCount;
  final int longestCount;
  final String? lastHitDate; // "YYYY-MM-DD"
  final String? lastBreakDate; // "YYYY-MM-DD"
  final StreakState state;
  final DateTime? pausedAt;
  final int? prePauseCount;
  final Map<String, int> weeklySkipsUsed; // "YYYY-Wxx": count
  final DateTime updatedAt;
  final int schemaVersion;

  const Streak({
    required this.habitId,
    this.currentCount = 0,
    this.longestCount = 0,
    this.lastHitDate,
    this.lastBreakDate,
    this.state = StreakState.fresh,
    this.pausedAt,
    this.prePauseCount,
    this.weeklySkipsUsed = const {},
    required this.updatedAt,
    this.schemaVersion = 1,
  });

  /// Create a fresh streak for a newly created habit.
  factory Streak.initial(String habitId) {
    return Streak(
      habitId: habitId,
      currentCount: 0,
      longestCount: 0,
      state: StreakState.fresh,
      weeklySkipsUsed: const {},
      updatedAt: DateTime.now(),
    );
  }

  factory Streak.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Streak(
      habitId: data['habitId'] as String? ?? doc.id,
      currentCount: data['currentCount'] as int? ?? 0,
      longestCount: data['longestCount'] as int? ?? 0,
      lastHitDate: data['lastHitDate'] as String?,
      lastBreakDate: data['lastBreakDate'] as String?,
      state: StreakState.fromString(data['state'] as String? ?? 'fresh'),
      pausedAt: data['pausedAt'] != null
          ? (data['pausedAt'] as Timestamp).toDate()
          : null,
      prePauseCount: data['prePauseCount'] as int?,
      weeklySkipsUsed: Map<String, int>.from(
          data['weeklySkipsUsed'] as Map? ?? {}),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      schemaVersion: data['schemaVersion'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'habitId': habitId,
      'currentCount': currentCount,
      'longestCount': longestCount,
      'lastHitDate': lastHitDate,
      'lastBreakDate': lastBreakDate,
      'state': state.name,
      if (pausedAt != null) 'pausedAt': Timestamp.fromDate(pausedAt!),
      if (prePauseCount != null) 'prePauseCount': prePauseCount,
      'weeklySkipsUsed': weeklySkipsUsed,
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': schemaVersion,
    };
  }

  Streak copyWith({
    int? currentCount,
    int? longestCount,
    String? lastHitDate,
    String? lastBreakDate,
    StreakState? state,
    DateTime? pausedAt,
    int? prePauseCount,
    Map<String, int>? weeklySkipsUsed,
    DateTime? updatedAt,
  }) {
    return Streak(
      habitId: habitId,
      currentCount: currentCount ?? this.currentCount,
      longestCount: longestCount ?? this.longestCount,
      lastHitDate: lastHitDate ?? this.lastHitDate,
      lastBreakDate: lastBreakDate ?? this.lastBreakDate,
      state: state ?? this.state,
      pausedAt: pausedAt ?? this.pausedAt,
      prePauseCount: prePauseCount ?? this.prePauseCount,
      weeklySkipsUsed: weeklySkipsUsed ?? this.weeklySkipsUsed,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion,
    );
  }
}
