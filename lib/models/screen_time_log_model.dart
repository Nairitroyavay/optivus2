import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppUsage — a single app's foreground time for the day
// ─────────────────────────────────────────────────────────────────────────────

class AppUsage {
  final String packageName;
  final String appName;
  final int minutes;
  final int unlockCount;

  const AppUsage({
    required this.packageName,
    required this.appName,
    required this.minutes,
    this.unlockCount = 0,
  });

  factory AppUsage.fromMap(Map<String, dynamic> map) => AppUsage(
        packageName: map['packageName'] as String? ?? '',
        appName:
            map['appName'] as String? ?? map['packageName'] as String? ?? '',
        minutes: (map['minutes'] as num?)?.toInt() ?? 0,
        unlockCount: (map['unlockCount'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'packageName': packageName,
        'appName': appName,
        'minutes': minutes,
        'unlockCount': unlockCount,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// ScreenTimeLogModel — persisted at /users/{uid}/screenTimeRaw/{logId}
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

  /// Number of minutes used per hour (index 0 = 12 AM).
  final List<int> hourlyDistribution;

  /// User-defined caps per package name (in minutes).
  final Map<String, int> appCaps;

  /// Package names that already triggered a slip event today.
  final List<String> slippedAppsToday;

  /// Number of times any cap was crossed today (1st vs 2nd escalation).
  final int crossingCount;

  /// 7-day trailing average of totalMinutes.
  final int weeklyAverage;

  /// Flagged true if heuristic determines non-actionable unlocks (>80/day).
  final bool unlockHeuristicFlagged;

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
    this.hourlyDistribution = const [],
    this.appCaps = const {},
    this.slippedAppsToday = const [],
    this.crossingCount = 0,
    this.weeklyAverage = 0,
    this.unlockHeuristicFlagged = false,
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
      hourlyDistribution: (data['hourlyDistribution'] as List<dynamic>? ?? [])
          .map((e) => (e as num).toInt())
          .toList(),
      appCaps: (data['appCaps'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, (v as num).toInt())),
      slippedAppsToday: (data['slippedAppsToday'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      crossingCount: (data['crossingCount'] as num?)?.toInt() ?? 0,
      weeklyAverage: (data['weeklyAverage'] as num?)?.toInt() ?? 0,
      unlockHeuristicFlagged: data['unlockHeuristicFlagged'] as bool? ?? false,
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
        'hourlyDistribution': hourlyDistribution,
        'appCaps': appCaps,
        'slippedAppsToday': slippedAppsToday,
        'crossingCount': crossingCount,
        'weeklyAverage': weeklyAverage,
        'unlockHeuristicFlagged': unlockHeuristicFlagged,
        'capturedAt': Timestamp.fromDate(capturedAt),
        'schemaVersion': schemaVersion,
      };

  // ── Helpers ───────────────────────────────────────────────────────────────

  ScreenTimeLogModel copyWith({
    String? logId,
    String? uid,
    int? totalMinutes,
    List<AppUsage>? topApps,
    int? unlockCount,
    List<int>? hourlyDistribution,
    Map<String, int>? appCaps,
    List<String>? slippedAppsToday,
    int? crossingCount,
    int? weeklyAverage,
    bool? unlockHeuristicFlagged,
    DateTime? capturedAt,
    int? schemaVersion,
  }) {
    return ScreenTimeLogModel(
      logId: logId ?? this.logId,
      uid: uid ?? this.uid,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      topApps: topApps ?? this.topApps,
      unlockCount: unlockCount ?? this.unlockCount,
      hourlyDistribution: hourlyDistribution ?? this.hourlyDistribution,
      appCaps: appCaps ?? this.appCaps,
      slippedAppsToday: slippedAppsToday ?? this.slippedAppsToday,
      crossingCount: crossingCount ?? this.crossingCount,
      weeklyAverage: weeklyAverage ?? this.weeklyAverage,
      unlockHeuristicFlagged:
          unlockHeuristicFlagged ?? this.unlockHeuristicFlagged,
      capturedAt: capturedAt ?? this.capturedAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns true if the given package has crossed its user-defined cap today.
  bool isCapCrossed(String packageName) {
    final cap = appCaps[packageName];
    if (cap == null) return false;
    final app = topApps.firstWhere(
      (a) => a.packageName == packageName,
      orElse: () => const AppUsage(packageName: '', appName: '', minutes: 0),
    );
    return app.minutes >= cap;
  }

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
