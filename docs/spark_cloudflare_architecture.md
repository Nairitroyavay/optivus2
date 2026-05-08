# Spark + Cloudflare Architecture

Updated: 2026-05-08

Optivus is targeting Firebase Spark-compatible infrastructure. Do not add or
deploy features that require Google Cloud billing.

## Allowed Firebase Products

- Firebase Auth
- Cloud Firestore
- Crashlytics
- Remote Config
- App Check and FCM when already wired safely
- Analytics only if it is already configured without adding billing risk

## Disallowed Google Billing Paths

- Firebase Cloud Functions
- Firebase Cloud Storage
- Firebase Hosting or App Hosting
- Google Maps API
- New Google Cloud services that require billing

## Active Backend Pattern

Flutter talks directly to Firebase Auth and Firestore for client-owned data.
Server-only work runs on Cloudflare Workers or Cloudflare Cron Triggers.
Workers verify Firebase ID tokens from the `Authorization: Bearer <token>`
header before doing user-scoped work.

AI provider keys live only in Cloudflare Worker secrets. Flutter must never
ship AI provider keys.

## Uploads And Images

Firebase Storage is inactive. Image upload and image import features stay behind
feature flags until Cloudflare R2 signed upload endpoints exist.

Required flags default to false:

- `ENABLE_R2_UPLOADS`
- `ENABLE_IMAGE_ROUTINE_IMPORT`
- `ENABLE_PROFILE_IMAGE_UPLOAD`
- `ENABLE_CLASS_TIMETABLE_IMAGE_IMPORT`
- `ENABLE_HOSTEL_MESS_IMAGE_IMPORT`
- `ENABLE_SKIN_PRODUCT_IMAGE_IMPORT`
- `ENABLE_AI_COACH_WORKER`

Disabled image flows must show a Coming Soon message and keep manual/text
alternatives working.

## Maps

Google Maps API is inactive. Map UI may use Mapbox tiles only through
`MAPBOX_ACCESS_TOKEN`. If the token is absent, live GPS metrics and saved
activity stats must still work without rendering a map.

## Deploy Rules

Allowed Firebase deploy scope:

```sh
firebase deploy --only firestore:rules,firestore:indexes
```

Do not run Firebase deploys for functions, storage, hosting, or apphosting.

Cloudflare Workers are deployed separately with Wrangler after review and
tests. The routine import Worker is MVP preview-only: it returns suggestions to
Flutter, and Flutter saves the reviewed final JSON.
