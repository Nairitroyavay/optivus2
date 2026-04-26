# Optivus — System Design Document

**Document version:** 2.0
**Last updated:** April 2026
**Companion to:** *Optivus PRD*, *Optivus UserFlow*, *Optivus EventSystem*
**Audience:** Senior engineers, CTOs, technical reviewers
**Scope target:** 100K → 1M users; no large-scale rewrites along the way

---

## 1. System overview

### 1.1 What this document is

This is the technical blueprint for building Optivus as a real product, not a prototype. It assumes you've read the PRD, User Flow, and Event System docs — those tell you **what** to build. This tells you **how it actually works** under load: where data lives, how events propagate, how the system stays consistent across devices and offline windows, and how it scales from 100 to 1,000,000 users without a rewrite.

It is opinionated. Every choice is justified.

### 1.2 The 30-second mental model

Optivus is a **mobile-first, event-sourced, offline-first system**. A Flutter app on each user's phone is the primary interface; a Firebase backend is the source of truth; Cloud Functions handle anything that needs to happen server-side; BigQuery archives the long tail of events for analytics and AI training. There is no traditional REST/GraphQL API — clients talk directly to Firestore over its native SDK, which gives you offline persistence, real-time sync, and binary-protocol efficiency for free.

```
┌─────────────────────────────────────────────────────────┐
│                  USER'S PHONE                            │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Flutter App                                        │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────────────┐ │  │
│  │  │ UI Layer │◄─┤Service   │◄─┤Local Event Bus   │ │  │
│  │  │(Riverpod)│  │Layer     │  │(in-memory)       │ │  │
│  │  └──────────┘  └─────┬────┘  └──────────────────┘ │  │
│  │                      │                              │  │
│  │  ┌───────────────────▼─────────────────────────┐   │  │
│  │  │   Firestore SDK (offline cache + sync)      │   │  │
│  │  └───────────────────┬─────────────────────────┘   │  │
│  └──────────────────────┼─────────────────────────────┘  │
└─────────────────────────┼────────────────────────────────┘
                          │ encrypted, authenticated
                          ▼
┌─────────────────────────────────────────────────────────┐
│                  FIREBASE BACKEND                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ Firebase     │  │ Firestore    │  │ FCM          │  │
│  │ Auth         │  │ (hot data)   │  │ (push)       │  │
│  └──────────────┘  └──────┬───────┘  └──────────────┘  │
│                            │ triggers                    │
│                            ▼                             │
│  ┌──────────────────────────────────────────────────┐   │
│  │ Cloud Functions (event processors, schedulers)   │   │
│  └──────┬─────────────────────┬──────────────────┬──┘   │
│         │                     │                  │      │
│         ▼                     ▼                  ▼      │
│  ┌─────────────┐      ┌──────────────┐   ┌──────────┐   │
│  │ Cloud Tasks │      │ BigQuery     │   │ Gemini   │   │
│  │ (scheduling)│      │ (cold/AI)    │   │ API      │   │
│  └─────────────┘      └──────────────┘   └──────────┘   │
└─────────────────────────────────────────────────────────┘
```

### 1.3 Two invariants the entire system depends on

These are the rules everything else is built on. Violate either of them and the system breaks at scale.

1. **Firestore is the source of truth, not the local stream.** The local event bus on the device is a fast-path optimization for UI responsiveness. It is *not* authoritative. State changes are durable only after they're committed to Firestore.
2. **Service A never calls Service B directly.** All cross-service communication happens through events. This is what enables Cloud Functions, AI coach, analytics, and future services to plug in without modifying existing code.

### 1.4 Hot path vs cold path

A core design decision: data is split by access pattern.

| | Hot path | Cold path |
|---|---|---|
| **Stores** | Firestore | BigQuery |
| **Holds** | Recent events (90 days), current state, all user-facing data | Archived events, aggregates, ML feature data |
| **Optimized for** | Real-time reads/writes, offline sync | Analytics, training, large scans |
| **Cost shape** | Per-operation | Per-byte-scanned |
| **Read pattern** | Apps query directly | Cloud Functions and analysts only |

Without this split, the events collection grows unbounded and Firestore costs become the largest line item by month 6.

---

## 2. Architecture design

### 2.1 Tech stack and rationale

| Layer | Choice | Why |
|---|---|---|
| **Mobile** | Flutter (Android first, iOS later) | Single codebase, native performance, mature Firebase SDK |
| **State management** | Riverpod | Compile-time safety, testability, works with streams |
| **Routing** | GoRouter | Declarative, deep-link friendly |
| **Local DB / cache** | Firestore offline persistence | Free with the SDK; no separate Hive/SQLite needed for MVP |
| **Auth** | Firebase Auth (Email + Google + Apple) | Drops in, integrates with security rules, free up to 50K MAU |
| **Primary DB** | Cloud Firestore | Real-time sync, offline cache, scales to multi-region |
| **Server compute** | Cloud Functions (Gen 2) | Event-triggered, no infra to manage, autoscale |
| **Scheduling** | Cloud Tasks + Cloud Scheduler | Per-user time-zoned schedules; reliable at scale |
| **Analytics warehouse** | BigQuery | Native Firestore export, cheap at scale, SQL access for AI features |
| **Push** | Firebase Cloud Messaging | Universal, reliable, integrated |
| **Local notifications** | `flutter_local_notifications` + AlarmManager | For deterministic on-device reminders that survive offline |
| **AI** | Gemini API via Cloud Function | API key never exposed to client |
| **Crash + perf** | Firebase Crashlytics + Performance Monitoring | Free tier sufficient at all scales |
| **Feature flags** | Firebase Remote Config | Runtime config without app updates |
| **App integrity** | Firebase App Check | Prevents API abuse from stolen client tokens |

### 2.2 No traditional API layer — and why that's correct

A common reflex is to put a Node.js or Go API in front of the database. **Don't.** The Firestore SDK *is* the API for clients. It gives you:

- Wire-compatible offline cache (write while offline, sync when online)
- Real-time subscriptions (`.snapshots()`) replacing WebSocket plumbing you'd have to build
- Built-in auth integration (security rules enforce access)
- Multi-region replication
- Binary protocol (~5x lighter than equivalent JSON over REST)

A custom REST/GraphQL layer would add 50+ ms latency, require its own scaling, and duplicate features Firebase already provides. Use Cloud Functions for the things SDKs can't do (server-only logic, secrets, AI calls). Use Firestore for everything else.

**The exception:** if you ever need a public API (for partners, integrations, or a web extension), build a thin Cloud Functions HTTP layer at that point — never speculatively.

### 2.3 Real-time vs batch boundaries

| Concern | Pattern | Why |
|---|---|---|
| User-visible state changes (task completed, habit logged) | Real-time, write to Firestore immediately | UI must respond in <100ms |
| Streak rollup at day-close | Batch, runs once per user per day | No need for sub-second precision on a once-daily compute |
| Notification scheduling for tomorrow | Batch, pre-scheduled at day-close | Removes per-event scheduling cost |
| Event archival to BigQuery | Batch, hourly Cloud Function | BigQuery streaming inserts are expensive; batched are 100x cheaper |
| AI coach suggestions | Pre-computed at day-start, cached | Generating live on every screen open is cost-prohibitive |
| Crash and perf telemetry | Async, fire-and-forget | Not user-facing; eventual consistency fine |

### 2.4 Client-side architecture inside the Flutter app

The app itself follows a layered architecture:

```
   ┌────────────────────────────────────────────────────┐
   │  UI Layer (Widgets)                                 │
   │  - Stateless widgets only                           │
   │  - Subscribe to Riverpod providers                  │
   └────────────────────┬───────────────────────────────┘
                        │
   ┌────────────────────▼───────────────────────────────┐
   │  Presentation Layer (Riverpod providers)            │
   │  - Combine multiple streams into UI-ready models    │
   │  - Cache derived values (mission ring %, etc.)      │
   └────────────────────┬───────────────────────────────┘
                        │
   ┌────────────────────▼───────────────────────────────┐
   │  Service Layer (TaskService, HabitService, ...)     │
   │  - Orchestrate writes                               │
   │  - Emit events                                      │
   │  - Subscribe to events                              │
   └────────────────────┬───────────────────────────────┘
                        │
   ┌────────────────────▼───────────────────────────────┐
   │  Data Layer                                         │
   │  - Firestore SDK (primary)                          │
   │  - LocalEventBus (in-memory, for fast UI)           │
   │  - SecureStorage (auth tokens, device id)           │
   └────────────────────────────────────────────────────┘
```

The local event bus is a `StreamController.broadcast()` that fires *immediately* after a Firestore write resolves. Listeners get the new event before Firestore's snapshot listeners (which add ~50ms round-trip). This is what makes the UI feel instant while still keeping Firestore as source of truth.

---

## 3. Core modules

The system is divided into seven logical modules. Each owns specific data and emits/consumes specific events. Modules are not necessarily separate services — most are just well-bounded code in the same Flutter binary, but the boundaries make it possible to extract any of them later.

### 3.1 User Management module

**Owns:** authentication, user profile, device registration, account lifecycle

**Responsibilities:**
- Sign-up / log-in / sign-out flows
- Profile creation and editing (biometrics, accountability, coach config)
- Multi-device support (a user with both phone and tablet)
- Account deletion with 7-day soft-delete window
- Token refresh and session management

**Data owned:**
- `users/{uid}` — main profile document
- `users/{uid}/devices/{deviceId}` — registered devices for FCM and event source tracking
- `users/{uid}/sessions/{sessionId}` — active sessions (last 5)

**Emits:** `user_signed_up`, `profile_updated`, `biometrics_updated`, `account_deleted`

**Listens to:** none

### 3.2 Habit System module

**Owns:** good and bad habits, log entries, type-specific logic for the 10 tracker types

**Responsibilities:**
- CRUD on habits
- Log good habits, slip events, undo logs
- Run type-specific validation (no calorie data if eating-disorder flag is set)
- Compute today's running totals
- Auto-detect procrastination from event log
- Auto-import phone usage from Android `UsageStatsManager`

**Data owned:**
- `users/{uid}/habits/{habitId}`
- `users/{uid}/habits/{habitId}/logs/{logId}` — partitioned by date for query efficiency

**Emits:** `good_habit_logged`, `bad_habit_slip_logged`, `habit_log_deleted`, `slip_streak_detected`

**Listens to:** `task_started` (for procrastination detection), `task_abandoned` (same)

### 3.3 Task System module

**Owns:** scheduled blocks, the start/complete/abandon state machine, subtasks

**Responsibilities:**
- Generate today's tasks from the user's weekday template
- Manage state transitions: Scheduled → Started → Completed/Abandoned/Paused
- Auto-abandon stale tasks (planned end + 90 min, no start)
- Auto-complete when all subtasks checked
- Capture plan-vs-actual durations for AI learning

**Data owned:**
- `users/{uid}/tasks/{taskId}` — keyed by `{routineType}_{YYYYMMDD}_{slot}` for easy debug
- `users/{uid}/taskOutcomes/{taskId}` — append-only outcome record

**Emits:** `task_scheduled`, `task_started`, `task_completed`, `task_abandoned`, `task_paused`, `task_resumed`, `subtask_checked`

**Listens to:** `day_started` (generate today's tasks if not already), `suggestion_accepted` (mutate plan)

### 3.4 Identity & Goal System module

**Owns:** long-term identities, milestone tracking, identity scoring

**Responsibilities:**
- Manage user's selected identities (Strong Body, Top Student, etc.)
- Compute identity scores from contributing habits and routines (weighted)
- Track milestones (manual + auto-detected from biometrics)
- Provide the "Why this score?" transparency layer

**Data owned:**
- `users/{uid}/identities/{identityId}`
- `users/{uid}/identities/{identityId}/milestones/{milestoneId}`

**Emits:** `identity_progress_changed`, `milestone_completed`

**Listens to:** `task_completed`, `task_abandoned`, `good_habit_logged`, `bad_habit_slip_logged`, `routine_day_summarized`, `biometrics_updated`

### 3.5 Event Tracking module

**Owns:** the event log itself — the system's nervous system

**Responsibilities:**
- Validate every event against its schema (one of 30+ event types, versioned)
- Write to Firestore with idempotency keys
- Broadcast to local subscribers
- Maintain time-sharded structure to prevent unbounded collection growth
- Drive Cloud Function triggers

**Data owned:**
- `users/{uid}/events_recent/{eventId}` — last 7 days, queried by clients
- `users/{uid}/events_archive/{YYYYMM}/items/{eventId}` — 8–90 days old
- BigQuery `optivus.events` table — 90+ days

**Emits:** every event flows through here
**Listens to:** none directly; it *is* the bus

### 3.6 Analytics & Insights module

**Owns:** derived metrics, weekly/monthly summaries, AI-readable feature stores

**Responsibilities:**
- Compute Mission ring %, routine completion %, streak rollups
- Generate weekly Strengths / Areas-to-Improve cards
- Detect patterns (Monday-morning slips, gym-day correlations)
- Build feature vectors for the future AI coach

**Data owned:**
- `users/{uid}/dailySummaries/{YYYY-MM-DD}` — locked at day_closed
- `users/{uid}/weeklySummaries/{YYYY-WXX}`
- BigQuery aggregate tables

**Emits:** `routine_day_summarized`, `weekly_insight_ready`

**Listens to:** `day_closed`, `task_completed`, `task_abandoned`, all habit events

### 3.7 Notification System module

**Owns:** every notification scheduled or delivered, across local and FCM channels

**Responsibilities:**
- Schedule local notifications via `flutter_local_notifications`
- Send pushes via FCM for re-engagement and AI nudges
- Persist scheduled notifications to Firestore (for survival across reinstalls/restarts)
- Apply the 6-tier priority ladder, frequency caps, and silence windows
- Re-register all scheduled notifications on app start

**Data owned:**
- `users/{uid}/scheduledNotifications/{notifId}` — durable record
- `users/{uid}/notificationLog/{notifId}` — what was sent, tapped, dismissed

**Emits:** `notification_scheduled`, `notification_sent`, `notification_tapped`, `notification_suppressed`

**Listens to:** `task_scheduled`, `task_started`, `task_completed`, `bad_habit_slip_logged`, `suggestion_generated`

---

## 4. Database design

### 4.1 Why Firestore (and what to watch out for)

Firestore is the right primary datastore because it gives offline persistence, real-time subscriptions, multi-region replication, and security rules in one product. But it has known footguns at scale:

- Per-document write rate limit: 1 write/sec sustained (hot keys can throttle)
- Per-collection-group query: 500 docs/sec on indexed queries
- Composite indexes must be declared in advance; queries fail without them
- Subcollections don't reduce parent document size
- Listening to a large collection re-downloads everything on first connect

The schema below is designed around these constraints.

### 4.2 Top-level collection map

```
users/{uid}
   ├── profile fields (denormalized)
   │
   ├── devices/{deviceId}
   ├── sessions/{sessionId}
   │
   ├── habits/{habitId}
   │     └── logs/{YYYY-MM-DD}/items/{logId}    ◄── time-bucketed
   │
   ├── tasks/{taskId}
   ├── taskOutcomes/{taskId}
   │
   ├── routines/{routineType}                    ◄── single doc per type
   │
   ├── streaks/{habitId}
   │
   ├── identities/{identityId}
   │     └── milestones/{milestoneId}
   │
   ├── events_recent/{eventId}                   ◄── 7 days only, TTL'd
   ├── events_archive/{YYYYMM}/items/{eventId}   ◄── monthly buckets
   │
   ├── dailySummaries/{YYYY-MM-DD}
   ├── weeklySummaries/{YYYY-WXX}
   │
   ├── scheduledNotifications/{notifId}
   ├── notificationLog/{notifId}
   │
   └── suggestions/{suggestionId}                ◄── AI writes here

config/                                          ◄── global, read-only
   ├── habitPresets/{presetId}
   ├── identityPresets/{presetId}
   └── healthMilestones/{milestoneId}
```

### 4.3 Critical schema patterns

#### Schema versioning on every document

Every document includes:
```
{
  schemaVersion: 1,
  ...
}
```

When a schema change is needed: increment to 2, write a migration Cloud Function that reads `schemaVersion: 1` docs and rewrites them. Clients support both versions during the migration window. Without this, every schema change becomes a downtime event.

#### Time-bucketed subcollections for high-write data

Habit logs and events are written constantly. Storing them in a flat collection causes:
- Slow queries (must scan large collection)
- Expensive listeners (re-downloads on every change)
- Cost at scale

**Solution:** bucket by month or day.

```
habits/{habitId}/logs/2026-04-25/items/{logId}    ← daily bucket
events_archive/202604/items/{eventId}             ← monthly bucket
```

This keeps each subcollection small (hundreds of docs, not millions) and makes archival trivial — to delete old data, you delete the bucket document.

#### Denormalized profile data on user document

`users/{uid}` stores fields the client reads on every screen (name, coach config, accountability, identities list). This is a deliberate denormalization. Reading 5 separate documents for one home screen render at 1M users would cost more than the entire Firestore bill should be.

#### Write coalescing for active counters

Bad pattern: incrementing `today_total` on the habit document for every log → hot key → throttling.

Good pattern: each log is its own document; the running total is computed by summing today's bucket on read. Cache the result in a Riverpod provider; it auto-updates via the Firestore listener.

### 4.4 Field shapes (most important documents)

#### `users/{uid}` (denormalized profile)

```
{
  schemaVersion: 1,
  uid: "abc123",
  email: "user@example.com",
  name: "Nairit",
  createdAt: timestamp,
  
  onboarding: {
    completed: true,
    completedAt: timestamp,
    version: "v1.0"
  },
  
  profile: {
    coachName: "Bro",
    coachStyle: "tough_love",
    accountability: "strict",
    timezone: "Asia/Kolkata",
    locale: "en-IN"
  },
  
  biometrics: {
    dob: timestamp,
    gender: "male",
    heightCm: 175,
    weightKg: 50,
    targetWeightKg: 62,
    activityLevel: "lightly_active",
    waterTargetMl: 2800,
    updatedAt: timestamp
  },
  
  lifestyle: {
    wakeTime: "07:00",
    sleepTime: "23:00",
    occupation: "student"
  },
  
  identities: ["strong_body", "top_student", "become_disciplined"],
  healthFlags: [],
  
  // Operational
  lastDayClosed: "2026-04-24",          // ★ idempotent day-close
  lastSeenAt: timestamp,
  notificationBudget: 8,
  
  // For re-engagement
  engagementState: "active",            // active | silent | ghost | dormant
  ghostDayCount: 0
}
```

#### `users/{uid}/tasks/{taskId}`

```
{
  schemaVersion: 1,
  taskId: "fixed_2026_04_25_gym",
  type: "fixed",
  parentRoutine: "fixed",
  title: "Gym",
  emoji: "🏋",
  identityTags: ["strong_body"],
  alarmTier: "custom",
  
  plannedStart: timestamp,
  plannedEnd: timestamp,
  
  state: "completed",
  actualStart: timestamp,
  actualEnd: timestamp,
  actualDurationMin: 82,
  driftPct: 0.367,
  
  subtasks: [
    { id: "s1", title: "Warmup", checked: true },
    { id: "s2", title: "Lifts", checked: true }
  ],
  
  reasonTag: null,
  
  createdAt: timestamp,
  updatedAt: timestamp
}
```

#### `users/{uid}/events_recent/{eventId}`

```
{
  schemaVersion: 1,
  eventId: "evt_abc123",                // also doc ID, idempotent
  eventName: "task_completed",
  ts: serverTimestamp,
  deviceLocalTs: clientTimestamp,
  source: "ui",                         // ui | system | ai
  deviceId: "device_xyz",
  payloadVersion: 1,
  payload: { ... event-specific ... }
}
```

#### `users/{uid}/streaks/{habitId}`

```
{
  schemaVersion: 1,
  habitId: "hydration",
  currentCount: 18,
  longestCount: 42,
  lastHitDate: "2026-04-25",
  lastBreakDate: "2026-03-12",
  state: "active",                      // active | paused | broken | fresh
  pausedAt: null,
  prePauseCount: null,
  weeklySkipsUsed: { "2026-W17": 0 },   // for Forgiving accountability
  updatedAt: timestamp
}
```

### 4.5 Indexing strategy

These composite indexes must be declared in `firestore.indexes.json` from day one. Skipping any of them causes runtime query failures in production.

| Collection | Fields | Used by |
|---|---|---|
| `tasks` | `state ASC, plannedStart ASC` | "Show me today's scheduled tasks" |
| `tasks` | `parentRoutine ASC, plannedStart DESC` | Routine tab filter views |
| `events_recent` | `eventName ASC, ts DESC` | Service replay on app start |
| `events_recent` | `source ASC, ts DESC` | Debug & analytics |
| `habits/{habitId}/logs/{date}/items` | `ts ASC` | Today's log timeline |
| `scheduledNotifications` | `state ASC, fireAt ASC` | "What's coming up" |
| `dailySummaries` | `date DESC` | Tracker week/month views |

### 4.6 BigQuery schema (cold storage + analytics)

Firestore exports daily to BigQuery via the official extension. The `events` archive is your AI training data — design it well now.

```sql
TABLE optivus.events (
  event_id        STRING,
  user_id         STRING,
  event_name      STRING,
  ts              TIMESTAMP,
  device_id       STRING,
  source          STRING,
  payload         JSON,
  schema_version  INT64,
  
  -- Partitioning + clustering for cost control
)
PARTITION BY DATE(ts)
CLUSTER BY user_id, event_name
```

Partitioning on `ts` and clustering on `user_id` keeps query cost low — most analytics queries are scoped to one user or one day.

---

## 5. Event system integration

This section addresses every gap from the architectural review of the prior MVP design.

### 5.1 The corrected mental model — Firestore is source of truth

```
User taps "Mark complete"
        │
        ▼
┌───────────────────────────────────────────┐
│ TaskService.completeTask(taskId)          │
│                                           │
│ 1. Build event object with idempotency_id │
│ 2. WriteBatch:                            │
│    - update task doc (state = completed)  │
│    - write event doc (events_recent/)     │
│ 3. Commit atomically                      │
└───────────────────┬───────────────────────┘
                    │
        ┌───────────┴───────────┐
        ▼                       ▼
  Local fast-path          Firestore commit
  (in-memory bus)          (durable)
        │                       │
        ▼                       ▼
  UI updates instantly    Cloud Function trigger
  (Mission ring,          (streak update,
   active task bar)        notification cancel)
```

Two things land in parallel:
1. The local in-memory event bus fires *immediately* — UI animates without waiting for Firestore round-trip
2. Firestore commits the change durably; this triggers Cloud Functions for any server-side reactions

If the app crashes between step 1 and the Firestore commit, the WriteBatch ensures atomicity — either both writes (task + event) succeed, or both fail. There is no partial state.

### 5.2 Idempotency

Every event includes a deterministic `event_id` that the client generates:

```
event_id = sha256(user_id + event_name + ts_to_second + payload_hash)
```

If the same event is emitted twice (network retry, user double-tap), Firestore's "create with specific doc ID" rejects the duplicate. Cloud Functions triggered by event creation use the doc ID as their dedup key.

**This eliminates a class of bugs that plague event-sourced systems** — duplicate streak increments, double-counted habit logs, repeated notifications.

### 5.3 Event replay on app start (the consistency layer)

When the app launches:

```
1. Firestore SDK syncs offline queue (any writes made offline)
2. Read users/{uid}.lastDayClosed
3. Read users/{uid}/events_recent ordered by ts, last 50
4. For each unprocessed event (compared against local processed_events_log):
     dispatch to listeners (Mission ring, streak service, etc.)
5. Mark them processed locally
```

This is the **safety net**: if the device was killed mid-flow, if a Cloud Function failed silently, if the user reinstalled — all derived state is reconstructed from the event log on next launch.

### 5.4 Day-close — the most critical idempotent operation

The earlier MVP design said *"runs on first app open after midnight."* That's incomplete. Real flow:

```
On every app open + once daily via Cloud Scheduler:

1. Read users/{uid}.lastDayClosed
2. Compute todayInUserTimezone
3. WHILE lastDayClosed < (todayInUserTimezone - 1):
     missedDate = lastDayClosed + 1
     runDayCloseRollup(missedDate)
     update users/{uid}.lastDayClosed = missedDate
     emit "day_closed" with payload.date = missedDate
```

**Why the WHILE loop:** if a user is offline for 4 days and returns, the system needs to roll up day-close for each missed day in order. Streaks pause at day 3 per the engagement-state machine, but the rollups still happen so the audit trail is complete.

**Why both client-side and Cloud Scheduler:** the client handles the common case (user opens app daily). The Cloud Scheduler runs at 3am user-local-time as a safety net for users who haven't opened the app — this fires `ghost_day_detected` events and updates engagement state without requiring the user's presence.

### 5.5 Event bus channels and listener registration

Inside the Flutter app, the local bus is a single `StreamController<Event>.broadcast()`. Listeners filter by event name:

```
class EventBus {
  final _ctrl = StreamController<Event>.broadcast();
  
  void emit(Event e) => _ctrl.add(e);
  
  Stream<Event> on(String name) =>
      _ctrl.stream.where((e) => e.name == name);
  
  Stream<Event> onAny() => _ctrl.stream;
}
```

Each service registers its listeners in its constructor. Riverpod owns service lifecycles, so subscriptions are cleaned up on dispose automatically. There is no manual unsubscribe management.

### 5.6 Cloud Function triggers (server-side listeners)

Critical reactions also run server-side, triggered by Firestore writes. This is the safety net for when the client doesn't react (offline at the moment, app killed, different device).

| Trigger | Cloud Function | What it does |
|---|---|---|
| Write to `events_recent/` where `eventName == "day_closed"` | `processDayClose` | Re-validate streak rollup; trigger weekly summary if Sunday |
| Write to `events_recent/` where `eventName == "task_completed"` | `updateAggregates` | Update analytics aggregates for this user |
| Write to `events_recent/` where `eventName == "bad_habit_slip_logged"` | `aiCoachReact` | Queue AI response (future feature, hook exists today) |
| Hourly schedule | `archiveEvents` | Move events_recent docs older than 7 days to events_archive |
| Daily 3am UTC | `globalDayCloseSweep` | Find users where lastDayClosed < yesterday and force a rollup |

### 5.7 Schema versioning for events

Each event has both `schemaVersion` (the document) and `payloadVersion` (the payload shape). When you change a payload:

- Add the new payload format under `payloadVersion: 2`
- Cloud Functions and clients support both
- After 60 days (rolling out new app version + clients updated), drop `payloadVersion: 1` support
- Migrate the event_archive lazily

This is how you evolve event schemas without breaking historical data.

### 5.8 Addressing the original critique points

| Critique | Resolution in this design |
|---|---|
| Client-only event system | §5.1 — Firestore is source of truth; local bus is fast-path only |
| Day-close incomplete | §5.4 — `lastDayClosed` field + while-loop + Cloud Scheduler safety net |
| Events collection unbounded | §4.2 — time-bucketed `events_recent` (7d) + `events_archive` (90d) + BigQuery (forever) |
| Missing sync layer | §5.3 — event replay on app start reconstructs state from event log |
| Notifications break on reinstall | §3.7 — `scheduledNotifications` collection persists; re-register on app start |
| No schema versioning | §4.3 — `schemaVersion` on every doc, `payloadVersion` on events |
| "Service A calls Service B" | §1.3 — invariant; enforced by code review and module boundaries |

---

## 6. Data flow

Three end-to-end flows. These are the patterns; every other flow in the app follows the same shape.

### 6.1 User completes a habit (water +500ml)

```
Step 1 — User taps "+500ml" on Hydration card
    ▼
Step 2 — UI calls HabitService.logGood(habitId, 500, "ml")
    ▼
Step 3 — HabitService builds:
    log = { amount: 500, unit: "ml", ts: serverTimestamp }
    event = { eventName: "good_habit_logged", payload: {habitId, amount:500, ...} }
    eventId = deterministic_hash(uid, "good_habit_logged", ts, payload)
    ▼
Step 4 — Firestore WriteBatch (atomic):
    create  habits/hydration/logs/2026-04-25/items/{logId}
    create  events_recent/{eventId}                       ← idempotent
    ▼
Step 5 — Local event bus fires "good_habit_logged" instantly
    ▼ (parallel listeners)
    │
    ├── HydrationProvider re-reads today bucket → emits new total → UI ring fills
    │
    ├── MissionRingProvider recomputes today's % (no DB read; uses cached value + delta)
    │
    └── (Listener registered for streak rollup deferred to day_close — does nothing now)
    ▼
Step 6 — Firestore commit completes (50–200ms typical)
    ▼
Step 7 — Cloud Function trigger fires (server-side):
    archiveEvents marks event for next hourly archive
    updateAggregates increments user's daily-summary aggregate (writes back to dailySummaries/{date})
    ▼
Step 8 — Tracker tab listening on dailySummaries auto-updates the weekly chart
```

**Latency:** UI feels updated in <16ms (one frame). Durability achieved in ~150ms. Server-side aggregates lag by ~500ms but are not user-blocking.

### 6.2 User skips a task (auto-abandon scenario)

```
Step 1 — Task scheduled for 5:00 PM gym, alarmTier: "custom"
         At 4:55 PM → local pre-reminder fires (gentle nudge)
         At 5:00 PM → custom alarm fires (full screen)
         User dismisses without tapping Start
    ▼
Step 2 — At 5:30 PM, user still hasn't started the task
         At 6:30 PM (planned_end + 90 min), the system auto-abandons
    ▼
Step 3 — There are TWO paths to detection:
    
    Path A — Client-side (if user has app open):
       A timer in TaskService fires when planned_start + 90 min has passed
       and state still == "scheduled"
    
    Path B — Server-side (safety net):
       A Cloud Function scheduled via Cloud Tasks (queued when task was scheduled)
       fires at planned_start + 90 min
       Reads task state; if still "scheduled", auto-abandons
    ▼
Step 4 — Whichever path fires first wins (idempotency_id ensures dedup)
         WriteBatch:
         update tasks/gym → state = "abandoned", abandonedAt, reason: "auto_no_start"
         create events_recent/{eventId} → "task_abandoned"
    ▼
Step 5 — Listeners react:
    ├── MissionRingProvider recomputes (denominator unchanged, this task = 0)
    ├── RoutineService recomputes "fixed" routine % for today
    ├── Coach queue: schedule a gentle EoD check-in ("What got in the way?")
    └── NotificationService cancels any pending alerts for this task
    ▼
Step 6 — Cloud Function triggers:
    aiCoachReact (future) generates a response card
    updateAggregates updates today's `abandonedCount`
```

### 6.3 User breaks a streak

```
Step 1 — User has 18-day Hydration streak. On day 19, they hit only 1.5L (target 2L).
    ▼
Step 2 — At 11:30 PM (sleep block start) OR 11:59 PM (midnight cutoff),
         day_close is triggered
    ▼
Step 3 — runDayCloseRollup() executes:
    
    For each active habit:
       hit = sum(today's logs) >= dailyGoal
       streak = read users/{uid}/streaks/{habitId}
       
       IF hit:
         streak.currentCount += 1
         emit "streak_extended"
       ELSE:
         apply accountability rule (Forgiving / Strict / Ruthless)
         IF grace not granted:
           streak.currentCount = 0
           streak.lastBreakDate = today
           emit "streak_broken"
    ▼
Step 4 — For Hydration, accountability = "strict", no grace:
    streaks/hydration → currentCount: 18 → 0, state: "broken"
    events_recent → "streak_broken" with payload {habitId: "hydration", oldCount: 18, ...}
    ▼
Step 5 — Listeners react:
    ├── HabitDetailScreen → streak chip animates from 🔥18 to 🔥0 with gentle copy
    │   "Streak ended at 18. Resets are part of it."
    │   (NEVER red banner, NEVER "you failed")
    │
    ├── Identity scorer recomputes Strong Body % (Hydration was a contributor)
    │   ≈ -1.4% drop
    │
    └── Coach queue: tomorrow morning's plan gets a Day-1 reset reminder
                     ("Day 1 again. You've done this before.")
    ▼
Step 6 — Cloud Function processDayClose validates:
         If client-side streak math disagrees with server replay → re-emits corrected event
         (this is the consistency safety net)
```

The reframing of the break — gentle copy, no red, AI plans tomorrow as Day 1 not as failure — is enforced both at the UI string layer (banned vocabulary list) and at the Coach prompt layer (banned instructions in the system prompt).

---

## 7. Scalability plan

### 7.1 Capacity targets and back-of-envelope numbers

Assume realistic engagement at scale:

| User scale | DAU (50%) | Events/day | Peak QPS | Storage (90d hot) |
|---|---|---|---|---|
| 1K users | 500 | 15K | <1 | 400MB |
| 100K users | 50K | 1.5M | ~50 | 40GB |
| 1M users | 500K | 15M | ~500 | 400GB |

Average user: ~30 events/day (10 task transitions, 5 habit logs, 5 notifications, 10 misc).
Peak hours (8–10pm): ~3x average rate.

### 7.2 Where each layer scales (and where it doesn't)

| Layer | Native scale | Action needed at 1M users |
|---|---|---|
| Firestore reads/writes | Auto-scales; pay per op | Cost optimization: batch writes, BigQuery offload |
| Firestore single-document writes | 1 write/sec sustained | Avoid hot keys (don't increment counters on shared docs) |
| Firebase Auth | 100M+ users on free tier | None |
| Cloud Functions | Auto-scales to thousands of concurrent invocations | Use Gen 2 (Cloud Run-based); set max instances per function |
| FCM | Billions of pushes/day globally | None |
| BigQuery | Petabytes | Partition + cluster on import (already designed §4.6) |
| Cloud Tasks | Millions/sec per queue | Shard queues by user_id hash if a single queue saturates |

### 7.3 Cost projection at 1M users

Rough monthly costs at 1M users (USD):

| Service | Monthly | Notes |
|---|---|---|
| Firestore reads | $1,800 | ~3B reads/month at $0.06/100K |
| Firestore writes | $1,000 | ~500M writes/month at $0.18/100K (after batching) |
| Firestore storage | $200 | 400GB hot at $0.18/GB |
| Cloud Functions | $500 | ~100M invocations |
| BigQuery storage | $50 | 5TB at $0.01/GB after 90 days |
| BigQuery queries | $200 | Used by AI training only |
| FCM | $0 | Free |
| Firebase Auth | $0 | Free under 50K MAU; ~$100 above |
| **Total** | **~$3,800/mo** | At 1M users = $0.0038/user/mo |

That's healthy unit economics for a productivity app with even modest monetization (Pro tier at $5/mo with 5% conversion = $250K/mo revenue).

### 7.4 The hot-key problem and how to avoid it

The trap: a "global counter" pattern where one document is incremented on every event.

**Anti-patterns to never write:**
- `users/{uid}` document containing `totalEvents: 1234` updated on every event
- A daily aggregate doc updated by every event from every user
- A leaderboard doc with all users' streaks

**Correct patterns:**
- Each event is its own document; aggregates are computed by Cloud Function on a schedule, not in real-time
- Per-user daily summaries written once at day_close, read many times
- Sharded counters if real-time aggregates are absolutely needed (split into 10 shards, sum on read)

### 7.5 Caching strategy

| Cache | Where | TTL | Invalidation |
|---|---|---|---|
| User profile | Riverpod provider in app | Session | On `profile_updated` event |
| Today's tasks | Firestore offline cache + Riverpod | Real-time via snapshots | Auto via SDK |
| Habit configs | Firestore offline cache | Real-time | Auto |
| Routine templates | App memory after first read | Until app restart | Manual on edit |
| Identity scores | dailySummaries doc + Riverpod | Until day_closed | On `identity_progress_changed` |
| AI suggestions (future) | suggestions collection + Riverpod | Until accepted/dismissed/expired | On state change |

**No Redis. No Memcached.** Firestore's offline cache plus Riverpod's in-memory cache handles the entire app's caching needs at all scales we care about. Adding an external cache adds operational burden with no benefit.

---

## 8. Performance optimization

### 8.1 Offline-first as a foundation, not an afterthought

Mobile users lose connectivity constantly — subway, elevator, airplane mode, cheap data plans. The app must work *fully* offline for at least one day's session.

**What works offline:**
- All UI navigation, all reads (Firestore offline cache returns last synced data)
- All writes — they queue locally and sync when online
- Local event bus continues to fire; UI updates instantly
- Local notifications (already on-device, don't need network)

**What doesn't work offline:**
- AI coach chat (Gemini requires network) — show queued state
- Real-time sync between user's two devices (obvious)
- New images / cover art for new books

**Critical rule:** never block UI on a network call. Every action either:
- Returns from local state immediately and syncs in background, or
- Shows a clear "Connecting…" state with a manual retry

### 8.2 Optimistic updates

Standard pattern: update local state first, write to Firestore, reconcile if write fails.

```
User taps "Mark complete":
  1. Local task state → "completed" (UI animates)
  2. Local event bus → fires "task_completed" (Mission ring updates)
  3. Firestore write begins
  4. IF write fails:
     - Show toast: "Couldn't sync — retrying"
     - Roll back local state
     - Retry with exponential backoff
  5. IF write succeeds:
     - No-op (local state matches server)
```

Firestore SDK does most of this automatically with offline persistence. The explicit rollback handler is only needed for cases where the write would be rejected (security rules violation, schema mismatch).

### 8.3 Reducing Firestore read costs

| Anti-pattern | Cost | Fix |
|---|---|---|
| Listen to entire `events` collection on Home tab | 1 read per event ever, every session | Listen only to today's bucket |
| Reload all habits on every screen | N reads per screen | Cache habits in Riverpod, listen once per session |
| Query all tasks ever to compute streaks | Unbounded | Read streaks doc directly (it's pre-computed) |
| Real-time listen on a 1000-doc collection | 1000 initial reads + ongoing | Paginate; listen only to first page |

### 8.4 App startup performance

Target: cold start to interactive Home tab in <2 seconds on a midrange Android.

```
Cold start sequence:
  0ms     - Native splash (Android)
  100ms   - Flutter framework init
  300ms   - Riverpod container init (no IO)
  400ms   - Firebase init (Auth state restored from cache, fast)
  500ms   - Onboarding check (read users/{uid}.onboarding.completed from cache)
  600ms   - Home tab widget tree builds (with cached data)
  600ms   - First frame painted
  ────────────────────────────────────────
  Background:
  +200ms  - Firestore subscriptions establish (real-time updates begin flowing)
  +500ms  - Event replay completes (lastDayClosed check, missed-day rollup if needed)
  +1000ms - Day-close trigger if needed (silent unless rollup affects today's UI)
```

The cached-data-first approach is critical — never wait for network on app start. Show the user's last-known state immediately; let updates trickle in.

### 8.5 Image and asset strategy

- **No remote images for app UI.** All icons, illustrations, and skeuomorphic glass elements ship with the app.
- **Habit emojis** are Unicode — zero cost.
- **Book covers** (Reading tracker) cached aggressively; first load from Google Books API, then permanent local cache.
- **Coach avatars** are SVG (vector, tiny).
- **App total install size target:** <30 MB.

---

## 9. Security design

### 9.1 Authentication

- Firebase Auth with three providers: Email/password, Google, Apple (required for iOS)
- Tokens auto-refresh; SDK handles transparently
- Sign-out clears local Firestore cache + secure storage

### 9.2 Authorization (Firestore security rules)

The minimum-viable rules from MVP are not enough at production. Real rules:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
  
    // User-owned data — only the user can access
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null
                        && request.auth.uid == userId
                        && request.auth.token.email_verified == true;
    }
    
    // Events: write-only from clients (no edits, no deletes)
    match /users/{userId}/events_recent/{eventId} {
      allow create: if request.auth.uid == userId
                    && request.resource.data.eventName is string
                    && request.resource.data.ts == request.time
                    && eventId == request.resource.data.eventId;
      allow read: if request.auth.uid == userId;
      allow update, delete: if false;     // append-only
    }
    
    // Configs are global, read-only
    match /config/{document=**} {
      allow read: if request.auth != null;
      allow write: if false;              // admin-only via console
    }
    
    // Suggestions: AI writes (via Cloud Function with service account); 
    //   user can update state field only
    match /users/{userId}/suggestions/{suggestionId} {
      allow read: if request.auth.uid == userId;
      allow update: if request.auth.uid == userId
                    && onlyModifies(['state', 'updatedAt']);
      allow create, delete: if false;
    }
  }
  
  function onlyModifies(fields) {
    return request.resource.data.diff(resource.data).affectedKeys().hasOnly(fields);
  }
}
```

### 9.3 Firebase App Check

Without App Check, anyone can extract your Firebase config from the app binary and hammer your backend with arbitrary requests. App Check ensures every Firestore/Functions request comes from a genuine instance of your app:

- Android: Play Integrity attestation
- iOS: DeviceCheck / App Attest
- Web (future): reCAPTCHA Enterprise

Enabling App Check is non-optional at scale. It alone has saved me from incidents in past products.

### 9.4 PII and sensitive data

- **Health flags, biometrics, conversations** are user-private and stored only in `users/{uid}/`.
- **Eating disorder flag** is treated as the most sensitive single field — never appears in analytics queries, never exported to any aggregate.
- **AI coach conversations** are sent to Gemini API but never stored on Anthropic/Google's side beyond their normal log retention; we tell the user this in Privacy & Data settings.
- **Account deletion** is real: hard-delete after 7-day grace period, including BigQuery archives via scheduled cleanup query.

### 9.5 Encryption

- In transit: TLS 1.3 (managed by SDK)
- At rest: Firestore encrypts everything by default with Google-managed keys
- For especially sensitive fields (free-form coach conversations, sensitive context): consider customer-managed encryption keys at scale, but not for MVP

### 9.6 Threat model

| Threat | Mitigation |
|---|---|
| Stolen client config → API abuse | App Check |
| User-A reads User-B's data | Security rules (`request.auth.uid == userId`) |
| Replay of intercepted requests | Firebase Auth tokens are short-lived (1hr); App Check refreshes |
| Malicious schema injection | Security rules validate field types and required fields |
| Denial-of-wallet (someone spamming our Firestore from a stolen API key) | App Check + per-user rate limits in security rules |
| AI prompt injection via user input | Server-side input sanitization in Cloud Function before Gemini call |
| Account takeover | MFA option in Profile (added v1.1) |

---

## 10. Notifications system

### 10.1 The hybrid approach

Optivus uses two notification channels in concert:

| Channel | Source | When |
|---|---|---|
| Local (`flutter_local_notifications` + `AlarmManager`) | On-device, scheduled in advance | Predictable, time-based reminders (task pre-reminders, custom alarms, end-of-task chimes) |
| FCM push | Server-side, via Cloud Function | Reactive (AI coach response, slip nudge, re-engagement) |

The local channel is preferred whenever the time is known in advance — it works offline, has no cost, and survives app backgrounding. FCM is only used when the trigger is server-side.

### 10.2 Solving the durability problem

The earlier MVP design's flaw: local notifications break if user reinstalls, restarts device, or OS kills background services. Production fix:

```
Whenever a notification is scheduled:
  1. Write a record to users/{uid}/scheduledNotifications/{notifId}:
       { fireAt, category, priority, deepLink, title, body, state: "scheduled" }
  2. Schedule via OS API (AlarmManager / UNCalendarNotificationTrigger)

On app start:
  1. Read all scheduledNotifications where state == "scheduled" 
                                          AND fireAt > now
  2. Re-register them with the OS (AlarmManager doesn't survive device restart)
  3. Cancel any whose state is "sent" or "cancelled" but still in OS queue

When a notification fires:
  - Local handler updates state = "sent" in Firestore
  - On user tap → state = "tapped"
  - On dismiss → state = "dismissed"
```

This guarantees that no scheduled notification is ever lost across app restarts, device reboots, or reinstalls.

### 10.3 The decision pipeline

Every notification goes through this checklist before firing (already specified in Event System doc §11):

1. Priority bypass — P1 alarms fire unconditionally
2. Silence window — active task, post-completion 30min, sleep block, slip cooldown
3. DnD check — system Do Not Disturb
4. Frequency cap — daily budget (default 8), per-category caps, 60-min rolling window
5. Dedup — similar notification already pending or recently sent
6. Adaptive timing — if app is foreground, convert push to in-app toast

Suppressed notifications still emit `notification_suppressed` events. The AI uses these to learn what's not landing.

### 10.4 Custom alarms (the P1 tier)

Wake-up, gym, and medication alarms use a different code path — they use `AlarmManager.setAlarmClock()` on Android and the critical-alert entitlement on iOS. These bypass DnD with explicit user permission and play full audio.

Coach-voice alarms are pre-rendered audio clips (one per coach style: Tough Love, Supportive, Zen, etc.), shipped with the app. No TTS at runtime — that would require network and add latency.

### 10.5 FCM for reactive notifications

Reactive flows (AI coach responding to a slip 30 seconds later, re-engagement push 24 hours after going quiet) come through FCM:

```
Event fires (e.g., bad_habit_slip_logged) → Cloud Function triggered
  → Compose response (with coach prompt + recent context)
  → Apply notification decision pipeline
  → IF approved: send FCM push to all user's registered devices
  → Write notificationLog entry
```

FCM tokens are stored in `users/{uid}/devices/{deviceId}` and refreshed on each app session. Stale tokens are auto-removed when FCM returns `UNREGISTERED`.

---

## 11. Future expansion

### 11.1 The AI coach (highest-priority post-MVP)

Already designed for as a plug-in. Concrete steps when ready:

1. Deploy `aiCoachReact` Cloud Function — listens to relevant events (slip, abandon, day_close)
2. Function reads user's identity profile + last 50 events + active conversation context
3. Calls Gemini API with composed prompt
4. Writes response to `users/{uid}/suggestions/{suggestionId}` OR `users/{uid}/coachMessages/{msgId}`
5. Client real-time listener picks it up; UI renders the message or suggestion card

The "strategic AI planner" (full event-system doc §10) is implemented as a daily scheduled Cloud Function:
- Cloud Scheduler → triggers at 6am user-local-time → reads yesterday's data + today's plan → generates intervention candidates → writes top 5 to suggestions collection → notification scheduler picks them up

Total infra to add: 2 Cloud Functions, 1 scheduler. No client changes — the suggestions UI already exists.

### 11.2 iOS

The Flutter codebase is iOS-ready. What changes:
- Apple Sign-In becomes required (App Store rule)
- Phone usage tracking unavailable; replace with self-report
- Critical alerts entitlement requires Apple approval
- TestFlight + App Store Connect setup
- HealthKit integration (replaces Google Fit)

### 11.3 Web

A web companion (read-only dashboard initially) is a Flutter Web build sharing 90% of the code. The Firestore SDK works in browsers identically. Use cases: weekly review on a laptop, sharing a streak, progress visualization on a bigger screen.

### 11.4 Advanced analytics & ML

The BigQuery `events` table is purpose-built for this:

- **Cohort analysis** — onboarding completion rate by signup source, D1/D7/D30/D90 retention curves
- **Pattern mining** — what predicts a user breaking a 30+ day streak? (scrolling spike 2 days before, missed sleep block 1 day before, etc.)
- **AI training** — fine-tune a small model on (user_state, intervention, outcome) tuples so the coach gets *demonstrably better* over time, measured against a held-out set
- **Personalization features** — "users like you typically need 90 minutes for a gym block" computed from clustered cohorts

The data is already being collected. The infrastructure (BigQuery + scheduled queries) is already designed. What's missing is just the modeling work itself.

### 11.5 Integrations

In rough priority order:
- Apple Health / Google Fit (sleep, steps, workouts, heart rate)
- Calendar (Google Cal, Apple Cal — pull existing events, annotate as fixed-schedule blocks)
- Spotify/Apple Music (focus mode music for deep work blocks)
- Wearables (Apple Watch for quick task start/complete; Wear OS later)
- Screen Time API (iOS, gated behind Family Controls)

Each integration is its own module. None require changes to the core event system — they just add new event types and new Cloud Functions to populate them.

### 11.6 Monetization (system-design implications)

Two tiers:
- **Free** — full core functionality, capped at 10 coach messages/day, no custom alarms beyond wake-up
- **Pro** ($5/mo or $40/yr) — unlimited coach, all custom alarm tiers, advanced analytics, 5+ identities, integrations

System impact:
- `users/{uid}.subscription` field with tier and expiry
- Security rules check subscription tier on certain features
- RevenueCat or native StoreKit/Play Billing for purchase flow
- Monthly Cloud Function audits subscriptions; downgrades expired Pro users gracefully

No major architecture changes needed. The monetization layer sits on top of the core system.

---

## Closing principles

Three rules to never break, no matter how messy the code gets:

1. **Firestore is the source of truth.** Local state is an optimization, not authority.
2. **Service A does not call Service B.** Events are the only contract between modules.
3. **Every document has a `schemaVersion`.** Every event has both `schemaVersion` and `payloadVersion`.

Everything else in this document is a derivation of these three rules plus the constraints of running on Firebase at startup-scale. If you understand the rules and you understand the constraints, you can rederive any specific decision. If you find yourself wanting to break a rule, you've probably found a missing event type or a missing service boundary — fix that, don't break the rule.

The system is designed to grow with the product. The MVP is buildable in 12 weeks by one engineer. The same codebase scales to 1M users with the additions explicitly called out in this document — no rewrites, no migrations beyond schema versions. That is what production-ready means.
