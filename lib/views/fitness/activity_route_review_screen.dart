import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;

import 'package:optivus2/core/config/map_config.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/models/activity_split_model.dart';
import 'package:optivus2/models/fitness_activity_model.dart';
import 'package:optivus2/models/route_point_model.dart';
import 'package:optivus2/views/fitness/activity_formatters.dart';

class ActivityRouteReviewScreen extends ConsumerStatefulWidget {
  final String activityId;

  const ActivityRouteReviewScreen({super.key, required this.activityId});

  @override
  ConsumerState<ActivityRouteReviewScreen> createState() =>
      _ActivityRouteReviewScreenState();
}

class _ActivityRouteReviewScreenState
    extends ConsumerState<ActivityRouteReviewScreen> {
  final _mapController = fm.MapController();
  bool _fitQueued = false;
  String? _eventActivityId;

  @override
  Widget build(BuildContext context) {
    final activityAsync = ref.watch(activityDetailProvider(widget.activityId));
    final pointsAsync =
        ref.watch(activityRoutePointsProvider(widget.activityId));
    final splitsAsync = ref.watch(activitySplitsProvider(widget.activityId));
    final mapboxReady = ref.watch(appFeatureFlagsProvider).mapboxMapsReady;

    return Scaffold(
      backgroundColor: const Color(0xFF10131A),
      body: activityAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _EmptyRouteState(
          title: 'Route unavailable',
          message: '$err',
          onBack: () => context.pop(),
        ),
        data: (activity) {
          if (activity == null) {
            return _EmptyRouteState(
              title: 'Activity not found',
              message: 'This saved activity no longer exists.',
              onBack: () => context.go('/fitness/history'),
            );
          }
          _emitRouteReviewOpened(activity);

          final points = pointsAsync.valueOrNull ?? const <RoutePointModel>[];
          final splits =
              splitsAsync.valueOrNull ?? const <ActivitySplitModel>[];
          final loadingRoute = pointsAsync.isLoading && points.isEmpty;

          if (loadingRoute) {
            return const Center(child: CircularProgressIndicator());
          }
          if (points.length < 2) {
            return _EmptyRouteState(
              title: 'No saved route',
              message:
                  'This activity can still be reviewed from history and detail.',
              onBack: () => context.pop(),
            );
          }

          _queueFit(points);
          final center =
              ll.LatLng(points.first.latitude, points.first.longitude);

          return Stack(
            children: [
              if (mapboxReady)
                fm.FlutterMap(
                  mapController: _mapController,
                  options: fm.MapOptions(
                    initialCenter: center,
                    initialZoom: 15,
                    interactionOptions: const fm.InteractionOptions(
                      flags: fm.InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    fm.TileLayer(
                      urlTemplate: MapConfig.mapboxTileUrl,
                      userAgentPackageName: 'com.example.optivus',
                    ),
                    fm.PolylineLayer(polylines: _polylines(points)),
                    fm.MarkerLayer(markers: _markers(points, splits)),
                  ],
                )
              else
                const _RouteMapUnavailableSurface(),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: Row(
                    children: [
                      _RoundMapButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => context.pop(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _RouteTitleChip(activity: activity),
                      ),
                    ],
                  ),
                ),
              ),
              if (mapboxReady)
                Positioned(
                  right: 14,
                  top: MediaQuery.of(context).padding.top + 82,
                  child: Column(
                    children: [
                      _RoundMapButton(
                        icon: Icons.center_focus_strong_rounded,
                        onTap: () => _fitRoute(points),
                      ),
                      _RoundMapButton(
                        icon: Icons.add_rounded,
                        onTap: () => _mapController.move(
                          _mapController.camera.center,
                          (_mapController.camera.zoom + 1).clamp(3, 20),
                        ),
                      ),
                      _RoundMapButton(
                        icon: Icons.remove_rounded,
                        onTap: () => _mapController.move(
                          _mapController.camera.center,
                          (_mapController.camera.zoom - 1).clamp(3, 20),
                        ),
                      ),
                    ],
                  ),
                ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 16 + MediaQuery.of(context).padding.bottom,
                child: _RouteStatsPanel(
                  activity: activity,
                  pointCount: points.length,
                  splitCount: splits.length,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _emitRouteReviewOpened(FitnessActivityModel activity) {
    if (_eventActivityId == activity.activityId) return;
    _eventActivityId = activity.activityId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(fitnessActivityRepositoryProvider)
          .emitRouteReviewOpened(activity);
    });
  }

  void _queueFit(List<RoutePointModel> points) {
    if (!ref.read(appFeatureFlagsProvider).mapboxMapsReady) return;
    if (_fitQueued) return;
    _fitQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitRoute(points);
    });
  }

  void _fitRoute(List<RoutePointModel> points) {
    if (points.isEmpty) return;
    final bounds = fm.LatLngBounds.fromPoints(
      points.map((p) => ll.LatLng(p.latitude, p.longitude)).toList(),
    );
    _mapController.fitCamera(
      fm.CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(42, 120, 42, 190),
      ),
    );
  }

  List<fm.Polyline> _polylines(List<RoutePointModel> points) {
    final polylines = <fm.Polyline>[];
    var segment = <ll.LatLng>[];

    void flush() {
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
      if (point.isPausePoint) flush();
      segment.add(ll.LatLng(point.latitude, point.longitude));
    }
    flush();
    return polylines;
  }

  List<fm.Marker> _markers(
    List<RoutePointModel> points,
    List<ActivitySplitModel> splits,
  ) {
    final markers = <fm.Marker>[
      fm.Marker(
        point: ll.LatLng(points.first.latitude, points.first.longitude),
        width: 42,
        height: 42,
        child: const Icon(Icons.flag_circle_rounded, color: kMint, size: 34),
      ),
      fm.Marker(
        point: ll.LatLng(points.last.latitude, points.last.longitude),
        width: 42,
        height: 42,
        child: const Icon(Icons.sports_score_rounded, color: kCoral, size: 34),
      ),
    ];

    for (final split in splits.where((s) => s.endedAt != null)) {
      final point = _closestPoint(points, split.endedAt!);
      if (point == null) continue;
      markers.add(
        fm.Marker(
          point: ll.LatLng(point.latitude, point.longitude),
          width: 30,
          height: 30,
          child: Container(
            decoration: BoxDecoration(
              color: kWhite.withValues(alpha: 0.92),
              shape: BoxShape.circle,
              border: Border.all(color: kBlue, width: 2),
            ),
            child: Center(
              child: Text(
                '${split.splitNumber}',
                style: const TextStyle(
                  color: kInk,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return markers;
  }

  RoutePointModel? _closestPoint(List<RoutePointModel> points, DateTime time) {
    RoutePointModel? best;
    var bestDelta = 1 << 62;
    for (final point in points) {
      final delta = point.timestamp.difference(time).inMilliseconds.abs();
      if (delta < bestDelta) {
        best = point;
        bestDelta = delta;
      }
    }
    return best;
  }
}

class _RouteTitleChip extends StatelessWidget {
  final FitnessActivityModel activity;

  const _RouteTitleChip({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: kWhite.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        activityDisplayTitle(activity),
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: kInk,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RouteMapUnavailableSurface extends StatelessWidget {
  const _RouteMapUnavailableSurface();

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
                const Icon(Icons.map_outlined, color: kBlue, size: 42),
                const SizedBox(height: 12),
                const Text(
                  'Map is not configured yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Set MAPBOX_ACCESS_TOKEN to view saved routes. Activity stats remain available.',
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

class _RouteStatsPanel extends StatelessWidget {
  final FitnessActivityModel activity;
  final int pointCount;
  final int splitCount;

  const _RouteStatsPanel({
    required this.activity,
    required this.pointCount,
    required this.splitCount,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      frosted: true,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _RouteStat(
              label: 'Distance',
              value: formatDistance(activity.distanceMeters)),
          _RouteStat(
              label: 'Time',
              value: formatStopwatchSeconds(activity.durationSeconds)),
          _RouteStat(label: 'Splits', value: '$splitCount'),
          _RouteStat(label: 'Points', value: '$pointCount'),
        ],
      ),
    );
  }
}

class _RouteStat extends StatelessWidget {
  final String label;
  final String value;

  const _RouteStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: kSub.withValues(alpha: 0.68),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: kInk,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundMapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundMapButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: kWhite.withValues(alpha: 0.86),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, color: kInk),
          ),
        ),
      ),
    );
  }
}

class _EmptyRouteState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onBack;

  const _EmptyRouteState({
    required this.title,
    required this.message,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidBg(
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
                  const Icon(Icons.map_outlined, color: kBlue, size: 42),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: kInk,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: kSub.withValues(alpha: 0.72),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LiquidButton(label: 'Back', onTap: onBack),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
