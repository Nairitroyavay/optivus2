import '../services/firestore_service.dart';
import '../providers/routine_provider.dart'; // RoutineState lives here

/// Persists and loads the full RoutineState to/from Firestore.
///
/// Firestore path: /users/{uid}/routine/current
class RoutineRepository {
  final FirestoreService _service;

  RoutineRepository(this._service);

  /// Save the entire routine state as a single Firestore document.
  Future<void> saveRoutine(RoutineState state) {
    return _service.saveRoutine(state.toMap());
  }

  /// Load the routine state. Returns null if no data exists yet.
  Future<RoutineState?> loadRoutine() async {
    final data = await _service.getRoutine();
    if (data == null) return null;
    return RoutineState.fromMap(data);
  }
}
