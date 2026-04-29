import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw const NotAuthenticatedError();
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _tasksRef =>
      _firestore.collection('users').doc(_uid).collection('tasks');

  /// Real-time stream of tasks whose plannedStart falls within [date]'s day.
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

  Future<TaskModel> _getTask(String taskId) async {
    final doc = await _tasksRef.doc(taskId).get();
    if (!doc.exists) throw TaskNotFoundError(taskId);
    return TaskModel.fromFirestore(doc);
  }

  Future<void> createTask(TaskModel task) async {
    final docRef = _tasksRef.doc(task.id);
    final batch = _firestore.batch();
    
    batch.set(docRef, task.toFirestore());

    await _eventService.emit(
      eventName: EventNames.taskScheduled,
      payload: {
        'taskId': task.id,
        'type': task.type.toJson(),
        'plannedStart': task.plannedStart.toIso8601String(),
        'plannedEnd': task.plannedEnd.toIso8601String(),
      },
      batch: batch,
    );

    await batch.commit();
  }

  Future<void> startTask(String taskId) async {
    final task = await _getTask(taskId);
    if (task.state != TaskState.scheduled) {
      throw InvalidStateTransitionError(
        taskId: taskId,
        currentState: task.state.name,
        attemptedAction: 'start',
      );
    }

    final docRef = _tasksRef.doc(taskId);
    final now = DateTime.now();

    final batch = _firestore.batch();
    batch.update(docRef, {
      'state': TaskState.started.name,
      'actualStart': Timestamp.fromDate(now),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _eventService.emit(
      eventName: EventNames.taskStarted,
      payload: {
        'taskId': taskId,
        'timestamp': now.toIso8601String(),
      },
      batch: batch,
    );

    await batch.commit();
  }

  Future<void> pauseTask(String taskId) async {
    final task = await _getTask(taskId);
    if (task.state != TaskState.started) {
      throw InvalidStateTransitionError(
        taskId: taskId,
        currentState: task.state.name,
        attemptedAction: 'pause',
      );
    }

    final docRef = _tasksRef.doc(taskId);
    final now = DateTime.now();

    final batch = _firestore.batch();
    batch.update(docRef, {
      'state': TaskState.paused.name,
      'pausedAt': Timestamp.fromDate(now),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _eventService.emit(
      eventName: EventNames.taskPaused,
      payload: {
        'taskId': taskId,
        'timestamp': now.toIso8601String(),
      },
      batch: batch,
    );

    await batch.commit();
  }

  Future<void> resumeTask(String taskId) async {
    final task = await _getTask(taskId);
    if (task.state != TaskState.paused) {
      throw InvalidStateTransitionError(
        taskId: taskId,
        currentState: task.state.name,
        attemptedAction: 'resume',
      );
    }

    final docRef = _tasksRef.doc(taskId);
    final now = DateTime.now();

    final pauseDiff = now.difference(task.pausedAt ?? now);
    final newTotalPause = (task.totalPauseDurationMin ?? 0) + pauseDiff.inMinutes;

    final batch = _firestore.batch();
    batch.update(docRef, {
      'state': TaskState.started.name,
      'totalPauseDurationMin': newTotalPause,
      'pausedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _eventService.emit(
      eventName: EventNames.taskResumed,
      payload: {
        'taskId': taskId,
        'timestamp': now.toIso8601String(),
      },
      batch: batch,
    );

    await batch.commit();
  }

  Future<void> completeTask(String taskId) async {
    final task = await _getTask(taskId);
    if (task.state != TaskState.started && task.state != TaskState.paused) {
      throw InvalidStateTransitionError(
        taskId: taskId,
        currentState: task.state.name,
        attemptedAction: 'complete',
      );
    }

    final docRef = _tasksRef.doc(taskId);
    final now = DateTime.now();

    int additionalPauseMin = 0;
    if (task.state == TaskState.paused && task.pausedAt != null) {
      additionalPauseMin = now.difference(task.pausedAt!).inMinutes;
    }

    final totalPauseMin = (task.totalPauseDurationMin ?? 0) + additionalPauseMin;
    final totalDurationMin = task.actualStart != null ? now.difference(task.actualStart!).inMinutes : 0;
    int actualDurationMin = totalDurationMin - totalPauseMin;
    if (actualDurationMin < 0) actualDurationMin = 0;

    final batch = _firestore.batch();
    final updates = <String, dynamic>{
      'state': TaskState.completed.name,
      'actualEnd': Timestamp.fromDate(now),
      'actualDurationMin': actualDurationMin,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (task.state == TaskState.paused) {
      updates['totalPauseDurationMin'] = totalPauseMin;
    }
    
    batch.update(docRef, updates);

    await _eventService.emit(
      eventName: EventNames.taskCompleted,
      payload: {
        'taskId': taskId,
        'timestamp': now.toIso8601String(),
      },
      batch: batch,
    );

    await batch.commit();
  }

  Future<void> abandonTask(
    String taskId, {
    AbandonReason? reason,
    String? reasonTag,
  }) async {
    final task = await _getTask(taskId);
    if (task.state == TaskState.completed || task.state == TaskState.abandoned) {
      throw InvalidStateTransitionError(
        taskId: taskId,
        currentState: task.state.name,
        attemptedAction: 'abandon',
      );
    }

    final docRef = _tasksRef.doc(taskId);
    final now = DateTime.now();

    final batch = _firestore.batch();
    
    final updates = <String, dynamic>{
      'state': TaskState.abandoned.name,
      'abandonedAt': Timestamp.fromDate(now),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (reason != null) updates['reasonCategory'] = reason.toJson();
    if (reasonTag != null) updates['reasonTag'] = reasonTag;
    
    batch.update(docRef, updates);

    await _eventService.emit(
      eventName: EventNames.taskAbandoned,
      payload: {
        'taskId': taskId,
        'timestamp': now.toIso8601String(),
        if (reason != null) 'reasonCategory': reason.toJson(),
        if (reasonTag != null) 'reasonTag': reasonTag,
      },
      batch: batch,
    );

    await batch.commit();
  }
}
