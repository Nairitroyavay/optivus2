import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:optivus2/core/utils/uuid_generator.dart';
import 'package:optivus2/models/activity_split_model.dart';
import 'package:optivus2/models/fitness_activity_model.dart';
import 'package:optivus2/models/fitness_permission_state_model.dart';
import 'package:optivus2/models/route_point_model.dart';
import 'package:optivus2/repositories/fitness_activity_repository.dart';
import 'package:optivus2/services/fitness_metrics_calculator.dart';
import 'package:optivus2/services/fitness_route_service.dart';
import 'package:optivus2/services/fitness_ai_coach_service.dart';
import 'package:optivus2/services/fitness_event_service.dart';
import 'package:optivus2/services/fitness_stats_service.dart';
import 'package:optivus2/services/location_tracking_service.dart';
import 'package:optivus2/services/task_service.dart';

class ActiveActivityState {
  final FitnessActivityModel? activity;
  final LiveActivityMetricsModel metrics;
  final List<RoutePointModel> routePoints;
  final FitnessPermissionStateModel permissionState;
  final bool isStarting;
  final bool isSaving;
  final bool isTracking;
  final bool isPaused;
  final String? errorMessage;
  final String? offlineMessage;

  const ActiveActivityState({
    this.activity,
    this.metrics = const LiveActivityMetricsModel(),
    this.routePoints = const [],
    this.permissionState = const FitnessPermissionStateModel(),
    this.isStarting = false,
    this.isSaving = false,
    this.isTracking = false,
    this.isPaused = false,
    this.errorMessage,
    this.offlineMessage,
  });

  ActiveActivityState copyWith({
    FitnessActivityModel? activity,
    bool clearActivity = false,
    LiveActivityMetricsModel? metrics,
    List<RoutePointModel>? routePoints,
    FitnessPermissionStateModel? permissionState,
    bool? isStarting,
    bool? isSaving,
    bool? isTracking,
    bool? isPaused,
    String? errorMessage,
    bool clearError = false,
    String? offlineMessage,
    bool clearOffline = false,
  }) {
    return ActiveActivityState(
      activity: clearActivity ? null : (activity ?? this.activity),
      metrics: metrics ?? this.metrics,
      routePoints: routePoints ?? this.routePoints,
      permissionState: permissionState ?? this.permissionState,
      isStarting: isStarting ?? this.isStarting,
      isSaving: isSaving ?? this.isSaving,
      isTracking: isTracking ?? this.isTracking,
      isPaused: isPaused ?? this.isPaused,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      offlineMessage:
          clearOffline ? null : (offlineMessage ?? this.offlineMessage),
    );
  }
}

class ActiveActivityController extends StateNotifier<ActiveActivityState> {
  ActiveActivityController({
    required FitnessActivityRepository repository,
    required LocationTrackingService locationService,
    required FitnessRouteService routeService,
    required FitnessMetricsCalculator metricsCalculator,
    FitnessStatsService? statsService,
    FitnessEventService? fitnessEventService,
    FitnessAICoachService? aiCoachService,
    TaskService? taskService,
  })  : _repository = repository,
        _locationService = locationService,
        _routeService = routeService,
        _metricsCalculator = metricsCalculator,
        _statsService = statsService,
        _fitnessEventService = fitnessEventService,
        _aiCoachService = aiCoachService,
        _taskService = taskService,
        super(const ActiveActivityState());

  final FitnessActivityRepository _repository;
  final LocationTrackingService _locationService;
  final FitnessRouteService _routeService;
  final FitnessMetricsCalculator _metricsCalculator;
  final FitnessStatsService? _statsService;
  final FitnessEventService? _fitnessEventService;
  final FitnessAICoachService? _aiCoachService;
  final TaskService? _taskService;

  StreamSubscription<dynamic>? _positionSub;
  Timer? _tickTimer;
  DateTime? _startedAt;
  DateTime? _lastResumeAt;
  DateTime? _pausedAt;
  int _movingBeforeCurrentResumeMs = 0;
  int _pausedMs = 0;
  double _distanceMeters = 0;
  double _maxSpeedKmh = 0;
  int _sequence = 0;
  bool _busy = false;
  bool _segmentBreakPending = false;
  final _pendingPoints = <RoutePointModel>[];

  Future<void> startActivity(FitnessActivityModel draft) async {
    if (_busy || state.isTracking) return;
    _busy = true;
    state =
        state.copyWith(isStarting: true, clearError: true, clearOffline: true);

    try {
      final permissionState = draft.isGpsActivity
          ? await _locationService.requestForegroundPermission()
          : const FitnessPermissionStateModel(
              gpsSignalStrength: GpsSignalStrength.none,
            );

      if (draft.isGpsActivity && !permissionState.isGpsReady) {
        state = state.copyWith(
          permissionState: permissionState,
          isStarting: false,
          errorMessage:
              'Location permission and GPS are required to draw this route.',
        );
        return;
      }

      final now = DateTime.now();
      _startedAt = now;
      _lastResumeAt = now;
      _movingBeforeCurrentResumeMs = 0;
      _pausedMs = 0;
      _distanceMeters = 0;
      _maxSpeedKmh = 0;
      _sequence = 0;
      _segmentBreakPending = false;
      _pendingPoints.clear();

      final activity = draft.copyWith(
        status: FitnessActivityStatus.active,
        startedAt: now,
        createdAt: draft.createdAt,
        updatedAt: now,
        syncStatus: FitnessSyncStatus.synced,
      );

      if ((activity.routineTaskId ?? '').isNotEmpty) {
        await _taskService?.startLinkedFitnessActivity(
          taskId: activity.routineTaskId!,
          fitnessActivityId: activity.activityId,
        );
        await _fitnessEventService?.emitRoutineFitnessStarted(
          activityId: activity.activityId,
          activityType: activity.activityType.toJson(),
          routineTaskId: activity.routineTaskId!,
        );
      }

      await _repository.createActivity(activity);

      state = state.copyWith(
        activity: activity,
        permissionState: permissionState,
        isStarting: false,
        isTracking: true,
        isPaused: false,
        metrics: const LiveActivityMetricsModel(),
        routePoints: const [],
      );

      _startTimer();
      if (activity.isGpsActivity) {
        await _repository.emitRouteTrackingStarted(activity);
        _startPositionStream(activity);
      }
    } catch (e) {
      state = state.copyWith(
        isStarting: false,
        errorMessage: 'Could not start activity: $e',
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> pause() async {
    final activity = state.activity;
    if (activity == null || state.isPaused || _busy) return;

    final now = DateTime.now();
    _movingBeforeCurrentResumeMs = _currentMovingMs(now);
    _pausedAt = now;

    final updated = _activityWithLiveSummary(
      activity.copyWith(status: FitnessActivityStatus.paused),
      now,
    );
    state = state.copyWith(activity: updated, isPaused: true);
    await _repository.pauseActivity(updated);
  }

  Future<void> resume() async {
    final activity = state.activity;
    if (activity == null || !state.isPaused || _busy) return;

    final now = DateTime.now();
    final pausedAt = _pausedAt;
    if (pausedAt != null) {
      _pausedMs += now.difference(pausedAt).inMilliseconds;
    }
    _lastResumeAt = now;
    _pausedAt = null;
    _segmentBreakPending = true;

    final updated = _activityWithLiveSummary(
      activity.copyWith(status: FitnessActivityStatus.active),
      now,
    );
    state = state.copyWith(activity: updated, isPaused: false);
    await _repository.resumeActivity(updated);
  }

  Future<FitnessActivityModel?> finish() async {
    final activity = state.activity;
    if (activity == null || _busy) return null;
    _busy = true;
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final now = DateTime.now();
      await _stopLiveTracking(activity);
      await _flushRoutePoints(activity.activityId);

      final completed = _activityWithLiveSummary(
        activity.copyWith(
          status: FitnessActivityStatus.completed,
          endedAt: now,
          updatedAt: now,
        ),
        now,
      );
      final splits = _splitsForCompletedActivity(completed);
      if (splits.isNotEmpty) {
        await _repository.saveSplits(completed.activityId, splits);
      }
      await _repository.completeActivity(completed);
      await _runCompletionSideEffects(completed);
      state = state.copyWith(
        activity: completed,
        isTracking: false,
        isSaving: false,
      );
      return completed;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Could not finish activity: $e',
      );
      return null;
    } finally {
      _busy = false;
    }
  }

  Future<void> cancel() async {
    final activity = state.activity;
    if (activity == null || _busy) return;
    _busy = true;
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      await _stopLiveTracking(activity);
      final cancelled = _activityWithLiveSummary(
        activity.copyWith(
          status: FitnessActivityStatus.cancelled,
          endedAt: DateTime.now(),
        ),
        DateTime.now(),
      );
      await _repository.cancelActivity(cancelled);
      await _abandonLinkedRoutineTask(activity);
      state = const ActiveActivityState();
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Could not cancel activity: $e',
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> discard() async {
    final activity = state.activity;
    if (activity == null || _busy) return;
    _busy = true;
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      await _stopLiveTracking(activity);
      _pendingPoints.clear();
      await _repository.discardActivityCascade(
        uid: FirebaseAuth.instance.currentUser?.uid ?? '',
        activityId: activity.activityId,
      );
      await _abandonLinkedRoutineTask(activity);
      state = const ActiveActivityState();
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Could not discard activity: $e',
      );
    } finally {
      _busy = false;
    }
  }

  void _startTimer() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final activity = state.activity;
      final startedAt = _startedAt;
      if (activity == null || startedAt == null) return;

      final now = DateTime.now();
      final metrics = _metricsFor(now);
      state = state.copyWith(
        metrics: metrics,
        activity: _activityWithLiveSummary(activity, now),
      );
    });
  }

  void _startPositionStream(FitnessActivityModel activity) {
    _positionSub?.cancel();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    _positionSub = _locationService.positionStream().listen(
      (position) async {
        final now = DateTime.now();
        final points = state.routePoints;
        final lastPoint = points.isEmpty ? null : points.last;
        final segmentBreakPending = _segmentBreakPending;
        final accepted = _routeService.shouldAcceptPosition(
          position: position,
          now: now,
          lastPoint: segmentBreakPending ? null : lastPoint,
          isPaused: state.isPaused,
        );
        if (!accepted) return;

        _sequence += 1;
        final rawPoint = _routeService.pointFromPosition(
          position: position,
          pointId: generateId(),
          activityId: activity.activityId,
          uid: uid,
          sequence: _sequence,
        );
        final point = segmentBreakPending
            ? rawPoint.copyWith(isPausePoint: true)
            : rawPoint;

        if (lastPoint != null && !segmentBreakPending) {
          _distanceMeters += _metricsCalculator.distanceMeters(
            startLat: lastPoint.latitude,
            startLng: lastPoint.longitude,
            endLat: point.latitude,
            endLng: point.longitude,
          );
        }
        if (point.speedMps != null) {
          _maxSpeedKmh = _maxSpeedKmh < point.speedMps! * 3.6
              ? point.speedMps! * 3.6
              : _maxSpeedKmh;
        }
        if (segmentBreakPending) {
          _segmentBreakPending = false;
        }

        final nextPoints = [...state.routePoints, point];
        _pendingPoints.add(point);

        state = state.copyWith(
          routePoints: nextPoints,
          metrics: _metricsFor(now),
          permissionState: state.permissionState.copyWith(
            gpsSignalStrength: (point.accuracy ?? 999) <= 20
                ? GpsSignalStrength.strong
                : GpsSignalStrength.good,
          ),
        );

        if (_pendingPoints.length >= 5) {
          await _flushRoutePoints(activity.activityId);
        }
      },
      onError: (Object e) {
        state = state.copyWith(
          errorMessage: 'GPS tracking error: $e',
          permissionState: state.permissionState.copyWith(
            gpsSignalStrength: GpsSignalStrength.weak,
          ),
        );
      },
    );
  }

  Future<void> _stopLiveTracking(FitnessActivityModel activity) async {
    _tickTimer?.cancel();
    _tickTimer = null;
    await _positionSub?.cancel();
    _positionSub = null;
    await _locationService.stopTracking();
    if (activity.isGpsActivity) {
      await _repository.emitRouteTrackingStopped(activity);
    }
  }

  Future<void> _flushRoutePoints(String activityId) async {
    if (_pendingPoints.isEmpty) return;
    final points = List<RoutePointModel>.from(_pendingPoints);
    _pendingPoints.clear();
    try {
      await _repository.saveRoutePointsBatch(activityId, points);
      if (state.offlineMessage != null) {
        state = state.copyWith(clearOffline: true);
      }
    } catch (_) {
      _pendingPoints.insertAll(0, points);
      state = state.copyWith(
        offlineMessage: 'Saved on device. Syncing when internet returns.',
        activity:
            state.activity?.copyWith(syncStatus: FitnessSyncStatus.pending),
      );
    }
  }

  Future<void> _runCompletionSideEffects(FitnessActivityModel activity) async {
    try {
      await _statsService?.updateCompletionAggregatesAfterActivityCompleted(
        activity,
        eventService: _fitnessEventService,
      );
    } catch (e) {
      debugPrint(
          '[ActiveActivityController] Fitness stats side effects failed: $e');
    }

    try {
      await _fitnessEventService?.emitFitnessStreakUpdated(
        streakId: 'fitness_activity_days',
        currentCount: 1,
        action: 'extended',
      );
    } catch (e) {
      debugPrint('[ActiveActivityController] Fitness streak event failed: $e');
    }

    final routineTaskId = activity.routineTaskId;
    if (routineTaskId != null && routineTaskId.isNotEmpty) {
      try {
        await _taskService?.completeTask(routineTaskId);
        await _fitnessEventService?.emitRoutineFitnessCompleted(
          activityId: activity.activityId,
          activityType: activity.activityType.toJson(),
          routineTaskId: routineTaskId,
        );
      } catch (e) {
        debugPrint(
            '[ActiveActivityController] Routine fitness completion failed: $e');
      }
    }

    try {
      await _fitnessEventService?.emitAiFeedbackRequested(
        activityId: activity.activityId,
        activityType: activity.activityType.toJson(),
      );
      final aiCoachService = _aiCoachService;
      final eventService = _fitnessEventService;
      if (aiCoachService != null) {
        unawaited(
          aiCoachService.generateAndSaveFeedback(activity).then((_) {
            return eventService?.emitAiFeedbackGenerated(
              activityId: activity.activityId,
              activityType: activity.activityType.toJson(),
            );
          }),
        );
      }
    } catch (e) {
      debugPrint('[ActiveActivityController] AI feedback request failed: $e');
    }
  }

  Future<void> _abandonLinkedRoutineTask(FitnessActivityModel activity) async {
    final routineTaskId = activity.routineTaskId;
    if (routineTaskId == null || routineTaskId.isEmpty) return;
    try {
      await _taskService?.abandonTask(routineTaskId);
    } catch (e) {
      debugPrint(
          '[ActiveActivityController] Linked routine abandon failed: $e');
    }
  }

  FitnessActivityModel _activityWithLiveSummary(
    FitnessActivityModel activity,
    DateTime now,
  ) {
    final metrics = _metricsFor(now);
    final routeBounds = _routeService.boundsFor(state.routePoints);
    final first = state.routePoints.isEmpty ? null : state.routePoints.first;
    final last = state.routePoints.isEmpty ? null : state.routePoints.last;

    return activity.copyWith(
      durationSeconds: metrics.elapsedMs ~/ 1000,
      movingTimeSeconds: metrics.movingMs ~/ 1000,
      pausedSeconds: metrics.pausedMs ~/ 1000,
      pausedDurationMs: metrics.pausedMs,
      distanceMeters: metrics.distanceMeters,
      averagePaceSecondsPerKm: metrics.averagePaceSecondsPerKm,
      currentPaceSecondsPerKm: metrics.currentPaceSecondsPerKm,
      averageSpeedKmh: metrics.averageSpeedKmh,
      maxSpeedKmh: _maxSpeedKmh > 0 ? _maxSpeedKmh : null,
      calories: metrics.calories,
      hasRoute: state.routePoints.isNotEmpty,
      routePointCount: state.routePoints.length,
      startLat: first?.latitude,
      startLng: first?.longitude,
      endLat: last?.latitude,
      endLng: last?.longitude,
      minLat: routeBounds?.minLat,
      minLng: routeBounds?.minLng,
      maxLat: routeBounds?.maxLat,
      maxLng: routeBounds?.maxLng,
      syncStatus: state.offlineMessage == null
          ? FitnessSyncStatus.synced
          : FitnessSyncStatus.pending,
      updatedAt: now,
    );
  }

  LiveActivityMetricsModel _metricsFor(DateTime now) {
    final startedAt = _startedAt;
    final elapsedMs =
        startedAt == null ? 0 : now.difference(startedAt).inMilliseconds;
    final movingMs = _currentMovingMs(now);
    final pausedMs = _currentPausedMs(now);
    final movingSeconds = movingMs ~/ 1000;
    final pace = _metricsCalculator.paceSecondsPerKm(
      movingSeconds: movingSeconds,
      distanceMeters: _distanceMeters,
    );
    final speed = _metricsCalculator.speedKmh(
      movingSeconds: movingSeconds,
      distanceMeters: _distanceMeters,
    );
    final activityType =
        state.activity?.activityType ?? FitnessActivityType.custom;

    return LiveActivityMetricsModel(
      elapsedMs: elapsedMs,
      movingMs: movingMs,
      pausedMs: pausedMs,
      distanceMeters: _distanceMeters,
      currentPaceSecondsPerKm: pace,
      currentSpeedKmh: speed,
      averagePaceSecondsPerKm: pace,
      averageSpeedKmh: speed,
      maxSpeedKmh: _maxSpeedKmh > 0 ? _maxSpeedKmh : speed,
      calories: _metricsCalculator.caloriesEstimate(
        type: activityType,
        movingSeconds: movingSeconds,
        distanceMeters: _distanceMeters,
      ),
      splitCount: (_distanceMeters ~/ 1000).toInt(),
      currentAltitudeMeters:
          state.routePoints.isEmpty ? null : state.routePoints.last.altitude,
    );
  }

  List<ActivitySplitModel> _splitsForCompletedActivity(
    FitnessActivityModel activity,
  ) {
    if (activity.isPoolSwimming &&
        (activity.lapCount ?? 0) > 0 &&
        (activity.poolLengthMeters ?? 0) > 0) {
      return _poolLapSplits(activity);
    }
    if (activity.distanceMeters < 250 || state.routePoints.length < 2) {
      return const [];
    }
    return _routeDistanceSplits(activity, state.routePoints);
  }

  List<ActivitySplitModel> _poolLapSplits(FitnessActivityModel activity) {
    final laps = activity.lapCount ?? 0;
    final poolLength = activity.poolLengthMeters ?? 0;
    final movingMs = activity.movingTimeSeconds * 1000;
    if (laps <= 0 || poolLength <= 0 || movingMs <= 0) return const [];

    return List<ActivitySplitModel>.generate(laps, (index) {
      final startMs = (movingMs * index / laps).round();
      final endMs = (movingMs * (index + 1) / laps).round();
      final durationMs = endMs - startMs;
      final startedAt =
          activity.startedAt?.add(Duration(milliseconds: startMs));
      final endedAt = activity.startedAt?.add(Duration(milliseconds: endMs));
      return ActivitySplitModel(
        splitId: '${activity.activityId}_lap_${index + 1}',
        splitNumber: index + 1,
        distanceMeters: poolLength.toDouble(),
        durationMs: durationMs,
        paceSecondsPerKm:
            durationMs <= 0 ? null : durationMs / 1000 / (poolLength / 1000),
        startedAt: startedAt,
        endedAt: endedAt,
      );
    });
  }

  List<ActivitySplitModel> _routeDistanceSplits(
    FitnessActivityModel activity,
    List<RoutePointModel> points,
  ) {
    final splits = <ActivitySplitModel>[];
    var splitNumber = 1;
    var nextBoundaryMeters = 1000.0;
    var splitStartDistance = 0.0;
    var cumulativeDistance = 0.0;
    var splitStartTime = points.first.timestamp;
    var previous = points.first;

    for (final point in points.skip(1)) {
      if (point.isPausePoint) {
        previous = point;
        splitStartTime = point.timestamp;
        continue;
      }

      final segmentDistance = _metricsCalculator.distanceMeters(
        startLat: previous.latitude,
        startLng: previous.longitude,
        endLat: point.latitude,
        endLng: point.longitude,
      );
      if (segmentDistance <= 0) {
        previous = point;
        continue;
      }

      while (cumulativeDistance + segmentDistance >= nextBoundaryMeters) {
        final metersIntoSegment = nextBoundaryMeters - cumulativeDistance;
        final fraction = (metersIntoSegment / segmentDistance).clamp(0.0, 1.0);
        final segmentMs =
            point.timestamp.difference(previous.timestamp).inMilliseconds;
        final boundaryTime = previous.timestamp.add(
          Duration(milliseconds: (segmentMs * fraction).round()),
        );
        final durationMs =
            boundaryTime.difference(splitStartTime).inMilliseconds;
        final splitDistance = nextBoundaryMeters - splitStartDistance;
        splits.add(
          ActivitySplitModel(
            splitId:
                '${activity.activityId}_split_${splitNumber.toString().padLeft(3, '0')}',
            splitNumber: splitNumber,
            distanceMeters: splitDistance,
            durationMs: durationMs.clamp(0, 1 << 31).toInt(),
            paceSecondsPerKm: durationMs <= 0
                ? null
                : durationMs / 1000 / (splitDistance / 1000),
            startedAt: splitStartTime,
            endedAt: boundaryTime,
          ),
        );
        splitNumber += 1;
        splitStartDistance = nextBoundaryMeters;
        splitStartTime = boundaryTime;
        nextBoundaryMeters += 1000;
      }

      cumulativeDistance += segmentDistance;
      previous = point;
    }

    final remaining = cumulativeDistance - splitStartDistance;
    if (remaining >= 250 && points.last.timestamp.isAfter(splitStartTime)) {
      final durationMs = points.last.timestamp
          .difference(splitStartTime)
          .inMilliseconds
          .clamp(0, 1 << 31);
      splits.add(
        ActivitySplitModel(
          splitId:
              '${activity.activityId}_split_${splitNumber.toString().padLeft(3, '0')}',
          splitNumber: splitNumber,
          distanceMeters: remaining,
          durationMs: durationMs.toInt(),
          paceSecondsPerKm:
              durationMs <= 0 ? null : durationMs / 1000 / (remaining / 1000),
          startedAt: splitStartTime,
          endedAt: points.last.timestamp,
        ),
      );
    }

    return splits;
  }

  int _currentMovingMs(DateTime now) {
    if (state.isPaused) return _movingBeforeCurrentResumeMs;
    final lastResumeAt = _lastResumeAt;
    if (lastResumeAt == null) return _movingBeforeCurrentResumeMs;
    return _movingBeforeCurrentResumeMs +
        now.difference(lastResumeAt).inMilliseconds;
  }

  int _currentPausedMs(DateTime now) {
    final pausedAt = _pausedAt;
    if (!state.isPaused || pausedAt == null) return _pausedMs;
    return _pausedMs + now.difference(pausedAt).inMilliseconds;
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _positionSub?.cancel();
    _locationService.stopTracking();
    super.dispose();
  }
}
