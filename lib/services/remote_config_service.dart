import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigKeys {
  static const coachEnabled = 'coach_enabled';
  static const notificationBudgetDefault = 'notification_budget_default';
  static const aiFeaturesEnabled = 'ai_features_enabled';
  static const aiCoachMessagesEnabled = 'ai_coach_messages_enabled';
  static const aiRoutineSuggestionsEnabled = 'ai_routine_suggestions_enabled';
  static const aiIdentityScoringEnabled = 'ai_identity_scoring_enabled';
  static const fitnessAiFeedbackEnabled = 'fitness_ai_feedback_enabled';
  static const routineImportWorkerEnabled = 'routine_import_worker_enabled';
  static const r2UploadsEnabled = 'r2_uploads_enabled';
  static const profileImageUploadEnabled = 'profile_image_upload_enabled';
  static const imageRoutineImportEnabled = 'image_routine_import_enabled';
  static const classTimetableImageImportEnabled =
      'class_timetable_image_import_enabled';
  static const hostelMessImageImportEnabled =
      'hostel_mess_image_import_enabled';
  static const skinProductImageImportEnabled =
      'skin_product_image_import_enabled';
  static const mapboxMapsEnabled = 'mapbox_maps_enabled';
  static const quietDayModeDefault = 'quiet_day_mode_default';
  static const quietDayStartHour = 'quiet_day_start_hour';
  static const quietDayEndHour = 'quiet_day_end_hour';
}

const Map<String, Object> remoteConfigDefaults = {
  RemoteConfigKeys.coachEnabled: true,
  RemoteConfigKeys.notificationBudgetDefault: 3,
  RemoteConfigKeys.aiFeaturesEnabled: false,
  RemoteConfigKeys.aiCoachMessagesEnabled: false,
  RemoteConfigKeys.aiRoutineSuggestionsEnabled: false,
  RemoteConfigKeys.aiIdentityScoringEnabled: false,
  RemoteConfigKeys.fitnessAiFeedbackEnabled: false,
  RemoteConfigKeys.routineImportWorkerEnabled: false,
  RemoteConfigKeys.r2UploadsEnabled: false,
  RemoteConfigKeys.profileImageUploadEnabled: false,
  RemoteConfigKeys.imageRoutineImportEnabled: false,
  RemoteConfigKeys.classTimetableImageImportEnabled: false,
  RemoteConfigKeys.hostelMessImageImportEnabled: false,
  RemoteConfigKeys.skinProductImageImportEnabled: false,
  RemoteConfigKeys.mapboxMapsEnabled: true,
  RemoteConfigKeys.quietDayModeDefault: false,
  RemoteConfigKeys.quietDayStartHour: 22,
  RemoteConfigKeys.quietDayEndHour: 7,
};

class AppRemoteConfig {
  final bool coachEnabled;
  final int notificationBudgetDefault;
  final bool aiFeaturesEnabled;
  final bool aiCoachMessagesEnabled;
  final bool aiRoutineSuggestionsEnabled;
  final bool aiIdentityScoringEnabled;
  final bool fitnessAiFeedbackEnabled;
  final bool routineImportWorkerEnabled;
  final bool r2UploadsEnabled;
  final bool profileImageUploadEnabled;
  final bool imageRoutineImportEnabled;
  final bool classTimetableImageImportEnabled;
  final bool hostelMessImageImportEnabled;
  final bool skinProductImageImportEnabled;
  final bool mapboxMapsEnabled;
  final bool quietDayModeDefault;
  final int quietDayStartHour;
  final int quietDayEndHour;

  const AppRemoteConfig({
    required this.coachEnabled,
    required this.notificationBudgetDefault,
    required this.aiFeaturesEnabled,
    required this.aiCoachMessagesEnabled,
    required this.aiRoutineSuggestionsEnabled,
    required this.aiIdentityScoringEnabled,
    required this.fitnessAiFeedbackEnabled,
    required this.routineImportWorkerEnabled,
    required this.r2UploadsEnabled,
    required this.profileImageUploadEnabled,
    required this.imageRoutineImportEnabled,
    required this.classTimetableImageImportEnabled,
    required this.hostelMessImageImportEnabled,
    required this.skinProductImageImportEnabled,
    required this.mapboxMapsEnabled,
    required this.quietDayModeDefault,
    required this.quietDayStartHour,
    required this.quietDayEndHour,
  });

  factory AppRemoteConfig.defaults() => const AppRemoteConfig(
        coachEnabled: true,
        notificationBudgetDefault: 3,
        aiFeaturesEnabled: false,
        aiCoachMessagesEnabled: false,
        aiRoutineSuggestionsEnabled: false,
        aiIdentityScoringEnabled: false,
        fitnessAiFeedbackEnabled: false,
        routineImportWorkerEnabled: false,
        r2UploadsEnabled: false,
        profileImageUploadEnabled: false,
        imageRoutineImportEnabled: false,
        classTimetableImageImportEnabled: false,
        hostelMessImageImportEnabled: false,
        skinProductImageImportEnabled: false,
        mapboxMapsEnabled: true,
        quietDayModeDefault: false,
        quietDayStartHour: 22,
        quietDayEndHour: 7,
      );

  factory AppRemoteConfig.fromFirebase(FirebaseRemoteConfig remoteConfig) {
    return AppRemoteConfig(
      coachEnabled: remoteConfig.getBool(RemoteConfigKeys.coachEnabled),
      notificationBudgetDefault:
          remoteConfig.getInt(RemoteConfigKeys.notificationBudgetDefault),
      aiFeaturesEnabled:
          remoteConfig.getBool(RemoteConfigKeys.aiFeaturesEnabled),
      aiCoachMessagesEnabled:
          remoteConfig.getBool(RemoteConfigKeys.aiCoachMessagesEnabled),
      aiRoutineSuggestionsEnabled:
          remoteConfig.getBool(RemoteConfigKeys.aiRoutineSuggestionsEnabled),
      aiIdentityScoringEnabled:
          remoteConfig.getBool(RemoteConfigKeys.aiIdentityScoringEnabled),
      fitnessAiFeedbackEnabled:
          remoteConfig.getBool(RemoteConfigKeys.fitnessAiFeedbackEnabled),
      routineImportWorkerEnabled:
          remoteConfig.getBool(RemoteConfigKeys.routineImportWorkerEnabled),
      r2UploadsEnabled: remoteConfig.getBool(RemoteConfigKeys.r2UploadsEnabled),
      profileImageUploadEnabled:
          remoteConfig.getBool(RemoteConfigKeys.profileImageUploadEnabled),
      imageRoutineImportEnabled:
          remoteConfig.getBool(RemoteConfigKeys.imageRoutineImportEnabled),
      classTimetableImageImportEnabled: remoteConfig
          .getBool(RemoteConfigKeys.classTimetableImageImportEnabled),
      hostelMessImageImportEnabled:
          remoteConfig.getBool(RemoteConfigKeys.hostelMessImageImportEnabled),
      skinProductImageImportEnabled:
          remoteConfig.getBool(RemoteConfigKeys.skinProductImageImportEnabled),
      mapboxMapsEnabled:
          remoteConfig.getBool(RemoteConfigKeys.mapboxMapsEnabled),
      quietDayModeDefault:
          remoteConfig.getBool(RemoteConfigKeys.quietDayModeDefault),
      quietDayStartHour:
          remoteConfig.getInt(RemoteConfigKeys.quietDayStartHour),
      quietDayEndHour: remoteConfig.getInt(RemoteConfigKeys.quietDayEndHour),
    );
  }

  Map<String, Object> toLogMap() => {
        RemoteConfigKeys.coachEnabled: coachEnabled,
        RemoteConfigKeys.notificationBudgetDefault: notificationBudgetDefault,
        RemoteConfigKeys.aiFeaturesEnabled: aiFeaturesEnabled,
        RemoteConfigKeys.aiCoachMessagesEnabled: aiCoachMessagesEnabled,
        RemoteConfigKeys.aiRoutineSuggestionsEnabled:
            aiRoutineSuggestionsEnabled,
        RemoteConfigKeys.aiIdentityScoringEnabled: aiIdentityScoringEnabled,
        RemoteConfigKeys.fitnessAiFeedbackEnabled: fitnessAiFeedbackEnabled,
        RemoteConfigKeys.routineImportWorkerEnabled: routineImportWorkerEnabled,
        RemoteConfigKeys.r2UploadsEnabled: r2UploadsEnabled,
        RemoteConfigKeys.profileImageUploadEnabled: profileImageUploadEnabled,
        RemoteConfigKeys.imageRoutineImportEnabled: imageRoutineImportEnabled,
        RemoteConfigKeys.classTimetableImageImportEnabled:
            classTimetableImageImportEnabled,
        RemoteConfigKeys.hostelMessImageImportEnabled:
            hostelMessImageImportEnabled,
        RemoteConfigKeys.skinProductImageImportEnabled:
            skinProductImageImportEnabled,
        RemoteConfigKeys.mapboxMapsEnabled: mapboxMapsEnabled,
        RemoteConfigKeys.quietDayModeDefault: quietDayModeDefault,
        RemoteConfigKeys.quietDayStartHour: quietDayStartHour,
        RemoteConfigKeys.quietDayEndHour: quietDayEndHour,
      };
}

class RemoteConfigService {
  final FirebaseRemoteConfig? _injectedRemoteConfig;
  late final FirebaseRemoteConfig _remoteConfig =
      _injectedRemoteConfig ?? FirebaseRemoteConfig.instance;
  AppRemoteConfig _current = AppRemoteConfig.defaults();

  RemoteConfigService({FirebaseRemoteConfig? remoteConfig})
      : _injectedRemoteConfig = remoteConfig;

  AppRemoteConfig get current => _current;

  Future<AppRemoteConfig> initialize() async {
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval:
            kDebugMode ? Duration.zero : const Duration(hours: 1),
      ),
    );
    await _remoteConfig.setDefaults(remoteConfigDefaults);

    try {
      await _remoteConfig.fetchAndActivate();
    } catch (error) {
      debugPrint(
          '[RemoteConfig] fetchAndActivate failed; using defaults: $error');
    }

    _current = AppRemoteConfig.fromFirebase(_remoteConfig);
    debugPrint('[RemoteConfig] active flags: ${_current.toLogMap()}');
    return _current;
  }

  Future<AppRemoteConfig> refresh() async {
    try {
      await _remoteConfig.fetchAndActivate();
      _current = AppRemoteConfig.fromFirebase(_remoteConfig);
      debugPrint('[RemoteConfig] refreshed flags: ${_current.toLogMap()}');
    } catch (error) {
      debugPrint('[RemoteConfig] refresh failed; keeping cached flags: $error');
    }
    return _current;
  }
}
