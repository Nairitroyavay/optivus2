# Build, Test, and QA Baseline

Updated: 2026-05-10

This is the current Task 1.2 baseline for local development and Play Store
internal-testing readiness. Keep `docs/OPTIVUS_STRICT_TASK_RULES.md` as the
source of truth for forbidden services and deployment limits.

## Command Matrix

| Area | Command | Current status | Notes |
| --- | --- | --- | --- |
| Spark guardrail | `python3 scripts/spark_guardrail_scan.py` | PASS | No active forbidden dependency or deploy target found. Expected warning: inactive `storage.rules` exists and must stay unreferenced by `firebase.json`. |
| Dart analyzer | `flutter analyze` | PASS | `No issues found! (ran in 5.2s)`. `lib/views/tabs/profile_tab.dart` was specifically checked for duplicate `emptyLabel`; only two call-site arguments and one `_buildPills` parameter exist. |
| Flutter tests | `flutter test` | PASS WITH SKIPS | Active tests passed: `+163 ~155`. Skipped tests are listed below and remain known coverage gaps. |
| Routine import Worker tests | `cd workers/routine-import-worker && npm test` | PASS | 17 pass, 0 fail, 0 skipped. Covers auth, invalid tokens, preview-only behavior, AI output validation, image URL rejection, and usage-cap rate limiting. |
| Coach reply Worker tests | `cd workers/coach-reply-worker && npm test` | PASS | 7 pass, 0 fail, 0 skipped. Covers Firebase auth, invalid tokens, user mismatch, preview response shape, rate limiting, and crisis/recovery safety branches. |
| AI gateway Worker tests | `cd workers/ai-gateway-worker && npm test` | PASS | 8 pass, 0 fail, 0 skipped. Covers Firebase auth, invalid tokens, user mismatch, context payloads, preview response shape, rate limiting, and crisis/recovery safety branches. |
| Android release app bundle | `flutter build appbundle --release` | PASS | Built `build/app/outputs/bundle/release/app-release.aab` at 348.9 MB after clearing stale Gradle caches. |
| Firebase deploy | none | NOT ALLOWED | Do not run `firebase deploy`. |
| Cloudflare deploy | none | NOT ALLOWED | Do not run `wrangler deploy` or Worker deploy scripts during baseline QA. |

## Android Build Notes

The release build initially failed because newer AndroidX artifacts required
Android Gradle Plugin 8.9.1 or newer while the project used 8.7.2. The baseline
toolchain is now:

| File | Baseline value |
| --- | --- |
| `android/settings.gradle.kts` | `com.android.application` version `8.9.1` |
| `android/gradle/wrapper/gradle-wrapper.properties` | Gradle `8.11.1` |

If release build failures mention missing files under `build/app/intermediates`
or Gradle incremental caches, clear generated caches before rebuilding:

```sh
cd android
./gradlew --stop
cd ..
flutter clean
rm -rf build
rm -rf android/.gradle
rm -rf ~/.gradle/caches/transforms-*
rm -rf ~/.gradle/caches/modules-2/files-2.1/com.android.tools.build/gradle
flutter pub get
flutter build appbundle --release
```

Current Play Store readiness blockers remain outside this build baseline:
`android/app/build.gradle.kts` still uses `applicationId =
"com.example.optivus"` and release signing still points at the debug signing
config.

## Dart-define Test Dimensions

Run smoke tests with all optional flags absent first. Manual/text fallbacks must
work when AI, R2, and Mapbox flags are missing.

| Dimension | Dart define | Default baseline |
| --- | --- | --- |
| Routine import Worker | `ROUTINE_IMPORT_ENDPOINT` | unset |
| Coach reply Worker | `COACH_REPLY_ENDPOINT` | unset |
| Generic AI Worker | `AI_GENERATE_ENDPOINT` | unset |
| R2 signed upload Worker | `R2_SIGNED_UPLOAD_ENDPOINT` | unset |
| R2 delete upload Worker | `R2_DELETE_UPLOAD_ENDPOINT` | unset |
| Mapbox tiles | `MAPBOX_ACCESS_TOKEN` | unset |
| R2 uploads | `ENABLE_R2_UPLOADS` | false |
| Image routine import | `ENABLE_IMAGE_ROUTINE_IMPORT` | false |
| Profile image upload | `ENABLE_PROFILE_IMAGE_UPLOAD` | false |
| Class timetable image import | `ENABLE_CLASS_TIMETABLE_IMAGE_IMPORT` | false |
| Hostel mess image import | `ENABLE_HOSTEL_MESS_IMAGE_IMPORT` | false |
| Skin product image import | `ENABLE_SKIN_PRODUCT_IMAGE_IMPORT` | false |
| AI coach Worker | `ENABLE_AI_COACH_WORKER` | false |

## Remote Config Kill Switches

These Remote Config defaults are intentionally release-safe. A Worker-backed
feature is available only when its dart-define endpoint/compile flag and its
Remote Config kill switch are both enabled.

| Key | Default baseline |
| --- | --- |
| `coach_enabled` | true |
| `ai_features_enabled` | false |
| `ai_coach_messages_enabled` | false |
| `ai_routine_suggestions_enabled` | false |
| `ai_identity_scoring_enabled` | false |
| `fitness_ai_feedback_enabled` | false |
| `routine_import_worker_enabled` | false |
| `r2_uploads_enabled` | false |
| `profile_image_upload_enabled` | false |
| `image_routine_import_enabled` | false |
| `class_timetable_image_import_enabled` | false |
| `hostel_mess_image_import_enabled` | false |
| `skin_product_image_import_enabled` | false |
| `mapbox_maps_enabled` | true, but still requires `MAPBOX_ACCESS_TOKEN` |

## Current Skipped Flutter Tests

`flutter test` currently reports 155 skipped tests. They are intentional
contract placeholders, but they are release coverage gaps until implemented.

| File | Skipped tests |
| --- | ---: |
| `test/services/analytics_service_contract_test.dart` | 26 |
| `test/services/coach_service_contract_test.dart` | 28 |
| `test/services/routine_import_service_contract_test.dart` | 22 |
| `test/services/routine_service_contract_test.dart` | 17 |
| `test/services/rule_engine_service_contract_test.dart` | 21 |
| `test/services/safety_router_contract_test.dart` | 21 |
| `test/services/suggestion_service_contract_test.dart` | 20 |

Missing automated coverage:

- No Flutter integration test suite for first launch, signup, onboarding,
  routine setup, tracker flows, notifications, audio, export, delete, legal
  links, offline mode, or release-build install.
- No automated real-device smoke script exists yet.

## Real-device Smoke Checklist

Run these on a physical Android device before Play Store internal testing:

1. Install release build or internal-test artifact.
2. Fresh launch succeeds without debug-only assumptions.
3. Signup/login works and lands on onboarding or the main shell as expected.
4. Complete onboarding with all AI/R2/Mapbox flags absent.
5. Create manual fixed, skin care, eating, class, and supplement routines.
6. Verify Routine timeline task start, pause, resume, complete, skip, and
   abandon actions.
7. Verify Habits and Tracker logging paths.
8. Verify Coach disabled/missing-endpoint fallback, then Worker-enabled flow
   only against a dev Worker endpoint.
9. Verify notification permission prompt, local scheduling, tap handling, and
   disabled/denied states.
10. Verify location/activity flows continue when `MAPBOX_ACCESS_TOKEN` is
    absent.
11. Verify meditation audio assets play offline.
12. Verify export data and delete account flows in a test account.
13. Verify legal/support links once Cloudflare Pages URLs exist.
14. Verify offline and poor-network behavior does not crash.

## Forbidden-service Confirmation

This baseline did not add Firebase Functions, Firebase Storage, Google Maps,
Firebase Hosting/App Hosting, Google Cloud billing services, Cloud Run, Cloud
Build, Artifact Registry, Google Cloud Secrets Manager, or Google Cloud Vision.
No Firebase or Cloudflare deploy command was run.
