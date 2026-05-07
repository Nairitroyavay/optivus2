// lib/services/fitness_health_connector_service.dart
//
// Stub/interface for Health Connect (Android) and HealthKit (iOS).
// Phase 1: defines the contract and returns stub data.
// Phase 2: actual platform channel implementation.

import 'package:flutter/foundation.dart';

/// Health data reading capability status.
enum HealthConnectionStatus { disconnected, connecting, connected, denied }

/// Stub health data point returned by the connector.
class HealthDataPoint {
  final String type; // 'heart_rate', 'steps', 'calories', 'sleep'
  final double value;
  final DateTime timestamp;

  const HealthDataPoint({
    required this.type,
    required this.value,
    required this.timestamp,
  });
}

class FitnessHealthConnectorService {
  HealthConnectionStatus _status = HealthConnectionStatus.disconnected;

  HealthConnectionStatus get status => _status;

  /// Request permissions to read health data from the platform.
  /// Phase 1: always returns true (stub).
  Future<bool> requestPermissions() async {
    debugPrint('[HealthConnector] Stub: requestPermissions called');
    _status = HealthConnectionStatus.connected;
    return true;
  }

  /// Check if health data access is currently authorized.
  Future<bool> isAuthorized() async {
    return _status == HealthConnectionStatus.connected;
  }

  /// Disconnect from the health platform.
  Future<void> disconnect() async {
    _status = HealthConnectionStatus.disconnected;
    debugPrint('[HealthConnector] Disconnected');
  }

  /// Read heart rate samples for a time range.
  /// Phase 1: returns empty list (stub).
  Future<List<HealthDataPoint>> readHeartRate({
    required DateTime start,
    required DateTime end,
  }) async {
    debugPrint('[HealthConnector] Stub: readHeartRate');
    return const [];
  }

  /// Read step count for a time range.
  /// Phase 1: returns 0 (stub).
  Future<int> readSteps({
    required DateTime start,
    required DateTime end,
  }) async {
    debugPrint('[HealthConnector] Stub: readSteps');
    return 0;
  }

  /// Read active calories for a time range.
  /// Phase 1: returns 0 (stub).
  Future<int> readActiveCalories({
    required DateTime start,
    required DateTime end,
  }) async {
    debugPrint('[HealthConnector] Stub: readActiveCalories');
    return 0;
  }

  /// Write a completed workout to the health platform.
  /// Phase 1: no-op (stub).
  Future<bool> writeWorkout({
    required String activityType,
    required DateTime start,
    required DateTime end,
    required double distanceMeters,
    required int calories,
  }) async {
    debugPrint('[HealthConnector] Stub: writeWorkout');
    return true;
  }
}
