import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OnboardingState {
  final List<String> selectedCategories;
  final List<String> badHabits;
  final List<String> goodHabits;
  final List<String> goals; // Long-term goals
  final String coachStyle;
  final String coachName;
  final String accountabilityType;
  final List<Map<String, dynamic>> scheduleItems;

  OnboardingState({
    this.selectedCategories = const [],
    this.badHabits = const [],
    this.goodHabits = const [],
    this.goals = const [],
    this.coachStyle = 'Supportive',
    this.coachName = '',
    this.accountabilityType = 'Strict',
    this.scheduleItems = const [],
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
    };
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  Timer? _debounceTimer;

  OnboardingNotifier() : super(OnboardingState());

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void saveToFirestoreDebounced() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      // Fire-and-forget; errors are handled inside saveToFirestore.
      saveToFirestore();
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

  Future<bool> saveToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'onboarding': state.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      // Log and return failure; callers can decide how to notify.
      debugPrint('Error saving onboarding data: $e');
      return false;
    }
  }
}

final onboardingProvider = StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier();
});
