import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';
import '../models/routine_model.dart';
import '../models/goal_model.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  Future<void> saveTask(TaskModel task) async {
    await _db.collection('tasks').doc(task.id).set(task.toMap());
  }

  Future<void> saveRoutine(RoutineModel routine) async {
    await _db.collection('routines').doc(routine.id).set(routine.toMap());
  }

  Future<void> saveGoal(GoalModel goal) async {
    await _db.collection('goals').doc(goal.id).set(goal.toMap());
  }
}
