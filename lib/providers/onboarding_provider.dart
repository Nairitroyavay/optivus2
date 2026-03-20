import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingState {
  final List<String> selectedCategories;
  final String coachStyle;
  final List<String> goals;
  final String wakeTime;
  final String sleepHours;
  final List<String> mealTimes;

  OnboardingState({
    this.selectedCategories = const [],
    this.coachStyle = 'Supportive',
    this.goals = const [],
    this.wakeTime = '',
    this.sleepHours = '',
    this.mealTimes = const [],
  });

  OnboardingState copyWith({
    List<String>? selectedCategories,
    String? coachStyle,
    List<String>? goals,
    String? wakeTime,
    String? sleepHours,
    List<String>? mealTimes,
  }) {
    return OnboardingState(
      selectedCategories: selectedCategories ?? this.selectedCategories,
      coachStyle: coachStyle ?? this.coachStyle,
      goals: goals ?? this.goals,
      wakeTime: wakeTime ?? this.wakeTime,
      sleepHours: sleepHours ?? this.sleepHours,
      mealTimes: mealTimes ?? this.mealTimes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'selectedCategories': selectedCategories,
      'coachStyle': coachStyle,
      'goals': goals,
      'wakeTime': wakeTime,
      'sleepHours': sleepHours,
      'mealTimes': mealTimes,
    };
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(OnboardingState());

  void updateCategories(List<String> cats) => state = state.copyWith(selectedCategories: cats);
  void updateCoachStyle(String style) => state = state.copyWith(coachStyle: style);
  void updateGoals(List<String> goals) => state = state.copyWith(goals: goals);
  void updateWakeTime(String wakeTime) => state = state.copyWith(wakeTime: wakeTime);
  void updateSleepHours(String sleepHours) => state = state.copyWith(sleepHours: sleepHours);
  void updateMealTimes(List<String> mealTimes) => state = state.copyWith(mealTimes: mealTimes);
}

final onboardingProvider = StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier();
});
