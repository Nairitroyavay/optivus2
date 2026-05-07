// lib/models/day_summary_model.dart
//
// Day summary per DB Schema §1A.5.
// Stored at: /users/{uid}/dailySummaries/{date}
// Written once per calendar day by RoutineService.runDayCloseIfNeeded.
// Populated with real metrics returned by StreakService.runDayCloseRollup.

import 'package:cloud_firestore/cloud_firestore.dart';

class DaySummary {
  final String date; // "YYYY-MM-DD", also used as doc ID
  final int missionScore; // 0-100
  final double missionPct; // 0.0-1.0, same value as missionScore / 100
  final double overallPct; // 0.0-1.0 weighted/equal routine completion
  final Map<String, double> perRoutinePct;
  final Map<String, int> slipCounts;
  final Map<String, double> identityProgress;
  final double identityAlignedCompletedValue;
  final double nonAlignedCompletedValue;
  final double maxPossibleValueToday;
  final int habitsCompleted;
  final int habitsBadLogged;
  final int tasksCompleted;
  final int tasksAbandoned;
  final int tasksSkipped;
  final int tasksScheduled;
  final int focusMinutes;
  final int routinesCompleted;
  final int routinesMissed;
  final int streaksActive;
  final List<String> streaksMilestonesHit; // "<habitId>:<milestone>" entries
  final int screenTimeMinutes;
  final int addictionsLoggedCount;
  final int stressMarkersCount;
  final String userState; // on_track | slipping | relapsing | recovering
  final DateTime computedAt;
  final int schemaVersion;

  // Fitness metrics (optional, added in Phase 3)
  final int fitnessActivitiesCompleted;
  final double fitnessDistanceMeters;
  final int fitnessCalories;
  final int fitnessDurationMs;

  const DaySummary({
    required this.date,
    this.missionScore = 0,
    double? missionPct,
    this.overallPct = 0,
    this.perRoutinePct = const {},
    this.slipCounts = const {},
    this.identityProgress = const {},
    this.identityAlignedCompletedValue = 0,
    this.nonAlignedCompletedValue = 0,
    this.maxPossibleValueToday = 0,
    this.habitsCompleted = 0,
    this.habitsBadLogged = 0,
    this.tasksCompleted = 0,
    this.tasksAbandoned = 0,
    this.tasksSkipped = 0,
    this.tasksScheduled = 0,
    this.focusMinutes = 0,
    this.routinesCompleted = 0,
    this.routinesMissed = 0,
    this.streaksActive = 0,
    this.streaksMilestonesHit = const [],
    this.screenTimeMinutes = 0,
    this.addictionsLoggedCount = 0,
    this.stressMarkersCount = 0,
    this.userState = 'on_track',
    required this.computedAt,
    this.schemaVersion = 1,
    this.fitnessActivitiesCompleted = 0,
    this.fitnessDistanceMeters = 0,
    this.fitnessCalories = 0,
    this.fitnessDurationMs = 0,
  }) : missionPct = missionPct ?? missionScore / 100;

  factory DaySummary.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final missionScore = _asInt(data['missionScore']);
    return DaySummary(
      date: data['date'] as String? ?? doc.id,
      missionScore: missionScore,
      missionPct: _asDouble(data['missionPct'], fallback: missionScore / 100),
      overallPct: _asDouble(data['overallPct']),
      perRoutinePct: _asDoubleMap(data['perRoutinePct']),
      slipCounts: _asIntMap(data['slipCounts']),
      identityProgress: _asDoubleMap(data['identityProgress']),
      identityAlignedCompletedValue:
          _asDouble(data['identityAlignedCompletedValue']),
      nonAlignedCompletedValue: _asDouble(data['nonAlignedCompletedValue']),
      maxPossibleValueToday: _asDouble(data['maxPossibleValueToday']),
      habitsCompleted: _asInt(data['habitsCompleted']),
      habitsBadLogged: _asInt(data['habitsBadLogged']),
      tasksCompleted: _asInt(data['tasksCompleted']),
      tasksAbandoned: _asInt(data['tasksAbandoned']),
      tasksSkipped: _asInt(data['tasksSkipped']),
      tasksScheduled: _asInt(data['tasksScheduled']),
      focusMinutes: _asInt(data['focusMinutes']),
      routinesCompleted: _asInt(data['routinesCompleted']),
      routinesMissed: _asInt(data['routinesMissed']),
      streaksActive: _asInt(data['streaksActive']),
      streaksMilestonesHit:
          List<String>.from(data['streaksMilestonesHit'] as List? ?? []),
      screenTimeMinutes: _asInt(data['screenTimeMinutes']),
      addictionsLoggedCount: _asInt(data['addictionsLoggedCount']),
      stressMarkersCount: _asInt(data['stressMarkersCount']),
      userState: data['userState'] as String? ?? 'on_track',
      computedAt: data['computedAt'] != null
          ? (data['computedAt'] as Timestamp).toDate()
          : DateTime.now(),
      schemaVersion: data['schemaVersion'] as int? ?? 1,
      fitnessActivitiesCompleted: _asInt(data['fitnessActivitiesCompleted']),
      fitnessDistanceMeters: _asDouble(data['fitnessDistanceMeters']),
      fitnessCalories: _asInt(data['fitnessCalories']),
      fitnessDurationMs: _asInt(data['fitnessDurationMs']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': date,
      'missionScore': missionScore,
      'missionPct': missionPct,
      'overallPct': overallPct,
      'perRoutinePct': perRoutinePct,
      'slipCounts': slipCounts,
      'identityProgress': identityProgress,
      'identityAlignedCompletedValue': identityAlignedCompletedValue,
      'nonAlignedCompletedValue': nonAlignedCompletedValue,
      'maxPossibleValueToday': maxPossibleValueToday,
      'habitsCompleted': habitsCompleted,
      'habitsBadLogged': habitsBadLogged,
      'tasksCompleted': tasksCompleted,
      'tasksAbandoned': tasksAbandoned,
      'tasksSkipped': tasksSkipped,
      'tasksScheduled': tasksScheduled,
      'focusMinutes': focusMinutes,
      'routinesCompleted': routinesCompleted,
      'routinesMissed': routinesMissed,
      'streaksActive': streaksActive,
      'streaksMilestonesHit': streaksMilestonesHit,
      'screenTimeMinutes': screenTimeMinutes,
      'addictionsLoggedCount': addictionsLoggedCount,
      'stressMarkersCount': stressMarkersCount,
      'userState': userState,
      'computedAt': FieldValue.serverTimestamp(),
      'schemaVersion': schemaVersion,
      'fitnessActivitiesCompleted': fitnessActivitiesCompleted,
      'fitnessDistanceMeters': fitnessDistanceMeters,
      'fitnessCalories': fitnessCalories,
      'fitnessDurationMs': fitnessDurationMs,
    };
  }
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return fallback;
}

double _asDouble(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return fallback;
}

Map<String, double> _asDoubleMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      entry.key.toString(): _asDouble(entry.value),
  };
}

Map<String, int> _asIntMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      entry.key.toString(): _asInt(entry.value),
  };
}
