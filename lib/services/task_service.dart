// lib/services/task_service.dart
//
// TaskService — per ServiceContracts §2.4 and EventSystem §3, §5.
//
// State machine:
//   scheduled → started → paused/resumed → completed
//   scheduled → skipped
//   started/paused → abandoned
//   completed, skipped, abandoned are terminal.
//
// Enforcement rules:
//   • Only one task may be in `started` state at a time.
//   • All invalid transitions throw typed AppErrors (never silent fails).
//   • Every Firestore mutation is paired with an event inside the same WriteBatch.
//   • On every terminal transition (complete / abandon / skip) a derived
//     /users/{uid}/task_outcomes/{taskId} document is written for analytics.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:optivus2/core/constants/event_names.dart';
import 'package:optivus2/core/errors/app_errors.dart';
import 'package:optivus2/models/task_model.dart';
import 'package:optivus2/services/event_service.dart';

class TaskService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final EventService _eventService;

  TaskService({
    required EventService eventService,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _eventService = eventService,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw const NotAuthenticatedError();
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _tasksRef =>
      _firestore.collection('users').doc(_uid).collection('tasks');

  CollectionReference<Map<String, dynamic>> get _outcomesRef =>
      _firestore.collection('users').doc(_uid).collection('task_outcomes');

  Future<TaskModel> _getTask(String taskId) async {
    final doc = await _tasksRef.doc(taskId).get();
    if (!doc.exists) throw TaskNotFoundError(taskId);
    return TaskModel.fromFirestore(doc);
  }

  /// Returns the ID of any currently-started task, or null if none.
  Future<String?> _activeTaskId() async {
    final snap = await _tasksRef
        .where('state', isEqualTo: TaskState.started.toJson())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  Map<String, dynamic> _buildPayload(
    TaskModel task, {
    DateTime? actualEnd,
    int? actualDurationMin,
    double? driftPct,
    AbandonReason? reasonCategory,
    String? reasonTag,
  }) {
    final payload = <String, dynamic>{
      'taskId': task.id,
      'type': task.type.toJson(),
      'plannedStart': task.plannedStart.toIso8601String(),
      'plannedEnd': task.plannedEnd.toIso8601String(),
      'plannedDurationMin': task.plannedDurationMin,
    };
    if (task.actualStart != null) {
      payload['actualStart'] = task.actualStart!.toIso8601String();
    }
    if (actualEnd != null) {
      payload['actualEnd'] = actualEnd.toIso8601String();
    } else if (task.actualEnd != null) {
      payload['actualEnd'] = task.actualEnd!.toIso8601String();
    }
    if (actualDurationMin != null) {
      payload['actualDurationMin'] = actualDurationMin;
    } else if (task.actualDurationMin != null) {
      payload['actualDurationMin'] = task.actualDurationMin;
    }
    final resolvedDrift = driftPct ?? task.driftPct;
    if (resolvedDrift != null) payload['driftPct'] = resolvedDrift;
    final rc = reasonCategory ?? task.reasonCategory;
    if (rc != null) payload['reasonCategory'] = rc.toJson();
    final rt = reasonTag ?? task.reasonTag;
    if (rt != null) payload['reasonTag'] = rt;
    return payload;
  }

  ({int actualDurationMin, double driftPct}) _computeDuration(
    TaskModel task, {
    required DateTime now,
    int extraPauseMin = 0,
  }) {
    final totalPauseMin = (task.totalPauseDurationMin ?? 0) + extraPauseMin;
    final wallClockMin = task.actualStart != null
        ? now.difference(task.actualStart!).inMinutes
        : 0;
    final activeMin = (wallClockMin - totalPauseMin).clamp(0, wallClockMin);
    final planned = task.plannedDurationMin;
    final drift = planned > 0 ? (activeMin - planned) / planned * 100 : 0.0;
    return (
      actualDurationMin: activeMin,
      driftPct: double.parse(drift.toStringAsFixed(1)),
    );
  }

  /// Writes a /users/{uid}/task_outcomes/{taskId} doc within the given batch.
  void _writeTaskOutcome(
    WriteBatch batch,
    TaskModel task, {
    required String outcome, // completed | abandoned | skipped
    required DateTime endedAt,
    required int actualDurationMin,
    required double driftPct,
  }) {
    final ref = _outcomesRef.doc(task.id);
    final startedAt = task.actualStart;
    final startDriftMin = startedAt?.difference(task.plannedStart).inMinutes;
    final completedSubtasks =
        task.subtasks.where((s) => s.checked).length;

    batch.set(ref, {
      'taskId': task.id,
      'outcome': outcome,
      'plannedStart': Timestamp.fromDate(task.plannedStart),
      'plannedEnd': Timestamp.fromDate(task.plannedEnd),
      'plannedDurationMin': task.plannedDurationMin,
      if (startedAt != null) 'actualStart': Timestamp.fromDate(startedAt),
      'actualEnd': Timestamp.fromDate(endedAt),
      if (startDriftMin != null) 'startDriftMin': startDriftMin,
      'actualDurationMin': actualDurationMin,
      'durationDriftPct': driftPct,
      'subtasksPlanned': task.subtasks.length,
      'subtasksCompleted': completedSubtasks,
      'weekday': _weekdayName(task.plannedStart),
      'timeOfDayBucket': _timeOfDayBucket(task.plannedStart),
      if (task.reasonCategory != null)
        'reasonCategory': task.reasonCategory!.toJson(),
      if (task.reasonTag != null) 'reasonTag': task.reasonTag,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static String _weekdayName(DateTime dt) {
    const names = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    return names[dt.weekday - 1];
  }

  static String _timeOfDayBucket(DateTime dt) {
    final h = dt.hour;
    if (h >= 5 && h < 11) return 'morning';
    if (h >= 11 && h < 14) return 'midday';
    if (h >= 14 && h < 17) return 'afternoon';
    if (h >= 17 && h < 21) return 'evening';
    return 'night';
  }

  // ── Real-time streams ──────────────────────────────────────────────────────

  /// Stream of a single task by ID. Emits null when the doc does not exist.
  Stream<TaskModel?> watchTask(String taskId) {
    return _tasksRef.doc(taskId).snapshots().map(
          (doc) => doc.exists ? TaskModel.fromFirestore(doc) : null,
        );
  }

  /// Stream of tasks whose plannedStart falls within [date]'s calendar day.
  Stream<List<TaskModel>> watchTasksForDay(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    return _tasksRef
        .where('plannedStart',
            isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('plannedStart', isLessThan: Timestamp.fromDate(dayEnd))
        .orderBy('plannedStart')
        .snapshots()
        .map((snap) => snap.docs.map(TaskModel.fromFirestore).toList());
  }

  /// Stream of tasks whose plannedStart falls within the [days]-day window
  /// starting at [from]'s calendar day.
  Stream<List<TaskModel>> watchTasksForWindow(DateTime from, {int days = 14}) {
    final dayStart = DateTime(from.year, from.month, from.day);
    final windowEnd = dayStart.add(Duration(days: days));

    return _tasksRef
        .where('plannedStart',
            isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('plannedStart', isLessThan: Timestamp.fromDate(windowEnd))
        .orderBy('plannedStart')
        .snapshots()
        .map((snap) => snap.docs.map(TaskModel.fromFirestore).toList());
  }

  /// Stream of the currently-started task. Emits null when none is active.
  Stream<TaskModel?> watchActiveTask() {
    return _tasksRef
        .where('state', isEqualTo: TaskState.started.toJson())
        .limit(1)
        .snapshots()
        .map((snap) =>
            snap.docs.isEmpty ? null : TaskModel.fromFirestore(snap.docs.first));
  }

  // ── Operations ──────────────────────────────────────────────────────────────

  /// Creates a new task doc and emits `task_scheduled`.
  Future<void> createTask(TaskModel task) async {
    if (!task.plannedEnd.isAfter(task.plannedStart)) {
      throw const InvalidTimeRangeError();
    }
    if (task.plannedDurationMin > 480) throw const TaskTooLongError();

    final docRef = _tasksRef.doc(task.id);
    final batch = _firestore.batch();
    batch.set(docRef, task.toFirestore());

    await _eventService.emit(
      eventName: EventNames.taskScheduled,
      source: 'app',
      payload: _buildPayload(task),
      batch: batch,
    );

    await batch.commit();
    debugPrint('[TaskService] createTask ${task.id}');
  }

  static const int _kBatchChunk = 450;

  /// Idempotently synchronizes generated routine tasks with Firestore.
  ///
  /// Uses merge:true so execution state (started, paused, completed) is never
  /// clobbered. Emits `task_scheduled` for tasks falling within today + tomorrow.
  Future<void> syncRoutineTasks(List<TaskModel> tasks) async {
    if (tasks.isEmpty) return;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final emitWindowEnd = todayStart.add(const Duration(days: 2));

    for (int start = 0; start < tasks.length; start += _kBatchChunk) {
      final chunk = tasks.sublist(
        start,
        (start + _kBatchChunk).clamp(0, tasks.length),
      );

      final batch = _firestore.batch();

      for (final task in chunk) {
        final docRef = _tasksRef.doc(task.id);

        final updates = <String, dynamic>{
          'taskId': task.id,
          'type': task.type.toJson(),
          if (task.parentRoutine != null) 'parentRoutine': task.parentRoutine,
          'title': task.title,
          if (task.emoji != null) 'emoji': task.emoji,
          if (task.color != null) 'color': task.color,
          'identityTags': task.identityTags,
          'alarmTier': task.alarmTier.name,
          'plannedStart': Timestamp.fromDate(task.plannedStart),
          'plannedEnd': Timestamp.fromDate(task.plannedEnd),
          'subtasks': task.subtasks.map((s) => s.toMap()).toList(),
          'schemaVersion': task.schemaVersion,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        batch.set(docRef, updates, SetOptions(merge: true));

        if (!task.plannedStart.isBefore(todayStart) &&
            task.plannedStart.isBefore(emitWindowEnd)) {
          await _eventService.emit(
            eventName: EventNames.taskScheduled,
            source: 'routine_sync',
            payload: _buildPayload(task),
            batch: batch,
          );
        }
      }

      await batch.commit();
    }

    debugPrint('[TaskService] syncRoutineTasks total ${tasks.length} tasks synced');
  }

  /// Transitions scheduled → started.
  Future<void> startTask(String taskId) async {
    final existingActiveId = await _activeTaskId();
    if (existingActiveId != null && existingActiveId != taskId) {
      throw MultipleActiveTasksError(existingActiveId);
    }

    final task = await _getTask(taskId);
    if (task.state != TaskState.scheduled) {
      throw InvalidStateTransitionError(
        taskId: taskId,
        currentState: task.state.toJson(),
        attemptedAction: 'start',
      );
    }

    final docRef = _tasksRef.doc(taskId);
    final now = DateTime.now();

    final batch = _firestore.batch();
    batch.update(docRef, {
      'state': TaskState.started.toJson(),
      'actualStart': Timestamp.fromDate(now),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _eventService.emit(
      eventName: EventNames.taskStarted,
      source: 'app',
      payload: _buildPayload(task.copyWith(actualStart: now)),
      batch: batch,
    );

    await batch.commit();
  }

  /// Transitions started → paused.
  Future<void> pauseTask(String taskId) async {
    final task = await _getTask(taskId);
    if (task.state != TaskState.started) {
      throw InvalidStateTransitionError(
        taskId: taskId,
        currentState: task.state.toJson(),
        attemptedAction: 'pause',
      );
    }

    final docRef = _tasksRef.doc(taskId);
    final now = DateTime.now();

    final batch = _firestore.batch();
    batch.update(docRef, {
      'state': TaskState.paused.toJson(),
      'pausedAt': Timestamp.fromDate(now),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _eventService.emit(
      eventName: EventNames.taskPaused,
      source: 'app',
      payload: _buildPayload(task),
      batch: batch,
    );

    await batch.commit();
  }

  /// Transitions paused → started, accumulating pause time.
  Future<void> resumeTask(String taskId) async {
    final task = await _getTask(taskId);
    if (task.state != TaskState.paused) {
      throw InvalidStateTransitionError(
        taskId: taskId,
        currentState: task.state.toJson(),
        attemptedAction: 'resume',
      );
    }

    final docRef = _tasksRef.doc(taskId);
    final now = DateTime.now();
    final pauseDiff = now.difference(task.pausedAt ?? now);
    final newTotalPause =
        (task.totalPauseDurationMin ?? 0) + pauseDiff.inMinutes;

    final batch = _firestore.batch();
    batch.update(docRef, {
      'state': TaskState.started.toJson(),
      'totalPauseDurationMin': newTotalPause,
      'pausedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _eventService.emit(
      eventName: EventNames.taskResumed,
      source: 'app',
      payload: _buildPayload(
        task.copyWith(totalPauseDurationMin: newTotalPause, clearPausedAt: true),
      ),
      batch: batch,
    );

    await batch.commit();
  }

  /// Transitions started or paused → completed.
  Future<void> completeTask(String taskId) async {
    final task = await _getTask(taskId);
    if (task.state != TaskState.started && task.state != TaskState.paused) {
      throw InvalidStateTransitionError(
        taskId: taskId,
        currentState: task.state.toJson(),
        attemptedAction: 'complete',
      );
    }

    final docRef = _tasksRef.doc(taskId);
    final now = DateTime.now();

    int extraPauseMin = 0;
    if (task.state == TaskState.paused && task.pausedAt != null) {
      extraPauseMin = now.difference(task.pausedAt!).inMinutes;
    }

    final (:actualDurationMin, :driftPct) =
        _computeDuration(task, now: now, extraPauseMin: extraPauseMin);
    final totalPauseMin = (task.totalPauseDurationMin ?? 0) + extraPauseMin;

    final updates = <String, dynamic>{
      'state': TaskState.completed.toJson(),
      'actualEnd': Timestamp.fromDate(now),
      'actualDurationMin': actualDurationMin,
      'driftPct': driftPct,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (extraPauseMin > 0) updates['totalPauseDurationMin'] = totalPauseMin;

    final batch = _firestore.batch();
    batch.update(docRef, updates);

    _writeTaskOutcome(
      batch,
      task.copyWith(actualEnd: now),
      outcome: 'completed',
      endedAt: now,
      actualDurationMin: actualDurationMin,
      driftPct: driftPct,
    );

    await _eventService.emit(
      eventName: EventNames.taskCompleted,
      source: 'app',
      payload: _buildPayload(
        task,
        actualEnd: now,
        actualDurationMin: actualDurationMin,
        driftPct: driftPct,
      ),
      batch: batch,
    );

    await batch.commit();
  }

  /// Transitions started/paused → abandoned.
  Future<void> abandonTask(
    String taskId, {
    AbandonReason? reason,
    String? reasonTag,
  }) async {
    final task = await _getTask(taskId);
    if (task.state.isTerminal) {
      throw InvalidStateTransitionError(
        taskId: taskId,
        currentState: task.state.toJson(),
        attemptedAction: 'abandon',
      );
    }
    if (task.state == TaskState.scheduled) {
      // scheduled → abandoned is not a valid path; use skipTask instead.
      throw InvalidStateTransitionError(
        taskId: taskId,
        currentState: task.state.toJson(),
        attemptedAction: 'abandon',
      );
    }

    final docRef = _tasksRef.doc(taskId);
    final now = DateTime.now();

    int extraPauseMin = 0;
    if (task.state == TaskState.paused && task.pausedAt != null) {
      extraPauseMin = now.difference(task.pausedAt!).inMinutes;
    }

    final (:actualDurationMin, :driftPct) =
        _computeDuration(task, now: now, extraPauseMin: extraPauseMin);
    final totalPauseMin = (task.totalPauseDurationMin ?? 0) + extraPauseMin;

    final updates = <String, dynamic>{
      'state': TaskState.abandoned.toJson(),
      'abandonedAt': Timestamp.fromDate(now),
      'actualDurationMin': actualDurationMin,
      'driftPct': driftPct,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (extraPauseMin > 0) updates['totalPauseDurationMin'] = totalPauseMin;
    if (reason != null) updates['reasonCategory'] = reason.toJson();
    if (reasonTag != null) updates['reasonTag'] = reasonTag;

    final batch = _firestore.batch();
    batch.update(docRef, updates);

    _writeTaskOutcome(
      batch,
      task.copyWith(
        actualEnd: now,
        reasonCategory: reason,
        reasonTag: reasonTag,
      ),
      outcome: 'abandoned',
      endedAt: now,
      actualDurationMin: actualDurationMin,
      driftPct: driftPct,
    );

    await _eventService.emit(
      eventName: EventNames.taskAbandoned,
      source: 'app',
      payload: _buildPayload(
        task,
        actualEnd: now,
        actualDurationMin: actualDurationMin,
        driftPct: driftPct,
        reasonCategory: reason,
        reasonTag: reasonTag,
      ),
      batch: batch,
    );

    await batch.commit();
  }

  /// Transitions scheduled → skipped (terminal).
  Future<void> skipTask(
    String taskId, {
    AbandonReason reason = AbandonReason.userSkipped,
    String? reasonTag,
  }) async {
    final task = await _getTask(taskId);
    if (task.state != TaskState.scheduled) {
      throw TaskSkippedFromInvalidStateError(
        taskId: taskId,
        currentState: task.state.toJson(),
      );
    }

    final docRef = _tasksRef.doc(taskId);
    final now = DateTime.now();

    const actualDurationMin = 0;
    final planned = task.plannedDurationMin;
    final driftPct = planned > 0 ? -100.0 : 0.0;

    final updates = <String, dynamic>{
      'state': TaskState.skipped.toJson(),
      'skippedAt': Timestamp.fromDate(now),
      'actualDurationMin': actualDurationMin,
      'driftPct': driftPct,
      'reasonCategory': reason.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (reasonTag != null) updates['reasonTag'] = reasonTag;

    final batch = _firestore.batch();
    batch.update(docRef, updates);

    _writeTaskOutcome(
      batch,
      task.copyWith(reasonCategory: reason, reasonTag: reasonTag),
      outcome: 'skipped',
      endedAt: now,
      actualDurationMin: actualDurationMin,
      driftPct: driftPct,
    );

    await _eventService.emit(
      eventName: EventNames.taskSkipped,
      source: 'app',
      payload: _buildPayload(
        task,
        actualDurationMin: actualDurationMin,
        driftPct: driftPct,
        reasonCategory: reason,
        reasonTag: reasonTag,
      ),
      batch: batch,
    );

    await batch.commit();
  }

  /// Deletes a task doc and emits `task_deleted`. The corresponding
  /// task_outcomes document (if any) is left intact for analytics.
  Future<void> deleteTask(String taskId) async {
    final task = await _getTask(taskId);

    final docRef = _tasksRef.doc(taskId);
    final batch = _firestore.batch();
    batch.delete(docRef);

    await _eventService.emit(
      eventName: EventNames.taskDeleted,
      source: 'app',
      payload: _buildPayload(task),
      batch: batch,
    );

    await batch.commit();
  }

  /// Marks [subtaskId] as checked. Idempotent — no-op + no event if already checked.
  Future<void> checkSubtask(String taskId, String subtaskId) =>
      _setSubtaskChecked(taskId, subtaskId, checked: true);

  /// Marks [subtaskId] as unchecked. Idempotent — no-op + no event if already unchecked.
  Future<void> uncheckSubtask(String taskId, String subtaskId) =>
      _setSubtaskChecked(taskId, subtaskId, checked: false);

  Future<void> _setSubtaskChecked(
    String taskId,
    String subtaskId, {
    required bool checked,
  }) async {
    final task = await _getTask(taskId);

    if (task.state != TaskState.started && task.state != TaskState.paused) {
      throw SubtaskToggleNotAllowedError(
        taskId: taskId,
        currentState: task.state.toJson(),
      );
    }

    final idx = task.subtasks.indexWhere((s) => s.id == subtaskId);
    if (idx == -1) throw SubtaskNotFoundError(subtaskId);

    final subtask = task.subtasks[idx];
    if (subtask.checked == checked) return; // idempotent

    final updated = List<Subtask>.from(task.subtasks);
    updated[idx] = subtask.copyWith(checked: checked);
    final allDone = updated.every((s) => s.checked);

    final docRef = _tasksRef.doc(taskId);
    final batch = _firestore.batch();
    batch.update(docRef, {
      'subtasks': updated.map((s) => s.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _eventService.emit(
      eventName:
          checked ? EventNames.subtaskChecked : EventNames.subtaskUnchecked,
      source: 'app',
      payload: {
        'taskId': taskId,
        'subtaskId': subtaskId,
        'checked': checked,
        'allSubtasksChecked': allDone,
        'type': task.type.toJson(),
        'plannedStart': task.plannedStart.toIso8601String(),
        'plannedEnd': task.plannedEnd.toIso8601String(),
        'plannedDurationMin': task.plannedDurationMin,
      },
      batch: batch,
    );

    await batch.commit();
  }
}
