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
  final List<String> identityTags;
  final List<String> milestones;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  const GoalModel({
    required this.id,
    required this.title,
    this.description,
    this.isCompleted = false,
    this.identityTags = const [],
    this.milestones = const [],
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
  });

  factory GoalModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return GoalModel(
      id: data['id'] as String? ?? doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      isCompleted: data['isCompleted'] as bool? ?? false,
      identityTags: List<String>.from(data['identityTags'] as List? ?? []),
      milestones: List<String>.from(data['milestones'] as List? ?? []),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now())
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] is Timestamp
              ? (data['updatedAt'] as Timestamp).toDate()
              : DateTime.now())
          : DateTime.now(),
      schemaVersion: data['schemaVersion'] as int? ?? 1,
    );
  }

  factory GoalModel.fromMap(Map<String, dynamic> map) {
    return GoalModel(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      isCompleted: map['isCompleted'] as bool? ?? false,
      identityTags:
          List<String>.from(map['identityTags'] as List? ?? []),
      milestones:
          List<String>.from(map['milestones'] as List? ?? []),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.now())
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] is Timestamp
              ? (map['updatedAt'] as Timestamp).toDate()
              : DateTime.now())
          : DateTime.now(),
      schemaVersion: map['schemaVersion'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      if (description != null) 'description': description,
      'isCompleted': isCompleted,
      'identityTags': identityTags,
      'milestones': milestones,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': schemaVersion,
    };
  }

  Map<String, dynamic> toMap() => toFirestore();
}
