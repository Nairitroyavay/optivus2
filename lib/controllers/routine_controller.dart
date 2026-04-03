import '../repositories/routine_repository.dart';
import '../models/routine_model.dart';
import '../models/task_model.dart';

class RoutineController {
  final RoutineRepository _repo;

  RoutineController(this._repo);

  Future<void> createRoutine(String name, String description) async {
    final routine = RoutineModel(
      id: DateTime.now().toString(),
      name: name,
      description: description,
    );

    await _repo.addRoutine(routine);
  }
}
