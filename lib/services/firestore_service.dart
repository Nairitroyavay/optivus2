import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task_model.dart';
import '../models/goal_model.dart';

class FirestoreService {
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

  Future<void> saveUserProfile(Map<String, dynamic> data, {bool merge = false}) =>
      userDoc.set(data, merge ? SetOptions(merge: true) : null);

  Future<Map<String, dynamic>?> getUserProfile() async {
    final doc = await userDoc.get();
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

  Future<void> saveCoachChatTurn(String threadId, String turnId, Map<String, dynamic> turnData) =>
      userDoc.collection('coach_chats').doc(threadId).collection('turns').doc(turnId).set(turnData);

  Future<List<Map<String, dynamic>>> getCoachChatTurns(String threadId) async {
    final snap = await userDoc.collection('coach_chats').doc(threadId).collection('turns').orderBy('timestamp').get();
    return snap.docs.map((d) => d.data()).toList();
  }

  // ── Account Deletion (cascade all subcollections) ─────────────────────────

  Future<void> deleteAllUserData() async {
    // Delete every document in each subcollection
    for (final sub in ['tasks', 'goals', 'routine']) {
      final snap = await userDoc.collection(sub).get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    }
    // Delete the user profile document itself
    await userDoc.delete();
  }
}
