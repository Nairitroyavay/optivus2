// lib/core/event_orchestrator.dart
//
// Central reaction layer. Listens to every event on the bus and dispatches
// side-effects to the appropriate services (StreakService, NotificationService,
// etc.). This keeps cross-cutting concerns out of individual services.
//
// Wired up via Riverpod in providers.dart and eagerly initialized on startup.
//
// ── Day-close ordering ────────────────────────────────────────────────────
// RoutineService runs the full day-close sequence (habit log rollup →
// streak computation → dailySummaries write → events).  The orchestrator
// must NOT re-trigger runDayCloseRollup when it receives dayClosed —
// that would cause streak events to fire a second time.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/event_names.dart';
import '../models/event_model.dart';
import '../models/task_model.dart';
import '../services/coach_service.dart';
import '../services/event_service.dart';
import '../services/gemini_service.dart';
import '../services/notification_service.dart';
import '../services/rule_engine_service.dart';
import '../services/state_aggregator_service.dart';
import '../services/streak_service.dart';

class EventOrchestrator {
  final EventService _eventService;
  final StreakService _streakService;
  final NotificationService _notificationService;
  final StateAggregatorService _stateAggregatorService;
  final RuleEngineService _ruleEngineService;
  final GeminiService _geminiService;
  final FirebaseAuth _auth;

  StreamSubscription<Event>? _subscription;

  EventOrchestrator({
    required EventService eventService,
    required StreakService streakService,
    required NotificationService notificationService,
    StateAggregatorService? stateAggregatorService,
    RuleEngineService? ruleEngineService,
    GeminiService? geminiService,
    FirebaseAuth? auth,
  })  : _eventService = eventService,
        _streakService = streakService,
        _notificationService = notificationService,
        _stateAggregatorService =
            stateAggregatorService ?? StateAggregatorService(),
        _ruleEngineService = ruleEngineService ?? RuleEngineService(),
        _geminiService = geminiService ?? GeminiService(),
        _auth = auth ?? FirebaseAuth.instance;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Call once during app startup (after auth is resolved).
  /// Subscribes to the event bus and begins dispatching side-effects.
  void init() {
    // Services are referenced here to suppress unused-field warnings.
    assert(() {
      debugPrint('[EventOrchestrator] Initialized with '
          '${_streakService.runtimeType}, ${_notificationService.runtimeType}');
      return true;
    }());

    _notificationService.init();

    _subscription?.cancel();
    _subscription = _eventService.onAny().listen(
      (event) {
        unawaited(_handleEvent(event));
      },
      onError: (Object error) {
        debugPrint('[EventOrchestrator] Stream error: $error');
      },
    );
    debugPrint('[EventOrchestrator] Initialized — listening to event bus.');
  }

  /// Tear down when the app is shutting down or the user logs out.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    debugPrint('[EventOrchestrator] Disposed.');
  }

  // ── Dispatch ─────────────────────────────────────────────────────────────

  Future<void> _handleEvent(Event event) async {
    debugPrint('[EventOrchestrator] Received: ${event.eventName}');

    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        final snapshot = await _stateAggregatorService.buildSnapshot(uid);
        final rule = _ruleEngineService.evaluate(snapshot, event);
        if (rule != null) {
          final coachMessage =
              await _geminiService.generateOnce(rule.promptTemplate);
          await CoachService.saveProactiveCoachMessage(
            uid: uid,
            rule: rule,
            triggerEvent: event,
            message: coachMessage,
          );
        }
      } catch (e) {
        debugPrint('[EventOrchestrator] Rule engine pipeline failed: $e');
      }
    }

    switch (event.eventName) {
      // ── Task engine ───────────────────────────────────────────────────
      case EventNames.taskScheduled:
        if (uid != null) {
          try {
            final task = TaskModel.fromMap(event.payload);
            await _notificationService.scheduleTaskReminder(task, uid);
          } catch (e) {
            debugPrint('[EventOrchestrator] Failed to schedule task reminder: $e');
          }
        }
        break;

      case EventNames.taskCompleted:
        // Cancel the end-reminder if completed early.
        if (uid != null) {
          try {
            final task = TaskModel.fromMap(event.payload);
            await _notificationService.cancelTaskEndReminder(task, uid);
          } catch (e) {
            debugPrint('[EventOrchestrator] Failed to cancel task-end reminder: $e');
          }
        }
        break;

      case EventNames.taskStarted:
        // Schedule a task-end reminder at plannedEnd so the user is prompted
        // to mark the task complete if it was started but not yet finished.
        if (uid != null) {
          try {
            final task = TaskModel.fromMap(event.payload);
            await _notificationService.scheduleTaskEndReminder(task, uid);
          } catch (e) {
            debugPrint('[EventOrchestrator] Failed to schedule task-end reminder: $e');
          }
        }
        break;

      case EventNames.taskAbandoned:
        // Cancel the end-reminder if abandoned early.
        if (uid != null) {
          try {
            final task = TaskModel.fromMap(event.payload);
            await _notificationService.cancelTaskEndReminder(task, uid);
          } catch (e) {
            debugPrint('[EventOrchestrator] Failed to cancel task-end reminder: $e');
          }
        }
        break;

      // ── Habit tracking ────────────────────────────────────────────────
      // Intra-day log events are recorded by HabitService.  Streak changes
      // are computed atomically at day-close via RoutineService, so we only
      // log here for observability.
      case EventNames.goodHabitLogged:
        debugPrint(
            '[EventOrchestrator] goodHabitLogged — streak updated at day-close.');
        break;

      case EventNames.badHabitSlipLogged:
        debugPrint(
            '[EventOrchestrator] badHabitSlipLogged — streak updated at day-close.');
        if (uid != null) {
          try {
            final habitId   = event.payload['habitId']   as String? ?? '';
            final habitName = event.payload['habitName'] as String? ?? 'habit';
            if (habitId.isNotEmpty) {
              await _notificationService.scheduleSlipRecovery(
                uid: uid,
                habitId: habitId,
                habitName: habitName,
              );
            }
          } catch (e) {
            debugPrint('[EventOrchestrator] Failed to schedule slip-recovery notification: $e');
          }
        }
        break;

      // ── Streaks ───────────────────────────────────────────────────────
      // These are emitted by StreakService inside runDayCloseRollup and
      // arrive here for downstream reactions (notifications, UI badges).
      case EventNames.streakExtended:
        debugPrint('[EventOrchestrator] streakExtended — '
            'habitId=${event.payload['habitId']}, '
            'count=${event.payload['currentCount']}');
        // TODO: Call _notificationService with a congratulatory nudge.
        break;

      case EventNames.streakMilestoneReached:
        debugPrint('[EventOrchestrator] streakMilestoneReached — '
            'habitId=${event.payload['habitId']}, '
            'milestone=${event.payload['milestone']}');
        if (uid != null) {
          try {
            final habitId  = event.payload['habitId']  as String? ?? '';
            final milestone = event.payload['milestone'] as int?   ?? 0;
            if (habitId.isNotEmpty && milestone > 0) {
              await _notificationService.scheduleStreakMilestone(
                uid: uid,
                habitId: habitId,
                milestone: milestone,
              );
            }
          } catch (e) {
            debugPrint('[EventOrchestrator] Failed to schedule streak milestone notification: $e');
          }
        }
        break;

      case EventNames.streakBroken:
        debugPrint('[EventOrchestrator] streakBroken — '
            'habitId=${event.payload['habitId']}, '
            'previous=${event.payload['previousCount']}');
        // TODO: Call _notificationService with an encouraging nudge.
        break;

      // ── Day lifecycle ─────────────────────────────────────────────────
      // RoutineService has already completed the full rollup sequence
      // (habit logs → streaks → dailySummaries) before emitting this event.
      // Do NOT call runDayCloseRollup here — that would re-trigger streak
      // evaluation and duplicate all streak events.
      case EventNames.dayClosed:
        final date = event.payload['date'] as String? ?? _todayString();
        debugPrint('[EventOrchestrator] dayClosed for $date — '
            'rollup already completed by RoutineService.');
        // TODO: Call _notificationService to deliver the day summary.
        break;

      case EventNames.dayStarted:
        // TODO: Schedule today's routine notifications.
        break;

      // ── Routine ───────────────────────────────────────────────────────
      case EventNames.routineBlockCompleted:
        // TODO: Check if all blocks for the day are done → emit dayClosed?
        break;

      case EventNames.routineDaySummarized:
        final date = event.payload['date'] as String? ?? _todayString();
        debugPrint('[EventOrchestrator] routineDaySummarized for $date.');
        // TODO: Log or notify that routine summary is available.
        break;

      // ── Engagement ────────────────────────────────────────────────────
      case EventNames.ghostDayDetected:
        // TODO: Call _notificationService with a re-engagement nudge.
        break;

      case EventNames.comebackInitiated:
        // TODO: Reset relevant streak pause states.
        break;

      // ── Default (no-op for events that don't need orchestration) ─────
      default:
        break;
    }
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  /// Returns today's date as a `YYYY-MM-DD` string in local time.
  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
