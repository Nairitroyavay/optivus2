import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppUsage — a single app's foreground time for the day
// ─────────────────────────────────────────────────────────────────────────────

class AppUsage {
  final String packageName;
  final String appName;
  final int minutes;

  const AppUsage({
    required this.packageName,
    required this.appName,
    required this.minutes,
  });

  factory AppUsage.fromMap(Map<String, dynamic> map) => AppUsage(
        packageName: map['packageName'] as String? ?? '',
        appName:
            map['appName'] as String? ?? map['packageName'] as String? ?? '',
        minutes: (map['minutes'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'packageName': packageName,
        'appName': appName,
        'minutes': minutes,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// ScreenTimeLogModel — persisted at /users/{uid}/screen_time_logs/{logId}
// ─────────────────────────────────────────────────────────────────────────────

class ScreenTimeLogModel {
  /// Document ID — always "daily_YYYY-MM-DD" for idempotent daily upserts.
  final String logId;

  /// Owner UID — redundant but useful for server-side queries.
  final String uid;

  /// Total foreground screen time across all apps today, in minutes.
  final int totalMinutes;

  /// Top apps sorted by foreground time (up to 5 entries).
  final List<AppUsage> topApps;

  /// Number of device unlocks today.
  final int unlockCount;

  /// Moment the snapshot was captured on the device.
  final DateTime capturedAt;

  /// Schema version — bump when the shape changes.
  final int schemaVersion;

  const ScreenTimeLogModel({
    required this.logId,
    required this.uid,
    required this.totalMinutes,
    required this.topApps,
    required this.unlockCount,
    required this.capturedAt,
    this.schemaVersion = 1,
  });

  // ── Firestore serialisation ───────────────────────────────────────────────

  factory ScreenTimeLogModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ScreenTimeLogModel(
      logId: data['logId'] as String? ?? doc.id,
      uid: data['uid'] as String? ?? '',
      totalMinutes: (data['totalMinutes'] as num?)?.toInt() ?? 0,
      topApps: (data['topApps'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => AppUsage.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      unlockCount: (data['unlockCount'] as num?)?.toInt() ?? 0,
      capturedAt: _toDateTime(data['capturedAt']) ?? DateTime.now(),
      schemaVersion: (data['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'logId': logId,
        'uid': uid,
        'totalMinutes': totalMinutes,
        'topApps': topApps.map((a) => a.toMap()).toList(),
        'unlockCount': unlockCount,
        'capturedAt': Timestamp.fromDate(capturedAt),
        'schemaVersion': schemaVersion,
      };

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Formats [totalMinutes] as "Xh Ym" (e.g. "2h 7m").
  String get formattedTotal {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  static DateTime? _toDateTime(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
