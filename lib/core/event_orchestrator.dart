// lib/core/event_orchestrator.dart
//
// Central reaction layer. Listens to every event on the bus and dispatches
// side-effects to the appropriate services (StreakService, NotificationService,
// etc.). This keeps cross-cutting concerns out of individual services.
//
// Wired up via Riverpod in providers.dart and eagerly initialized on startup.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/event_names.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';
import '../services/streak_service.dart';
import '../services/notification_service.dart';

class EventOrchestrator {
  final EventService _eventService;
  final StreakService _streakService;
  final NotificationService _notificationService;

  StreamSubscription<Event>? _subscription;

  EventOrchestrator({
    required EventService eventService,
    required StreakService streakService,
    required NotificationService notificationService,
  })  : _eventService = eventService,
        _streakService = streakService,
        _notificationService = notificationService;

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

    _subscription?.cancel();
    _subscription = _eventService.onAny().listen(
      _handleEvent,
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

  void _handleEvent(Event event) {
    debugPrint('[EventOrchestrator] Received: ${event.eventName}');

    switch (event.eventName) {
      // ── Task engine ───────────────────────────────────────────────────
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
      case EventNames.goodHabitLogged:
        // TODO: Call _streakService.extendOrCreate() for the habit.
        // TODO: Check if a streak milestone was reached and fire
        //       EventNames.streakMilestoneReached if so.
        break;

      case EventNames.badHabitSlipLogged:
        // TODO: Call _streakService to reset or decrement the clean streak.
        // TODO: Check for EventNames.slipStreakDetected pattern.
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
        // TODO: Call _streakService.runDayCloseRollup(date) for all habits.
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
}
