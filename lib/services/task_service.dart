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

  Future<void> completeTask(String taskId) async {
    final docRef = _tasksRef.doc(taskId);
    final now = DateTime.now();

    final batch = _firestore.batch();
    batch.update(docRef, {
      'state': TaskState.completed.name,
      'actualEnd': Timestamp.fromDate(now),
      'updatedAt': FieldValue.serverTimestamp(),
    });

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
