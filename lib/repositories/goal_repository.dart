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

  /// Creates a new goal and emits [EventNames.identityCreated].
  ///
  /// Note: [EventNames.identityCreated] refers to the "goal-as-identity"
  /// entity, not the identity profile document.
  Future<void> createGoal(GoalModel goal) async {
    _validateGoalId(goal.goalId);
    final now = DateTime.now();
    final created = goal.copyWith(createdAt: now, updatedAt: now);

    await _saveGoal(created);
    await _emit(
      eventName: EventNames.identityCreated,
      payload: _goalPayload(created),
    );
  }

  /// Updates an existing goal and emits [EventNames.identityUpdated].
  ///
  /// Also emits [EventNames.identityProgressChanged], [EventNames.identityHabitLinked],
  /// and [EventNames.milestoneCompleted] if the respective state changed.
  ///
  /// Note: [EventNames.identityUpdated] and related events refer to the
  /// "goal-as-identity" entity, not the identity profile document.
  Future<void> updateGoal(GoalModel goal) async {
    _validateGoalId(goal.goalId);
    final previous = await getGoal(goal.goalId);
    final updated = goal.copyWith(
      createdAt: previous?.createdAt ?? goal.createdAt,
      updatedAt: DateTime.now(),
    );

    await _saveGoal(updated);

    await _emit(
      eventName: EventNames.identityUpdated,
      payload: _goalPayload(updated),
    );

    if (previous != null && previous.progress != updated.progress) {
      await _emit(
        eventName: EventNames.identityProgressChanged,
        payload: {
          ..._goalPayload(updated),
          'oldPct': previous.progress,
          'newPct': updated.progress,
          'score': updated.progress,
        },
      );
    }

    for (final habitId in _newHabitLinks(previous, updated)) {
      await _emit(
        eventName: EventNames.identityHabitLinked,
        payload: {
          ..._goalPayload(updated),
          'habitId': habitId,
        },
      );
    }

    for (final milestone in _newlyCompletedMilestones(previous, updated)) {
      await _emit(
        eventName: EventNames.milestoneCompleted,
        payload: {
          ..._goalPayload(updated),
          'milestoneId': milestone.milestoneId,
          'title': milestone.title,
        },
      );
    }
  }

  Future<void> updateGoalProgress(String goalId, int progress) async {
    _validateGoalId(goalId);
    final goal = await getGoal(goalId);
    if (goal == null) return;

    final normalizedProgress = progress.clamp(0, 100).toInt();
    if (goal.progress == normalizedProgress) return;

    await updateGoal(
      goal.copyWith(
        progress: normalizedProgress,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Pauses a goal and emits [EventNames.identityPaused].
  ///
  /// Note: [EventNames.identityPaused] refers to the "goal-as-identity" entity.
  Future<void> pauseGoal(String goalId) async {
    _validateGoalId(goalId);
    final goal = await getGoal(goalId);
    if (goal == null) return;
    final paused = goal.copyWith(
      status: GoalStatus.paused,
      updatedAt: DateTime.now(),
    );
    await _saveGoal(paused);
    await _emit(
      eventName: EventNames.identityPaused,
      payload: _goalPayload(paused),
    );
  }

  /// Archives a goal and emits [EventNames.identityArchived].
  ///
  /// Note: [EventNames.identityArchived] refers to the "goal-as-identity" entity.
  Future<void> archiveGoal(String goalId) async {
    _validateGoalId(goalId);
    final goal = await getGoal(goalId);
    if (goal == null) return;
    final archived = goal.copyWith(
      status: GoalStatus.archived,
      archivedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _saveGoal(archived);
    await _emit(
      eventName: EventNames.identityArchived,
      payload: _goalPayload(archived),
    );
  }

  /// Links a habit to a goal and emits [EventNames.identityHabitLinked].
  ///
  /// Note: [EventNames.identityHabitLinked] refers to the "goal-as-identity" entity.
  Future<void> linkHabit({
    required String goalId,
    required String habitId,
  }) async {
    _validateGoalId(goalId);
    final goal = await getGoal(goalId);
    if (goal == null) return;
    if (goal.connectedHabitIds.contains(habitId)) return;

    final updated = goal.copyWith(
      connectedHabitIds: [...goal.connectedHabitIds, habitId],
      updatedAt: DateTime.now(),
    );
    await _saveGoal(updated);
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
    if (previous == null) return const [];

    final previousById = {
      for (final milestone in previous.milestones)
        if (milestone.milestoneId.isNotEmpty) milestone.milestoneId: milestone,
    };

    return goal.milestones.where((milestone) {
      if (!milestone.completed) return false;
      final oldMilestone = previousById[milestone.milestoneId];
      return oldMilestone != null && !oldMilestone.completed;
    }).toList();
  }

  void _validateGoalId(String goalId) {
    if (goalId.trim().isEmpty) {
      throw ArgumentError.value(goalId, 'goalId', 'Goal ID cannot be empty.');
    }
  }

  Future<void> _saveGoal(GoalModel goal) {
    return _service.saveUserSubdocument(
      FirestoreService.kGoals,
      goal.goalId,
      goal.toMap(),
    );
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
