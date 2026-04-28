import '../services/firestore_service.dart';
import '../models/user_model.dart';

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

  /// Save onboarding data merged into the user profile document.
  Future<void> saveOnboardingData(Map<String, dynamic> onboardingMap, {int step = 0}) async {
    await _service.saveUserProfile({
      'onboarding': onboardingMap,
      'onboardingStep': step,
      'updatedAt': DateTime.now().toIso8601String(),
    }, merge: true);
  }

  /// Complete onboarding by setting hasCompletedOnboarding to true.
  Future<void> completeOnboarding(Map<String, dynamic> onboardingMap) async {
    await _service.saveUserProfile({
      'onboarding': onboardingMap,
      'hasCompletedOnboarding': true,
      'onboardingStep': 9, // The final step
      'updatedAt': DateTime.now().toIso8601String(),
    }, merge: true);
  }

  /// Load onboarding data from the user profile.
  Future<Map<String, dynamic>?> getOnboardingData() async {
    final profile = await _service.getUserProfile();
    if (profile != null && profile['onboarding'] != null) {
      return Map<String, dynamic>.from(profile['onboarding']);
    }
    return null;
  }
}
