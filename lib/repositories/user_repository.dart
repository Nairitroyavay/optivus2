import '../services/firestore_service.dart';
import '../models/goal_model.dart';
import '../models/habit_model.dart';
import '../models/user_model.dart';

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
      'scheduleItems': List<Map<String, dynamic>>.from(
        (onboardingMap['scheduleItems'] as List? ?? const []).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      ),
      'aboutYou': aboutYou,
      'completedAt': completedAt,
    };
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
  Future<void> completeOnboarding(Map<String, dynamic> onboardingMap) async {
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

    await _materializeOnboardingSelections(
      onboardingMap,
      completedAt: DateTime.parse(completedAt),
    );
  }

  Future<void> _materializeOnboardingSelections(
    Map<String, dynamic> onboardingMap, {
    required DateTime completedAt,
  }) async {
    final goodHabits =
        List<String>.from(onboardingMap['goodHabits'] as List? ?? const []);
    final badHabits =
        List<String>.from(onboardingMap['badHabits'] as List? ?? const []);
    final goals =
        List<String>.from(onboardingMap['goals'] as List? ?? const []);
    final scheduleItems = List<Map<String, dynamic>>.from(
      (onboardingMap['scheduleItems'] as List? ?? const []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );

    for (final name
        in goodHabits.map(_cleanLabel).where((name) => name.isNotEmpty)) {
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

    for (final title
        in goals.map(_cleanLabel).where((goal) => goal.isNotEmpty)) {
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

    final fixedBlocks = scheduleItems
        .where((item) =>
            item['isAdd'] != true &&
            _cleanLabel(item['title'] as String? ?? '').isNotEmpty &&
            ((item['duration'] as num?)?.toDouble() ?? 0) > 0)
        .map((item) {
      final title = _cleanLabel(item['title'] as String? ?? '');
      final startHours =
          ((item['start'] as num?)?.toDouble() ?? 0).clamp(0, 24);
      final durationHours =
          ((item['duration'] as num?)?.toDouble() ?? 0).clamp(0.25, 24);
      final startMinute = (startHours * 60).round().clamp(0, 1439).toInt();
      final endMinute = ((startHours + durationHours) * 60)
          .round()
          .clamp(startMinute + 1, 1440)
          .toInt();
      final rawId = _cleanLabel(item['id'] as String? ?? '');
      final id = rawId.isNotEmpty ? _slug(rawId) : _slug(title);

      return {
        'id': id,
        'title': title,
        'emoji': _emojiForScheduleTitle(title),
        'startMinute': startMinute,
        'endMinute': endMinute,
        'colorHex': _colorHexFromArgb(item['color']),
      };
    }).toList();

    if (fixedBlocks.isNotEmpty) {
      final existingRoutine = await _service.getRoutine();
      await _service.saveRoutine({
        ...?existingRoutine,
        'fixedBlocks': fixedBlocks,
        'fixedScheduleSetUp': true,
      });
    }
  }

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
    return '📌';
  }

  String _colorHexFromArgb(Object? value) {
    if (value is num) {
      final rgb = value.toInt() & 0xFFFFFF;
      return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
    }
    return '#CBD5E1';
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
