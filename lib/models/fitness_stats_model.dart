// lib/models/fitness_stats_model.dart
//
// Aggregated fitness stats stored at:
//   /users/{uid}/fitnessStats/{periodKey}
// periodKey examples: daily_2026-05-07, weekly_2026-W19, monthly_2026-05

import 'package:cloud_firestore/cloud_firestore.dart';

class FitnessStatsModel {
  final String periodKey;
  final String periodType; // 'daily', 'weekly', 'monthly'
  final int totalActivities;
  final double totalDistanceMeters;
  final int totalDurationMs;
  final int totalCalories;
  final Map<String, int> activityBreakdown; // e.g. {'running': 3, 'cycling': 1}
  final int longestActivityMs;
  final double? averagePaceSecondsPerKm;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FitnessStatsModel({
    required this.periodKey,
    this.periodType = 'daily',
    this.totalActivities = 0,
    this.totalDistanceMeters = 0,
    this.totalDurationMs = 0,
    this.totalCalories = 0,
    this.activityBreakdown = const {},
    this.longestActivityMs = 0,
    this.averagePaceSecondsPerKm,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FitnessStatsModel.fromMap(
    Map<String, dynamic> map, {
    String fallbackId = '',
  }) {
    return FitnessStatsModel(
      periodKey:
          map['periodKey'] as String? ?? map['id'] as String? ?? fallbackId,
      periodType: map['periodType'] as String? ?? 'daily',
      totalActivities: (map['totalActivities'] as num?)?.toInt() ?? 0,
      totalDistanceMeters:
          (map['totalDistanceMeters'] as num?)?.toDouble() ?? 0,
      totalDurationMs: (map['totalDurationMs'] as num?)?.toInt() ?? 0,
      totalCalories: (map['totalCalories'] as num?)?.toInt() ?? 0,
      activityBreakdown: _asIntMap(map['activityBreakdown']),
      longestActivityMs: (map['longestActivityMs'] as num?)?.toInt() ?? 0,
      averagePaceSecondsPerKm:
          (map['averagePaceSecondsPerKm'] as num?)?.toDouble(),
      createdAt: _asDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _asDateTime(map['updatedAt']) ?? DateTime.now(),
    );
  }

  factory FitnessStatsModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return FitnessStatsModel.fromMap(data, fallbackId: doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'periodKey': periodKey,
      'periodType': periodType,
      'totalActivities': totalActivities,
      'totalDistanceMeters': totalDistanceMeters,
      'totalDurationMs': totalDurationMs,
      'totalCalories': totalCalories,
      'activityBreakdown': activityBreakdown,
      'longestActivityMs': longestActivityMs,
      if (averagePaceSecondsPerKm != null)
        'averagePaceSecondsPerKm': averagePaceSecondsPerKm,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  FitnessStatsModel copyWith({
    String? periodKey,
    String? periodType,
    int? totalActivities,
    double? totalDistanceMeters,
    int? totalDurationMs,
    int? totalCalories,
    Map<String, int>? activityBreakdown,
    int? longestActivityMs,
    double? averagePaceSecondsPerKm,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FitnessStatsModel(
      periodKey: periodKey ?? this.periodKey,
      periodType: periodType ?? this.periodType,
      totalActivities: totalActivities ?? this.totalActivities,
      totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
      totalDurationMs: totalDurationMs ?? this.totalDurationMs,
      totalCalories: totalCalories ?? this.totalCalories,
      activityBreakdown: activityBreakdown ?? this.activityBreakdown,
      longestActivityMs: longestActivityMs ?? this.longestActivityMs,
      averagePaceSecondsPerKm:
          averagePaceSecondsPerKm ?? this.averagePaceSecondsPerKm,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

Map<String, int> _asIntMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      entry.key.toString(): (entry.value as num?)?.toInt() ?? 0,
  };
}

DateTime? _asDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
