// lib/models/user_model.dart
//
// User root document per DB Schema §1A.5.
// Stored at: users/{uid}
// Mutable document — has createdAt, updatedAt, schemaVersion.

import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String? name;
  final String? timezone;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;
  final bool hasCompletedOnboarding;
  final int onboardingStep;
  final String? lastDayClosed;

  const UserModel({
    required this.id,
    required this.email,
    this.name,
    this.timezone,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
    this.hasCompletedOnboarding = false,
    this.onboardingStep = 0,
    this.lastDayClosed,
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return UserModel(
      id: data['id'] as String? ?? data['uid'] as String? ?? doc.id,
      email: data['email'] as String? ?? '',
      name: data['name'] as String? ?? data['displayName'] as String?,
      timezone: data['timezone'] as String?,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.parse(data['createdAt'] as String))
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] is Timestamp
              ? (data['updatedAt'] as Timestamp).toDate()
              : DateTime.parse(data['updatedAt'] as String))
          : DateTime.now(),
      schemaVersion: data['schemaVersion'] as int? ?? 1,
      hasCompletedOnboarding: data['hasCompletedOnboarding'] as bool? ?? false,
      onboardingStep: data['onboardingStep'] as int? ?? 0,
      lastDayClosed: data['lastDayClosed'] as String?,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String? ?? map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      name: map['name'] as String? ?? map['displayName'] as String?,
      timezone: map['timezone'] as String?,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.parse(map['createdAt'] as String))
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] is Timestamp
              ? (map['updatedAt'] as Timestamp).toDate()
              : DateTime.parse(map['updatedAt'] as String))
          : DateTime.now(),
      schemaVersion: map['schemaVersion'] as int? ?? 1,
      hasCompletedOnboarding: map['hasCompletedOnboarding'] as bool? ?? false,
      onboardingStep: map['onboardingStep'] as int? ?? 0,
      lastDayClosed: map['lastDayClosed'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'email': email,
      if (name != null) 'name': name,
      if (timezone != null) 'timezone': timezone,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': schemaVersion,
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'onboardingStep': onboardingStep,
      if (lastDayClosed != null) 'lastDayClosed': lastDayClosed,
    };
  }

  Map<String, dynamic> toMap() => toFirestore();

  UserModel copyWith({
    String? email,
    String? name,
    String? timezone,
    DateTime? updatedAt,
    bool? hasCompletedOnboarding,
    int? onboardingStep,
    String? lastDayClosed,
  }) {
    return UserModel(
      id: id,
      email: email ?? this.email,
      name: name ?? this.name,
      timezone: timezone ?? this.timezone,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      onboardingStep: onboardingStep ?? this.onboardingStep,
      lastDayClosed: lastDayClosed ?? this.lastDayClosed,
    );
  }
}
