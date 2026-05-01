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

class BodyBasics {
  final String? ageRange;
  final int? heightCm;
  final double? weightKg;
  final String? gender;
  final String? wakeTime;
  final String? sleepTime;
  final String? timezone;

  const BodyBasics({
    this.ageRange,
    this.heightCm,
    this.weightKg,
    this.gender,
    this.wakeTime,
    this.sleepTime,
    this.timezone,
  });

  factory BodyBasics.fromMap(Map<String, dynamic> map) {
    return BodyBasics(
      ageRange: map['ageRange'] as String?,
      heightCm: (map['heightCm'] as num?)?.toInt(),
      weightKg: (map['weightKg'] as num?)?.toDouble(),
      gender: map['gender'] as String?,
      wakeTime: map['wakeTime'] as String?,
      sleepTime: map['sleepTime'] as String?,
      timezone: map['timezone'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'ageRange': ageRange,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'gender': gender,
        'wakeTime': wakeTime,
        'sleepTime': sleepTime,
        'timezone': timezone,
      };

  BodyBasics copyWith({
    String? ageRange,
    int? heightCm,
    double? weightKg,
    String? gender,
    String? wakeTime,
    String? sleepTime,
    String? timezone,
    bool clearGender = false,
    bool clearHeight = false,
    bool clearWeight = false,
  }) {
    return BodyBasics(
      ageRange: ageRange ?? this.ageRange,
      heightCm: clearHeight ? null : (heightCm ?? this.heightCm),
      weightKg: clearWeight ? null : (weightKg ?? this.weightKg),
      gender: clearGender ? null : (gender ?? this.gender),
      wakeTime: wakeTime ?? this.wakeTime,
      sleepTime: sleepTime ?? this.sleepTime,
      timezone: timezone ?? this.timezone,
    );
  }

  String? validate() {
    if (heightCm != null && (heightCm! < 90 || heightCm! > 250)) {
      return 'Height must be between 90 cm and 250 cm.';
    }
    if (weightKg != null && (weightKg! < 25 || weightKg! > 300)) {
      return 'Weight must be between 25 kg and 300 kg.';
    }
    return null;
  }
}

class LifestyleProfile {
  final String? schoolWorkType;
  final String? exerciseLevel;
  final String? waterIntake;
  final String? dietPreference;
  final String? stressLevel;
  final String? sleepQuality;

  const LifestyleProfile({
    this.schoolWorkType,
    this.exerciseLevel,
    this.waterIntake,
    this.dietPreference,
    this.stressLevel,
    this.sleepQuality,
  });

  factory LifestyleProfile.fromMap(Map<String, dynamic> map) {
    return LifestyleProfile(
      schoolWorkType: map['schoolWorkType'] as String?,
      exerciseLevel: map['exerciseLevel'] as String?,
      waterIntake: map['waterIntake'] as String?,
      dietPreference: map['dietPreference'] as String?,
      stressLevel: map['stressLevel'] as String?,
      sleepQuality: map['sleepQuality'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'schoolWorkType': schoolWorkType,
        'exerciseLevel': exerciseLevel,
        'waterIntake': waterIntake,
        'dietPreference': dietPreference,
        'stressLevel': stressLevel,
        'sleepQuality': sleepQuality,
      };

  LifestyleProfile copyWith({
    String? schoolWorkType,
    String? exerciseLevel,
    String? waterIntake,
    String? dietPreference,
    String? stressLevel,
    String? sleepQuality,
  }) {
    return LifestyleProfile(
      schoolWorkType: schoolWorkType ?? this.schoolWorkType,
      exerciseLevel: exerciseLevel ?? this.exerciseLevel,
      waterIntake: waterIntake ?? this.waterIntake,
      dietPreference: dietPreference ?? this.dietPreference,
      stressLevel: stressLevel ?? this.stressLevel,
      sleepQuality: sleepQuality ?? this.sleepQuality,
    );
  }
}

class SensitiveContext {
  final bool? eatingDisorderFlag;
  final bool? crisisSelfHarmFlag;
  final bool medicalDisclaimerAcknowledged;
  final String? coachBoundaryPreference;

  const SensitiveContext({
    this.eatingDisorderFlag,
    this.crisisSelfHarmFlag,
    this.medicalDisclaimerAcknowledged = false,
    this.coachBoundaryPreference,
  });

  factory SensitiveContext.fromMap(Map<String, dynamic> map) {
    return SensitiveContext(
      eatingDisorderFlag: map['eatingDisorderFlag'] as bool?,
      crisisSelfHarmFlag: map['crisisSelfHarmFlag'] as bool?,
      medicalDisclaimerAcknowledged:
          map['medicalDisclaimerAcknowledged'] as bool? ?? false,
      coachBoundaryPreference: map['coachBoundaryPreference'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'eatingDisorderFlag': eatingDisorderFlag,
        'crisisSelfHarmFlag': crisisSelfHarmFlag,
        'medicalDisclaimerAcknowledged': medicalDisclaimerAcknowledged,
        'coachBoundaryPreference': coachBoundaryPreference,
      };

  SensitiveContext copyWith({
    bool? eatingDisorderFlag,
    bool? crisisSelfHarmFlag,
    bool? medicalDisclaimerAcknowledged,
    String? coachBoundaryPreference,
    bool clearEatingDisorderFlag = false,
    bool clearCrisisSelfHarmFlag = false,
    bool clearCoachBoundaryPreference = false,
  }) {
    return SensitiveContext(
      eatingDisorderFlag: clearEatingDisorderFlag
          ? null
          : (eatingDisorderFlag ?? this.eatingDisorderFlag),
      crisisSelfHarmFlag: clearCrisisSelfHarmFlag
          ? null
          : (crisisSelfHarmFlag ?? this.crisisSelfHarmFlag),
      medicalDisclaimerAcknowledged:
          medicalDisclaimerAcknowledged ?? this.medicalDisclaimerAcknowledged,
      coachBoundaryPreference: clearCoachBoundaryPreference
          ? null
          : (coachBoundaryPreference ?? this.coachBoundaryPreference),
    );
  }
}

class AboutYouProfile {
  final BodyBasics bodyBasics;
  final LifestyleProfile lifestyle;
  final SensitiveContext sensitiveContext;

  const AboutYouProfile({
    this.bodyBasics = const BodyBasics(),
    this.lifestyle = const LifestyleProfile(),
    this.sensitiveContext = const SensitiveContext(),
  });

  factory AboutYouProfile.fromMap(Map<String, dynamic> map) {
    return AboutYouProfile(
      bodyBasics: map['bodyBasics'] is Map
          ? BodyBasics.fromMap(Map<String, dynamic>.from(map['bodyBasics']))
          : const BodyBasics(),
      lifestyle: map['lifestyle'] is Map
          ? LifestyleProfile.fromMap(
              Map<String, dynamic>.from(map['lifestyle']))
          : const LifestyleProfile(),
      sensitiveContext: map['sensitiveContext'] is Map
          ? SensitiveContext.fromMap(
              Map<String, dynamic>.from(map['sensitiveContext']))
          : const SensitiveContext(),
    );
  }

  Map<String, dynamic> toMap() => {
        'bodyBasics': bodyBasics.toMap(),
        'lifestyle': lifestyle.toMap(),
        'sensitiveContext': sensitiveContext.toMap(),
      };

  AboutYouProfile copyWith({
    BodyBasics? bodyBasics,
    LifestyleProfile? lifestyle,
    SensitiveContext? sensitiveContext,
  }) {
    return AboutYouProfile(
      bodyBasics: bodyBasics ?? this.bodyBasics,
      lifestyle: lifestyle ?? this.lifestyle,
      sensitiveContext: sensitiveContext ?? this.sensitiveContext,
    );
  }

  String? validate() => bodyBasics.validate();
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
