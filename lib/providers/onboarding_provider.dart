import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:optivus2/core/constants/event_names.dart';
import 'package:optivus2/repositories/user_repository.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/models/user_model.dart';
import 'package:optivus2/services/event_service.dart';

List<Map<String, dynamic>> _normalizeFixedSchedule(Object? raw) {
  final items = raw is List ? raw : const [];
  return [
    for (var i = 0; i < items.length; i++)
      if (items[i] is Map)
        _normalizeFixedScheduleItem(
          Map<String, dynamic>.from(items[i] as Map),
          i,
        ),
  ];
}

Map<String, dynamic> _normalizeFixedScheduleItem(
  Map<String, dynamic> item,
  int index,
) {
  final now = DateTime.now().toIso8601String();
  final templateId = _cleanString(item['templateId']);
  final createdAt = _cleanString(item['createdAt']);
  final updatedAt = _cleanString(item['updatedAt']);
  return {
    'templateId':
        templateId.isNotEmpty ? templateId : 'fixed_schedule_${index + 1}',
    'title': _cleanString(item['title']),
    'routineType': 'fixed_schedule',
    'startTime': _normalizeTime(item['startTime'], fallback: '09:00'),
    'endTime': _normalizeTime(item['endTime'], fallback: '10:00'),
    'repeatRule': 'daily',
    'category': _cleanString(item['category']),
    'notes': _cleanString(item['notes']),
    'isActive': item['isActive'] as bool? ?? true,
    'createdAt': createdAt.isNotEmpty ? createdAt : now,
    'updatedAt': updatedAt.isNotEmpty ? updatedAt : now,
  };
}

String _cleanString(Object? value) => value?.toString().trim() ?? '';

String _normalizeTime(Object? value, {required String fallback}) {
  final text = value?.toString() ?? '';
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text.trim());
  if (match == null) return fallback;
  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null) return fallback;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return fallback;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class OnboardingState {
  final List<String> selectedCategories;
  final List<String> badHabits;
  final List<String> goodHabits;
  final List<String> goals; // Long-term goals
  final String coachStyle;
  final String coachName;
  final String accountabilityType;
  final List<Map<String, dynamic>> fixedSchedule;
  final AboutYouProfile aboutYou;
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
    this.fixedSchedule = const [],
    this.aboutYou = const AboutYouProfile(),
    this.currentStep = 0,
    this.completedAt,
    this.isHydrated = false,
    this.isLoading = true,
  });

  /// Convenience read of profile/main.sensitiveContext.eatingDisorderFlag.
  /// Also compatible with the older eatingDisorderHistory field name.
  bool get eatingDisorderFlag =>
      aboutYou.sensitiveContext.eatingDisorderFlag ?? false;

  OnboardingState copyWith({
    List<String>? selectedCategories,
    List<String>? badHabits,
    List<String>? goodHabits,
    List<String>? goals,
    String? coachStyle,
    String? coachName,
    String? accountabilityType,
    List<Map<String, dynamic>>? fixedSchedule,
    AboutYouProfile? aboutYou,
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
      fixedSchedule: fixedSchedule ?? this.fixedSchedule,
      aboutYou: aboutYou ?? this.aboutYou,
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
      fixedSchedule: _normalizeFixedSchedule(map['fixedSchedule']),
      aboutYou: map['aboutYou'] is Map
          ? AboutYouProfile.fromMap(
              Map<String, dynamic>.from(map['aboutYou'] as Map))
          : const AboutYouProfile(),
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
      'fixedSchedule': _normalizeFixedSchedule(fixedSchedule),
      'aboutYou': aboutYou.toMap(),
      'onboardingStep': currentStep,
      'completedAt': completedAt,
    };
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  Timer? _debounceTimer;
  final UserRepository _userRepo;
  final EventService _eventService;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  OnboardingNotifier(
    this._userRepo,
    this._eventService, {
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        super(OnboardingState());

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void saveToFirestoreDebounced(int step) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      saveToFirestore(
          step: step); // Fire-and-forget; errors are handled inside.
    });
  }

  void updateCategories(List<String> cats) =>
      state = state.copyWith(selectedCategories: cats);
  void updateBadHabits(List<String> habits) =>
      state = state.copyWith(badHabits: habits);
  void updateGoodHabits(List<String> habits) =>
      state = state.copyWith(goodHabits: habits);
  void updateGoals(List<String> goals) => state = state.copyWith(goals: goals);
  void updateCoachStyle(String style) =>
      state = state.copyWith(coachStyle: style);
  void updateCoachName(String name) => state = state.copyWith(coachName: name);
  void updateAccountability(String type) =>
      state = state.copyWith(accountabilityType: type);
  void updateFixedSchedule(List<Map<String, dynamic>> items) =>
      state = state.copyWith(fixedSchedule: _normalizeFixedSchedule(items));
  void updateCurrentStep(int step) => state = state.copyWith(currentStep: step);
  void updateAboutYou(AboutYouProfile aboutYou) =>
      state = state.copyWith(aboutYou: aboutYou);
  void updateBodyBasics(BodyBasics bodyBasics) => state = state.copyWith(
        aboutYou: state.aboutYou.copyWith(bodyBasics: bodyBasics),
      );
  void updateLifestyle(LifestyleProfile lifestyle) => state = state.copyWith(
        aboutYou: state.aboutYou.copyWith(lifestyle: lifestyle),
      );
  void updateSensitiveContext(SensitiveContext sensitiveContext) =>
      state = state.copyWith(
        aboutYou: state.aboutYou.copyWith(sensitiveContext: sensitiveContext),
      );

  void enableMindfulEating() {
    updateSensitiveContext(
      state.aboutYou.sensitiveContext.copyWith(eatingDisorderFlag: true),
    );
    saveToFirestoreDebounced(state.currentStep);
  }

  void forceDisableMindfulEating() {
    updateSensitiveContext(
      state.aboutYou.sensitiveContext.copyWith(eatingDisorderFlag: false),
    );
    saveToFirestoreDebounced(state.currentStep);
  }

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
      final validationError = state.aboutYou.validate();
      if (validationError != null) {
        debugPrint('Invalid onboarding About You data: $validationError');
        return false;
      }
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
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      debugPrint('Error: Cannot complete onboarding, user is null');
      return false;
    }

    try {
      final validationError = state.aboutYou.validate();
      if (validationError != null) {
        debugPrint('Invalid onboarding About You data: $validationError');
        return false;
      }
      final completedAt = DateTime.now().toIso8601String();
      state = state.copyWith(
        currentStep: 10,
        completedAt: completedAt,
      );
      final batch = _firestore.batch();
      final result =
          await _userRepo.completeOnboarding(state.toMap(), batch: batch);
      await _emitCompletionEvents(result, batch: batch);
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error completing onboarding: $e');
      return false;
    }
  }

  Future<void> _emitCompletionEvents(
    OnboardingCompletionResult result, {
    WriteBatch? batch,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    await _eventService.emit(
      eventName: EventNames.onboardingCompleted,
      eventId: 'onboarding_completed_$uid',
      source: 'onboarding',
      payload: {
        'hasCompletedOnboarding': true,
        'onboardingStep': 10,
        'completedAt': state.completedAt,
        'selectedCategories': state.selectedCategories,
        'badHabits': state.badHabits,
        'goodHabits': state.goodHabits,
        'goals': state.goals,
        'coachStyle': state.coachStyle,
        'coachName': state.coachName,
        'accountabilityType': state.accountabilityType,
        'fixedSchedule': result.onboarding['fixedSchedule'],
        'taskCount': result.tasks.length,
        'habitCount': state.goodHabits.length + state.badHabits.length,
        'goalCount': state.goals.length,
        'notificationCount': result.notifications.length,
        'snapshotId': result.snapshot['snapshotId'],
      },
      batch: batch,
    );

    await _eventService.emit(
      eventName: EventNames.identityCreated,
      eventId: 'identity_created_$uid',
      source: 'onboarding',
      payload: {
        'identityId': 'main',
        'status': 'stub',
        'selectedCategories': state.selectedCategories,
        'goals': state.goals,
        'coachStyle': state.coachStyle,
        'accountabilityType': state.accountabilityType,
        'hasCompletedOnboarding': true,
      },
      batch: batch,
    );

    for (final task in result.tasks) {
      await _eventService.emit(
        eventName: EventNames.taskScheduled,
        eventId: 'task_scheduled_${uid}_${task.id}',
        source: 'onboarding',
        payload: {
          'taskId': task.id,
          'type': task.type.toJson(),
          'plannedStart': task.plannedStart.toIso8601String(),
          'plannedEnd': task.plannedEnd.toIso8601String(),
          'plannedDurationMin': task.plannedDurationMin,
        },
        batch: batch,
      );
    }

    for (final notification in result.notifications) {
      await _eventService.emit(
        eventName: EventNames.notificationScheduled,
        eventId: 'notification_scheduled_${uid}_${notification.notifId}',
        source: 'onboarding',
        payload: {
          'notifId': notification.notifId,
          'category': notification.category,
          'scheduledFor': notification.scheduledFor.toIso8601String(),
          if (notification.taskId != null) 'taskId': notification.taskId,
          if (notification.habitId != null) 'habitId': notification.habitId,
        },
        batch: batch,
      );
    }

    for (final suggestion in result.suggestions) {
      final suggestionId = suggestion['suggestionId']?.toString();
      if (suggestionId == null || suggestionId.isEmpty) continue;

      await _eventService.emit(
        eventName: EventNames.suggestionGenerated,
        eventId: 'suggestion_generated_${uid}_$suggestionId',
        source: 'onboarding',
        payload: suggestion,
        batch: batch,
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>(
  (ref) => OnboardingNotifier(
    ref.read(userRepositoryProvider),
    ref.read(eventServiceProvider),
  ),
);

/// Streams `profile/main.sensitiveContext.eatingDisorderFlag`.
/// Also accepts the older `eatingDisorderHistory` alias.
/// When true, junk_food and nutrition habit taps route to MindfulEatingLogSheet.
final eatingDisorderFlagProvider = StreamProvider<bool>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(false);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('profile')
      .doc('main')
      .snapshots()
      .map((snap) {
    final data = snap.data();
    if (data == null) return false;
    final ctx = data['sensitiveContext'] as Map?;
    return (ctx?['eatingDisorderFlag'] as bool?) ??
        (ctx?['eatingDisorderHistory'] as bool?) ??
        false;
  });
});
