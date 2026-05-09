import 'package:flutter_test/flutter_test.dart';
import 'package:optivus2/core/config/app_config.dart';
import 'package:optivus2/services/remote_config_service.dart';

void main() {
  group('AppFeatureFlags', () {
    test('defaults fail closed for unsafe AI, R2, and image features', () {
      final flags = AppFeatureFlags.fromConfig(
        build: _buildConfig(),
        remote: AppRemoteConfig.defaults(),
      );

      expect(flags.aiFeaturesEnabled, isFalse);
      expect(flags.aiCoachMessagesReady, isFalse);
      expect(flags.aiRoutineSuggestionsReady, isFalse);
      expect(flags.aiIdentitySummariesReady, isFalse);
      expect(flags.fitnessAiFeedbackReady, isFalse);
      expect(flags.r2UploadsReady, isFalse);
      expect(flags.imageRoutineImportReady, isFalse);
      expect(flags.classTimetableImageImportReady, isFalse);
      expect(flags.hostelMessImageImportReady, isFalse);
      expect(flags.skinProductImageImportReady, isFalse);
    });

    test('requires kill switches and endpoints before enabling AI paths', () {
      final remote = _remoteConfig(
        aiFeaturesEnabled: true,
        aiCoachMessagesEnabled: true,
        aiRoutineSuggestionsEnabled: true,
        aiIdentityScoringEnabled: true,
        fitnessAiFeedbackEnabled: true,
        routineImportWorkerEnabled: true,
      );

      final missingEndpoints = AppFeatureFlags.fromConfig(
        build: _buildConfig(),
        remote: remote,
      );
      expect(missingEndpoints.aiCoachMessagesReady, isFalse);
      expect(missingEndpoints.aiRoutineSuggestionsReady, isFalse);
      expect(missingEndpoints.aiIdentitySummariesReady, isFalse);
      expect(missingEndpoints.fitnessAiFeedbackReady, isFalse);

      final withEndpoints = AppFeatureFlags.fromConfig(
        build: _buildConfig(
          enableAiCoachWorker: true,
          coachReplyEndpoint: 'https://coach.example',
          aiGenerateEndpoint: 'https://ai.example',
          routineImportEndpoint: 'https://routine.example',
        ),
        remote: remote,
      );
      expect(withEndpoints.aiCoachMessagesReady, isTrue);
      expect(withEndpoints.aiRoutineSuggestionsReady, isTrue);
      expect(withEndpoints.aiIdentitySummariesReady, isTrue);
      expect(withEndpoints.fitnessAiFeedbackReady, isTrue);
    });

    test('requires R2 endpoint, compile flags, and remote flags for images',
        () {
      final remote = _remoteConfig(
        aiFeaturesEnabled: true,
        aiRoutineSuggestionsEnabled: true,
        routineImportWorkerEnabled: true,
        r2UploadsEnabled: true,
        profileImageUploadEnabled: true,
        imageRoutineImportEnabled: true,
        classTimetableImageImportEnabled: true,
        hostelMessImageImportEnabled: true,
        skinProductImageImportEnabled: true,
      );

      final flags = AppFeatureFlags.fromConfig(
        build: _buildConfig(
          enableR2Uploads: true,
          enableProfileImageUpload: true,
          enableImageRoutineImport: true,
          enableClassTimetableImageImport: true,
          enableHostelMessImageImport: true,
          enableSkinProductImageImport: true,
          routineImportEndpoint: 'https://routine.example',
          signedUploadEndpoint: 'https://r2.example/sign',
        ),
        remote: remote,
      );

      expect(flags.r2UploadsReady, isTrue);
      expect(flags.profileImageUploadReady, isTrue);
      expect(flags.imageRoutineImportReady, isTrue);
      expect(flags.classTimetableImageImportReady, isTrue);
      expect(flags.hostelMessImageImportReady, isTrue);
      expect(flags.skinProductImageImportReady, isTrue);
    });

    test('keeps Mapbox disabled until token is configured', () {
      final remote = _remoteConfig(mapboxMapsEnabled: true);
      final missingToken = AppFeatureFlags.fromConfig(
        build: _buildConfig(),
        remote: remote,
      );
      expect(missingToken.mapboxMapsReady, isFalse);

      final withToken = AppFeatureFlags.fromConfig(
        build: _buildConfig(mapboxAccessToken: 'mapbox-token'),
        remote: remote,
      );
      expect(withToken.mapboxMapsReady, isTrue);
      expect(withToken.coachEnabled, isTrue);
    });
  });
}

AppBuildConfig _buildConfig({
  bool enableR2Uploads = false,
  bool enableImageRoutineImport = false,
  bool enableProfileImageUpload = false,
  bool enableClassTimetableImageImport = false,
  bool enableHostelMessImageImport = false,
  bool enableSkinProductImageImport = false,
  bool enableAiCoachWorker = false,
  String coachReplyEndpoint = '',
  String aiGenerateEndpoint = '',
  String routineImportEndpoint = '',
  String signedUploadEndpoint = '',
  String deleteUploadEndpoint = '',
  String mapboxAccessToken = '',
}) {
  return AppBuildConfig(
    features: CompileTimeFeatureFlags(
      enableR2Uploads: enableR2Uploads,
      enableImageRoutineImport: enableImageRoutineImport,
      enableProfileImageUpload: enableProfileImageUpload,
      enableClassTimetableImageImport: enableClassTimetableImageImport,
      enableHostelMessImageImport: enableHostelMessImageImport,
      enableSkinProductImageImport: enableSkinProductImageImport,
      enableAiCoachWorker: enableAiCoachWorker,
    ),
    cloudflare: CloudflareEndpointConfig(
      coachReplyEndpoint: coachReplyEndpoint,
      aiGenerateEndpoint: aiGenerateEndpoint,
      routineImportEndpoint: routineImportEndpoint,
    ),
    r2: R2EndpointConfig(
      signedUploadEndpoint: signedUploadEndpoint,
      deleteUploadEndpoint: deleteUploadEndpoint,
    ),
    mapbox: MapboxClientConfig(accessToken: mapboxAccessToken),
  );
}

AppRemoteConfig _remoteConfig({
  bool coachEnabled = true,
  int notificationBudgetDefault = 3,
  bool aiFeaturesEnabled = false,
  bool aiCoachMessagesEnabled = false,
  bool aiRoutineSuggestionsEnabled = false,
  bool aiIdentityScoringEnabled = false,
  bool fitnessAiFeedbackEnabled = false,
  bool routineImportWorkerEnabled = false,
  bool r2UploadsEnabled = false,
  bool profileImageUploadEnabled = false,
  bool imageRoutineImportEnabled = false,
  bool classTimetableImageImportEnabled = false,
  bool hostelMessImageImportEnabled = false,
  bool skinProductImageImportEnabled = false,
  bool mapboxMapsEnabled = true,
  bool quietDayModeDefault = false,
  int quietDayStartHour = 22,
  int quietDayEndHour = 7,
}) {
  return AppRemoteConfig(
    coachEnabled: coachEnabled,
    notificationBudgetDefault: notificationBudgetDefault,
    aiFeaturesEnabled: aiFeaturesEnabled,
    aiCoachMessagesEnabled: aiCoachMessagesEnabled,
    aiRoutineSuggestionsEnabled: aiRoutineSuggestionsEnabled,
    aiIdentityScoringEnabled: aiIdentityScoringEnabled,
    fitnessAiFeedbackEnabled: fitnessAiFeedbackEnabled,
    routineImportWorkerEnabled: routineImportWorkerEnabled,
    r2UploadsEnabled: r2UploadsEnabled,
    profileImageUploadEnabled: profileImageUploadEnabled,
    imageRoutineImportEnabled: imageRoutineImportEnabled,
    classTimetableImageImportEnabled: classTimetableImageImportEnabled,
    hostelMessImageImportEnabled: hostelMessImageImportEnabled,
    skinProductImageImportEnabled: skinProductImageImportEnabled,
    mapboxMapsEnabled: mapboxMapsEnabled,
    quietDayModeDefault: quietDayModeDefault,
    quietDayStartHour: quietDayStartHour,
    quietDayEndHour: quietDayEndHour,
  );
}
