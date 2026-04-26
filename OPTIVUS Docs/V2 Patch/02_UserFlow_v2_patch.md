# User Flow v2 Patch

**Patches:** Optivus_UserFlow.md
**Changelog ref:** OPTIVUS_CHANGELOG_v2.md §1.4, §1.5, §1.6
**Apply by:** Insert new sections at marked locations + append "Failure paths" subsection to every existing flow.
**Audience:** Nairit, Antigravity, Claude

---

## Patch 1 of 3 — Insert "System-Driven Flows" section

**Location:** After all existing user-initiated flows, before the "End of User Flows" closing.

**Action:** INSERT new section.

```markdown
## System-Driven Flows

The v1 doc covered flows the user initiates — open app, log habit, complete routine.
These flows are the visible surface of Optivus. Below the surface, the system runs
its own flows that the user doesn't start but does experience. These are documented
here for the first time.

### The canonical system loop

Every system-driven flow follows this shape. Memorize it.

```
Trigger
  → Event created (always — System Contract Rule 3)
  → Rule engine evaluates (always — even if AI down)
  → AI decides OR rule fallback (graceful degradation)
  → Notification or in-app message (priority-routed)
  → User reacts (or doesn't — see Failure Paths)
  → Reaction logged as new event (closes the loop)
```

Every system flow below is an instance of this template.

### Flow S1 — Task missed

```
Time hits planned_end of a Scheduled task with state still 'scheduled'
  → Event: task.abandoned (auto-emitted by Cloud Scheduler, source='scheduler')
  → Rule engine matches: AbandonmentRule, MissedRoutineRule (if task in routine)
  → Priority filter selects highest eligible
  → Context Builder snapshots user state
  → If AI budget remaining: Claude generates message
  → If AI budget exhausted: rule.fallback_message used
  → ai_messages row written
  → Notification scheduled (priority-tier-appropriate)
  → User opens app, sees coach message
  → Two paths from here:
       (a) User taps a suggested action (Reschedule, Talk to me, etc.)
            → Action executed → new event emitted (e.g. task.rescheduled)
       (b) User dismisses or ignores (see Failure Paths)
```

### Flow S2 — Phone usage spike

```
Android UsageStatsManager reports app foreground time crossed threshold
  → Background isolate detects spike (Instagram > 60 min in 90-min window, etc.)
  → Event: screen_time.spike_detected (source='system')
  → Rule engine matches Rule C3 (heavy scrolling)
  → Same downstream as Flow S1
  → User receives nudge: "Instagram passed your limit a while ago. Was that
    intentional, or did it sneak up on you?"
  → Suggested actions: [Lock app for 1h] [Adjust my limit] [Talk to me]
```

iOS users do not get this flow — Apple's Screen Time API doesn't expose real-time
data to third-party apps. iOS users must log screen time manually.

### Flow S3 — Smoking pattern detected

```
User logs 4th cigarette in same day via addiction_logs
  → Event: habit.bad_logged (count_today=4, time_since_last=45min)
  → Rule engine matches Rule C2 (escalating same-day count)
  → Priority 1 (critical safety-net) — bypasses budget
  → Forgiving archetype forced (regardless of accountability)
  → Coach speaks even if 7 messages already sent today
  → Suggested actions: [30-min lockout] [Call buddy] [Talk to me]
```

### Flow S4 — Day close (scheduled)

```
sleep_time - 30 min on user's local clock (Cloud Scheduler)
  → Server-side compute:
       - Final mission ring %
       - Streak updates (atomic transaction per Database Schema §9.11)
       - Day summary for tomorrow's morning brief
  → Event: user.day_closed (source='scheduler')
  → If completion >= 0.95 → Rule B3 fires ("Today was clean. Sleep well.")
  → If user_state in ['slipping','relapsing'] → bad-day acknowledgment if applicable
  → Notification sent only if rule.priority allows at this hour
  → ai_context_snapshots gets a new row (long-term memory entry per AI Master §6)
```

### Flow S5 — Inactivity check

```
Cloud Scheduler runs hourly: query users with last_event > 24h ago
  → For each: Event: user.inactive_24h (source='scheduler')
  → Rule F1 fires (low-priority check-in)
  → Push notification sent (subject to "1 push per 72h" cap)
  → If user opens app: chat bubble queued for first view
  → If user remains inactive 48h: Event: user.inactive_48h (no new push)
```

### Flow S6 — Crisis pathway (special — see AI Master Engine §3.2 Case E)

```
User types message containing CRISIS_MARKERS_HIGH (Section 6.2 of AI Master Engine)
  → Event: chat.user_message (source='app', metadata.crisis_markers_matched=[...])
  → Rule E1 fires immediately, bypassing all gating
  → Fixed non-LLM message sent (iCall referral)
  → Tier escalation logic engages:
       1st in 7 days → Tier 1 (existing E1)
       2nd in 7 days → Tier 2 (stronger message + 72h silence + internal alert)
       3rd in 14 days → Tier 3 (chat draft offer + high-priority operational alert
                                + manual human follow-up within 24h)
  → 24-72h silence lock per tier
  → User-initiated chat still works during silence (engine listens, doesn't push)
```

### Why these flows matter

A v1 reader of the User Flow doc would build a reactive product — the user does
something, the app responds. That's wrong. Optivus is a *proactive* product. The
above flows are 60%+ of the messages the user receives. Without documenting them,
Antigravity would build the user-initiated 40% and miss the rest.
```

---

## Patch 2 of 3 — Append "Failure Paths" subsection to every existing flow

**Location:** End of every existing user-initiated flow in v1.

**Action:** APPEND. The exact wording below is a template — adapt the bracketed parts per flow.

For each existing flow, append a subsection in this shape:

```markdown
#### Failure paths

Real users don't follow happy paths. Every flow has at least three failure branches.

**Failure 1 — User ignores the notification or message.** No tap within 24 hours.
- Notification marked dismissed (read_at = NULL, dismissed_at = NOW + 24h)
- No follow-up unless flow explicitly defines one
- Coach speak budget NOT refunded (the message was delivered; the user chose not to engage)
- If pattern persists (5+ ignored notifications in 7 days), Notification Service
  reduces tier by 1 for next 7 days (auto-anti-fatigue)

**Failure 2 — User abandons the [flow-specific action] mid-step.**
- Partial state preserved (per onboarding-resilience pattern in PRD v2)
- Event emitted: [flow_name].abandoned with metadata.last_step_completed
- No coach message sent immediately (wait for the next event)
- If abandonment repeats 3+ times for same flow, Coach Rule "stuck flow" fires
  (offer to redesign or pause the underlying habit/routine/goal)

**Failure 3 — User logs a bad-habit spike during or just after this flow.**
- Engine detects via cross-event correlation in Context Builder (`derived.*` fields)
- Bad-day pattern detector (AI Master Engine §4.1) may consolidate this flow's
  message with the bad-habit message into a single compassionate response
- Original flow's coach message is suppressed in favor of the bad-day acknowledgment
```

**Apply this template to every existing v1 flow:**
- Flow 1: Onboarding completion
- Flow 2: Daily app open / Home tab view
- Flow 3: Routine setup
- Flow 4: Habit logging (good/bad)
- Flow 5: AI Coach chat
- Flow 6: End-of-day reflection
- Flow 7: Tracker tab interaction
- Flow 8: Goals tab interaction
- Flow 9: Profile tab interaction
- Flow 10-14: System sections (Notification, Event, Strategic AI, Failure States)

For Flows 10-14, no Failure Paths subsection is needed — they're already meta-flows.

---

## Patch 3 of 3 — Insert "Passive Tracking Flow" as standalone section

**Location:** After "System-Driven Flows," before "End of User Flows."

**Action:** INSERT new section.

```markdown
## Passive Tracking Flow (Android Advantage)

Optivus is Android-first specifically because Android exposes app usage and system
events to third-party apps in ways iOS doesn't. This is a real platform advantage,
and the User Flow doc documents how it's used.

### What gets tracked passively

| Signal | Source | Event emitted |
|---|---|---|
| App foreground time per app | UsageStatsManager | `screen_time.logged` (rolled up daily) |
| App foreground spike | Background isolate watching UsageStatsManager | `screen_time.spike_detected` |
| Phone unlock count | KeyguardManager + ScreenStateReceiver | `device.unlock` (aggregated, not per-event) |
| Notification interaction | NotificationListenerService (with permission) | `notification.tapped` for notifications from Optivus only |
| Time of day awake | Inferred from unlock pattern | not an event — input to user_state classifier |

### Permission model

Each passive signal requires explicit permission. The user grants them in
Onboarding Step 10 (Notifications + Usage Access) or later from Profile → Permissions.

- **Usage Access** (PACKAGE_USAGE_STATS) — required for screen time. No usage data
  collected if denied; user logs manually.
- **Notification Listener** — only requested if user opts into "passive notification
  tracking" in advanced settings. Default: off.
- **Display Over Other Apps** — requested only when user enables "app lockout"
  feature (Rule C3 suggested action).

### What is never tracked passively

To respect Data Ownership (PRD §[Data Ownership]):

- Content of notifications from other apps (only the fact that one occurred)
- Content of messages, emails, or any other app's data
- Location (no location permission requested at all in v1)
- Microphone, camera (never)
- Contacts (never)

If the user grants Notification Listener permission, the app reads only:
notification source app + delivery time. Not body text. Not subject. Not images.
This is enforced in code via a hardcoded allowlist of fields read.

### Flow P1 — Screen time spike intervention

```
Background isolate (runs every 60s when app has Usage Access permission):
  query UsageStatsManager.queryUsageStats() for last 90 minutes
  for each app in user's blocked_apps list:
    if foreground_time >= 60 minutes AND single session:
      check Redis: has spike fired for this app today?
      if no:
        emit event: screen_time.spike_detected
        set Redis flag (TTL until midnight local)
        proceed through Rule C3 standard flow
      if yes:
        skip — already nudged today
```

### Flow P2 — Daily screen time rollup

```
Daily at 23:55 local time (WorkManager job):
  query UsageStatsManager.queryUsageStats() for last 24 hours
  for each tracked app:
    write to screen_time_logs (one row per app per day)
    emit event: screen_time.logged with metadata.minutes_used, metadata.over_limit
  if any app's over_limit = TRUE for 5+ of last 7 days:
    emit event: screen_time.chronic_overuse
    Rule SC-X fires (low-priority awareness)
```

### iOS degraded path

iOS users get the same surface flows (S1, S3, S4, S5, S6) but P1 and P2 are
unavailable. Their `screen_time_logs` rows are populated only when the user opens
Settings → Screen Time and types in numbers manually. The product warns iOS users
about this limitation in onboarding.

### Why this matters

Two reasons.

First, the AI's Context Builder gets richer data on Android — it can see "user
spent 90 minutes on Instagram between 3pm and 5pm" without the user logging
anything. Coach interventions become timelier and more accurate.

Second, the entire "AI behavioral coach" promise of Optivus depends on the AI
having visibility into actual behavior. Manual logging produces optimistic data
(users underreport bad habits, overreport good ones). Passive tracking produces
realistic data. On Android, Optivus can be honest. On iOS, it's partly self-reported.
```

---

## End of User Flow v2 patch

Three changes total:
1. Inserted "System-Driven Flows" section (six flows S1-S6)
2. Appended "Failure paths" subsection to every existing user-initiated flow (Flows 1-9)
3. Inserted "Passive Tracking Flow" section with two flows P1-P2 and iOS degraded path

No existing flow content is removed. The doc grows by ~40% but every existing flow
is preserved.
