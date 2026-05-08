class FeatureFlags {
  const FeatureFlags._();

  static const bool enableR2Uploads = bool.fromEnvironment(
    'ENABLE_R2_UPLOADS',
    defaultValue: false,
  );
  static const bool enableImageRoutineImport = bool.fromEnvironment(
    'ENABLE_IMAGE_ROUTINE_IMPORT',
    defaultValue: false,
  );
  static const bool enableProfileImageUpload = bool.fromEnvironment(
    'ENABLE_PROFILE_IMAGE_UPLOAD',
    defaultValue: false,
  );
  static const bool enableClassTimetableImageImport = bool.fromEnvironment(
    'ENABLE_CLASS_TIMETABLE_IMAGE_IMPORT',
    defaultValue: false,
  );
  static const bool enableHostelMessImageImport = bool.fromEnvironment(
    'ENABLE_HOSTEL_MESS_IMAGE_IMPORT',
    defaultValue: false,
  );
  static const bool enableSkinProductImageImport = bool.fromEnvironment(
    'ENABLE_SKIN_PRODUCT_IMAGE_IMPORT',
    defaultValue: false,
  );
  static const bool enableAiCoachWorker = bool.fromEnvironment(
    'ENABLE_AI_COACH_WORKER',
    defaultValue: false,
  );

  static bool get imageRoutineImportReady =>
      enableR2Uploads && enableImageRoutineImport;

  static bool get classTimetableImageImportReady =>
      imageRoutineImportReady && enableClassTimetableImageImport;

  static bool get hostelMessImageImportReady =>
      imageRoutineImportReady && enableHostelMessImageImport;

  static bool get skinProductImageImportReady =>
      imageRoutineImportReady && enableSkinProductImageImport;
}
