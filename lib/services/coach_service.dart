import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:optivus2/models/context_snapshot.dart';
import 'package:optivus2/services/task_service.dart';
import 'package:optivus2/services/streak_service.dart';
import 'package:optivus2/services/habit_service.dart';
import 'package:optivus2/core/utils/uuid_generator.dart';
import 'package:optivus2/models/coach_rule.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/models/event_model.dart';
import 'package:optivus2/repositories/user_repository.dart';
import 'package:optivus2/services/gemini_service.dart';

class CoachService {
  final TaskService _taskService;
  final StreakService _streakService;
  final HabitService _habitService;
  final UserRepository _userRepo;

  CoachService({
    required TaskService taskService,
    required StreakService streakService,
    required HabitService habitService,
    required UserRepository userRepo,
  })  : _taskService = taskService,
        _streakService = streakService,
        _habitService = habitService,
        _userRepo = userRepo;

  Future<String> generateSystemPrompt(String coachName, String tone) async {
    final context = await _loadCoachGroundingContext();
    final resolvedTone = await _resolveCoachTone(tone);

    return '''You are the user's personal Optivus AI life coach. Your name is $coachName.
Your tone should be: $resolvedTone.
User's main goals: ${context.goals}.
Good habits they want to build: ${context.goodHabits}.
Habits trying to break: ${context.badHabits}.

Current Context:
Today's Tasks:
${context.todayTasks}

Active Habits:
${context.activeHabits}

Active Streaks:
${context.activeStreaks}

You are embedded in their daily timeline app. Keep responses engaging, supportive, and relatively concise (1-3 paragraphs max) so they fit well in a chat bubble.
Return only the final coach message text, with no JSON or markdown.''';
  }

  Future<GeminiChatSession> startChat(
    String coachName,
    String tone, {
    List<Map<String, dynamic>>? initialHistory,
  }) async {
    final systemPrompt = await generateSystemPrompt(coachName, tone);
    return GeminiService()
        .startChat(systemPrompt, initialHistory: initialHistory);
  }

  /// Builds a structured context payload for the Cloud Function.
  ///
  /// Reads onboarding, today's tasks, habits, and streaks from Firestore
  /// and returns a map that the Cloud Function uses to build an enriched
  /// system prompt.  Called by [EventOrchestrator] after the rule engine
  /// has already decided to speak — this method does NOT decide whether
  /// to speak.
  Future<Map<String, dynamic>> buildContextPayload({
    required String uid,
    required ContextSnapshot snapshot,
    required Rule rule,
  }) async {
    debugPrint(
        '[CoachService] Building rule context: uid=$uid ruleId=${rule.id}');

    final onboardingSnapshot = await _userRepo.getOnboardingData();
    final onboarding = onboardingSnapshot?.onboarding;
    final coachName = (onboarding?['coachName'] as String?)?.isNotEmpty == true
        ? onboarding!['coachName'] as String
        : 'AI Coach';
    final tone = (onboarding?['coachStyle'] as String?)?.isNotEmpty == true
        ? onboarding!['coachStyle'] as String
        : 'Empathetic and motivating';
    final resolvedTone = await _resolveCoachTone(tone, uid: uid);
    final context = await _loadCoachGroundingContext();

    return <String, dynamic>{
      'coachName': coachName,
      'tone': resolvedTone,
      'goals': context.goals,
      'goodHabits': context.goodHabits,
      'badHabits': context.badHabits,
      'todayTasks': context.todayTasks,
      'activeHabits': context.activeHabits,
      'activeStreaks': context.activeStreaks,
      'ruleId': rule.id,
      'ruleIntent': rule.aiIntent,
      'userState': snapshot.userState,
      'missionScore': snapshot.missionScore,
    };
  }

  Future<String> _resolveCoachTone(String fallback, {String? uid}) async {
    final resolvedUid = uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (resolvedUid == null) return fallback;

    try {
      final now = DateTime.now();
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(resolvedUid)
          .get();
      final root = userSnap.data() ?? const <String, dynamic>{};
      final rootTone = _unexpiredToneOverride(root, now);
      if (rootTone != null) return rootTone;

      final profileSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(resolvedUid)
          .collection('profile')
          .doc('main')
          .get();
      final profileTone = _unexpiredToneOverride(
        profileSnap.data() ?? const <String, dynamic>{},
        now,
      );
      return profileTone ?? fallback;
    } catch (e) {
      debugPrint('[CoachService] Could not resolve coach tone override: $e');
      return fallback;
    }
  }

  String? _unexpiredToneOverride(Map<String, dynamic> data, DateTime now) {
    final tone = (data['coachToneOverride'] as String?)?.trim();
    if (tone == null || tone.isEmpty) return null;
    final until = _parseFlexibleDate(data['coachToneOverrideUntil']);
    if (until == null || !until.isAfter(now)) return null;
    return tone;
  }

  DateTime? _parseFlexibleDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Saves a proactive coach message to Firestore and writes the
  /// corresponding `spoke` decision to `coach_speak_log` — all in a
  /// single atomic [WriteBatch].
  ///
  /// Returns the generated `messageId`.
  static Future<String> saveProactiveCoachMessage({
    required String uid,
    required Rule rule,
    required EventModel triggerEvent,
    required String message,
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? FirebaseFirestore.instance;
    final now = DateTime.now();
    final messageId = generateId();
    final logId = generateId();

    final coachMessage = <String, dynamic>{
      'messageId': messageId,
      'userId': uid,
      'role': 'coach',
      'message': message,
      'body': message,
      'text': message,
      'messageType': 'check_in',
      'priority': rule.priority,
      'ruleId': rule.id,
      'ruleIntent': rule.aiIntent,
      'source': 'rule_engine',
      'deliveryType': 'proactive_rule',
      'triggerEventId': triggerEvent.eventId,
      'triggerEventName': triggerEvent.eventName,
      'timestamp': Timestamp.fromDate(now),
      'createdAt': Timestamp.fromDate(now),
      'aiGenerated': true,
      'schemaVersion': 1,
    };

    final batch = db.batch();
    final userRef = db.collection('users').doc(uid);

    // ── Coach message writes ─────────────────────────────────────────────
    batch.set(
      userRef.collection('coach_messages').doc(messageId),
      coachMessage,
    );

    batch.set(
      userRef
          .collection('coach_chats')
          .doc('main_thread')
          .collection('turns')
          .doc(messageId),
      {
        'id': messageId,
        'text': message,
        'isUser': false,
        'role': 'coach',
        'source': 'rule_engine',
        'ruleId': rule.id,
        'triggerEventId': triggerEvent.eventId,
        'timestamp': Timestamp.fromDate(now),
      },
    );

    // ── Speak log: "spoke" decision (atomic with the message) ────────────
    batch.set(
      userRef.collection('coach_speak_log').doc(logId),
      {
        'logId': logId,
        'userId': uid,
        'triggerEventId': triggerEvent.eventId,
        'triggerEventName': triggerEvent.eventName,
        'ruleId': rule.id,
        'ruleIntent': rule.aiIntent,
        'decision': 'spoke',
        'messageId': messageId,
        'messagePath': 'users/$uid/coach_messages/$messageId',
        'createdAt': Timestamp.fromDate(now),
        'schemaVersion': 1,
      },
    );

    await batch.commit();

    debugPrint('[CoachService] SPOKE — '
        'messageId=$messageId ruleId=${rule.id} '
        'trigger=${triggerEvent.eventId} logId=$logId');

    return messageId;
  }

  /// Logs a **suppressed** coach decision to `coach_speak_log`.
  ///
  /// "Spoke" decisions are logged atomically inside [saveProactiveCoachMessage]
  /// instead, so callers should only use this for drop decisions:
  /// `dropped_cooldown`, `dropped_no_rule`, `dropped_budget`.
  ///
  /// Every field is always written (nullable fields are set to `null`
  /// rather than omitted) to guarantee a consistent schema.
  static Future<void> logDecision({
    required String uid,
    required String triggerEventId,
    String? ruleId,
    required String decision,
    String? messageId,
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? FirebaseFirestore.instance;
    final logId = generateId();
    final now = DateTime.now();

    await db
        .collection('users')
        .doc(uid)
        .collection('coach_speak_log')
        .doc(logId)
        .set({
      'logId': logId,
      'triggerEventId': triggerEventId,
      'ruleId': ruleId, // null when no rule matched
      'decision': decision,
      'messageId': messageId, // null for all drop decisions
      'createdAt': Timestamp.fromDate(now),
      'schemaVersion': 1,
    });

    debugPrint('[CoachService] DECISION — '
        'decision=$decision ruleId=$ruleId '
        'trigger=$triggerEventId logId=$logId');
  }

  Future<
      ({
        String goals,
        String goodHabits,
        String badHabits,
        String todayTasks,
        String activeHabits,
        String activeStreaks,
      })> _loadCoachGroundingContext() async {
    final onboardingSnapshot = await _userRepo.getOnboardingData();
    final onboarding = onboardingSnapshot?.onboarding;
    final goals =
        (onboarding?['goals'] as List?)?.join(', ') ?? 'No specific goals set';
    final goodHabits =
        (onboarding?['goodHabits'] as List?)?.join(', ') ?? 'None specified';
    final badHabits =
        (onboarding?['badHabits'] as List?)?.join(', ') ?? 'None specified';

    final today = DateTime.now();
    final tasks = await _taskService.watchTasksForDay(today).first;
    final todayTasks = tasks.isEmpty
        ? 'None scheduled for today.'
        : tasks
            .map(
              (task) => '- ${task.title.isEmpty ? task.type.name : task.title} '
                  '(${_formatTime(task.plannedStart)}-${_formatTime(task.plannedEnd)})',
            )
            .join('\n');

    final activeHabits = await _habitService.habits().first;
    final activeHabitsText = activeHabits.isEmpty
        ? 'No active habits yet.'
        : activeHabits.map(_formatHabitSummary).join('\n');

    final streaksList = <String>[];
    for (final habit in activeHabits) {
      final streak = await _streakService.getStreak(habit.id);
      if (streak != null && streak.currentCount > 0) {
        streaksList.add('- ${habit.name}: ${streak.currentCount} days');
      }
    }
    final activeStreaks = streaksList.isNotEmpty
        ? streaksList.join('\n')
        : 'No active streaks yet.';

    return (
      goals: goals,
      goodHabits: goodHabits,
      badHabits: badHabits,
      todayTasks: todayTasks,
      activeHabits: activeHabitsText,
      activeStreaks: activeStreaks,
    );
  }

  String _formatHabitSummary(HabitModel habit) {
    if (habit.kind == HabitKind.good) {
      final goalText = habit.dailyGoal != null
          ? 'goal: ${habit.dailyGoal} ${habit.unit}/day'
          : 'goal: show up';
      return '- ${habit.name} (build, $goalText)';
    }

    final goalText = switch (habit.goalType ?? BadHabitGoalType.awarenessOnly) {
      BadHabitGoalType.eliminate => 'goal: eliminate',
      BadHabitGoalType.reduceToTarget =>
        'goal: <= ${habit.target ?? "target"} ${habit.unit}/day',
      BadHabitGoalType.awarenessOnly => 'goal: awareness',
    };
    return '- ${habit.name} (reduce, $goalText)';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
