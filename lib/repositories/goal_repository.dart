import '../services/firestore_service.dart';
import '../models/goal_model.dart';

class GoalRepository {
  final FirestoreService _service;

  GoalRepository(this._service);

  Future<void> addGoal(GoalModel goal) {
    return _service.saveGoal(goal);
  }
}
