import 'package:optivus2/models/fitness_activity_model.dart';

String formatActivityDuration(Duration duration) {
  final h = duration.inHours;
  final m = duration.inMinutes.remainder(60);
  final s = duration.inSeconds.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m ${s}s';
  return '${s}s';
}

String formatStopwatchSeconds(int seconds) {
  final d = Duration(seconds: seconds);
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:'
      '${s.toString().padLeft(2, '0')}';
}

String formatDistance(double meters) {
  if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(2)} km';
  return '${meters.round()} m';
}

String formatPace(double? secondsPerKm) {
  if (secondsPerKm == null || secondsPerKm <= 0) return '--';
  final minutes = secondsPerKm ~/ 60;
  final seconds = secondsPerKm.round() % 60;
  return '$minutes\'${seconds.toString().padLeft(2, '0')}"/km';
}

String formatSpeed(double? kmh) {
  if (kmh == null || kmh <= 0) return '--';
  return '${kmh.toStringAsFixed(1)} km/h';
}

String formatPrimaryPaceOrSpeed(FitnessActivityModel activity) {
  if (activity.activityType == FitnessActivityType.cycling) {
    return formatSpeed(activity.averageSpeedKmh);
  }
  return formatPace(activity.averagePaceSecondsPerKm);
}

String activityDisplayTitle(FitnessActivityModel activity) {
  return activity.title.isNotEmpty
      ? activity.title
      : activity.activityType.displayName;
}
