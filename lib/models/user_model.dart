// lib/models/user_model.dart
//
// User root document per DB Schema §1A.5.
// Stored at: users/{uid}
// Mutable document — has createdAt, updatedAt, schemaVersion.

import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationSettings {
  final bool dailyBrief;
  final bool streakAlerts;
  final bool coachNudges;
  final bool weeklyReview;

  const NotificationSettings({
    this.dailyBrief = true,
    this.streakAlerts = true,
    this.coachNudges = true,
    this.weeklyReview = true,
  });

  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    return NotificationSettings(
      dailyBrief: map['dailyBrief'] as bool? ?? true,
      streakAlerts: map['streakAlerts'] as bool? ?? true,
      coachNudges: map['coachNudges'] as bool? ?? true,
      weeklyReview: map['weeklyReview'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'dailyBrief': dailyBrief,
        'streakAlerts': streakAlerts,
        'coachNudges': coachNudges,
        'weeklyReview': weeklyReview,
      };

  NotificationSettings copyWith({
    bool? dailyBrief,
    bool? streakAlerts,
    bool? coachNudges,
    bool? weeklyReview,
  }) {
    return NotificationSettings(
      dailyBrief: dailyBrief ?? this.dailyBrief,
      streakAlerts: streakAlerts ?? this.streakAlerts,
      coachNudges: coachNudges ?? this.coachNudges,
      weeklyReview: weeklyReview ?? this.weeklyReview,
    );
  }
}

class UserModel {
  final String id;

  /// Canonical UID alias stored in the document (= Firestore doc.id).
  String get uid => id;

  final String email;

  /// Human-readable display name (used in UI and Firebase Auth profile).
  final String? displayName;

  /// Legacy alias — prefer [displayName]. Kept for backwards compat.
  String? get name => displayName;

  final String? timezone;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;
  final bool hasCompletedOnboarding;
  final int onboardingStep;
  final String? lastDayClosed;

  // ── Coach identity ──────────────────────────────────────────────────────
  final String? coachName;
  final String? coachStyle;
  final String? accountabilityMode;

  // ── Notification preferences ────────────────────────────────────────────
  final NotificationSettings notificationSettings;

  const UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.timezone,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
    this.hasCompletedOnboarding = false,
    this.onboardingStep = 0,
    this.lastDayClosed,
    this.coachName,
    this.coachStyle,
    this.accountabilityMode,
    this.notificationSettings = const NotificationSettings(),
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return UserModel(
      id: data['uid'] as String? ?? data['id'] as String? ?? doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? data['name'] as String?,
      timezone: data['timezone'] as String?,
      createdAt: _asDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: _asDateTime(data['updatedAt']) ?? DateTime.now(),
      schemaVersion: data['schemaVersion'] as int? ?? 1,
      hasCompletedOnboarding: data['hasCompletedOnboarding'] as bool? ?? false,
      onboardingStep: data['onboardingStep'] as int? ?? 0,
      lastDayClosed: data['lastDayClosed'] as String?,
      coachName: data['coachName'] as String?,
      coachStyle: data['coachStyle'] as String?,
      accountabilityMode: data['accountabilityMode'] as String?,
      notificationSettings: data['notificationSettings'] is Map
          ? NotificationSettings.fromMap(
              Map<String, dynamic>.from(data['notificationSettings'] as Map))
          : const NotificationSettings(),
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['uid'] as String? ?? map['id'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? map['name'] as String?,
      timezone: map['timezone'] as String?,
      createdAt: _asDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _asDateTime(map['updatedAt']) ?? DateTime.now(),
      schemaVersion: map['schemaVersion'] as int? ?? 1,
      hasCompletedOnboarding: map['hasCompletedOnboarding'] as bool? ?? false,
      onboardingStep: map['onboardingStep'] as int? ?? 0,
      lastDayClosed: map['lastDayClosed'] as String?,
      coachName: map['coachName'] as String?,
      coachStyle: map['coachStyle'] as String?,
      accountabilityMode: map['accountabilityMode'] as String?,
      notificationSettings: map['notificationSettings'] is Map
          ? NotificationSettings.fromMap(
              Map<String, dynamic>.from(map['notificationSettings'] as Map))
          : const NotificationSettings(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': id,
      'email': email,
      'displayName': displayName,
      'timezone': timezone,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': schemaVersion,
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'onboardingStep': onboardingStep,
      'lastDayClosed': lastDayClosed,
      'coachName': coachName,
      'coachStyle': coachStyle,
      'accountabilityMode': accountabilityMode,
      'notificationSettings': notificationSettings.toMap(),
    };
  }

  Map<String, dynamic> toMap() => toFirestore();

  UserModel copyWith({
    String? email,
    String? displayName,
    String? timezone,
    DateTime? updatedAt,
    bool? hasCompletedOnboarding,
    int? onboardingStep,
    String? lastDayClosed,
    String? coachName,
    String? coachStyle,
    String? accountabilityMode,
    NotificationSettings? notificationSettings,
  }) {
    return UserModel(
      id: id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      timezone: timezone ?? this.timezone,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      onboardingStep: onboardingStep ?? this.onboardingStep,
      lastDayClosed: lastDayClosed ?? this.lastDayClosed,
      coachName: coachName ?? this.coachName,
      coachStyle: coachStyle ?? this.coachStyle,
      accountabilityMode: accountabilityMode ?? this.accountabilityMode,
      notificationSettings: notificationSettings ?? this.notificationSettings,
    );
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
