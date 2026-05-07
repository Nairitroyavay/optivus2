import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:optivus2/models/route_point_model.dart';

class FitnessMapState {
  final bool followMode;
  final bool controlsLocked;
  final bool metricsCollapsed;
  final MapType mapType;
  final double mapZoom;
  final int cameraCommandVersion;
  final RoutePointModel? cameraTarget;

  const FitnessMapState({
    this.followMode = true,
    this.controlsLocked = false,
    this.metricsCollapsed = false,
    this.mapType = MapType.normal,
    this.mapZoom = 16,
    this.cameraCommandVersion = 0,
    this.cameraTarget,
  });

  FitnessMapState copyWith({
    bool? followMode,
    bool? controlsLocked,
    bool? metricsCollapsed,
    MapType? mapType,
    double? mapZoom,
    int? cameraCommandVersion,
    RoutePointModel? cameraTarget,
  }) {
    return FitnessMapState(
      followMode: followMode ?? this.followMode,
      controlsLocked: controlsLocked ?? this.controlsLocked,
      metricsCollapsed: metricsCollapsed ?? this.metricsCollapsed,
      mapType: mapType ?? this.mapType,
      mapZoom: mapZoom ?? this.mapZoom,
      cameraCommandVersion: cameraCommandVersion ?? this.cameraCommandVersion,
      cameraTarget: cameraTarget ?? this.cameraTarget,
    );
  }
}

class FitnessMapController extends StateNotifier<FitnessMapState> {
  FitnessMapController() : super(const FitnessMapState());

  GoogleMapController? _mapController;
  bool _isProgrammaticCameraMove = false;

  void attach(GoogleMapController controller) {
    _mapController = controller;
  }

  void detach() {
    _mapController = null;
  }

  Future<void> recenter(RoutePointModel? point) async {
    if (point == null) return;
    state = state.copyWith(
      followMode: true,
      mapZoom: 17,
      cameraTarget: point,
      cameraCommandVersion: state.cameraCommandVersion + 1,
    );
    await _animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(point.latitude, point.longitude),
        17,
      ),
    );
  }

  Future<void> zoomIn() async {
    state = state.copyWith(
      mapZoom: (state.mapZoom + 1).clamp(3, 20).toDouble(),
      cameraCommandVersion: state.cameraCommandVersion + 1,
    );
    await _animateCamera(CameraUpdate.zoomIn());
  }

  Future<void> zoomOut() async {
    state = state.copyWith(
      mapZoom: (state.mapZoom - 1).clamp(3, 20).toDouble(),
      cameraCommandVersion: state.cameraCommandVersion + 1,
    );
    await _animateCamera(CameraUpdate.zoomOut());
  }

  void handleCameraMoveStarted() {
    if (_isProgrammaticCameraMove) return;
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

  void cycleMapType() {
    final next = switch (state.mapType) {
      MapType.normal => MapType.satellite,
      MapType.satellite => MapType.terrain,
      MapType.terrain => MapType.hybrid,
      _ => MapType.normal,
    };
    state = state.copyWith(mapType: next);
  }

  Future<void> follow(RoutePointModel? point) async {
    if (!state.followMode || point == null) return;
    state = state.copyWith(
      cameraTarget: point,
      cameraCommandVersion: state.cameraCommandVersion + 1,
    );
    await _animateCamera(
      CameraUpdate.newLatLng(LatLng(point.latitude, point.longitude)),
    );
  }

  Future<void> _animateCamera(CameraUpdate update) async {
    final controller = _mapController;
    if (controller == null) return;

    _isProgrammaticCameraMove = true;
    try {
      await controller.animateCamera(update);
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      _isProgrammaticCameraMove = false;
    }
  }
}
