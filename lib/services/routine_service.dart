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
import '../models/user_model.dart';
import 'event_service.dart';
import 'streak_service.dart';

class RoutineService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final EventService _eventService;
  final StreakService _streakService;

  RoutineService({
    required EventService eventService,
    required StreakService streakService,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _eventService = eventService,
        _streakService = streakService,
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
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr = _formatDate(yesterday);

      if (lastDayClosed != null && lastDayClosed.compareTo(yesterdayStr) >= 0) {
        // Already closed — nothing to do.
        return;
      }

      debugPrint(
          '[RoutineService] Closing day $yesterdayStr (last: $lastDayClosed)');

      // ── Step 1-3: Roll up habit logs and compute / write streak docs ──────
      //
      // Habit logs are already normalised in /users/{uid}/habit_logs by
      // HabitService's dual-write.  StreakService reads exclusively from
      // that canonical collection so streak computation is safe here.
      final rollup = await _streakService.runDayCloseRollup(yesterdayStr);

      // ── Step 4: Write dailySummaries/{date} with real metrics ─────────────
      final summary = DaySummary(
        date: yesterdayStr,
        habitsCompleted: rollup.habitsCompleted,
        habitsBadLogged: rollup.habitsBadLogged,
        streaksActive: rollup.streaksActive,
        streaksMilestonesHit: rollup.streaksMilestonesHit,
        computedAt: now,
      );

      final batch = _firestore.batch();

      // /users/{uid}/dailySummaries/{date}
      final summaryRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('dailySummaries')
          .doc(yesterdayStr);
      batch.set(summaryRef, summary.toFirestore());

      // Advance lastDayClosed on the user document.
      final userRef = _firestore.collection('users').doc(uid);
      batch.update(userRef, {
        'lastDayClosed': yesterdayStr,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // ── Step 5-7: Emit day lifecycle events ───────────────────────────────
      //
      // Streak-level events (streakExtended, streakBroken, streakMilestoneReached)
      // were already emitted atomically per-habit inside runDayCloseRollup.
      // We emit only the day-scope events here.

      await _eventService.emit(
        eventName: EventNames.dayClosed,
        payload: {
          'date': yesterdayStr,
          'habitsCompleted': rollup.habitsCompleted,
          'streaksActive': rollup.streaksActive,
        },
      );

      await _eventService.emit(
        eventName: EventNames.routineDaySummarized,
        payload: {
          'date': yesterdayStr,
          'habitsCompleted': rollup.habitsCompleted,
          'streaksActive': rollup.streaksActive,
          'milestonesHit': rollup.streaksMilestonesHit,
        },
      );

      debugPrint('[RoutineService] Day $yesterdayStr closed successfully.');
    } catch (e, st) {
      debugPrint('[RoutineService] Error in runDayCloseIfNeeded: $e\n$st');
    }
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  /// Zero-padded `YYYY-MM-DD` string for a given [DateTime].
  static String _formatDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}
