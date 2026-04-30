import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task_model.dart';
import '../models/goal_model.dart';

class FirestoreService {
  static const List<String> userOwnedCollectionIds = [
    'tasks',
    'habits',
    'habit_logs',
    'goals',
    'streaks',
    'events',
    'events_recent',
    'coach_messages',
    'coach_speak_log',
    'dailySummaries',
  ];

  static const int _deleteBatchSize = 400;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  FirestoreService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Current authenticated user's UID. Throws if not logged in.
  String get uid => _auth.currentUser!.uid;

  /// Root document for the current user: /users/{uid}
  DocumentReference<Map<String, dynamic>> get userDoc =>
      _db.collection('users').doc(uid);

  // ── User Profile ─────────────────────────────────────────────────────────

  Future<void> saveUserProfile(Map<String, dynamic> data,
          {bool merge = false}) =>
      userDoc.set(data, merge ? SetOptions(merge: true) : null);

  Future<Map<String, dynamic>?> getUserProfile() async {
    final doc = await userDoc.get();
    return doc.exists ? doc.data() : null;
  }

  Future<void> saveUserSubdocument(
    String collectionPath,
    String docId,
    Map<String, dynamic> data, {
    bool merge = true,
  }) =>
      userDoc
          .collection(collectionPath)
          .doc(docId)
          .set(data, merge ? SetOptions(merge: true) : null);

  Future<Map<String, dynamic>?> getUserSubdocument(
    String collectionPath,
    String docId,
  ) async {
    final doc = await userDoc.collection(collectionPath).doc(docId).get();
    return doc.exists ? doc.data() : null;
  }

  // ── Tasks (subcollection: /users/{uid}/tasks/{taskId}) ────────────────────

  Future<void> saveTask(TaskModel task) =>
      userDoc.collection('tasks').doc(task.id).set(task.toMap());

  Future<List<TaskModel>> getTasks() async {
    final snap = await userDoc.collection('tasks').get();
    return snap.docs.map((d) => TaskModel.fromMap(d.data())).toList();
  }

  Future<void> deleteTask(String taskId) =>
      userDoc.collection('tasks').doc(taskId).delete();

  // ── Goals (subcollection: /users/{uid}/goals/{goalId}) ────────────────────

  Future<void> saveGoal(GoalModel goal) =>
      userDoc.collection('goals').doc(goal.id).set(goal.toMap());

  Future<List<GoalModel>> getGoals() async {
    final snap = await userDoc.collection('goals').get();
    return snap.docs.map((d) => GoalModel.fromMap(d.data())).toList();
  }

  Future<void> deleteGoal(String goalId) =>
      userDoc.collection('goals').doc(goalId).delete();

  // ── Routine (single doc: /users/{uid}/routine/current) ────────────────────

  Future<void> saveRoutine(Map<String, dynamic> routineMap) =>
      userDoc.collection('routine').doc('current').set(routineMap);

  Future<Map<String, dynamic>?> getRoutine() async {
    final doc = await userDoc.collection('routine').doc('current').get();
    return doc.exists ? doc.data() : null;
  }

  // ── Coach Chats (subcollection: /users/{uid}/coach_chats/{threadId}/turns) ────────────────────

  Future<void> saveCoachChatTurn(
          String threadId, String turnId, Map<String, dynamic> turnData) =>
      userDoc
          .collection('coach_chats')
          .doc(threadId)
          .collection('turns')
          .doc(turnId)
          .set(turnData);

  Future<List<Map<String, dynamic>>> getCoachChatTurns(String threadId) async {
    final snap = await userDoc
        .collection('coach_chats')
        .doc(threadId)
        .collection('turns')
        .orderBy('timestamp')
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  // ── Account Export & Deletion ─────────────────────────────────────────────

  Future<String> exportUserData() async {
    final currentUid = uid;
    final exportData = <String, dynamic>{
      'uid': currentUid,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'root': <String, dynamic>{},
      'collections': <String, dynamic>{},
    };

    final profileDoc = await userDoc.get();
    exportData['root'] = {
      'path': profileDoc.reference.path,
      'exists': profileDoc.exists,
      if (profileDoc.exists) 'data': _toJsonValue(profileDoc.data()),
    };

    for (final collectionId in userOwnedCollectionIds) {
      final snap = await userDoc
          .collection(collectionId)
          .orderBy(FieldPath.documentId)
          .get();

      exportData['collections'][collectionId] = snap.docs
          .map(
            (doc) => {
              'id': doc.id,
              'path': doc.reference.path,
              'data': _toJsonValue(doc.data()),
            },
          )
          .toList();
    }

    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  Future<void> deleteUserOwnedData() async {
    for (final collectionId in userOwnedCollectionIds) {
      await _deleteCollectionDocuments(userDoc.collection(collectionId));
    }

    await userDoc.delete();
  }

  Future<void> deleteAllUserData() => deleteUserOwnedData();

  Future<void> _deleteCollectionDocuments(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final snap = await collection.limit(_deleteBatchSize).get();
      if (snap.docs.isEmpty) return;

      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (snap.docs.length < _deleteBatchSize) return;
    }
  }

  Object? _toJsonValue(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }

    if (value is Timestamp) {
      return value.toDate().toUtc().toIso8601String();
    }

    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }

    if (value is GeoPoint) {
      return {
        'latitude': value.latitude,
        'longitude': value.longitude,
      };
    }

    if (value is DocumentReference) {
      return value.path;
    }

    if (value is Iterable) {
      return value.map(_toJsonValue).toList();
    }

    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _toJsonValue(entry.value),
      };
    }

    return value.toString();
  }
}
