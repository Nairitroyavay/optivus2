import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:optivus2/core/config/app_config.dart';
import 'package:optivus2/core/constants/event_names.dart';
import 'package:optivus2/models/context_snapshot.dart';
import 'package:optivus2/services/cloudflare_api_service.dart';
import 'package:optivus2/services/task_service.dart';
import 'package:optivus2/services/streak_service.dart';
import 'package:optivus2/services/habit_service.dart';
import 'package:optivus2/core/utils/uuid_generator.dart';
import 'package:optivus2/models/coach_rule.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/models/event_model.dart';
import 'package:optivus2/repositories/user_repository.dart';
import 'package:optivus2/services/event_service.dart';
import 'package:optivus2/services/gemini_service.dart';

typedef CoachReplyClient = Future<CoachReplyResult> Function({
  required String threadId,
  required String text,
  required String mode,
});

typedef CoachEventEmitter = Future<void> Function(
  String eventName,
  Map<String, dynamic> payload, {
  String priority,
  String source,
});

enum CoachTopicMode {
  recovery(
      'recovery', 'Recovery', 'Setbacks, urges, and getting back on track'),
  study('study', 'Study', 'Focus, planning, and deep work'),
  calm('calm', 'Calm', 'Stress, overwhelm, and grounding'),
  askAnything('ask_anything', 'Ask Anything', 'Open coaching and questions');

  final String key;
  final String label;
  final String description;

  const CoachTopicMode(this.key, this.label, this.description);

  static CoachTopicMode fromKey(String? key) {
    for (final mode in values) {
      if (mode.key == key) return mode;
    }
    return CoachTopicMode.askAnything;
  }
}

class CoachChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime? createdAt;
  final CoachTopicMode mode;
  final String? safetyBranch;
  final String? messageType;

  const CoachChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.createdAt,
    required this.mode,
    this.safetyBranch,
    this.messageType,
  });

  bool get isCrisis =>
      safetyBranch == 'crisis' || messageType == 'safety_crisis';

  factory CoachChatMessage.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return CoachChatMessage.fromMap(data, fallbackId: doc.id);
  }

  factory CoachChatMessage.fromMap(
    Map<String, dynamic> data, {
    required String fallbackId,
  }) {
    final rawText = data['text'] as String? ??
        data['message'] as String? ??
        data['body'] as String? ??
        '';
    final role = (data['role'] as String?)?.toLowerCase();
    final source = (data['source'] as String?)?.toLowerCase();
    final isUser = data['isUser'] == true || role == 'user' || source == 'user';
    return CoachChatMessage(
      id: data['messageId'] as String? ?? data['id'] as String? ?? fallbackId,
      text: rawText.trim(),
      isUser: isUser,
      createdAt: _parseMessageDate(data['createdAt']) ??
          _parseMessageDate(data['timestamp']),
      mode: CoachTopicMode.fromKey(data['mode'] as String?),
      safetyBranch: data['safetyBranch'] as String?,
      messageType: data['messageType'] as String?,
    );
  }
}

class CoachMessagePage {
  final List<CoachChatMessage> messages;
  final DocumentSnapshot<Map<String, dynamic>>? oldestDocument;
  final bool hasMore;

  const CoachMessagePage({
    required this.messages,
    required this.oldestDocument,
    required this.hasMore,
  });
}

class CoachService {
  static const String mainThreadId = 'main_thread';
  static const String aiDisabledFallbackText =
      'AI coach replies are off right now, but your message is saved. Try one small next step you can do in the next few minutes.';
  static const String missingEndpointFallbackText =
      'AI coach is not connected in this build yet, but your message is saved. Try one small next step you can do in the next few minutes.';

  final TaskService _taskService;
  final StreakService _streakService;
  final HabitService _habitService;
  final UserRepository _userRepo;
  final AppFeatureFlags? _featureFlags;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final CoachReplyClient? _coachReplyClient;
  final CoachEventEmitter? _eventEmitter;
  final AppBuildConfig _buildConfig;

  CoachService({
    required TaskService taskService,
    required StreakService streakService,
    required HabitService habitService,
    required UserRepository userRepo,
    AppFeatureFlags? featureFlags,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    CoachReplyClient? coachReplyClient,
    CoachEventEmitter? eventEmitter,
    AppBuildConfig? buildConfig,
  })  : _taskService = taskService,
        _streakService = streakService,
        _habitService = habitService,
        _userRepo = userRepo,
        _featureFlags = featureFlags,
        _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _coachReplyClient = coachReplyClient,
        _eventEmitter = eventEmitter,
        _buildConfig = buildConfig ?? AppBuildConfig.current;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Cannot use coach chat without authentication');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> _messagesRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('coach_messages');

  Future<String> loadCoachName() async {
    final onboardingSnapshot = await _userRepo.getOnboardingData();
    final onboarding = onboardingSnapshot?.onboarding;
    final name = (onboarding?['coachName'] as String?)?.trim();
    return name == null || name.isEmpty ? 'AI Coach' : name;
  }

  Future<CoachMessagePage> loadMessagesPage({
    int limit = 30,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final uid = _uid;
    Query<Map<String, dynamic>> query =
        _messagesRef(uid).orderBy('createdAt', descending: true).limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await query.get();
    final messages = snap.docs
        .map(CoachChatMessage.fromDoc)
        .where((message) => message.text.isNotEmpty)
        .toList(growable: false)
        .reversed
        .toList(growable: false);

    return CoachMessagePage(
      messages: messages,
      oldestDocument: snap.docs.isEmpty ? startAfter : snap.docs.last,
      hasMore: snap.docs.length == limit,
    );
  }

  Stream<List<CoachChatMessage>> watchLatestMessages({int limit = 40}) {
    final uid = _uid;
    return _messagesRef(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(CoachChatMessage.fromDoc)
              .where((message) => message.text.isNotEmpty)
              .toList(growable: false)
              .reversed
              .toList(growable: false),
        );
  }

  Future<CoachChatMessage> saveUserMessage({
    required String text,
    required CoachTopicMode mode,
    String threadId = mainThreadId,
  }) async {
    final uid = _uid;
    final now = DateTime.now();
    final messageId = generateId();
    final trimmed = text.trim();
    final data = <String, dynamic>{
      'id': messageId,
      'messageId': messageId,
      'uid': uid,
      'userId': uid,
      'threadId': threadId,
      'sessionId': threadId,
      'role': 'user',
      'isUser': true,
      'text': trimmed,
      'message': trimmed,
      'body': trimmed,
      'mode': mode.key,
      'source': 'user',
      'deliveryType': 'interactive_https',
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'schemaVersion': 1,
    };

    await _messagesRef(uid).doc(messageId).set(data);
    await _emitCoachEvent(
      EventNames.coachMessageSent,
      {'turnId': messageId},
    );

    return CoachChatMessage(
      id: messageId,
      text: trimmed,
      isUser: true,
      createdAt: now,
      mode: mode,
    );
  }

  Future<CoachChatMessage> generateAndSaveAssistantReply({
    required String userText,
    required CoachTopicMode mode,
    String threadId = mainThreadId,
  }) async {
    final uid = _uid;
    if (!(_featureFlags?.aiCoachMessagesReady ?? false)) {
      final hasEndpoint = _buildConfig.cloudflare.hasCoachReplyEndpoint;
      return _saveAssistantMessage(
        uid: uid,
        text:
            hasEndpoint ? aiDisabledFallbackText : missingEndpointFallbackText,
        mode: mode,
        threadId: threadId,
        source: hasEndpoint ? 'local_ai_disabled' : 'local_missing_endpoint',
        aiGenerated: false,
        emitEvent: false,
      );
    }

    final CoachReplyResult result;
    try {
      final replyClient = _coachReplyClient;
      result = replyClient == null
          ? await GeminiService().coachReply(
              threadId: threadId,
              text: userText,
              mode: mode.key,
            )
          : await replyClient(
              threadId: threadId,
              text: userText,
              mode: mode.key,
            );
    } on CloudflareConfigException {
      return _saveAssistantMessage(
        uid: uid,
        text: missingEndpointFallbackText,
        mode: mode,
        threadId: threadId,
        source: 'local_missing_endpoint',
        aiGenerated: false,
        emitEvent: false,
      );
    }

    return _saveAssistantMessage(
      uid: uid,
      text: result.text,
      mode: mode,
      threadId: threadId,
      messageId: result.messageId,
      suggestedActions: result.suggestedActions,
      safetyBranch: result.safetyBranch ?? 'normal',
    );
  }

  Future<CoachChatMessage> _saveAssistantMessage({
    required String uid,
    required String text,
    required CoachTopicMode mode,
    required String threadId,
    String? messageId,
    List<String> suggestedActions = const [],
    String safetyBranch = 'normal',
    String source = 'cloudflare_coach_reply',
    bool? aiGenerated,
    bool emitEvent = true,
  }) async {
    final now = DateTime.now();
    final resolvedMessageId = (messageId?.trim().isNotEmpty ?? false)
        ? messageId!.trim()
        : generateId();
    final trimmed = text.trim();
    final isCrisis = safetyBranch == 'crisis';

    final data = <String, dynamic>{
      'id': resolvedMessageId,
      'messageId': resolvedMessageId,
      'uid': uid,
      'userId': uid,
      'threadId': threadId,
      'sessionId': threadId,
      'role': 'coach',
      'isUser': false,
      'text': trimmed,
      'message': trimmed,
      'body': trimmed,
      'messageType': isCrisis ? 'safety_crisis' : 'coach_reply',
      'mode': mode.key,
      'source': source,
      'deliveryType': 'interactive_https',
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'aiGenerated': aiGenerated ?? !isCrisis,
      'suggestedActions': suggestedActions,
      'safetyBranch': safetyBranch,
      'schemaVersion': 1,
    };

    // TODO(server-trust): move this assistant write and coach_replied event
    // into the Cloudflare Worker once it has a trusted Firebase Admin path.
    await _messagesRef(uid).doc(resolvedMessageId).set(data);
    if (emitEvent) {
      await _emitCoachEvent(
        EventNames.coachReplied,
        {'turnId': resolvedMessageId},
        priority: isCrisis ? 'high' : 'normal',
        source: 'cloudflare_client',
      );
    }

    return CoachChatMessage(
      id: resolvedMessageId,
      text: trimmed,
      isUser: false,
      createdAt: now,
      mode: mode,
      safetyBranch: safetyBranch,
      messageType: isCrisis ? 'safety_crisis' : 'coach_reply',
    );
  }

  Future<void> _emitCoachEvent(
    String eventName,
    Map<String, dynamic> payload, {
    String priority = 'normal',
    String source = 'ui',
  }) async {
    try {
      final eventEmitter = _eventEmitter;
      if (eventEmitter == null) {
        await EventService(auth: _auth, firestore: _firestore).emit(
          eventName: eventName,
          payload: payload,
          priority: priority,
          source: source,
        );
      } else {
        await eventEmitter(
          eventName,
          payload,
          priority: priority,
          source: source,
        );
      }
    } catch (e) {
      debugPrint('[CoachService] $eventName event failed: $e');
    }
  }

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
    String threadId = 'main_thread',
    String mode = 'chat',
  }) async {
    if (!(_featureFlags?.aiCoachMessagesReady ?? false)) {
      throw StateError('AI coach replies are disabled.');
    }
    final systemPrompt = await generateSystemPrompt(coachName, tone);
    return GeminiService().startChat(
      systemPrompt,
      initialHistory: initialHistory,
      threadId: threadId,
      mode: mode,
    );
  }

  /// Builds a structured context payload for the Cloudflare Worker.
  ///
  /// Reads onboarding, today's tasks, habits, and streaks from Firestore
  /// and returns a map that the Worker uses to build an enriched
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
    final resolvedTone = await _resolveCoachTone(
      tone,
      uid: uid,
      snapshot: snapshot,
    );
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

  Future<String> _resolveCoachTone(
    String fallback, {
    String? uid,
    ContextSnapshot? snapshot,
  }) async {
    final resolvedUid = uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (resolvedUid == null) return fallback;

    try {
      final now = DateTime.now();

      // ── Priority 1: 48h Comeback Tone Lock ─────────────────────────────
      // If we already have the value from a snapshot, use it.
      if (snapshot != null && snapshot.isToneLocked) {
        return 'Highly supportive, non-judgmental, and encouraging';
      }

      // If no snapshot or it doesn't have the lock, check Firestore directly
      // (important for one-off calls outside the aggregator flow).
      if (snapshot == null) {
        final profileSnap = await _firestore
            .collection('users')
            .doc(resolvedUid)
            .collection('profile')
            .doc('main')
            .get();
        final profileData = profileSnap.data() ?? const <String, dynamic>{};
        final toneLockUntil = _parseFlexibleDate(profileData['toneLockUntil']);

        if (toneLockUntil != null && toneLockUntil.isAfter(now)) {
          return 'Highly supportive, non-judgmental, and encouraging';
        }
      }

      final userSnap =
          await _firestore.collection('users').doc(resolvedUid).get();
      final root = userSnap.data() ?? const <String, dynamic>{};

      // ── Priority 2: Generic root-level override ────────────────────────
      final rootTone = _unexpiredToneOverride(root, now);
      if (rootTone != null) return rootTone;

      // ── Priority 3: profile/main override ──────────────────────────────
      final profileSnap = await _firestore
          .collection('users')
          .doc(resolvedUid)
          .collection('profile')
          .doc('main')
          .get();
      final profileData = profileSnap.data() ?? const <String, dynamic>{};
      final profileTone = _unexpiredToneOverride(profileData, now);
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

DateTime? _parseMessageDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
