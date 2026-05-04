// lib/models/goal_model.dart
//
// Goal model stored at: /users/{uid}/goals/{goalId}

import 'package:cloud_firestore/cloud_firestore.dart';

abstract final class GoalStatus {
  static const active = 'active';
  static const paused = 'paused';
  static const archived = 'archived';
  static const completed = 'completed';

  static const values = {active, paused, archived, completed};

  static String normalize(String? value) {
    if (value == null || value.trim().isEmpty) return active;
    final normalized = value.trim().toLowerCase();
    return values.contains(normalized) ? normalized : active;
  }
}

class GoalMilestone {
  final String milestoneId;
  final String title;
  final bool completed;
  final DateTime? completedAt;

  const GoalMilestone({
    required this.milestoneId,
    required this.title,
    this.completed = false,
    this.completedAt,
  });

  factory GoalMilestone.fromMap(Map<String, dynamic> map) {
    return GoalMilestone(
      milestoneId: map['milestoneId'] as String? ?? map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      completed: map['completed'] as bool? ?? false,
      completedAt: _asDateTime(map['completedAt']),
    );
  }

  factory GoalMilestone.fromLegacyString(String title) {
    return GoalMilestone(
      milestoneId: _slug(title).isEmpty ? 'milestone' : _slug(title),
      title: title,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'milestoneId': milestoneId,
      'title': title,
      'completed': completed,
      'completedAt':
          completedAt == null ? null : Timestamp.fromDate(completedAt!),
    };
  }
}

class GoalModel {
  final String goalId;
  final String title;
  final String identityTag;
  final String why;
  final String status;
  final int weight;
  final int progress;
  final DateTime? targetDate;
  final List<GoalMilestone> milestones;
  final List<String> connectedHabitIds;
  final List<String> connectedRoutineTypes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  GoalModel({
    String? goalId,
    String? id,
    required this.title,
    String? identityTag,
    String? why,
    String? status,
    int? weight,
    int? progress,
    this.targetDate,
    List<GoalMilestone> milestones = const [],
    List<String> connectedHabitIds = const [],
    List<String> connectedRoutineTypes = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
    this.archivedAt,
    String? description,
    bool? isCompleted,
    int? progressPct,
    List<String>? identityTags,
    DateTime? lastComputedAt,
    String? colorHex,
    String? iconName,
    String? source,
    int? schemaVersion,
  })  : goalId = goalId ?? id ?? '',
        identityTag = _cleanString(
          identityTag ??
              (identityTags == null || identityTags.isEmpty
                  ? null
                  : identityTags.first),
        ),
        why = why ?? description ?? '',
        status = GoalStatus.normalize(
          status ??
              ((isCompleted ?? false)
                  ? GoalStatus.completed
                  : GoalStatus.active),
        ),
        weight = _asPositiveInt(weight, fallback: 1),
        progress = _asProgress(progress ?? progressPct),
        milestones = List.unmodifiable(milestones),
        connectedHabitIds =
            List.unmodifiable(_cleanStringList(connectedHabitIds)),
        connectedRoutineTypes =
            List.unmodifiable(_cleanStringList(connectedRoutineTypes)),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? lastComputedAt ?? DateTime.now();

  factory GoalModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return GoalModel.fromMap(data, fallbackId: doc.id);
  }

  factory GoalModel.fromMap(
    Map<String, dynamic> map, {
    String fallbackId = '',
  }) {
    final legacyIdentityTags = _cleanStringList(map['identityTags']);
    final identityTag = map['identityTag'] as String? ??
        (legacyIdentityTags.isEmpty ? null : legacyIdentityTags.first);

    return GoalModel(
      goalId: map['goalId'] as String? ?? map['id'] as String? ?? fallbackId,
      title: map['title'] as String? ?? '',
      identityTag: identityTag,
      why: map['why'] as String? ?? map['description'] as String? ?? '',
      status: map['status'] as String? ??
          ((map['isCompleted'] as bool? ?? false)
              ? GoalStatus.completed
              : GoalStatus.active),
      weight: _asPositiveInt(map['weight'], fallback: 1),
      progress: _asProgress(map['progress'] ?? map['progressPct']),
      targetDate: _asDateTime(map['targetDate']),
      milestones: _asMilestones(map['milestones']),
      connectedHabitIds: _cleanStringList(map['connectedHabitIds']),
      connectedRoutineTypes: _cleanStringList(map['connectedRoutineTypes']),
      createdAt: _asDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _asDateTime(map['updatedAt']) ??
          _asDateTime(map['lastComputedAt']) ??
          DateTime.now(),
      archivedAt: _asDateTime(map['archivedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'goalId': goalId,
      'title': title,
      'identityTag': identityTag,
      'why': why,
      'status': status,
      'weight': weight,
      'progress': progress,
      'targetDate': targetDate == null ? null : Timestamp.fromDate(targetDate!),
      'milestones':
          milestones.map((milestone) => milestone.toFirestore()).toList(),
      'connectedHabitIds': connectedHabitIds,
      'connectedRoutineTypes': connectedRoutineTypes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'archivedAt': archivedAt == null ? null : Timestamp.fromDate(archivedAt!),
    };
  }

  Map<String, dynamic> toMap() => toFirestore();

  GoalModel copyWith({
    String? goalId,
    String? id,
    String? title,
    String? identityTag,
    String? why,
    String? status,
    int? weight,
    int? progress,
    DateTime? targetDate,
    List<GoalMilestone>? milestones,
    List<String>? connectedHabitIds,
    List<String>? connectedRoutineTypes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? archivedAt,
    String? description,
    bool? isCompleted,
    int? progressPct,
    List<String>? identityTags,
    DateTime? lastComputedAt,
    String? colorHex,
    String? iconName,
    String? source,
    int? schemaVersion,
  }) {
    return GoalModel(
      goalId: goalId ?? id ?? this.goalId,
      title: title ?? this.title,
      identityTag: identityTag ??
          (identityTags == null || identityTags.isEmpty
              ? this.identityTag
              : identityTags.first),
      why: why ?? description ?? this.why,
      status: status ??
          (isCompleted == null
              ? this.status
              : (isCompleted ? GoalStatus.completed : GoalStatus.active)),
      weight: weight ?? this.weight,
      progress: progress ?? progressPct ?? this.progress,
      targetDate: targetDate ?? this.targetDate,
      milestones: milestones ?? this.milestones,
      connectedHabitIds: connectedHabitIds ?? this.connectedHabitIds,
      connectedRoutineTypes:
          connectedRoutineTypes ?? this.connectedRoutineTypes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? lastComputedAt ?? this.updatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  // Backwards-compatible accessors used by existing UI and older services.
  String get id => goalId;
  String? get description => why.isEmpty ? null : why;
  bool get isCompleted => status == GoalStatus.completed || progress >= 100;
  int get progressPct => progress;
  List<String> get identityTags =>
      identityTag.isEmpty ? const [] : <String>[identityTag];
  DateTime? get lastComputedAt => updatedAt;
  String? get colorHex => _defaultGoalColor(title);
  String? get iconName => _defaultGoalIcon(title);
  String get source => 'identity';
  int get schemaVersion => 3;
}

DateTime? _asDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

int _asProgress(Object? value) {
  if (value is int) return value.clamp(0, 100);
  if (value is num) return value.round().clamp(0, 100);
  return 0;
}

int _asPositiveInt(Object? value, {required int fallback}) {
  if (value is int && value > 0) return value;
  if (value is num && value > 0) return value.round();
  return fallback;
}

String _cleanString(String? value) => value?.trim() ?? '';

List<String> _cleanStringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

List<GoalMilestone> _asMilestones(Object? value) {
  if (value is! List) return const [];
  return value.map((item) {
    if (item is Map) {
      return GoalMilestone.fromMap(Map<String, dynamic>.from(item));
    }
    return GoalMilestone.fromLegacyString(item.toString());
  }).toList();
}

String _slug(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

String _defaultGoalColor(String title) {
  final text = title.toLowerCase();
  if (_matchesAny(text, const ['gym', 'fitness', 'health', 'run'])) {
    return '#22C55E';
  }
  if (_matchesAny(text, const ['study', 'learn', 'read', 'class', 'exam'])) {
    return '#3B82F6';
  }
  if (_matchesAny(text, const ['quit', 'reduce', 'stop', 'smoking'])) {
    return '#F97316';
  }
  return '#14B8A6';
}

String _defaultGoalIcon(String title) {
  final text = title.toLowerCase();
  if (_matchesAny(text, const ['study', 'learn', 'read', 'class', 'exam'])) {
    return 'menu_book_rounded';
  }
  if (_matchesAny(text, const ['gym', 'fitness', 'health', 'run'])) {
    return 'directions_run_rounded';
  }
  if (_matchesAny(text, const ['quit', 'reduce', 'stop', 'smoking'])) {
    return 'local_fire_department_rounded';
  }
  return 'flag_rounded';
}

bool _matchesAny(String text, List<String> terms) {
  for (final term in terms) {
    if (text.contains(term)) return true;
  }
  return false;
}
