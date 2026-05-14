import 'package:optivus2/services/remote_config_service.dart';

class AppBuildConfig {
  final CompileTimeFeatureFlags features;
  final CloudflareEndpointConfig cloudflare;
  final R2EndpointConfig r2;
  final MapboxClientConfig mapbox;

  const AppBuildConfig({
    required this.features,
    required this.cloudflare,
    required this.r2,
    required this.mapbox,
  });

  static const current = AppBuildConfig(
    features: CompileTimeFeatureFlags.fromEnvironment(),
    cloudflare: CloudflareEndpointConfig.fromEnvironment(),
    r2: R2EndpointConfig.fromEnvironment(),
    mapbox: MapboxClientConfig.fromEnvironment(),
  );
}

class CompileTimeFeatureFlags {
  final bool enableR2Uploads;
  final bool enableImageRoutineImport;
  final bool enableProfileImageUpload;
  final bool enableClassTimetableImageImport;
  final bool enableHostelMessImageImport;
  final bool enableSkinProductImageImport;
  final bool enableAiCoachWorker;

  const CompileTimeFeatureFlags({
    required this.enableR2Uploads,
    required this.enableImageRoutineImport,
    required this.enableProfileImageUpload,
    required this.enableClassTimetableImageImport,
    required this.enableHostelMessImageImport,
    required this.enableSkinProductImageImport,
    required this.enableAiCoachWorker,
  });

  const CompileTimeFeatureFlags.fromEnvironment()
      : enableR2Uploads = const bool.fromEnvironment(
          'ENABLE_R2_UPLOADS',
          defaultValue: false,
        ),
        enableImageRoutineImport = const bool.fromEnvironment(
          'ENABLE_IMAGE_ROUTINE_IMPORT',
          defaultValue: false,
        ),
        enableProfileImageUpload = const bool.fromEnvironment(
          'ENABLE_PROFILE_IMAGE_UPLOAD',
          defaultValue: false,
        ),
        enableClassTimetableImageImport = const bool.fromEnvironment(
          'ENABLE_CLASS_TIMETABLE_IMAGE_IMPORT',
          defaultValue: false,
        ),
        enableHostelMessImageImport = const bool.fromEnvironment(
          'ENABLE_HOSTEL_MESS_IMAGE_IMPORT',
          defaultValue: false,
        ),
        enableSkinProductImageImport = const bool.fromEnvironment(
          'ENABLE_SKIN_PRODUCT_IMAGE_IMPORT',
          defaultValue: false,
        ),
        enableAiCoachWorker = const bool.fromEnvironment(
          'ENABLE_AI_COACH_WORKER',
          defaultValue: false,
        );
}

class CloudflareEndpointConfig {
  final String coachReplyEndpoint;
  final String aiGenerateEndpoint;
  final String routineImportEndpoint;

  const CloudflareEndpointConfig({
    required this.coachReplyEndpoint,
    required this.aiGenerateEndpoint,
    required this.routineImportEndpoint,
  });

  const CloudflareEndpointConfig.fromEnvironment()
      : coachReplyEndpoint = const String.fromEnvironment(
          'COACH_REPLY_ENDPOINT',
        ),
        aiGenerateEndpoint = const String.fromEnvironment(
          'AI_GENERATE_ENDPOINT',
        ),
        routineImportEndpoint = const String.fromEnvironment(
          'ROUTINE_IMPORT_ENDPOINT',
        );

  String get normalizedCoachReplyEndpoint => coachReplyEndpoint.trim();
  String get normalizedAiGenerateEndpoint => aiGenerateEndpoint.trim();
  String get normalizedRoutineImportEndpoint => routineImportEndpoint.trim();

  bool get hasCoachReplyEndpoint => normalizedCoachReplyEndpoint.isNotEmpty;
  bool get hasAiGenerateEndpoint => normalizedAiGenerateEndpoint.isNotEmpty;
  bool get hasRoutineImportEndpoint =>
      normalizedRoutineImportEndpoint.isNotEmpty;
}

class R2EndpointConfig {
  final String signedUploadEndpoint;
  final String deleteUploadEndpoint;

  const R2EndpointConfig({
    required this.signedUploadEndpoint,
    required this.deleteUploadEndpoint,
  });

  const R2EndpointConfig.fromEnvironment()
      : signedUploadEndpoint = const String.fromEnvironment(
          'R2_SIGNED_UPLOAD_ENDPOINT',
        ),
        deleteUploadEndpoint = const String.fromEnvironment(
          'R2_DELETE_UPLOAD_ENDPOINT',
        );

  String get normalizedSignedUploadEndpoint => signedUploadEndpoint.trim();
  String get normalizedDeleteUploadEndpoint => deleteUploadEndpoint.trim();

  bool get hasSignedUploadEndpoint => normalizedSignedUploadEndpoint.isNotEmpty;
  bool get hasDeleteUploadEndpoint => normalizedDeleteUploadEndpoint.isNotEmpty;
}

class MapboxClientConfig {
  final String accessToken;

  const MapboxClientConfig({
    required this.accessToken,
  });

  const MapboxClientConfig.fromEnvironment()
      : accessToken = const String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

  String get normalizedAccessToken => accessToken.trim();

  bool get hasAccessToken => normalizedAccessToken.isNotEmpty;

  String tileUrlForStyleUri(String styleUri) {
    final normalized = styleUri.trim();
    const prefix = 'mapbox://styles/';
    if (!normalized.startsWith(prefix)) {
      throw ArgumentError.value(
        styleUri,
        'styleUri',
        'Expected a mapbox://styles/{owner}/{styleId} URI.',
      );
    }

    final path = normalized.substring(prefix.length);
    final segments = path.split('/');
    if (segments.length != 2 ||
        segments.any((segment) => segment.trim().isEmpty)) {
      throw ArgumentError.value(
        styleUri,
        'styleUri',
        'Expected a mapbox://styles/{owner}/{styleId} URI.',
      );
    }

    final owner = Uri.encodeComponent(segments[0].trim());
    final styleId = Uri.encodeComponent(segments[1].trim());
    return 'https://api.mapbox.com/styles/v1/$owner/$styleId/tiles/256/{z}/{x}/{y}@2x?access_token=$normalizedAccessToken';
  }

  String get tileUrl => tileUrlForStyleUri(
        'mapbox://styles/nairitroy/cmozyqm88000c01r14o8h7bn0',
      );
}

class AppFeatureFlags {
  final bool coachEnabled;
  final bool aiFeaturesEnabled;
  final bool aiCoachMessagesReady;
  final bool aiRoutineSuggestionsReady;
  final bool aiIdentitySummariesReady;
  final bool fitnessAiFeedbackReady;
  final bool routineImportWorkerReady;
  final bool r2UploadsReady;
  final bool profileImageUploadReady;
  final bool imageRoutineImportReady;
  final bool classTimetableImageImportReady;
  final bool hostelMessImageImportReady;
  final bool skinProductImageImportReady;
  final bool mapboxMapsReady;

  const AppFeatureFlags({
    required this.coachEnabled,
    required this.aiFeaturesEnabled,
    required this.aiCoachMessagesReady,
    required this.aiRoutineSuggestionsReady,
    required this.aiIdentitySummariesReady,
    required this.fitnessAiFeedbackReady,
    required this.routineImportWorkerReady,
    required this.r2UploadsReady,
    required this.profileImageUploadReady,
    required this.imageRoutineImportReady,
    required this.classTimetableImageImportReady,
    required this.hostelMessImageImportReady,
    required this.skinProductImageImportReady,
    required this.mapboxMapsReady,
  });

  factory AppFeatureFlags.fromConfig({
    required AppBuildConfig build,
    required AppRemoteConfig remote,
  }) {
    final aiGenerateReady =
        remote.aiFeaturesEnabled && build.cloudflare.hasAiGenerateEndpoint;
    final routineImportReady = remote.aiFeaturesEnabled &&
        remote.aiRoutineSuggestionsEnabled &&
        remote.routineImportWorkerEnabled &&
        build.cloudflare.hasRoutineImportEndpoint;
    final r2Ready = build.features.enableR2Uploads &&
        remote.r2UploadsEnabled &&
        build.r2.hasSignedUploadEndpoint;
    final imageRoutineReady = r2Ready &&
        routineImportReady &&
        build.features.enableImageRoutineImport &&
        remote.imageRoutineImportEnabled;

    return AppFeatureFlags(
      coachEnabled: remote.coachEnabled,
      aiFeaturesEnabled: remote.aiFeaturesEnabled,
      aiCoachMessagesReady: remote.aiFeaturesEnabled &&
          remote.aiCoachMessagesEnabled &&
          build.features.enableAiCoachWorker &&
          build.cloudflare.hasCoachReplyEndpoint,
      aiRoutineSuggestionsReady: routineImportReady,
      aiIdentitySummariesReady:
          aiGenerateReady && remote.aiIdentityScoringEnabled,
      fitnessAiFeedbackReady:
          aiGenerateReady && remote.fitnessAiFeedbackEnabled,
      routineImportWorkerReady: routineImportReady,
      r2UploadsReady: r2Ready,
      profileImageUploadReady: r2Ready &&
          build.features.enableProfileImageUpload &&
          remote.profileImageUploadEnabled,
      imageRoutineImportReady: imageRoutineReady,
      classTimetableImageImportReady: imageRoutineReady &&
          build.features.enableClassTimetableImageImport &&
          remote.classTimetableImageImportEnabled,
      hostelMessImageImportReady: imageRoutineReady &&
          build.features.enableHostelMessImageImport &&
          remote.hostelMessImageImportEnabled,
      skinProductImageImportReady: imageRoutineReady &&
          build.features.enableSkinProductImageImport &&
          remote.skinProductImageImportEnabled,
      mapboxMapsReady: remote.mapboxMapsEnabled && build.mapbox.hasAccessToken,
    );
  }

  AppFeatureFlags copyWith({
    bool? coachEnabled,
    bool? aiFeaturesEnabled,
    bool? aiCoachMessagesReady,
    bool? aiRoutineSuggestionsReady,
    bool? aiIdentitySummariesReady,
    bool? fitnessAiFeedbackReady,
    bool? routineImportWorkerReady,
    bool? r2UploadsReady,
    bool? profileImageUploadReady,
    bool? imageRoutineImportReady,
    bool? classTimetableImageImportReady,
    bool? hostelMessImageImportReady,
    bool? skinProductImageImportReady,
    bool? mapboxMapsReady,
  }) {
    return AppFeatureFlags(
      coachEnabled: coachEnabled ?? this.coachEnabled,
      aiFeaturesEnabled: aiFeaturesEnabled ?? this.aiFeaturesEnabled,
      aiCoachMessagesReady: aiCoachMessagesReady ?? this.aiCoachMessagesReady,
      aiRoutineSuggestionsReady: aiRoutineSuggestionsReady ?? this.aiRoutineSuggestionsReady,
      aiIdentitySummariesReady: aiIdentitySummariesReady ?? this.aiIdentitySummariesReady,
      fitnessAiFeedbackReady: fitnessAiFeedbackReady ?? this.fitnessAiFeedbackReady,
      routineImportWorkerReady: routineImportWorkerReady ?? this.routineImportWorkerReady,
      r2UploadsReady: r2UploadsReady ?? this.r2UploadsReady,
      profileImageUploadReady: profileImageUploadReady ?? this.profileImageUploadReady,
      imageRoutineImportReady: imageRoutineImportReady ?? this.imageRoutineImportReady,
      classTimetableImageImportReady: classTimetableImageImportReady ?? this.classTimetableImageImportReady,
      hostelMessImageImportReady: hostelMessImageImportReady ?? this.hostelMessImageImportReady,
      skinProductImageImportReady: skinProductImageImportReady ?? this.skinProductImageImportReady,
      mapboxMapsReady: mapboxMapsReady ?? this.mapboxMapsReady,
    );
  }

  static AppFeatureFlags defaults() => AppFeatureFlags.fromConfig(
        build: AppBuildConfig.current,
        remote: AppRemoteConfig.defaults(),
      );
}
