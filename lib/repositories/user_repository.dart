import '../services/firestore_service.dart';
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
    return {
      'selectedCategories':
          List<String>.from(onboardingMap['selectedCategories'] as List? ?? const []),
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
      'completedAt': completedAt,
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
    return {
      ..._sanitizeOnboardingMap(onboardingMap, completedAt: completedAt),
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
    return {
      'status': 'stub',
      'source': 'onboarding',
      'selectedCategories':
          List<String>.from(onboardingMap['selectedCategories'] as List? ?? const []),
      'goals': List<String>.from(onboardingMap['goals'] as List? ?? const []),
      'coachStyle': onboardingMap['coachStyle'] as String? ?? 'Supportive',
      'coachName': onboardingMap['coachName'] as String? ?? '',
      'accountabilityType':
          onboardingMap['accountabilityType'] as String? ?? 'Strict',
      'onboardingStep': step,
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'completedAt': completedAt,
      'updatedAt': updatedAt,
    };
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

    await _service.saveUserProfile({
      'onboarding': rootOnboarding,
      'onboardingStep': step,
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
      step: 9,
      hasCompletedOnboarding: true,
      updatedAt: completedAt,
      completedAt: completedAt,
    );

    await _service.saveUserProfile({
      'onboarding': rootOnboarding,
      'hasCompletedOnboarding': true,
      'onboardingStep': 9, // The final step
      'updatedAt': completedAt,
    }, merge: true);

    await _service.saveUserSubdocument(
      'onboarding',
      'state',
      _buildOnboardingStateDoc(
        onboardingMap,
        step: 9,
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
        step: 9,
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
        step: 9,
        hasCompletedOnboarding: true,
        updatedAt: completedAt,
        completedAt: completedAt,
      ),
    );
  }

  /// Load onboarding data from the user profile.
  Future<OnboardingDataSnapshot?> getOnboardingData() async {
    final stateDoc = await _service.getUserSubdocument('onboarding', 'state');
    if (stateDoc != null) {
      final data = Map<String, dynamic>.from(stateDoc);
      return OnboardingDataSnapshot(
        onboarding: data,
        step: (data['onboardingStep'] as num?)?.toInt() ?? 0,
        hasCompletedOnboarding: data['hasCompletedOnboarding'] as bool? ?? false,
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
