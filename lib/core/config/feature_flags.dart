import 'package:optivus2/core/config/app_config.dart';

class FeatureFlags {
  const FeatureFlags._();

  static const _build = AppBuildConfig.current;

  static bool get enableR2Uploads => _build.features.enableR2Uploads;

  static bool get enableImageRoutineImport =>
      _build.features.enableImageRoutineImport;

  static bool get enableProfileImageUpload =>
      _build.features.enableProfileImageUpload;

  static bool get enableClassTimetableImageImport =>
      _build.features.enableClassTimetableImageImport;

  static bool get enableHostelMessImageImport =>
      _build.features.enableHostelMessImageImport;

  static bool get enableSkinProductImageImport =>
      _build.features.enableSkinProductImageImport;

  static bool get enableAiCoachWorker => _build.features.enableAiCoachWorker;

  static bool get imageRoutineImportReady =>
      enableR2Uploads && enableImageRoutineImport;

  static bool get classTimetableImageImportReady =>
      imageRoutineImportReady && enableClassTimetableImageImport;

  static bool get hostelMessImageImportReady =>
      imageRoutineImportReady && enableHostelMessImageImport;

  static bool get skinProductImageImportReady =>
      imageRoutineImportReady && enableSkinProductImageImport;
}
