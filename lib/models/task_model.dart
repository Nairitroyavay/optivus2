// lib/models/task_model.dart
//
// Production task model per ServiceContracts §2.4 and DB Schema §1A.5.
// Stored at: users/{uid}/tasks/{taskId}
// Mutable document — state machine: scheduled → started → completed/abandoned.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Task lifecycle states.
enum TaskState {
  scheduled,
  started,
  paused,
  completed,
  abandoned;

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
      default:
        return TaskState.scheduled;
    }
  }
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
      id: map['id'] as String,
      title: map['title'] as String,
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

  // Scheduling
  final DateTime plannedStart;
  final DateTime plannedEnd;

  // State machine
  final TaskState state;
  final DateTime? actualStart;
  final DateTime? actualEnd;
  final DateTime? pausedAt;
  final DateTime? abandonedAt;
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

  const TaskModel({
    required this.id,
    this.type = TaskType.custom,
    this.parentRoutine,
    required this.title,
    this.emoji,
    this.color,
    this.identityTags = const [],
    this.alarmTier = AlarmTier.gentle,
    required this.plannedStart,
    required this.plannedEnd,
    this.state = TaskState.scheduled,
    this.actualStart,
    this.actualEnd,
    this.pausedAt,
    this.abandonedAt,
    this.actualDurationMin,
    this.totalPauseDurationMin,
    this.driftPct,
    this.subtasks = const [],
    this.reasonTag,
    this.reasonCategory,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
  });

  /// Computed: planned duration in minutes.
  int get plannedDurationMin =>
      plannedEnd.difference(plannedStart).inMinutes;

  /// Computed: are all subtasks checked?
  bool get allSubtasksChecked =>
      subtasks.isNotEmpty && subtasks.every((s) => s.checked);

  factory TaskModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return TaskModel(
      id: d['taskId'] as String? ?? doc.id,
      type: TaskType.fromString(d['type'] as String?),
      parentRoutine: d['parentRoutine'] as String?,
      title: d['title'] as String? ?? '',
      emoji: d['emoji'] as String?,
      color: d['color'] as String?,
      identityTags:
          List<String>.from(d['identityTags'] as List? ?? []),
      alarmTier: AlarmTier.fromString(d['alarmTier'] as String?),
      plannedStart: d['plannedStart'] != null
          ? (d['plannedStart'] as Timestamp).toDate()
          : DateTime.now(),
      plannedEnd: d['plannedEnd'] != null
          ? (d['plannedEnd'] as Timestamp).toDate()
          : DateTime.now(),
      state: TaskState.fromString(d['state'] as String?),
      actualStart: d['actualStart'] != null
          ? (d['actualStart'] as Timestamp).toDate()
          : null,
      actualEnd: d['actualEnd'] != null
          ? (d['actualEnd'] as Timestamp).toDate()
          : null,
      pausedAt: d['pausedAt'] != null
          ? (d['pausedAt'] as Timestamp).toDate()
          : null,
      abandonedAt: d['abandonedAt'] != null
          ? (d['abandonedAt'] as Timestamp).toDate()
          : null,
      actualDurationMin: d['actualDurationMin'] as int?,
      totalPauseDurationMin: d['totalPauseDurationMin'] as int?,
      driftPct: (d['driftPct'] as num?)?.toDouble(),
      subtasks: (d['subtasks'] as List?)
              ?.map((s) => Subtask.fromMap(s as Map<String, dynamic>))
              .toList() ??
          [],
      reasonTag: d['reasonTag'] as String?,
      reasonCategory: d['reasonCategory'] != null
          ? AbandonReason.fromString(d['reasonCategory'] as String?)
          : null,
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: d['updatedAt'] != null
          ? (d['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      schemaVersion: d['schemaVersion'] as int? ?? 1,
    );
  }

  /// Legacy factory for backwards compatibility.
  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] as String? ?? map['taskId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      plannedStart: map['time'] != null
          ? DateTime.parse(map['time'] as String)
          : (map['plannedStart'] != null
              ? (map['plannedStart'] is Timestamp
                  ? (map['plannedStart'] as Timestamp).toDate()
                  : DateTime.parse(map['plannedStart'] as String))
              : DateTime.now()),
      plannedEnd: map['plannedEnd'] != null
          ? (map['plannedEnd'] is Timestamp
              ? (map['plannedEnd'] as Timestamp).toDate()
              : DateTime.parse(map['plannedEnd'] as String))
          : DateTime.now().add(const Duration(hours: 1)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
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
      'plannedStart': Timestamp.fromDate(plannedStart),
      'plannedEnd': Timestamp.fromDate(plannedEnd),
      'state': state.name,
      if (actualStart != null)
        'actualStart': Timestamp.fromDate(actualStart!),
      if (actualEnd != null)
        'actualEnd': Timestamp.fromDate(actualEnd!),
      if (pausedAt != null)
        'pausedAt': Timestamp.fromDate(pausedAt!),
      if (abandonedAt != null)
        'abandonedAt': Timestamp.fromDate(abandonedAt!),
      if (actualDurationMin != null) 'actualDurationMin': actualDurationMin,
      if (totalPauseDurationMin != null)
        'totalPauseDurationMin': totalPauseDurationMin,
      if (driftPct != null) 'driftPct': driftPct,
      'subtasks': subtasks.map((s) => s.toMap()).toList(),
      if (reasonTag != null) 'reasonTag': reasonTag,
      if (reasonCategory != null)
        'reasonCategory': reasonCategory!.toJson(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': schemaVersion,
    };
  }

  /// Legacy toMap for backwards compatibility.
  Map<String, dynamic> toMap() => toFirestore();

  TaskModel copyWith({
    TaskState? state,
    DateTime? actualStart,
    DateTime? actualEnd,
    DateTime? pausedAt,
    DateTime? abandonedAt,
    int? actualDurationMin,
    int? totalPauseDurationMin,
    double? driftPct,
    List<Subtask>? subtasks,
    String? reasonTag,
    AbandonReason? reasonCategory,
    DateTime? updatedAt,
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
      plannedStart: plannedStart,
      plannedEnd: plannedEnd,
      state: state ?? this.state,
      actualStart: actualStart ?? this.actualStart,
      actualEnd: actualEnd ?? this.actualEnd,
      pausedAt: pausedAt ?? this.pausedAt,
      abandonedAt: abandonedAt ?? this.abandonedAt,
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
    );
  }
}
