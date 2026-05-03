// lib/models/habit_model.dart
//
// Production habit model per ServiceContracts §3.3 and DB Schema §1A.5.
// Stored at: users/{uid}/habits/{habitId}
// Mutable document — has both createdAt and updatedAt.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Habit kind — good (want to build) or bad (want to reduce/eliminate).
enum HabitKind {
  good,
  bad;

  static HabitKind fromString(String value) =>
      value == 'bad' ? HabitKind.bad : HabitKind.good;
}

/// Bad-habit goal type.
enum BadHabitGoalType {
  /// Zero per day — streak breaks on any slip.
  eliminate,

  /// Stay under a daily target.
  reduceToTarget,

  /// No target, just track. Default for first 7 days.
  awarenessOnly;

  static BadHabitGoalType fromString(String? value) {
    switch (value) {
      case 'eliminate':
        return BadHabitGoalType.eliminate;
      case 'reduce_to_target':
        return BadHabitGoalType.reduceToTarget;
      default:
        return BadHabitGoalType.awarenessOnly;
    }
  }

  String toJson() {
    switch (this) {
      case BadHabitGoalType.eliminate:
        return 'eliminate';
      case BadHabitGoalType.reduceToTarget:
        return 'reduce_to_target';
      case BadHabitGoalType.awarenessOnly:
        return 'awareness_only';
    }
  }
}

/// Habit lifecycle state.
enum HabitState {
  active,
  paused,
  archived;

  static HabitState fromString(String? value) {
    switch (value) {
      case 'paused':
        return HabitState.paused;
      case 'archived':
        return HabitState.archived;
      default:
        return HabitState.active;
    }
  }
}

class HabitModel {
  final String id;
  final String name;
  final HabitKind kind;
  final String unit; // "ml", "min", "pages", "count", etc.
  final String
      trackerType; // water, meditation, reading, exercise, smoking, etc.

  // Good habit fields
  final num? dailyGoal;

  // Bad habit fields
  final BadHabitGoalType? goalType;
  final num? target; // for reduce_to_target
  final num? baselinePerDay;
  final num? costPerUnit;
  final String? currency;

  // Planning & support metadata
  final List<int> scheduleDays;
  final bool remindersEnabled;
  final String? reminderTime;
  final String? accountability;

  // Appearance & identity
  final List<String> identityTags;
  final String? emoji;
  final String? color;

  // State
  final HabitState state;
  final DateTime? pausedAt;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  const HabitModel({
    required this.id,
    required this.name,
    required this.kind,
    this.unit = 'count',
    this.trackerType = 'generic',
    this.dailyGoal,
    this.goalType,
    this.target,
    this.baselinePerDay,
    this.costPerUnit,
    this.currency,
    this.scheduleDays = const [],
    this.remindersEnabled = false,
    this.reminderTime,
    this.accountability,
    this.identityTags = const [],
    this.emoji,
    this.color,
    this.state = HabitState.active,
    this.pausedAt,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
  });

  /// Backwards-compatible factory that handles both old and new Firestore shapes.
  factory HabitModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return HabitModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      kind: HabitKind.fromString(data['kind'] as String? ?? 'good'),
      unit: data['unit'] as String? ?? 'count',
      trackerType: data['trackerType'] as String? ?? 'generic',
      dailyGoal: data['dailyGoal'] as num?,
      goalType: data['goalType'] != null
          ? BadHabitGoalType.fromString(data['goalType'] as String?)
          : null,
      target: data['target'] as num?,
      baselinePerDay: data['baselinePerDay'] as num?,
      costPerUnit: data['costPerUnit'] as num?,
      currency: data['currency'] as String?,
      scheduleDays: List<int>.from(data['scheduleDays'] as List? ?? []),
      remindersEnabled: data['remindersEnabled'] as bool? ?? false,
      reminderTime: data['reminderTime'] as String?,
      accountability: data['accountability'] as String?,
      identityTags: List<String>.from(data['identityTags'] as List? ?? []),
      emoji: data['emoji'] as String? ?? data['icon'] as String?,
      color: data['color'] as String?,
      state: HabitState.fromString(data['state'] as String?),
      pausedAt: _asDateTime(data['pausedAt']),
      archivedAt: _asDateTime(data['archivedAt']),
      createdAt: _asDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: _asDateTime(data['updatedAt']) ?? DateTime.now(),
      schemaVersion: data['schemaVersion'] as int? ?? 1,
    );
  }

  /// Legacy factory to avoid breaking existing code that uses fromMap.
  factory HabitModel.fromMap(Map<String, dynamic> map, String id) {
    return HabitModel(
      id: id,
      name: map['name'] as String? ?? '',
      kind: HabitKind.fromString(map['kind'] as String? ?? 'good'),
      unit: map['unit'] as String? ?? 'count',
      trackerType: map['trackerType'] as String? ??
          map['category'] as String? ??
          'generic',
      dailyGoal: map['dailyGoal'] as num?,
      goalType: map['goalType'] != null
          ? BadHabitGoalType.fromString(map['goalType'] as String?)
          : null,
      target: map['target'] as num?,
      baselinePerDay: map['baselinePerDay'] as num?,
      costPerUnit: map['costPerUnit'] as num?,
      currency: map['currency'] as String?,
      scheduleDays: List<int>.from(map['scheduleDays'] as List? ?? []),
      remindersEnabled: map['remindersEnabled'] as bool? ?? false,
      reminderTime: map['reminderTime'] as String?,
      accountability: map['accountability'] as String?,
      identityTags: List<String>.from(map['identityTags'] as List? ?? []),
      emoji: map['emoji'] as String? ?? map['icon'] as String?,
      color: map['color'] as String?,
      state: HabitState.fromString(map['state'] as String?),
      pausedAt: _asDateTime(map['pausedAt']),
      archivedAt: _asDateTime(map['archivedAt']),
      createdAt: _asDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _asDateTime(map['updatedAt']) ?? DateTime.now(),
      schemaVersion: map['schemaVersion'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'habitId': id,
      'name': name,
      'kind': kind.name,
      'unit': unit,
      'trackerType': trackerType,
      if (dailyGoal != null) 'dailyGoal': dailyGoal,
      if (goalType != null) 'goalType': goalType!.toJson(),
      if (target != null) 'target': target,
      if (baselinePerDay != null) 'baselinePerDay': baselinePerDay,
      if (costPerUnit != null) 'costPerUnit': costPerUnit,
      if (currency != null) 'currency': currency,
      'scheduleDays': scheduleDays,
      'remindersEnabled': remindersEnabled,
      if (reminderTime != null) 'reminderTime': reminderTime,
      if (accountability != null) 'accountability': accountability,
      'identityTags': identityTags,
      if (emoji != null) 'emoji': emoji,
      if (color != null) 'color': color,
      'state': state.name,
      if (pausedAt != null) 'pausedAt': Timestamp.fromDate(pausedAt!),
      if (archivedAt != null) 'archivedAt': Timestamp.fromDate(archivedAt!),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': schemaVersion,
    };
  }

  /// Legacy toMap for backwards compatibility.
  Map<String, dynamic> toMap() => toFirestore();

  HabitModel copyWith({
    String? name,
    HabitKind? kind,
    String? unit,
    String? trackerType,
    num? dailyGoal,
    BadHabitGoalType? goalType,
    num? target,
    num? baselinePerDay,
    num? costPerUnit,
    String? currency,
    List<int>? scheduleDays,
    bool? remindersEnabled,
    String? reminderTime,
    String? accountability,
    List<String>? identityTags,
    String? emoji,
    String? color,
    HabitState? state,
    DateTime? pausedAt,
    bool clearPausedAt = false,
    DateTime? archivedAt,
    DateTime? updatedAt,
  }) {
    return HabitModel(
      id: id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      unit: unit ?? this.unit,
      trackerType: trackerType ?? this.trackerType,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      goalType: goalType ?? this.goalType,
      target: target ?? this.target,
      baselinePerDay: baselinePerDay ?? this.baselinePerDay,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      currency: currency ?? this.currency,
      scheduleDays: scheduleDays ?? this.scheduleDays,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      accountability: accountability ?? this.accountability,
      identityTags: identityTags ?? this.identityTags,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      state: state ?? this.state,
      pausedAt: clearPausedAt ? null : pausedAt ?? this.pausedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion,
    );
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
