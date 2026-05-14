# AI Coach Reply Worker Setup

The AI coach reply feature uses a Cloudflare Worker. Flutter sends the user's
Firebase ID token to the Worker, and the Worker calls Gemini with the API key
stored only as a Worker secret.

## Worker Commands

From the repo root:

```bash
cd workers/coach-reply-worker
npm install
npm test
npx wrangler dev
npx wrangler deploy
```

Set production secrets before deploy:

```bash
npx wrangler secret put GEMINI_API_KEY
npx wrangler secret put FIREBASE_PROJECT_ID
```

Optional rate limit secret:

```bash
npx wrangler secret put COACH_REPLY_RATE_LIMIT_PER_MINUTE
```

## Required Worker Secrets

- `GEMINI_API_KEY`: Gemini API key. This must never be added to Flutter.
- `FIREBASE_PROJECT_ID`: Firebase project ID used to verify Firebase ID tokens.
- `COACH_REPLY_RATE_LIMIT_PER_MINUTE`: optional per-user limit. Defaults to 30.

Optional Worker variable in `wrangler.toml`:

- `GEMINI_MODEL`: defaults to `gemini-1.5-flash` when not set.

## Flutter Dart Define

Enable the endpoint at build/run time:

```bash
/Users/roy/flutter/bin/flutter run \
  --dart-define=ENABLE_AI_COACH_WORKER=true \
  --dart-define=COACH_REPLY_ENDPOINT="https://YOUR_WORKER_URL"
```

Only `COACH_REPLY_ENDPOINT` is required for this feature's endpoint. Do not pass
the Gemini API key to Flutter.

## Remote Config Flags

Set these Firebase Remote Config values to enable AI replies:

- `coach_enabled`: `true`
- `ai_features_enabled`: `true`
- `ai_coach_messages_enabled`: `true`

The feature is active only when Remote Config flags are on, Flutter is built
with `ENABLE_AI_COACH_WORKER=true`, and `COACH_REPLY_ENDPOINT` is non-empty.

## Local Development Endpoint

Run local Worker dev:

```bash
cd workers/coach-reply-worker
npx wrangler dev --local --port 8787
```

For a desktop Flutter target:

```bash
--dart-define=COACH_REPLY_ENDPOINT="http://127.0.0.1:8787"
```

## Android Emulator Endpoint

The Android emulator reaches the host machine at `10.0.2.2`:

```bash
--dart-define=COACH_REPLY_ENDPOINT="http://10.0.2.2:8787"
```

## Real Phone Endpoint

A real phone cannot use `127.0.0.1` or `10.0.2.2` for the dev machine. Use one
of these:

- Deployed Worker URL, for example `https://optivus-coach-reply.<account>.workers.dev`
- A temporary HTTPS tunnel that points to local Wrangler dev
- A LAN URL only if the phone and dev machine are on the same network and the
  local firewall permits access

Example:

```bash
/Users/roy/flutter/bin/flutter run -d RMX2001 \
  --dart-define=ENABLE_AI_COACH_WORKER=true \
  --dart-define=COACH_REPLY_ENDPOINT="https://optivus-coach-reply.<account>.workers.dev"
```
