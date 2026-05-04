import '../core/constants/event_names.dart';
import '../models/goal_model.dart';
import '../services/event_service.dart';
import '../services/firestore_service.dart';

class GoalRepository {
  final FirestoreService _service;
  final EventService? _eventService;

  GoalRepository(
    this._service, {
    EventService? eventService,
  }) : _eventService = eventService;

  Future<List<GoalModel>> getGoals() => _service.getGoals();

  Future<GoalModel?> getGoal(String goalId) async {
    final data = await _service.getUserSubdocument(
      FirestoreService.kGoals,
      goalId,
    );
    return data == null ? null : GoalModel.fromMap(data, fallbackId: goalId);
  }

  Future<void> addGoal(GoalModel goal) => createGoal(goal);

  Future<void> createGoal(GoalModel goal) async {
    await _service.saveGoal(goal);
    await _emit(
      eventName: EventNames.identityCreated,
      payload: _goalPayload(goal),
    );
  }

  Future<void> updateGoal(GoalModel goal) async {
    final previous = await getGoal(goal.goalId);
    await _service.saveGoal(goal);

    await _emit(
      eventName: EventNames.identityUpdated,
      payload: _goalPayload(goal),
    );

    if (previous != null && previous.progress != goal.progress) {
      await _emit(
        eventName: EventNames.identityProgressChanged,
        payload: {
          ..._goalPayload(goal),
          'oldPct': previous.progress,
          'newPct': goal.progress,
          'score': goal.progress,
        },
      );
    }

    for (final habitId in _newHabitLinks(previous, goal)) {
      await _emit(
        eventName: EventNames.identityHabitLinked,
        payload: {
          ..._goalPayload(goal),
          'habitId': habitId,
        },
      );
    }

    for (final milestone in _newlyCompletedMilestones(previous, goal)) {
      await _emit(
        eventName: EventNames.milestoneCompleted,
        payload: {
          ..._goalPayload(goal),
          'milestoneId': milestone.milestoneId,
          'title': milestone.title,
        },
      );
    }
  }

  Future<void> pauseGoal(String goalId) async {
    final goal = await getGoal(goalId);
    if (goal == null) return;
    final paused = goal.copyWith(
      status: GoalStatus.paused,
      updatedAt: DateTime.now(),
    );
    await _service.saveGoal(paused);
    await _emit(
      eventName: EventNames.identityPaused,
      payload: _goalPayload(paused),
    );
  }

  Future<void> archiveGoal(String goalId) async {
    final goal = await getGoal(goalId);
    if (goal == null) return;
    final archived = goal.copyWith(
      status: GoalStatus.archived,
      archivedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _service.saveGoal(archived);
    await _emit(
      eventName: EventNames.identityArchived,
      payload: _goalPayload(archived),
    );
  }

  Future<void> linkHabit({
    required String goalId,
    required String habitId,
  }) async {
    final goal = await getGoal(goalId);
    if (goal == null) return;
    if (goal.connectedHabitIds.contains(habitId)) return;

    final updated = goal.copyWith(
      connectedHabitIds: [...goal.connectedHabitIds, habitId],
      updatedAt: DateTime.now(),
    );
    await _service.saveGoal(updated);
    await _emit(
      eventName: EventNames.identityHabitLinked,
      payload: {
        ..._goalPayload(updated),
        'habitId': habitId,
      },
    );
  }

  Map<String, dynamic> _goalPayload(GoalModel goal) {
    return {
      'goalId': goal.goalId,
      'identityId': goal.goalId,
      'identityTag': goal.identityTag,
      'status': goal.status,
    };
  }

  Set<String> _newHabitLinks(GoalModel? previous, GoalModel goal) {
    if (previous == null) return goal.connectedHabitIds.toSet();
    final oldIds = previous.connectedHabitIds.toSet();
    return goal.connectedHabitIds.where((id) => !oldIds.contains(id)).toSet();
  }

  List<GoalMilestone> _newlyCompletedMilestones(
    GoalModel? previous,
    GoalModel goal,
  ) {
    if (previous == null) {
      return goal.milestones.where((milestone) => milestone.completed).toList();
    }

    final oldCompleted = previous.milestones
        .where((milestone) => milestone.completed)
        .map((milestone) => milestone.milestoneId)
        .toSet();

    return goal.milestones
        .where(
          (milestone) =>
              milestone.completed &&
              !oldCompleted.contains(milestone.milestoneId),
        )
        .toList();
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
      source: 'goal_repository',
    );
  }
}
