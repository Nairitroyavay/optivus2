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
    int dailyNotificationBudget = 3;
    int notificationsSentToday = 0;
    bool quietDayMode = false;
    int daysSinceLastActive = 0;

    if (profileSnap.exists) {
      final d = profileSnap.data()!;

      final rawCoachTs = d['lastCoachMessageAt'];
      if (rawCoachTs is Timestamp) {
        lastCoachMessageAt = rawCoachTs.toDate();
      } else if (rawCoachTs is String) {
        lastCoachMessageAt = DateTime.tryParse(rawCoachTs);
      }

      dailyNotificationBudget =
          _asNonNegativeInt(d['dailyNotificationBudget'], fallback: 3);
      final notificationBudgetDate = d['notificationBudgetDate'] as String?;
      notificationsSentToday = notificationBudgetDate == todayStr
          ? _asNonNegativeInt(d['notificationsSentToday'])
          : 0;
      quietDayMode = d['quietDayMode'] as bool? ?? false;

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
          'budget=$notificationsSentToday/$dailyNotificationBudget '
          'quiet=$quietDayMode '
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
      dailyNotificationBudget: dailyNotificationBudget,
      notificationsSentToday: notificationsSentToday,
      quietDayMode: quietDayMode,
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

  static int _asNonNegativeInt(Object? value, {int fallback = 0}) {
    if (value is int) return value < 0 ? 0 : value;
    if (value is num) {
      final rounded = value.round();
      return rounded < 0 ? 0 : rounded;
    }
    return fallback;
  }

  Future<int?> updateIdentityProfile(String uid) async {
    debugPrint('[StateAggregator] Computing identity profile for $uid');
    final snapshot = await buildSnapshot(uid);

    final userRef = _firestore.collection('users').doc(uid);
    final results = await Future.wait([
      userRef.get(),
      userRef.collection('goals').get(),
      userRef.collection('habits').get(),
      userRef.collection('tasks').get(),
    ]);

    final userSnap = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final goalsSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final habitsSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;
    final tasksSnap = results[3] as QuerySnapshot<Map<String, dynamic>>;
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
      habits: habitsSnap.docs,
      tasks: tasksSnap.docs,
    );

    final batch = _firestore.batch();
    final goalRef = userRef.collection('goals');
    for (final goal in goalModels) {
      batch.set(goalRef.doc(goal.goalId), goal.toFirestore());
    }

    final identities = _deriveIdentities(
      onboardingGoals: onboardingGoals,
      goalModels: goalModels,
    );
    final score = _computeIdentityScore(goalModels, snapshot);

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

    final activeGoalIds = goalModels
        .where((goal) =>
            goal.status == GoalStatus.active ||
            goal.status == GoalStatus.completed)
        .map((goal) => goal.goalId)
        .toList();
    final pausedGoalIds = goalModels
        .where((goal) => goal.status == GoalStatus.paused)
        .map((goal) => goal.goalId)
        .toList();
    final archivedGoalIds = goalModels
        .where((goal) => goal.status == GoalStatus.archived)
        .map((goal) => goal.goalId)
        .toList();
    final goalProgress = {
      for (final goal in goalModels) goal.goalId: goal.progress,
    };
    final connectedHabitIds = _unionStrings(
      goalModels.expand((goal) => goal.connectedHabitIds),
    );
    final connectedRoutineTypes = _unionStrings(
      goalModels.expand((goal) => goal.connectedRoutineTypes),
    );

    batch.set(
      profileRef,
      {
        'identities': identities,
        'progressPct': score,
        'lastComputedAt': FieldValue.serverTimestamp(),
        'activeGoalIds': activeGoalIds,
        'pausedGoalIds': pausedGoalIds,
        'archivedGoalIds': archivedGoalIds,
        'goalProgress': goalProgress,
        'connectedHabitIds': connectedHabitIds,
        'connectedRoutineTypes': connectedRoutineTypes,
        'updatedAt': FieldValue.serverTimestamp(),
        'schemaVersion': 3,
      },
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
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> habits,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> tasks,
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
          goalId: _goalIdForTitle(title),
          title: title,
          identityTag: _defaultIdentityTag(title),
          why: _defaultGoalWhy(title),
          status: GoalStatus.active,
          weight: 1,
          progress: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }

    return goalsByKey.values.map((goal) {
      final connectedHabitIds = _unionStrings([
        ...goal.connectedHabitIds,
        ..._matchingHabitIds(goal, habits),
      ]);
      final connectedRoutineTypes = _unionStrings([
        ...goal.connectedRoutineTypes,
        ..._matchingRoutineTypes(goal, tasks),
      ]);
      final normalizedGoal = goal.copyWith(
        identityTag: goal.identityTag.isNotEmpty
            ? goal.identityTag
            : _defaultIdentityTag(goal.title),
        why: goal.why.isNotEmpty ? goal.why : _defaultGoalWhy(goal.title),
        connectedHabitIds: connectedHabitIds,
        connectedRoutineTypes: connectedRoutineTypes,
      );
      final progress = _computeGoalProgress(
        normalizedGoal,
        snapshot,
        habits: habits,
        tasks: tasks,
      );
      return goal.copyWith(
        identityTag: normalizedGoal.identityTag,
        why: normalizedGoal.why,
        progress: progress,
        status: goal.status == GoalStatus.active && progress >= 100
            ? GoalStatus.completed
            : goal.status,
        connectedHabitIds: connectedHabitIds,
        connectedRoutineTypes: connectedRoutineTypes,
        updatedAt: DateTime.now(),
      );
    }).toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));
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
      if (goal.status == GoalStatus.archived) continue;
      final identity =
          goal.identityTag.isNotEmpty ? goal.identityTag : goal.title;
      if (!identities.contains(identity)) identities.add(identity);
    }

    return identities;
  }

  int _computeIdentityScore(
    List<GoalModel> goalModels,
    ContextSnapshot snapshot,
  ) {
    final scoreableGoals =
        goalModels.where((goal) => goal.status != GoalStatus.archived).toList();
    if (scoreableGoals.isEmpty) return _computeFallbackIdentityScore(snapshot);

    var weightedTotal = 0;
    var totalWeight = 0;
    for (final goal in scoreableGoals) {
      weightedTotal += goal.progress * goal.weight;
      totalWeight += goal.weight;
    }

    if (totalWeight <= 0) return _computeFallbackIdentityScore(snapshot);
    return (weightedTotal / totalWeight).round().clamp(0, 100);
  }

  int _computeGoalProgress(
    GoalModel goal,
    ContextSnapshot snapshot, {
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> habits,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> tasks,
  }) {
    if (goal.status == GoalStatus.archived ||
        goal.status == GoalStatus.paused) {
      return goal.progress;
    }

    final directTaskSignal = _computeGoalTaskSignal(goal, tasks);
    final directHabitSignal = _computeGoalHabitSignal(goal, habits, snapshot);
    final directSignals = <int>[
      if (directTaskSignal != null) directTaskSignal,
      if (directHabitSignal != null) directHabitSignal,
      snapshot.missionScore.clamp(0, 100),
    ];

    if (directTaskSignal != null || directHabitSignal != null) {
      return (directSignals.reduce((total, value) => total + value) /
              directSignals.length)
          .round()
          .clamp(0, 100);
    }

    final text = [
      goal.title,
      goal.why,
      goal.identityTag,
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

  int? _computeGoalTaskSignal(
    GoalModel goal,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> tasks,
  ) {
    final matchingTasks =
        tasks.where((doc) => _goalMatchesTask(goal, doc.data())).toList();
    final terminalTasks = matchingTasks.where((doc) {
      final data = doc.data();
      final state = data['state'] as String? ?? data['status'] as String? ?? '';
      return state == 'completed' || state == 'abandoned' || state == 'skipped';
    }).toList();

    if (terminalTasks.isEmpty) return null;

    final completed = terminalTasks.where((doc) {
      final data = doc.data();
      final state = data['state'] as String? ?? data['status'] as String? ?? '';
      return state == 'completed';
    }).length;

    return ((completed / terminalTasks.length) * 100).round().clamp(0, 100);
  }

  int? _computeGoalHabitSignal(
    GoalModel goal,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> habits,
    ContextSnapshot snapshot,
  ) {
    final hasMatchingHabit =
        habits.any((doc) => _goalMatchesHabit(goal, doc.id, doc.data()));
    return hasMatchingHabit ? _computeHabitSignal(snapshot) : null;
  }

  List<String> _matchingHabitIds(
    GoalModel goal,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> habits,
  ) {
    return habits
        .where((doc) => _goalMatchesHabit(goal, doc.id, doc.data()))
        .map((doc) => doc.id)
        .toList();
  }

  List<String> _matchingRoutineTypes(
    GoalModel goal,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> tasks,
  ) {
    final routineTypes = <String>[];
    for (final doc in tasks) {
      final data = doc.data();
      if (!_goalMatchesTask(goal, data)) continue;
      final routineType = data['sourceRoutineType'] as String? ??
          data['parentRoutine'] as String? ??
          data['routineType'] as String?;
      if (routineType != null && routineType.trim().isNotEmpty) {
        routineTypes.add(routineType.trim());
      }
    }
    return _unionStrings(routineTypes);
  }

  bool _goalMatchesTask(GoalModel goal, Map<String, dynamic> data) {
    final identityTags = _stringList(data['identityTags']);
    final sourceRoutineType = data['sourceRoutineType'] as String? ??
        data['parentRoutine'] as String? ??
        data['routineType'] as String?;
    final title = data['title'] as String? ?? '';

    if (goal.connectedRoutineTypes
        .map(_normalizeTag)
        .contains(_normalizeTag(sourceRoutineType ?? ''))) {
      return true;
    }

    return _matchesGoalText(
      goal,
      [
        title,
        sourceRoutineType ?? '',
        ...identityTags,
      ],
    );
  }

  bool _goalMatchesHabit(
    GoalModel goal,
    String habitId,
    Map<String, dynamic> data,
  ) {
    if (goal.connectedHabitIds.contains(habitId)) return true;

    final identityTags = _stringList(data['identityTags']);
    return _matchesGoalText(
      goal,
      [
        data['name'] as String? ?? '',
        data['trackerType'] as String? ?? '',
        habitId,
        ...identityTags,
      ],
    );
  }

  bool _matchesGoalText(GoalModel goal, List<String> candidates) {
    final goalKeys = {
      _normalizeTag(goal.identityTag),
      _normalizeTag(goal.title),
    }..remove('');

    for (final candidate in candidates) {
      final normalized = _normalizeTag(candidate);
      if (normalized.isEmpty) continue;
      if (goalKeys.contains(normalized)) return true;
      for (final key in goalKeys) {
        if (normalized.contains(key) || key.contains(normalized)) return true;
      }
    }

    return false;
  }

  List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<String> _unionStrings(Iterable<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      final key = _normalizeTag(trimmed);
      if (seen.add(key)) result.add(trimmed);
    }
    return result;
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

  String _normalizeTag(String input) => _normalizeGoalKey(input);

  String _defaultGoalWhy(String title) {
    return 'Progress auto-updated from your daily tasks, habits, and streaks.';
  }

  String _defaultIdentityTag(String title) {
    final parts = title
        .split(RegExp(r'[^A-Za-z0-9]+'))
        .map((part) => part.trim().toLowerCase())
        .where((part) => part.length > 2)
        .toList();
    return parts.isEmpty ? _normalizeGoalKey(title) : parts.take(3).join('_');
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
