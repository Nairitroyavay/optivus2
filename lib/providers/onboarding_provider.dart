import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:optivus2/repositories/user_repository.dart';
import 'package:optivus2/core/providers.dart';

class OnboardingState {
  final List<String> selectedCategories;
  final List<String> badHabits;
  final List<String> goodHabits;
  final List<String> goals; // Long-term goals
  final String coachStyle;
  final String coachName;
  final String accountabilityType;
  final List<Map<String, dynamic>> scheduleItems;
  final int currentStep;
  final String? completedAt;
  final bool isHydrated;
  final bool isLoading;

  OnboardingState({
    this.selectedCategories = const [],
    this.badHabits = const [],
    this.goodHabits = const [],
    this.goals = const [],
    this.coachStyle = 'Supportive',
    this.coachName = '',
    this.accountabilityType = 'Strict',
    this.scheduleItems = const [],
    this.currentStep = 0,
    this.completedAt,
    this.isHydrated = false,
    this.isLoading = true,
  });

  OnboardingState copyWith({
    List<String>? selectedCategories,
    List<String>? badHabits,
    List<String>? goodHabits,
    List<String>? goals,
    String? coachStyle,
    String? coachName,
    String? accountabilityType,
    List<Map<String, dynamic>>? scheduleItems,
    int? currentStep,
    String? completedAt,
    bool clearCompletedAt = false,
    bool? isHydrated,
    bool? isLoading,
  }) {
    return OnboardingState(
      selectedCategories: selectedCategories ?? this.selectedCategories,
      badHabits: badHabits ?? this.badHabits,
      goodHabits: goodHabits ?? this.goodHabits,
      goals: goals ?? this.goals,
      coachStyle: coachStyle ?? this.coachStyle,
      coachName: coachName ?? this.coachName,
      accountabilityType: accountabilityType ?? this.accountabilityType,
      scheduleItems: scheduleItems ?? this.scheduleItems,
      currentStep: currentStep ?? this.currentStep,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      isHydrated: isHydrated ?? this.isHydrated,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  factory OnboardingState.fromMap(
    Map<String, dynamic> map, {
    int? fallbackStep,
    bool isHydrated = true,
    bool isLoading = false,
  }) {
    return OnboardingState(
      selectedCategories:
          List<String>.from(map['selectedCategories'] as List? ?? const []),
      badHabits: List<String>.from(map['badHabits'] as List? ?? const []),
      goodHabits: List<String>.from(map['goodHabits'] as List? ?? const []),
      goals: List<String>.from(map['goals'] as List? ?? const []),
      coachStyle: map['coachStyle'] as String? ?? 'Supportive',
      coachName: map['coachName'] as String? ?? '',
      accountabilityType: map['accountabilityType'] as String? ?? 'Strict',
      scheduleItems: List<Map<String, dynamic>>.from(
        (map['scheduleItems'] as List? ?? const []).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      ),
      currentStep:
          (map['onboardingStep'] as num?)?.toInt() ?? fallbackStep ?? 0,
      completedAt: map['completedAt'] as String?,
      isHydrated: isHydrated,
      isLoading: isLoading,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'selectedCategories': selectedCategories,
      'badHabits': badHabits,
      'goodHabits': goodHabits,
      'goals': goals,
      'coachStyle': coachStyle,
      'coachName': coachName,
      'accountabilityType': accountabilityType,
      'scheduleItems': scheduleItems,
      'onboardingStep': currentStep,
      'completedAt': completedAt,
    };
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  Timer? _debounceTimer;
  final UserRepository _userRepo;

  OnboardingNotifier(this._userRepo) : super(OnboardingState());

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void saveToFirestoreDebounced(int step) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      saveToFirestore(step: step); // Fire-and-forget; errors are handled inside.
    });
  }

  void updateCategories(List<String> cats) => state = state.copyWith(selectedCategories: cats);
  void updateBadHabits(List<String> habits) => state = state.copyWith(badHabits: habits);
  void updateGoodHabits(List<String> habits) => state = state.copyWith(goodHabits: habits);
  void updateGoals(List<String> goals) => state = state.copyWith(goals: goals);
  void updateCoachStyle(String style) => state = state.copyWith(coachStyle: style);
  void updateCoachName(String name) => state = state.copyWith(coachName: name);
  void updateAccountability(String type) => state = state.copyWith(accountabilityType: type);
  void updateScheduleItems(List<Map<String, dynamic>> items) => state = state.copyWith(scheduleItems: items);
  void updateCurrentStep(int step) => state = state.copyWith(currentStep: step);

  Future<int> loadFromFirestore() async {
    if (!_userRepo.isLoggedIn) {
      state = state.copyWith(isHydrated: true, isLoading: false);
      return 0;
    }

    try {
      final snapshot = await _userRepo.getOnboardingData();
      if (snapshot == null) {
        state = state.copyWith(isHydrated: true, isLoading: false);
        return state.currentStep;
      }

      state = OnboardingState.fromMap(
        snapshot.onboarding,
        fallbackStep: snapshot.step,
        isHydrated: true,
        isLoading: false,
      );
      return state.currentStep;
    } catch (e) {
      debugPrint('Error loading onboarding data: $e');
      state = state.copyWith(isHydrated: true, isLoading: false);
      return state.currentStep;
    }
  }

  Future<bool> saveToFirestore({int step = 0}) async {
    if (!_userRepo.isLoggedIn) return false;

    try {
      state = state.copyWith(
        currentStep: step,
        clearCompletedAt: true,
      );
      await _userRepo.saveOnboardingData(state.toMap(), step: step);
      return true;
    } catch (e) {
      debugPrint('Error saving onboarding data: $e');
      return false;
    }
  }

  Future<bool> completeOnboarding() async {
    if (!_userRepo.isLoggedIn) return false;

    try {
      final completedAt = DateTime.now().toIso8601String();
      state = state.copyWith(
        currentStep: 9,
        completedAt: completedAt,
      );
      await _userRepo.completeOnboarding(state.toMap());
      return true;
    } catch (e) {
      debugPrint('Error completing onboarding: $e');
      return false;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>(
  (ref) => OnboardingNotifier(ref.read(userRepositoryProvider)),
);
