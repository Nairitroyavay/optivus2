import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/services/firestore_service.dart';
import 'package:optivus2/services/event_service.dart';
import 'package:optivus2/services/streak_service.dart';
import 'package:optivus2/services/notification_service.dart';
import 'package:optivus2/core/event_orchestrator.dart';
import 'package:optivus2/repositories/user_repository.dart';
import 'package:optivus2/repositories/routine_repository.dart';
import 'package:optivus2/services/task_service.dart';
import 'package:optivus2/services/habit_service.dart';
import 'package:optivus2/models/task_model.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/models/streak_model.dart';
import 'package:optivus2/models/day_summary_model.dart';
import 'package:optivus2/services/routine_service.dart';
import 'package:optivus2/services/coach_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

export 'providers/bootstrap_provider.dart';

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

/// Streak rollup and maintenance service.
final streakServiceProvider = Provider<StreakService>(
  (ref) => StreakService(
    eventService: ref.read(eventServiceProvider),
  ),
);

/// Local and push notification scheduling service.
final notificationServiceProvider = Provider<NotificationService>(
  (_) => NotificationService(),
);

/// Central side-effect dispatcher — listens to the event bus and
/// calls StreakService, NotificationService, etc. as appropriate.
/// Calling init() eagerly so it starts listening on first read.
final eventOrchestratorProvider = Provider<EventOrchestrator>((ref) {
  final orchestrator = EventOrchestrator(
    eventService: ref.read(eventServiceProvider),
    streakService: ref.read(streakServiceProvider),
    notificationService: ref.read(notificationServiceProvider),
  );
  orchestrator.init();
  ref.onDispose(orchestrator.dispose);
  return orchestrator;
});

/// Routine side-effect service.
final routineServiceProvider = Provider<RoutineService>(
  (ref) => RoutineService(
    eventService: ref.read(eventServiceProvider),
    streakService: ref.read(streakServiceProvider),
  ),
);

/// AI Coach Service
final coachServiceProvider = Provider<CoachService>(
  (ref) => CoachService(
    taskService: ref.read(taskServiceProvider),
    streakService: ref.read(streakServiceProvider),
    habitService: ref.read(habitServiceProvider),
    userRepo: ref.read(userRepositoryProvider),
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

/// Real-time stream of tasks for the next 14-day routine window.
///
/// Consumed by [RoutineTab] so every day in the scrollable timeline has
/// live Firestore-backed task data, preventing config-only fallback blocks
/// from appearing alongside real task documents.
final routineWindowTasksProvider = StreamProvider<List<TaskModel>>((ref) {
  final taskService = ref.watch(taskServiceProvider);
  return taskService.tasksForWindow(DateTime.now(), days: 14);
});

/// Real-time stream of all active habits.
final habitsProvider = StreamProvider<List<HabitModel>>((ref) {
  final habitService = ref.watch(habitServiceProvider);
  return habitService.habits();
});

/// Real-time stream of all streaks.
final allStreaksProvider = StreamProvider<List<Streak>>((ref) {
  final streakService = ref.watch(streakServiceProvider);
  return streakService.watchAllStreaks();
});

/// Real-time stream of today's habit logs.
final todayHabitLogsProvider = StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('habit_logs')
      .where('occurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
      .where('occurredAt', isLessThan: Timestamp.fromDate(endOfDay))
      .snapshots()
      .map((snap) => snap.docs);
});

/// Real-time stream of today's DaySummary.
final todaySummaryProvider = StreamProvider<DaySummary?>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(null);

  final now = DateTime.now();
  final todayStr = '${now.year.toString().padLeft(4, '0')}-'
                   '${now.month.toString().padLeft(2, '0')}-'
                   '${now.day.toString().padLeft(2, '0')}';

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('dailySummaries')
      .doc(todayStr)
      .snapshots()
      .map((snap) => snap.exists ? DaySummary.fromFirestore(snap) : null);
});
