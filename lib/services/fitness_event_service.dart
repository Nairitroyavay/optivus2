// lib/services/fitness_event_service.dart
//
// Thin coordinator for fitness-specific event emission.
// Delegates to the central EventService — never writes to Firestore directly.
//
// Per EventSystem §2: all events flow through EventService.emit().

import '../core/constants/event_names.dart';
import '../services/event_service.dart';

class FitnessEventService {
  final EventService _eventService;

  FitnessEventService({required EventService eventService})
      : _eventService = eventService;

  // ── Goals ────────────────────────────────────────────────────────────────

  Future<void> emitGoalCreated({
    required String goalId,
    required String goalType,
    required double targetValue,
    required String unit,
  }) =>
      _eventService.emit(
        eventName: EventNames.fitnessGoalCreated,
        payload: {
          'goalId': goalId,
          'goalType': goalType,
          'targetValue': targetValue,
          'unit': unit,
        },
        source: 'fitness_event_service',
      );

  Future<void> emitGoalProgressUpdated({
    required String goalId,
    required String goalType,
    required double currentValue,
    required double targetValue,
  }) =>
      _eventService.emit(
        eventName: EventNames.fitnessGoalProgressUpdated,
        payload: {
          'goalId': goalId,
          'goalType': goalType,
          'currentValue': currentValue,
          'targetValue': targetValue,
        },
        source: 'fitness_event_service',
      );

  Future<void> emitGoalCompleted({
    required String goalId,
    required String goalType,
  }) =>
      _eventService.emit(
        eventName: EventNames.fitnessGoalCompleted,
        payload: {
          'goalId': goalId,
          'goalType': goalType,
        },
        source: 'fitness_event_service',
      );

  Future<void> emitWeeklyDistanceGoalCompleted({
    required String goalId,
    required double distanceKm,
  }) =>
      _eventService.emit(
        eventName: EventNames.weeklyDistanceGoalCompleted,
        payload: {
          'goalId': goalId,
          'distanceKm': distanceKm,
        },
        source: 'fitness_event_service',
      );

  // ── Streaks ──────────────────────────────────────────────────────────────

  Future<void> emitFitnessStreakUpdated({
    required String streakId,
    required int currentCount,
    required String action, // 'extended', 'broken', 'paused'
  }) =>
      _eventService.emit(
        eventName: EventNames.fitnessStreakUpdated,
        payload: {
          'streakId': streakId,
          'currentCount': currentCount,
          'action': action,
        },
        source: 'fitness_event_service',
      );

  // ── AI Coach Feedback ────────────────────────────────────────────────────

  Future<void> emitAiFeedbackRequested({
    required String activityId,
    required String activityType,
  }) =>
      _eventService.emit(
        eventName: EventNames.fitnessAiFeedbackRequested,
        payload: {
          'activityId': activityId,
          'activityType': activityType,
        },
        source: 'fitness_event_service',
      );

  Future<void> emitAiFeedbackGenerated({
    required String activityId,
    required String activityType,
  }) =>
      _eventService.emit(
        eventName: EventNames.fitnessAiFeedbackGenerated,
        payload: {
          'activityId': activityId,
          'activityType': activityType,
        },
        source: 'fitness_event_service',
      );

  // ── Routine-Fitness linking ──────────────────────────────────────────────

  Future<void> emitRoutineFitnessStarted({
    required String activityId,
    required String activityType,
    required String routineTaskId,
  }) =>
      _eventService.emit(
        eventName: EventNames.routineFitnessStarted,
        payload: {
          'activityId': activityId,
          'activityType': activityType,
          'routineTaskId': routineTaskId,
        },
        source: 'fitness_event_service',
      );

  Future<void> emitRoutineFitnessCompleted({
    required String activityId,
    required String activityType,
    required String routineTaskId,
  }) =>
      _eventService.emit(
        eventName: EventNames.routineFitnessCompleted,
        payload: {
          'activityId': activityId,
          'activityType': activityType,
          'routineTaskId': routineTaskId,
        },
        source: 'fitness_event_service',
      );
}
