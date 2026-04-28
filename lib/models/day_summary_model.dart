// lib/models/day_summary_model.dart
//
// Day summary per DB Schema §1A.5.
// Stored at: users/{uid}/days/{YYYY-MM-DD}/summary
// Written once by the day-close Cloud Function / RoutineService.

import 'package:cloud_firestore/cloud_firestore.dart';

class DaySummary {
  final String date; // "YYYY-MM-DD", also used as doc ID
  final int missionScore; // 0-100
  final int habitsCompleted;
  final int habitsBadLogged;
  final int tasksCompleted;
  final int tasksAbandoned;
  final int routinesCompleted;
  final int routinesMissed;
  final int streaksActive;
  final List<String> streaksMilestonesHit;
  final int screenTimeMinutes;
  final int addictionsLoggedCount;
  final int stressMarkersCount;
  final String userState; // on_track | slipping | relapsing | recovering
  final DateTime computedAt;
  final int schemaVersion;

  const DaySummary({
    required this.date,
    this.missionScore = 0,
    this.habitsCompleted = 0,
    this.habitsBadLogged = 0,
    this.tasksCompleted = 0,
    this.tasksAbandoned = 0,
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
  });

  factory DaySummary.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return DaySummary(
      date: data['date'] as String? ?? doc.id,
      missionScore: data['missionScore'] as int? ?? 0,
      habitsCompleted: data['habitsCompleted'] as int? ?? 0,
      habitsBadLogged: data['habitsBadLogged'] as int? ?? 0,
      tasksCompleted: data['tasksCompleted'] as int? ?? 0,
      tasksAbandoned: data['tasksAbandoned'] as int? ?? 0,
      routinesCompleted: data['routinesCompleted'] as int? ?? 0,
      routinesMissed: data['routinesMissed'] as int? ?? 0,
      streaksActive: data['streaksActive'] as int? ?? 0,
      streaksMilestonesHit: List<String>.from(
          data['streaksMilestonesHit'] as List? ?? []),
      screenTimeMinutes: data['screenTimeMinutes'] as int? ?? 0,
      addictionsLoggedCount: data['addictionsLoggedCount'] as int? ?? 0,
      stressMarkersCount: data['stressMarkersCount'] as int? ?? 0,
      userState: data['userState'] as String? ?? 'on_track',
      computedAt: data['computedAt'] != null
          ? (data['computedAt'] as Timestamp).toDate()
          : DateTime.now(),
      schemaVersion: data['schemaVersion'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': date,
      'missionScore': missionScore,
      'habitsCompleted': habitsCompleted,
      'habitsBadLogged': habitsBadLogged,
      'tasksCompleted': tasksCompleted,
      'tasksAbandoned': tasksAbandoned,
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
    };
  }
}
