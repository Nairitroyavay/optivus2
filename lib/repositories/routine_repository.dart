import '../services/firestore_service.dart';
import '../models/routine_model.dart';

class RoutineRepository {
  final FirestoreService _service;

  RoutineRepository(this._service);

  Future<void> addRoutine(RoutineModel routine) {
    return _service.saveRoutine(routine);
  }
}
