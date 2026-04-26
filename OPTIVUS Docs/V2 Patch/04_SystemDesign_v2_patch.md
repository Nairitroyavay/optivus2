# System Design (Production) v2 Patch

**Patches:** Optivus_SystemDesign_Production.md
**Changelog ref:** OPTIVUS_CHANGELOG_v2.md §1.8
**Apply by:** Insert one new section near the top of the Architecture section.
**Audience:** Nairit, Antigravity, Claude

---

## Patch 1 of 1 — Insert "Architecture Role Separation" section

**Location:** At the top of the System Architecture section, immediately after any
high-level architecture diagram and before the per-service detail.

**Action:** INSERT new section.

```markdown
## Architecture Role Separation

The v1 doc described both Postgres and Firestore as data layers. This was read by
some reviewers as inconsistency. It isn't — it's a deliberate role split. v2 makes
the roles explicit so there's no ambiguity for the reader or for Antigravity.

### Final architecture (v2)

```
                        ┌──────────────────┐
                        │   Android App    │
                        │   (Flutter UI)   │
                        └────────┬─────────┘
                                 │
                                 ▼
                        ┌──────────────────┐
                        │  API Gateway     │
                        │  (Cloud Run)     │
                        └────────┬─────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              ▼                  ▼                  ▼
       ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
       │ EventSvc    │    │ TaskSvc     │    │ CoachSvc    │
       │ HabitSvc    │    │ StreakSvc   │    │ NotifSvc    │
       └──────┬──────┘    └──────┬──────┘    └──────┬──────┘
              │                  │                  │
              └──────────┬───────┴──────────────────┘
                         │
        ┌────────────────┼────────────────┐
        ▼                ▼                ▼
   ┌─────────┐      ┌─────────┐      ┌─────────────┐
   │Postgres │      │  Redis  │      │  Firestore  │
   │ (truth) │      │ (cache) │      │ (realtime   │
   │         │      │         │      │  push only) │
   └─────────┘      └─────────┘      └─────────────┘
```

### Role table (canonical)

| Component | Role | What lives here | What does NOT live here |
|---|---|---|---|
| **Postgres** | Source of truth for ALL data | users, habits, routines, goals, tasks, events, streaks, ai_messages, ai_rule_logs, journal_entries, screen_time_logs, addiction_logs, notifications, sessions | Auth credentials (Firebase), transient counters (Redis), realtime push state (Firestore) |
| **Redis** | Cache + transient counters | Coach cooldowns, daily token budgets, rate limit counters, mission ring cache (5-min TTL), user_state cache (1h TTL), session lookups | Anything that must survive a Redis flush (which is everything important — Redis is a cache) |
| **Firestore** | Realtime push delivery layer | `coach_messages` collection (mirrored from Postgres `ai_messages` table for client streams) | Source-of-truth data, anything queried by Postgres services, anything used for analytics |

### What "Firestore is realtime push ONLY" means

The CoachTab in the Flutter app subscribes to a Firestore stream of `coach_messages`
to render new bubbles in real time as the engine produces them. This is the only
permitted use of Firestore in v2.

**Write path:** When CoachService writes a new message:
1. INSERT into Postgres `ai_messages` (source of truth)
2. Mirror-write to Firestore `coach_messages/{user_id}/messages/{message_id}`
   (push delivery only)
3. The mirror is fire-and-forget — if it fails, log and retry async; the Postgres
   write is what counts

**Read path:** Two readers, two purposes:
- CoachTab UI: subscribes to Firestore for streaming updates
- Any service, analytics, audit, debug query: reads from Postgres

If Firestore goes down: real-time updates degrade to polling Postgres (the app
detects subscription failure and falls back to a 30-second polling loop). Coach
messages still land. UX is worse but functional.

### What's left of Firestore from v1

During the migration (per Database Schema §12 phased plan):

| Phase | Firestore role |
|---|---|
| Today (pre-v2) | Owns users, routines, onboarding, ai chat — everything |
| Weeks 1–6 (transition) | Dual-write target for users + routines; new domains write to Postgres only |
| Weeks 7–11 (cutover) | Reads switching to Postgres per feature flag |
| Week 12+ (steady state) | ONLY `coach_messages` push collection, nothing else |

The dual-write phase is *not* an architectural inconsistency — it's a temporary
operational state with a defined end date. v2 docs assume the steady state.

### Why not collapse this into one of the others

You could ask: why not eliminate Firestore entirely and use Postgres LISTEN/NOTIFY
for realtime push? Answer: LISTEN/NOTIFY doesn't survive client reconnects well,
doesn't have battle-tested SDKs for Flutter, and adds operational complexity
(connection pooling, replica routing). Firestore's listener pattern is cheap,
mature, and battles tested. We pay for what we use.

You could also ask: why not eliminate Redis and use Postgres for everything?
Answer: cooldown checks fire on every event, ~10 reads per event arrival. At 1B
events/day, that's 10B Postgres reads/day for a fundamentally non-relational
operation. Redis handles it for $30/month. Postgres would handle it for $300+/month
and slow down everything else.

The three-tier architecture is the right shape for the workload.

### Hard rules (System Contract aligned)

These rules align with the System Contract in PRD §[System Contract]:

1. **Services write to Postgres first.** Any other write (Redis cache, Firestore
   mirror) is secondary and recoverable from Postgres.
2. **Services read from Postgres or Redis.** Never directly from Firestore (except
   the CoachTab UI, which is not a service).
3. **AI never reads from any data store directly.** Context Builder is the only
   bridge (per System Contract Rule 2).
4. **A failure in Redis or Firestore does not corrupt user data.** Both are
   recoverable / regeneratable from Postgres.
5. **A failure in Postgres is a P0 incident.** It's the only stateful single point
   of failure, by design.

### Service write order (atomic where possible)

For the day-close transaction (the most multi-write operation in the system), the
order is:

```
BEGIN TRANSACTION (Postgres)
  1. Compute completion for all today's routines → INSERT/UPDATE routine_completions
  2. Update streaks → UPDATE streaks
  3. Emit user.day_closed event → INSERT events
  4. Refresh materialized view → REFRESH MATERIALIZED VIEW CONCURRENTLY user_daily_summary
COMMIT
  5. (post-commit) Invalidate Redis caches for this user
  6. (post-commit) Mirror any new ai_messages to Firestore coach_messages
```

Steps 1–4 are atomic. Steps 5–6 are best-effort. If 5 fails: cache serves stale
data for up to 1h until natural TTL. If 6 fails: realtime push is delayed; user
sees the message on next app open or polling fallback.

This is the pattern for all multi-system operations: Postgres is transactional;
secondary systems are eventually consistent.
```

---

## End of System Design v2 patch

One change: a single new section that locks the Postgres + Redis + Firestore role
separation into explicit, named contracts.

No architectural redesign. The systems and services described in v1 are unchanged.
The patch only clarifies which data store does what — preventing the "v1 looks
inconsistent" misread.
