// lib/services/routine_service.dart

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
      final yesterdayStr = "${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";

      if (lastDayClosed == null || lastDayClosed.compareTo(yesterdayStr) < 0) {
        debugPrint('[RoutineService] Closing day $yesterdayStr (last: $lastDayClosed)');

        // Run streak rollup
        await _streakService.runDayCloseRollup(yesterdayStr);

        // Generate DaySummaryModel
        final summary = DaySummary(
          date: yesterdayStr,
          computedAt: now,
        );

        final batch = _firestore.batch();

        // Write to /users/{uid}/dailySummaries/{date}
        final summaryRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('dailySummaries')
            .doc(yesterdayStr);
        batch.set(summaryRef, summary.toFirestore());

        // Update lastDayClosed on UserModel
        final userRef = _firestore.collection('users').doc(uid);
        batch.update(userRef, {
          'lastDayClosed': yesterdayStr,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await batch.commit();

        // Emit EventNames.dayClosed
        await _eventService.emit(
          eventName: EventNames.dayClosed,
          payload: {'date': yesterdayStr},
        );
      }
    } catch (e, st) {
      debugPrint('[RoutineService] Error running runDayCloseIfNeeded: $e\n$st');
    }
  }
}
