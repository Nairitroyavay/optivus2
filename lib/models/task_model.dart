// lib/models/task_model.dart
//
// Production task model per ServiceContracts §2.4 and DB Schema §1A.5.
// Stored at: users/{uid}/tasks/{taskId}
// Mutable document — state machine: scheduled → started → completed/abandoned.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Task lifecycle states.
///
/// State machine:
///   scheduled → started → paused/resumed → completed
///   scheduled → skipped
///   started/paused → abandoned
///   completed, skipped, abandoned are terminal.
enum TaskState {
  scheduled,
  started,
  paused,
  completed,
  abandoned,
  skipped;

  static TaskState fromString(String? value) {
    switch (value) {
      case 'started':
        return TaskState.started;
      case 'paused':
        return TaskState.paused;
      case 'completed':
        return TaskState.completed;
      case 'abandoned':
        return TaskState.abandoned;
      case 'skipped':
      case 'cancelled':
        // Legacy/interop value. Keep the public enum stable while preserving
        // terminal behavior so cancelled docs are never treated as scheduled.
        return TaskState.skipped;
      default:
        return TaskState.scheduled;
    }
  }

  /// Serialises to the snake_case string stored in Firestore and events.
  String toJson() => name;

  bool get isTerminal =>
      this == TaskState.completed ||
      this == TaskState.abandoned ||
      this == TaskState.skipped;
}

/// Task type — which routine category this block belongs to.
enum TaskType {
  skinCare,
  eating,
  classBlock,
  fixed,
  custom,
  habitBlock;

  static TaskType fromString(String? value) {
    switch (value) {
      case 'skin_care':
        return TaskType.skinCare;
      case 'eating':
        return TaskType.eating;
      case 'class':
        return TaskType.classBlock;
      case 'fixed':
        return TaskType.fixed;
      case 'habit_block':
        return TaskType.habitBlock;
      default:
        return TaskType.custom;
    }
  }

  String toJson() {
    switch (this) {
      case TaskType.skinCare:
        return 'skin_care';
      case TaskType.eating:
        return 'eating';
      case TaskType.classBlock:
        return 'class';
      case TaskType.fixed:
        return 'fixed';
      case TaskType.custom:
        return 'custom';
      case TaskType.habitBlock:
        return 'habit_block';
    }
  }
}

/// Alarm intensity for task reminders.
enum AlarmTier {
  gentle,
  active,
  custom;

  static AlarmTier fromString(String? value) {
    switch (value) {
      case 'active':
        return AlarmTier.active;
      case 'custom':
        return AlarmTier.custom;
      default:
        return AlarmTier.gentle;
    }
  }
}

/// Reason a task was abandoned.
enum AbandonReason {
  userSkipped,
  autoIdle,
  autoNoStart;

  static AbandonReason fromString(String? value) {
    switch (value) {
      case 'auto_idle':
        return AbandonReason.autoIdle;
      case 'auto_no_start':
        return AbandonReason.autoNoStart;
      default:
        return AbandonReason.userSkipped;
    }
  }

  String toJson() {
    switch (this) {
      case AbandonReason.userSkipped:
        return 'user_skipped';
      case AbandonReason.autoIdle:
        return 'auto_idle';
      case AbandonReason.autoNoStart:
        return 'auto_no_start';
    }
  }
}

/// A subtask within a task.
class Subtask {
  final String id;
  final String title;
  final bool checked;

  const Subtask({
    required this.id,
    required this.title,
    this.checked = false,
  });

  factory Subtask.fromMap(Map<String, dynamic> map) {
    return Subtask(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      checked: map['checked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'checked': checked,
      };

  Subtask copyWith({bool? checked}) =>
      Subtask(id: id, title: title, checked: checked ?? this.checked);
}

class TaskModel {
  final String id;
  final TaskType type;
  final String? parentRoutine;
  final String title;
  final String? emoji;
  final String? color;
  final List<String> identityTags;
  final AlarmTier alarmTier;
  final String alarmSound;
  final String alarmSoundAsset;
  final bool alarmVoiceEnabled;
  final String alarmCoachVoiceAsset;
  final String alarmVibrationPattern;
  final List<int> alarmSnoozeDurations;

  // Scheduling
  final DateTime plannedStart;
  final DateTime plannedEnd;

  // State machine
  final TaskState state;
  final DateTime? actualStart;
  final DateTime? actualEnd;
  final DateTime? pausedAt;
  final DateTime? abandonedAt;
  final DateTime? skippedAt;
  final int? actualDurationMin;
  final int? totalPauseDurationMin;
  final double? driftPct;

  // Subtasks
  final List<Subtask> subtasks;

  // Abandonment metadata
  final String? reasonTag;
  final AbandonReason? reasonCategory;

  // Timestamps & versioning
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  // Fitness-routine linking
  final String? fitnessActivityId;

  const TaskModel({
    required this.id,
    this.type = TaskType.custom,
    this.parentRoutine,
    required this.title,
    this.emoji,
    this.color,
    this.identityTags = const [],
    this.alarmTier = AlarmTier.gentle,
    this.alarmSound = 'steady',
    this.alarmSoundAsset =
        'assets/audio/ambient_atmospheric/ambient_atmospheric_01.mp3',
    this.alarmVoiceEnabled = true,
    this.alarmCoachVoiceAsset =
        'assets/audio/healing_432hz/healing_432hz_01.mp3',
    this.alarmVibrationPattern = 'standard',
    this.alarmSnoozeDurations = const [5, 10],
    required this.plannedStart,
    required this.plannedEnd,
    this.state = TaskState.scheduled,
    this.actualStart,
    this.actualEnd,
    this.pausedAt,
    this.abandonedAt,
    this.skippedAt,
    this.actualDurationMin,
    this.totalPauseDurationMin,
    this.driftPct,
    this.subtasks = const [],
    this.reasonTag,
    this.reasonCategory,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
    this.fitnessActivityId,
  });

  /// Computed: planned duration in minutes.
  int get plannedDurationMin => plannedEnd.difference(plannedStart).inMinutes;

  /// Computed: are all subtasks checked?
  bool get allSubtasksChecked =>
      subtasks.isNotEmpty && subtasks.every((s) => s.checked);

  factory TaskModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return TaskModel(
      id: d['taskId'] as String? ?? doc.id,
      type: TaskType.fromString(d['type'] as String?),
      parentRoutine: d['parentRoutine'] as String?,
      title: d['title'] as String? ?? '',
      emoji: d['emoji'] as String?,
      color: d['color'] as String?,
      identityTags: List<String>.from(d['identityTags'] as List? ?? []),
      alarmTier: AlarmTier.fromString(d['alarmTier'] as String?),
      alarmSound:
          d['alarmSound'] as String? ?? d['sound'] as String? ?? 'steady',
      alarmSoundAsset: d['alarmSoundAsset'] as String? ??
          d['soundAsset'] as String? ??
          'assets/audio/ambient_atmospheric/ambient_atmospheric_01.mp3',
      alarmVoiceEnabled: d['alarmVoiceEnabled'] as bool? ??
          d['coachVoiceEnabled'] as bool? ??
          true,
      alarmCoachVoiceAsset: d['alarmCoachVoiceAsset'] as String? ??
          d['coachVoiceAsset'] as String? ??
          'assets/audio/healing_432hz/healing_432hz_01.mp3',
      alarmVibrationPattern: d['alarmVibrationPattern'] as String? ??
          d['vibrationPattern'] as String? ??
          'standard',
      alarmSnoozeDurations: _asIntList(
        d['alarmSnoozeDurations'] ?? d['snoozeDurations'],
      ),
      plannedStart: _asDateTime(d['plannedStart']) ?? DateTime.now(),
      plannedEnd: _asDateTime(d['plannedEnd']) ?? DateTime.now(),
      state: TaskState.fromString(
        (d['state'] as String?) ?? (d['status'] as String?),
      ),
      actualStart: _asDateTime(d['actualStart']),
      actualEnd: _asDateTime(d['actualEnd']),
      pausedAt: _asDateTime(d['pausedAt']),
      abandonedAt: _asDateTime(d['abandonedAt']),
      skippedAt: _asDateTime(d['skippedAt']),
      actualDurationMin: d['actualDurationMin'] as int?,
      totalPauseDurationMin: d['totalPauseDurationMin'] as int?,
      driftPct: (d['driftPct'] as num?)?.toDouble(),
      subtasks: (d['subtasks'] as List?)
              ?.map((s) => Subtask.fromMap(Map<String, dynamic>.from(s as Map)))
              .toList() ??
          [],
      reasonTag: d['reasonTag'] as String?,
      reasonCategory: d['reasonCategory'] != null
          ? AbandonReason.fromString(d['reasonCategory'] as String?)
          : null,
      createdAt: _asDateTime(d['createdAt']) ?? DateTime.now(),
      updatedAt: _asDateTime(d['updatedAt']) ?? DateTime.now(),
      schemaVersion: d['schemaVersion'] as int? ?? 1,
      fitnessActivityId: d['fitnessActivityId'] as String?,
    );
  }

  /// Legacy factory for backwards compatibility.
  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] as String? ?? map['taskId'] as String? ?? '',
      type: TaskType.fromString(map['type'] as String?),
      parentRoutine: map['parentRoutine'] as String?,
      title: map['title'] as String? ?? '',
      emoji: map['emoji'] as String?,
      color: map['color'] as String?,
      identityTags: List<String>.from(map['identityTags'] as List? ?? []),
      alarmTier: AlarmTier.fromString(map['alarmTier'] as String?),
      alarmSound:
          map['alarmSound'] as String? ?? map['sound'] as String? ?? 'steady',
      alarmSoundAsset: map['alarmSoundAsset'] as String? ??
          map['soundAsset'] as String? ??
          'assets/audio/ambient_atmospheric/ambient_atmospheric_01.mp3',
      alarmVoiceEnabled: map['alarmVoiceEnabled'] as bool? ??
          map['coachVoiceEnabled'] as bool? ??
          true,
      alarmCoachVoiceAsset: map['alarmCoachVoiceAsset'] as String? ??
          map['coachVoiceAsset'] as String? ??
          'assets/audio/healing_432hz/healing_432hz_01.mp3',
      alarmVibrationPattern: map['alarmVibrationPattern'] as String? ??
          map['vibrationPattern'] as String? ??
          'standard',
      alarmSnoozeDurations: _asIntList(
        map['alarmSnoozeDurations'] ?? map['snoozeDurations'],
      ),
      plannedStart: map['time'] != null
          ? (_asDateTime(map['time']) ?? DateTime.now())
          : (_asDateTime(map['plannedStart']) ?? DateTime.now()),
      plannedEnd: _asDateTime(map['plannedEnd']) ??
          DateTime.now().add(const Duration(hours: 1)),
      state: TaskState.fromString(
        (map['state'] as String?) ?? (map['status'] as String?),
      ),
      actualStart: _asDateTime(map['actualStart']),
      actualEnd: _asDateTime(map['actualEnd']),
      pausedAt: _asDateTime(map['pausedAt']),
      abandonedAt: _asDateTime(map['abandonedAt']),
      skippedAt: _asDateTime(map['skippedAt']),
      actualDurationMin: map['actualDurationMin'] as int?,
      totalPauseDurationMin: map['totalPauseDurationMin'] as int?,
      driftPct: (map['driftPct'] as num?)?.toDouble(),
      subtasks: (map['subtasks'] as List?)
              ?.map((s) => Subtask.fromMap(Map<String, dynamic>.from(s as Map)))
              .toList() ??
          const [],
      reasonTag: map['reasonTag'] as String?,
      reasonCategory: map['reasonCategory'] != null
          ? AbandonReason.fromString(map['reasonCategory'] as String?)
          : null,
      createdAt: _asDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _asDateTime(map['updatedAt']) ?? DateTime.now(),
      schemaVersion: map['schemaVersion'] as int? ?? 1,
      fitnessActivityId: map['fitnessActivityId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'taskId': id,
      'type': type.toJson(),
      if (parentRoutine != null) 'parentRoutine': parentRoutine,
      'title': title,
      if (emoji != null) 'emoji': emoji,
      if (color != null) 'color': color,
      'identityTags': identityTags,
      'alarmTier': alarmTier.name,
      'alarmSound': alarmSound,
      'alarmSoundAsset': alarmSoundAsset,
      'alarmVoiceEnabled': alarmVoiceEnabled,
      'alarmCoachVoiceAsset': alarmCoachVoiceAsset,
      'alarmVibrationPattern': alarmVibrationPattern,
      'alarmSnoozeDurations': alarmSnoozeDurations,
      'plannedStart': Timestamp.fromDate(plannedStart),
      'plannedEnd': Timestamp.fromDate(plannedEnd),
      'state': state.toJson(),
      'status': state.toJson(),
      if (actualStart != null) 'actualStart': Timestamp.fromDate(actualStart!),
      if (actualEnd != null) 'actualEnd': Timestamp.fromDate(actualEnd!),
      if (pausedAt != null) 'pausedAt': Timestamp.fromDate(pausedAt!),
      if (abandonedAt != null) 'abandonedAt': Timestamp.fromDate(abandonedAt!),
      if (skippedAt != null) 'skippedAt': Timestamp.fromDate(skippedAt!),
      if (actualDurationMin != null) 'actualDurationMin': actualDurationMin,
      if (totalPauseDurationMin != null)
        'totalPauseDurationMin': totalPauseDurationMin,
      if (driftPct != null) 'driftPct': driftPct,
      'subtasks': subtasks.map((s) => s.toMap()).toList(),
      if (reasonTag != null) 'reasonTag': reasonTag,
      if (reasonCategory != null) 'reasonCategory': reasonCategory!.toJson(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': schemaVersion,
      if (fitnessActivityId != null) 'fitnessActivityId': fitnessActivityId,
    };
  }

  /// Legacy toMap for backwards compatibility.
  Map<String, dynamic> toMap() => toFirestore();

  TaskModel copyWith({
    TaskState? state,
    DateTime? actualStart,
    DateTime? actualEnd,

    /// Pass [clearPausedAt] = true to set pausedAt to null.
    bool clearPausedAt = false,
    DateTime? pausedAt,

    /// Pass [clearAbandonedAt] = true to set abandonedAt to null.
    bool clearAbandonedAt = false,
    DateTime? abandonedAt,

    /// Pass [clearSkippedAt] = true to set skippedAt to null.
    bool clearSkippedAt = false,
    DateTime? skippedAt,
    int? actualDurationMin,
    int? totalPauseDurationMin,
    double? driftPct,
    List<Subtask>? subtasks,
    String? reasonTag,
    AbandonReason? reasonCategory,
    DateTime? updatedAt,
    String? fitnessActivityId,
  }) {
    return TaskModel(
      id: id,
      type: type,
      parentRoutine: parentRoutine,
      title: title,
      emoji: emoji,
      color: color,
      identityTags: identityTags,
      alarmTier: alarmTier,
      alarmSound: alarmSound,
      alarmSoundAsset: alarmSoundAsset,
      alarmVoiceEnabled: alarmVoiceEnabled,
      alarmCoachVoiceAsset: alarmCoachVoiceAsset,
      alarmVibrationPattern: alarmVibrationPattern,
      alarmSnoozeDurations: alarmSnoozeDurations,
      plannedStart: plannedStart,
      plannedEnd: plannedEnd,
      state: state ?? this.state,
      actualStart: actualStart ?? this.actualStart,
      actualEnd: actualEnd ?? this.actualEnd,
      pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
      abandonedAt: clearAbandonedAt ? null : (abandonedAt ?? this.abandonedAt),
      skippedAt: clearSkippedAt ? null : (skippedAt ?? this.skippedAt),
      actualDurationMin: actualDurationMin ?? this.actualDurationMin,
      totalPauseDurationMin:
          totalPauseDurationMin ?? this.totalPauseDurationMin,
      driftPct: driftPct ?? this.driftPct,
      subtasks: subtasks ?? this.subtasks,
      reasonTag: reasonTag ?? this.reasonTag,
      reasonCategory: reasonCategory ?? this.reasonCategory,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion,
      fitnessActivityId: fitnessActivityId ?? this.fitnessActivityId,
    );
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static List<int> _asIntList(Object? value) {
    if (value is! List) return const [5, 10];
    final values = value
        .whereType<Object>()
        .map((item) {
          if (item is int) return item;
          if (item is num) return item.round();
          return int.tryParse(item.toString()) ?? 0;
        })
        .where((item) => item > 0)
        .toSet()
        .toList()
      ..sort();
    return values.isEmpty ? const [5] : values;
  }
}

/// Generates a deterministic Firestore document ID for a materialized routine block.
/// Example: routine_2026-05-13_fixed_schedule_tpl123_0900_1000
String buildRoutineInstanceKey({
  required String scheduledDate,
  required String sourceRoutineType,
  required String templateId,
  required String title,
  required DateTime plannedStart,
  required DateTime plannedEnd,
}) {
  final slugType = sourceRoutineType
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final cleanType = slugType.isEmpty ? 'task' : slugType;

  final slugTitle = title
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final cleanTemplateId = templateId
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  // If templateId is missing/empty, fallback to normalized title.
  final fallbackId = cleanTemplateId.isNotEmpty
      ? cleanTemplateId
      : (slugTitle.isNotEmpty ? slugTitle : 'template');

  final startStr =
      '${plannedStart.hour.toString().padLeft(2, '0')}${plannedStart.minute.toString().padLeft(2, '0')}';
  final endStr =
      '${plannedEnd.hour.toString().padLeft(2, '0')}${plannedEnd.minute.toString().padLeft(2, '0')}';

  return 'routine_${scheduledDate}_${cleanType}_${fallbackId}_${startStr}_$endStr';
}
