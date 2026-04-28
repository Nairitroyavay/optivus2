import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/services/firestore_service.dart';
import 'package:optivus2/services/event_service.dart';
import 'package:optivus2/repositories/user_repository.dart';
import 'package:optivus2/repositories/routine_repository.dart';
import 'package:optivus2/services/task_service.dart';
import 'package:optivus2/services/habit_service.dart';
import 'package:optivus2/models/task_model.dart';
import 'package:optivus2/models/habit_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CENTRAL DI — Single source of truth for service & repository providers
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps Firebase instances — never access Firebase directly outside this.
final firestoreServiceProvider = Provider<FirestoreService>(
  (_) => FirestoreService(),
);

/// The event bus — pub-sub backbone of the entire system.
/// Every other service depends on this.
final eventServiceProvider = Provider<EventService>(
  (_) => EventService(),
);

/// Task state transition and logging service.
final taskServiceProvider = Provider<TaskService>(
  (ref) => TaskService(
    eventService: ref.read(eventServiceProvider),
  ),
);

/// Habit tracking and logging service.
final habitServiceProvider = Provider<HabitService>(
  (ref) => HabitService(
    eventService: ref.read(eventServiceProvider),
  ),
);

/// User profile + onboarding persistence.
final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(ref.read(firestoreServiceProvider)),
);

/// Routine state persistence (save / load RoutineState).
final routineRepositoryProvider = Provider<RoutineRepository>(
  (ref) => RoutineRepository(ref.read(firestoreServiceProvider)),
);

/// Real-time stream of today's Firestore-backed tasks.
final todayTasksProvider = StreamProvider<List<TaskModel>>((ref) {
  final taskService = ref.watch(taskServiceProvider);
  return taskService.tasksFor(DateTime.now());
});

/// Real-time stream of all active habits.
final habitsProvider = StreamProvider<List<HabitModel>>((ref) {
  final habitService = ref.watch(habitServiceProvider);
  return habitService.habits();
});

