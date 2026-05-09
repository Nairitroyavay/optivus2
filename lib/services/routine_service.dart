// lib/services/routine_service.dart
//
// Owns the day-close lifecycle.  Called on app launch to check whether
// yesterday's day has been closed and, if not, runs the full sequence:
//
//   1. Roll up habit logs from /users/{uid}/habit_logs (via StreakService).
//   2. Compute streak changes per habit (inside StreakService.runDayCloseRollup).
//   3. Write/update streak docs at /users/{uid}/streaks/{habitId} (inside StreakService).
//   4. Write dailySummaries/{date} with real metrics returned from the rollup.
//   5. Emit streak events (streakExtended / streakBroken / streakMilestoneReached)
//      per habit — emitted atomically inside StreakService.
//   6. Emit day_closed.
//   7. Emit routine_day_summarized.
//
// The EventOrchestrator only listens for day_closed / routine_day_summarized
// to trigger downstream side-effects (notifications, etc.).  It must NOT
// re-trigger the rollup — that would cause duplicate streak events.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/event_names.dart';
import '../models/day_summary_model.dart';
import '../models/routine_template_model.dart';
import '../models/suggestion_model.dart';
import '../models/task_model.dart';
import '../models/user_model.dart';
import 'event_service.dart';
import 'state_aggregator_service.dart';
import 'streak_service.dart';

class RoutineService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final EventService _eventService;
  final StreakService _streakService;
  final StateAggregatorService _stateAggregatorService;

  RoutineService({
    required EventService eventService,
    required StreakService streakService,
    required StateAggregatorService stateAggregatorService,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _eventService = eventService,
        _streakService = streakService,
        _stateAggregatorService = stateAggregatorService,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Checks whether the previous calendar day has been closed; if not, runs
  /// the full day-close sequence described in the file header.
  ///
  /// Idempotent — guarded by `lastDayClosed` on the user document.
  Future<void> runDayCloseIfNeeded() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final uid = user.uid;
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) return;

      final userModel = UserModel.fromFirestore(userDoc);
      final lastDayClosed = userModel.lastDayClosed;

      final now = DateTime.now();
      final todayStr = _formatDate(now);
      final yesterdayStr = _formatDate(now.subtract(const Duration(days: 1)));

      await _handleComebackIfNeeded(uid, userDoc, now);
      await runDayStartIfNeeded(now);

      if (lastDayClosed != null && lastDayClosed.compareTo(yesterdayStr) >= 0) {
        // Already closed — nothing to do.
        return;
      }

      var dateToClose = lastDayClosed == null
          ? yesterdayStr
          : _formatDate(_parseDate(lastDayClosed).add(const Duration(days: 1)));

      while (dateToClose.compareTo(todayStr) < 0) {
        await _closeDate(uid, dateToClose);
        dateToClose = _formatDate(
          _parseDate(dateToClose).add(const Duration(days: 1)),
        );
      }
    } catch (e, st) {
      debugPrint('[RoutineService] Error in runDayCloseIfNeeded: $e\n$st');
    }
  }

  /// Starts today's lifecycle once per local date. Safe to call on app launch.
  Future<void> runDayStartIfNeeded([DateTime? now]) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;
    final today = now ?? DateTime.now();
    final dateStr = _formatDate(today);
    final eventId = _eventId('day_started', uid, dateStr);

    final eventRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('events')
        .doc(eventId);
    if ((await eventRef.get()).exists) return;

    await _materializeTemplatesForDate(uid, today);
    await _writeContextSnapshot(uid, dateStr, 'day_start');
    await _eventService.emit(
      eventName: EventNames.dayStarted,
      source: 'routine_service',
      eventId: eventId,
      payload: {
        'date': dateStr,
        'source': 'client',
      },
    );
  }

  /// Completes the pending comeback prompt and restores ghost-paused streaks.
  Future<void> completePendingComeback() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final userRef = _firestore.collection('users').doc(uid);
    final userSnap = await userRef.get();
    final pending = Map<String, dynamic>.from(
      userSnap.data()?['pendingComeback'] as Map? ?? const {},
    );
    final rawGapDays = pending['gapDays'];
    final gapDays = rawGapDays is num ? rawGapDays.toInt() : null;

    await _streakService.resumeAllPausedStreaks(
      reason: 'ghost',
      gapDays: gapDays,
    );
    await userRef.set({
      'pendingComeback': {
        ...pending,
        'status': 'dismissed',
        'dismissedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _handleComebackIfNeeded(
    String uid,
    DocumentSnapshot<Map<String, dynamic>> userDoc,
    DateTime now,
  ) async {
    final lastSeen = await _resolveLastSeen(userDoc);
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = _formatDate(today);

    if (lastSeen == null) {
      await _writeLastSeen(uid, now, todayStr);
      return;
    }

    final lastSeenDay =
        DateTime(lastSeen.value.year, lastSeen.value.month, lastSeen.value.day);
    final gapDays = today.difference(lastSeenDay).inDays.clamp(0, 9999);

    if (gapDays >= 3) {
      final lastSeenDate = _formatDate(lastSeenDay);
      final threshold = _comebackThreshold(gapDays);
      final eventId =
          _eventId('comeback_initiated', uid, todayStr, gapDays.toString());
      final suggestionIds = _comebackSuggestionIds(todayStr);

      await _streakService.pauseAllActiveStreaks(
        reason: 'ghost',
        gapDays: gapDays,
      );
      final protectedCount = await _countGhostPausedStreaks(uid);
      final suggestions = _comebackSuggestions(
        suggestionIds: suggestionIds,
        gapDays: gapDays,
        now: now,
      );

      final batch = _firestore.batch();
      final userRef = _firestore.collection('users').doc(uid);
      final profileRef = userRef.collection('profile').doc('main');

      for (final suggestion in suggestions) {
        batch.set(
          userRef.collection('suggestions').doc(suggestion['suggestionId']),
          suggestion,
          SetOptions(merge: true),
        );
      }

      batch.set(
          userRef,
          {
            'pendingComeback': {
              'status': 'pending',
              'gapDays': gapDays,
              'lastSeenDate': lastSeenDate,
              'lastSeenSource': lastSeen.source,
              'returnDate': todayStr,
              'threshold': threshold,
              'protectedStreakCount': protectedCount,
              'suggestionIds': suggestionIds,
              'suggestions': suggestions
                  .map((suggestion) => {
                        'suggestionId': suggestion['suggestionId'],
                        'title': suggestion['title'],
                        'body': suggestion['body'],
                      })
                  .toList(),
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            'coachToneOverride': 'Supportive',
            'coachToneOverrideUntil':
                Timestamp.fromDate(now.add(const Duration(hours: 48))),
            'coachToneOverrideReason': 'comeback',
            'lastSeen': Timestamp.fromDate(now),
            'lastSeenAt': Timestamp.fromDate(now),
            'lastSeenDate': todayStr,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
      batch.set(
          profileRef,
          {
            'lastActiveDate': Timestamp.fromDate(now),
            'coachToneOverride': 'Supportive',
            'coachToneOverrideUntil':
                Timestamp.fromDate(now.add(const Duration(hours: 48))),
            'coachToneOverrideReason': 'comeback',
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      await _eventService.emit(
        eventName: EventNames.comebackInitiated,
        source: 'routine_service',
        eventId: eventId,
        payload: {
          'uid': uid,
          'gapDays': gapDays,
          'lastSeenDate': lastSeenDate,
          'lastSeenSource': lastSeen.source,
          'returnDate': todayStr,
          'threshold': threshold,
          'suggestionIds': suggestionIds,
        },
        batch: batch,
      );

      for (final suggestionId in suggestionIds) {
        await _eventService.emit(
          eventName: EventNames.suggestionGenerated,
          source: 'comeback_modal',
          eventId:
              _eventId('suggestion_generated', uid, todayStr, suggestionId),
          payload: {'suggestionId': suggestionId},
          batch: batch,
        );
      }

      await batch.commit();
      return;
    }

    await _writeLastSeen(uid, now, todayStr);
  }

  Future<_ResolvedLastSeen?> _resolveLastSeen(
    DocumentSnapshot<Map<String, dynamic>> userDoc,
  ) async {
    final data = userDoc.data() ?? const <String, dynamic>{};
    final rootLastSeen = _parseFlexibleDate(data['lastSeen']) ??
        _parseFlexibleDate(data['lastSeenAt']);
    if (rootLastSeen != null) {
      return _ResolvedLastSeen(rootLastSeen, 'users_root');
    }

    final profileSnap =
        await userDoc.reference.collection('profile').doc('main').get();
    final profileLastSeen =
        _parseFlexibleDate(profileSnap.data()?['lastActiveDate']);
    if (profileLastSeen != null) {
      return _ResolvedLastSeen(profileLastSeen, 'profile_main');
    }

    return null;
  }

  Future<void> _writeLastSeen(String uid, DateTime now, String todayStr) async {
    final userRef = _firestore.collection('users').doc(uid);
    final batch = _firestore.batch();
    batch.set(
        userRef,
        {
          'lastSeen': Timestamp.fromDate(now),
          'lastSeenAt': Timestamp.fromDate(now),
          'lastSeenDate': todayStr,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    batch.set(
        userRef.collection('profile').doc('main'),
        {
          'lastActiveDate': Timestamp.fromDate(now),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    await batch.commit();
  }

  Future<int> _countGhostPausedStreaks(String uid) async {
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('streaks')
        .where('state', isEqualTo: 'paused')
        .where('pauseReason', isEqualTo: 'ghost')
        .get();
    return snap.size;
  }

  Future<void> _closeDate(String uid, String dateStr) async {
    final summaryRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('dailySummaries')
        .doc(dateStr);
    if ((await summaryRef.get()).exists) {
      await _firestore.collection('users').doc(uid).set({
        'lastDayClosed': dateStr,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    debugPrint('[RoutineService] Closing day $dateStr');

    await _markOverdueTasks(uid, dateStr);
    final rollup = await _streakService.runDayCloseRollup(dateStr);
    final summary = await computeDailySummary(
      uid: uid,
      date: dateStr,
      rollup: rollup,
    );

    final batch = _firestore.batch();
    batch.set(summaryRef, summary.toFirestore());
    batch.set(
      _firestore.collection('users').doc(uid),
      {
        'lastDayClosed': dateStr,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();

    await _emitRoutineBlockCompletedEvents(uid, dateStr);
    await _eventService.emit(
      eventName: EventNames.routineDaySummarized,
      source: 'routine_service',
      eventId: _eventId('routine_day_summarized', uid, dateStr),
      payload: {
        'date': dateStr,
        'tasksCompleted': summary.tasksCompleted,
        'tasksAbandoned': summary.tasksAbandoned,
        'habitsCompleted': summary.habitsCompleted,
        'habitsBadLogged': summary.habitsBadLogged,
        'streaksActive': summary.streaksActive,
        'milestonesHit': summary.streaksMilestonesHit,
        'missionScore': summary.missionScore,
        'overallPct': summary.overallPct,
        'perRoutinePct': summary.perRoutinePct,
      },
    );
    await _eventService.emit(
      eventName: EventNames.dayClosed,
      source: 'routine_service',
      eventId: _eventId('day_closed', uid, dateStr),
      payload: {
        'date': dateStr,
        'tasksCompleted': summary.tasksCompleted,
        'tasksAbandoned': summary.tasksAbandoned,
        'habitsCompleted': summary.habitsCompleted,
        'habitsBadLogged': summary.habitsBadLogged,
        'streaksActive': summary.streaksActive,
        'missionScore': summary.missionScore,
        'userState': summary.userState,
      },
    );
    await _stateAggregatorService.updateIdentityProfile(uid);
    await _writeContextSnapshot(uid, dateStr, 'day_close');
    debugPrint('[RoutineService] Day $dateStr closed successfully.');
  }

  Future<DaySummary> computeDailySummary({
    required String uid,
    required String date,
    required DayRollupResult rollup,
  }) async {
    final tasks = await _tasksForDate(uid, date);
    final habitLogs = await _habitLogsForDate(uid, date);
    final identityProfile = await _firestore
        .collection('users')
        .doc(uid)
        .collection('identity_profile')
        .doc('main')
        .get();
    final identities = (identityProfile.data()?['identities'] as List? ?? [])
        .map((item) => _normalizeTag(item.toString()))
        .where((item) => item.isNotEmpty)
        .toSet();
    final identityProgress = <String, double>{
      for (final identity
          in (identityProfile.data()?['identities'] as List? ?? const []))
        identity.toString():
            ((identityProfile.data()?['progressPct'] as num?) ?? 0).toDouble(),
    };

    final perRoutine = <String, List<double>>{};
    var tasksCompleted = 0;
    var tasksAbandoned = 0;
    var tasksSkipped = 0;
    var focusMinutes = 0;
    var alignedCompletedValue = 0.0;
    var nonAlignedCompletedValue = 0.0;
    var maxPossibleValue = 0.0;

    for (final task in tasks) {
      if (task.state == TaskState.completed) tasksCompleted++;
      if (task.state == TaskState.abandoned) tasksAbandoned++;
      if (task.state == TaskState.skipped) tasksSkipped++;
      focusMinutes += task.actualDurationMin ?? 0;

      final contribution = _routineContribution(task, DateTime.now());
      if (contribution != null) {
        perRoutine.putIfAbsent(_routineKey(task), () => []).add(contribution);
      }

      if (_excludedFromMission(task)) continue;
      final aligned = task.identityTags
          .map(_normalizeTag)
          .any((tag) => identities.contains(tag));
      final weight = aligned ? 1.0 : 0.5;
      maxPossibleValue +=
          1.0; // denominator = full task count; weight only penalises numerator
      if (task.state == TaskState.completed) {
        if (aligned) {
          alignedCompletedValue += weight;
        } else {
          nonAlignedCompletedValue += weight;
        }
      }
    }

    final perRoutinePct = <String, double>{
      for (final entry in perRoutine.entries)
        entry.key: entry.value.isEmpty
            ? 0
            : entry.value.reduce((a, b) => a + b) / entry.value.length,
    };
    final overallPct = perRoutinePct.isEmpty
        ? 0.0
        : perRoutinePct.values.reduce((a, b) => a + b) / perRoutinePct.length;
    final missionPct = maxPossibleValue <= 0
        ? 0.0
        : ((alignedCompletedValue + nonAlignedCompletedValue) /
                maxPossibleValue)
            .clamp(0.0, 1.0);
    final slipCounts = <String, int>{};
    for (final log in habitLogs) {
      if (log['logType'] != 'slip') continue;
      final habitId = (log['habitId'] ?? '').toString();
      if (habitId.isEmpty) continue;
      slipCounts[habitId] = (slipCounts[habitId] ?? 0) + 1;
    }

    return DaySummary(
      date: date,
      missionScore: (missionPct * 100).round().clamp(0, 100),
      missionPct: missionPct,
      overallPct: overallPct,
      perRoutinePct: perRoutinePct,
      slipCounts: slipCounts,
      identityProgress: identityProgress,
      identityAlignedCompletedValue: alignedCompletedValue,
      nonAlignedCompletedValue: nonAlignedCompletedValue,
      maxPossibleValueToday: maxPossibleValue,
      habitsCompleted: rollup.habitsCompleted,
      habitsBadLogged: rollup.habitsBadLogged,
      tasksCompleted: tasksCompleted,
      tasksAbandoned: tasksAbandoned,
      tasksSkipped: tasksSkipped,
      tasksScheduled: tasks.length,
      focusMinutes: focusMinutes,
      routinesCompleted:
          perRoutinePct.values.where((pct) => pct >= 0.999).length,
      routinesMissed: perRoutinePct.values.where((pct) => pct <= 0).length,
      streaksActive: rollup.streaksActive,
      streaksMilestonesHit: rollup.streaksMilestonesHit,
      addictionsLoggedCount: rollup.habitsBadLogged,
      userState: _deriveUserState(
        habitsCompleted: rollup.habitsCompleted,
        habitsBadLogged: rollup.habitsBadLogged,
        tasksCompleted: tasksCompleted,
        tasksAbandoned: tasksAbandoned,
      ),
      computedAt: DateTime.now(),
    );
  }

  Future<void> _markOverdueTasks(String uid, String dateStr) async {
    final tasks = await _tasksForDate(uid, dateStr);
    for (final task in tasks) {
      if (task.state.isTerminal) continue;

      final now = DateTime.now();
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp()
      };
      String outcome;
      int actualDurationMin;
      double driftPct;
      if (task.state == TaskState.scheduled) {
        outcome = 'skipped';
        actualDurationMin = 0;
        driftPct = task.plannedDurationMin > 0 ? -100 : 0;
        updates.addAll({
          'state': TaskState.skipped.toJson(),
          'status': TaskState.skipped.toJson(),
          'skippedAt': Timestamp.fromDate(now),
          'actualDurationMin': actualDurationMin,
          'driftPct': driftPct,
          'reasonCategory': AbandonReason.autoNoStart.toJson(),
          'reasonTag': 'day_close',
        });
      } else {
        outcome = 'abandoned';
        final activeMinutes = task.actualStart == null
            ? 0
            : now.difference(task.actualStart!).inMinutes.clamp(0, 100000);
        actualDurationMin = activeMinutes;
        driftPct = task.plannedDurationMin > 0
            ? double.parse(
                (((activeMinutes - task.plannedDurationMin) /
                            task.plannedDurationMin) *
                        100)
                    .toStringAsFixed(1),
              )
            : 0;
        updates.addAll({
          'state': TaskState.abandoned.toJson(),
          'status': TaskState.abandoned.toJson(),
          'abandonedAt': Timestamp.fromDate(now),
          'actualDurationMin': actualDurationMin,
          'driftPct': driftPct,
          'reasonCategory': AbandonReason.autoIdle.toJson(),
          'reasonTag': 'day_close',
        });
      }

      final batch = _firestore.batch();
      batch.update(
        _firestore
            .collection('users')
            .doc(uid)
            .collection('tasks')
            .doc(task.id),
        updates,
      );
      batch.set(
        _firestore
            .collection('users')
            .doc(uid)
            .collection('task_outcomes')
            .doc(task.id),
        {
          'taskId': task.id,
          'outcome': outcome,
          'plannedStart': Timestamp.fromDate(task.plannedStart),
          'plannedEnd': Timestamp.fromDate(task.plannedEnd),
          'plannedDurationMin': task.plannedDurationMin,
          if (task.actualStart != null)
            'actualStart': Timestamp.fromDate(task.actualStart!),
          'actualEnd': Timestamp.fromDate(now),
          'actualDurationMin': actualDurationMin,
          'durationDriftPct': driftPct,
          'subtasksPlanned': task.subtasks.length,
          'subtasksCompleted': task.subtasks.where((s) => s.checked).length,
          'reasonCategory': updates['reasonCategory'],
          'reasonTag': 'day_close',
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await batch.commit();
    }
  }

  Future<void> _emitRoutineBlockCompletedEvents(
      String uid, String dateStr) async {
    for (final task in await _tasksForDate(uid, dateStr)) {
      if (task.state != TaskState.completed || task.parentRoutine == null) {
        continue;
      }
      await _eventService.emit(
        eventName: EventNames.routineBlockCompleted,
        source: 'routine_service',
        eventId: _eventId('routine_block_completed', uid, dateStr, task.id),
        payload: {
          'taskId': task.id,
          'routineType': _routineKey(task),
          'routineId': task.parentRoutine,
          'date': dateStr,
        },
      );
    }
  }

  Future<List<TaskModel>> _tasksForDate(String uid, String dateStr) async {
    final start = _parseDate(dateStr);
    final end = start.add(const Duration(days: 1));
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .where('plannedStart',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('plannedStart', isLessThan: Timestamp.fromDate(end))
        .get();
    return snap.docs.map(TaskModel.fromFirestore).toList();
  }

  Future<List<Map<String, dynamic>>> _habitLogsForDate(
      String uid, String dateStr) async {
    final start = _parseDate(dateStr);
    final end = start.add(const Duration(days: 1));
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('habit_logs')
        .where('occurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('occurredAt', isLessThan: Timestamp.fromDate(end))
        .get();
    return snap.docs.map((doc) => doc.data()).toList();
  }

  Future<void> _writeContextSnapshot(
    String uid,
    String dateStr,
    String source,
  ) async {
    final snapshot = await _stateAggregatorService.buildSnapshot(uid);
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('ai_context_snapshots')
        .doc('${dateStr}_$source')
        .set({
      ...snapshot.toMap(),
      'date': dateStr,
      'source': source,
      'createdAt': FieldValue.serverTimestamp(),
      'schemaVersion': 1,
    }, SetOptions(merge: true));
  }

  Future<void> _materializeTemplatesForDate(String uid, DateTime date) async {
    final routineSnap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('routine')
        .doc('current')
        .get();
    final templatesRoot = routineSnap.data()?['templates'];
    if (templatesRoot is! Map) return;

    final dateStr = _formatDate(date);
    for (final entry in templatesRoot.entries) {
      final routineType = entry.key.toString();
      if (entry.value is! List) continue;
      for (final raw in entry.value as List) {
        if (raw is! Map || raw['isActive'] == false) continue;
        final templateMap = Map<String, dynamic>.from(raw);
        final templateModel = RoutineTemplateModel.forSave(
          templateMap,
          fallbackRoutineType: routineType,
        );
        final template = templateModel.toMap();

        final repeatRule = templateModel.repeatRule.trim().isEmpty
            ? 'daily'
            : templateModel.repeatRule;
        final targetDate = (templateMap['targetDate']?.toString() ?? '').trim();
        final startDate = (templateMap['startDate']?.toString() ?? '').trim();
        final endDate = (templateMap['endDate']?.toString() ?? '').trim();
        if (targetDate.isNotEmpty && targetDate != dateStr) continue;
        if (startDate.isNotEmpty && dateStr.compareTo(startDate) < 0) {
          continue;
        }
        if (endDate.isNotEmpty && dateStr.compareTo(endDate) > 0) {
          continue;
        }
        final repeatRuleKey = repeatRule.toLowerCase();
        final repeatsToday = repeatRuleKey == 'once'
            ? targetDate == dateStr
            : _repeatRuleMatchesDate(repeatRule, date);
        if (!repeatsToday) continue;

        final title = templateModel.title;
        if (title.isEmpty) continue;
        final candidateRoutineType = templateModel.routineType.trim().isEmpty
            ? routineType
            : templateModel.routineType;
        final templateId = templateModel.templateId;

        final startTime = _normalizeTime(templateModel.startTime, '09:00');
        final hasExplicitEndTime =
            (templateMap['endTime']?.toString().trim() ?? '').isNotEmpty;
        final endTime = _normalizeTime(templateModel.endTime, '09:30');
        final plannedStart = _dateTimeFromTime(date, startTime);
        var plannedEnd = hasExplicitEndTime
            ? _dateTimeFromTime(date, endTime)
            : plannedStart.add(const Duration(minutes: 30));
        if (!plannedEnd.isAfter(plannedStart)) {
          plannedEnd = plannedStart.add(const Duration(minutes: 30));
        }

        final taskId =
            'routine_${dateStr}_${_slug(candidateRoutineType)}_${_slug(templateId)}';
        final taskRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('tasks')
            .doc(taskId);
        final taskSnap = await taskRef.get();
        if (taskSnap.exists) {
          final state =
              _taskState(taskSnap.data() ?? const <String, dynamic>{});
          if (_isTerminalTaskState(state)) continue;

          await taskRef.set(
            {
              'sourceRoutineType': candidateRoutineType,
              'routineTemplateId': templateId,
              'scheduledDate': dateStr,
              'repeatRule': repeatRule,
              'materializedFromTemplateAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
              'schemaVersion': 1,
            },
            SetOptions(merge: true),
          );
          continue;
        }

        final now = DateTime.now();
        final task = TaskModel(
          id: taskId,
          type: _taskTypeForRoutineType(candidateRoutineType),
          parentRoutine: templateId,
          title: title,
          emoji: template['emoji']?.toString(),
          color: template['colorHex']?.toString(),
          identityTags: [candidateRoutineType],
          plannedStart: plannedStart,
          plannedEnd: plannedEnd,
          subtasks: _subtasksForTemplate(template),
          createdAt: now,
          updatedAt: now,
        );
        final batch = _firestore.batch();
        batch.set(taskRef, {
          ...task.toFirestore(),
          'status': TaskState.scheduled.toJson(),
          'sourceRoutineType': candidateRoutineType,
          'routineTemplateId': templateId,
          'scheduledDate': dateStr,
          'repeatRule': repeatRule,
          'materializedFromTemplateAt': FieldValue.serverTimestamp(),
        });
        await _eventService.emit(
          eventName: EventNames.taskScheduled,
          source: 'routine_service',
          eventId: _eventId('task_scheduled', uid, taskId),
          payload: _taskPayload(task),
          batch: batch,
        );
        await batch.commit();
      }
    }
  }

  double? _routineContribution(TaskModel task, DateTime now) {
    if (_excludedRoutineSkip(task)) return null;
    switch (task.state) {
      case TaskState.completed:
        return 1;
      case TaskState.started:
      case TaskState.paused:
        final elapsed = (task.state == TaskState.paused && task.pausedAt != null
                ? task.pausedAt!
                : now)
            .difference(task.actualStart ?? task.plannedStart)
            .inMinutes;
        if (task.plannedDurationMin <= 0) return 0;
        return (elapsed / task.plannedDurationMin).clamp(0, 0.95).toDouble();
      case TaskState.abandoned:
      case TaskState.skipped:
      case TaskState.scheduled:
        return 0;
    }
  }

  bool _excludedRoutineSkip(TaskModel task) {
    if (task.state != TaskState.skipped) return false;
    final tag = (task.reasonTag ?? '').toLowerCase();
    return tag == 'valid_reason' || tag == 'day_off' || tag == 'illness';
  }

  bool _excludedFromMission(TaskModel task) => _excludedRoutineSkip(task);

  String _routineKey(TaskModel task) {
    final type = task.type.toJson();
    if (type == 'custom' && task.parentRoutine != null) {
      return task.parentRoutine!;
    }
    return type;
  }

  String _deriveUserState({
    required int habitsCompleted,
    required int habitsBadLogged,
    required int tasksCompleted,
    required int tasksAbandoned,
  }) {
    final positives = habitsCompleted + tasksCompleted;
    final negatives = habitsBadLogged + tasksAbandoned;
    if (habitsBadLogged >= 3 && positives == 0) return 'relapsing';
    if (negatives > 0 && positives > 0) return 'recovering';
    if (negatives > 0) return 'slipping';
    return 'on_track';
  }

  Map<String, dynamic> _taskPayload(TaskModel task) => {
        'taskId': task.id,
        'type': task.type.toJson(),
        'plannedStart': task.plannedStart.toIso8601String(),
        'plannedEnd': task.plannedEnd.toIso8601String(),
        'plannedDurationMin': task.plannedDurationMin,
      };

  List<Subtask> _subtasksForTemplate(Map<String, dynamic> template) {
    final subtasks = <Subtask>[];
    for (final step in template['steps'] as List? ?? const []) {
      if (step is Map && (step['name']?.toString().trim() ?? '').isNotEmpty) {
        final title = step['name'].toString().trim();
        subtasks.add(Subtask(id: _slug(title), title: title));
      } else if (step is String && step.trim().isNotEmpty) {
        subtasks.add(Subtask(id: _slug(step), title: step.trim()));
      }
    }
    for (final entry in const {
      'dosage': 'dosage',
      'room': 'room',
      'professor': 'professor',
    }.entries) {
      final value = template[entry.key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        subtasks.add(Subtask(id: entry.value, title: value));
      }
    }
    return subtasks;
  }

  TaskType _taskTypeForRoutineType(String routineType) {
    switch (routineType) {
      case 'skin_care':
        return TaskType.skinCare;
      case 'eating':
        return TaskType.eating;
      case 'classes':
        return TaskType.classBlock;
      case 'fixed_schedule':
        return TaskType.fixed;
      default:
        return TaskType.custom;
    }
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  /// Zero-padded `YYYY-MM-DD` string for a given [DateTime].
  static String _formatDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  static DateTime _parseDate(String value) {
    final parts = value.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }

  static String _eventId(String eventName, String uid, String date,
          [String extra = '']) =>
      [
        'client',
        eventName,
        uid,
        date,
        if (extra.isNotEmpty) extra,
      ].map(_slug).join('_');

  static String _slug(String value) {
    final slug = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return slug.isEmpty ? 'item' : slug;
  }

  static String _normalizeTag(String value) => value.trim().toLowerCase();

  static String _normalizeTime(Object? value, String fallback) {
    final match =
        RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value?.toString() ?? '');
    if (match == null) return fallback;
    final hour = int.tryParse(match.group(1)!) ?? 0;
    final minute = int.tryParse(match.group(2)!) ?? 0;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return fallback;
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  static DateTime _dateTimeFromTime(DateTime date, String hhmm) {
    final normalized = _normalizeTime(hhmm, '09:00');
    final parts = normalized.split(':').map(int.parse).toList();
    return DateTime(date.year, date.month, date.day, parts[0], parts[1]);
  }

  static bool _repeatRuleMatchesDate(String repeatRule, DateTime date) {
    final rule = repeatRule.trim().toLowerCase();
    if (rule.isEmpty || rule == 'daily') return true;
    if (rule == 'once') return false;

    final weekly = RegExp(r'^weekly:(.+)$').firstMatch(rule);
    if (weekly != null) {
      final days = weekly
          .group(1)!
          .split(',')
          .map((part) => int.tryParse(part.trim()))
          .whereType<int>()
          .toSet();
      return days.contains(date.weekday);
    }
    final weekday =
        RegExp(r'^(weekday|mess_menu_weekday):(\d)$').firstMatch(rule);
    if (weekday != null) return int.parse(weekday.group(2)!) == date.weekday;

    final monthly = RegExp(r'^monthly:(\d{1,2})$').firstMatch(rule);
    if (monthly != null) {
      return int.tryParse(monthly.group(1)!) == date.day;
    }

    debugPrint(
        '[RoutineService] Unknown repeat rule: $repeatRule. Failing safely.');
    return false;
  }

  static String _taskState(Map<String, dynamic> data) =>
      ((data['state'] as String?) ?? (data['status'] as String?) ?? 'scheduled')
          .toLowerCase();

  static bool _isTerminalTaskState(String state) =>
      state == 'completed' ||
      state == 'skipped' ||
      state == 'abandoned' ||
      state == 'cancelled';

  static DateTime? _parseFlexibleDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
      final parts = value.split('-').map(int.tryParse).toList();
      if (parts.length == 3 && parts.every((part) => part != null)) {
        return DateTime(parts[0]!, parts[1]!, parts[2]!);
      }
    }
    return null;
  }

  static int _comebackThreshold(int gapDays) {
    const thresholds = [30, 14, 7, 3];
    return thresholds.firstWhere((threshold) => gapDays >= threshold);
  }

  static List<String> _comebackSuggestionIds(String returnDate) => [
        'comeback_${returnDate}_tiny_anchor',
        'comeback_${returnDate}_one_habit_log',
        'comeback_${returnDate}_short_reset',
      ];

  static List<Map<String, dynamic>> _comebackSuggestions({
    required List<String> suggestionIds,
    required int gapDays,
    required DateTime now,
  }) {
    final ideas = [
      (
        title: 'Pick one tiny anchor',
        body: 'Choose the smallest scheduled block and call that the restart.',
      ),
      (
        title: 'Log one honest habit',
        body: 'One habit log is enough to make today count again.',
      ),
      (
        title: 'Do a 10-minute reset',
        body: 'Set a short timer, clear one task, then stop cleanly.',
      ),
    ];

    return [
      for (var i = 0; i < suggestionIds.length; i++)
        SuggestionModel(
          suggestionId: suggestionIds[i],
          title: ideas[i].title,
          body: ideas[i].body,
          reason: ideas[i].body,
          category: 'comeback_restart',
          status: 'generated',
          source: 'comeback_modal',
          gapDays: gapDays,
          createdAt: now,
          updatedAt: now,
        ).toMap(),
    ];
  }
}

class _ResolvedLastSeen {
  final DateTime value;
  final String source;

  const _ResolvedLastSeen(this.value, this.source);
}
