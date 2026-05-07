// lib/models/route_point_model.dart
//
// GPS route point stored at:
//   /users/{uid}/fitnessActivities/{activityId}/routePoints/{pointId}
// Phase 1 defines the model; Phase 2 writes points during live tracking.

import 'package:cloud_firestore/cloud_firestore.dart';

class RoutePointModel {
  final String pointId;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final double? speedMps;
  final int? heartRate;
  final DateTime timestamp;

  const RoutePointModel({
    required this.pointId,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.speedMps,
    this.heartRate,
    required this.timestamp,
  });

  factory RoutePointModel.fromMap(
    Map<String, dynamic> map, {
    String fallbackId = '',
  }) {
    return RoutePointModel(
      pointId: map['pointId'] as String? ?? map['id'] as String? ?? fallbackId,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      altitude: (map['altitude'] as num?)?.toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      speedMps: (map['speedMps'] as num?)?.toDouble(),
      heartRate: (map['heartRate'] as num?)?.toInt(),
      timestamp: _asDateTime(map['timestamp']) ?? DateTime.now(),
    );
  }

  factory RoutePointModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return RoutePointModel.fromMap(data, fallbackId: doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'pointId': pointId,
      'latitude': latitude,
      'longitude': longitude,
      if (altitude != null) 'altitude': altitude,
      if (accuracy != null) 'accuracy': accuracy,
      if (speedMps != null) 'speedMps': speedMps,
      if (heartRate != null) 'heartRate': heartRate,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  RoutePointModel copyWith({
    String? pointId,
    double? latitude,
    double? longitude,
    double? altitude,
    double? accuracy,
    double? speedMps,
    int? heartRate,
    DateTime? timestamp,
  }) {
    return RoutePointModel(
      pointId: pointId ?? this.pointId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      accuracy: accuracy ?? this.accuracy,
      speedMps: speedMps ?? this.speedMps,
      heartRate: heartRate ?? this.heartRate,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

DateTime? _asDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
