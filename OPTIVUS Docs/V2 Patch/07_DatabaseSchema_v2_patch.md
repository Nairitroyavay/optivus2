# Database Schema v2 Patch

**Patches:** Optivus_Database_Schema.md
**Changelog ref:** OPTIVUS_CHANGELOG_v2.md §1.12 (memory expansion), §3.1 (token budget keys), §2.3 (notification_logs deferral)
**Apply by:** Three small targeted edits.
**Audience:** Nairit, Antigravity, Claude

---

## Patch 1 of 3 — Expand `ai_context_snapshots` table notes

**Location:** §3.10 AI System, the existing `ai_context_snapshots` table definition.

**Action:** REPLACE the brief description with full memory-model alignment.

**Find:**
```markdown
### Table: `ai_context_history` (sliding context for the chat tab)
```

**Note:** the v1 doc named this `ai_context_history`. v2 renames to
`ai_context_snapshots` to align with the AI Master Engine doc's Memory Model
section. The rename is purely cosmetic but consistent.

**Replace the section with:**

```markdown
### Table: `ai_context_snapshots` (long-term memory + chat continuity)

This table serves two distinct purposes:

1. **Long-term coach memory** — weekly summaries the AI consults when constructing
   broader context (per AI Master Engine §6 Memory Model)
2. **Chat session continuity** — short-term context groupings for in-app chat
   threads

Both are user-visible in Profile → Coach Memory and user-deletable per row.
There is no other long-term AI memory store. No vector embeddings in v1.

```sql
CREATE TABLE ai_context_snapshots (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Discriminator: what kind of snapshot is this?
    snapshot_type   TEXT NOT NULL DEFAULT 'chat_session'
        CHECK (snapshot_type IN ('chat_session', 'weekly_summary', 'crisis_aftermath')),

    -- The structured payload (shape varies by snapshot_type)
    snapshot        JSONB NOT NULL,

    -- For weekly_summary type: the week this row covers
    -- For chat_session type: the moment of the snapshot
    -- For crisis_aftermath: the timestamp of the triggering event
    occurred_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- For chat_session: groups consecutive messages into a session
    chat_session_id UUID,

    -- User control surface
    is_deleted_by_user  BOOLEAN NOT NULL DEFAULT FALSE,
    user_deleted_at     TIMESTAMPTZ,

    schema_version  SMALLINT NOT NULL DEFAULT 1
);

-- Indexes
CREATE INDEX idx_ai_context_user_time ON ai_context_snapshots(user_id, occurred_at DESC)
    WHERE is_deleted_by_user = FALSE;

CREATE INDEX idx_ai_context_user_type_time ON ai_context_snapshots(user_id, snapshot_type, occurred_at DESC)
    WHERE is_deleted_by_user = FALSE;

CREATE INDEX idx_ai_context_chat_session ON ai_context_snapshots(chat_session_id, occurred_at)
    WHERE chat_session_id IS NOT NULL AND is_deleted_by_user = FALSE;

-- TTL policy (per snapshot_type):
--   chat_session: 30 days, then auto-archived (DELETE WHERE snapshot_type='chat_session' AND occurred_at < NOW() - INTERVAL '30 days')
--   weekly_summary: indefinite (user-controlled deletion only)
--   crisis_aftermath: 1 year, then archived
```

#### Snapshot payload shapes

**`weekly_summary`** (one per user per week, generated Sunday 23:55 user-local):

```jsonc
{
  "type": "weekly_summary",
  "week_starting": "2026-04-19",
  "completion_pct_avg": 0.65,
  "completion_pct_trend": "declining",
  "habits": {
    "cigarettes": {"count": 3, "trend": "stable"},
    "gym": {"completions": 2, "target": 4, "trend": "down"}
  },
  "user_state_during_week": ["on_track","on_track","slipping","slipping","slipping","relapsing","slipping"],
  "coach_messages_count": 4,
  "coach_topics_covered": ["cigarettes","gym","stress"],
  "stress_markers_in_chat": 1,
  "crisis_markers_in_chat": 0,
  "summary_text": "Week of Apr 19: completion declined from 80% to 50%. Smoked 3 days. Mentioned 'overwhelmed' once. Coach spoke 4 times, all C-rule (slip)."
}
```

**`chat_session`** (groups messages within a chat session):

```jsonc
{
  "type": "chat_session",
  "session_started_at": "2026-04-26T14:23:00+05:30",
  "session_ended_at": "2026-04-26T14:31:00+05:30",
  "message_count": 6,
  "topics_discussed": ["cigarettes_today", "stress_at_work"],
  "summary_text": "User initiated chat after slip. Discussed work stress as trigger. Agreed to 30-min lockout."
}
```

**`crisis_aftermath`** (one per Tier 1+ crisis trigger):

```jsonc
{
  "type": "crisis_aftermath",
  "tier": 1,
  "triggered_at": "2026-04-26T22:45:00+05:30",
  "silence_lock_until": "2026-04-27T22:45:00+05:30",
  "iCall_referral_shown": true,
  "user_acknowledgment": "I'm ok",
  "summary_text": "Tier 1 crisis trigger at night. User typed 'I'm ok' 3h later. Silence honored."
}
```

#### What the AI sees

The Context Builder fetches snapshots based on the rule's `long_term_context_weeks`
parameter (per AI Master Engine §6.4):

- Most rules: 0 weeks of long-term (current event log only)
- Weekly review: 4 weeks
- Crisis aftermath: 12 weeks
- Identity drift detection: 24 weeks

Only `summary_text` and basic stats (`completion_pct_avg`, `coach_messages_count`)
are fed into the LLM prompt. The full `snapshot` JSONB is for analytics and
user-visible audit.

#### User control surface

In Profile → Coach Memory:
- All non-deleted snapshots listed, newest first
- Each shows: type, date range, summary_text
- "Delete" button on each: sets `is_deleted_by_user = TRUE, user_deleted_at = NOW()`
  (soft delete — actual hard delete on a 24h delay so user can undo)
- "Delete all" button: bulk-flags all rows for this user

Soft-deleted rows are excluded from all reads via the partial indexes. After 24h,
a Cloud Scheduler hard-deletes flagged rows.
```

---

## Patch 2 of 3 — Add token budget keys to Redis pattern table

**Location:** §7.3 Caching layer (Redis), the key pattern table.

**Action:** APPEND rows to the existing table.

**Find:** the table starting with "Key pattern | Purpose | TTL".

**Append these rows:**

```markdown
| `ai_tokens:{uid}:{date}` | Daily AI token consumption counter | 26h |
| `ai_messages:{uid}:{date}` | Daily AI message count (matches speak budget) | 26h |
| `ai:global_kill_switch` | Boolean — global LLM disable flag | None (manually managed, monthly reset) |
| `ai:monthly_spend_usd` | Running total of monthly LLM spend | Until 1st of month UTC |
| `crisis:{uid}:trigger_count_7d` | Crisis trigger count for 7-day window | 7 days from last trigger |
| `crisis:{uid}:trigger_count_14d` | Crisis trigger count for 14-day window | 14 days from last trigger |
```

**Then add a brief explanation paragraph immediately after the table:**

```markdown
The `ai_tokens:` and `ai_messages:` keys enforce per-user daily caps from AI
Master Engine §11.1. The global keys (`ai:global_kill_switch`, `ai:monthly_spend_usd`)
enforce the monthly cap from §11.2.

Crisis counter keys (`crisis:{uid}:trigger_count_*`) drive the multi-tier crisis
escalation from AI Master Engine §3.1 Case E. Each crisis trigger increments both
counters; the 7-day key naturally expires sooner, demoting the user back from
Tier 2 to Tier 1 territory if they go a week clean. The 14-day key holds Tier 3
state for two weeks.

These keys are checked on every relevant event arrival. Performance-critical;
that's why they're in Redis and not Postgres.
```

---

## Patch 3 of 3 — Add Q8 to Open Questions about notification_logs

**Location:** §11 Open Questions, after the existing Q7.

**Action:** APPEND new question Q8.

```markdown
### Q8. Promote notification interaction tracking to a separate `notification_logs` table?

**Current state (v2):** All notification interaction state (`delivered_at`,
`read_at`, `tapped_at`, `dismissed_at`, `failed_at`) lives as columns on the
`notifications` table itself. Updates mutate these columns in place.

**Alternative:** Move interaction events to an append-only `notification_logs`
table. Each interaction (delivered, read, tapped, dismissed) becomes a new row.
The `notifications` table holds only the scheduling intent.

**Pros of the alternative:**
- Cleaner audit trail (every state change preserved with timestamp + metadata)
- Better fit with the append-only philosophy used elsewhere in the schema
- Easier compliance audits (can prove what was sent, when, and how the user reacted)

**Cons of the alternative:**
- Doubles storage for notifications (each one now has 1+ child rows)
- Requires JOIN for "what's the latest state of this notification?" queries
- Adds table-count to the schema for marginal initial benefit

**Recommendation:** Defer. Keep the in-row state model in v2. Promote to
`notification_logs` only after:
- First compliance audit demands it, OR
- Notification volume exceeds 50M rows total, OR
- Operational debugging requires per-state-transition timestamps frequently
  enough to be painful

**When promoted:** the migration is straightforward. The existing in-row
timestamps become seed rows in the new `notification_logs` table, and the
`notifications` table keeps the latest-state denormalized for fast UI queries
(via trigger-maintained columns or a view).

This is logged here so the deferral is explicit and the migration path is
preserved for later.
```

---

## End of Database Schema v2 patch

Three changes:
1. Expanded `ai_context_snapshots` (renamed from `ai_context_history`) with
   discriminator field, three payload shapes, soft-delete support, and user
   control surface
2. Added 6 Redis key patterns for token budgets, kill switch, and crisis counters
3. Added Q8 to Open Questions about future `notification_logs` table promotion

Existing tables, indexes, and partitioning strategies unchanged.
