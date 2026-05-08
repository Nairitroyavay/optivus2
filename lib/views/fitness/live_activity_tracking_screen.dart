import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;

import 'package:optivus2/controllers/active_activity_controller.dart';
import 'package:optivus2/core/config/map_config.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/models/fitness_activity_model.dart';
import 'package:optivus2/models/fitness_permission_state_model.dart';
import 'package:optivus2/models/route_point_model.dart';
import 'package:optivus2/views/fitness/activity_pause_bottom_sheet.dart';
import 'package:optivus2/views/fitness/finish_activity_confirmation_sheet.dart';

enum _LiveMapProvider { mapbox, none }

_LiveMapProvider get _liveMapProvider {
  if (MapConfig.hasMapboxAccessToken) return _LiveMapProvider.mapbox;
  return _LiveMapProvider.none;
}

class LiveActivityTrackingScreen extends ConsumerStatefulWidget {
  const LiveActivityTrackingScreen({super.key});

  @override
  ConsumerState<LiveActivityTrackingScreen> createState() =>
      _LiveActivityTrackingScreenState();
}

class _LiveActivityTrackingScreenState
    extends ConsumerState<LiveActivityTrackingScreen> {
  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeActivityControllerProvider);
    final mapState = ref.watch(fitnessMapControllerProvider);
    final activity = active.activity;

    if (activity == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: LiquidBg(
          colors: const [Color(0xFF78FDFF), Color(0xFFE8FEFE)],
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: LiquidCard(
                  frosted: true,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.route_rounded, color: kBlue, size: 40),
                      const SizedBox(height: 12),
                      const Text(
                        'No active activity',
                        style: TextStyle(
                          color: kInk,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      LiquidButton(
                        label: 'Choose Activity',
                        onTap: () => context.go('/fitness/select'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final route = active.routePoints;
    final lastPoint = route.isEmpty ? null : route.last;
    _followLastPoint(lastPoint);

    final isGps = activity.isGpsActivity;
    final mapProvider = isGps ? _liveMapProvider : _LiveMapProvider.none;
    final showMapControls = mapProvider != _LiveMapProvider.none;

    return PopScope(
      canPop: !active.isTracking,
      child: Scaffold(
        backgroundColor: const Color(0xFF10131A),
        body: Stack(
          children: [
            Positioned.fill(
              child: isGps
                  ? switch (mapProvider) {
                      _LiveMapProvider.mapbox => _LiveMapboxMap(
                          route: route,
                          lastPoint: lastPoint,
                          controlsLocked: mapState.controlsLocked,
                        ),
                      _LiveMapProvider.none => const _MapUnavailableSurface(),
                    }
                  : _TimerOnlySurface(activity: activity),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: _TopTrackingBar(
                  activity: activity,
                  gpsLabel: _gpsLabel(active),
                  isPaused: active.isPaused,
                ),
              ),
            ),
            if (showMapControls)
              Positioned(
                right: 14,
                top: MediaQuery.of(context).padding.top + 80,
                child: _MapControls(
                  lastPoint: lastPoint,
                  controlsLocked: mapState.controlsLocked,
                  supportsMapType: false,
                ),
              ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 18 + MediaQuery.of(context).padding.bottom,
              child: _MetricsPanel(
                activity: activity,
                state: active,
                collapsed: mapState.metricsCollapsed,
                onPause: _pause,
                onResume: _resume,
                onFinish: _confirmFinish,
                onCancel: _cancel,
              ),
            ),
            if (active.errorMessage != null)
              Positioned(
                left: 14,
                right: 14,
                top: MediaQuery.of(context).padding.top + 132,
                child: _MessageBanner(
                  text: active.errorMessage!,
                  color: kCoral,
                ),
              ),
            if (active.offlineMessage != null)
              Positioned(
                left: 14,
                right: 14,
                top: MediaQuery.of(context).padding.top + 132,
                child: _MessageBanner(
                  text: active.offlineMessage!,
                  color: kAmber,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _followLastPoint(RoutePointModel? point) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(fitnessMapControllerProvider.notifier).follow(point);
    });
  }

  Future<void> _pause() async {
    HapticFeedback.mediumImpact();
    await ref.read(activeActivityControllerProvider.notifier).pause();
    if (!mounted) return;
    final action = await ActivityPauseBottomSheet.show(context);
    if (!mounted) return;
    switch (action) {
      case ActivityPauseAction.resume:
        await _resume();
      case ActivityPauseAction.finish:
        await _confirmFinish();
      case ActivityPauseAction.cancel:
        await _cancel();
      case null:
        break;
    }
  }

  Future<void> _resume() async {
    HapticFeedback.selectionClick();
    await ref.read(activeActivityControllerProvider.notifier).resume();
  }

  Future<void> _confirmFinish() async {
    final state = ref.read(activeActivityControllerProvider);
    final activity = state.activity;
    if (activity == null) return;

    final action = await FinishActivityConfirmationSheet.show(
      context,
      distance: _formatDistance(state.metrics.distanceMeters),
      duration: _formatDuration(state.metrics.elapsedMs),
      paceOrSpeed: _formatPrimaryPaceOrSpeed(activity, state.metrics),
      calories: '${state.metrics.calories ?? 0} kcal',
    );
    if (!mounted) return;

    switch (action) {
      case FinishActivityAction.save:
        final completed =
            await ref.read(activeActivityControllerProvider.notifier).finish();
        if (mounted && completed != null) {
          context.go('/fitness/activity/${completed.activityId}/summary');
        }
      case FinishActivityAction.resume:
        await _resume();
      case FinishActivityAction.discard:
        await ref.read(activeActivityControllerProvider.notifier).discard();
        if (mounted) context.go('/fitness');
      case null:
        break;
    }
  }

  Future<void> _cancel() async {
    await ref.read(activeActivityControllerProvider.notifier).cancel();
    if (mounted) context.go('/fitness');
  }

  String _gpsLabel(ActiveActivityState state) {
    if (!state.permissionState.locationGranted) return 'GPS off';
    return switch (state.permissionState.gpsSignalStrength) {
      GpsSignalStrength.strong => 'GPS strong',
      GpsSignalStrength.good => 'GPS good',
      GpsSignalStrength.weak => 'GPS weak',
      GpsSignalStrength.none => 'GPS searching',
    };
  }
}

class _LiveMapboxMap extends ConsumerStatefulWidget {
  final List<RoutePointModel> route;
  final RoutePointModel? lastPoint;
  final bool controlsLocked;

  const _LiveMapboxMap({
    required this.route,
    required this.lastPoint,
    required this.controlsLocked,
  });

  @override
  ConsumerState<_LiveMapboxMap> createState() => _LiveMapboxMapState();
}

class _LiveMapboxMapState extends ConsumerState<_LiveMapboxMap> {
  final _controller = fm.MapController();

  @override
  Widget build(BuildContext context) {
    ref.listen(fitnessMapControllerProvider, (previous, next) {
      if (previous?.cameraCommandVersion == next.cameraCommandVersion) return;
      final target = next.cameraTarget;
      if (target == null) return;
      _controller.move(
        ll.LatLng(target.latitude, target.longitude),
        next.mapZoom,
      );
    });

    final initial = widget.lastPoint == null
        ? const ll.LatLng(20.5937, 78.9629)
        : ll.LatLng(
            widget.lastPoint!.latitude,
            widget.lastPoint!.longitude,
          );

    return fm.FlutterMap(
      mapController: _controller,
      options: fm.MapOptions(
        initialCenter: initial,
        initialZoom: 16,
        interactionOptions: fm.InteractionOptions(
          flags: widget.controlsLocked
              ? fm.InteractiveFlag.none
              : fm.InteractiveFlag.all,
        ),
        onPositionChanged: (_, hasGesture) {
          if (!hasGesture) return;
          ref
              .read(fitnessMapControllerProvider.notifier)
              .handleCameraMoveStarted();
        },
      ),
      children: [
        fm.TileLayer(
          urlTemplate: MapConfig.mapboxTileUrl,
          userAgentPackageName: 'com.example.optivus',
        ),
        fm.PolylineLayer(polylines: _mapboxPolylines(widget.route)),
        fm.MarkerLayer(markers: _mapboxMarkers(widget.route, widget.lastPoint)),
      ],
    );
  }

  List<fm.Polyline> _mapboxPolylines(List<RoutePointModel> points) {
    final polylines = <fm.Polyline>[];
    var segment = <ll.LatLng>[];

    void flushSegment() {
      if (segment.length >= 2) {
        polylines.add(
          fm.Polyline(
            points: segment,
            color: kBlue,
            strokeWidth: 6,
          ),
        );
      }
      segment = [];
    }

    for (final point in points) {
      if (point.isPausePoint) flushSegment();
      segment.add(ll.LatLng(point.latitude, point.longitude));
    }
    flushSegment();

    return polylines;
  }

  List<fm.Marker> _mapboxMarkers(
    List<RoutePointModel> route,
    RoutePointModel? lastPoint,
  ) {
    return [
      if (route.isNotEmpty)
        fm.Marker(
          point: ll.LatLng(route.first.latitude, route.first.longitude),
          width: 36,
          height: 36,
          child: const Icon(
            Icons.flag_circle_rounded,
            color: kMint,
            size: 32,
          ),
        ),
      if (lastPoint != null)
        fm.Marker(
          point: ll.LatLng(lastPoint.latitude, lastPoint.longitude),
          width: 42,
          height: 42,
          child: const Icon(
            Icons.navigation_rounded,
            color: kBlue,
            size: 34,
          ),
        ),
    ];
  }
}

class _MapUnavailableSurface extends StatelessWidget {
  const _MapUnavailableSurface();

  @override
  Widget build(BuildContext context) {
    return LiquidBg(
      colors: const [Color(0xFF1D2430), Color(0xFF10131A)],
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: LiquidCard(
            frosted: true,
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.map_outlined,
                  color: kBlue,
                  size: 42,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Map is not configured yet. GPS tracking still works.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Distance, pace, calories, controls, and route point saving continue in the background.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kSub.withValues(alpha: 0.72),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimerOnlySurface extends StatelessWidget {
  final FitnessActivityModel activity;

  const _TimerOnlySurface({required this.activity});

  @override
  Widget build(BuildContext context) {
    return LiquidBg(
      colors: const [Color(0xFF1D2430), Color(0xFF10131A)],
      child: Center(
        child: Icon(
          activity.activityType == FitnessActivityType.swimming
              ? Icons.pool_rounded
              : Icons.fitness_center_rounded,
          color: kWhite.withValues(alpha: 0.34),
          size: 116,
        ),
      ),
    );
  }
}

class _TopTrackingBar extends StatelessWidget {
  final FitnessActivityModel activity;
  final String gpsLabel;
  final bool isPaused;

  const _TopTrackingBar({
    required this.activity,
    required this.gpsLabel,
    required this.isPaused,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GlassChip(
          icon: Icons.directions_run_rounded,
          label: activity.activityType.displayName,
        ),
        const SizedBox(width: 8),
        if (activity.isGpsActivity)
          _GlassChip(icon: Icons.gps_fixed, label: gpsLabel),
        const Spacer(),
        _GlassChip(
          icon: isPaused ? Icons.pause_rounded : Icons.radio_button_checked,
          label: isPaused ? 'Paused' : 'Live',
          color: isPaused ? kAmber : kMint,
        ),
      ],
    );
  }
}

class _MapControls extends ConsumerWidget {
  final RoutePointModel? lastPoint;
  final bool controlsLocked;
  final bool supportsMapType;

  const _MapControls({
    required this.lastPoint,
    required this.controlsLocked,
    required this.supportsMapType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(fitnessMapControllerProvider.notifier);
    final state = ref.watch(fitnessMapControllerProvider);

    return Column(
      children: [
        _MapButton(
          icon: Icons.my_location_rounded,
          onTap: () => controller.recenter(lastPoint),
          active: state.followMode,
        ),
        _MapButton(
          icon: Icons.add_rounded,
          onTap: controller.zoomIn,
        ),
        _MapButton(
          icon: Icons.remove_rounded,
          onTap: controller.zoomOut,
        ),
        if (supportsMapType)
          _MapButton(
            icon: Icons.layers_rounded,
            onTap: controller.cycleMapType,
          ),
        _MapButton(
          icon: controlsLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
          onTap: controller.toggleControlsLocked,
          active: controlsLocked,
        ),
        _MapButton(
          icon: state.metricsCollapsed
              ? Icons.keyboard_arrow_up_rounded
              : Icons.keyboard_arrow_down_rounded,
          onTap: controller.toggleMetricsCollapsed,
        ),
      ],
    );
  }
}

class _MetricsPanel extends StatelessWidget {
  final FitnessActivityModel activity;
  final ActiveActivityState state;
  final bool collapsed;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinish;
  final VoidCallback onCancel;

  const _MetricsPanel({
    required this.activity,
    required this.state,
    required this.collapsed,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = state.metrics;
    return LiquidCard(
      frosted: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!collapsed) ...[
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Time',
                    value: _formatDuration(metrics.elapsedMs),
                  ),
                ),
                Expanded(
                  child: _MetricTile(
                    label: 'Moving',
                    value: _formatDuration(metrics.movingMs),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Distance',
                    value: _formatDistance(metrics.distanceMeters),
                  ),
                ),
                Expanded(
                  child: _MetricTile(
                    label: activity.activityType == FitnessActivityType.cycling
                        ? 'Speed'
                        : 'Pace',
                    value: _formatPrimaryPaceOrSpeed(activity, metrics),
                  ),
                ),
                Expanded(
                  child: _MetricTile(
                    label: 'Calories',
                    value: '${metrics.calories ?? 0}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              Expanded(
                child: LiquidButton(
                  label: state.isPaused ? 'Resume' : 'Pause',
                  leading: Icon(
                    state.isPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    color: kWhite,
                  ),
                  color: state.isPaused ? kMint : kAmber,
                  onTap: state.isSaving
                      ? null
                      : (state.isPaused ? onResume : onPause),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LiquidButton(
                  label: 'Finish',
                  leading: const Icon(Icons.flag_rounded, color: kWhite),
                  color: kBlue,
                  onTap: state.isSaving ? null : onFinish,
                ),
              ),
              if (state.isPaused) ...[
                const SizedBox(width: 10),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: kCoral),
                  onPressed: state.isSaving ? null : onCancel,
                  icon: const Icon(Icons.close_rounded, color: kWhite),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: kSub.withValues(alpha: 0.66),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              color: kInk,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _GlassChip({
    required this.icon,
    required this.label,
    this.color = kBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: kWhite.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kWhite.withValues(alpha: 0.9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: kInk,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _MapButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: active ? kBlue : kWhite.withValues(alpha: 0.84),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: active ? kWhite : kInk),
          ),
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  final String text;
  final Color color;

  const _MessageBanner({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: kWhite,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _formatDuration(int milliseconds) {
  final d = Duration(milliseconds: milliseconds);
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String _formatDistance(double meters) {
  if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(2)} km';
  return '${meters.round()} m';
}

String _formatPrimaryPaceOrSpeed(
  FitnessActivityModel activity,
  LiveActivityMetricsModel metrics,
) {
  if (activity.activityType == FitnessActivityType.cycling) {
    final speed = metrics.currentSpeedKmh ?? 0;
    return '${speed.toStringAsFixed(1)} km/h';
  }
  final pace = metrics.currentPaceSecondsPerKm;
  if (pace == null || pace <= 0) return '--';
  final minutes = pace ~/ 60;
  final seconds = pace.round() % 60;
  return '$minutes\'${seconds.toString().padLeft(2, '0')}"/km';
}
