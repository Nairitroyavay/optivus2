import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'package:optivus2/models/fitness_permission_state_model.dart';

class LocationTrackingService {
  StreamSubscription<ServiceStatus>? _serviceStatusSub;

  Future<FitnessPermissionStateModel> checkPermissionState() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();
    return _permissionState(permission, serviceEnabled);
  }

  Future<FitnessPermissionStateModel> requestForegroundPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return _permissionState(permission, serviceEnabled);
  }

  Stream<Position> positionStream() {
    return Geolocator.getPositionStream(locationSettings: _settings());
  }

  Stream<ServiceStatus> serviceStatusStream() {
    return Geolocator.getServiceStatusStream();
  }

  Future<Position?> currentPosition() async {
    try {
      return Geolocator.getCurrentPosition(locationSettings: _settings());
    } catch (_) {
      return null;
    }
  }

  void listenToGpsService(ValueChanged<bool> onEnabledChanged) {
    _serviceStatusSub?.cancel();
    _serviceStatusSub = serviceStatusStream().listen((status) {
      onEnabledChanged(status == ServiceStatus.enabled);
    });
  }

  Future<void> stopTracking() async {
    await _serviceStatusSub?.cancel();
    _serviceStatusSub = null;
  }

  FitnessPermissionStateModel _permissionState(
    LocationPermission permission,
    bool serviceEnabled,
  ) {
    final granted = permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
    final always = permission == LocationPermission.always;
    return FitnessPermissionStateModel(
      locationGranted: granted,
      locationAlwaysGranted: always,
      gpsSignalStrength: granted && serviceEnabled
          ? GpsSignalStrength.good
          : GpsSignalStrength.none,
    );
  }

  LocationSettings _settings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
        intervalDuration: const Duration(seconds: 2),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Optivus fitness tracking active',
          notificationText: 'Optivus is recording your active workout route.',
          enableWakeLock: true,
        ),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.fitness,
        distanceFilter: 3,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 3,
    );
  }
}
