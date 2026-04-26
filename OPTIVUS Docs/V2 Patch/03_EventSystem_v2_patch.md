# Event System v2 Patch

**Patches:** Optivus_EventSystem.md
**Changelog ref:** OPTIVUS_CHANGELOG_v2.md §1.7, §3.3, §1.6
**Apply by:** Insert two new sections + update the canonical taxonomy table.
**Audience:** Nairit, Antigravity, Claude

---

## Patch 1 of 3 — Insert "Event Guarantees" section

**Location:** After the existing event taxonomy/payload section, before any rule-engine integration discussion.

**Action:** INSERT new section.

```markdown
## Event Guarantees

The event log is the central nervous system. If events drop, get duplicated, or
arrive out of order silently, every downstream component (rule engine, streaks,
AI coach, analytics) corrupts. This section specifies the exact contract.

### Guarantee 1 — Idempotent writes

Every event has a client-generated UUIDv7 as `event_id`. The same event submitted
twice (network retry, app backgrounded mid-send, server retry) produces exactly
one row.

**Mechanism:**

```sql
-- The events table has event_id as primary key (per Database Schema §3.9):
CREATE TABLE events (
    id              UUID NOT NULL DEFAULT gen_random_uuid(),
    -- ... other columns
    PRIMARY KEY (id, occurred_at)
) PARTITION BY RANGE (occurred_at);

-- Every insert uses ON CONFLICT DO NOTHING:
INSERT INTO events (id, user_id, event_type, occurred_at, metadata, source, schema_version)
VALUES ($1, $2, $3, $4, $5, $6, $7)
ON CONFLICT (id, occurred_at) DO NOTHING
RETURNING id, (xmax = 0) AS was_inserted;
```

The `was_inserted` boolean lets the caller distinguish "inserted now" from "already
existed" — both are success states, but downstream side effects (publish to pub/sub,
emit notification) only fire when `was_inserted = TRUE`.

**Client responsibility:**
- Generate UUIDv7 on the client at the moment of the action (not at send time)
- Persist locally before sending — if app crashes mid-send, retry on next launch
  with the same UUID
- Retry indefinitely on network failure with exponential backoff (1s, 2s, 4s, 8s, 16s, 32s, cap)

### Guarantee 2 — Retry-safe pipeline

Every consumer of an event must be idempotent at its own layer.

| Consumer | Idempotency mechanism |
|---|---|
| `StreakService` | Computes streak from event log on each run — no incremental state that can desync |
| `CoachService` | Checks `coach_speak_log` for `(user_id, event_id, rule_id)` triple before speaking |
| `NotificationService` | `notifications` table has UNIQUE constraint on `(user_id, source_id, scheduled_for)` |
| Materialized views | `REFRESH MATERIALIZED VIEW CONCURRENTLY` is idempotent by definition |

If a consumer fails to enforce idempotency, the failure is on that consumer, not
the events layer. The events layer guarantees at-least-once delivery; consumers
upgrade it to exactly-once-side-effects.

### Guarantee 3 — No silent failures

Every event write outcome falls into one of these states. Each is logged.

| Outcome | Logged where | Action |
|---|---|---|
| `inserted` | Server access log | Publish to pub/sub |
| `duplicate_no_op` | Server access log (debug level) | Skip publish |
| `validation_failed` | Server error log + Crashlytics | Return 400 to client; client retries are pointless |
| `db_unavailable` | Server error log + alerting | Return 503; client retries with backoff |
| `partition_missing` | Server error log + critical alerting | Server-side incident — partition creation lagged |

**Hard rule:** no event write returns 200 OK without either (a) `was_inserted=TRUE`
and pub/sub publish confirmed, or (b) `was_inserted=FALSE` indicating duplicate.
Any other state is an error response. There is no "success but didn't actually
write" path.

### Guarantee 4 — Ordered within a user, not across users

Events for a single user are ordered by `occurred_at` (client-stamped). Events
across users are unordered. This is intentional — global ordering would require
distributed coordination that doesn't add value for any Optivus use case.

If two events for the same user have identical `occurred_at` (millisecond
collision — rare but possible at app open), tie-broken by `event_id` lexicographic
order (UUIDv7 has natural time sort built in).

### Guarantee 5 — Audit-trail integrity

Events are append-only. Never UPDATE. Never DELETE except by partition drop after
archive (per Database Schema §4.2). If a logged event is wrong (user logged
"smoking" when they meant "vaping"), the correction is a NEW event with
`metadata.corrects_event_id = <original_id>`. Both events remain in the log.

This means:
- The audit trail can be replayed to reconstruct any user state at any point in time
- Privacy law deletion is the only legitimate destructive operation
- Any code that tries to UPDATE or DELETE an event is a bug, regardless of intent
```

---

## Patch 2 of 3 — Insert "Taxonomy Governance" section

**Location:** After the "Event Guarantees" section, at the end of the doc before the closing.

**Action:** INSERT new section.

```markdown
## Taxonomy Governance

The 25-event taxonomy (24 from v1 + `screen_time.spike_detected` added in v2) is
locked. Adding, removing, or renaming events follows the process below.

Without governance, events accumulate by accident, break the rule engine quietly,
and six months later nobody knows what `task.maybe_started_v2` is.

### Adding a new event type

A new event type may be added only after all of the following are true:

1. **Documented use case.** A specific feature or rule consumes this event. No
   speculative events ("we might want this someday").
2. **Schema version bump.** The Event System doc bumps from `schema_version: N`
   to `N+1`. The bump is in this doc's header.
3. **Backward compatibility verified.** Existing rules that match against the
   `*` wildcard or that use `event_type IN (...)` filters still behave correctly.
4. **Canonical table updated.** The new event type is added to the canonical
   table (§4.1) with a clear category, trigger description, and example metadata
   shape.
5. **At least one consuming rule.** There must be a rule in `coach_rules.dart`
   that fires on this event. Otherwise the event is dead data.
6. **Single-PR rule.** All of the above land in one pull request, not spread
   across multiple. Partial PRs are not accepted.

### Removing an event type

A retired event type follows a 30-day deprecation window:

1. **Day 0:** Mark the event type `deprecated: true` in the canonical table.
   Existing emitters are migrated to the new event type. Both old and new are
   accepted.
2. **Day 0–30:** Both old and new events flow normally. Telemetry confirms emit
   rate of old type drops to ~0.
3. **Day 30:** Stop accepting writes for the old event type. Clients still
   sending it get a 200 response (so old app versions don't crash) but the event
   is silently no-op'd. Log to a `deprecated_event_attempts` table for tracking.
4. **Day 90:** Remove from canonical table. Codebase references removed.

### Renaming an event type

Renaming is treated as remove + add (do both, sequentially, never atomically).

This forces the deprecation window to apply, which is the right behavior — old
clients in the wild will still emit the old name, and the system must accept
those gracefully.

### Changing event metadata schema

Two cases:

**Adding optional fields:** Bump the event's metadata schema version (`metadata.schema_version`).
Old consumers that don't read the new field continue to work. No deprecation
window needed. Documented in the event type's row in §4.1.

**Removing or renaming fields:** Treated as a full event-type version bump
(deprecation window, parallel acceptance, eventual removal). The reason: any
consumer reading the removed field will fail. Same as removing the whole event.

**Required → optional:** Allowed without bump (loosens the contract).
**Optional → required:** Treated as field rename (full bump). Old emitters won't
include the field; if it's required, their writes fail.

### Approval flow

All event taxonomy changes require:

1. A PR that updates Event System §4.1 *and* the consuming rule(s) in AI Master
   Engine *and* the relevant DB indexes if needed
2. Description in the PR explicitly listing which other docs reference this event
   (search the seven canonical docs for the event name)
3. Code review approval from at least one person other than the author
4. (For solo dev phase): self-review with a 24-hour cooling-off period before
   merge — read the PR a day later before clicking merge

### Why this matters

The events log is the source of truth for streaks, mission rings, AI memory, and
analytics. A silent change to event semantics breaks all four. A 30-day deprecation
window for removals lets us catch consumers we forgot about. The single-PR rule
prevents partial migrations that leave the system in an inconsistent state.

This is overhead. It's worth it. The alternative — letting events drift — costs
weeks of debugging six months from now.
```

---

## Patch 3 of 3 — Update canonical event table to add `screen_time.spike_detected`

**Location:** §4.1 "Event taxonomy (the canonical 24)" — note: the section header
itself needs updating to "the canonical 25".

**Action:** REPLACE the section header and ADD one row to the table.

**Old header:**
```
## 4.1 Event taxonomy (the canonical 24)
```

**New header:**
```
## 4.1 Event taxonomy (the canonical 25)
```

**Add this row to the table, in the "Screen time" category section:**

```
| | `screen_time.spike_detected` | Background isolate detects single-app session crossing threshold (Android only) |
```

**Add a note immediately after the table:**

```markdown
> **Platform note:** `screen_time.spike_detected` only fires on Android. iOS users
> get `screen_time.logged` (manual) and `screen_time.exceeded` (manual or computed)
> but not the real-time spike event. See User Flow Passive Tracking section for
> details.

> **Schema version:** This taxonomy is at `schema_version: 2` as of the v2 changelog.
> Any future additions follow the Taxonomy Governance section below.
```

---

## End of Event System v2 patch

Three changes:
1. Inserted "Event Guarantees" section with five named guarantees and the exact
   idempotency SQL pattern
2. Inserted "Taxonomy Governance" section with the formal change process
3. Added `screen_time.spike_detected` as event #25 with platform note + schema_version bump

No existing event taxonomy semantics change. The 24 v1 events are untouched.
