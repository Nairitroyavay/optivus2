// lib/services/task_service.dart
//
// TaskService — per ServiceContracts §2.4 and EventSystem §3.2.
// State machine: scheduled → started → paused → started → completed/abandoned
//                scheduled → skipped  (user never started it)
//
// Enforcement rules:
//   • Only one task may be in `started` state at a time.
//   • All invalid transitions throw typed AppErrors (never silent fails).
//   • Every Firestore mutation is paired with an event inside the same WriteBatch.
//   • Event payloads satisfy the full contract:
//       taskId, type, plannedStart, plannedEnd,
//       actualStart, actualEnd,
//       plannedDurationMin, actualDurationMin, driftPct,
//       reasonCategory, reasonTag

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

  /// Builds the full event payload required by the contract.
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

  /// Computes actualDurationMin and driftPct given wall-clock end, task, and
  /// any extra pause minutes accumulated in the current session (e.g. the
  /// pause that was still open when completeTask/abandonTask is called).
  ({int actualDurationMin, double driftPct}) _computeDuration(
    TaskModel task, {
    required DateTime now,
    int extraPauseMin = 0,
  }) {
    final totalPauseMin = (task.totalPauseDurationMin ?? 0) + extraPauseMin;
    final wallClockMin =
        task.actualStart != null ? now.difference(task.actualStart!).inMinutes : 0;
    final activeMin = (wallClockMin - totalPauseMin).clamp(0, wallClockMin);
    final planned = task.plannedDurationMin;
    final drift = planned > 0 ? (activeMin - planned) / planned * 100 : 0.0;
    return (
      actualDurationMin: activeMin,
      driftPct: double.parse(drift.toStringAsFixed(1)),
    );
  }

  // ── Real-time stream ─────────────────────────────────────────────────────────

  /// Stream of tasks whose plannedStart falls within [date]'s calendar day.
  Stream<List<TaskModel>> tasksFor(DateTime date) {
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

  // ── Operations ───────────────────────────────────────────────────────────────

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

  /// Transitions scheduled → started.
  ///
  /// Throws [MultipleActiveTasksError] if another task is already in `started`.
  Future<void> startTask(String taskId) async {
    // Enforce one-active-task invariant BEFORE fetching the target task.
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
    debugPrint('[TaskService] startTask $taskId');
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
    debugPrint('[TaskService] pauseTask $taskId');
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
    debugPrint('[TaskService] resumeTask $taskId');
  }

  /// Transitions started or paused → completed.
  ///
  /// Computes actualDurationMin and driftPct and writes them to Firestore.
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

    // Capture pause duration that was still open at completion time.
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
    debugPrint('[TaskService] completeTask $taskId '
        '(actual=${actualDurationMin}min, drift=$driftPct%)');
  }

  /// Transitions any non-terminal state → abandoned.
  ///
  /// Use [reason] + [reasonTag] to capture why the user abandoned.
  Future<void> abandonTask(
    String taskId, {
    AbandonReason? reason,
    String? reasonTag,
  }) async {
    final task = await _getTask(taskId);
    if (task.state == TaskState.completed ||
        task.state == TaskState.abandoned) {
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
    debugPrint('[TaskService] abandonTask $taskId');
  }

  /// Transitions scheduled → abandoned (user skips before ever starting).
  ///
  /// This is semantically distinct from [abandonTask]: no actual work happened,
  /// so actualDurationMin is 0 and driftPct reflects the full planned deficit.
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

    // No actual work: driftPct = -100 % (entire planned block missed).
    const actualDurationMin = 0;
    final planned = task.plannedDurationMin;
    final driftPct = planned > 0 ? -100.0 : 0.0;

    final updates = <String, dynamic>{
      'state': TaskState.abandoned.toJson(),
      'abandonedAt': Timestamp.fromDate(now),
      'actualDurationMin': actualDurationMin,
      'driftPct': driftPct,
      'reasonCategory': reason.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (reasonTag != null) updates['reasonTag'] = reasonTag;

    final batch = _firestore.batch();
    batch.update(docRef, updates);

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
    debugPrint('[TaskService] skipTask $taskId');
  }

  /// Toggles a subtask's checked state.
  ///
  /// Only allowed while the task is in `started` or `paused` state.
  /// Emits [EventNames.subtaskChecked] or [EventNames.subtaskUnchecked].
  Future<void> toggleSubtask(String taskId, String subtaskId) async {
    final task = await _getTask(taskId);

    if (task.state != TaskState.started && task.state != TaskState.paused) {
      throw SubtaskToggleNotAllowedError(
        taskId: taskId,
        currentState: task.state.toJson(),
      );
    }

    final subtaskIndex =
        task.subtasks.indexWhere((s) => s.id == subtaskId);
    if (subtaskIndex == -1) throw SubtaskNotFoundError(subtaskId);

    final subtask = task.subtasks[subtaskIndex];
    final nowChecked = !subtask.checked;

    final updatedSubtasks = List<Subtask>.from(task.subtasks);
    updatedSubtasks[subtaskIndex] = subtask.copyWith(checked: nowChecked);

    // Check if all subtasks will be done after this toggle — useful for
    // prompting the user to complete the task from the UI layer.
    final allDone = updatedSubtasks.every((s) => s.checked);

    final docRef = _tasksRef.doc(taskId);
    final batch = _firestore.batch();
    batch.update(docRef, {
      'subtasks': updatedSubtasks.map((s) => s.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _eventService.emit(
      eventName:
          nowChecked ? EventNames.subtaskChecked : EventNames.subtaskUnchecked,
      source: 'app',
      payload: {
        'taskId': taskId,
        'subtaskId': subtaskId,
        'checked': nowChecked,
        'allSubtasksChecked': allDone,
        // Contract fields — include for consistency with other task events.
        'type': task.type.toJson(),
        'plannedStart': task.plannedStart.toIso8601String(),
        'plannedEnd': task.plannedEnd.toIso8601String(),
        'plannedDurationMin': task.plannedDurationMin,
      },
      batch: batch,
    );

    await batch.commit();
    debugPrint(
        '[TaskService] toggleSubtask $subtaskId on $taskId → checked=$nowChecked'
        '${allDone ? ' (all done)' : ''}');
  }
}
