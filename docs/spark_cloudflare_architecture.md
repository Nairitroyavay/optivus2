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

## Current Service Labels

- `firebase.json` is allowed to reference only `firestore.rules` and
  `firestore.indexes.json` as Firebase deploy targets.
- `storage.rules` is inactive legacy text and must stay unreferenced by
  `firebase.json`.
- `functions/` is inactive legacy Firebase Functions reference code. Keep it as
  migration context only until a removal task deletes it; do not add new backend
  work there.
- `workers/` contains the active backend/API proxy packages.
- Public legal and support pages belong on Cloudflare Pages, not Firebase
  Hosting/App Hosting.

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
tests. Routine import, coach reply, and AI gateway Workers require Firebase ID
tokens, keep provider secrets server-side, apply per-user preview rate limits,
and return preview-only JSON. Flutter saves any reviewed final JSON to
Firestore.

## Guardrail Scan

Run this before implementation work and before release checks:

```sh
python3 scripts/spark_guardrail_scan.py
```

The scan fails on active forbidden Firebase/Google billing deploy targets,
packages, manifest keys, or config references. See
`docs/spark_only_guardrail_scan.md` for the manual checklist and the allowed
legacy-reference rules.
