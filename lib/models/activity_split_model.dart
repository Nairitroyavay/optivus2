// lib/models/activity_split_model.dart
//
// Per-km/mile split stored at:
//   /users/{uid}/fitnessActivities/{activityId}/splits/{splitId}

import 'package:cloud_firestore/cloud_firestore.dart';

class ActivitySplitModel {
  final String splitId;
  final int splitNumber;
  final double distanceMeters;
  final int durationMs;
  final double? paceSecondsPerKm;
  final double? elevationDelta;
  final int? averageHeartRate;
  final DateTime? startedAt;
  final DateTime? endedAt;

  const ActivitySplitModel({
    required this.splitId,
    required this.splitNumber,
    this.distanceMeters = 0,
    this.durationMs = 0,
    this.paceSecondsPerKm,
    this.elevationDelta,
    this.averageHeartRate,
    this.startedAt,
    this.endedAt,
  });

  factory ActivitySplitModel.fromMap(
    Map<String, dynamic> map, {
    String fallbackId = '',
  }) {
    return ActivitySplitModel(
      splitId: map['splitId'] as String? ?? map['id'] as String? ?? fallbackId,
      splitNumber: (map['splitNumber'] as num?)?.toInt() ?? 0,
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble() ?? 0,
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      paceSecondsPerKm: (map['paceSecondsPerKm'] as num?)?.toDouble(),
      elevationDelta: (map['elevationDelta'] as num?)?.toDouble(),
      averageHeartRate: (map['averageHeartRate'] as num?)?.toInt(),
      startedAt: _asDateTime(map['startedAt']),
      endedAt: _asDateTime(map['endedAt']),
    );
  }

  factory ActivitySplitModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return ActivitySplitModel.fromMap(data, fallbackId: doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'splitId': splitId,
      'splitNumber': splitNumber,
      'distanceMeters': distanceMeters,
      'durationMs': durationMs,
      if (paceSecondsPerKm != null) 'paceSecondsPerKm': paceSecondsPerKm,
      if (elevationDelta != null) 'elevationDelta': elevationDelta,
      if (averageHeartRate != null) 'averageHeartRate': averageHeartRate,
      if (startedAt != null) 'startedAt': Timestamp.fromDate(startedAt!),
      if (endedAt != null) 'endedAt': Timestamp.fromDate(endedAt!),
    };
  }

  ActivitySplitModel copyWith({
    String? splitId,
    int? splitNumber,
    double? distanceMeters,
    int? durationMs,
    double? paceSecondsPerKm,
    double? elevationDelta,
    int? averageHeartRate,
    DateTime? startedAt,
    DateTime? endedAt,
  }) {
    return ActivitySplitModel(
      splitId: splitId ?? this.splitId,
      splitNumber: splitNumber ?? this.splitNumber,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationMs: durationMs ?? this.durationMs,
      paceSecondsPerKm: paceSecondsPerKm ?? this.paceSecondsPerKm,
      elevationDelta: elevationDelta ?? this.elevationDelta,
      averageHeartRate: averageHeartRate ?? this.averageHeartRate,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }
}

DateTime? _asDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
