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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/event_names.dart';
import '../models/context_snapshot.dart';
import '../models/event_model.dart';
import '../models/task_model.dart';
import '../services/coach_service.dart';
import '../services/event_service.dart';
import '../services/gemini_service.dart';
import '../services/habit_service.dart';
import '../services/notification_service.dart';
import '../services/rule_engine_service.dart';
import '../services/state_aggregator_service.dart';
import '../services/streak_service.dart';

class EventOrchestrator {
  final EventService _eventService;
  final StreakService _streakService;
  final HabitService _habitService;
  final NotificationService _notificationService;
  final StateAggregatorService _stateAggregatorService;
  final RuleEngineService _ruleEngineService;
  final GeminiService _geminiService;
  final CoachService _coachService;
  final FirebaseAuth _auth;

  StreamSubscription<Event>? _subscription;

  EventOrchestrator({
    required EventService eventService,
    required StreakService streakService,
    required HabitService habitService,
    required NotificationService notificationService,
    required CoachService coachService,
    StateAggregatorService? stateAggregatorService,
    RuleEngineService? ruleEngineService,
    GeminiService? geminiService,
    FirebaseAuth? auth,
  })  : _eventService = eventService,
        _streakService = streakService,
        _habitService = habitService,
        _notificationService = notificationService,
        _coachService = coachService,
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
      ContextSnapshot? snapshot;
      try {
        await _notificationService.ensureNotificationSettings(uid);
        snapshot = await _stateAggregatorService.buildSnapshot(uid);
      } catch (e) {
        debugPrint('[EventOrchestrator] Failed to build snapshot: $e');
      }

      // ── Coach decision pipeline ──────────────────────────────────────────
      // For every event, the pipeline evaluates rules, checks cooldown and
      // budget, and either speaks (saves a coach message + speak-log row
      // atomically) or logs a suppression decision to coach_speak_log.
      if (snapshot != null) {
        try {
          final rule = _ruleEngineService.evaluate(snapshot, event);
          String decision = 'spoke';

          if (rule == null) {
            decision = 'dropped_no_rule';
          } else {
            final isCooldown = await _isCoachCooldown(
              uid: uid,
              cooldownTopic: rule.cooldownTopic,
              cooldownSeconds: rule.cooldownSeconds,
            );

            if (isCooldown) {
              decision = 'dropped_cooldown';
            }
          }

          if (decision == 'spoke' && rule != null) {
            final budgetDecision =
                await _notificationService.reserveNotificationSlot(
              uid: uid,
              intentDescription: 'coach_message_${rule.id}',
              category: 'coach_message',
              triggerEventId: event.eventId,
              isCritical: rule.isCritical,
            );

            if (!budgetDecision.allowed) {
              decision = budgetDecision.reason == 'quiet_day_mode'
                  ? 'dropped_quiet_day'
                  : 'dropped_budget';
            }
          }

          if (decision == 'spoke' && rule != null) {
            // Rule has decided to speak and budget has been reserved before the LLM call.
            debugPrint('[Coach] Rule selected: ${rule.id} — '
                'building context payload before Cloud Function call.');

            final contextPayload = await _coachService.buildContextPayload(
              uid: uid,
              snapshot: snapshot,
              rule: rule,
            );

            debugPrint('[Coach] Context payload built — '
                'calling Cloud Function (aiGenerate) for text generation.');

            String coachMessage;
            try {
              coachMessage = await _geminiService.generateWithContext(
                rulePrompt: rule.promptTemplate,
                contextPayload: contextPayload,
              );
            } catch (e) {
              debugPrint('[Coach] Cloud Function failed: $e — '
                  'using fallback message.');
              coachMessage = rule.fallbackMessage;
            }

            await CoachService.saveProactiveCoachMessage(
              uid: uid,
              rule: rule,
              triggerEvent: event,
              message: coachMessage,
            );

            debugPrint('[Coach] SENT message — '
                'event=${event.eventName} ruleId=${rule.id}');
          } else {
            await CoachService.logDecision(
              uid: uid,
              triggerEventId: event.eventId,
              ruleId: rule?.id,
              decision: decision,
            );

            debugPrint('[Coach] SUPPRESSED — '
                'event=${event.eventName} decision=$decision '
                'ruleId=${rule?.id ?? "none"}');
          }
        } catch (e) {
          debugPrint('[EventOrchestrator] Coach pipeline failed: $e');
        }
      }
    }

    switch (event.eventName) {
      case EventNames.taskScheduled:
        if (uid != null) {
          try {
            final task = TaskModel.fromMap(event.payload);
            await _notificationService.scheduleTaskReminder(task, uid);
          } catch (e) {
            debugPrint(
                '[EventOrchestrator] Failed to schedule task reminder: $e');
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
            debugPrint(
                '[EventOrchestrator] Failed to cancel task-end reminder: $e');
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

            // ── Procrastination Auto-Detect (Late Start) ──────────────────
            // If the task started more than 30 minutes after planned start.
            final drift =
                task.actualStart?.difference(task.plannedStart).inMinutes ?? 0;
            if (drift > 30) {
              final habit = await _habitService.getProcrastinationHabit();
              if (habit != null) {
                await _habitService.logProcrastinationSlip(
                  habitId: habit.id,
                  trigger: 'late_start',
                  minutesLost: drift,
                  relatedTaskId: task.id,
                  source: 'auto',
                  occurredAt: task.actualStart,
                );
              }
            }
          } catch (e) {
            debugPrint(
                '[EventOrchestrator] Failed to handle task-start signals: $e');
          }
        }
        break;

      case EventNames.taskAbandoned:
        // Cancel the end-reminder if abandoned early.
        if (uid != null) {
          try {
            final task = TaskModel.fromMap(event.payload);
            await _notificationService.cancelTaskEndReminder(task, uid);

            // ── Procrastination Auto-Detect (No Show) ────────────────────
            // If the task was abandoned automatically because it never started.
            if (task.reasonCategory == AbandonReason.autoNoStart) {
              final habit = await _habitService.getProcrastinationHabit();
              if (habit != null) {
                await _habitService.logProcrastinationSlip(
                  habitId: habit.id,
                  trigger: 'no_show',
                  minutesLost: task.plannedDurationMin,
                  relatedTaskId: task.id,
                  source: 'auto',
                  occurredAt: task.plannedStart,
                );
              }
            }
          } catch (e) {
            debugPrint(
                '[EventOrchestrator] Failed to handle task-abandon signals: $e');
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
            final habitId = event.payload['habitId'] as String? ?? '';
            final habitName = event.payload['habitName'] as String? ?? 'habit';
            if (habitId.isNotEmpty) {
              await _notificationService.scheduleSlipRecovery(
                uid: uid,
                habitId: habitId,
                habitName: habitName,
              );
            }
          } catch (e) {
            debugPrint(
                '[EventOrchestrator] Failed to schedule slip-recovery notification: $e');
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
            final habitId = event.payload['habitId'] as String? ?? '';
            final milestone = event.payload['milestone'] as int? ?? 0;
            if (habitId.isNotEmpty && milestone > 0) {
              await _notificationService.scheduleStreakMilestone(
                uid: uid,
                habitId: habitId,
                milestone: milestone,
              );
            }
          } catch (e) {
            debugPrint(
                '[EventOrchestrator] Failed to schedule streak milestone notification: $e');
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

    if (uid != null && _shouldRefreshIdentityProgress(event.eventName)) {
      await _refreshIdentityProgress(
        uid: uid,
        triggerEventName: event.eventName,
        triggerEventId: event.eventId,
      );
    }
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  bool _shouldRefreshIdentityProgress(String eventName) {
    switch (eventName) {
      case EventNames.onboardingCompleted:
      case EventNames.taskCompleted:
      case EventNames.taskAbandoned:
      case EventNames.goodHabitLogged:
      case EventNames.badHabitSlipLogged:
      case EventNames.streakExtended:
      case EventNames.streakBroken:
      case EventNames.streakMilestoneReached:
      case EventNames.dayClosed:
        return true;
      default:
        return false;
    }
  }

  Future<void> _refreshIdentityProgress({
    required String uid,
    required String triggerEventName,
    required String triggerEventId,
  }) async {
    try {
      final newScore = await _stateAggregatorService.updateIdentityProfile(uid);
      if (newScore == null) return;

      await _eventService.emit(
        eventName: EventNames.identityProgressChanged,
        payload: {
          'score': newScore,
          'triggerEventId': triggerEventId,
          'triggerEventName': triggerEventName,
        },
        source: 'orchestrator',
      );

      debugPrint(
        '[EventOrchestrator] identity_progress_changed fired — '
        'score=$newScore trigger=$triggerEventName',
      );
    } catch (e) {
      debugPrint('[EventOrchestrator] Failed to update identity profile: $e');
    }
  }

  Future<bool> _isCoachCooldown({
    required String uid,
    required String cooldownTopic,
    required int cooldownSeconds,
  }) async {
    final cutoff = DateTime.now().subtract(Duration(seconds: cooldownSeconds));
    final recentLogs = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('coach_speak_log')
        .where('decision', isEqualTo: 'spoke')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    for (final doc in recentLogs.docs) {
      final data = doc.data();
      final docRuleId = data['ruleId'] as String?;
      final createdAt = data['createdAt'] as Timestamp?;
      if (docRuleId == null || createdAt == null) continue;

      try {
        final pastRule =
            RuleEngineService.rules.firstWhere((rule) => rule.id == docRuleId);
        if (pastRule.cooldownTopic == cooldownTopic &&
            createdAt.toDate().isAfter(cutoff)) {
          return true;
        }
      } catch (_) {
        // Ignore logs for rules that no longer exist in this build.
      }
    }

    return false;
  }

  /// Returns today's date as a `YYYY-MM-DD` string in local time.
  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
