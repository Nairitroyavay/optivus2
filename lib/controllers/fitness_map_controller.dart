import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:optivus2/models/route_point_model.dart';

class FitnessMapState {
  final bool followMode;
  final bool controlsLocked;
  final bool metricsCollapsed;
  final double mapZoom;
  final int cameraCommandVersion;
  final RoutePointModel? cameraTarget;

  const FitnessMapState({
    this.followMode = true,
    this.controlsLocked = false,
    this.metricsCollapsed = false,
    this.mapZoom = 16,
    this.cameraCommandVersion = 0,
    this.cameraTarget,
  });

  FitnessMapState copyWith({
    bool? followMode,
    bool? controlsLocked,
    bool? metricsCollapsed,
    double? mapZoom,
    int? cameraCommandVersion,
    RoutePointModel? cameraTarget,
  }) {
    return FitnessMapState(
      followMode: followMode ?? this.followMode,
      controlsLocked: controlsLocked ?? this.controlsLocked,
      metricsCollapsed: metricsCollapsed ?? this.metricsCollapsed,
      mapZoom: mapZoom ?? this.mapZoom,
      cameraCommandVersion: cameraCommandVersion ?? this.cameraCommandVersion,
      cameraTarget: cameraTarget ?? this.cameraTarget,
    );
  }
}

class FitnessMapController extends StateNotifier<FitnessMapState> {
  FitnessMapController() : super(const FitnessMapState());

  void recenter(RoutePointModel? point) {
    if (point == null) return;
    state = state.copyWith(
      followMode: true,
      mapZoom: 17,
      cameraTarget: point,
      cameraCommandVersion: state.cameraCommandVersion + 1,
    );
  }

  void zoomIn() {
    state = state.copyWith(
      mapZoom: (state.mapZoom + 1).clamp(3, 20).toDouble(),
      cameraCommandVersion: state.cameraCommandVersion + 1,
    );
  }

  void zoomOut() {
    state = state.copyWith(
      mapZoom: (state.mapZoom - 1).clamp(3, 20).toDouble(),
      cameraCommandVersion: state.cameraCommandVersion + 1,
    );
  }

  void handleCameraMoveStarted() {
    state = state.copyWith(followMode: false);
  }

  void toggleFollowMode() {
    state = state.copyWith(followMode: !state.followMode);
  }

  void toggleControlsLocked() {
    state = state.copyWith(controlsLocked: !state.controlsLocked);
  }

  void toggleMetricsCollapsed() {
    state = state.copyWith(metricsCollapsed: !state.metricsCollapsed);
  }

  void cycleMapType() {}

  void follow(RoutePointModel? point) {
    if (!state.followMode || point == null) return;
    state = state.copyWith(
      cameraTarget: point,
      cameraCommandVersion: state.cameraCommandVersion + 1,
    );
  }
}
