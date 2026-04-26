# PRD v2 Patch

**Patches:** Optivus_PRD.md
**Changelog ref:** OPTIVUS_CHANGELOG_v2.md §1.1, §1.2, §1.3, §2.1
**Apply by:** Insert/replace the sections below at the marked locations in the v1 PRD.
**Audience:** Nairit, Antigravity, Claude

---

## Patch 1 of 4 — Insert "System Contract" section

**Location:** After the Executive Summary, before the Persona section.

**Action:** INSERT new section.

```markdown
## System Contract

These are the five non-negotiable rules of Optivus. Every feature, every service,
every line of code respects them. If a design choice conflicts with a System Contract
rule, the rule wins — change the design.

### Rule 1 — Decisions are based on actual logged events, not planned data
The engine never reasons from "the user has gym scheduled for 7pm." It reasons from
"the user did or didn't log a gym completion." Plans are aspirations. Events are truth.
The mission ring, streaks, AI coach, and analytics all read from the events log.

### Rule 2 — AI never reads the raw database
The Context Builder is the only path between user data and the LLM. Claude (or any
future model) receives a structured `ContextSnapshot` derived from the database — it
never gets a database connection, raw SQL, or unfiltered records. This protects
user privacy and keeps the AI's behavior auditable.

### Rule 3 — Every user action emits an event
Tap a habit checkbox? Event. Start a routine? Event. Open the app? Event. Type a
chat message? Event. There are no "untracked" actions in Optivus. The events log is
the audit trail, the analytics source, and the AI's input — it cannot have gaps.

### Rule 4 — The system functions without AI
Every coach rule has a `fallback_message`. If Claude is down, rate-limited, or over
budget, the user still gets a coherent response. The product degrades gracefully to
rule-driven messages. The AI is enhancement, not dependency.

### Rule 5 — Android system data is first-class input
On Android, app usage, screen unlocks, and notification interactions are available
via system APIs. Optivus uses them. They emit events the same way user-logged
actions do. iOS users get a degraded experience for these signals (manual logging
only). This is a deliberate platform decision, not an accident.

### How the System Contract is enforced
- Every PR description must list which Contract rules apply to the change.
- A Contract violation is automatic blocker in code review, regardless of who wrote it.
- These rules can be amended only via a written architectural decision record (ADR),
  not by individual feature requests.
```

---

## Patch 2 of 4 — Insert "Data Ownership" section

**Location:** Immediately after the System Contract section.

**Action:** INSERT new section.

```markdown
## Data Ownership

The user owns all data Optivus stores about them. This is contract, not promise.

### Full delete
- User can request account deletion from Profile → Settings → Delete Account.
- Reauthorization required (per existing audit-confirmed flow).
- Within 30 days, all user data is hard-deleted across:
  - Postgres (cascade on `users.id`)
  - Firestore (legacy collections during migration)
  - Redis (all keys with `{user_id}` pattern)
  - S3 archive (Parquet files containing the user's events)
  - `coach_speak_log` and `ai_rule_logs` (anonymized — `user_id` set to NULL, not deleted, so aggregate behavior research survives)
- Deletion produces a confirmation email and a final export bundle (see below).

### Full export
- User can request a data export from Profile → Settings → Export My Data.
- Bundle includes:
  - `user.json` — profile, identity tags, settings
  - `events.csv` — every logged event in chronological order
  - `habits.csv`, `routines.csv`, `goals.csv`, `tasks.csv`, `journal.json`
  - `coach_messages.json` — every coach message + every user reply
  - `coach_memory.json` — every long-term memory summary the AI sees about you
- Bundle is delivered as a single .zip via signed S3 URL, valid for 7 days.
- Export is rate-limited to once per 24 hours.

### No hidden AI memory
The AI never stores memory about the user outside the database tables the user can read.
Specifically:
- No vector embeddings in v1.
- No off-database "model fine-tuning" on user data.
- No conversation memory in LLM provider's caches that the user can't access.
- Long-term memory is summarized rows in `ai_context_snapshots`, user-readable in
  Profile → Coach Memory, user-deletable with one tap.

### What deletion does NOT remove
- Crash logs (Firebase Crashlytics, anonymized after 30 days)
- Aggregated cohort analytics (your behavior contributes to "average completion rate"
  metrics, but not as identifiable data)
- Signed payment records (if any; required by tax law)

These exclusions are listed verbatim in the deletion confirmation email so the user
knows what survives.
```

---

## Patch 3 of 4 — Replace "Success Metrics" section

**Location:** Existing Success Metrics section (likely near the end of v1 PRD).

**Action:** REPLACE entire section.

```markdown
## Success Metrics

The metrics that drive product decisions. Adherence metrics are kept but de-emphasized;
behavior-quality metrics are the primary lens.

### Primary metrics (drive product decisions)

**AI suggestion acceptance rate** — Of the suggested-action buttons under coach
messages, what % do users tap? Target: 30%+ at v1, 45%+ at v1.5. Below 20% means
the suggestions are wrong, not that users don't engage.

**Notification fatigue rate** — Of all notifications sent, what % are dismissed
without engagement (no tap, no in-app action within 1h)? Target: under 25%. Above
40% means we're nagging.

**Behavior change consistency** — 30-day rolling variance in routine completion %.
Low variance with high mean = real behavior change. High variance = streaks-and-crashes
pattern (the thing Optivus is supposed to prevent). Target: variance under 0.15 with
mean above 0.6 for users at week 4+.

### Secondary metrics (kept from v1, monitored)

- DAU / MAU
- D1, D7, D30 retention
- Average current streak length per active habit
- Time-to-first-coach-interaction after onboarding

### Anti-metrics (we deliberately don't optimize for these)

- Total messages sent (could be increased trivially by removing cooldowns)
- Total events logged (could be inflated by re-logging)
- Time spent in app (Optivus is supposed to *reduce* phone time — long sessions are
  often a failure signal, not a win)
- Streak length alone (a 200-day streak with 50% completion variance is worse than
  a 30-day streak with 5% variance)

### Crisis & safety metrics (separate dashboard, low-noise)
- Number of users who hit crisis Tier 1, 2, or 3 in the last 30 days
- Time from crisis trigger to coach response (target: under 15s)
- Number of Tier 3 manual-handoff alerts issued
- Number of users who report (via in-app feedback) that the coach said something
  hurtful (target: zero — investigate every report)

These are not vanity metrics. The crisis dashboard is monitored daily by the founder
in the early days, and any non-zero hurtful-message count blocks the next release.
```

---

## Patch 4 of 4 — Update Onboarding section with resilience rules

**Location:** Existing onboarding flow description.

**Action:** APPEND a "Resilience and Resume" subsection at the end of the onboarding section.

```markdown
### Resilience and Resume

The 11-step onboarding earns its depth (every step feeds the engine — biometrics
into safety guards, identity tags into ring weights, accountability mode into the
coach archetype matrix). Removing steps weakens personalization. Instead, onboarding
is built to survive friction.

**Auto-save on every step.** Onboarding state writes to Firestore on every input
change, debounced to 2 seconds. Confirmed working in v1 codebase per audit.

**Resume from any step ≥ 2.** Closing the app, network drop, or backgrounded
session does not lose progress. Reopening the app drops the user back at the last
step they reached, with their inputs preserved.

**Skip with documented defaults.** From Step 4 onward, every step has a
"Skip — use defaults" button. The button label includes the default value visibly
("Skip — uses Forgiving mode", "Skip — empty identity tags"). Silent defaults are
banned; the user must always know what they're choosing not to set.

**Default values per step (canonical):**
- Step 4 (Accountability mode): `forgiving`
- Step 5 (Coach name): `Coach`
- Step 6 (Coach style): `supportive`
- Step 7 (Identity tags): `[]` (empty array — user can add later in Profile)
- Step 8 (Biometrics): all fields nullable; calorie tracking auto-disabled if skipped
- Step 9 (AI plan review): generic starter plan with 3 example tasks
- Step 10 (Notifications): default tier 3 ("Standard"), enabled
- Step 11 (Final confirm): cannot be skipped — explicit "I'm ready" tap required

**Re-enter from settings.** Onboarding is not a one-time event. Profile → Settings
→ Re-run Onboarding takes the user back through steps 4-11, pre-populated with
their current values. Step 1-3 (auth, account creation) are not re-runnable.

**Why this approach:** the depth is the product. The risk was UX friction, not
depth. Saving progress and allowing skips with documented defaults addresses
friction without losing personalization data for users who do complete it. Users
who skip everything get a usable but minimal profile that the engine treats as
"new user" (Forgiving mode, no identity tags, generic priorities).
```

---

## End of PRD v2 patch

Four insertions/replacements total. After applying, the PRD has:
- A System Contract section (new)
- A Data Ownership section (new)
- Upgraded Success Metrics (replaced)
- Onboarding Resilience subsection (appended)

No other v1 PRD content is removed. The PRD's persona, feature descriptions, and
product narrative are untouched.
