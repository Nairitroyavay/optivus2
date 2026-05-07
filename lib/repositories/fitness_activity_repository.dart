// lib/repositories/fitness_activity_repository.dart
//
// Owns all Firestore access for the fitness activity domain.
// Follows the GoalRepository pattern: thin CRUD + event emission.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/event_names.dart';
import '../models/fitness_activity_model.dart';
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
            .map((d) =>
                FitnessActivityModel.fromMap(d.data(), fallbackId: d.id))
            .toList());
  }

  Future<void> deleteActivity(String activityId) async {
    // Read current activity to get the type for the event payload.
    final snap = await _activitiesRef.doc(activityId).get();
    final data = snap.data();

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

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, dynamic> _activityPayload(FitnessActivityModel activity) {
    return {
      'activityId': activity.activityId,
      'activityType': activity.activityType.toJson(),
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
