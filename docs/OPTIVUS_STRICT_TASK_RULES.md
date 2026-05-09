# Optivus Strict Task Rules

## 1. Architecture Rules

- Firebase Spark only.
- Firebase is allowed only for:
  - Auth
  - Firestore
  - Analytics
  - Crashlytics
  - Remote Config
  - FCM if safe
  - App Check if safe
  - Performance Monitoring if safe
- Cloudflare Workers replace Firebase Functions.
- Cloudflare R2 replaces Firebase Storage.
- Cloudflare Pages replaces Firebase Hosting/App Hosting.
- Mapbox replaces Google Maps.
- Flutter assets are used for local meditation audio.
- No Google Cloud billing dependency is allowed.

## 2. Forbidden Services

Do not add, re-enable, deploy, depend on, or recommend these services for the Optivus MVP:

- Firebase Cloud Functions
- Firebase Storage
- Firebase App Hosting
- Firebase Hosting for this MVP
- Google Cloud Functions
- Cloud Run
- Cloud Build
- Artifact Registry
- Google Cloud Secrets Manager
- Google Maps API
- Google Cloud Vision API
- Firebase Blaze requirement
- Any service requiring Google Cloud billing

## 3. Required Worker Pattern

All AI/backend calls must follow this pattern:

Flutter app
-> sends Firebase ID token in Authorization header
-> Cloudflare Worker verifies request
-> Worker calls Gemini/OpenAI/other server APIs
-> Worker returns preview/result
-> Flutter saves reviewed final JSON to Firestore

Important:

- Do not put API keys in Flutter.
- Do not put R2 secrets in Flutter.
- Do not put Firebase service account secrets in Flutter.
- Worker should be preview-only unless a task explicitly says secure server-side write is required.

## 4. Required R2 Pattern

For image/file upload:

Flutter
-> asks Cloudflare Worker for signed R2 upload URL
-> uploads directly to R2 signed URL
-> stores only objectKey/metadata/result in Firestore
-> temporary images have cleanup plan

Important:

- No Firebase Storage.
- No base64 large images in Firestore.
- No direct R2 secret in Flutter.

## 5. Required Mapbox Pattern

- Use MAPBOX_ACCESS_TOKEN through dart-define or local env.
- Do not commit real Mapbox token.
- App must work with fallback UI if token is missing.
- GPS/running metrics must continue without map rendering.

## 6. Every Task Prompt Must Include

- Use docs/OPTIVUS_STRICT_TASK_RULES.md as rules.
- Work in planning mode first.
- Inspect files before editing.
- List files inspected.
- Give plan before code edits.
- Use existing code structure.
- Extend instead of rewrite.
- Avoid duplicate models/providers/services.
- Preserve manual/text fallback.
- Keep Spark-only architecture.
- Run flutter analyze and tests.
- Return final report.

## 7. Task Output Format

Every future task must return:

1. Files inspected
2. Files changed
3. Summary
4. Firestore paths affected
5. Cloudflare Worker endpoints affected
6. R2 paths affected
7. Events added/changed
8. Feature flags added/changed
9. Analyzer/test results
10. Manual verification steps
11. Remaining risks

## 8. Play Store Release Rules

Before Play Store upload:

- package name must not be com.example.*
- release signing must be configured
- app icon/splash/name must be final
- privacy policy URL must exist
- delete account instructions must exist
- permissions must be justified
- no debug keys/secrets committed
- flutter analyze must pass
- flutter test must pass
- Android release build must pass
- real-device smoke test must pass
