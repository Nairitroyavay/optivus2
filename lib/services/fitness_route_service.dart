import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import 'package:optivus2/models/route_point_model.dart';
import 'package:optivus2/services/fitness_metrics_calculator.dart';

class FitnessRouteBounds {
  final double minLat;
  final double minLng;
  final double maxLat;
  final double maxLng;

  const FitnessRouteBounds({
    required this.minLat,
    required this.minLng,
    required this.maxLat,
    required this.maxLng,
  });
}

class FitnessRouteService {
  FitnessRouteService({
    FitnessMetricsCalculator calculator = const FitnessMetricsCalculator(),
  }) : _calculator = calculator;

  final FitnessMetricsCalculator _calculator;

  bool shouldAcceptPosition({
    required Position position,
    required DateTime now,
    RoutePointModel? lastPoint,
    bool isPaused = false,
  }) {
    if (isPaused) return false;
    if (position.timestamp.isAfter(now.add(const Duration(minutes: 1)))) {
      return false;
    }
    if (now.difference(position.timestamp).inMinutes > 5) return false;

    final accuracy = position.accuracy;
    if (accuracy.isNaN || accuracy <= 0 || accuracy > 65) return false;

    final last = lastPoint;
    if (last == null) return true;

    final distance = _calculator.distanceMeters(
      startLat: last.latitude,
      startLng: last.longitude,
      endLat: position.latitude,
      endLng: position.longitude,
    );
    if (distance < 5) return false;

    final elapsedSeconds =
        position.timestamp.difference(last.timestamp).inMilliseconds / 1000;
    if (elapsedSeconds <= 0) return false;
    final impliedSpeedMps = distance / elapsedSeconds;

    if (impliedSpeedMps > 15 && position.speed < 0) return false;
    if (impliedSpeedMps > 28) return false;

    return true;
  }

  RoutePointModel pointFromPosition({
    required Position position,
    required String pointId,
    required String activityId,
    required String uid,
    required int sequence,
  }) {
    return RoutePointModel(
      pointId: pointId,
      activityId: activityId,
      uid: uid,
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude.isNaN ? null : position.altitude,
      accuracy: position.accuracy.isNaN ? null : position.accuracy,
      speedMps:
          position.speed.isNaN || position.speed < 0 ? null : position.speed,
      heading: position.heading.isNaN || position.heading < 0
          ? null
          : position.heading,
      sequence: sequence,
      timestamp: position.timestamp,
    );
  }

  FitnessRouteBounds? boundsFor(List<RoutePointModel> points) {
    if (points.isEmpty) return null;
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    return FitnessRouteBounds(
      minLat: minLat,
      minLng: minLng,
      maxLat: maxLat,
      maxLng: maxLng,
    );
  }
}
