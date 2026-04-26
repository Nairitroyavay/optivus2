# Optivus — Database Schema Design

**Document type:** Production-ready database design — single source of truth
**Author:** Senior backend architecture pass
**Audience:** Nairit (you), Antigravity (the coding agent), Claude (design + review)
**Companion to:** Optivus_PRD.md, Optivus_EventSystem.md, Optivus_ServiceContracts.md, Optivus_AI_Master_Engine.md, code audit
**Date:** 26 April 2026
**Status:** Approved schema — ready to implement as migrations

---

## Notes for Antigravity (the AI agent reading this to build it)

Before generating any migration, read this entire document. The schema has heavy interconnection — events reference rules, ai_messages reference events, streaks are derived from habit_logs. Skipping ahead breaks foreign keys.

Hard constraints when you generate code:

1. **The current Optivus codebase is Flutter + Firebase Firestore.** This document specifies a *target* schema. Not all of this exists yet. Per the audit, only `users` (basic), `routine`, and `onboarding` data exist in Firestore today. Everything else is new.
2. **The recommendation is Postgres-first, NOT a Firestore migration.** Read §1 before assuming we'll keep Firestore. The reasoning matters — if the team decides to stay on Firestore, the table designs translate but the partitioning, indexes, and ACID guarantees do not. Flag this decision before building.
3. **Every table has `schema_version`.** Per audit P1, the existing codebase is missing this everywhere. Add it as you build.
4. **Every timestamp is `TIMESTAMPTZ`,** never `TIMESTAMP`. Optivus users span time zones; naive timestamps create silent bugs.
5. **All IDs are UUIDs**, generated client-side (UUIDv7 preferred — naturally sorted). Not auto-increment. Never reveal counts or guess-next-id.
6. **The `events` table is the heart.** It will become the largest table by far. Read §4 before touching it. Wrong index strategy = production-level pain in 6 months.
7. **If you hit a design point not covered here, stop and ask Nairit.** Do not invent. The §11 open questions are explicitly undecided.

---

## Notes for Nairit

This document closes the design loop. With the PRD, EventSystem, ServiceContracts, AI Master Engine, and now this schema, every layer of Optivus has a written spec. The next thing should be code.

**The big call this document makes:** move off Firestore, onto Postgres, with Redis for hot reads. §1 explains why. Short version: Firestore is great for the routine + user docs you already have, but the event system, rule engine, and analytics-grade queries the PRD demands hit Firestore's structural limits — fan-out fees, lack of ad-hoc joins, no real partitioning. Trying to build the AI brain on Firestore costs more in engineering time than rewriting it.

You don't have to migrate today. Phase 1 (auth, profiles, routines) can stay on Firestore. The rewrite begins when you start building the event system. That's a clean break point.

If you'd rather stay on Firestore for v1 and revisit later, that's a valid call — but read §11 Q1 first to understand what you're trading off.

---

# Table of Contents

1. **Database Choice** — Postgres + Redis, with Firestore migration path
2. **Schema Conventions** — naming, types, IDs, timestamps
3. **Core Tables** — full DDL for all 17 tables
4. **Event Table Deep Dive** — design, partitioning, query patterns
5. **Relationships** — ER diagram + cardinalities
6. **AI Rule Engine Storage** — rules, logs, messages, context
7. **Scalability Strategy** — indexes, partitioning, caching, archival
8. **Sample Data** — real INSERT examples for every domain
9. **Query Examples** — the 12 queries the app actually runs
10. **Design Principles** — what we optimized for and what we didn't
11. **Open Questions** — explicitly undecided
12. **Migration Path from Firestore**

---

# Part 1 — Database Choice

## 1.1 Recommendation

**Primary:** PostgreSQL 16 with `JSONB`, native partitioning, and `pgcrypto` for UUIDs.
**Cache & rate limit:** Redis 7 (not optional for this design).
**Cold archive:** S3 (Parquet files) for events older than 90 days.
**Existing Firestore:** keep for `users` profile docs and `routines/current` document during transition. Migrate after event system is live.

This is **a hybrid by deployment**, not by data model. Postgres owns the data model; Redis owns transient coach state and pre-computed counters; S3 owns history.

## 1.2 Why not pure MongoDB

MongoDB would handle the JSON shape of events well, but loses:
- Foreign key integrity (we have many — events reference rules, messages reference events, streaks reference habits)
- Cheap transactions across collections (we need ACID on day_close which writes to streaks + events + ai_messages atomically)
- Mature partitioning by time (Postgres native partitions are excellent for events)
- Mature analytics (Postgres + materialized views beat Mongo aggregation pipelines for the streak rollups)

## 1.3 Why not stay on Firestore

The current codebase is Firestore. Why move:

| Need | Firestore | Postgres |
|---|---|---|
| Event system at 1M events/user/year | Fan-out fees scale linearly with listeners; no partitions | Native time partitions, $0 marginal cost |
| Rule engine condition queries | Limited compound queries, no joins | Full SQL, joins, CTEs |
| Day-close transaction (streaks + events + messages atomically) | No multi-document transactions across collection groups | Native ACID transactions |
| Cohort analytics ("how many users in 'slipping' state for 7+ days") | Requires BigQuery export pipeline + delay | One SQL query, real-time |
| Schema migration safety | No migrations — silent drift | Migrations as code, version-controlled |
| Cost at 100k MAU | Read/write per-document fees compound | Predictable fixed instance cost |

The earlier production system design doc projected ~$3,800/month at 1M users on Firestore-only. Same scale on Postgres with read replicas: ~$800/month. The break-even is around 8k MAU.

## 1.4 What stays on Firestore (transition)

For 4–6 weeks during migration, this dual-write model works:

- **Firestore continues:** user profile doc, routine doc, onboarding doc (the existing `users/{uid}` and `users/{uid}/routine/current`).
- **Postgres new:** events, ai_rules, ai_messages, habit_logs, streaks, journal_entries, screen_time_logs, addiction_logs, notifications.
- **Both temporarily:** habits and goals (write to both, read from Postgres, allow rollback).

After 6 weeks of confidence, move user/routine/onboarding to Postgres too, kill Firestore.

## 1.5 Why Redis is not optional

Three workloads burn Postgres if served directly:

- **Coach cooldowns** — checked on every event arrival. ~10 reads/event. At 1k events/day × 100k users = 1B reads/day to a single table. Postgres can do it but it's wasteful.
- **Speak budget counter** — incremented on every coach message, checked on every event. Counter primitive, not relational.
- **Active session tracking** — "is this user currently in app" is a 30-second TTL fact, not a database row.

These three live in Redis. Everything else lives in Postgres.

---

# Part 2 — Schema Conventions

These rules apply to every table in §3. Antigravity must follow them without exception.

## 2.1 Naming

- Tables: `snake_case_plural` (`habit_logs`, not `HabitLog` or `habit_log`)
- Columns: `snake_case` (`created_at`, not `createdAt`)
- Indexes: `idx_<table>_<columns>` (`idx_events_user_id_occurred_at`)
- Foreign keys: `<table>_id` (`user_id`, `habit_id`)
- Booleans: `is_*` or `has_*` (`is_active`, `has_completed_onboarding`)

## 2.2 Types

- **IDs:** `UUID` (UUIDv7 from client), `PRIMARY KEY`. Never `SERIAL`.
- **Timestamps:** always `TIMESTAMPTZ`. Default `NOW()` on `created_at`. Never `TIMESTAMP` (without TZ) — silent bug magnet.
- **Text:** `TEXT`, not `VARCHAR(n)`. Postgres treats them identically; the cap is rarely useful.
- **Money:** never floats. Use `BIGINT` cents.
- **Enums:** prefer `TEXT` + `CHECK` constraint over native `ENUM`. Postgres native enums are painful to alter.
- **JSON:** `JSONB`, never `JSON`. JSONB indexes; JSON doesn't.

## 2.3 Required columns on every table

```sql
id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
schema_version  SMALLINT     NOT NULL DEFAULT 1
```

`updated_at` is maintained by an `AFTER UPDATE` trigger (one trigger function shared across all tables). `schema_version` lets us migrate row-by-row without locking.

## 2.4 Soft deletes

Most tables support soft delete via `deleted_at TIMESTAMPTZ NULL`. Hard delete only on:
- `sessions` (just delete)
- `events` older than retention window (deleted by partition drop)
- User-requested account deletion (cascade hard-delete everything)

Default queries always include `WHERE deleted_at IS NULL`. Partial indexes `WHERE deleted_at IS NULL` keep index sizes small.

---

# Part 3 — Core Tables (full DDL)

17 tables across 7 domains. Each section gives the DDL, the indexes, and a one-line reason for any unusual choice.

## 3.1 User System

### Table: `users`

```sql
CREATE TABLE users (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email                       TEXT NOT NULL UNIQUE,
    firebase_uid                TEXT UNIQUE,                    -- nullable during migration
    name                        TEXT,
    photo_url                   TEXT,

    -- Onboarding (denormalized — read on every coach decision)
    accountability_mode         TEXT NOT NULL DEFAULT 'forgiving'
        CHECK (accountability_mode IN ('forgiving','strict','ruthless')),
    coach_name                  TEXT NOT NULL DEFAULT 'Coach',
    coach_style                 TEXT,
    identity_tags               TEXT[] DEFAULT '{}',
    eating_disorder_flag        BOOLEAN NOT NULL DEFAULT FALSE,
    coach_enabled               BOOLEAN NOT NULL DEFAULT TRUE,

    -- Biometrics (optional, from PRD onboarding "About You")
    birth_date                  DATE,
    height_cm                   SMALLINT,
    weight_kg                   NUMERIC(5,2),
    sex                         TEXT CHECK (sex IN ('male','female','other','prefer_not_to_say')),

    -- Lifecycle
    has_completed_onboarding    BOOLEAN NOT NULL DEFAULT FALSE,
    onboarding_completed_at     TIMESTAMPTZ,
    timezone                    TEXT NOT NULL DEFAULT 'UTC',     -- e.g. 'Asia/Kolkata'
    locale                      TEXT NOT NULL DEFAULT 'en-IN',

    -- Standard
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    schema_version              SMALLINT NOT NULL DEFAULT 1,
    deleted_at                  TIMESTAMPTZ
);

CREATE INDEX idx_users_email ON users(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_firebase_uid ON users(firebase_uid) WHERE firebase_uid IS NOT NULL;
CREATE INDEX idx_users_active ON users(id) WHERE deleted_at IS NULL;
```

**Why denormalize coach fields here:** the engine reads them on every event. Joining `users` → `user_preferences` → `coach_settings` on every event adds latency. Coach fields are stable; denormalization is the right call.

### Table: `sessions`

```sql
CREATE TABLE sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash      TEXT NOT NULL UNIQUE,           -- never store raw tokens
    device_info     JSONB DEFAULT '{}'::JSONB,      -- {os, app_version, fcm_token, ...}
    ip_address      INET,
    last_active_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at      TIMESTAMPTZ NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sessions_user_id ON sessions(user_id);
CREATE INDEX idx_sessions_expires_at ON sessions(expires_at);
CREATE INDEX idx_sessions_token_hash ON sessions(token_hash);
```

**Why this exists at all when Firebase Auth handles tokens:** `sessions` here is for FCM (push) tokens, device fingerprints, last-active tracking — things Firebase Auth doesn't surface. Auth itself stays on Firebase.

## 3.2 Habit System

### Table: `habits`

```sql
CREATE TABLE habits (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    name                TEXT NOT NULL,                      -- 'Gym', 'Smoking', 'Reading'
    kind                TEXT NOT NULL                       -- 'good' or 'bad' (PRD distinction)
        CHECK (kind IN ('good','bad')),
    category            TEXT NOT NULL                       -- 'health' | 'productivity' | 'recovery' | etc.
        CHECK (category IN ('health','productivity','recovery','mindfulness','social','finance','custom')),

    -- Targeting
    target_per_day      INT,                                -- e.g. 'water 8 times' OR null for 'do once'
    target_per_week     INT,                                -- e.g. 'gym 4 times'
    unit                TEXT,                               -- 'reps' | 'minutes' | 'glasses' | null

    -- Identity
    identity_tags       TEXT[] DEFAULT '{}',                -- ties to user.identity_tags
    icon                TEXT,
    color               TEXT,                               -- hex without #

    -- Coach behavior overrides
    coach_priority      SMALLINT DEFAULT 2 CHECK (coach_priority BETWEEN 1 AND 4),
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    paused_until        TIMESTAMPTZ,                        -- 'pause for 7 days' from coach

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    schema_version      SMALLINT NOT NULL DEFAULT 1,
    deleted_at          TIMESTAMPTZ
);

CREATE INDEX idx_habits_user_id ON habits(user_id) WHERE deleted_at IS NULL AND is_active = TRUE;
CREATE INDEX idx_habits_user_kind ON habits(user_id, kind) WHERE deleted_at IS NULL;
```

### Table: `habit_logs`

```sql
CREATE TABLE habit_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    habit_id        UUID NOT NULL REFERENCES habits(id) ON DELETE CASCADE,

    occurred_at     TIMESTAMPTZ NOT NULL,                   -- when the habit happened (NOT when logged)
    logged_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),     -- when the user logged it

    quantity        NUMERIC(10,2),                          -- e.g. 2.5 for 2.5 km
    unit            TEXT,                                   -- redundant with habits.unit but allows override
    note            TEXT,
    trigger         TEXT,                                   -- for bad habits: 'stress' | 'boredom' | 'social' | 'habit'
    mood_score      SMALLINT CHECK (mood_score BETWEEN 1 AND 5),

    -- For coach context
    user_state_at_log   TEXT,                               -- snapshot of user_state at log time
    metadata        JSONB DEFAULT '{}'::JSONB,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    schema_version  SMALLINT NOT NULL DEFAULT 1
);

CREATE INDEX idx_habit_logs_user_occurred ON habit_logs(user_id, occurred_at DESC);
CREATE INDEX idx_habit_logs_habit_occurred ON habit_logs(habit_id, occurred_at DESC);
CREATE INDEX idx_habit_logs_user_today ON habit_logs(user_id, occurred_at)
    WHERE occurred_at > (NOW() - INTERVAL '7 days');
```

**Why split `occurred_at` and `logged_at`:** users log at 11pm "the cigarette I had at 3pm". The streak math needs the actual time. The "when was this entered?" matters for fraud / double-log detection.

## 3.3 Routine System

### Table: `routines`

```sql
CREATE TABLE routines (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    name            TEXT NOT NULL,                          -- 'Morning Skin Care', 'Gym Block'
    kind            TEXT NOT NULL                           -- per PRD routine types
        CHECK (kind IN ('morning_skin_care','evening_skin_care','eating','classes','fixed_block','custom')),

    -- Timing
    days_of_week    SMALLINT[] DEFAULT '{0,1,2,3,4,5,6}',   -- 0=Sunday, 6=Saturday
    window_start    TIME,                                   -- e.g. '07:00:00'
    window_end      TIME,
    grace_minutes   INT DEFAULT 30,                         -- buffer before "missed"

    -- Step structure (denormalized for speed; single source of truth)
    steps           JSONB DEFAULT '[]'::JSONB,
    -- e.g. [{"id":"s1","title":"Cleanser","order":0},{"id":"s2","title":"Toner","order":1}]

    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    paused_until    TIMESTAMPTZ,
    color           TEXT,
    icon            TEXT,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    schema_version  SMALLINT NOT NULL DEFAULT 1,
    deleted_at      TIMESTAMPTZ
);

CREATE INDEX idx_routines_user ON routines(user_id) WHERE deleted_at IS NULL AND is_active = TRUE;
```

### Table: `routine_completions`

```sql
CREATE TABLE routine_completions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    routine_id          UUID NOT NULL REFERENCES routines(id) ON DELETE CASCADE,

    occurred_on         DATE NOT NULL,                      -- the calendar day this completion is for
    started_at          TIMESTAMPTZ,
    completed_at        TIMESTAMPTZ,
    completion_pct      NUMERIC(5,4) NOT NULL DEFAULT 0,    -- 0.0000 to 1.0000

    steps_completed     JSONB DEFAULT '[]'::JSONB,          -- ['s1','s2'] step IDs done
    state               TEXT NOT NULL DEFAULT 'pending'
        CHECK (state IN ('pending','in_progress','completed','partial','missed','skipped')),

    note                TEXT,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    schema_version      SMALLINT NOT NULL DEFAULT 1,

    UNIQUE (user_id, routine_id, occurred_on)               -- one completion record per routine per day
);

CREATE INDEX idx_routine_completions_user_date ON routine_completions(user_id, occurred_on DESC);
CREATE INDEX idx_routine_completions_routine_date ON routine_completions(routine_id, occurred_on DESC);
CREATE INDEX idx_routine_completions_state ON routine_completions(user_id, state, occurred_on)
    WHERE state IN ('missed','partial');
```

**Why no `routine_tasks` table:** the brief asked for it, but tasks-within-routines are step lists that change with the routine. They're metadata. Splitting into a child table means every routine read is a join. Storing as JSONB on `routines.steps` is faster and the steps don't have their own lifecycle.

For *one-off* tasks (the user's daily todos, not part of a routine), see `tasks` in §3.4.

## 3.4 Task System

### Table: `tasks`

```sql
CREATE TABLE tasks (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    title               TEXT NOT NULL,
    description         TEXT,
    identity_tags       TEXT[] DEFAULT '{}',

    -- Scheduling
    planned_start       TIMESTAMPTZ,
    planned_end         TIMESTAMPTZ,
    actual_start        TIMESTAMPTZ,
    actual_end          TIMESTAMPTZ,
    duration_minutes    INT,                                -- planned duration

    -- State machine (per PRD)
    state               TEXT NOT NULL DEFAULT 'scheduled'
        CHECK (state IN ('scheduled','started','paused','completed','skipped','abandoned')),

    -- Linkage
    routine_id          UUID REFERENCES routines(id) ON DELETE SET NULL,
    goal_id             UUID,                               -- FK after goals defined; circular reference

    -- Subtasks (denormalized JSONB)
    subtasks            JSONB DEFAULT '[]'::JSONB,
    -- e.g. [{"id":"st1","title":"Outline","done":true}]

    color               TEXT,
    icon                TEXT,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    schema_version      SMALLINT NOT NULL DEFAULT 1,
    deleted_at          TIMESTAMPTZ
);

CREATE INDEX idx_tasks_user_planned ON tasks(user_id, planned_start)
    WHERE deleted_at IS NULL AND state IN ('scheduled','started','paused');
CREATE INDEX idx_tasks_user_state ON tasks(user_id, state) WHERE deleted_at IS NULL;
CREATE INDEX idx_tasks_routine ON tasks(routine_id) WHERE routine_id IS NOT NULL;

-- Add the deferred FK:
-- ALTER TABLE tasks ADD CONSTRAINT fk_tasks_goal_id
--     FOREIGN KEY (goal_id) REFERENCES goals(id) ON DELETE SET NULL;
```

## 3.5 Goal System

### Table: `goals`

```sql
CREATE TABLE goals (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    title               TEXT NOT NULL,
    description         TEXT,
    category            TEXT,                               -- 'fitness','study','career','recovery'
    identity_tag        TEXT,                               -- single tag for ring-weight calc

    -- Targeting
    metric_type         TEXT                                -- 'count' | 'duration_minutes' | 'binary' | 'numeric'
        CHECK (metric_type IN ('count','duration_minutes','binary','numeric')),
    target_value        NUMERIC(12,2),                      -- 'read 12 books' → 12
    current_value       NUMERIC(12,2) DEFAULT 0,
    unit                TEXT,                               -- 'books','km','kg','hours'

    -- Mission ring
    ring_weight         NUMERIC(3,2) DEFAULT 1.0
        CHECK (ring_weight BETWEEN 0 AND 5),
    daily_target        NUMERIC(12,2),                      -- per-day expected progress

    -- Lifecycle
    starts_on           DATE,
    deadline            DATE,
    is_completed        BOOLEAN NOT NULL DEFAULT FALSE,
    completed_at        TIMESTAMPTZ,

    -- AI strategic plan
    ai_plan             JSONB DEFAULT '{}'::JSONB,          -- breakdown into tasks/milestones
    ai_plan_generated_at TIMESTAMPTZ,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    schema_version      SMALLINT NOT NULL DEFAULT 1,
    deleted_at          TIMESTAMPTZ
);

CREATE INDEX idx_goals_user_active ON goals(user_id, is_completed)
    WHERE deleted_at IS NULL;
CREATE INDEX idx_goals_deadline ON goals(deadline) WHERE deadline IS NOT NULL AND is_completed = FALSE;
```

### Table: `goal_progress`

```sql
CREATE TABLE goal_progress (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    goal_id         UUID NOT NULL REFERENCES goals(id) ON DELETE CASCADE,

    occurred_on     DATE NOT NULL,
    delta           NUMERIC(12,2) NOT NULL,                 -- the change (e.g. +1 book)
    new_value       NUMERIC(12,2) NOT NULL,                 -- value after this entry
    note            TEXT,
    source          TEXT,                                   -- 'manual' | 'task_completion' | 'habit_log'
    source_id       UUID,                                   -- pointer to the source record

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    schema_version  SMALLINT NOT NULL DEFAULT 1
);

CREATE INDEX idx_goal_progress_goal_date ON goal_progress(goal_id, occurred_on DESC);
CREATE INDEX idx_goal_progress_user_date ON goal_progress(user_id, occurred_on DESC);
```

## 3.6 Streak System

### Table: `streaks`

```sql
CREATE TABLE streaks (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- The thing being streaked (one of: habit, routine, goal)
    streak_type         TEXT NOT NULL
        CHECK (streak_type IN ('habit_good','habit_bad_clean','routine','goal')),
    target_id           UUID NOT NULL,                      -- references habits.id, routines.id, or goals.id

    -- Mode
    accountability      TEXT NOT NULL                       -- copied from user at streak start
        CHECK (accountability IN ('forgiving','strict','ruthless')),

    -- Counts
    current_streak      INT NOT NULL DEFAULT 0,
    longest_streak      INT NOT NULL DEFAULT 0,
    total_completions   INT NOT NULL DEFAULT 0,

    -- Dates
    started_on          DATE,
    last_completion_on  DATE,
    last_break_on       DATE,
    paused_until        TIMESTAMPTZ,                        -- 'paused-not-broken' on ghost periods

    -- Status
    state               TEXT NOT NULL DEFAULT 'active'
        CHECK (state IN ('active','paused','broken','recovering')),

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    schema_version      SMALLINT NOT NULL DEFAULT 1,

    UNIQUE (user_id, streak_type, target_id)
);

CREATE INDEX idx_streaks_user ON streaks(user_id);
CREATE INDEX idx_streaks_user_active ON streaks(user_id) WHERE state = 'active';
CREATE INDEX idx_streaks_milestone ON streaks(current_streak)
    WHERE current_streak IN (7,14,30,60,90,100,365);  -- partial for milestone fires
```

**Why streaks is a real table not derived:** computing streaks from `habit_logs` on every read is slow at scale. Day-close (Cloud Scheduler at user.sleep_time) updates this table once per user per day. Reads are then O(1).

## 3.7 Tracker-Specific Tables

These extend habit_logs for the 10 trackers in the PRD with stronger typing where needed.

### Table: `screen_time_logs`

```sql
CREATE TABLE screen_time_logs (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    occurred_on         DATE NOT NULL,
    app_name            TEXT NOT NULL,                      -- 'instagram', 'youtube', 'reddit'
    minutes_used        INT NOT NULL,
    sessions_count      INT,                                -- if known
    longest_session_min INT,

    -- User-set limit at the time of log (denormalized — limits change)
    user_limit_minutes  INT,
    over_limit          BOOLEAN GENERATED ALWAYS AS (minutes_used > COALESCE(user_limit_minutes, 999999)) STORED,

    source              TEXT NOT NULL DEFAULT 'manual'      -- 'manual' | 'screentime_api' | 'estimate'
        CHECK (source IN ('manual','screentime_api','estimate')),

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    schema_version      SMALLINT NOT NULL DEFAULT 1,

    UNIQUE (user_id, app_name, occurred_on)
);

CREATE INDEX idx_screen_time_user_date ON screen_time_logs(user_id, occurred_on DESC);
CREATE INDEX idx_screen_time_over_limit ON screen_time_logs(user_id, occurred_on)
    WHERE over_limit = TRUE;
```

### Table: `addiction_logs`

```sql
CREATE TABLE addiction_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    addiction_type  TEXT NOT NULL                           -- 'cigarettes', 'alcohol', 'porn', etc.
        CHECK (addiction_type IN ('cigarettes','alcohol','porn','gambling','other')),
    occurred_at     TIMESTAMPTZ NOT NULL,
    quantity        NUMERIC(10,2) DEFAULT 1,                -- 1 cigarette, 0.5 drinks, etc.
    unit            TEXT,                                   -- 'cigarette', 'drink', 'session'

    trigger         TEXT,                                   -- 'stress','boredom','social','habit','craving'
    location        TEXT,
    note            TEXT,
    cost_cents      BIGINT,                                 -- for "money saved" tracker

    -- Context at time of log
    mood_before     SMALLINT CHECK (mood_before BETWEEN 1 AND 5),
    mood_after      SMALLINT CHECK (mood_after BETWEEN 1 AND 5),

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    schema_version  SMALLINT NOT NULL DEFAULT 1
);

CREATE INDEX idx_addiction_logs_user_occurred ON addiction_logs(user_id, occurred_at DESC);
CREATE INDEX idx_addiction_logs_type ON addiction_logs(user_id, addiction_type, occurred_at DESC);
```

**Why a separate table from `habit_logs`:** addictions need stronger typing — cost tracking, mood pre/post, trigger taxonomy. Treating "smoking" as just another bad habit loses the relapse-pause and money-saved features the PRD specifies.

## 3.8 Journal System

### Table: `journal_entries`

```sql
CREATE TABLE journal_entries (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    occurred_on         DATE NOT NULL,
    kind                TEXT NOT NULL DEFAULT 'free'
        CHECK (kind IN ('free','prompted','day_close','reflection','gratitude')),

    title               TEXT,
    body                TEXT NOT NULL,
    mood_score          SMALLINT CHECK (mood_score BETWEEN 1 AND 10),
    energy_score        SMALLINT CHECK (energy_score BETWEEN 1 AND 10),
    tags                TEXT[] DEFAULT '{}',

    -- For prompted entries
    prompt_used         TEXT,                               -- the question the AI asked

    -- AI summary (offline-generated)
    ai_summary          TEXT,
    ai_themes           TEXT[],

    is_private          BOOLEAN NOT NULL DEFAULT TRUE,      -- never share even with coach? user choice

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    schema_version      SMALLINT NOT NULL DEFAULT 1,
    deleted_at          TIMESTAMPTZ
);

CREATE INDEX idx_journal_user_date ON journal_entries(user_id, occurred_on DESC)
    WHERE deleted_at IS NULL;
CREATE INDEX idx_journal_user_kind ON journal_entries(user_id, kind, occurred_on DESC)
    WHERE deleted_at IS NULL;
CREATE INDEX idx_journal_search_body ON journal_entries USING GIN (to_tsvector('english', body))
    WHERE deleted_at IS NULL;
```

**Why GIN index on body:** users will eventually want "find that entry where I wrote about my dad." Full-text search on Postgres is built in and free.

## 3.9 Event System (the heart) — see §4 for deep dive

### Table: `events`

```sql
CREATE TABLE events (
    id              UUID NOT NULL DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL,                          -- no FK on partition root, declared per partition
    event_type      TEXT NOT NULL,                          -- 'habit.bad_logged', 'task.completed', etc.
    occurred_at     TIMESTAMPTZ NOT NULL,                   -- partition key
    metadata        JSONB NOT NULL DEFAULT '{}'::JSONB,

    -- Indexed extracts (for hot queries — see §4.4)
    -- These are GENERATED columns from metadata
    habit_id        UUID GENERATED ALWAYS AS ((metadata->>'habit_id')::UUID) STORED,
    routine_id      UUID GENERATED ALWAYS AS ((metadata->>'routine_id')::UUID) STORED,
    task_id         UUID GENERATED ALWAYS AS ((metadata->>'task_id')::UUID) STORED,

    -- Provenance
    source          TEXT NOT NULL DEFAULT 'app'
        CHECK (source IN ('app','server','scheduler','migration')),
    schema_version  SMALLINT NOT NULL DEFAULT 1,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (id, occurred_at)                           -- composite PK required for partitioning
) PARTITION BY RANGE (occurred_at);
```

Partitions, indexes, and the event-type taxonomy: see §4.

## 3.10 AI System

### Table: `ai_rules`

```sql
CREATE TABLE ai_rules (
    id                  TEXT PRIMARY KEY,                   -- 'slip_cigarette_strict_on_track' (string ID, not UUID)
    description         TEXT NOT NULL,

    -- Trigger
    event_type          TEXT NOT NULL,                      -- 'habit.bad_logged' or '*'
    conditions          JSONB NOT NULL DEFAULT '[]'::JSONB, -- per AI Master Engine §2

    -- Routing
    priority            SMALLINT NOT NULL CHECK (priority BETWEEN 1 AND 4),
    cooldown_seconds    INT NOT NULL DEFAULT 3600,
    cooldown_topic      TEXT NOT NULL,

    -- Coach behavior
    ai_intent           TEXT NOT NULL,
    archetype_override  TEXT,                               -- 'forgiving', 'celebratory', etc.
    tone                JSONB DEFAULT '{}'::JSONB,

    -- Generation
    prompt_template     TEXT NOT NULL,
    example_outputs     TEXT[] DEFAULT '{}',
    fallback_message    TEXT NOT NULL,

    -- Post-message
    suggested_actions   JSONB DEFAULT '[]'::JSONB,
    followup_policy     TEXT NOT NULL DEFAULT 'none'
        CHECK (followup_policy IN ('none','check_in_2h','check_in_24h','check_in_after_routine')),

    -- Lifecycle
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    rule_version        INT NOT NULL DEFAULT 1,             -- bumped when text changes
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ai_rules_event_type ON ai_rules(event_type) WHERE is_active = TRUE;
CREATE INDEX idx_ai_rules_priority ON ai_rules(priority) WHERE is_active = TRUE;
```

**Caveat that contradicts the AI Master Engine doc:** the AI Master Engine recommends rules live in *code*, not config. This table exists for two reasons: (1) **rule firing logs need a stable ID** to reference; (2) **A/B testing** at scale eventually requires runtime control. The recommended workflow: rules are authored in `coach_rules.dart`, deployed via a "rules sync" migration that upserts them into this table at boot. Code is source of truth; this table is reference + telemetry anchor.

### Table: `ai_rule_logs`

```sql
CREATE TABLE ai_rule_logs (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    rule_id             TEXT NOT NULL REFERENCES ai_rules(id),
    event_id            UUID NOT NULL,                      -- the triggering event (no FK due to partition)

    decision            TEXT NOT NULL                       -- what the engine decided
        CHECK (decision IN ('spoke','dropped_cooldown','dropped_budget','dropped_silence',
                            'dropped_no_eligible','deferred')),
    drop_reason         TEXT,
    deferred_until      TIMESTAMPTZ,

    -- Snapshot of context at decision time (compressed)
    context_snapshot    JSONB NOT NULL,
    user_state          TEXT,
    accountability      TEXT,

    -- Resulting message (if spoke)
    ai_message_id       UUID,                               -- forward ref to ai_messages

    occurred_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    schema_version      SMALLINT NOT NULL DEFAULT 1
);

CREATE INDEX idx_ai_rule_logs_user_time ON ai_rule_logs(user_id, occurred_at DESC);
CREATE INDEX idx_ai_rule_logs_rule_time ON ai_rule_logs(rule_id, occurred_at DESC);
CREATE INDEX idx_ai_rule_logs_decision ON ai_rule_logs(decision, occurred_at DESC);
```

### Table: `ai_messages`

```sql
CREATE TABLE ai_messages (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Provenance
    rule_id             TEXT REFERENCES ai_rules(id),       -- nullable — chat replies have no rule
    rule_log_id         UUID REFERENCES ai_rule_logs(id),
    triggering_event_id UUID,                               -- no FK (partition)

    -- Content
    role                TEXT NOT NULL                       -- 'coach' | 'user' (chat replies)
        CHECK (role IN ('coach','user')),
    body                TEXT NOT NULL,
    message_type        TEXT NOT NULL DEFAULT 'check_in'    -- per AI Master Engine §9
        CHECK (message_type IN ('check_in','nudge','celebration','reflection','safety','user_reply')),
    priority            SMALLINT CHECK (priority BETWEEN 1 AND 4),

    -- AI generation details
    llm_model           TEXT,                               -- 'claude-haiku-4-5'
    llm_latency_ms      INT,
    llm_tokens_in       INT,
    llm_tokens_out      INT,
    used_fallback       BOOLEAN NOT NULL DEFAULT FALSE,

    -- UI extras
    suggested_actions   JSONB DEFAULT '[]'::JSONB,
    followup_scheduled_at TIMESTAMPTZ,

    -- User interaction
    delivered_at        TIMESTAMPTZ,
    read_at             TIMESTAMPTZ,
    user_action_taken   TEXT,                               -- which suggested_action they tapped, if any
    user_dismissed_at   TIMESTAMPTZ,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    schema_version      SMALLINT NOT NULL DEFAULT 1
);

CREATE INDEX idx_ai_messages_user_created ON ai_messages(user_id, created_at DESC);
CREATE INDEX idx_ai_messages_user_role ON ai_messages(user_id, role, created_at DESC);
CREATE INDEX idx_ai_messages_unread ON ai_messages(user_id, created_at)
    WHERE read_at IS NULL AND role = 'coach';
```

### Table: `ai_context_history` (sliding context for the chat tab)

```sql
CREATE TABLE ai_context_history (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    snapshot        JSONB NOT NULL,                         -- the ContextSnapshot at this moment
    occurred_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- For chat continuity
    chat_session_id UUID,                                   -- groups consecutive messages

    schema_version  SMALLINT NOT NULL DEFAULT 1
);

CREATE INDEX idx_ai_context_user_time ON ai_context_history(user_id, occurred_at DESC);

-- TTL: drop snapshots older than 30 days
-- (Implemented as nightly DELETE WHERE occurred_at < NOW() - INTERVAL '30 days')
```

## 3.11 Notification System

### Table: `notifications`

```sql
CREATE TABLE notifications (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Source
    source              TEXT NOT NULL                       -- 'coach' | 'reminder' | 'system' | 'streak'
        CHECK (source IN ('coach','reminder','system','streak','social')),
    source_id           UUID,                               -- e.g. ai_messages.id or routines.id

    -- Content
    title               TEXT NOT NULL,
    body                TEXT NOT NULL,
    deeplink            TEXT,                               -- e.g. 'optivus://coach' or 'optivus://routine/abc'
    image_url           TEXT,

    -- Tier (per PRD P1–P6 escalation)
    tier                SMALLINT NOT NULL DEFAULT 3
        CHECK (tier BETWEEN 1 AND 6),
    sound               TEXT,                               -- 'default','gentle','alarm','custom_xyz'

    -- Scheduling
    scheduled_for       TIMESTAMPTZ NOT NULL,
    delivered_at        TIMESTAMPTZ,
    failed_at           TIMESTAMPTZ,
    failure_reason      TEXT,

    -- User interaction
    read_at             TIMESTAMPTZ,
    tapped_at           TIMESTAMPTZ,
    dismissed_at        TIMESTAMPTZ,

    -- Reinstall safety (per audit P1)
    needs_reschedule    BOOLEAN NOT NULL DEFAULT FALSE,     -- true after app reinstall, false after re-registered

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    schema_version      SMALLINT NOT NULL DEFAULT 1
);

CREATE INDEX idx_notifications_user_scheduled ON notifications(user_id, scheduled_for)
    WHERE delivered_at IS NULL;
CREATE INDEX idx_notifications_user_undelivered ON notifications(user_id)
    WHERE delivered_at IS NULL AND scheduled_for < NOW() + INTERVAL '24 hours';
CREATE INDEX idx_notifications_needs_reschedule ON notifications(user_id)
    WHERE needs_reschedule = TRUE;
```

---

# Part 4 — Event Table Deep Dive

The events table will be 80% of total DB volume. Getting this right is the single most important decision in this document.

## 4.1 Event taxonomy (the canonical 24)

Every event has `event_type` matching one of these strings. Locked enum. Adding a new type requires a code release.

| Category | Type | Triggered by |
|---|---|---|
| **Habit** | `habit.good_logged` | User logs a good habit |
| | `habit.bad_logged` | User logs a bad habit |
| | `habit.target_met` | Daily/weekly target reached |
| **Routine** | `routine.started` | User taps "Start" on a routine |
| | `routine.step_completed` | Single step done |
| | `routine.completed` | All steps done |
| | `routine.window_missed` | Window closed without completion |
| | `routine.window_closing` | 15 min before window closes (watched) |
| **Task** | `task.created` | User adds a task |
| | `task.started` | State change Scheduled→Started |
| | `task.paused` | Started→Paused |
| | `task.completed` | Any→Completed |
| | `task.abandoned` | Any→Abandoned |
| **Streak** | `streak.milestone` | Hit 7/14/30/60/90/100/365 |
| | `streak.broken` | Streak reset |
| | `streak.recovered` | Returned to streak after break |
| **Screen time** | `screen_time.logged` | Daily log entered |
| | `screen_time.exceeded` | Crossed user limit |
| **Addiction** | `addiction.logged` | Cigarette/etc. logged |
| | `addiction.relapse` | After clean streak ≥1 day |
| **User** | `user.day_closed` | Day-close rollup completed |
| | `user.inactive_24h` | No app open in 24h |
| | `user.inactive_48h` | No app open in 48h |
| **Chat** | `chat.user_message` | User typed in coach chat |

## 4.2 Partitioning

The events table is **partitioned by month** on `occurred_at`. New partition created automatically by a Cloud Scheduler job (or `pg_partman`).

```sql
-- Master table (already shown in §3.9)

-- Partitions
CREATE TABLE events_2026_04 PARTITION OF events
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');

CREATE TABLE events_2026_05 PARTITION OF events
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

-- Default partition (catches anything outside known ranges)
CREATE TABLE events_default PARTITION OF events DEFAULT;
```

**Retention policy:**
- Partitions younger than 90 days: hot, in primary DB
- Partitions 90 days to 18 months: detached, exported to S3 as Parquet, queryable via Athena/BigQuery
- Partitions older than 18 months: deleted (after Parquet archive verified)

Detaching a partition is `O(1)`. Dropping is `O(1)`. This is why Postgres native partitions beat row-level deletes by orders of magnitude.

## 4.3 Indexes per partition

Each partition gets these indexes (created automatically by `pg_partman` template):

```sql
-- On every partition:
CREATE INDEX ON events_YYYY_MM (user_id, occurred_at DESC);
CREATE INDEX ON events_YYYY_MM (user_id, event_type, occurred_at DESC);
CREATE INDEX ON events_YYYY_MM (event_type, occurred_at DESC);
CREATE INDEX ON events_YYYY_MM (habit_id, occurred_at DESC) WHERE habit_id IS NOT NULL;
CREATE INDEX ON events_YYYY_MM (routine_id, occurred_at DESC) WHERE routine_id IS NOT NULL;
CREATE INDEX ON events_YYYY_MM (task_id, occurred_at DESC) WHERE task_id IS NOT NULL;
```

Partial indexes on the GENERATED columns (`habit_id` etc.) make joins to the parent tables fast without bloating index size on events that don't have those fields.

## 4.4 Event metadata patterns

`metadata` is JSONB, but the shape per event_type is contractual. Sample shapes:

```jsonc
// habit.bad_logged
{
  "habit_id": "uuid-of-cigarettes-habit",
  "habit_name": "cigarettes",                    // denormalized for display
  "count_today": 1,
  "trigger": "stress",
  "occurred_at_local": "14:23",                  // user's local time
  "user_state_at_log": "on_track"
}

// routine.window_missed
{
  "routine_id": "uuid",
  "routine_name": "morning_skin_care",
  "window_start": "07:00",
  "window_end": "09:00",
  "completion_pct": 0,
  "steps_completed": [],
  "miss_count_7d": 2
}

// streak.milestone
{
  "streak_type": "habit_good",
  "target_id": "uuid-of-meditation-habit",
  "habit_name": "meditation",
  "value": 7,
  "longest_ever": 12
}

// chat.user_message
{
  "message_id": "uuid",
  "text_length": 187,
  "stress_markers_matched": ["overwhelmed", "cant focus"],
  "crisis_markers_matched": [],
  "char_count": 187
}
```

**Important rule:** never store user-typed free text (chat messages, journal bodies, notes) inside `metadata`. Reasons:
- GDPR/data deletion gets hard (find every event with PII)
- Bloats event table
- The actual text lives in dedicated tables (`ai_messages`, `journal_entries`)

Store *references* and *derived signals* only. The example above stores `message_id` and counts, not the message body.

## 4.5 Insert path

Events arrive at ~1k/user/day at scale. The hot path:

```
[Client app]
  → POST /events  (with user JWT)
  → Edge Cloud Function:
       1. validate event_type, schema_version
       2. write to events (single INSERT, partition routes automatically)
       3. publish to internal pub/sub: 'event.<type>'
  → Subscribed services pick up:
       - CoachService (for AI rule eval)
       - StreakService (for incremental streak update)
       - NotificationService (for follow-up scheduling)
```

Each subscriber is independent. Failure of one doesn't block others. This is the event-driven property that makes the architecture scalable.

---

# Part 5 — Relationships

## 5.1 ER overview

```
                            ┌──────────┐
                            │  users   │
                            └─────┬────┘
                                  │ 1
                ┌─────────────────┼─────────────────┐
                │ N               │ N               │ N
          ┌─────▼────┐      ┌─────▼─────┐    ┌─────▼────┐
          │  habits  │      │ routines  │    │  goals   │
          └────┬─────┘      └─────┬─────┘    └────┬─────┘
               │ 1                │ 1             │ 1
               │ N                │ N             │ N
       ┌───────▼──────┐   ┌──────▼─────────┐   ┌──▼───────────┐
       │  habit_logs  │   │  routine_      │   │ goal_progress│
       └──────────────┘   │  completions   │   └──────────────┘
                          └────────────────┘

      users ──1:N──> events  (the central spine, partitioned by month)
      users ──1:N──> ai_messages
      users ──1:N──> notifications
      users ──1:N──> journal_entries
      users ──1:N──> tasks ──N:1──> routines (optional)
                     tasks ──N:1──> goals (optional)

      streaks: one row per (user, streak_type, target_id)
      ai_rule_logs: every coach decision, with FK to user, rule, and event (no FK on event)
      ai_messages: FK to ai_rule_logs (when rule-driven), FK to user always
```

## 5.2 Cardinality table

| Parent | Child | Cardinality | Cascade |
|---|---|---|---|
| users | sessions | 1:N | DELETE CASCADE |
| users | habits | 1:N | DELETE CASCADE |
| habits | habit_logs | 1:N | DELETE CASCADE |
| users | routines | 1:N | DELETE CASCADE |
| routines | routine_completions | 1:N | DELETE CASCADE |
| users | goals | 1:N | DELETE CASCADE |
| goals | goal_progress | 1:N | DELETE CASCADE |
| users | tasks | 1:N | DELETE CASCADE |
| routines | tasks | 1:N | SET NULL (tasks survive routine deletion) |
| goals | tasks | 1:N | SET NULL |
| users | streaks | 1:N | DELETE CASCADE |
| users | events | 1:N | (no FK — partition root limitation) |
| users | journal_entries | 1:N | DELETE CASCADE |
| users | ai_messages | 1:N | DELETE CASCADE |
| ai_rules | ai_rule_logs | 1:N | RESTRICT (don't delete rules with logs) |
| ai_rule_logs | ai_messages | 1:1 (when rule-driven) | SET NULL |
| users | notifications | 1:N | DELETE CASCADE |

**Why no FK from events to users:** Postgres requires the FK to reference the partition root key. With composite primary key `(id, occurred_at)`, you can't FK *into* events from elsewhere, and a cross-partition FK from events *to* users hurts insert speed at scale. We enforce user existence at write time via the application service layer.

## 5.3 The "events as audit log" pattern

Events are not just routing triggers — they're the audit log. Three guarantees:

1. **Append-only.** Never UPDATE or DELETE an event row. Corrections go in as new events with `metadata.corrects_event_id`.
2. **Immutable timestamp.** `occurred_at` is set at insert and never changes.
3. **Replayable.** Given the events log, you can reconstruct streaks, completions, and user state. This is the "service A doesn't call service B" invariant from the audit — events are the only contract between services.

---

# Part 6 — AI Rule Engine Storage (consolidated)

This section consolidates AI-related storage from §3 with the contract from `Optivus_AI_Master_Engine.md`.

## 6.1 The four AI tables and their job

| Table | Purpose | Row count at 100k MAU |
|---|---|---|
| `ai_rules` | Rule catalog (synced from code) | ~50 rows total |
| `ai_rule_logs` | Every routing decision (spoke, dropped, deferred) | ~10/user/day → 1M/day |
| `ai_messages` | Every coach message + every user reply | ~5/user/day → 500k/day |
| `ai_context_history` | Snapshots for chat continuity | ~3/user/day → 300k/day, 30-day TTL |

`ai_rule_logs` is the largest of the four. It's not partitioned in v1 (volume is manageable up to ~50M rows on a beefy instance), but it should be partitioned by month before it crosses 100M.

## 6.2 Why `ai_rule_logs` is precious

This table answers questions you don't know you'll ask yet:

- "Why didn't the coach speak to user X yesterday?" → query `ai_rule_logs` filtered by user_id, see drop reasons.
- "Which rules fire most?" → `GROUP BY rule_id, COUNT(*)`.
- "Are we hitting cooldown too often?" → `WHERE drop_reason = 'cooldown'`.
- "Is rule_id 'slip_cigarette_strict_on_track' too noisy?" → ratio of spoke vs dropped.

Without this log, debugging the engine is guessing. **Antigravity: do not skip writing to this table to "save space."** It pays for itself the first time something breaks in production.

## 6.3 Coach state in Redis (not Postgres)

Three keys per user, all in Redis:

```
coach:{user_id}:budget:YYYY-MM-DD   → integer (decremented per speak), TTL 26h
coach:{user_id}:cooldown:{topic}    → unix timestamp, TTL = cooldown_seconds
coach:{user_id}:lastspoke           → unix timestamp, TTL 1h
```

Why Redis: these are read on *every* event arrival. At 1B events/day, hitting Postgres for cooldown checks is 10× more reads than Postgres should serve. Redis handles it for ~$30/month.

If Redis is down, the engine *fails open* — assumes no cooldown, no budget consumed, speaks if other gates pass. This is intentional. Better to occasionally double-message than to silence the coach during an outage.

## 6.4 Linking rule logs to messages

Every coach message that comes from a rule has a chain:

```
event (event.id)
  → ai_rule_logs (event_id = event.id, decision = 'spoke')
    → ai_messages (rule_log_id = ai_rule_logs.id)
      → notifications (source = 'coach', source_id = ai_messages.id)
```

This chain lets you trace "the user got this push notification because of this event 12 minutes earlier" — invaluable for debugging.

User-typed chat replies (no rule fired) have `rule_id = NULL`, `rule_log_id = NULL`, `role = 'user'`.

---

# Part 7 — Scalability Strategy

## 7.1 Indexing strategy summary

Three principles applied throughout:

1. **Index every foreign key.** Postgres doesn't auto-index FKs. We've explicitly created them on every parent_id column.
2. **Partial indexes for hot subsets.** `WHERE deleted_at IS NULL`, `WHERE state = 'active'`, etc. Half the index size, twice the speed.
3. **Composite indexes match query patterns.** `(user_id, occurred_at DESC)` because every UI query is "this user, recent first."

Every index is justified by a query in §9. If a query doesn't exist, the index doesn't exist. Adding indexes "just in case" is a real cost — slower writes, larger memory footprint.

## 7.2 Partitioning summary

| Table | Partitioned? | Strategy |
|---|---|---|
| `events` | Yes | Range by month on `occurred_at`. 90-day hot, archive older. |
| `ai_rule_logs` | At v2 | Range by month on `occurred_at`. Threshold ~100M rows. |
| `ai_messages` | At v2 | Range by month on `created_at`. Same threshold. |
| `notifications` | At v3 | Only after >50M rows. Most are short-lived. |
| Everything else | No | None should grow that fast. |

## 7.3 Caching layer (Redis)

| Key pattern | Purpose | TTL |
|---|---|---|
| `coach:{uid}:budget:{date}` | Daily speak budget | 26h |
| `coach:{uid}:cooldown:{topic}` | Per-topic cooldown | rule.cooldown_seconds |
| `coach:{uid}:lastspoke` | Rate limit (15-min) | 1h |
| `coach:{uid}:context_summary` | Pre-computed context for fast prompt building | 5 min |
| `user:{uid}:state` | Current user_state classification | 1h |
| `user:{uid}:streaks_active` | Set of active streak summaries | 1h, invalidated on day_close |
| `mission_ring:{uid}:{date}` | Computed completion % | 5 min |
| `session:{token_hash}` | Active session | until expiry |

**Cache invalidation rule:** writes to Postgres invalidate Redis. The app code does this via service-layer interceptors. Stale cache > stale data.

## 7.4 Read replicas

At 50k+ MAU, deploy a Postgres read replica. Route to it:

- Tracker tab queries (last 30 days of habit_logs)
- Profile screen queries (streaks, totals)
- Mission ring computation
- Analytics for the strategic AI planner

Keep on primary:
- Auth (sessions table)
- Event writes
- Day-close transactions
- Anything in a write transaction

## 7.5 Materialized views

Two materialized views, refreshed at day-close per user (or hourly globally):

```sql
CREATE MATERIALIZED VIEW user_daily_summary AS
SELECT
    user_id,
    DATE(occurred_at AT TIME ZONE 'UTC') AS day,
    COUNT(*) FILTER (WHERE event_type = 'habit.good_logged') AS good_habits,
    COUNT(*) FILTER (WHERE event_type = 'habit.bad_logged') AS bad_habits,
    COUNT(*) FILTER (WHERE event_type = 'task.completed') AS tasks_done,
    COUNT(*) FILTER (WHERE event_type = 'routine.completed') AS routines_done,
    COUNT(*) FILTER (WHERE event_type = 'routine.window_missed') AS routines_missed
FROM events
WHERE occurred_at > NOW() - INTERVAL '90 days'
GROUP BY user_id, DATE(occurred_at AT TIME ZONE 'UTC');

CREATE UNIQUE INDEX ON user_daily_summary (user_id, day);

-- Refresh nightly:
-- REFRESH MATERIALIZED VIEW CONCURRENTLY user_daily_summary;
```

This view drives the routine completion 7-day chart on the home screen. Without it, the chart query is a costly aggregate over events on every page load.

## 7.6 Cost projection

At 100k MAU, ~1k events/user/day = 100M events/day = 3B/month. Estimate:

| Component | Monthly cost |
|---|---:|
| Postgres primary (8 vCPU, 32 GB RAM, 1 TB SSD) | $400 |
| Postgres read replica (4 vCPU, 16 GB) | $200 |
| Redis (4 GB managed) | $50 |
| S3 archive (50 GB Parquet/month) | $5 |
| Cloud Functions (event ingestion + scheduled jobs) | $150 |
| Anthropic API (Claude Haiku, ~5 messages/user/day) | $1,200 |
| Firebase Auth (still primary identity) | $80 |
| **Total** | **~$2,085** |

This is roughly half what Firestore-only would cost at the same scale. The Anthropic line is the largest variable — can be cut 50% by using Haiku 4.5 instead of larger models for fallback wording.

---

# Part 8 — Sample Data

Real-shape INSERTs. Use these as seed data for local dev.

## 8.1 Sample user

```sql
INSERT INTO users (
    id, email, firebase_uid, name,
    accountability_mode, coach_name, coach_style, identity_tags,
    eating_disorder_flag, coach_enabled,
    birth_date, height_cm, weight_kg, sex,
    has_completed_onboarding, onboarding_completed_at, timezone, locale
) VALUES (
    '01927f3a-1234-7000-8000-000000000001',
    'nairit@example.com',
    'firebase-uid-abc',
    'Nairit',
    'strict',
    'Sensei',
    'supportive',
    ARRAY['Strong Body','Inner Peace','Disciplined Mind'],
    FALSE,
    TRUE,
    '2006-08-15',
    175,
    50.0,
    'male',
    TRUE,
    '2026-04-20T10:30:00+05:30',
    'Asia/Kolkata',
    'en-IN'
);
```

## 8.2 Sample habit

```sql
-- A bad habit: cigarettes
INSERT INTO habits (
    id, user_id, name, kind, category,
    target_per_day, unit, identity_tags, color, icon
) VALUES (
    '01927f3a-1234-7000-8001-000000000001',
    '01927f3a-1234-7000-8000-000000000001',
    'Cigarettes',
    'bad',
    'recovery',
    0,                                                  -- target = 0 for bad habits
    'cigarette',
    ARRAY['Strong Body'],
    'D54848',
    'smoking'
);

-- A good habit: gym
INSERT INTO habits (
    id, user_id, name, kind, category,
    target_per_week, unit, identity_tags, color, icon
) VALUES (
    '01927f3a-1234-7000-8001-000000000002',
    '01927f3a-1234-7000-8000-000000000001',
    'Gym',
    'good',
    'health',
    4,
    'session',
    ARRAY['Strong Body','Disciplined Mind'],
    '4A90E2',
    'dumbbell'
);
```

## 8.3 Sample event (slip event)

```sql
INSERT INTO events (
    id, user_id, event_type, occurred_at, metadata, source
) VALUES (
    '01927f3a-1234-7000-8002-000000000001',
    '01927f3a-1234-7000-8000-000000000001',
    'habit.bad_logged',
    '2026-04-26T14:23:00+05:30',
    jsonb_build_object(
        'habit_id', '01927f3a-1234-7000-8001-000000000001',
        'habit_name', 'cigarettes',
        'count_today', 1,
        'trigger', 'stress',
        'occurred_at_local', '14:23',
        'user_state_at_log', 'on_track',
        'clean_streak_before_slip', 3
    ),
    'app'
);
```

## 8.4 Sample AI rule log + message

```sql
-- The decision log entry
INSERT INTO ai_rule_logs (
    id, user_id, rule_id, event_id,
    decision, context_snapshot, user_state, accountability,
    occurred_at
) VALUES (
    '01927f3a-1234-7000-8003-000000000001',
    '01927f3a-1234-7000-8000-000000000001',
    'slip_cigarette_strict_on_track',
    '01927f3a-1234-7000-8002-000000000001',
    'spoke',
    jsonb_build_object(
        'speak_budget_remaining', 5,
        'topics_spoken_last_24h', ARRAY['morning_brief'],
        'silence_window', false,
        'time_since_last_spoke_min', 240
    ),
    'on_track',
    'strict',
    '2026-04-26T14:23:08+05:30'
);

-- The actual message the user saw
INSERT INTO ai_messages (
    id, user_id, rule_id, rule_log_id, triggering_event_id,
    role, body, message_type, priority,
    llm_model, llm_latency_ms, llm_tokens_in, llm_tokens_out, used_fallback,
    suggested_actions, followup_scheduled_at,
    delivered_at, created_at
) VALUES (
    '01927f3a-1234-7000-8004-000000000001',
    '01927f3a-1234-7000-8000-000000000001',
    'slip_cigarette_strict_on_track',
    '01927f3a-1234-7000-8003-000000000001',
    '01927f3a-1234-7000-8002-000000000001',
    'coach',
    'First one in 3 days — not nothing. What set it off today?',
    'check_in',
    2,
    'claude-haiku-4-5',
    1247,
    320,
    24,
    FALSE,
    jsonb_build_array(
        jsonb_build_object('label','Log trigger','action','log_trigger','params', '{}'::jsonb),
        jsonb_build_object('label','Set guard rail','action','set_guardrail','params','{}'::jsonb),
        jsonb_build_object('label','Talk to me','action','open_chat','params','{}'::jsonb)
    ),
    '2026-04-26T16:23:08+05:30',
    '2026-04-26T14:23:09+05:30',
    '2026-04-26T14:23:09+05:30'
);
```

## 8.5 Sample streak

```sql
INSERT INTO streaks (
    user_id, streak_type, target_id, accountability,
    current_streak, longest_streak, total_completions,
    started_on, last_completion_on, state
) VALUES (
    '01927f3a-1234-7000-8000-000000000001',
    'habit_good',
    '01927f3a-1234-7000-8001-000000000002',  -- gym
    'strict',
    5,
    12,
    47,
    '2026-04-22',
    '2026-04-26',
    'active'
);
```

---

# Part 9 — Query Examples

The 12 queries the app actually runs. Each is given with the index it relies on.

## 9.1 Get today's habits for user

```sql
SELECT h.id, h.name, h.kind, h.target_per_day, h.color, h.icon,
       COUNT(hl.id) FILTER (WHERE DATE(hl.occurred_at AT TIME ZONE u.timezone) = CURRENT_DATE) AS logged_today
FROM habits h
JOIN users u ON u.id = h.user_id
LEFT JOIN habit_logs hl ON hl.habit_id = h.id
    AND hl.occurred_at > NOW() - INTERVAL '24 hours'
WHERE h.user_id = $1
  AND h.deleted_at IS NULL
  AND h.is_active = TRUE
GROUP BY h.id, u.timezone
ORDER BY h.kind DESC, h.name;
```
*Uses: `idx_habits_user_id`, `idx_habit_logs_user_today`*

## 9.2 Get missed routines (last 7 days)

```sql
SELECT rc.id, r.name, rc.occurred_on, rc.completion_pct, rc.state
FROM routine_completions rc
JOIN routines r ON r.id = rc.routine_id
WHERE rc.user_id = $1
  AND rc.state IN ('missed','partial')
  AND rc.occurred_on > CURRENT_DATE - INTERVAL '7 days'
ORDER BY rc.occurred_on DESC;
```
*Uses: `idx_routine_completions_state`*

## 9.3 Get user events for last 24h

```sql
SELECT id, event_type, occurred_at, metadata
FROM events
WHERE user_id = $1
  AND occurred_at > NOW() - INTERVAL '24 hours'
ORDER BY occurred_at DESC
LIMIT 200;
```
*Uses: per-partition `(user_id, occurred_at DESC)` index. Partition pruning kicks in — only the current partition is scanned.*

## 9.4 Get AI message history (chat tab)

```sql
SELECT id, role, body, message_type, suggested_actions, created_at, read_at
FROM ai_messages
WHERE user_id = $1
ORDER BY created_at DESC
LIMIT 50;
```
*Uses: `idx_ai_messages_user_created`*

## 9.5 Get unread coach messages

```sql
SELECT id, body, message_type, priority, created_at
FROM ai_messages
WHERE user_id = $1
  AND role = 'coach'
  AND read_at IS NULL
ORDER BY created_at ASC;
```
*Uses: `idx_ai_messages_unread`*

## 9.6 Compute mission ring % for today

```sql
WITH today_data AS (
    SELECT
        SUM(CASE WHEN rc.state = 'completed' THEN g.ring_weight
                 WHEN rc.state = 'partial'   THEN g.ring_weight * rc.completion_pct
                 ELSE 0 END) AS achieved,
        SUM(g.ring_weight) AS total
    FROM routines r
    LEFT JOIN routine_completions rc ON rc.routine_id = r.id AND rc.occurred_on = CURRENT_DATE
    LEFT JOIN goals g ON g.id = ANY(r.identity_tags::UUID[])  -- pseudocode; actual join via task→goal
    WHERE r.user_id = $1 AND r.is_active = TRUE
)
SELECT COALESCE(achieved / NULLIF(total, 0), 0) AS mission_ring_pct
FROM today_data;
```
*This one is heavy — that's why §7.5 cached it as a Redis key with 5-min TTL.*

## 9.7 Get current streaks

```sql
SELECT s.streak_type, s.target_id,
       CASE s.streak_type
           WHEN 'habit_good' THEN h.name
           WHEN 'habit_bad_clean' THEN h.name
           WHEN 'routine' THEN r.name
           WHEN 'goal' THEN g.title
       END AS target_name,
       s.current_streak, s.longest_streak, s.last_completion_on, s.state
FROM streaks s
LEFT JOIN habits h ON h.id = s.target_id AND s.streak_type IN ('habit_good','habit_bad_clean')
LEFT JOIN routines r ON r.id = s.target_id AND s.streak_type = 'routine'
LEFT JOIN goals g ON g.id = s.target_id AND s.streak_type = 'goal'
WHERE s.user_id = $1
  AND s.state = 'active'
  AND s.current_streak > 0
ORDER BY s.current_streak DESC;
```
*Uses: `idx_streaks_user_active`*

## 9.8 Cigarettes today + cost (money saved tracker)

```sql
SELECT
    COUNT(*) AS smoked_today,
    COALESCE(SUM(quantity), 0) AS units_today,
    COALESCE(SUM(cost_cents), 0) AS cost_today_cents,
    -- "money saved" = (avg daily * days_clean * cost_per_unit) for clean days
    (SELECT current_streak FROM streaks
     WHERE user_id = $1 AND streak_type = 'habit_bad_clean'
     AND target_id = (SELECT id FROM habits WHERE user_id = $1 AND name = 'Cigarettes' LIMIT 1)
    ) AS clean_streak_days
FROM addiction_logs
WHERE user_id = $1
  AND addiction_type = 'cigarettes'
  AND occurred_at >= (CURRENT_DATE AT TIME ZONE 'Asia/Kolkata');
```
*Uses: `idx_addiction_logs_type`*

## 9.9 Recent journal search ("entries about my dad")

```sql
SELECT id, title, occurred_on, mood_score,
       ts_headline('english', body, query, 'MaxWords=20') AS preview
FROM journal_entries, plainto_tsquery('english', 'dad') AS query
WHERE user_id = $1
  AND deleted_at IS NULL
  AND to_tsvector('english', body) @@ query
ORDER BY occurred_on DESC
LIMIT 20;
```
*Uses: `idx_journal_search_body` (GIN)*

## 9.10 Coach decision audit ("why did the coach speak/not speak yesterday?")

```sql
SELECT arl.occurred_at, arl.rule_id, arl.decision, arl.drop_reason,
       am.body AS message_sent
FROM ai_rule_logs arl
LEFT JOIN ai_messages am ON am.rule_log_id = arl.id
WHERE arl.user_id = $1
  AND arl.occurred_at > NOW() - INTERVAL '24 hours'
ORDER BY arl.occurred_at DESC;
```
*Uses: `idx_ai_rule_logs_user_time`*

## 9.11 Day-close transaction (atomic)

```sql
BEGIN;

-- 1. Compute completion for all today's routines
INSERT INTO routine_completions (user_id, routine_id, occurred_on, completion_pct, state, started_at, completed_at)
SELECT $1, r.id, CURRENT_DATE,
       /* computed from steps_completed */ 0.85, 'partial',
       NOW(), NOW()
FROM routines r
WHERE r.user_id = $1 AND r.is_active = TRUE
ON CONFLICT (user_id, routine_id, occurred_on) DO UPDATE
    SET completion_pct = EXCLUDED.completion_pct,
        state = EXCLUDED.state,
        updated_at = NOW();

-- 2. Update streaks
UPDATE streaks
SET current_streak = current_streak + 1,
    longest_streak = GREATEST(longest_streak, current_streak + 1),
    last_completion_on = CURRENT_DATE,
    updated_at = NOW()
WHERE user_id = $1
  AND state = 'active'
  AND /* streak-specific completion criteria */ TRUE;

-- 3. Emit day_closed event
INSERT INTO events (user_id, event_type, occurred_at, metadata, source)
VALUES ($1, 'user.day_closed', NOW(), jsonb_build_object('day', CURRENT_DATE), 'scheduler');

-- 4. Refresh cached materialized view for this user
REFRESH MATERIALIZED VIEW CONCURRENTLY user_daily_summary;

COMMIT;
```

This atomicity is *the* reason we left Firestore. Day-close on Firestore requires multiple cross-collection writes that aren't transactional — partial failure leaves user state inconsistent.

## 9.12 Cohort: users in 'slipping' state for 7+ days

```sql
SELECT u.id, u.email, u.coach_name,
       COUNT(*) FILTER (WHERE rc.state IN ('missed','partial')) AS misses_7d,
       AVG(rc.completion_pct) AS avg_completion_7d
FROM users u
JOIN routine_completions rc ON rc.user_id = u.id
WHERE rc.occurred_on > CURRENT_DATE - INTERVAL '7 days'
  AND u.has_completed_onboarding = TRUE
  AND u.deleted_at IS NULL
GROUP BY u.id
HAVING AVG(rc.completion_pct) < 0.50
ORDER BY avg_completion_7d ASC;
```

This is the kind of query that's a 50-line Cloud Function pulling from 7 Firestore collections — but it's a single SQL statement here. This is the migration's payoff.

---

# Part 10 — Design Principles

The decisions throughout this document follow these principles. Antigravity should refer back here when deciding on a new table or column not specified.

## 10.1 Normalize for truth, denormalize for speed

Each piece of data has one place that's the source of truth. But hot fields (user.accountability_mode, habit.color) are duplicated into events and logs because:
- They're stable (rarely change)
- They're read on every event evaluation
- Joining to look them up at read time costs more than the duplicate storage

When you denormalize, document it (see "Why denormalize coach fields here" in §3.1).

## 10.2 Append-only where possible

Events, habit_logs, addiction_logs, ai_rule_logs are append-only. Never UPDATE rows. This gives:
- Audit trail for free
- No write conflicts
- Easy partition + archive

Tables with UPDATE semantics (users, habits, routines, goals) keep `updated_at` and consider future use of `pg_audit` for change history if compliance demands it.

## 10.3 JSONB for flexibility, columns for queryability

`metadata JSONB` on events allows new event shapes without schema changes. But fields needed for indexing get pulled out as GENERATED columns (see `events.habit_id`). Best of both worlds.

Don't reach for JSONB just because you might need flexibility later. Real columns are faster, type-safer, and easier to query. Use JSONB when the shape genuinely varies.

## 10.4 Time zones matter

Every timestamp is `TIMESTAMPTZ`. Every "today" calculation uses `AT TIME ZONE u.timezone`. Storing local time strings for display only is acceptable (`metadata.occurred_at_local`).

## 10.5 Schema versions everywhere

Every table has `schema_version`. This lets us:
- Migrate row-by-row in the background without locks
- Read both old and new shapes during a migration
- Identify which records need attention after a deployment

Default 1, bump on breaking change to that table's row shape.

## 10.6 The hard stops

Things this schema deliberately does NOT do:

- **No `users.password_hash`** — auth is Firebase. Optivus stores no passwords.
- **No raw OAuth/Gemini/Anthropic API tokens** — all in environment, never in DB.
- **No PII in event metadata** — references only.
- **No silent data deletion** — soft delete first, hard delete only after explicit cascade.
- **No GraphQL-style nested writes** — every write touches one or two tables; complex multi-write goes through a service function with an explicit transaction.
- **No `ENUM` types** — they're painful to alter. We use `TEXT` + `CHECK` constraint.
- **No sequence-based IDs** — UUIDs everywhere. No "next ID" leaks.

---

# Part 11 — Open Questions

Explicitly undecided. Antigravity must NOT silently pick — flag and ask Nairit.

### Q1. Migrate off Firestore now, in 6 weeks, or never?
The recommendation is "after event system is built" (§1.4). The alternative — staying on Firestore — is feasible for v1 but caps growth. Decide based on business runway.

### Q2. Postgres host: Neon, Supabase, or self-hosted on GCP?
Neon (serverless, cheap to start, scales). Supabase (Postgres + RLS + auth bundled, but auth conflicts with Firebase). GCP Cloud SQL (most control, most cost). Recommendation: Neon for solo-dev phase.

### Q3. Replicate writes to BigQuery for analytics, or query Postgres replica?
For first 100k MAU: query the read replica. After that: stream events to BigQuery for cohort analysis. Don't build the BQ pipeline before you need it.

### Q4. Row-level security (RLS) on every table?
Postgres RLS can enforce "user X can only read user X's rows" at the DB layer. Powerful, but adds policy maintenance. Recommendation: enforce at service layer in v1, move to RLS once team grows.

### Q5. Partitioning strategy for `ai_rule_logs`?
Same as events (monthly range), but only after row count justifies it. Set up `pg_partman` template now, activate later.

### Q6. Search backend for journal entries?
Postgres GIN works up to ~10M entries. Beyond that, OpenSearch or Typesense. Defer until users complain about search speed.

### Q7. Real-time push to client?
For coach messages, the client subscribes to changes. Options: Postgres LISTEN/NOTIFY (Postgres-native), Pusher/Ably (managed), Firebase Realtime (incongruent if migrating off). Recommendation: keep `coach_messages` mirrored to a Firestore collection just for the realtime stream. Yes, this is dual-write — but it cleanly separates "source of truth" (Postgres) from "realtime push" (Firestore).

---

# Part 12 — Migration Path from Firestore

This is the actual sequence to get from "everything in Firestore" to "this schema." Six phases.

## Phase 1 — Stand up Postgres, dual-read (week 1)
- Provision Postgres + Redis
- Run all DDL migrations
- Create Cloud Function endpoint `/postgres-write` that mirrors writes
- App still reads from Firestore, but every write also goes to Postgres
- No user-facing change

## Phase 2 — Backfill (week 2)
- Export Firestore data via `gcloud firestore export`
- Transform Firestore docs → Postgres rows via a one-time Cloud Run job
- Validate row counts and sample records match
- Postgres now has historical data

## Phase 3 — Build the missing services (weeks 3–6)
- `EventService`, `HabitService`, `TaskService`, `StreakService`, `CoachService`
- All write to Postgres; all read from Postgres
- Existing routine/onboarding still on Firestore (parallel paths)

## Phase 4 — Switch reads (week 7)
- Toggle a feature flag per screen — Tracker tab reads from Postgres first
- Monitor latency + error rate for 1 week per screen
- Roll back if anything breaks

## Phase 5 — Stop dual-writing (week 8)
- Remove Firestore writes for migrated domains
- Keep `users` and `routines` collections in Firestore for now (they're stable)
- Optivus is now Postgres-primary

## Phase 6 — Final migration (week 12+)
- Migrate `users` profile and `routines` to Postgres
- Decommission Firestore (except realtime push collection in Q7)
- Done

Total elapsed: ~3 months calendar time, but only 4–5 weeks of actual eng work scattered across normal feature development. The migration runs alongside building the AI engine, not before.

---

# End of schema design

This document is the database backbone. Every other Optivus document depends on it:

- **PRD** describes user-facing behavior → this schema stores the data behind that behavior.
- **EventSystem doc** describes the event taxonomy → §4.1 is the canonical list.
- **AI Master Engine doc** describes coach logic → §3.10 stores rule decisions and messages.
- **ServiceContracts doc** describes service interfaces → those services read/write these tables.
- **Code audit** identified 0 of 6 services exist → this schema is what they'll talk to.

If a future change is proposed that conflicts with this schema, that change needs to update §3 (DDL), §4 (events) where relevant, §5 (relationships), and §9 (queries) together. They reference each other.

If you ship it well, you have a database that's built for the *shape* of Optivus — not retrofitted from a generic todo app. That's the bar.
