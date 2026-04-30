import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/event_names.dart';
import '../models/screen_time_log_model.dart';
import 'event_service.dart';
import 'screen_time_bridge.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ScreenTimeImporter
//
// Orchestrates the full import pipeline:
//   1. Pull live data from ScreenTimeBridge (native UsageStatsManager)
//   2. Map to ScreenTimeLogModel
//   3. Upsert to /users/{uid}/screen_time_logs/daily_YYYY-MM-DD  (idempotent)
//   4. Emit screen_time_synced event via EventService
//
// Logs a confirmation line so console verification is trivial:
//   [ScreenTimeImporter] sync OK totalMinutes=X unlockCount=Y
// ─────────────────────────────────────────────────────────────────────────────

class ScreenTimeImporter {
  final ScreenTimeBridge _bridge;
  final EventService _eventService;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ScreenTimeImporter({
    required ScreenTimeBridge bridge,
    required EventService eventService,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _bridge = bridge,
        _eventService = eventService,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns true if the device-level usage-stats permission is granted.
  Future<bool> hasPermission() => _bridge.hasPermission();

  /// Opens the system settings page for granting usage access.
  Future<void> requestPermission() => _bridge.requestPermission();

  /// Runs the full sync pipeline.
  ///
  /// Returns the persisted [ScreenTimeLogModel] on success, or null if:
  ///   - No user is signed in
  ///   - Permission is not granted
  ///   - The native query fails
  Future<ScreenTimeLogModel?> sync() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      debugPrint('[ScreenTimeImporter] sync aborted: no authenticated user');
      return null;
    }

    // 1. Query native layer
    final snapshot = await _bridge.queryToday();
    if (snapshot == null) {
      debugPrint('[ScreenTimeImporter] sync aborted: bridge returned null '
          '(permission not granted or non-Android)');
      return null;
    }

    // 2. Build log document — idempotent doc ID keyed on today's date
    final now = snapshot.capturedAt;
    final logId = _dailyLogId(now);

    final log = ScreenTimeLogModel(
      logId: logId,
      uid: uid,
      totalMinutes: snapshot.totalMinutes,
      topApps: snapshot.topApps,
      unlockCount: snapshot.unlockCount,
      capturedAt: now,
      schemaVersion: snapshot.schemaVersion,
    );

    // 3. Upsert to Firestore (merge: true so we overwrite stale values safely)
    final logRef = _screenTimeLogsRef(uid).doc(logId);
    await logRef.set(log.toFirestore(), SetOptions(merge: true));

    // 4. Emit event
    await _eventService.emit(
      eventName: EventNames.screenTimeSynced,
      eventId: 'screen_time_synced_${logId}_${snapshot.capturedAtMs}',
      payload: {
        'totalMinutes': snapshot.totalMinutes,
        'unlockCount': snapshot.unlockCount,
        'topAppCount': snapshot.topApps.length,
        'topApps': snapshot.topApps.map((app) => app.toMap()).toList(),
        'logId': logId,
        'capturedAt': now.toUtc().toIso8601String(),
        'schemaVersion': snapshot.schemaVersion,
      },
      source: 'screen_time_importer',
      priority: 'normal',
    );

    debugPrint('[ScreenTimeImporter] sync OK '
        'totalMinutes=${snapshot.totalMinutes} '
        'unlockCount=${snapshot.unlockCount} '
        'topApps=${snapshot.topApps.length} '
        'logId=$logId');

    return log;
  }

  // ── Stream — real-time listener for today's log ────────────────────────────

  /// Emits the current day's [ScreenTimeLogModel] in real time.
  /// Emits null when no document exists yet (pre-first sync).
  Stream<ScreenTimeLogModel?> watchToday() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);

    final logId = _dailyLogId(DateTime.now());
    return _screenTimeLogsRef(uid).doc(logId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return ScreenTimeLogModel.fromFirestore(snap);
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _screenTimeLogsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('screen_time_logs');

  /// Returns a canonical document ID for the given date: "daily_YYYY-MM-DD"
  static String _dailyLogId(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return 'daily_$y-$m-$d';
  }
}
