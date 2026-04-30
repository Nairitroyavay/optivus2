// lib/models/goal_model.dart
//
// Goal model per DB Schema §1A.5.
// Stored at: users/{uid}/goals/{goalId}
// Mutable document — has createdAt, updatedAt, schemaVersion.

import 'package:cloud_firestore/cloud_firestore.dart';

class GoalModel {
  final String id;
  final String title;
  final String? description;
  final bool isCompleted;
  final int progressPct;
  final List<String> identityTags;
  final List<String> milestones;
  final DateTime? targetDate;
  final DateTime? lastComputedAt;
  final String? colorHex;
  final String? iconName;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  const GoalModel({
    required this.id,
    required this.title,
    this.description,
    this.isCompleted = false,
    this.progressPct = 0,
    this.identityTags = const [],
    this.milestones = const [],
    this.targetDate,
    this.lastComputedAt,
    this.colorHex,
    this.iconName,
    this.source = 'manual',
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
  });

  factory GoalModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return GoalModel(
      id: data['id'] as String? ?? doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      isCompleted: data['isCompleted'] as bool? ?? false,
      progressPct: _asProgressPct(data['progressPct']),
      identityTags: List<String>.from(data['identityTags'] as List? ?? []),
      milestones: List<String>.from(data['milestones'] as List? ?? []),
      targetDate: _asDateTime(data['targetDate']),
      lastComputedAt: _asDateTime(data['lastComputedAt']),
      colorHex: data['colorHex'] as String?,
      iconName: data['iconName'] as String?,
      source: data['source'] as String? ?? 'manual',
      createdAt: _asDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: _asDateTime(data['updatedAt']) ?? DateTime.now(),
      schemaVersion: data['schemaVersion'] as int? ?? 1,
    );
  }

  factory GoalModel.fromMap(Map<String, dynamic> map) {
    return GoalModel(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      isCompleted: map['isCompleted'] as bool? ?? false,
      progressPct: _asProgressPct(map['progressPct']),
      identityTags: List<String>.from(map['identityTags'] as List? ?? []),
      milestones: List<String>.from(map['milestones'] as List? ?? []),
      targetDate: _asDateTime(map['targetDate']),
      lastComputedAt: _asDateTime(map['lastComputedAt']),
      colorHex: map['colorHex'] as String?,
      iconName: map['iconName'] as String?,
      source: map['source'] as String? ?? 'manual',
      createdAt: _asDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _asDateTime(map['updatedAt']) ?? DateTime.now(),
      schemaVersion: map['schemaVersion'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      if (description != null) 'description': description,
      'isCompleted': isCompleted,
      'progressPct': progressPct,
      'identityTags': identityTags,
      'milestones': milestones,
      if (targetDate != null) 'targetDate': Timestamp.fromDate(targetDate!),
      if (lastComputedAt != null)
        'lastComputedAt': Timestamp.fromDate(lastComputedAt!),
      if (colorHex != null) 'colorHex': colorHex,
      if (iconName != null) 'iconName': iconName,
      'source': source,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': schemaVersion,
    };
  }

  Map<String, dynamic> toMap() => toFirestore();

  GoalModel copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    int? progressPct,
    List<String>? identityTags,
    List<String>? milestones,
    DateTime? targetDate,
    DateTime? lastComputedAt,
    String? colorHex,
    String? iconName,
    String? source,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? schemaVersion,
  }) {
    return GoalModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      progressPct: progressPct ?? this.progressPct,
      identityTags: identityTags ?? this.identityTags,
      milestones: milestones ?? this.milestones,
      targetDate: targetDate ?? this.targetDate,
      lastComputedAt: lastComputedAt ?? this.lastComputedAt,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName ?? this.iconName,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static int _asProgressPct(Object? value) {
    if (value is int) return value.clamp(0, 100);
    if (value is num) return value.round().clamp(0, 100);
    return 0;
  }
}
