// lib/core/event_orchestrator.dart
//
// Central reaction layer. Listens to every event on the bus and dispatches
// side-effects to the appropriate services (StreakService, NotificationService,
// etc.). This keeps cross-cutting concerns out of individual services.
//
// Wired up via Riverpod in providers.dart and eagerly initialized on startup.

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
    // They will be called from the switch cases once implemented.
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
        try {
          final task = TaskModel.fromMap(event.payload);
          _notificationService.scheduleTaskAlarm(task);
        } catch (e) {
          debugPrint('[EventOrchestrator] Failed to schedule task alarm: $e');
        }
        break;

      case EventNames.taskCompleted:
        // TODO: Call _streakService to check if a streak should be extended.
        // TODO: Call _notificationService to send a "task done" confirmation.
        break;

      case EventNames.taskStarted:
        // TODO: Optionally schedule a reminder notification if the task
        //       exceeds its planned duration.
        break;

      case EventNames.taskAbandoned:
        // TODO: Notify the user or log analytics for abandoned tasks.
        break;

      // ── Habit tracking ────────────────────────────────────────────────
      // Intra-day log events are recorded by HabitService.  Streak changes
      // are computed atomically at day-close via runDayCloseRollup rather
      // than incrementally, so we only log here for observability.
      case EventNames.goodHabitLogged:
        debugPrint('[EventOrchestrator] goodHabitLogged — streak updated at day-close.');
        break;

      case EventNames.badHabitSlipLogged:
        debugPrint('[EventOrchestrator] badHabitSlipLogged — streak updated at day-close.');
        break;

      // ── Streaks ───────────────────────────────────────────────────────
      case EventNames.streakMilestoneReached:
        // TODO: Call _notificationService to celebrate the milestone.
        break;

      case EventNames.streakBroken:
        // TODO: Call _notificationService with an encouraging nudge.
        break;

      // ── Day lifecycle ─────────────────────────────────────────────────
      case EventNames.dayClosed:
        // Primary trigger for the streak rollup.  The date is carried in the
        // event payload; fall back to today if somehow absent.
        final date = event.payload['date'] as String? ??
            _todayString();
        debugPrint('[EventOrchestrator] dayClosed → runDayCloseRollup($date)');
        _streakService.runDayCloseRollup(date).catchError((Object e) {
          debugPrint('[EventOrchestrator] runDayCloseRollup error: $e');
        });
        // TODO: Call _notificationService to deliver the day summary.
        break;

      case EventNames.dayStarted:
        // TODO: Schedule today's routine notifications.
        break;

      // ── Routine ───────────────────────────────────────────────────────
      case EventNames.routineBlockCompleted:
        // TODO: Check if all blocks for the day are done → emit dayClosed?
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
