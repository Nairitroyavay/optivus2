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
import 'package:optivus2/models/habit_log_model.dart';
import 'package:optivus2/models/streak_model.dart';
import 'package:optivus2/models/day_summary_model.dart';
import 'package:optivus2/models/screen_time_log_model.dart';
import 'package:optivus2/services/routine_service.dart';
import 'package:optivus2/services/coach_service.dart';
import 'package:optivus2/services/state_aggregator_service.dart';
import 'package:optivus2/services/remote_config_service.dart';
import 'package:optivus2/services/screen_time_bridge.dart';
import 'package:optivus2/services/screen_time_importer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

export 'providers/bootstrap_provider.dart';

/// Active Remote Config wrapper. Overridden from `main.dart` after Firebase
/// startup so consumers can read the initialized service synchronously.
final remoteConfigServiceProvider = Provider<RemoteConfigService>(
  (_) => RemoteConfigService(),
);

/// Typed feature flags and remote defaults. Overridden from `main.dart` with
/// the values available at startup; services can watch/read this without
/// reaching into Firebase directly.
final appRemoteConfigProvider = Provider<AppRemoteConfig>(
  (_) => AppRemoteConfig.defaults(),
);

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

final stateAggregatorServiceProvider = Provider<StateAggregatorService>(
  (_) => StateAggregatorService(),
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
    coachService: ref.read(coachServiceProvider),
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
    stateAggregatorService: ref.read(stateAggregatorServiceProvider),
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
  return taskService.watchTasksForDay(DateTime.now());
});

/// Selected Routine tab calendar day. Kept in core providers so the add sheet,
/// timeline, and task stream agree on the active day.
final selectedRoutineDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final currentUserDocumentProvider =
    StreamProvider<Map<String, dynamic>?>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((snap) => snap.data());
});

/// Real-time stream for the selected Routine tab day.
final selectedRoutineTasksProvider = StreamProvider<List<TaskModel>>((ref) {
  final selected = ref.watch(selectedRoutineDateProvider);
  final taskService = ref.watch(taskServiceProvider);
  return taskService.watchTasksForDay(selected);
});

/// Real-time stream of tasks for the next 14-day routine window.
///
/// Consumed by [RoutineTab] so every day in the scrollable timeline has
/// live Firestore-backed task data, preventing config-only fallback blocks
/// from appearing alongside real task documents.
final routineWindowTasksProvider = StreamProvider<List<TaskModel>>((ref) {
  final taskService = ref.watch(taskServiceProvider);
  return taskService.watchTasksForWindow(DateTime.now(), days: 14);
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

/// Real-time stream of a single streak document by id.
final streakByIdProvider =
    StreamProvider.family<Streak?, String>((ref, streakId) {
  final streakService = ref.watch(streakServiceProvider);
  return streakService.watchStreak(streakId);
});

/// Real-time stream of habit logs for a habit over the trailing [days] window.
/// Used by the streak heatmap to color cells per day.
final habitLogsForRangeProvider =
    StreamProvider.family<List<HabitLog>, ({String habitId, int days})>(
  (ref, args) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const <HabitLog>[]);

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: args.days - 1));

    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('habit_logs')
        .where('habitId', isEqualTo: args.habitId)
        .where('occurredAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .snapshots()
        .map((snap) => snap.docs.map(HabitLog.fromFirestore).toList());
  },
);

/// Real-time stream of daily summaries for the trailing [days] window.
/// Used to render routine-streak history when habit logs aren't applicable.
final recentDailySummariesProvider =
    StreamProvider.family<List<DaySummary>, int>((ref, days) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const <DaySummary>[]);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('dailySummaries')
      .orderBy('date', descending: true)
      .limit(days)
      .snapshots()
      .map((snap) => snap.docs.map(DaySummary.fromFirestore).toList());
});

/// Real-time stream of today's habit logs.
final todayHabitLogsProvider = StreamProvider<List<HabitLog>>((ref) {
  final habitService = ref.watch(habitServiceProvider);
  return habitService.watchHabitLogsForDate(DateTime.now());
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

// ─────────────────────────────────────────────────────────────────────────────
// Screen-Time providers
// ─────────────────────────────────────────────────────────────────────────────

/// Thin wrapper around the native MethodChannel.
final screenTimeBridgeProvider = Provider<ScreenTimeBridge>(
  (_) => ScreenTimeBridge(),
);

/// Orchestrates native query → Firestore upsert → event emission.
final screenTimeImporterProvider = Provider<ScreenTimeImporter>(
  (ref) => ScreenTimeImporter(
    bridge: ref.read(screenTimeBridgeProvider),
    eventService: ref.read(eventServiceProvider),
  ),
);

/// Real-time stream of today's screen_time_logs document.
/// Emits null until the first sync has been completed.
final screenTimeLogProvider = StreamProvider<ScreenTimeLogModel?>((ref) {
  final importer = ref.watch(screenTimeImporterProvider);
  return importer.watchToday();
});

// ─────────────────────────────────────────────────────────────────────────────
// Tracker AI suggestions
// ─────────────────────────────────────────────────────────────────────────────

/// Real-time stream of pending AI suggestions targeted at the tracker surface.
///
/// Returns raw maps because the Suggestion model does not exist yet (Task 11.1).
/// Each map includes the document ID under the 'id' key.
/// Limited to 1 doc — the tracker only shows one insight card at a time.
final trackerSuggestionsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const []);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('suggestions')
      .where('status', isEqualTo: 'pending')
      .where('targetSurface', isEqualTo: 'tracker')
      .limit(1)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => <String, dynamic>{'id': d.id, ...d.data()}).toList());
});
