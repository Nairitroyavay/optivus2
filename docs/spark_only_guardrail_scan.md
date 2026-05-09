# Spark-only Guardrail Scan

Updated: 2026-05-09

Use this before implementation work and before Play Store release checks.
The goal is to keep Optivus on Firebase Spark-compatible infrastructure and
prevent accidental revival of Firebase Blaze-only or Google Cloud billing paths.

## Command

```sh
python3 scripts/spark_guardrail_scan.py
```

The scan fails on active forbidden dependencies, deploy targets, manifest keys,
or config references. Warning-level wording still needs manual review, but does
not by itself prove an active billing dependency.

## What Must Stay True

- `firebase.json` may deploy Firestore rules and indexes only.
- `pubspec.yaml` must not include `firebase_storage`, `cloud_functions`,
  `firebase_functions`, `google_maps_flutter`, or Google Cloud client packages.
- Android manifests must not contain Google Maps API key metadata.
- Worker configs must stay Cloudflare Worker configs only.
- `storage.rules` may remain only as an inactive legacy reference and must not
  be referenced by `firebase.json`.
- `functions/` may remain only as inactive legacy reference code. Do not deploy
  it, port new work into it, or use it as the target for future backend tasks.

## Allowed Active Architecture

- Firebase Spark: Auth, Firestore, Analytics, Crashlytics, Remote Config, FCM,
  and App Check when they remain Spark-safe.
- Cloudflare Workers: backend, AI, API proxy, scheduled backend work, and any
  server-side secret handling.
- Cloudflare R2: image and file object storage through signed Worker endpoints.
- Cloudflare Pages: legal, privacy, support, and other static web pages.
- Mapbox: maps through `MAPBOX_ACCESS_TOKEN`, with non-map GPS fallbacks.
- Flutter assets: meditation audio bundled with the app.

## Allowed Legacy References

References to Firebase Cloud Functions, Firebase Storage, Google Maps,
Firebase Hosting/App Hosting, Cloud Run, Cloud Build, Artifact Registry, Google
Cloud Secret Manager, Google Cloud Vision, or Blaze are allowed only when the
surrounding text clearly says one of the following:

- the service is forbidden or disallowed;
- the reference is historical, legacy, or inactive;
- the replacement is Cloudflare Workers, Cloudflare Cron Triggers, Cloudflare
  R2, Cloudflare Pages, or Mapbox;
- the code is rejecting an unsupported URL or deploy path.

## Manual Checklist

1. Run `python3 scripts/spark_guardrail_scan.py`.
2. Confirm `firebase.json` contains no `functions`, `storage`, `hosting`, or
   `apphosting` deploy target.
3. Confirm `pubspec.yaml` contains no forbidden Firebase/Google Maps package.
4. Confirm Android manifests contain no Google Maps API key metadata.
5. Confirm Workers use `Authorization: Bearer <Firebase ID token>` where user
   scope matters and keep provider/API keys in Wrangler secrets.
6. Confirm `functions/README.md` and `functions/package.json` still label the
   directory as legacy Spark-inactive and keep deploy scripts disabled.
7. Confirm warnings from the scan are either prohibition/legacy text or queued
   for cleanup in the relevant task.

## Current Legacy Queue

- `functions/` is inactive legacy Firebase Functions reference code.
- `storage.rules` is inactive legacy Firebase Storage rules text.
- Historical planning/audit docs may mention forbidden services only under
  Spark-only override labels.
- Active Flutter comments that mention Cloud Functions should be rewritten when
  their owning implementation task touches the file.

## Release Gate

Before Play Store release work, the scan must show no failures. The only
expected warning in the current repo is the inactive `storage.rules` reminder.
Any warning outside docs, todo files, legacy `functions/`, or explicit rejection
code must be reviewed as a possible active forbidden-service reference.
