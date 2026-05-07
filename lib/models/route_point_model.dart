// lib/models/route_point_model.dart
//
// GPS route point stored at:
//   /users/{uid}/fitnessActivities/{activityId}/routePoints/{pointId}
// Phase 1 defines the model; Phase 2 writes points during live tracking.

import 'package:cloud_firestore/cloud_firestore.dart';

class RoutePointModel {
  final String pointId;
  final String activityId;
  final String uid;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final double? speedMps;
  final double? heading;
  final int? heartRate;
  final int sequence;
  final bool isPausePoint;
  final DateTime timestamp;
  final DateTime createdAt;

  const RoutePointModel({
    required this.pointId,
    this.activityId = '',
    this.uid = '',
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.speedMps,
    this.heading,
    this.heartRate,
    this.sequence = 0,
    this.isPausePoint = false,
    required this.timestamp,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? timestamp;

  factory RoutePointModel.fromMap(
    Map<String, dynamic> map, {
    String fallbackId = '',
  }) {
    return RoutePointModel(
      pointId: map['pointId'] as String? ?? map['id'] as String? ?? fallbackId,
      activityId: map['activityId'] as String? ?? '',
      uid: map['uid'] as String? ?? '',
      latitude: (map['lat'] as num?)?.toDouble() ??
          (map['latitude'] as num?)?.toDouble() ??
          0,
      longitude: (map['lng'] as num?)?.toDouble() ??
          (map['longitude'] as num?)?.toDouble() ??
          0,
      altitude: (map['altitudeMeters'] as num?)?.toDouble() ??
          (map['altitude'] as num?)?.toDouble(),
      accuracy: (map['accuracyMeters'] as num?)?.toDouble() ??
          (map['accuracy'] as num?)?.toDouble(),
      speedMps: (map['speedMps'] as num?)?.toDouble(),
      heading: (map['heading'] as num?)?.toDouble(),
      heartRate: (map['heartRate'] as num?)?.toInt(),
      sequence: (map['sequence'] as num?)?.toInt() ?? 0,
      isPausePoint: map['isPausePoint'] as bool? ?? false,
      timestamp: _asDateTime(map['recordedAt']) ??
          _asDateTime(map['timestamp']) ??
          DateTime.now(),
      createdAt: _asDateTime(map['createdAt']),
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
      'activityId': activityId,
      if (uid.isNotEmpty) 'uid': uid,
      'lat': latitude,
      'lng': longitude,
      'latitude': latitude,
      'longitude': longitude,
      if (altitude != null) 'altitudeMeters': altitude,
      if (altitude != null) 'altitude': altitude,
      if (accuracy != null) 'accuracyMeters': accuracy,
      if (accuracy != null) 'accuracy': accuracy,
      if (speedMps != null) 'speedMps': speedMps,
      if (heading != null) 'heading': heading,
      if (heartRate != null) 'heartRate': heartRate,
      'sequence': sequence,
      'isPausePoint': isPausePoint,
      'recordedAt': Timestamp.fromDate(timestamp),
      'timestamp': Timestamp.fromDate(timestamp),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  RoutePointModel copyWith({
    String? pointId,
    String? activityId,
    String? uid,
    double? latitude,
    double? longitude,
    double? altitude,
    double? accuracy,
    double? speedMps,
    double? heading,
    int? heartRate,
    int? sequence,
    bool? isPausePoint,
    DateTime? timestamp,
    DateTime? createdAt,
  }) {
    return RoutePointModel(
      pointId: pointId ?? this.pointId,
      activityId: activityId ?? this.activityId,
      uid: uid ?? this.uid,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      accuracy: accuracy ?? this.accuracy,
      speedMps: speedMps ?? this.speedMps,
      heading: heading ?? this.heading,
      heartRate: heartRate ?? this.heartRate,
      sequence: sequence ?? this.sequence,
      isPausePoint: isPausePoint ?? this.isPausePoint,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

DateTime? _asDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
