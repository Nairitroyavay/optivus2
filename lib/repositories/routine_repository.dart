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

  /// Save only the fixed schedule template config at
  /// /users/{uid}/routine/current.templates.fixed_schedule.
  Future<void> saveFixedScheduleTemplates(
    List<FixedScheduleTemplate> templates,
  ) async {
    final existing = await _service.getRoutine() ?? <String, dynamic>{};
    final existingTemplates = existing['templates'] is Map
        ? Map<String, dynamic>.from(existing['templates'] as Map)
        : <String, dynamic>{};

    await _service.saveRoutine({
      ...existing,
      'templates': {
        ...existingTemplates,
        'fixed_schedule':
            templates.map((template) => template.toMap()).toList(),
      },
      'fixedScheduleSetUp': templates.isNotEmpty,
    });
  }

  /// Load the routine state. Returns null if no data exists yet.
  Future<RoutineState?> loadRoutine() async {
    final data = await _service.getRoutine();
    if (data == null) return null;
    return RoutineState.fromMap(data);
  }
}
