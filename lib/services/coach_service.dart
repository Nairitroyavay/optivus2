import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:optivus2/services/task_service.dart';
import 'package:optivus2/services/streak_service.dart';
import 'package:optivus2/services/habit_service.dart';
import 'package:optivus2/core/utils/uuid_generator.dart';
import 'package:optivus2/models/coach_rule.dart';
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
    // 1. Fetch onboarding data for goals and bad habits
    final onboardingSnapshot = await _userRepo.getOnboardingData();
    final onboarding = onboardingSnapshot?.onboarding;
    final goals = (onboarding?['goals'] as List?)?.join(', ') ?? 'No specific goals set';
    final badHabits = (onboarding?['badHabits'] as List?)?.join(', ') ?? 'None specified';

    // 2. Fetch today's tasks
    final today = DateTime.now();
    final tasks = await _taskService.tasksFor(today).first;
    final tasksList = tasks
        .map((t) => "- ${t.type.name} at ${t.plannedStart.hour}:${t.plannedStart.minute.toString().padLeft(2, '0')}")
        .join('\n');

    // 3. Fetch active streaks
    final activeHabits = await _habitService.habits().first;
    final streaksList = <String>[];
    for (var habit in activeHabits) {
      final streak = await _streakService.getStreak(habit.id);
      if (streak != null && streak.currentCount > 0) {
        streaksList.add("- ${habit.name}: ${streak.currentCount} days");
      }
    }
    final streaksText = streaksList.isNotEmpty ? streaksList.join('\n') : "No active streaks yet.";

    return '''You are the user's personal Optivus AI life coach. Your name is $coachName.
Your tone should be: $tone.
User's main goals: $goals.
Habits trying to break: $badHabits.

Current Context:
Today's Tasks:
${tasksList.isEmpty ? "None scheduled for today." : tasksList}

Active Streaks:
$streaksText

You are embedded in their daily timeline app. Keep responses engaging, supportive, and relatively concise (1-3 paragraphs max) so they fit well in a chat bubble.''';
  }

  Future<GeminiChatSession> startChat(String coachName, String tone, {List<Map<String, dynamic>>? initialHistory}) async {
    final systemPrompt = await generateSystemPrompt(coachName, tone);
    return GeminiService().startChat(systemPrompt, initialHistory: initialHistory);
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
      'triggerEventId': triggerEvent.eventId,
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
      userRef.collection('coach_chats').doc('main_thread').collection('turns').doc(messageId),
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
        'triggerEventId': triggerEvent.eventId,
        'ruleId': rule.id,
        'decision': 'spoke',
        'messageId': messageId,
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
      'ruleId': ruleId,       // null when no rule matched
      'decision': decision,
      'messageId': messageId, // null for all drop decisions
      'createdAt': Timestamp.fromDate(now),
      'schemaVersion': 1,
    });

    debugPrint('[CoachService] DECISION — '
        'decision=$decision ruleId=$ruleId '
        'trigger=$triggerEventId logId=$logId');
  }
}
