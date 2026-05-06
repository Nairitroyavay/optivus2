import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/event_names.dart';
import '../models/event_model.dart';
import '../models/screen_time_log_model.dart';
import 'event_service.dart';
import 'screen_time_bridge.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ScreenTimeImporter
//
// Orchestrates the full import pipeline:
//   1. Pull live data from ScreenTimeBridge (native UsageStatsManager)
//   2. Map to ScreenTimeLogModel
//   3. Upsert to /users/{uid}/screenTimeRaw/daily_YYYY-MM-DD  (idempotent)
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

  Timer? _syncTimer;
  StreamSubscription<EventModel>? _dayCloseSubscription;

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

  /// Starts a periodic sync every 30 minutes while the app is in foreground,
  /// and subscribes to the [EventNames.dayClosed] event for a day-close sync.
  void startForegroundSyncLoop() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      sync();
    });
    _listenDayClose();
    debugPrint('[ScreenTimeImporter] Foreground sync loop started (30m).');
    // Initial sync
    sync();
  }

  void stopForegroundSyncLoop() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _dayCloseSubscription?.cancel();
    _dayCloseSubscription = null;
    debugPrint('[ScreenTimeImporter] Foreground sync loop stopped.');
  }

  /// Subscribes once to [EventNames.dayClosed] so the final snapshot of the
  /// day is captured even if the 30-minute timer has not yet fired.
  void _listenDayClose() {
    _dayCloseSubscription?.cancel();
    _dayCloseSubscription =
        _eventService.on(EventNames.dayClosed).listen((_) {
      debugPrint('[ScreenTimeImporter] dayClosed received — running day-close sync.');
      sync();
    });
  }

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
    final logRef = _screenTimeLogsRef(uid).doc(logId);

    // 3. Fetch context for weekly average and crossings
    // Calculate weekly average (last 7 days)
    final lastWeek = await _screenTimeLogsRef(uid)
        .where(FieldPath.documentId, isLessThan: logId)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(7)
        .get();

    int weeklyAverage = snapshot.totalMinutes;
    if (lastWeek.docs.isNotEmpty) {
      final sum = lastWeek.docs.fold<int>(0, (prev, doc) {
        return prev + ((doc.data()['totalMinutes'] as num?)?.toInt() ?? 0);
      });
      weeklyAverage = (sum / lastWeek.docs.length).round();
    }

    Map<String, int> appCaps = {};
    List<String> slippedAppsToday = [];
    int crossingCount = 0;

    final todaySnap = await logRef.get();
    if (todaySnap.exists) {
      final todayLog = ScreenTimeLogModel.fromFirestore(todaySnap);
      appCaps = Map<String, int>.from(todayLog.appCaps);
      slippedAppsToday = List<String>.from(todayLog.slippedAppsToday);
      crossingCount = todayLog.crossingCount;
    } else {
      // Carry forward caps from most recent log
      if (lastWeek.docs.isNotEmpty) {
        final lastLog = ScreenTimeLogModel.fromFirestore(lastWeek.docs.first);
        appCaps = Map<String, int>.from(lastLog.appCaps);
      }
    }

    // 4. Evaluate heuristics and cap violations
    final unlockHeuristicFlagged = snapshot.unlockCount > 80;
    final newSlips = <String>[];
    bool anyNewCrossing = false;

    for (final app in snapshot.topApps) {
      final cap = appCaps[app.packageName];
      if (cap != null && app.minutes >= cap) {
        if (!slippedAppsToday.contains(app.packageName)) {
          newSlips.add(app.packageName);
          slippedAppsToday.add(app.packageName);
          anyNewCrossing = true;
        }
      }
    }

    if (anyNewCrossing) {
      crossingCount++;
    }

    // 5. Save merged log
    final log = ScreenTimeLogModel(
      logId: logId,
      uid: uid,
      totalMinutes: snapshot.totalMinutes,
      topApps: snapshot.topApps,
      unlockCount: snapshot.unlockCount,
      hourlyDistribution: snapshot.hourlyDistribution,
      appCaps: appCaps,
      slippedAppsToday: slippedAppsToday,
      crossingCount: crossingCount,
      weeklyAverage: weeklyAverage,
      unlockHeuristicFlagged: unlockHeuristicFlagged,
      capturedAt: now,
      schemaVersion: snapshot.schemaVersion,
    );

    await logRef.set(log.toFirestore(), SetOptions(merge: true));

    // 6. Emit events and log slips.
    // Payload is intentionally minimal — the StrictEventRule for
    // screen_time_synced only permits logId + totalMinutes.
    // All additional context (unlockCount, weeklyAverage, crossingCount) is
    // already persisted in the Firestore document written above.
    await _eventService.emit(
      eventName: EventNames.screenTimeSynced,
      eventId: 'screen_time_synced_${logId}_${snapshot.capturedAtMs}',
      payload: {
        'logId': logId,
        'totalMinutes': snapshot.totalMinutes,
      },
      source: 'screen_time_importer',
    );

    if (newSlips.isNotEmpty) {
      final habitId = await _getScreenTimeHabitId(uid);
      for (final slipApp in newSlips) {
        await _eventService.emit(
          eventName: EventNames.badHabitSlipLogged,
          eventId: 'slip_${slipApp}_${logId}_${snapshot.capturedAtMs}',
          payload: {
            'packageName': slipApp,
            'habitName': snapshot.topApps
                .firstWhere((a) => a.packageName == slipApp)
                .appName,
            'logId': logId,
            'habitId': habitId,
            'crossingCount': crossingCount,
          },
          source: 'screen_time_importer',
          priority: 'high',
        );

        if (habitId != null) {
          await _firestore
              .collection('users')
              .doc(uid)
              .collection('habit_logs')
              .add({
            'habitId': habitId,
            'habitKind': 'bad',
            'logType': 'slip',
            'occurredAt': FieldValue.serverTimestamp(),
            'loggedAt': FieldValue.serverTimestamp(),
            'trigger': 'cap_crossed: $slipApp',
            'note': 'App $slipApp crossed its ${appCaps[slipApp]}m cap.',
            'source': 'auto_screen_time',
            'schemaVersion': 1,
          });
        }
      }
    }

    debugPrint('[ScreenTimeImporter] sync OK '
        'totalMinutes=${snapshot.totalMinutes} '
        'unlockCount=${snapshot.unlockCount} '
        'newSlips=${newSlips.length} '
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

  /// Updates the cap for a specific app in today's log.
  Future<void> updateAppCap(String packageName, int capMinutes) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final logId = _dailyLogId(DateTime.now());
    await _screenTimeLogsRef(uid).doc(logId).set({
      'appCaps': {packageName: capMinutes}
    }, SetOptions(merge: true));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<String?> _getScreenTimeHabitId(String uid) async {
    final habits = await _firestore
        .collection('users')
        .doc(uid)
        .collection('habits')
        .where('trackerType', isEqualTo: 'screen_time')
        .limit(1)
        .get();
    return habits.docs.isEmpty ? null : habits.docs.first.id;
  }

  CollectionReference<Map<String, dynamic>> _screenTimeLogsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('screenTimeRaw');

  /// Returns a canonical document ID for the given date: "daily_YYYY-MM-DD"
  static String _dailyLogId(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return 'daily_$y-$m-$d';
  }
}
