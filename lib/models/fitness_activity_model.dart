// lib/models/fitness_activity_model.dart
//
// Core fitness activity model stored at: /users/{uid}/fitnessActivities/{activityId}
// Phase 1 foundation — records activity metadata and summary metrics.

import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Activity Type
// ─────────────────────────────────────────────────────────────────────────────

enum FitnessActivityType {
  running,
  walking,
  cycling,
  hiking,
  swimming,
  gymWorkout,
  custom;

  /// Safe deserialization — unknown strings fall back to [custom].
  static FitnessActivityType fromString(String? value) {
    switch (value) {
      case 'running':
      case 'run':
        return FitnessActivityType.running;
      case 'walking':
      case 'walk':
        return FitnessActivityType.walking;
      case 'cycling':
      case 'cycle':
        return FitnessActivityType.cycling;
      case 'hiking':
      case 'hike':
        return FitnessActivityType.hiking;
      case 'swimming':
      case 'swim':
        return FitnessActivityType.swimming;
      case 'gym':
      case 'workout':
      case 'gym_workout':
      case 'gymWorkout':
        return FitnessActivityType.gymWorkout;
      default:
        return FitnessActivityType.custom;
    }
  }

  String toJson() {
    switch (this) {
      case FitnessActivityType.running:
        return 'running';
      case FitnessActivityType.walking:
        return 'walking';
      case FitnessActivityType.cycling:
        return 'cycling';
      case FitnessActivityType.hiking:
        return 'hiking';
      case FitnessActivityType.swimming:
        return 'swimming';
      case FitnessActivityType.gymWorkout:
        return 'gym_workout';
      case FitnessActivityType.custom:
        return 'custom';
    }
  }

  String get displayName {
    switch (this) {
      case FitnessActivityType.running:
        return 'Run';
      case FitnessActivityType.walking:
        return 'Walk';
      case FitnessActivityType.cycling:
        return 'Cycle';
      case FitnessActivityType.hiking:
        return 'Hike';
      case FitnessActivityType.swimming:
        return 'Swim';
      case FitnessActivityType.gymWorkout:
        return 'Gym';
      case FitnessActivityType.custom:
        return 'Custom';
    }
  }

  String get emoji {
    switch (this) {
      case FitnessActivityType.running:
        return '🏃';
      case FitnessActivityType.walking:
        return '🚶';
      case FitnessActivityType.cycling:
        return '🚴';
      case FitnessActivityType.hiking:
        return '🥾';
      case FitnessActivityType.swimming:
        return '🏊';
      case FitnessActivityType.gymWorkout:
        return '🏋️';
      case FitnessActivityType.custom:
        return '⚡';
    }
  }

  /// Whether this activity type uses GPS tracking.
  bool get isGpsActivity {
    switch (this) {
      case FitnessActivityType.running:
      case FitnessActivityType.walking:
      case FitnessActivityType.cycling:
      case FitnessActivityType.hiking:
        return true;
      case FitnessActivityType.swimming:
      case FitnessActivityType.gymWorkout:
      case FitnessActivityType.custom:
        return false;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity Status
// ─────────────────────────────────────────────────────────────────────────────

enum FitnessActivityStatus {
  pending,
  active,
  paused,
  completed,
  discarded,
  cancelled;

  static FitnessActivityStatus fromString(String? value) {
    switch (value) {
      case 'active':
        return FitnessActivityStatus.active;
      case 'paused':
        return FitnessActivityStatus.paused;
      case 'completed':
        return FitnessActivityStatus.completed;
      case 'discarded':
        return FitnessActivityStatus.discarded;
      case 'cancelled':
        return FitnessActivityStatus.cancelled;
      default:
        return FitnessActivityStatus.pending;
    }
  }

  String toJson() => name;
}

enum FitnessSyncStatus {
  synced,
  pending,
  failed;

  static FitnessSyncStatus fromString(String? value) {
    switch (value) {
      case 'pending':
        return FitnessSyncStatus.pending;
      case 'failed':
        return FitnessSyncStatus.failed;
      default:
        return FitnessSyncStatus.synced;
    }
  }

  String toJson() => name;
}

// ─────────────────────────────────────────────────────────────────────────────
// Fitness Activity Model
// ─────────────────────────────────────────────────────────────────────────────

class FitnessActivityModel {
  final String activityId;
  final FitnessActivityType activityType;
  final FitnessActivityStatus status;
  final String title;
  final String notes;

  // Timing
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final int movingTimeSeconds;
  final int pausedSeconds;
  final int pausedDurationMs;

  // Distance & speed
  final double distanceMeters;
  final double elevationGainMeters;
  final double? averagePaceSecondsPerKm;
  final double? currentPaceSecondsPerKm;
  final double? averageSpeedKmh;
  final double? maxSpeedKmh;

  // Calories & heart rate
  final int? calories;
  final int? averageHeartRate;
  final int? maxHeartRate;

  // Goals / targets set before start
  final double? goalDistanceMeters;
  final int? goalDurationMinutes;
  final int? goalCalories;

  // GPS flag
  final bool isGpsActivity;
  final bool hasRoute;
  final int routePointCount;
  final double? startLat;
  final double? startLng;
  final double? endLat;
  final double? endLng;
  final double? minLat;
  final double? minLng;
  final double? maxLat;
  final double? maxLng;
  final String? encodedPolyline;
  final FitnessSyncStatus syncStatus;

  // Swimming-specific
  final bool isPoolSwimming;
  final int? poolLengthMeters;
  final int? lapCount;

  // Gym/workout-specific
  final String workoutCategory;
  final String aiFeedback;

  // Routine integration
  final String? routineTaskId;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  const FitnessActivityModel({
    required this.activityId,
    required this.activityType,
    this.status = FitnessActivityStatus.pending,
    this.title = '',
    this.notes = '',
    this.startedAt,
    this.endedAt,
    this.durationSeconds = 0,
    this.movingTimeSeconds = 0,
    this.pausedSeconds = 0,
    this.pausedDurationMs = 0,
    this.distanceMeters = 0,
    this.elevationGainMeters = 0,
    this.averagePaceSecondsPerKm,
    this.currentPaceSecondsPerKm,
    this.averageSpeedKmh,
    this.maxSpeedKmh,
    this.calories,
    this.averageHeartRate,
    this.maxHeartRate,
    this.goalDistanceMeters,
    this.goalDurationMinutes,
    this.goalCalories,
    this.isGpsActivity = false,
    this.hasRoute = false,
    this.routePointCount = 0,
    this.startLat,
    this.startLng,
    this.endLat,
    this.endLng,
    this.minLat,
    this.minLng,
    this.maxLat,
    this.maxLng,
    this.encodedPolyline,
    this.syncStatus = FitnessSyncStatus.synced,
    this.isPoolSwimming = false,
    this.poolLengthMeters,
    this.lapCount,
    this.workoutCategory = '',
    this.aiFeedback = '',
    this.routineTaskId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FitnessActivityModel.fromMap(
    Map<String, dynamic> map, {
    String fallbackId = '',
  }) {
    final type = FitnessActivityType.fromString(
      map['type'] as String? ?? map['activityType'] as String?,
    );
    return FitnessActivityModel(
      activityId:
          map['activityId'] as String? ?? map['id'] as String? ?? fallbackId,
      activityType: type,
      status: FitnessActivityStatus.fromString(map['status'] as String?),
      title: map['title'] as String? ?? '',
      notes: map['note'] as String? ?? map['notes'] as String? ?? '',
      startedAt: _asDateTime(map['startedAt']),
      endedAt: _asDateTime(map['endedAt']),
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      movingTimeSeconds: (map['movingTimeSeconds'] as num?)?.toInt() ?? 0,
      pausedSeconds: (map['pausedSeconds'] as num?)?.toInt() ?? 0,
      pausedDurationMs: (map['pausedDurationMs'] as num?)?.toInt() ??
          ((map['pausedSeconds'] as num?)?.toInt() ?? 0) * 1000,
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble() ?? 0,
      elevationGainMeters:
          (map['elevationGainMeters'] as num?)?.toDouble() ?? 0,
      averagePaceSecondsPerKm:
          (map['averagePaceSecondsPerKm'] as num?)?.toDouble(),
      currentPaceSecondsPerKm:
          (map['currentPaceSecondsPerKm'] as num?)?.toDouble(),
      averageSpeedKmh: (map['averageSpeedKmh'] as num?)?.toDouble() ??
          ((map['averageSpeedMps'] as num?)?.toDouble() == null
              ? null
              : (map['averageSpeedMps'] as num).toDouble() * 3.6),
      maxSpeedKmh: (map['maxSpeedKmh'] as num?)?.toDouble() ??
          ((map['maxSpeedMps'] as num?)?.toDouble() == null
              ? null
              : (map['maxSpeedMps'] as num).toDouble() * 3.6),
      calories: (map['calories'] as num?)?.toInt() ??
          (map['caloriesEstimate'] as num?)?.toInt(),
      averageHeartRate: (map['averageHeartRate'] as num?)?.toInt(),
      maxHeartRate: (map['maxHeartRate'] as num?)?.toInt(),
      goalDistanceMeters: (map['goalDistanceMeters'] as num?)?.toDouble(),
      goalDurationMinutes: (map['goalDurationMinutes'] as num?)?.toInt(),
      goalCalories: (map['goalCalories'] as num?)?.toInt(),
      isGpsActivity: map['isGpsActivity'] as bool? ?? type.isGpsActivity,
      hasRoute: map['hasRoute'] as bool? ?? false,
      routePointCount: (map['routePointCount'] as num?)?.toInt() ?? 0,
      startLat: (map['startLat'] as num?)?.toDouble(),
      startLng: (map['startLng'] as num?)?.toDouble(),
      endLat: (map['endLat'] as num?)?.toDouble(),
      endLng: (map['endLng'] as num?)?.toDouble(),
      minLat: (map['minLat'] as num?)?.toDouble(),
      minLng: (map['minLng'] as num?)?.toDouble(),
      maxLat: (map['maxLat'] as num?)?.toDouble(),
      maxLng: (map['maxLng'] as num?)?.toDouble(),
      encodedPolyline: map['encodedPolyline'] as String?,
      syncStatus: FitnessSyncStatus.fromString(map['syncStatus'] as String?),
      isPoolSwimming: map['isPoolSwimming'] as bool? ?? false,
      poolLengthMeters: (map['poolLengthMeters'] as num?)?.toInt(),
      lapCount: (map['lapCount'] as num?)?.toInt(),
      workoutCategory: map['workoutCategory'] as String? ?? '',
      aiFeedback: map['aiFeedback'] as String? ?? '',
      routineTaskId: map['routineTaskId'] as String?,
      createdAt: _asDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _asDateTime(map['updatedAt']) ?? DateTime.now(),
    );
  }

  factory FitnessActivityModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return FitnessActivityModel.fromMap(data, fallbackId: doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'activityId': activityId,
      'type': activityType.toJson(),
      'activityType': activityType.toJson(),
      'status': status.toJson(),
      'title': title,
      'note': notes,
      'notes': notes,
      if (startedAt != null) 'startedAt': Timestamp.fromDate(startedAt!),
      if (endedAt != null) 'endedAt': Timestamp.fromDate(endedAt!),
      'durationSeconds': durationSeconds,
      'movingTimeSeconds': movingTimeSeconds,
      'pausedDurationMs': pausedDurationMs,
      'pausedSeconds':
          pausedSeconds > 0 ? pausedSeconds : pausedDurationMs ~/ 1000,
      'distanceMeters': distanceMeters,
      'elevationGainMeters': elevationGainMeters,
      if (averagePaceSecondsPerKm != null)
        'averagePaceSecondsPerKm': averagePaceSecondsPerKm,
      if (currentPaceSecondsPerKm != null)
        'currentPaceSecondsPerKm': currentPaceSecondsPerKm,
      if (averageSpeedKmh != null) 'averageSpeedKmh': averageSpeedKmh,
      if (averageSpeedKmh != null) 'averageSpeedMps': averageSpeedKmh! / 3.6,
      if (maxSpeedKmh != null) 'maxSpeedKmh': maxSpeedKmh,
      if (maxSpeedKmh != null) 'maxSpeedMps': maxSpeedKmh! / 3.6,
      if (calories != null) 'calories': calories,
      if (calories != null) 'caloriesEstimate': calories,
      if (averageHeartRate != null) 'averageHeartRate': averageHeartRate,
      if (maxHeartRate != null) 'maxHeartRate': maxHeartRate,
      if (goalDistanceMeters != null) 'goalDistanceMeters': goalDistanceMeters,
      if (goalDurationMinutes != null)
        'goalDurationMinutes': goalDurationMinutes,
      if (goalCalories != null) 'goalCalories': goalCalories,
      'isGpsActivity': isGpsActivity,
      'hasRoute': hasRoute,
      'routePointCount': routePointCount,
      if (encodedPolyline != null) 'encodedPolyline': encodedPolyline,
      if (startLat != null) 'startLat': startLat,
      if (startLng != null) 'startLng': startLng,
      if (endLat != null) 'endLat': endLat,
      if (endLng != null) 'endLng': endLng,
      if (minLat != null) 'minLat': minLat,
      if (minLng != null) 'minLng': minLng,
      if (maxLat != null) 'maxLat': maxLat,
      if (maxLng != null) 'maxLng': maxLng,
      'syncStatus': syncStatus.toJson(),
      'isPoolSwimming': isPoolSwimming,
      if (poolLengthMeters != null) 'poolLengthMeters': poolLengthMeters,
      if (lapCount != null) 'lapCount': lapCount,
      if (workoutCategory.isNotEmpty) 'workoutCategory': workoutCategory,
      if (aiFeedback.isNotEmpty) 'aiFeedback': aiFeedback,
      if (routineTaskId != null) 'routineTaskId': routineTaskId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  FitnessActivityModel copyWith({
    String? activityId,
    FitnessActivityType? activityType,
    FitnessActivityStatus? status,
    String? title,
    String? notes,
    DateTime? startedAt,
    bool clearStartedAt = false,
    DateTime? endedAt,
    bool clearEndedAt = false,
    int? durationSeconds,
    int? movingTimeSeconds,
    int? pausedSeconds,
    int? pausedDurationMs,
    double? distanceMeters,
    double? elevationGainMeters,
    double? averagePaceSecondsPerKm,
    double? currentPaceSecondsPerKm,
    double? averageSpeedKmh,
    double? maxSpeedKmh,
    int? calories,
    int? averageHeartRate,
    int? maxHeartRate,
    double? goalDistanceMeters,
    int? goalDurationMinutes,
    int? goalCalories,
    bool? isGpsActivity,
    bool? hasRoute,
    int? routePointCount,
    double? startLat,
    double? startLng,
    double? endLat,
    double? endLng,
    double? minLat,
    double? minLng,
    double? maxLat,
    double? maxLng,
    String? encodedPolyline,
    FitnessSyncStatus? syncStatus,
    bool? isPoolSwimming,
    int? poolLengthMeters,
    int? lapCount,
    String? workoutCategory,
    String? aiFeedback,
    String? routineTaskId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FitnessActivityModel(
      activityId: activityId ?? this.activityId,
      activityType: activityType ?? this.activityType,
      status: status ?? this.status,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      endedAt: clearEndedAt ? null : (endedAt ?? this.endedAt),
      durationSeconds: durationSeconds ?? this.durationSeconds,
      movingTimeSeconds: movingTimeSeconds ?? this.movingTimeSeconds,
      pausedSeconds: pausedSeconds ?? this.pausedSeconds,
      pausedDurationMs: pausedDurationMs ?? this.pausedDurationMs,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      elevationGainMeters: elevationGainMeters ?? this.elevationGainMeters,
      averagePaceSecondsPerKm:
          averagePaceSecondsPerKm ?? this.averagePaceSecondsPerKm,
      currentPaceSecondsPerKm:
          currentPaceSecondsPerKm ?? this.currentPaceSecondsPerKm,
      averageSpeedKmh: averageSpeedKmh ?? this.averageSpeedKmh,
      maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
      calories: calories ?? this.calories,
      averageHeartRate: averageHeartRate ?? this.averageHeartRate,
      maxHeartRate: maxHeartRate ?? this.maxHeartRate,
      goalDistanceMeters: goalDistanceMeters ?? this.goalDistanceMeters,
      goalDurationMinutes: goalDurationMinutes ?? this.goalDurationMinutes,
      goalCalories: goalCalories ?? this.goalCalories,
      isGpsActivity: isGpsActivity ?? this.isGpsActivity,
      hasRoute: hasRoute ?? this.hasRoute,
      routePointCount: routePointCount ?? this.routePointCount,
      startLat: startLat ?? this.startLat,
      startLng: startLng ?? this.startLng,
      endLat: endLat ?? this.endLat,
      endLng: endLng ?? this.endLng,
      minLat: minLat ?? this.minLat,
      minLng: minLng ?? this.minLng,
      maxLat: maxLat ?? this.maxLat,
      maxLng: maxLng ?? this.maxLng,
      encodedPolyline: encodedPolyline ?? this.encodedPolyline,
      syncStatus: syncStatus ?? this.syncStatus,
      isPoolSwimming: isPoolSwimming ?? this.isPoolSwimming,
      poolLengthMeters: poolLengthMeters ?? this.poolLengthMeters,
      lapCount: lapCount ?? this.lapCount,
      workoutCategory: workoutCategory ?? this.workoutCategory,
      aiFeedback: aiFeedback ?? this.aiFeedback,
      routineTaskId: routineTaskId ?? this.routineTaskId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Alias for [endedAt] — when the activity was marked complete.
  DateTime? get completedAt => endedAt;

  /// Duration in milliseconds.
  int get durationMs => durationSeconds * 1000;

  /// Computed elapsed duration (excluding pauses).
  Duration get activeDuration {
    if (startedAt == null) return Duration.zero;
    final end = endedAt ?? DateTime.now();
    final totalMs = end.difference(startedAt!).inMilliseconds;
    return Duration(
        milliseconds: (totalMs - pausedDurationMs).clamp(0, totalMs));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Activity Metrics (in-memory only, not persisted)
// ─────────────────────────────────────────────────────────────────────────────

class LiveActivityMetricsModel {
  final int elapsedMs;
  final int movingMs;
  final int pausedMs;
  final double distanceMeters;
  final double? currentPaceSecondsPerKm;
  final double? currentSpeedKmh;
  final double? averagePaceSecondsPerKm;
  final double? averageSpeedKmh;
  final double? maxSpeedKmh;
  final int? currentHeartRate;
  final int? calories;
  final int splitCount;
  final double? currentAltitudeMeters;

  const LiveActivityMetricsModel({
    this.elapsedMs = 0,
    this.movingMs = 0,
    this.pausedMs = 0,
    this.distanceMeters = 0,
    this.currentPaceSecondsPerKm,
    this.currentSpeedKmh,
    this.averagePaceSecondsPerKm,
    this.averageSpeedKmh,
    this.maxSpeedKmh,
    this.currentHeartRate,
    this.calories,
    this.splitCount = 0,
    this.currentAltitudeMeters,
  });

  factory LiveActivityMetricsModel.fromMap(Map<String, dynamic> map) {
    return LiveActivityMetricsModel(
      elapsedMs: (map['elapsedMs'] as num?)?.toInt() ??
          ((map['elapsedSeconds'] as num?)?.toInt() ?? 0) * 1000,
      movingMs: (map['movingMs'] as num?)?.toInt() ??
          ((map['movingTimeSeconds'] as num?)?.toInt() ?? 0) * 1000,
      pausedMs: (map['pausedMs'] as num?)?.toInt() ??
          ((map['pausedSeconds'] as num?)?.toInt() ?? 0) * 1000,
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble() ?? 0,
      currentPaceSecondsPerKm:
          (map['currentPaceSecondsPerKm'] as num?)?.toDouble(),
      currentSpeedKmh: (map['currentSpeedKmh'] as num?)?.toDouble(),
      averagePaceSecondsPerKm:
          (map['averagePaceSecondsPerKm'] as num?)?.toDouble(),
      averageSpeedKmh: (map['averageSpeedKmh'] as num?)?.toDouble(),
      maxSpeedKmh: (map['maxSpeedKmh'] as num?)?.toDouble(),
      currentHeartRate: (map['currentHeartRate'] as num?)?.toInt(),
      calories: (map['calories'] as num?)?.toInt() ??
          (map['caloriesEstimate'] as num?)?.toInt(),
      splitCount: (map['splitCount'] as num?)?.toInt() ?? 0,
      currentAltitudeMeters: (map['currentAltitudeMeters'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'elapsedMs': elapsedMs,
      'elapsedSeconds': elapsedMs ~/ 1000,
      'movingMs': movingMs,
      'movingTimeSeconds': movingMs ~/ 1000,
      'pausedMs': pausedMs,
      'pausedSeconds': pausedMs ~/ 1000,
      'distanceMeters': distanceMeters,
      if (currentPaceSecondsPerKm != null)
        'currentPaceSecondsPerKm': currentPaceSecondsPerKm,
      if (currentSpeedKmh != null) 'currentSpeedKmh': currentSpeedKmh,
      if (averagePaceSecondsPerKm != null)
        'averagePaceSecondsPerKm': averagePaceSecondsPerKm,
      if (averageSpeedKmh != null) 'averageSpeedKmh': averageSpeedKmh,
      if (maxSpeedKmh != null) 'maxSpeedKmh': maxSpeedKmh,
      if (currentHeartRate != null) 'currentHeartRate': currentHeartRate,
      if (calories != null) 'calories': calories,
      if (calories != null) 'caloriesEstimate': calories,
      'splitCount': splitCount,
      if (currentAltitudeMeters != null)
        'currentAltitudeMeters': currentAltitudeMeters,
    };
  }

  LiveActivityMetricsModel copyWith({
    int? elapsedMs,
    int? movingMs,
    int? pausedMs,
    double? distanceMeters,
    double? currentPaceSecondsPerKm,
    double? currentSpeedKmh,
    double? averagePaceSecondsPerKm,
    double? averageSpeedKmh,
    double? maxSpeedKmh,
    int? currentHeartRate,
    int? calories,
    int? splitCount,
    double? currentAltitudeMeters,
  }) {
    return LiveActivityMetricsModel(
      elapsedMs: elapsedMs ?? this.elapsedMs,
      movingMs: movingMs ?? this.movingMs,
      pausedMs: pausedMs ?? this.pausedMs,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      currentPaceSecondsPerKm:
          currentPaceSecondsPerKm ?? this.currentPaceSecondsPerKm,
      currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
      averagePaceSecondsPerKm:
          averagePaceSecondsPerKm ?? this.averagePaceSecondsPerKm,
      averageSpeedKmh: averageSpeedKmh ?? this.averageSpeedKmh,
      maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
      currentHeartRate: currentHeartRate ?? this.currentHeartRate,
      calories: calories ?? this.calories,
      splitCount: splitCount ?? this.splitCount,
      currentAltitudeMeters:
          currentAltitudeMeters ?? this.currentAltitudeMeters,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

DateTime? _asDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
