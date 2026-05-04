import 'package:cloud_firestore/cloud_firestore.dart';

class IdentityProfileModel {
  final List<String> identities;
  final int progressPct;
  final DateTime lastComputedAt;
  final List<String> activeGoalIds;
  final List<String> pausedGoalIds;
  final List<String> archivedGoalIds;
  final Map<String, int> goalProgress;
  final List<String> connectedHabitIds;
  final List<String> connectedRoutineTypes;
  final int schemaVersion;

  const IdentityProfileModel({
    this.identities = const [],
    this.progressPct = 0,
    required this.lastComputedAt,
    this.activeGoalIds = const [],
    this.pausedGoalIds = const [],
    this.archivedGoalIds = const [],
    this.goalProgress = const {},
    this.connectedHabitIds = const [],
    this.connectedRoutineTypes = const [],
    this.schemaVersion = 3,
  });

  factory IdentityProfileModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return IdentityProfileModel.fromMap(doc.data() ?? const {});
  }

  factory IdentityProfileModel.fromMap(Map<String, dynamic> map) {
    final identities = _stringList(
      map['identities'] ?? map['identityTags'] ?? map['goals'],
    );

    return IdentityProfileModel(
      identities: identities,
      progressPct: _progress(map['progressPct'] ?? map['progress']),
      lastComputedAt: _asDateTime(map['lastComputedAt']) ??
          _asDateTime(map['updatedAt']) ??
          DateTime.now(),
      activeGoalIds: _stringList(map['activeGoalIds']),
      pausedGoalIds: _stringList(map['pausedGoalIds']),
      archivedGoalIds: _stringList(map['archivedGoalIds']),
      goalProgress: _intMap(map['goalProgress']),
      connectedHabitIds: _stringList(map['connectedHabitIds']),
      connectedRoutineTypes: _stringList(map['connectedRoutineTypes']),
      schemaVersion: map['schemaVersion'] as int? ?? 3,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'identities': identities,
      'progressPct': progressPct,
      'lastComputedAt': Timestamp.fromDate(lastComputedAt),
      'activeGoalIds': activeGoalIds,
      'pausedGoalIds': pausedGoalIds,
      'archivedGoalIds': archivedGoalIds,
      'goalProgress': goalProgress,
      'connectedHabitIds': connectedHabitIds,
      'connectedRoutineTypes': connectedRoutineTypes,
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': schemaVersion,
    };
  }

  Map<String, dynamic> toMap() => toFirestore();

  IdentityProfileModel copyWith({
    List<String>? identities,
    int? progressPct,
    DateTime? lastComputedAt,
    List<String>? activeGoalIds,
    List<String>? pausedGoalIds,
    List<String>? archivedGoalIds,
    Map<String, int>? goalProgress,
    List<String>? connectedHabitIds,
    List<String>? connectedRoutineTypes,
    int? schemaVersion,
  }) {
    return IdentityProfileModel(
      identities: identities ?? this.identities,
      progressPct: progressPct ?? this.progressPct,
      lastComputedAt: lastComputedAt ?? this.lastComputedAt,
      activeGoalIds: activeGoalIds ?? this.activeGoalIds,
      pausedGoalIds: pausedGoalIds ?? this.pausedGoalIds,
      archivedGoalIds: archivedGoalIds ?? this.archivedGoalIds,
      goalProgress: goalProgress ?? this.goalProgress,
      connectedHabitIds: connectedHabitIds ?? this.connectedHabitIds,
      connectedRoutineTypes:
          connectedRoutineTypes ?? this.connectedRoutineTypes,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static int _progress(Object? value) {
    if (value is int) return value.clamp(0, 100);
    if (value is num) return value.round().clamp(0, 100);
    return 0;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static Map<String, int> _intMap(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, dynamic item) {
      final intValue = item is int
          ? item
          : item is num
              ? item.round()
              : 0;
      return MapEntry(key.toString(), intValue.clamp(0, 100));
    });
  }
}
