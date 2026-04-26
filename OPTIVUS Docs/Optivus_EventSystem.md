# Optivus — Event-Driven System Spec

**Document version:** 1.0
**Last updated:** April 2026
**Companion to:** *Optivus PRD v1.0*, *Optivus User Flow v1.0*

This document is the backend logic layer. It translates the UX flows and feature specs into an event-driven architecture: every meaningful state change emits an event, every service subscribes to the events it cares about, and every feature is broken down into the trigger that starts it, the data it reads, and what happens on success vs failure.

It is not code. It is the rules engineers (and the AI) follow before code gets written.

---

## Table of contents

1. [Architecture in one paragraph](#1-architecture-in-one-paragraph)
2. [Event taxonomy & naming rules](#2-event-taxonomy--naming-rules)
3. [Master event catalog](#3-master-event-catalog)
4. [Service map — who listens to what](#4-service-map--who-listens-to-what)
5. [Feature logic — Task Engine](#5-feature-logic--task-engine)
6. [Feature logic — Habit tracking (good)](#6-feature-logic--habit-tracking-good)
7. [Feature logic — Habit tracking (bad)](#7-feature-logic--habit-tracking-bad)
8. [Feature logic — Streak system](#8-feature-logic--streak-system)
9. [Feature logic — Routine completion %](#9-feature-logic--routine-completion-)
10. [Feature logic — Mission ring](#10-feature-logic--mission-ring)
11. [Feature logic — Identity score](#11-feature-logic--identity-score)
12. [Feature logic — AI Coach decision engine](#12-feature-logic--ai-coach-decision-engine)
13. [Feature logic — Notification scheduler](#13-feature-logic--notification-scheduler)
14. [Feature logic — Money saved](#14-feature-logic--money-saved)
15. [Feature logic — Failure & re-engagement](#15-feature-logic--failure--re-engagement)
16. [Edge cases & failure handling rules](#16-edge-cases--failure-handling-rules)

---

## 1. Architecture in one paragraph

The app is a **publish-subscribe event log**. The UI publishes events when the user does something. Background services publish events when they detect something. Every feature (streaks, mission ring, AI coach, notifications, money saved) is a **listener** that subscribes to a specific subset of events, applies its own pure logic, and publishes new events of its own. This decouples UI from logic, makes every state change auditable, gives the AI a perfectly clean stream to learn from, and means a feature can be added or replaced without touching unrelated code.

The event log is **append-only**. Nothing is ever mutated or deleted. Corrections are new events, not edits. State you see on screen is always derived from the event log by replaying events through reducers — never stored as the source of truth.

---

## 2. Event taxonomy & naming rules

### Naming convention

```
{domain}_{state_or_action}
```

- **Past tense** for things that already happened (`task_completed`, `slip_logged`)
- **Present tense** for active states the system is observing (`day_started`, `task_active`)
- **Lowercase, snake_case**, no abbreviations (`habit` not `hbt`, `notification` not `notif`)
- Names are **stable forever**. Payloads can grow but never break backwards compatibility — version the payload (`payload_v: 2`) instead of renaming the event.

### Event envelope (every event has these fields)

```
{
  event_id:    UUID                    // unique per event
  event_name:  string                  // e.g. "task_completed"
  user_id:     string                  // owner
  ts:          ISO-8601 timestamp      // when it happened
  device_id:   string                  // which device emitted it
  source:      "ui" | "system" | "ai"  // who emitted it
  payload_v:   integer                 // schema version
  payload:     object                  // event-specific data
}
```

### Domains

| Domain | Owns | Examples |
|---|---|---|
| `user` | account lifecycle | `user_signed_up`, `account_deleted` |
| `onboarding` | first-run flow | `onboarding_completed` |
| `task` | scheduled blocks & subtasks | `task_started`, `task_completed`, `task_abandoned` |
| `habit` | recurring trackable behaviors | `good_habit_logged`, `bad_habit_slip_logged` |
| `streak` | streak state changes | `streak_extended`, `streak_broken`, `streak_paused` |
| `routine` | per-day routine completion | `routine_block_completed`, `routine_day_summarized` |
| `coach` | conversation & suggestions | `coach_message_sent`, `suggestion_accepted` |
| `notification` | push/in-app delivery | `notification_sent`, `notification_tapped` |
| `identity` | long-term goal scoring | `identity_progress_changed` |
| `day` | day-level lifecycle | `day_started`, `day_closed` |
| `engagement` | absence / comeback | `ghost_day_detected`, `comeback_initiated` |
| `biometrics` | body data updates | `biometrics_updated` |

---

## 3. Master event catalog

| Event | Trigger | Source | Payload | Listeners |
|---|---|---|---|---|
| `user_signed_up` | Firebase Auth creates user | UI | `{email, signup_ts, signup_source}` | Onboarding router, Analytics |
| `onboarding_completed` | User taps *Enter Optivus* on Page 10 | UI | `{identity_profile, biometrics, schedule, coach_config, accountability}` | Plan generator, Coach (system prompt seeding), Notification scheduler, Streak service |
| `biometrics_updated` | User edits About You | UI | `{old, new, fields_changed[]}` | Calorie/water target recompute, Identity score, AI memory |
| `task_scheduled` | Plan generator creates a block | System | `{task_id, type, planned_start, planned_end, parent_routine, alarm_tier, identity_tags[]}` | Notification scheduler |
| `task_started` | User taps *I'm starting this* | UI | `{task_id, planned_start, actual_start, drift_min, started_via}` | Notification scheduler (cancel pre-reminder, arm hanging-task timer), Mission ring, Active task pinner, Coach silence rule |
| `task_paused` | User taps *Pause* | UI | `{task_id, paused_at, elapsed_so_far_min}` | Notification scheduler (arm 20-min auto-abandon), Mission ring |
| `task_resumed` | User taps *Resume* | UI | `{task_id, resumed_at, total_pause_duration}` | Notification scheduler (cancel auto-abandon), Mission ring |
| `subtask_checked` | User taps subtask checkbox | UI | `{task_id, subtask_id, checked_at}` | Task engine (auto-complete trigger), Mission ring |
| `task_completed` | User taps *Mark complete* OR last subtask checked | UI | `{task_id, planned_duration, actual_duration, drift_pct, subtasks_completed, subtasks_total}` | Streak service, Mission ring, Identity score, AI memory, Notification scheduler |
| `task_abandoned` | (a) Auto: planned end + 20 min idle while paused, (b) Auto: scheduled time + 90 min with no start, (c) Manual: user taps *Skip* | System or UI | `{task_id, abandoned_at, reason: "auto_idle"\|"auto_no_start"\|"user_skipped", reason_tag?, started_at?}` | Streak service, Mission ring, Coach (queue check-in), AI memory |
| `good_habit_logged` | User logs in Tracker / Home pill / Coach NL command | UI or AI | `{habit_id, amount, unit, ts, source: "manual"\|"notification"\|"coach"\|"auto"}` | Streak service, Mission ring, Identity score, Money saved (if quit-replacement), AI memory |
| `bad_habit_slip_logged` | User logs slip in Tracker | UI | `{habit_id, trigger_tag?, ts, count_today_after, photo_attached?}` | Streak service (break or count up), Coach (queue response), Identity score, AI memory |
| `slip_streak_detected` | Streak service detects 3+ slips in 30 min | System | `{habit_id, count, window_min, first_slip_ts, last_slip_ts}` | Coach (replaces individual responses with single coalesced one) |
| `streak_extended` | Streak service computes a +1 at day-close | System | `{habit_id, old_count, new_count}` | Coach (P6 celebration if milestone), Mission ring badge |
| `streak_milestone_reached` | Streak service detects a milestone (3, 7, 14, 30, 60, 90, 180, 365) | System | `{habit_id, milestone, streak_count}` | Coach (celebration), Notification scheduler (P6) |
| `streak_broken` | Streak service computes a break at day-close | System | `{habit_id, old_count, reset_to: 0, reason: "missed_target"\|"slip"\|"abandoned"}` | Coach (compose gentle message), Identity score |
| `streak_paused` | User goes ghost (3+ days no app open) | System | `{habit_id, paused_at, pre_pause_count}` | UI (display "paused" chip), Coach silence |
| `streak_resumed` | User returns within ghost grace window | System | `{habit_id, resumed_at, restored_count}` | UI, Coach |
| `routine_block_completed` | A `task_completed` whose parent is a recurring routine | System (derived) | `{routine_type, block_id, weekday, completion_pct_today}` | Routine completion %, Mission ring |
| `routine_day_summarized` | At `day_closed` | System | `{date, per_routine_pct: {skin_care, eating, classes, fixed, custom}, overall_pct}` | Identity score, Coach (EoD message), Tracker UI |
| `coach_message_sent` | User sends in Coach tab | UI | `{turn_id, text, mode}` | Gemini service |
| `coach_replied` | Gemini returns | System | `{turn_id, text, suggested_actions?, latency_ms}` | Coach UI |
| `suggestion_generated` | AI planner produces a suggestion | AI | `{suggestion_id, type, target_date, rationale, priority_score, source_pattern}` | Routine AI panel, Notification scheduler |
| `suggestion_accepted` | User taps *Accept* | UI | `{suggestion_id, type, target_date}` | Plan generator (mutate plan), AI memory (reinforce) |
| `suggestion_dismissed` | User taps *Dismiss* | UI | `{suggestion_id, type, reason?}` | AI memory (decay similar suggestions for 7d) |
| `notification_scheduled` | Scheduler queues a push | System | `{notif_id, fire_at, category, priority, deep_link}` | (internal) |
| `notification_sent` | Scheduler delivers | System | `{notif_id, category, priority, ts, delivered}` | Frequency cap counter, Analytics |
| `notification_tapped` | OS callback | OS | `{notif_id, tapped_at, deep_link}` | Deep link router, AI memory (this nudge worked) |
| `notification_dismissed` | OS callback | OS | `{notif_id, dismissed_via}` | AI memory (this nudge didn't land) |
| `notification_suppressed` | Scheduler decides not to fire | System | `{would_have_been_id, reason: "budget_full"\|"dnd"\|"cooldown"\|"dedup"\|"silence_window"}` | AI memory |
| `identity_progress_changed` | Identity scorer recomputes after a contributing event | System | `{identity_id, old_pct, new_pct, delta, contributors_changed[]}` | Goals tab, Profile tab, Coach (queue insight if delta significant) |
| `milestone_completed` | Identity scorer or user marks a milestone done | System or UI | `{identity_id, milestone_id, completed_at, auto_or_manual}` | Coach (P6 celebration) |
| `day_started` | First `task_started` of the day OR 6 AM fallback if user is offline | System | `{date, weekday_template_id, planned_blocks_count}` | Daily AI planner, Notification scheduler |
| `day_closed` | (a) `task_started` on sleep block, (b) midnight cutoff if no sleep block, (c) 4 AM hard cutoff | System | `{date, completion_pct, slips, abandoned_count, completed_count, focus_minutes, money_saved_today}` | Streak service, EoD summary generator, Identity score, AI memory |
| `ghost_day_detected` | Background job: app not opened 24h+ | System | `{user_id, last_seen_ts, missed_days}` | Re-engagement service |
| `comeback_initiated` | User opens app after 3+ day gap | System | `{user_id, gap_days, last_seen_ts}` | Comeback flow, Coach (force Supportive 48h), Streak service (resume) |
| `account_deleted` | User confirms delete | UI | `{user_id, deleted_at, scheduled_purge_at}` | Auth, Cleanup job |

---

## 4. Service map — who listens to what

A service is a self-contained logic module. It subscribes to events, runs pure logic, and publishes new events. None of these services share state directly; they communicate only through the event log.

| Service | Subscribes to | Publishes |
|---|---|---|
| **Plan Generator** | `onboarding_completed`, `suggestion_accepted`, `biometrics_updated` | `task_scheduled` |
| **Task Engine** | `task_scheduled`, `task_started`, `task_paused`, `task_resumed`, `subtask_checked`, `task_completed`, `task_abandoned` | `task_completed` (auto when subtasks all checked), `task_abandoned` (auto on timeout) |
| **Streak Service** | `task_completed`, `task_abandoned`, `good_habit_logged`, `bad_habit_slip_logged`, `day_closed`, `comeback_initiated` | `streak_extended`, `streak_broken`, `streak_milestone_reached`, `streak_paused`, `streak_resumed`, `slip_streak_detected` |
| **Routine Completion Calculator** | `task_completed`, `task_abandoned`, `task_skipped`, `day_closed` | `routine_block_completed`, `routine_day_summarized` |
| **Mission Ring** | `task_completed`, `task_abandoned`, `subtask_checked`, `good_habit_logged`, `task_started`, `task_paused` | (none — pure UI projection) |
| **Identity Scorer** | `task_completed`, `task_abandoned`, `good_habit_logged`, `bad_habit_slip_logged`, `routine_day_summarized`, `biometrics_updated` | `identity_progress_changed`, `milestone_completed` |
| **AI Decision Engine** | `day_started`, `task_completed`, `task_abandoned`, `bad_habit_slip_logged`, `slip_streak_detected`, `routine_day_summarized`, `notification_dismissed`, `suggestion_dismissed` | `suggestion_generated`, queues coach messages |
| **Notification Scheduler** | `task_scheduled`, `task_started`, `task_completed`, `suggestion_generated`, `bad_habit_slip_logged`, plus all `streak_*` and `milestone_*` | `notification_scheduled`, `notification_sent`, `notification_suppressed` |
| **Money Saved Calculator** | `bad_habit_slip_logged`, `good_habit_logged` (when habit is a quit-replacement), `day_closed` | (none — pure derived state) |
| **Re-engagement Service** | Background timer + `notification_tapped` (any), `task_started` (any) | `ghost_day_detected`, `comeback_initiated`, `streak_paused`, `streak_resumed` |
| **Phone Behavior Importer** | Background timer (every 30 min foreground + once at `day_closed`) | `good_habit_logged` for screen time, raw data into event log |

---

## 5. Feature logic — Task Engine

The state machine that governs every scheduled block on the timeline.

### State machine

```
Scheduled  ──► Started  ──► Completed
    │            │
    │            ├──► Paused ──► Resumed ──► (back to Started)
    │            │       │
    │            │       └──► (20 min idle) ──► Abandoned (auto)
    │            │
    │            └──► Abandoned (user skips after starting)
    │
    └──► (planned_start + 90 min, no start) ──► Abandoned (auto)
```

### 5.1 Trigger: `task_started`

**What triggers it:** User taps **I'm starting this** on a block in Routine tab or Home.

**Data it uses:**
- The task record from `task_scheduled` payload (planned start, planned end, parent routine, identity tags)
- Current timestamp
- Subtask list if the task has children

**Pre-conditions checked before firing:**
- Task is in `Scheduled` state (cannot start an already-started or completed task)
- No other task is currently in `Started` state (only one active task at a time — see edge case 16.1 for handling)

**Logic on success:**
1. Compute `drift_min = actual_start − planned_start`
2. Mark task state = `Started`
3. Pin the task to the top of the screen with a live elapsed-time chip
4. Cancel any pending pre-reminder for this task
5. If task has subtasks, render them as tappable checkboxes
6. Begin a silence window for proactive coach nudges (Section 12.5)
7. Emit `task_started` event

**Logic on failure:**
- If pre-condition fails → show toast *"You already have an active task — finish or pause it first"*; offer one-tap deep link to the active task; emit nothing
- If user has no network: event is queued in local store, app continues optimistically; sync on reconnect

### 5.2 Trigger: `task_completed`

**What triggers it:** Either path:
- (a) User taps **Mark as complete**
- (b) Last subtask is checked (auto-complete)

**Data it uses:**
- `task_started` payload (actual_start)
- Current timestamp (actual_end)
- Subtask checkbox state

**Logic:**
1. Compute `actual_duration = actual_end − actual_start`
2. Compute `drift_pct = (actual_duration − planned_duration) / planned_duration`
3. Compute `subtasks_completed = count(checked) / count(total)`
4. Save these to the task record (append-only — original `task_scheduled` is not mutated)
5. Unpin from active-task bar
6. Animate Mission ring update
7. Open silence window: 30 min no proactive nudges (don't break the flow of a winner)
8. Emit `task_completed`
9. **If parent routine** (skin care, eating, etc.) → derived event `routine_block_completed` is also emitted

**Listeners then react:**
- Streak service → may emit `streak_extended` if this task is part of a streak chain
- Identity scorer → recomputes affected identity %s
- AI memory → captures the actual duration for future planning (this is how the AI learns the user's gym block actually takes 82 min, not 60)

### 5.3 Trigger: `task_abandoned`

Three paths into Abandoned:

**Path A — Auto (no start):** task scheduled, time passed, planned_start + 90 min elapsed with no `task_started` event.
- System emits `task_abandoned` with `reason: "auto_no_start"`

**Path B — Auto (idle while paused):** task is in Paused state, no resume for 20 min.
- System emits `task_abandoned` with `reason: "auto_idle"`, started_at preserved

**Path C — User skipped:** user taps Skip with optional reason chip.
- Emits `task_abandoned` with `reason: "user_skipped"`, `reason_tag` if picked

**Logic:**
1. Mark task state = `Abandoned`
2. Capture how far the user got (subtasks_completed, elapsed minutes if started)
3. Open a Coach queue check-in with priority based on context (a sleep block abandoned at 11:47 PM matters more than a "go for a walk" task)
4. Emit `task_abandoned`

**Critical rule:** Abandonment is **not** the same as failure. The framing in the AI's response and in any UI surface is *"What got in the way?"* not *"You failed."* See Section 16.4.

### 5.4 Subtask completion logic

**When user taps a subtask checkbox:**
- Emit `subtask_checked`
- Recompute `parent.subtasks_completed_pct = checked_count / total_count`
- If `subtasks_completed_pct == 1.0` → auto-fire `task_completed` (path b)

**When user un-checks a subtask** (rare but allowed):
- Emit `subtask_unchecked`
- Recompute pct
- If parent was `Completed`, do **not** revert to Started — the task stays Completed but the subtask record updates. (Reverting would create a state-machine ambiguity.)

### 5.5 Plan-vs-actual capture (the data the AI lives on)

Every completed or abandoned task writes back to a `task_outcome` record:
- `planned_start`, `actual_start`, `start_drift_min`
- `planned_duration`, `actual_duration`, `duration_drift_pct`
- `planned_subtask_count`, `actual_subtask_count`
- `outcome: completed | abandoned`
- `weekday`, `time_of_day_bucket` (morning / midday / afternoon / evening / night)

**After 14 days of data**, the AI starts using rolling averages of these fields to refine the `planned_*` values for future scheduling. This is the loop that makes Optivus "learn the user."

---

## 6. Feature logic — Habit tracking (good)

A good habit is a recurring measurable behavior with a daily target the user wants to hit (water, meditation, reading, gym).

### 6.1 Trigger: `good_habit_logged`

**What triggers it:**
- User taps a quick-log button (+250 ml, +500 ml, +1 L, custom)
- User taps a habit pill on Home with a preset amount
- User asks the coach in natural language: *"I just drank 500ml"*
- Auto-import from Google Fit / Apple Health for exercise & sleep
- Notification tap → deep-link to logger

**Data it uses:**
- Habit config: `{habit_id, name, unit, daily_goal, baseline?, identity_tags[]}`
- Log payload: `{amount, unit, ts, source}`
- Today's running total for this habit

**Logic on log:**
1. Validate amount > 0 and unit matches habit config
2. Compute `today_total = previous_today_total + amount`
3. Compute `pct_of_goal = today_total / daily_goal` (cap visually at 100%, but record overage for stats)
4. Append the log entry to `habit_logs/{habit_id}/{date}/{log_id}`
5. Emit `good_habit_logged`
6. UI animates the relevant card (ring fill, counter tick, haptic)
7. If `pct_of_goal` crosses 100% **for the first time today** → flag `goal_hit_today = true` on the habit's daily record (this is what the streak service uses)

**Logic on undo (swipe-left on log entry):**
- Emit `good_habit_log_deleted` with the log_id
- Recompute today_total (just subtract the deleted amount; event log preserves the original)
- If undo brings the total below daily_goal AND the current day is still active, `goal_hit_today` reverts to false; streak does not break until day-close

### 6.2 Determining "did the user hit their goal today?"

This decision is made **at `day_closed`**, not the moment of logging. Reason: logs can be added or undone any time before day-close. The streak service should only act on the final day-end state.

```
hit_today(habit) = sum(today's log amounts) >= daily_goal
```

The streak service reads `hit_today` for every active habit at day close and emits `streak_extended` or `streak_broken` accordingly.

### 6.3 Special log types

| Habit type | Log shape | Special rule |
|---|---|---|
| Water | `{amount_ml}` | Auto-target = `weight_kg × 35 ml`; heat-day boost adds 500ml (Section 8.4.5 of User Flow) |
| Meditation | `{duration_seconds, type}` | Any duration counts toward streak — even 90 seconds |
| Reading | `{minutes \| pages \| book_finished}` | Mode chosen at habit creation; only the chosen mode counts toward goal |
| Exercise | `{type, duration_min, intensity, distance?}` | Auto-PR detection compares to all previous logs of same type |
| Money saved (active mode) | `{amount, reason_text}` | Manual deposit; aggregated with passive savings |

### 6.4 Failure mode: the user doesn't log

The biggest threat to a good-habit tracker is the user did the thing but forgot to log it. Mitigations:
- **End-of-day reminder** at 30 min before sleep block: *"Log anything you did today?"* — opens Tracker home directly
- **Phone import auto-fills** sleep, steps, exercise (with confirm) so manual logging isn't required for those
- **Coach NL fallback**: user can type *"I drank 2 liters today"* in chat any time and the coach back-fills the log
- **Forgive-once-per-week** on Forgiving accountability — if user has logged consistently for 6 days and skips logging on the 7th without a target hit, streak holds with a *"used your weekly skip"* note

---

## 7. Feature logic — Habit tracking (bad)

A bad habit is a behavior the user wants to *reduce* or *eliminate*. The same engine handles smoking, doom-scrolling, junk food, and procrastination, with type-specific configs.

### 7.1 Trigger: `bad_habit_slip_logged`

**What triggers it:**
- User taps **Log slip** in Tracker
- For screen time: auto-imported from Android `UsageStatsManager` and emitted only if a flagged-app cap is crossed
- For procrastination: auto-detected from event log (`actual_start − planned_start > 30 min` OR `task_abandoned without task_started`)

**Data it uses:**
- Habit config: `{habit_id, name, unit, baseline_per_day, cost_per_unit, identity_tags[]}`
- Slip payload: `{trigger_tag?, ts, photo?, related_task_id?}`

**Logic:**
1. `count_today_after = count_today_before + 1`
2. Append to `slip_logs/{habit_id}/{date}/{slip_id}`
3. Emit `bad_habit_slip_logged`
4. **Frequency check:** if 3+ slips for same habit in last 30 min → emit `slip_streak_detected`, suppress per-slip coach response
5. **Money saved math:** Money calculator subscribes and recomputes (Section 14)
6. UI: increment the count number with a gentle animation, **never** a red banner. Update money-saved card (which may pause for the day if user crossed baseline).

### 7.2 Failure mode: the user doesn't log slips honestly

The hardest design problem in this entire app. Mitigations:
- **Logging is non-shaming.** Trigger picker is *optional*; user can tap Skip to log without explanation; confirmation language is *"Logged. Thank you for being honest."*
- **Friction parity.** Logging a slip takes the same number of taps as logging a positive (≤2 taps). Asymmetry breeds dishonesty.
- **No streak panic on slip.** Streaks roll up at day-close, not at slip moment. So a slip mid-day doesn't immediately kill an 18-day streak — the user has the rest of the day to potentially still hit a "stay under baseline" goal if their habit is configured as reduction not elimination.
- **Auto-detection paths** for screen time and procrastination remove the dependency on user honesty for those specific habits.

### 7.3 Bad-habit goal types

A bad habit can be configured as one of three goal types:

| Goal type | Definition | Streak rule |
|---|---|---|
| **Eliminate** | 0 per day | Streak extends if `count_today == 0`; breaks on any slip |
| **Reduce-to-target** | ≤ N per day (e.g., max 2 cigarettes) | Streak extends if `count_today ≤ target`; breaks if exceeded |
| **Awareness-only** | No target, just track | No streak. Just the data. Used early in habit-change journey. |

Default at creation: **Awareness-only** for the first 7 days, then prompt user to pick a goal type. This avoids breaking streaks before a user knows their baseline.

### 7.4 Auto-detect: procrastination

Two auto-paths:

**Path 1 — Late start:**
- Listener subscribes to `task_started`
- If `drift_min > 30` AND task type is in user's procrastination-tracked list (defaults: study, gym, deep work)
- Emit `bad_habit_slip_logged` with `habit_id = procrastination`, `trigger_tag = "late_start"`, `related_task_id`

**Path 2 — No-show:**
- Listener subscribes to `task_abandoned` with `reason: "auto_no_start"`
- Emit `bad_habit_slip_logged` with `habit_id = procrastination`, `trigger_tag = "no_show"`, `related_task_id`

Both auto-logs are dismissable from the UI (swipe left on the log entry). Dismissals emit `slip_log_dismissed` which the AI uses as a signal that the user disagrees with the auto-detection — over time, thresholds adjust per-user.

### 7.5 Auto-detect: screen time

- Phone Behavior Importer pulls usage data every 30 min while app is foreground + once at day_closed
- For each flagged app with a daily cap, check `today_minutes >= cap_minutes`
- If a cap is crossed for the first time today: emit `bad_habit_slip_logged` with `habit_id = screen_time_{app}`, no trigger tag
- Subsequent crossings same day do **not** re-emit (one slip per app per day max)

---

## 8. Feature logic — Streak system

A streak is a count of consecutive days a user hit their goal for a specific habit. Streaks are computed at day-close, not in real time.

### 8.1 Streak record shape

```
streak/{habit_id} = {
  current_count:   int       // current run
  longest_count:   int       // user's all-time best
  last_hit_date:   date      // most recent day the goal was met
  last_break_date: date?     // when current streak last reset
  state:           "active" | "paused" | "broken" | "fresh"
  paused_at:       ts?       // if state == "paused"
  pre_pause_count: int?      // count when pause started
}
```

### 8.2 Trigger: `day_closed` — streak rollup

**For every active habit:**

1. Read `hit_today(habit)` (Section 6.2 for good habits; "no slip" or "stayed under target" for bad habits)
2. Apply rules:

**If `hit_today == true`:**
- `current_count += 1`
- `last_hit_date = today`
- If `current_count > longest_count` → update longest
- Check milestone list `[3, 7, 14, 30, 60, 90, 180, 365]`:
  - If new count matches a milestone → emit `streak_milestone_reached`
- Emit `streak_extended`

**If `hit_today == false`:**
- Apply accountability rule (Section 8.3) — may grant grace
- If grace not granted:
  - `current_count = 0`
  - `last_break_date = today`
  - `state = "broken"`
  - Emit `streak_broken`

### 8.3 Accountability rules

User picks one during onboarding (changeable in Profile → Accountability).

| Mode | Grace logic | Reset language tone |
|---|---|---|
| **Forgiving** | 1 free skip per habit per rolling 7-day window. If `current_count >= 6 && skips_in_last_7_days == 0`, the miss is consumed by the grace token and streak holds. UI shows: *"Used your weekly skip on hydration."* | Gentle |
| **Strict** | No grace. Miss = reset. | Gentle |
| **Ruthless** | No grace. Miss = reset. | Sharp but never insulting |

The accountability mode can be set **per-habit** as well as globally. Use case: Forgiving on cigarettes (long-term recovery is non-linear), Strict on gym (showing up is binary).

### 8.4 Trigger: `streak_paused`

**What triggers it:** Re-engagement service detects the user has been ghost (no app open) for 3+ consecutive days.

**Logic:**
- For every active habit, store `pre_pause_count = current_count`, set state = `paused`, capture `paused_at`
- Streaks **do not reset** during pause; the comeback flow can restore them
- Emit `streak_paused` per habit

### 8.5 Trigger: `streak_resumed`

**What triggers it:** `comeback_initiated` fires (user opens app after gap of 3–7 days).

**Logic:**
- For each paused habit:
  - If gap was 3–7 days → restore `current_count = pre_pause_count`, state = `active`
  - If gap was 8+ days → reset `current_count = 0`, state = `broken`, emit `streak_broken`
- Emit `streak_resumed` for restored streaks

This is the most important user-retention rule in the app: **absence ≠ slip.**

### 8.6 Trigger: `slip_streak_detected`

Edge case: user logs 3+ slips of the same habit within 30 min.

**What it does:**
- Suppresses the per-slip coach response that would normally fire after each slip
- Instead, emits one coalesced `slip_streak_detected` event
- Coach receives this and composes a single message addressing the cluster: *"Three slips in 30 min. Something happening — want to talk?"*
- Notification scheduler treats this as a single P4, not three

---

## 9. Feature logic — Routine completion %

A routine is a recurring set of blocks tied to a specific theme (skin care, eating, classes, fixed schedule, custom). Each routine has its own daily completion % and a weekly rollup.

### 9.1 Per-block completion contribution

Every block in a routine contributes to that routine's daily % based on its outcome state:

| Block outcome | Contribution to today's % |
|---|---|
| Completed | 1.0 |
| In Progress (Started, not yet completed at time of read) | proportional: `min(elapsed / planned_duration, 0.95)` (cap at 0.95 so it doesn't jump to 100% by drift alone) |
| Paused | same as In Progress at time of pause |
| Abandoned (auto or manual) | 0.0 |
| Skipped with valid reason (illness, scheduled day off) | excluded from denominator (treated as N/A, not a fail) |
| Upcoming (not yet at planned start) | excluded from denominator (until day-close) |

### 9.2 Daily routine % formula

```
routine_pct(routine_type, date) = sum(contributions) / count(non-excluded blocks)
```

Computed live as events arrive; final value locked at `day_closed`.

### 9.3 Trigger: `routine_block_completed`

Listener detects when a `task_completed` belongs to a routine (parent_routine field is set).

**Logic:**
1. Recompute that routine's today % using formula 9.2
2. Update the relevant Tracker UI card and Routine tab badge
3. Emit `routine_block_completed`

### 9.4 Trigger: `routine_day_summarized`

Fires once per day at `day_closed`.

**Logic:**
1. Lock final % values for each routine type
2. Compute overall day completion: weighted average across routines (weights configurable; default = equal)
3. Write to `routine_summaries/{user_id}/{date}`
4. Emit `routine_day_summarized` with the full per-routine breakdown
5. This event feeds: Identity scorer, AI EoD message generator, Tracker UI weekly view

### 9.5 The drift heatmap (most-used analysis surface)

For every block ever scheduled, store `(weekday, hour_bucket, outcome)`. The drift heatmap is a derived view:

```
drift_heatmap[weekday][hour] = count(abandoned) / count(scheduled)
```

The AI reads this when generating tomorrow's plan (Section 12.1) — chronic afternoon drift triggers a *"lighten the afternoon"* suggestion.

---

## 10. Feature logic — Mission ring

The big circle on Home that shows "Today's Mission %." It's a real-time projection of the day's progress.

### 10.1 Formula

```
mission_pct(today) = (
  identity_aligned_completed_value
  + non_aligned_completed_value × 0.5
) / max_possible_value_today
```

Where:
- A task is *identity-aligned* if its `identity_tags[]` overlaps with the user's chosen identities
- Identity-aligned completions count at full weight; non-aligned at half weight (so a user who completes 7 random tasks but skipped the 3 that mattered most for *their* identities sees Mission < 70%)
- `max_possible_value_today` is the total weighted value of all tasks scheduled for today

This is the rule that makes Mission ring more than a checkbox count — it's the system telling the user whether today actually moved them toward who they said they wanted to become.

### 10.2 When it updates

| Event | Mission ring action |
|---|---|
| `task_started` | No change to %, but ring shows a small pulse |
| `subtask_checked` | Recompute (proportional credit) |
| `task_completed` | Recompute, animate fill |
| `task_abandoned` | Recompute (denominator unchanged, that task contributes 0) |
| `good_habit_logged` (if habit tied to today's plan) | Recompute |

### 10.3 Failure mode: the ring shows 100% but the user feels like they did nothing

This happens when a user's identity tags don't actually map to their planned tasks (e.g., they picked "Top Student" but none of today's tasks are tagged with that identity). The AI detects this at day_closed:
- If `mission_pct == 100%` but `identity_aligned_completed_value == 0` → AI insight surfaces tomorrow: *"Yesterday was 100% complete, but none of it was Top Student work. Want me to schedule study time tomorrow?"*

---

## 11. Feature logic — Identity score

Each long-term identity ("Strong Body", "Top Student") has a 0–100 score that represents the user's progress toward that identity.

### 11.1 Score formula

```
identity_score(identity) = sum_over_contributors(
  contributor_completion_rate_28d × contributor_weight
) / sum_of_weights × 100
```

Where:
- A *contributor* is a habit or routine declared as feeding this identity
- `contributor_completion_rate_28d` = `days_hit / 28` (good habits) or `1 − (slips / baseline_slips × 28)` (bad habits)
- `contributor_weight` is High (1.0), Medium (0.6), Low (0.3); user can override

### 11.2 Trigger: `identity_progress_changed`

Fires whenever any contributor's completion rate changes meaningfully (delta > 0.5%).

**Logic:**
1. Recompute score
2. If `|new_score − old_score| >= 0.5` → emit event with delta and changed contributors
3. UI: identity card animates, trend chip updates
4. AI: queues an insight only if delta is significant (>= 2% change in either direction)

### 11.3 The "Why this score?" transparency layer

Whenever the user opens the identity detail screen, the explanation card recomputes:
- Lists every contributor with its current rate, weight, and contribution to the score
- Explains in plain language which contributor pulled the score up or down most this week
- Suggests the highest-leverage move (the contributor with the biggest weight × biggest gap to 100%)

This is implemented as a **pure function** of the identity's current state — no events emitted, just a read.

---

## 12. Feature logic — AI Coach decision engine

The AI is reactive (responds to messages, slips) and strategic (plans the day's interventions). This section defines the strategic loop because reactivity is straightforward (in → out via Gemini).

### 12.1 Trigger: `day_started`

Fires once per day. The strategic planner runs synchronously before any notifications are scheduled.

**Inputs:**
- Today's `task_scheduled` set
- Yesterday's `day_closed` payload
- Last 7 days of slips, abandonments, completions (from event log)
- Drift heatmap (Section 9.5)
- Active streaks
- Identity scores
- Today's notification budget (default 8)

**Logic:**

1. **Generate intervention candidates.** For each potential coach moment today, score it:

| Candidate type | Score |
|---|---|
| Carry-over from yesterday's failure pattern | 9 |
| Pre-emptive at known trigger time (from heatmap) | 8 |
| Identity-aligned push for the day's most-touched identity | 7 |
| Goal nudge (close to milestone) | 5 |
| Streak/celebration | 3 |

2. **Allocate speak budget.** Take top-N candidates where N = proactive budget for the day (default 5). Schedule each at the timestamp that makes most sense (e.g., pre-emptive walks fire 5 min *before* the trigger time, not at it).

3. **Set silence windows:**
   - During every Active task (`task_started` → `task_completed`)
   - 30 min after any `task_completed`
   - 2 hours after any `bad_habit_slip_logged` for that habit (one response, then back off)
   - Sleep block start → wake alarm
   - First 15 min of any deep-work block

4. **Emit `suggestion_generated`** for each scheduled candidate.

### 12.2 Trigger: `bad_habit_slip_logged`

Reactive path — coach decides whether and how to respond.

**Logic:**
1. Check if `slip_streak_detected` is currently active for this habit → if yes, do nothing (wait for coalesced response)
2. Check 2-hour cooldown for this habit → if cooldown active, suppress
3. Check accountability mode and tone budget for the day
4. Compose response using:
   - Trigger tag (if user provided one)
   - Time-of-day pattern from this user's heatmap
   - Last 3 slip-and-response interactions for this habit (was the user receptive? frustrated? engaged?)
5. Queue notification at base_delay = 30s
6. Open silence window: 2 hours for this habit

### 12.3 Trigger: `suggestion_dismissed`

User dismissed an AI suggestion.

**Logic:**
- For the suggestion type, increment dismiss counter
- If dismiss counter for same type ≥ 3 in last 7 days → divide priority score by 2 for next 7 days (decay)
- AI memory captures: this user doesn't respond to this kind of suggestion right now

### 12.4 Trigger: `suggestion_accepted`

Reinforcement signal.

**Logic:**
- Boost similar-type suggestions in next planning runs
- Capture phrasing/timing/context of accepted suggestion → bias future generations toward this pattern

### 12.5 The "When NOT to speak" rule set

These are hard suppression rules — they override priority scores.

| Rule | Trigger | Behavior |
|---|---|---|
| Don't break the flow | `task_completed` fired | 30-min silence on proactive nudges |
| Don't pile on after a slip | `bad_habit_slip_logged` for habit X | 2-hour silence on habit X |
| Don't interrupt active work | Any task is in Started state | Suppress all P5/P6 |
| Don't shout into the void | 3 consecutive same-type dismissals | Stop suggesting that type for 7 days |
| Don't doom-loop | 3 consecutive bad days | Force tone to Supportive regardless of user setting; tomorrow's plan auto-trims to 3 essentials |
| Quiet day | User toggled Quiet Day | Only P1 and P2 fire |

### 12.6 Tone budget

Tough Love is a finite resource:
- Max 2 sharp interventions per day in Tough Love mode; remaining nudges soften
- Never Tough Love within 2h of `bad_habit_slip_logged`
- Never Tough Love during Quiet Day
- Auto-disabled for 48h after 3 consecutive bad days

---

## 13. Feature logic — Notification scheduler

The service that decides whether, when, and how to fire each notification.

### 13.1 Notification record

```
notification = {
  notif_id, category, priority (P1–P6),
  fire_at, deep_link, payload,
  state: "scheduled" | "sent" | "suppressed" | "dismissed" | "tapped"
}
```

### 13.2 Decision pipeline (runs whenever a notification is queued for firing)

For every notification, the scheduler walks this checklist *in order*:

1. **Priority bypass check.** If P1 → fire immediately, skip remaining checks
2. **Silence window check.** Is current time inside any silence window (active task, post-completion, sleep block, slip cooldown, Quiet Day)? If yes and priority ≤ P5 → suppress
3. **DnD check.** Is system DnD active? If yes and priority ≤ P5 → suppress
4. **Frequency cap check.**
   - Today's total >= budget? Suppress P5/P6
   - Same-category cap reached? Suppress
   - Last notification within 60 min of similar category? Defer 45 min
5. **Dedup check.** Is there a similar notification already pending or recently sent? Replace or drop
6. **Adaptive timing check.** Is user app-foreground right now? Convert to in-app toast, don't fire system push
7. **Fire.** Emit `notification_sent`. Decrement budget.

If suppressed at any step → emit `notification_suppressed` with the reason. AI memory uses this to learn what's not landing.

### 13.3 Custom alarm (P1) flow

Custom alarms bypass the entire pipeline. They are scheduled directly with the OS (`AlarmManager` on Android, `UNCalendarNotificationTrigger` + critical-alert entitlement on iOS) at the moment `task_scheduled` fires for an alarm-opted-in task. This guarantees they fire even if the app is killed.

---

## 14. Feature logic — Money saved

A pure derived calculation — emits no events of its own, just listens.

### 14.1 Passive savings (auto from quit habits)

For each bad habit configured with `cost_per_unit > 0`:

```
daily_passive_saved(habit) = max(0, baseline_per_day − count_today) × cost_per_unit
```

Recomputed whenever:
- `bad_habit_slip_logged` fires for this habit → daily saved drops
- `day_closed` fires → daily saved locked, summed into weekly/monthly totals

### 14.2 Active savings (manual deposits)

User logs in Tracker → Money tracker. Each deposit is a row.

### 14.3 Total

```
total_saved = sum(passive_daily) + sum(manual_deposits)
```

Displayed across the Money tracker, the smoking detail screen, and the EoD summary.

### 14.4 Relapse pause (the safety rule)

If user logs `count_today > baseline_per_day` for a habit:
- That habit's passive savings for today = 0 (not negative — never debit)
- The Money tracker UI **temporarily hides** the savings counter for the rest of the day
- It returns automatically at the next `day_closed` where `count_today ≤ baseline`

This prevents the contrast (*"You were saving ₹2,400, but today you wasted ₹100"*) from compounding shame after a bad day.

---

## 15. Feature logic — Failure & re-engagement

### 15.1 The failure-stage state machine

```
Active ──► Off-day ──► Bad day ──► 3 bad days ──► Silent day
   ▲                                                   │
   │                                                   ▼
   │                                              Ghost day 1
   │                                                   │
   └── Comeback ◄── Ghost day 14 ◄── Ghost day 7 ◄────┘
```

### 15.2 Failure-stage triggers

| Stage | Trigger formula | Auto-action |
|---|---|---|
| Off-day | `day_closed` with `mission_pct < 50%` | EoD message tone softens |
| Bad day | `day_closed` with `mission_pct < 20%` OR `slip_count > 2 × weekly_avg` | EoD message offers "lighten tomorrow"; emits `bad_day_detected` |
| 3 bad days | 3 consecutive `bad_day_detected` events | AI tone forced to Supportive 48h, tomorrow's plan auto-trims to 3 essentials |
| Silent day | App opened but 0 logs/taps in 12 waking hours | Single in-app toast at next typical-active hour |
| Ghost day 1 | App not opened 24h | One push at typical morning time |
| Ghost day 3 | App not opened 72h | One push: streaks paused not broken |
| Ghost day 7 | App not opened 168h | Final retention push: streaks expire tomorrow |
| Ghost day 14 | App not opened 14d | Comeback offer push |
| Dormant | App not opened 30d | All scheduled notifications cancelled |

### 15.3 Trigger: `comeback_initiated`

User opens app after gap ≥ 3 days.

**Logic:**
1. Replace Home with comeback modal: *"Hey. Welcome back."*
2. Three options: Easy day (1 task) · Half day (3 tasks) · Full day (regular plan)
3. User picks one → emit `comeback_path_chosen`
4. Force coach tone to Supportive for next 48 hours
5. Suppress any reference to the gap in coach messages for 48 hours
6. Restore paused streaks if gap ≤ 7 days (Section 8.5)
7. Cancel all pending ghost-period notifications

---

## 16. Edge cases & failure handling rules

These are the cases where the simple logic above breaks.

### 16.1 Two tasks scheduled at the same time

User has both *Class* and *Lunch* scheduled at 1 PM (calendar conflict).
- Plan generator detects overlap at `task_scheduled` time → flags both with `conflicts_with: [other_task_id]`
- UI shows both stacked with a yellow conflict ribbon
- User can resolve in setup (move one) or accept it (overlap in real life happens — eating during class)
- Both can be Started simultaneously; system relaxes the "one active task" rule when conflict ribbon is present
- For routine % math, conflicting blocks each contribute independently

### 16.2 User Starts a task days late

User taps Start on a block whose `planned_start` was 3 days ago.
- This is unusual but allowed (rare but legitimate use case: catching up on a paused habit)
- System records it as a `task_started` for today, not for the original scheduled date
- The original block on the past date stays Abandoned
- The newly-started block is treated as an ad-hoc task added to today
- Coach is notified of the unusual pattern but doesn't comment unless asked

### 16.3 User completes a task without ever starting it

User taps Mark complete on a Scheduled block (skipping Started).
- Allowed but UI confirms: *"Mark complete without starting?"*
- On confirm: emit synthetic `task_started` immediately followed by `task_completed`, both with `source: "ui_quick_complete"`
- `actual_duration` = 0
- AI memory flags this — it can't learn duration patterns from quick-completes

### 16.4 Reframing failure language

This is a rule, not a feature. **Anywhere the system surfaces a missed/abandoned/slipped state to the user, the language must be:**
- ✅ *"What got in the way?"*
- ✅ *"Today was off — happens."*
- ✅ *"Logged. Thank you for being honest."*
- ❌ *"You failed."*
- ❌ *"Streak broken!"* (with red banner)
- ❌ *"You missed your goal."*

This is enforced at the UI layer via a curated string pack — copywriters work from this pack, not free-form. Coach messages are constrained by a system prompt rule that bans the failure vocabulary list.

### 16.5 Offline event handling

- All events are written to a local event store first, then synced
- Local store survives app kills and reboots
- On reconnect, sync pushes events in chronological order
- Server reconciles by event_id (idempotent) — duplicate events are dropped
- If a local event references a server-only ID that doesn't exist yet, it's queued in a pending bucket and retried after sync

### 16.6 Clock drift

User changes phone time, travels timezones, or has a wrong clock.
- Every event captures both `device_local_ts` and `server_ts` (set by Firestore on write)
- `server_ts` is authoritative for streak math, day-close, and ordering
- `device_local_ts` is used only for UI display
- If `|device_local_ts − server_ts| > 1 hour` → flag the user record and use server time exclusively until they sync

### 16.7 The user uninstalls and reinstalls

- On reinstall, login restores everything: identity profile, biometrics, schedule, all events, all streaks (paused at the install moment)
- A `comeback_initiated` event fires if gap ≥ 3 days
- All settings are restored from the cloud — the user does **not** redo onboarding

### 16.8 The user deletes their account

- `account_deleted` event fires
- 7-day soft-delete window: user can re-login to restore
- After 7 days: hard-delete job runs, all events purged, all derived data dropped, no recovery

---

## Closing principle

Every feature in Optivus is a **listener on the event log**. If an engineer can't describe a feature in terms of (1) the events it subscribes to, (2) the data it reads, (3) the events it emits, then the feature isn't designed yet — it's an idea.

This document is the contract between the AI's intelligence, the user's experience, and the engineering team's code. Every change to a feature must be expressible as a change to this document first.
