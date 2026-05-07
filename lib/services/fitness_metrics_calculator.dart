import 'dart:math' as math;

import 'package:optivus2/models/fitness_activity_model.dart';

class FitnessMetricsCalculator {
  const FitnessMetricsCalculator();

  double distanceMeters({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _toRadians(endLat - startLat);
    final dLng = _toRadians(endLng - startLng);
    final lat1 = _toRadians(startLat);
    final lat2 = _toRadians(endLat);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  double? paceSecondsPerKm({
    required int movingSeconds,
    required double distanceMeters,
  }) {
    if (movingSeconds <= 0 || distanceMeters < 1) return null;
    return movingSeconds / (distanceMeters / 1000);
  }

  double? speedKmh({
    required int movingSeconds,
    required double distanceMeters,
  }) {
    if (movingSeconds <= 0 || distanceMeters < 1) return null;
    return (distanceMeters / movingSeconds) * 3.6;
  }

  int caloriesEstimate({
    required FitnessActivityType type,
    required int movingSeconds,
    required double distanceMeters,
  }) {
    final minutes = movingSeconds / 60;
    final met = switch (type) {
      FitnessActivityType.running => 9.8,
      FitnessActivityType.walking => 3.8,
      FitnessActivityType.cycling => 7.5,
      FitnessActivityType.hiking => 6.0,
      FitnessActivityType.swimming => 8.0,
      FitnessActivityType.gymWorkout => 5.0,
      FitnessActivityType.custom => 4.0,
    };
    const assumedWeightKg = 72.0;
    final timeCalories = met * 3.5 * assumedWeightKg / 200 * minutes;
    final distanceBonus = distanceMeters /
        1000 *
        switch (type) {
          FitnessActivityType.running => 68.0,
          FitnessActivityType.walking => 42.0,
          FitnessActivityType.cycling => 28.0,
          FitnessActivityType.hiking => 55.0,
          _ => 0.0,
        };
    return math.max(timeCalories, distanceBonus).round();
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;
}
