import '../services/firestore_service.dart';
import '../models/context_snapshot.dart';
import '../models/goal_model.dart';
import '../models/habit_model.dart';
import '../models/scheduled_notification_model.dart';
import '../models/task_model.dart';
import '../models/user_model.dart';

class OnboardingCompletionResult {
  final Map<String, dynamic> onboarding;
  final List<TaskModel> tasks;
  final List<ScheduledNotification> notifications;
  final List<Map<String, dynamic>> suggestions;
  final Map<String, dynamic> snapshot;

  const OnboardingCompletionResult({
    required this.onboarding,
    required this.tasks,
    required this.notifications,
    required this.suggestions,
    required this.snapshot,
  });
}

class _OnboardingMaterializationResult {
  final List<TaskModel> tasks;
  final List<ScheduledNotification> notifications;
  final List<Map<String, dynamic>> suggestions;
  final Map<String, dynamic> snapshot;

  const _OnboardingMaterializationResult({
    required this.tasks,
    required this.notifications,
    required this.suggestions,
    required this.snapshot,
  });
}

class OnboardingDataSnapshot {
  final Map<String, dynamic> onboarding;
  final int step;
  final bool hasCompletedOnboarding;
  final String? completedAt;

  const OnboardingDataSnapshot({
    required this.onboarding,
    required this.step,
    required this.hasCompletedOnboarding,
    required this.completedAt,
  });
}

class UserRepository {
  final FirestoreService _service;

  UserRepository(this._service);

  // ── Auth Check ──────────────────────────────────────────────────────────────

  /// Whether a user is currently authenticated.
  /// Use this instead of accessing FirebaseAuth.instance directly.
  bool get isLoggedIn {
    try {
      _service.uid; // throws if not logged in
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── User Profile ────────────────────────────────────────────────────────────

  Future<void> saveUser(UserModel user) async {
    await _service.saveUserProfile(user.toMap());
  }

  Future<UserModel?> getUser(String uid) async {
    final data = await _service.getUserProfile();
    if (data != null) {
      return UserModel.fromMap(data);
    }
    return null;
  }

  // ── Onboarding Data ─────────────────────────────────────────────────────────

  Map<String, dynamic> _sanitizeOnboardingMap(
    Map<String, dynamic> onboardingMap, {
    String? completedAt,
  }) {
    final aboutYou = _sanitizeAboutYou(onboardingMap['aboutYou']);
    return {
      'selectedCategories': List<String>.from(
          onboardingMap['selectedCategories'] as List? ?? const []),
      'badHabits':
          List<String>.from(onboardingMap['badHabits'] as List? ?? const []),
      'goodHabits':
          List<String>.from(onboardingMap['goodHabits'] as List? ?? const []),
      'goals': List<String>.from(onboardingMap['goals'] as List? ?? const []),
      'coachStyle': onboardingMap['coachStyle'] as String? ?? 'Supportive',
      'coachName': onboardingMap['coachName'] as String? ?? '',
      'accountabilityType':
          onboardingMap['accountabilityType'] as String? ?? 'Strict',
      'fixedSchedule': _sanitizeFixedSchedule(onboardingMap['fixedSchedule']),
      'aboutYou': aboutYou,
      'completedAt': completedAt,
    };
  }

  List<Map<String, dynamic>> _sanitizeFixedSchedule(Object? raw) {
    final items = raw is List ? raw : const [];
    return [
      for (var i = 0; i < items.length; i++)
        if (items[i] is Map)
          _sanitizeFixedScheduleItem(
            Map<String, dynamic>.from(items[i] as Map),
            i,
          ),
    ];
  }

  Map<String, dynamic> _sanitizeFixedScheduleItem(
    Map<String, dynamic> item,
    int index,
  ) {
    final now = DateTime.now().toIso8601String();
    final templateId = _cleanLabel(item['templateId']?.toString() ?? '');
    final createdAt = _cleanLabel(item['createdAt']?.toString() ?? '');
    final updatedAt = _cleanLabel(item['updatedAt']?.toString() ?? '');

    return {
      'templateId':
          templateId.isNotEmpty ? templateId : 'fixed_schedule_${index + 1}',
      'title': _cleanLabel(item['title']?.toString() ?? ''),
      'routineType': 'fixed_schedule',
      'startTime': _sanitizeTime(item['startTime'], fallback: '09:00'),
      'endTime': _sanitizeTime(item['endTime'], fallback: '10:00'),
      'repeatRule': 'daily',
      'category': _cleanLabel(item['category']?.toString() ?? ''),
      'notes': _cleanLabel(item['notes']?.toString() ?? ''),
      'isActive': item['isActive'] as bool? ?? true,
      'createdAt': createdAt.isNotEmpty ? createdAt : now,
      'updatedAt': updatedAt.isNotEmpty ? updatedAt : now,
    };
  }

  String _sanitizeTime(Object? value, {required String fallback}) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$')
        .firstMatch(value?.toString().trim() ?? '');
    if (match == null) return fallback;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return fallback;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return fallback;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> _sanitizeAboutYou(Object? raw) {
    final map =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final body = map['bodyBasics'] is Map
        ? Map<String, dynamic>.from(map['bodyBasics'] as Map)
        : <String, dynamic>{};
    final lifestyle = map['lifestyle'] is Map
        ? Map<String, dynamic>.from(map['lifestyle'] as Map)
        : <String, dynamic>{};
    final sensitive = map['sensitiveContext'] is Map
        ? Map<String, dynamic>.from(map['sensitiveContext'] as Map)
        : <String, dynamic>{};

    final heightCm = (body['heightCm'] as num?)?.toInt();
    final weightKg = (body['weightKg'] as num?)?.toDouble();
    if (heightCm != null && (heightCm < 90 || heightCm > 250)) {
      throw ArgumentError('Height must be between 90 cm and 250 cm.');
    }
    if (weightKg != null && (weightKg < 25 || weightKg > 300)) {
      throw ArgumentError('Weight must be between 25 kg and 300 kg.');
    }

    return {
      'bodyBasics': {
        'ageRange': body['ageRange'] as String?,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'gender': body['gender'] as String?,
        'wakeTime': body['wakeTime'] as String?,
        'sleepTime': body['sleepTime'] as String?,
        'timezone': body['timezone'] as String?,
      },
      'lifestyle': {
        'schoolWorkType': lifestyle['schoolWorkType'] as String?,
        'exerciseLevel': lifestyle['exerciseLevel'] as String?,
        'waterIntake': lifestyle['waterIntake'] as String?,
        'dietPreference': lifestyle['dietPreference'] as String?,
        'stressLevel': lifestyle['stressLevel'] as String?,
        'sleepQuality': lifestyle['sleepQuality'] as String?,
      },
      'sensitiveContext': {
        'eatingDisorderFlag': sensitive['eatingDisorderFlag'] as bool?,
        'crisisSelfHarmFlag': sensitive['crisisSelfHarmFlag'] as bool?,
        'medicalDisclaimerAcknowledged':
            sensitive['medicalDisclaimerAcknowledged'] as bool? ?? false,
        'coachBoundaryPreference':
            sensitive['coachBoundaryPreference'] as String?,
      },
    };
  }

  Map<String, dynamic> _buildRootOnboardingPayload(
    Map<String, dynamic> onboardingMap, {
    required int step,
    required bool hasCompletedOnboarding,
    required String updatedAt,
    String? completedAt,
  }) {
    return {
      ..._sanitizeOnboardingMap(onboardingMap, completedAt: completedAt),
      'onboardingStep': step,
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'updatedAt': updatedAt,
    };
  }

  Map<String, dynamic> _buildOnboardingStateDoc(
    Map<String, dynamic> onboardingMap, {
    required int step,
    required bool hasCompletedOnboarding,
    required String updatedAt,
    String? completedAt,
  }) {
    return {
      ..._sanitizeOnboardingMap(onboardingMap, completedAt: completedAt),
      'onboardingStep': step,
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'status': hasCompletedOnboarding ? 'completed' : 'in_progress',
      'updatedAt': updatedAt,
    };
  }

  Map<String, dynamic> _buildProfileMainDoc(
    Map<String, dynamic> onboardingMap, {
    required int step,
    required bool hasCompletedOnboarding,
    required String updatedAt,
    String? completedAt,
  }) {
    final aboutYou = _sanitizeAboutYou(onboardingMap['aboutYou']);
    return {
      ..._sanitizeOnboardingMap(onboardingMap, completedAt: completedAt),
      'biometrics': aboutYou['bodyBasics'],
      'lifestyle': aboutYou['lifestyle'],
      'sensitiveContext': aboutYou['sensitiveContext'],
      'onboardingStep': step,
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'source': 'onboarding',
      'updatedAt': updatedAt,
    };
  }

  Map<String, dynamic> _buildIdentityProfileStub(
    Map<String, dynamic> onboardingMap, {
    required int step,
    required bool hasCompletedOnboarding,
    required String updatedAt,
    String? completedAt,
  }) {
    final aboutYou = _sanitizeAboutYou(onboardingMap['aboutYou']);
    return {
      'status': 'stub',
      'source': 'onboarding',
      'selectedCategories': List<String>.from(
          onboardingMap['selectedCategories'] as List? ?? const []),
      'goals': List<String>.from(onboardingMap['goals'] as List? ?? const []),
      'coachStyle': onboardingMap['coachStyle'] as String? ?? 'Supportive',
      'coachName': onboardingMap['coachName'] as String? ?? '',
      'accountabilityType':
          onboardingMap['accountabilityType'] as String? ?? 'Strict',
      'biometrics': aboutYou['bodyBasics'],
      'lifestyle': aboutYou['lifestyle'],
      'sensitiveContext': aboutYou['sensitiveContext'],
      'onboardingStep': step,
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'completedAt': completedAt,
      'updatedAt': updatedAt,
    };
  }

  String? _timezoneFromAboutYou(Map<String, dynamic> onboardingMap) {
    final aboutYou = _sanitizeAboutYou(onboardingMap['aboutYou']);
    final bodyBasics = aboutYou['bodyBasics'];
    if (bodyBasics is! Map) return null;
    final timezone = bodyBasics['timezone'] as String?;
    return timezone == null || timezone.trim().isEmpty ? null : timezone;
  }

  /// Save onboarding data merged into the user profile document.
  Future<void> saveOnboardingData(
    Map<String, dynamic> onboardingMap, {
    int step = 0,
  }) async {
    final now = DateTime.now().toIso8601String();
    final rootOnboarding = _buildRootOnboardingPayload(
      onboardingMap,
      step: step,
      hasCompletedOnboarding: false,
      updatedAt: now,
    );

    final timezone = _timezoneFromAboutYou(onboardingMap);
    await _service.saveUserProfile({
      'onboarding': rootOnboarding,
      'onboardingStep': step,
      if (timezone != null) 'timezone': timezone,
      'updatedAt': now,
    }, merge: true);

    await _service.saveUserSubdocument(
      'onboarding',
      'state',
      _buildOnboardingStateDoc(
        onboardingMap,
        step: step,
        hasCompletedOnboarding: false,
        updatedAt: now,
      ),
    );

    await _service.saveUserSubdocument(
      'profile',
      'main',
      _buildProfileMainDoc(
        onboardingMap,
        step: step,
        hasCompletedOnboarding: false,
        updatedAt: now,
      ),
    );

    await _service.saveUserSubdocument(
      'identity_profile',
      'main',
      _buildIdentityProfileStub(
        onboardingMap,
        step: step,
        hasCompletedOnboarding: false,
        updatedAt: now,
      ),
    );
  }

  /// Complete onboarding by setting hasCompletedOnboarding to true.
  Future<OnboardingCompletionResult> completeOnboarding(
      Map<String, dynamic> onboardingMap) async {
    final completedAt = DateTime.now().toIso8601String();
    final rootOnboarding = _buildRootOnboardingPayload(
      onboardingMap,
      step: 10,
      hasCompletedOnboarding: true,
      updatedAt: completedAt,
      completedAt: completedAt,
    );

    final timezone = _timezoneFromAboutYou(onboardingMap);
    await _service.saveUserProfile({
      'onboarding': rootOnboarding,
      'hasCompletedOnboarding': true,
      'onboardingStep': 10, // The final step
      if (timezone != null) 'timezone': timezone,
      'updatedAt': completedAt,
    }, merge: true);

    await _service.saveUserSubdocument(
      'onboarding',
      'state',
      _buildOnboardingStateDoc(
        onboardingMap,
        step: 10,
        hasCompletedOnboarding: true,
        updatedAt: completedAt,
        completedAt: completedAt,
      ),
    );

    await _service.saveUserSubdocument(
      'profile',
      'main',
      _buildProfileMainDoc(
        onboardingMap,
        step: 10,
        hasCompletedOnboarding: true,
        updatedAt: completedAt,
        completedAt: completedAt,
      ),
    );

    await _service.saveUserSubdocument(
      'identity_profile',
      'main',
      _buildIdentityProfileStub(
        onboardingMap,
        step: 10,
        hasCompletedOnboarding: true,
        updatedAt: completedAt,
        completedAt: completedAt,
      ),
    );

    final materialized = await _materializeOnboardingSelections(
      onboardingMap,
      completedAt: DateTime.parse(completedAt),
    );
    return OnboardingCompletionResult(
      onboarding: rootOnboarding,
      tasks: materialized.tasks,
      notifications: materialized.notifications,
      suggestions: materialized.suggestions,
      snapshot: materialized.snapshot,
    );
  }

  Future<_OnboardingMaterializationResult> _materializeOnboardingSelections(
    Map<String, dynamic> onboardingMap, {
    required DateTime completedAt,
  }) async {
    final rawGoodHabits =
        List<String>.from(onboardingMap['goodHabits'] as List? ?? const []);
    final badHabits =
        List<String>.from(onboardingMap['badHabits'] as List? ?? const []);
    final rawGoals =
        List<String>.from(onboardingMap['goals'] as List? ?? const []);
    final fixedSchedule = _effectiveFixedSchedule(
      _sanitizeFixedSchedule(onboardingMap['fixedSchedule']),
      completedAt,
    );
    final goodHabits = rawGoodHabits
        .map(_cleanLabel)
        .where((name) => name.isNotEmpty)
        .toList();
    final goals =
        rawGoals.map(_cleanLabel).where((goal) => goal.isNotEmpty).toList();
    final habitNames =
        goodHabits.isNotEmpty ? goodHabits : const ['Review daily plan'];
    final goalTitles = goals.isNotEmpty
        ? goals
        : const ['Complete today with one finished block'];
    final createdTasks = <TaskModel>[];
    final scheduledNotifications = <ScheduledNotification>[];

    for (final name in habitNames) {
      final id = 'onboarding_good_${_slug(name)}';
      if (await _service.getUserSubdocument('habits', id) != null) continue;
      await _service.saveUserSubdocument(
        'habits',
        id,
        HabitModel(
          id: id,
          name: name,
          kind: HabitKind.good,
          unit: 'count',
          trackerType: _trackerTypeFor(name),
          dailyGoal: 1,
          identityTags: [name],
          emoji: _emojiForHabit(name, HabitKind.good),
          color: '#22C55E',
          createdAt: completedAt,
          updatedAt: completedAt,
        ).toFirestore(),
      );
    }

    for (final name
        in badHabits.map(_cleanLabel).where((name) => name.isNotEmpty)) {
      final id = 'onboarding_bad_${_slug(name)}';
      if (await _service.getUserSubdocument('habits', id) != null) continue;
      await _service.saveUserSubdocument(
        'habits',
        id,
        HabitModel(
          id: id,
          name: name,
          kind: HabitKind.bad,
          unit: 'count',
          trackerType: _trackerTypeFor(name),
          goalType: BadHabitGoalType.awarenessOnly,
          identityTags: [name],
          emoji: _emojiForHabit(name, HabitKind.bad),
          color: '#EF4444',
          createdAt: completedAt,
          updatedAt: completedAt,
        ).toFirestore(),
      );
    }

    for (final title in goalTitles) {
      final id = 'onboarding_goal_${_slug(title)}';
      if (await _service.getUserSubdocument('goals', id) != null) continue;
      await _service.saveUserSubdocument(
        'goals',
        id,
        GoalModel(
          id: id,
          title: title,
          identityTags: [title],
          colorHex: '#22C55E',
          iconName: 'flag_rounded',
          source: 'onboarding',
          createdAt: completedAt,
          updatedAt: completedAt,
        ).toFirestore(),
      );
    }

    final templates = fixedSchedule
        .where(
            (item) => _cleanLabel(item['title']?.toString() ?? '').isNotEmpty)
        .toList();

    final existingRoutine = await _service.getRoutine() ?? {};
    final existingTemplates = existingRoutine['templates'] is Map
        ? Map<String, dynamic>.from(existingRoutine['templates'] as Map)
        : <String, dynamic>{};
    await _service.saveRoutine({
      ...existingRoutine,
      'templates': {
        ...existingTemplates,
        'fixed_schedule': templates,
      },
      'fixedScheduleSetUp': templates.isNotEmpty,
    });

    final todayTasks = _buildTodayTasksFromTemplates(
      templates,
      completedAt: completedAt,
    );
    for (final task in todayTasks) {
      await _service.saveUserSubdocument(
        'tasks',
        task.id,
        task.toFirestore(),
      );
      createdTasks.add(task);
    }

    final notifications = _buildStarterNotifications(
      todayTasks,
      completedAt: completedAt,
    );
    for (final notification in notifications) {
      await _service.saveUserSubdocument(
        'scheduled_notifications',
        notification.notifId,
        notification.toFirestore(),
      );
      scheduledNotifications.add(notification);
    }

    final suggestions = _buildStarterSuggestions(
      onboardingMap,
      fixedSchedule: templates,
      habits: habitNames,
      goals: goalTitles,
      completedAt: completedAt,
    );
    final snapshot = _buildInitialContextSnapshot(
      onboardingMap,
      taskCount: createdTasks.length,
      habitCount: habitNames.length + badHabits.length,
      goalCount: goalTitles.length,
      notificationCount: scheduledNotifications.length,
      suggestions: suggestions,
      completedAt: completedAt,
    );
    await _service.saveUserSubdocument(
      'ai_context_snapshots',
      snapshot['snapshotId'] as String,
      snapshot,
    );

    return _OnboardingMaterializationResult(
      tasks: createdTasks,
      notifications: scheduledNotifications,
      suggestions: suggestions,
      snapshot: snapshot,
    );
  }

  List<Map<String, dynamic>> _effectiveFixedSchedule(
    List<Map<String, dynamic>> fixedSchedule,
    DateTime completedAt,
  ) {
    final nonBlank = fixedSchedule
        .where(
            (item) => _cleanLabel(item['title']?.toString() ?? '').isNotEmpty)
        .toList();
    if (nonBlank.isNotEmpty) return nonBlank;

    final now = completedAt.toIso8601String();
    return [
      {
        'templateId': 'starter_morning_focus',
        'title': 'Morning Focus',
        'routineType': 'fixed_schedule',
        'startTime': '09:00',
        'endTime': '09:30',
        'repeatRule': 'daily',
        'category': 'Focus',
        'notes': 'Start with one clear priority.',
        'isActive': true,
        'createdAt': now,
        'updatedAt': now,
      },
      {
        'templateId': 'starter_habit_check',
        'title': 'Habit Check-in',
        'routineType': 'fixed_schedule',
        'startTime': '13:00',
        'endTime': '13:15',
        'repeatRule': 'daily',
        'category': 'Habits',
        'notes': 'Log one habit and reset the day.',
        'isActive': true,
        'createdAt': now,
        'updatedAt': now,
      },
      {
        'templateId': 'starter_evening_review',
        'title': 'Evening Review',
        'routineType': 'fixed_schedule',
        'startTime': '20:30',
        'endTime': '20:45',
        'repeatRule': 'daily',
        'category': 'Review',
        'notes': 'Close the day and pick tomorrow\'s first block.',
        'isActive': true,
        'createdAt': now,
        'updatedAt': now,
      },
    ];
  }

  List<TaskModel> _buildTodayTasksFromTemplates(
    List<Map<String, dynamic>> templates, {
    required DateTime completedAt,
  }) {
    final today =
        DateTime(completedAt.year, completedAt.month, completedAt.day);
    final dateKey = _dateKey(today);
    return templates.map((template) {
      final templateId =
          _cleanLabel(template['templateId']?.toString() ?? 'template');
      final title = _cleanLabel(template['title']?.toString() ?? '');
      final startMinutes =
          _minutesFromTime(template['startTime'], fallback: '09:00');
      final endMinutes =
          _minutesFromTime(template['endTime'], fallback: '10:00');
      final plannedStart = today.add(Duration(minutes: startMinutes));
      var plannedEnd = today.add(Duration(minutes: endMinutes));
      if (!plannedEnd.isAfter(plannedStart)) {
        plannedEnd = plannedEnd.add(const Duration(days: 1));
      }
      return TaskModel(
        id: 'onboarding_${dateKey}_${_slug(templateId)}',
        type: TaskType.fixed,
        parentRoutine: templateId,
        title: title.isNotEmpty ? title : 'Routine block',
        emoji: _emojiForScheduleTitle(title),
        color: '#CBD5E1',
        identityTags: [if (title.isNotEmpty) title],
        plannedStart: plannedStart,
        plannedEnd: plannedEnd,
        createdAt: completedAt,
        updatedAt: completedAt,
      );
    }).toList();
  }

  List<ScheduledNotification> _buildStarterNotifications(
    List<TaskModel> tasks, {
    required DateTime completedAt,
  }) {
    final now = DateTime.now();
    return tasks.take(3).toList().asMap().entries.map((entry) {
      final task = entry.value;
      var scheduledFor = task.plannedStart.subtract(const Duration(minutes: 5));
      if (!scheduledFor.isAfter(now)) {
        scheduledFor = now.add(Duration(minutes: 15 * (entry.key + 1)));
      }
      return ScheduledNotification(
        notifId: 'onboarding_task_reminder_${task.id}',
        category: NotifCategory.taskReminder,
        scheduledFor: scheduledFor,
        taskId: task.id,
        createdAt: completedAt,
      );
    }).toList();
  }

  List<Map<String, dynamic>> _buildStarterSuggestions(
    Map<String, dynamic> onboardingMap, {
    required List<Map<String, dynamic>> fixedSchedule,
    required List<String> habits,
    required List<String> goals,
    required DateTime completedAt,
  }) {
    final coachStyle = onboardingMap['coachStyle'] as String? ?? 'Supportive';
    return [
      {
        'suggestionId': 'onboarding_start_first_block',
        'title': 'Start with the first scheduled block',
        'body': fixedSchedule.isEmpty
            ? 'Use the starter plan today, then customize it after your first run.'
            : 'Treat your first fixed block as today\'s anchor.',
        'source': 'onboarding_deterministic',
        'createdAt': completedAt.toIso8601String(),
      },
      {
        'suggestionId': 'onboarding_log_one_habit',
        'title': 'Log one habit today',
        'body': 'Focus on ${habits.first}. One clean log is enough to begin.',
        'source': 'onboarding_deterministic',
        'createdAt': completedAt.toIso8601String(),
      },
      {
        'suggestionId': 'onboarding_goal_review',
        'title': 'Connect the plan to your top goal',
        'body':
            'Use the $coachStyle coach style to stay aligned with ${goals.first}.',
        'source': 'onboarding_deterministic',
        'createdAt': completedAt.toIso8601String(),
      },
    ];
  }

  Map<String, dynamic> _buildInitialContextSnapshot(
    Map<String, dynamic> onboardingMap, {
    required int taskCount,
    required int habitCount,
    required int goalCount,
    required int notificationCount,
    required List<Map<String, dynamic>> suggestions,
    required DateTime completedAt,
  }) {
    final snapshotId = 'onboarding_initial_${_dateKey(completedAt)}';
    return {
      'snapshotId': snapshotId,
      ...const ContextSnapshot(
        userState: 'on_track',
        notificationsSentToday: 0,
        dailyNotificationBudget: 3,
      ).toMap(),
      'source': 'onboarding',
      'onboardingStep': 10,
      'coachStyle': onboardingMap['coachStyle'] as String? ?? 'Supportive',
      'routineTaskCount': taskCount,
      'habitCount': habitCount,
      'goalCount': goalCount,
      'scheduledNotificationCount': notificationCount,
      'suggestions': suggestions,
      'createdAt': completedAt.toIso8601String(),
      'updatedAt': completedAt.toIso8601String(),
      'schemaVersion': 1,
    };
  }

  int _minutesFromTime(Object? value, {required String fallback}) {
    final normalized = _sanitizeTime(value, fallback: fallback);
    final parts = normalized.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

  String _cleanLabel(String value) => value.replaceAll('\n', ' ').trim();

  String _slug(String value) {
    final slug = _cleanLabel(value)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return slug.isEmpty ? 'item' : slug;
  }

  String _trackerTypeFor(String name) {
    final key = name.toLowerCase();
    if (key.contains('gym') ||
        key.contains('exercise') ||
        key.contains('workout')) {
      return 'exercise';
    }
    if (key.contains('read')) return 'reading';
    if (key.contains('scroll')) return 'screen_time';
    if (key.contains('food')) return 'nutrition';
    if (key.contains('procrast')) return 'procrastination';
    if (key.contains('cigarette') || key.contains('smok')) return 'smoking';
    return 'generic';
  }

  String _emojiForHabit(String name, HabitKind kind) {
    final key = name.toLowerCase();
    if (key.contains('gym') || key.contains('workout')) return '💪';
    if (key.contains('read')) return '📚';
    if (key.contains('cigarette') || key.contains('smok')) return '🚭';
    if (key.contains('scroll')) return '📱';
    if (key.contains('food')) return '🍟';
    if (key.contains('procrast')) return '⏳';
    return kind == HabitKind.good ? '✅' : '⚠️';
  }

  String _emojiForScheduleTitle(String title) {
    final key = title.toLowerCase();
    if (key.contains('sleep')) return '🛏️';
    if (key.contains('class') || key.contains('study')) return '🎓';
    if (key.contains('work')) return '💼';
    if (key.contains('gym') || key.contains('workout')) return '💪';
    if (key.contains('meal') ||
        key.contains('dinner') ||
        key.contains('food')) {
      return '🍽️';
    }
    if (key.contains('habit')) return '✅';
    if (key.contains('review')) return '📝';
    return '📌';
  }

  /// Load onboarding data from the user profile.
  Future<OnboardingDataSnapshot?> getOnboardingData() async {
    final stateDoc = await _service.getUserSubdocument('onboarding', 'state');
    if (stateDoc != null) {
      final data = Map<String, dynamic>.from(stateDoc);
      return OnboardingDataSnapshot(
        onboarding: data,
        step: (data['onboardingStep'] as num?)?.toInt() ?? 0,
        hasCompletedOnboarding:
            data['hasCompletedOnboarding'] as bool? ?? false,
        completedAt: data['completedAt'] as String?,
      );
    }

    final profile = await _service.getUserProfile();
    if (profile != null && profile['onboarding'] != null) {
      final data = Map<String, dynamic>.from(profile['onboarding']);
      return OnboardingDataSnapshot(
        onboarding: data,
        step: (profile['onboardingStep'] as num?)?.toInt() ??
            (data['onboardingStep'] as num?)?.toInt() ??
            0,
        hasCompletedOnboarding: profile['hasCompletedOnboarding'] as bool? ??
            data['hasCompletedOnboarding'] as bool? ??
            false,
        completedAt: data['completedAt'] as String?,
      );
    }
    return null;
  }
}
