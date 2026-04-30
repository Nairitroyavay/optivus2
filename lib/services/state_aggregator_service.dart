// lib/services/state_aggregator_service.dart
//
// Aggregates 4 Firestore collections into a single ContextSnapshot.
// Collections (all under /users/{uid}/):
//   events_recent   — today's events filtered by ts
//   streaks         — active streaks (state == active)
//   dailySummaries  — today's summary doc (written at day-close)
//   profile/main    — lastCoachMessageAt, budget, lastActiveDate

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/event_names.dart';
import '../models/context_snapshot.dart';
import '../models/goal_model.dart';
import '../models/streak_model.dart';

class StateAggregatorService {
  final FirebaseFirestore _firestore;

  StateAggregatorService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<ContextSnapshot> buildSnapshot(String uid) async {
    final now = DateTime.now();
    final todayStr = _dateString(now);
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    debugPrint('[StateAggregator] Building snapshot uid=$uid date=$todayStr');

    final userRef = _firestore.collection('users').doc(uid);

    // ── Parallel reads ───────────────────────────────────────────────────────
    final results = await Future.wait([
      // [0] events_recent — today's window
      userRef
          .collection('events_recent')
          .where('ts', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('ts', isLessThan: Timestamp.fromDate(tomorrowStart))
          .get(),
      // [1] streaks — active only
      userRef
          .collection('streaks')
          .where('state', isEqualTo: StreakState.active.name)
          .get(),
      // [2] dailySummaries — today's doc
      userRef
          .collection('dailySummaries')
          .where('date', isEqualTo: todayStr)
          .limit(1)
          .get(),
      // [3] profile/main
      userRef.collection('profile').doc('main').get(),
    ]);

    final eventsSnap = results[0] as QuerySnapshot<Map<String, dynamic>>;
    final streaksSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final summariesSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;
    final profileSnap = results[3] as DocumentSnapshot<Map<String, dynamic>>;

    debugPrint('[StateAggregator] events_recent: ${eventsSnap.size} doc(s)');
    debugPrint('[StateAggregator] streaks(active): ${streaksSnap.size} doc(s)');
    debugPrint(
        '[StateAggregator] dailySummaries: ${summariesSnap.size} doc(s) for $todayStr');
    debugPrint('[StateAggregator] profile/main exists=${profileSnap.exists}');

    // ── events_recent ────────────────────────────────────────────────────────
    int tasksCompletedToday = 0;
    int tasksAbandonedToday = 0;
    int goodHabitsLoggedToday = 0;
    int badHabitSlipsToday = 0;

    for (final doc in eventsSnap.docs) {
      switch (doc.data()['eventName'] as String? ?? '') {
        case EventNames.taskCompleted:
          tasksCompletedToday++;
          break;
        case EventNames.taskAbandoned:
          tasksAbandonedToday++;
          break;
        case EventNames.goodHabitLogged:
          goodHabitsLoggedToday++;
          break;
        case EventNames.badHabitSlipLogged:
          badHabitSlipsToday++;
          break;
      }
    }

    // ── streaks ──────────────────────────────────────────────────────────────
    final int activeStreakCount = streaksSnap.size;
    int longestActiveStreak = 0;
    for (final doc in streaksSnap.docs) {
      final streak = Streak.fromFirestore(doc);
      if (streak.currentCount > longestActiveStreak) {
        longestActiveStreak = streak.currentCount;
      }
    }

    // ── dailySummaries ───────────────────────────────────────────────────────
    int missionScore = 0;
    String? summaryUserState;

    if (summariesSnap.docs.isNotEmpty) {
      final d = summariesSnap.docs.first.data();
      missionScore = d['missionScore'] as int? ?? 0;
      summaryUserState = d['userState'] as String?;
      debugPrint(
          '[StateAggregator] dailySummaries → missionScore=$missionScore userState=$summaryUserState');
    } else {
      debugPrint('[StateAggregator] dailySummaries → no doc yet (intra-day)');
    }

    // ── profile/main ─────────────────────────────────────────────────────────
    DateTime? lastCoachMessageAt;
    int notificationBudgetRemaining = 3;
    int daysSinceLastActive = 0;

    if (profileSnap.exists) {
      final d = profileSnap.data()!;

      final rawCoachTs = d['lastCoachMessageAt'];
      if (rawCoachTs is Timestamp) {
        lastCoachMessageAt = rawCoachTs.toDate();
      } else if (rawCoachTs is String) {
        lastCoachMessageAt = DateTime.tryParse(rawCoachTs);
      }

      notificationBudgetRemaining =
          d['notificationBudgetRemaining'] as int? ?? 3;

      final rawActive = d['lastActiveDate'];
      DateTime? lastActive;
      if (rawActive is Timestamp) {
        lastActive = rawActive.toDate();
      } else if (rawActive is String) {
        lastActive = DateTime.tryParse(rawActive);
      }
      if (lastActive != null) {
        final lastActiveDay =
            DateTime(lastActive.year, lastActive.month, lastActive.day);
        daysSinceLastActive =
            todayStart.difference(lastActiveDay).inDays.clamp(0, 9999);
      }

      debugPrint('[StateAggregator] profile/main → '
          'budget=$notificationBudgetRemaining '
          'daysSinceLastActive=$daysSinceLastActive');
    }

    // ── userState ────────────────────────────────────────────────────────────
    // Prefer the persisted state from dailySummaries (post day-close); derive
    // live from events when no summary exists yet (intra-day).
    final userState = summaryUserState ??
        _deriveUserState(
          tasksCompletedToday: tasksCompletedToday,
          tasksAbandonedToday: tasksAbandonedToday,
          goodHabitsLoggedToday: goodHabitsLoggedToday,
          badHabitSlipsToday: badHabitSlipsToday,
          longestActiveStreak: longestActiveStreak,
        );

    final snapshot = ContextSnapshot(
      tasksCompletedToday: tasksCompletedToday,
      tasksAbandonedToday: tasksAbandonedToday,
      goodHabitsLoggedToday: goodHabitsLoggedToday,
      badHabitSlipsToday: badHabitSlipsToday,
      longestActiveStreak: longestActiveStreak,
      activeStreakCount: activeStreakCount,
      missionScore: missionScore,
      userState: userState,
      lastCoachMessageAt: lastCoachMessageAt,
      notificationBudgetRemaining: notificationBudgetRemaining,
      daysSinceLastActive: daysSinceLastActive,
    );

    debugPrint('[StateAggregator] Snapshot ready: ${snapshot.debugSummary}');
    return snapshot;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _deriveUserState({
    required int tasksCompletedToday,
    required int tasksAbandonedToday,
    required int goodHabitsLoggedToday,
    required int badHabitSlipsToday,
    required int longestActiveStreak,
  }) {
    final positive = tasksCompletedToday +
        goodHabitsLoggedToday +
        (longestActiveStreak > 0 ? 1 : 0);
    final negative = badHabitSlipsToday + tasksAbandonedToday;

    if (badHabitSlipsToday >= 3 && positive == 0) return 'relapsing';
    if (negative > 0 && positive > 0) return 'recovering';
    if (negative > 0) return 'slipping';
    return 'on_track';
  }

  static String _dateString(DateTime dt) => '${dt.year}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  Future<int?> updateIdentityProfile(String uid) async {
    debugPrint('[StateAggregator] Computing identity profile for $uid');
    final snapshot = await buildSnapshot(uid);

    final userRef = _firestore.collection('users').doc(uid);
    final results = await Future.wait([
      userRef.get(),
      userRef.collection('goals').get(),
    ]);

    final userSnap = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final goalsSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final onboarding = Map<String, dynamic>.from(
      userSnap.data()?['onboarding'] as Map? ?? const {},
    );

    final onboardingGoals = (onboarding['goals'] as List? ?? const [])
        .map((goal) => goal.toString().trim())
        .where((goal) => goal.isNotEmpty)
        .toList();

    final existingGoals =
        goalsSnap.docs.map((doc) => GoalModel.fromFirestore(doc)).toList();
    final goalModels = _mergeGoalsWithOnboarding(
      existingGoals: existingGoals,
      onboardingGoals: onboardingGoals,
      snapshot: snapshot,
    );

    final batch = _firestore.batch();
    final goalRef = userRef.collection('goals');
    for (final goal in goalModels) {
      batch.set(
        goalRef.doc(goal.id),
        {
          ...goal.toFirestore(),
          'lastComputedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'schemaVersion': 2,
        },
        SetOptions(merge: true),
      );
    }

    final identities = _deriveIdentities(
      onboardingGoals: onboardingGoals,
      goalModels: goalModels,
    );
    final score = goalModels.isEmpty
        ? _computeFallbackIdentityScore(snapshot)
        : (goalModels
                    .map((goal) => goal.progressPct)
                    .reduce((total, value) => total + value) /
                goalModels.length)
            .round()
            .clamp(0, 100);

    final profileRef = userRef.collection('identity_profile').doc('main');
    final profileSnap = await profileRef.get();

    int oldScore = 0;
    List<String> oldIdentities = const [];
    if (profileSnap.exists) {
      oldScore = profileSnap.data()?['progressPct'] as int? ?? 0;
      oldIdentities = List<String>.from(
        profileSnap.data()?['identities'] as List? ?? const [],
      );
    }

    final identitiesChanged = !_listEquals(oldIdentities, identities);
    final scoreChanged = score != oldScore;

    batch.set(
      profileRef,
      {
        'identities': identities,
        'progressPct': score,
        'lastComputedAt': FieldValue.serverTimestamp(),
        'schemaVersion': 2,
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    debugPrint(
      '[StateAggregator] identity_profile/main updated — '
      'score=$oldScore->$score identities=${identities.length}',
    );

    if (scoreChanged) {
      debugPrint(
          '[StateAggregator] Updated identity score: $oldScore -> $score');
      return score;
    }

    if (identitiesChanged || !profileSnap.exists) {
      debugPrint(
          '[StateAggregator] Identity list updated with unchanged score.');
    }

    return null;
  }

  List<GoalModel> _mergeGoalsWithOnboarding({
    required List<GoalModel> existingGoals,
    required List<String> onboardingGoals,
    required ContextSnapshot snapshot,
  }) {
    final goalsByKey = <String, GoalModel>{};

    for (final goal in existingGoals) {
      goalsByKey[_normalizeGoalKey(goal.title)] = goal;
    }

    for (final title in onboardingGoals) {
      final key = _normalizeGoalKey(title);
      goalsByKey.putIfAbsent(
        key,
        () => GoalModel(
          id: _goalIdForTitle(title),
          title: title,
          description: _defaultGoalDescription(title),
          progressPct: 0,
          identityTags: _defaultIdentityTags(title),
          colorHex: _defaultGoalColor(title),
          iconName: _defaultGoalIcon(title),
          source: 'onboarding_v2',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          schemaVersion: 2,
        ),
      );
    }

    return goalsByKey.values.map((goal) {
      final progressPct = _computeGoalProgress(goal, snapshot);
      return goal.copyWith(
        description: goal.description ?? _defaultGoalDescription(goal.title),
        progressPct: progressPct,
        isCompleted: goal.isCompleted || progressPct >= 100,
        identityTags: goal.identityTags.isNotEmpty
            ? goal.identityTags
            : _defaultIdentityTags(goal.title),
        colorHex: goal.colorHex ?? _defaultGoalColor(goal.title),
        iconName: goal.iconName ?? _defaultGoalIcon(goal.title),
        source: goal.source.isEmpty ? 'onboarding_v2' : goal.source,
        lastComputedAt: DateTime.now(),
        schemaVersion: goal.schemaVersion < 2 ? 2 : goal.schemaVersion,
      );
    }).toList()
      ..sort((a, b) => b.progressPct.compareTo(a.progressPct));
  }

  List<String> _deriveIdentities({
    required List<String> onboardingGoals,
    required List<GoalModel> goalModels,
  }) {
    final identities = <String>[];

    for (final goal in onboardingGoals) {
      if (!identities.contains(goal)) identities.add(goal);
    }
    for (final goal in goalModels) {
      if (!identities.contains(goal.title)) identities.add(goal.title);
    }

    return identities;
  }

  int _computeGoalProgress(GoalModel goal, ContextSnapshot snapshot) {
    final text = [
      goal.title,
      goal.description ?? '',
      ...goal.identityTags,
    ].join(' ').toLowerCase();

    final taskSignal = _computeTaskSignal(snapshot);
    final habitSignal = _computeHabitSignal(snapshot);
    final consistencySignal = snapshot.missionScore.clamp(0, 100);
    final recoverySignal =
        (100 - (snapshot.badHabitSlipsToday * 25)).clamp(0, 100);

    if (_matchesAny(text, const [
      'study',
      'learn',
      'read',
      'class',
      'exam',
      'career',
      'work',
      'product',
      'project',
      'discipline',
    ])) {
      return ((taskSignal * 0.7) + (consistencySignal * 0.3))
          .round()
          .clamp(0, 100);
    }

    if (_matchesAny(text, const [
      'gym',
      'fitness',
      'fit',
      'health',
      'exercise',
      'run',
      'workout',
      'sleep',
    ])) {
      return ((habitSignal * 0.7) + (consistencySignal * 0.3))
          .round()
          .clamp(0, 100);
    }

    if (_matchesAny(text, const [
      'quit',
      'reduce',
      'stop',
      'smoking',
      'cigarette',
      'alcohol',
      'drink',
      'social media',
      'dopamine',
      'porn',
      'weed',
    ])) {
      return ((recoverySignal * 0.6) +
              (habitSignal * 0.2) +
              (consistencySignal * 0.2))
          .round()
          .clamp(0, 100);
    }

    return ((taskSignal + habitSignal + consistencySignal) / 3)
        .round()
        .clamp(0, 100);
  }

  int _computeFallbackIdentityScore(ContextSnapshot snapshot) {
    final taskSignal = _computeTaskSignal(snapshot);
    final habitSignal = _computeHabitSignal(snapshot);
    return ((taskSignal + habitSignal + snapshot.missionScore.clamp(0, 100)) /
            3)
        .round()
        .clamp(0, 100);
  }

  int _computeTaskSignal(ContextSnapshot snapshot) {
    final totalTasks =
        snapshot.tasksCompletedToday + snapshot.tasksAbandonedToday;
    if (totalTasks <= 0) {
      return snapshot.missionScore.clamp(0, 100);
    }

    return ((snapshot.tasksCompletedToday / totalTasks) * 100)
        .round()
        .clamp(0, 100);
  }

  int _computeHabitSignal(ContextSnapshot snapshot) {
    final rawScore = (snapshot.goodHabitsLoggedToday * 20) +
        (snapshot.activeStreakCount * 12) +
        (snapshot.longestActiveStreak * 3) -
        (snapshot.badHabitSlipsToday * 20);
    return rawScore.clamp(0, 100);
  }

  bool _matchesAny(String text, List<String> terms) {
    for (final term in terms) {
      if (text.contains(term)) return true;
    }
    return false;
  }

  String _goalIdForTitle(String title) {
    final normalized = _normalizeGoalKey(title);
    return normalized.isEmpty ? 'goal_custom' : 'goal_$normalized';
  }

  String _normalizeGoalKey(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  String _defaultGoalDescription(String title) {
    return 'Progress auto-updated from your daily tasks, habits, and streaks.';
  }

  List<String> _defaultIdentityTags(String title) {
    return title
        .split(RegExp(r'[^A-Za-z0-9]+'))
        .map((part) => part.trim().toLowerCase())
        .where((part) => part.length > 2)
        .take(3)
        .toList();
  }

  String _defaultGoalColor(String title) {
    final text = title.toLowerCase();
    if (_matchesAny(text, const ['gym', 'fitness', 'health', 'run'])) {
      return '#22C55E';
    }
    if (_matchesAny(text, const ['study', 'learn', 'read', 'class', 'exam'])) {
      return '#3B82F6';
    }
    if (_matchesAny(text, const ['quit', 'reduce', 'stop', 'smoking'])) {
      return '#F97316';
    }
    return '#14B8A6';
  }

  String _defaultGoalIcon(String title) {
    final text = title.toLowerCase();
    if (_matchesAny(text, const ['study', 'learn', 'read', 'class', 'exam'])) {
      return 'menu_book_rounded';
    }
    if (_matchesAny(text, const ['gym', 'fitness', 'health', 'run'])) {
      return 'directions_run_rounded';
    }
    if (_matchesAny(text, const ['quit', 'reduce', 'stop', 'smoking'])) {
      return 'local_fire_department_rounded';
    }
    return 'flag_rounded';
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
