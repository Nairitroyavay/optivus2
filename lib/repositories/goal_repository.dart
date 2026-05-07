import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/event_names.dart';
import '../models/goal_model.dart';
import '../services/event_service.dart';
import '../services/firestore_service.dart';
import '../services/gemini_service.dart';

class GoalArchiveSummary {
  final String title;
  final String body;
  final String source;
  final DateTime? generatedAt;

  const GoalArchiveSummary({
    required this.title,
    required this.body,
    required this.source,
    this.generatedAt,
  });

  factory GoalArchiveSummary.fromMap(Map<String, dynamic> map) {
    return GoalArchiveSummary(
      title: _asString(map['title'], fallback: 'Final summary'),
      body: _asString(map['body']),
      source: _asString(map['source'], fallback: 'unknown'),
      generatedAt: _asDateTime(map['generatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'source': source,
      'generatedAt':
          generatedAt == null ? null : Timestamp.fromDate(generatedAt!),
    };
  }
}

class ArchivedIdentityRecord {
  final GoalModel goal;
  final GoalArchiveSummary? archiveSummary;

  const ArchivedIdentityRecord({
    required this.goal,
    this.archiveSummary,
  });
}

class GoalRepository {
  final FirestoreService _service;
  final EventService? _eventService;
  final GeminiService _geminiService;

  GoalRepository(
    this._service, {
    EventService? eventService,
    GeminiService? geminiService,
  })  : _eventService = eventService,
        _geminiService = geminiService ?? GeminiService();

  Future<List<GoalModel>> getGoals() => _service.getGoals();

  Stream<List<ArchivedIdentityRecord>> watchInactiveGoals() {
    return _service
        .userCollection(FirestoreService.kGoals)
        .where('status', whereIn: [GoalStatus.paused, GoalStatus.archived])
        .snapshots()
        .map((snapshot) {
          final records = snapshot.docs.map((doc) {
            final data = doc.data();
            final summary = data['archiveSummary'];
            return ArchivedIdentityRecord(
              goal: GoalModel.fromMap(data, fallbackId: doc.id),
              archiveSummary: summary is Map
                  ? GoalArchiveSummary.fromMap(
                      Map<String, dynamic>.from(summary))
                  : null,
            );
          }).toList();
          records.sort((a, b) {
            final aDate = a.goal.archivedAt ?? a.goal.updatedAt;
            final bDate = b.goal.archivedAt ?? b.goal.updatedAt;
            return bDate.compareTo(aDate);
          });
          return records;
        });
  }

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
  Future<void> pauseGoal(
    String goalId, {
    DateTime? pausedUntil,
    int? pauseDurationDays,
  }) async {
    _validateGoalId(goalId);
    final goal = await getGoal(goalId);
    if (goal == null) return;
    if (goal.status == GoalStatus.archived) return;

    final now = DateTime.now();
    final paused = goal.copyWith(
      status: GoalStatus.paused,
      updatedAt: now,
    );
    await _service.saveUserSubdocument(
      FirestoreService.kGoals,
      paused.goalId,
      {
        ...paused.toMap(),
        'pausedAt': Timestamp.fromDate(now),
        'pausedUntil':
            pausedUntil == null ? null : Timestamp.fromDate(pausedUntil),
        'pauseDurationDays': pauseDurationDays,
      },
    );
    await _emit(
      eventName: EventNames.identityPaused,
      payload: {
        ..._goalPayload(paused),
        if (pausedUntil != null) 'pausedUntil': pausedUntil.toIso8601String(),
        if (pauseDurationDays != null) 'pauseDurationDays': pauseDurationDays,
      },
    );
  }

  /// Archives a goal and emits [EventNames.identityArchived].
  ///
  /// Note: [EventNames.identityArchived] refers to the "goal-as-identity" entity.
  Future<void> archiveGoal(String goalId) async {
    _validateGoalId(goalId);
    final goal = await getGoal(goalId);
    if (goal == null) return;
    if (goal.status == GoalStatus.archived) return;

    final now = DateTime.now();
    final summary = await _buildArchiveSummary(goal, now);
    final archived = goal.copyWith(
      status: GoalStatus.archived,
      archivedAt: now,
      updatedAt: now,
    );
    await _service.saveUserSubdocument(
      FirestoreService.kGoals,
      archived.goalId,
      {
        ...archived.toMap(),
        'archiveSummary': summary.toMap(),
      },
    );
    await _emit(
      eventName: EventNames.identityArchived,
      payload: _goalPayload(archived),
    );
  }

  Future<void> reactivateGoal(String goalId) async {
    _validateGoalId(goalId);
    final goal = await getGoal(goalId);
    if (goal == null) return;
    if (goal.status == GoalStatus.active) return;

    final reactivated = goal.copyWith(
      status: GoalStatus.active,
      updatedAt: DateTime.now(),
      clearArchivedAt: true,
    );
    await _service.saveUserSubdocument(
      FirestoreService.kGoals,
      reactivated.goalId,
      {
        ...reactivated.toMap(),
        'pausedAt': FieldValue.delete(),
        'pausedUntil': FieldValue.delete(),
        'pauseDurationDays': FieldValue.delete(),
      },
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

  Future<GoalArchiveSummary> _buildArchiveSummary(
    GoalModel goal,
    DateTime generatedAt,
  ) async {
    final tag = goal.identityTag.isNotEmpty ? goal.identityTag : goal.title;
    final prompt = '''
Write a warm, concise final summary card for an archived Optivus identity.
Identity: $tag
Why it mattered: ${goal.why.isEmpty ? 'Not provided' : goal.why}
Progress: ${goal.progress}%
Milestones completed: ${goal.milestones.where((m) => m.completed).length}/${goal.milestones.length}

Return 2 short sentences. No markdown. No shame or judgment.
''';

    try {
      final body = await _geminiService.generate(
        systemPrompt:
            'You write kind, concise identity reflection cards for Optivus.',
        userMessage: prompt,
      );
      if (body.trim().isNotEmpty) {
        return GoalArchiveSummary(
          title: 'Final summary',
          body: body.trim(),
          source: 'ai',
          generatedAt: generatedAt,
        );
      }
    } catch (_) {
      // Archive must remain available if AI generation is temporarily offline.
    }

    return GoalArchiveSummary(
      title: 'Final summary',
      body:
          '$tag was part of your progress, with ${goal.progress}% identity score when archived.',
      source: 'fallback',
      generatedAt: generatedAt,
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

DateTime? _asDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _asString(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
