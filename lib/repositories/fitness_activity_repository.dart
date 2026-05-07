// lib/repositories/fitness_activity_repository.dart
//
// Owns all Firestore access for the fitness activity domain.
// Follows the GoalRepository pattern: thin CRUD + event emission.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/event_names.dart';
import '../models/activity_split_model.dart';
import '../models/fitness_activity_model.dart';
import '../models/heart_rate_sample_model.dart';
import '../models/route_point_model.dart';
import '../services/event_service.dart';
import '../services/firestore_service.dart';

class FitnessActivityRepository {
  final FirestoreService _service;
  final EventService? _eventService;

  FitnessActivityRepository(
    this._service, {
    EventService? eventService,
  }) : _eventService = eventService;

  // ── Collection references ──────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _activitiesRef =>
      _service.userCollection(FirestoreService.kFitnessActivities);

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<void> createActivity(FitnessActivityModel activity) async {
    await _activitiesRef.doc(activity.activityId).set(activity.toMap());

    await _emit(
      eventName: EventNames.fitnessActivityStarted,
      payload: _activityPayload(activity),
    );
  }

  Future<void> updateActivity(FitnessActivityModel activity) async {
    await _activitiesRef
        .doc(activity.activityId)
        .set(activity.toMap(), SetOptions(merge: true));
  }

  Future<void> completeActivity(FitnessActivityModel activity) async {
    final ref = _activitiesRef.doc(activity.activityId);
    final snap = await ref.get();
    if (snap.exists) {
      final current = FitnessActivityModel.fromMap(
        snap.data()!,
        fallbackId: snap.id,
      );
      if (current.status == FitnessActivityStatus.completed) return;
    }

    final completed = activity.copyWith(
      status: FitnessActivityStatus.completed,
      endedAt: activity.endedAt ?? DateTime.now(),
    );
    await ref.set(completed.toMap(), SetOptions(merge: true));

    await _emit(
      eventName: EventNames.fitnessActivityCompleted,
      payload: _completedActivityPayload(completed),
    );
    final typeEventName = _completedEventName(completed.activityType);
    if (typeEventName != EventNames.fitnessActivityCompleted) {
      await _emit(
        eventName: typeEventName,
        payload: _completedActivityPayload(completed),
      );
    }
    if (completed.hasRoute) {
      await _emit(
        eventName: EventNames.routeSaved,
        payload: _completedActivityPayload(completed),
      );
    }
  }

  Future<void> pauseActivity(FitnessActivityModel activity) async {
    await updateActivity(
        activity.copyWith(status: FitnessActivityStatus.paused));
    await _emit(
      eventName: EventNames.fitnessActivityPaused,
      payload: _activityPayload(activity),
    );
  }

  Future<void> resumeActivity(FitnessActivityModel activity) async {
    await updateActivity(
        activity.copyWith(status: FitnessActivityStatus.active));
    await _emit(
      eventName: EventNames.fitnessActivityResumed,
      payload: _activityPayload(activity),
    );
  }

  Future<void> cancelActivity(FitnessActivityModel activity) async {
    await updateActivity(activity.copyWith(
      status: FitnessActivityStatus.cancelled,
      endedAt: DateTime.now(),
    ));
    await _emit(
      eventName: EventNames.fitnessActivityCancelled,
      payload: _activityPayload(activity),
    );
  }

  Stream<FitnessActivityModel?> watchActivity(String activityId) {
    return _activitiesRef.doc(activityId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return FitnessActivityModel.fromMap(
        snap.data()!,
        fallbackId: snap.id,
      );
    });
  }

  Stream<List<FitnessActivityModel>> watchActivityHistory({int limit = 50}) {
    return _activitiesRef
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map(
                (d) => FitnessActivityModel.fromMap(d.data(), fallbackId: d.id))
            .toList());
  }

  Future<void> deleteActivity(String activityId) async {
    await discardActivityCascade(
      uid: FirebaseAuth.instance.currentUser?.uid ?? '',
      activityId: activityId,
    );
  }

  Future<void> discardActivityCascade({
    required String uid,
    required String activityId,
  }) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (uid.isNotEmpty && currentUid != null && uid != currentUid) {
      throw StateError('Cannot discard another user\'s fitness activity.');
    }

    final snap = await _activitiesRef.doc(activityId).get();
    final data = snap.data();

    await _deleteSubcollection(activityId, 'routePoints');
    await _deleteSubcollection(activityId, 'splits');
    await _deleteSubcollection(activityId, 'heartRateSamples');
    await _activitiesRef.doc(activityId).delete();

    if (data != null) {
      final activity =
          FitnessActivityModel.fromMap(data, fallbackId: activityId);
      await _emit(
        eventName: EventNames.fitnessActivityDiscarded,
        payload: _activityPayload(activity),
      );
    }
  }

  CollectionReference<Map<String, dynamic>> _routePointsRef(
    String activityId,
  ) {
    return _activitiesRef.doc(activityId).collection('routePoints');
  }

  CollectionReference<Map<String, dynamic>> _splitsRef(String activityId) {
    return _activitiesRef.doc(activityId).collection('splits');
  }

  CollectionReference<Map<String, dynamic>> _heartRateSamplesRef(
    String activityId,
  ) {
    return _activitiesRef.doc(activityId).collection('heartRateSamples');
  }

  Future<void> saveRoutePoint(
    String activityId,
    RoutePointModel point,
  ) async {
    await _routePointsRef(activityId).doc(point.pointId).set(point.toMap());
  }

  Future<void> saveRoutePointsBatch(
    String activityId,
    List<RoutePointModel> points,
  ) async {
    if (points.isEmpty) return;

    for (var start = 0; start < points.length; start += 450) {
      final batch = FirebaseFirestore.instance.batch();
      final chunk = points.skip(start).take(450);
      for (final point in chunk) {
        batch.set(
            _routePointsRef(activityId).doc(point.pointId), point.toMap());
      }
      await batch.commit();
    }
  }

  Stream<List<RoutePointModel>> watchRoutePoints(String activityId) {
    return _routePointsRef(activityId).orderBy('sequence').snapshots().map(
        (snap) => snap.docs
            .map((d) => RoutePointModel.fromMap(d.data(), fallbackId: d.id))
            .toList());
  }

  Future<void> saveSplits(
    String activityId,
    List<ActivitySplitModel> splits,
  ) async {
    await _deleteSubcollection(activityId, 'splits');
    if (splits.isEmpty) return;

    for (var start = 0; start < splits.length; start += 450) {
      final batch = FirebaseFirestore.instance.batch();
      for (final split in splits.skip(start).take(450)) {
        batch.set(_splitsRef(activityId).doc(split.splitId), split.toMap());
      }
      await batch.commit();
    }
  }

  Stream<List<ActivitySplitModel>> watchSplits(String activityId) {
    return _splitsRef(activityId).orderBy('splitNumber').snapshots().map(
          (snap) => snap.docs
              .map((d) => ActivitySplitModel.fromMap(
                    d.data(),
                    fallbackId: d.id,
                  ))
              .toList(),
        );
  }

  Future<void> saveHeartRateSamples(
    String activityId,
    List<HeartRateSampleModel> samples,
  ) async {
    if (samples.isEmpty) return;

    for (var start = 0; start < samples.length; start += 450) {
      final batch = FirebaseFirestore.instance.batch();
      for (final sample in samples.skip(start).take(450)) {
        batch.set(
          _heartRateSamplesRef(activityId).doc(sample.sampleId),
          sample.toMap(),
        );
      }
      await batch.commit();
    }
  }

  Stream<List<HeartRateSampleModel>> watchHeartRateSamples(String activityId) {
    return _heartRateSamplesRef(activityId)
        .orderBy('timestamp')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => HeartRateSampleModel.fromMap(
                    d.data(),
                    fallbackId: d.id,
                  ))
              .toList(),
        );
  }

  Future<void> emitRouteReviewOpened(FitnessActivityModel activity) {
    return _emit(
      eventName: EventNames.routeReviewOpened,
      payload: _activityPayload(activity),
    );
  }

  Future<void> _deleteSubcollection(
    String activityId,
    String collectionId,
  ) async {
    final ref = _activitiesRef.doc(activityId).collection(collectionId);

    while (true) {
      final snap = await ref.limit(450).get();
      if (snap.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> emitRouteTrackingStarted(FitnessActivityModel activity) {
    return _emit(
      eventName: EventNames.routeTrackingStarted,
      payload: _activityPayload(activity),
    );
  }

  Future<void> emitRouteTrackingStopped(FitnessActivityModel activity) {
    return _emit(
      eventName: EventNames.routeTrackingStopped,
      payload: _activityPayload(activity),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, dynamic> _activityPayload(FitnessActivityModel activity) {
    return {
      'uid': FirebaseAuth.instance.currentUser?.uid ?? '',
      'activityId': activity.activityId,
      'activityType': activity.activityType.toJson(),
      'source': 'optivus_fitness',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> _completedActivityPayload(
    FitnessActivityModel activity,
  ) {
    return {
      ..._activityPayload(activity),
      'distanceMeters': activity.distanceMeters,
      'durationSeconds': activity.durationSeconds,
      'movingTimeSeconds': activity.movingTimeSeconds,
      'caloriesEstimate': activity.calories ?? 0,
      'hasRoute': activity.hasRoute,
    };
  }

  String _completedEventName(FitnessActivityType type) {
    return switch (type) {
      FitnessActivityType.running => EventNames.runningActivityCompleted,
      FitnessActivityType.walking => EventNames.walkingActivityCompleted,
      FitnessActivityType.cycling => EventNames.cyclingActivityCompleted,
      FitnessActivityType.hiking => EventNames.hikingActivityCompleted,
      FitnessActivityType.swimming => EventNames.swimmingActivityCompleted,
      FitnessActivityType.gymWorkout => EventNames.gymActivityCompleted,
      FitnessActivityType.custom => EventNames.fitnessActivityCompleted,
    };
  }

  Future<void> _emit({
    required String eventName,
    required Map<String, dynamic> payload,
  }) async {
    final eventService = _eventService;
    if (eventService == null) return;
    await eventService.emit(
      eventName: eventName,
      payload: payload,
      source: 'fitness_activity_repository',
    );
  }
}
