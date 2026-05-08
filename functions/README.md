# Legacy Firebase Functions Reference

This directory is retained only as Spark-inactive reference code while backend
work moves to Cloudflare Workers and Cron Triggers.

Do not deploy this directory with Firebase. Firebase Cloud Functions require
Blaze billing and are outside the Optivus Spark-only architecture.

Active backend targets:

- Flutter client uses Firebase Auth and Firestore directly.
- AI and routine import endpoints run on Cloudflare Workers.
- Object upload work must use Cloudflare R2 signed upload endpoints when those
  endpoints are implemented.
