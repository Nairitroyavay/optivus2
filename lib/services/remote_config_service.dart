import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigKeys {
  static const coachEnabled = 'coach_enabled';
  static const notificationBudgetDefault = 'notification_budget_default';
  static const aiFeaturesEnabled = 'ai_features_enabled';
  static const aiCoachMessagesEnabled = 'ai_coach_messages_enabled';
  static const aiRoutineSuggestionsEnabled = 'ai_routine_suggestions_enabled';
  static const aiIdentityScoringEnabled = 'ai_identity_scoring_enabled';
  static const quietDayModeDefault = 'quiet_day_mode_default';
  static const quietDayStartHour = 'quiet_day_start_hour';
  static const quietDayEndHour = 'quiet_day_end_hour';
}

const Map<String, Object> remoteConfigDefaults = {
  RemoteConfigKeys.coachEnabled: true,
  RemoteConfigKeys.notificationBudgetDefault: 3,
  RemoteConfigKeys.aiFeaturesEnabled: true,
  RemoteConfigKeys.aiCoachMessagesEnabled: true,
  RemoteConfigKeys.aiRoutineSuggestionsEnabled: true,
  RemoteConfigKeys.aiIdentityScoringEnabled: true,
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
    required this.quietDayModeDefault,
    required this.quietDayStartHour,
    required this.quietDayEndHour,
  });

  factory AppRemoteConfig.defaults() => const AppRemoteConfig(
        coachEnabled: true,
        notificationBudgetDefault: 3,
        aiFeaturesEnabled: true,
        aiCoachMessagesEnabled: true,
        aiRoutineSuggestionsEnabled: true,
        aiIdentityScoringEnabled: true,
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
        RemoteConfigKeys.quietDayModeDefault: quietDayModeDefault,
        RemoteConfigKeys.quietDayStartHour: quietDayStartHour,
        RemoteConfigKeys.quietDayEndHour: quietDayEndHour,
      };
}

class RemoteConfigService {
  final FirebaseRemoteConfig _remoteConfig;
  AppRemoteConfig _current = AppRemoteConfig.defaults();

  RemoteConfigService({FirebaseRemoteConfig? remoteConfig})
      : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

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
