# Optivus Build Plan: V1 → V2 → V3

## Short Summary

Optivus is not a fresh project. The current repo already has a meaningful base:
- Firebase Auth email/password flow exists.
- `users/{uid}` creation exists.
- Router + bootstrap provider exist.
- 10-page onboarding UI exists.
- Routine UI is extensive and visually advanced.
- Firestore-backed `TaskModel`, `HabitModel`, `Streak`, `EventModel`, `UserModel` exist.
- `TaskService`, `HabitService`, `StreakService`, `EventService`, `RoutineService`, `NotificationService` already exist in partial form.
- `TrackerTab` already reads real habits from Firestore.
- `RoutineTab` already reads today’s Firestore tasks plus routine state.
- Cloud Function `aiGenerate` already exists for Gemini.

The biggest issue is not “missing UI.” The biggest issue is system mismatch:
- docs define event-driven, append-only, production-safe flows
- code implements only part of that contract
- some screens are real, some are still demo/static
- some services exist but do not yet satisfy the documented payloads, collection layout, or orchestration rules

V1 should focus on shipping a stable, honest core:
- Auth
- Onboarding completion
- Habits
- Tasks
- Event log
- Day close
- Basic streaks
- Basic rule-based coach fallback
- Local notifications

V2 should start only after V1 event integrity is stable:
- coach message storage
- rule engine expansion
- scheduled reactions
- identity progress
- notification budget

V3 should be production hardening and scale work:
- screen-time import
- Cloud Function schedulers
- analytics/archive
- App Check
- monitoring
- export/delete/privacy
- QA and release readiness

The plan below respects the current codebase and extends it rather than rewriting it.

---

## What Exists vs Missing

### What already exists in code

- `lib/main.dart` initializes Firebase, enables Firestore persistence, eagerly starts orchestrator, and runs day-close check.
- `lib/core/providers/bootstrap_provider.dart` already centralizes auth/onboarding bootstrap.
- `lib/core/router/app_router.dart` already routes based on bootstrap state.
- `lib/services/auth_service.dart` signs up/signs in with Firebase Auth and creates `/users/{uid}`.
- `lib/providers/onboarding_provider.dart` saves onboarding state to Firestore with debounce.
- `lib/views/screens/onboarding_screen.dart` already emits `onboarding_completed`.
- `lib/providers/routine_provider.dart` persists routine state and already emits some `task_scheduled` events.
- `lib/services/event_service.dart` writes to both `/users/{uid}/events/{eventId}` and `/users/{uid}/events_recent/{eventId}`.
- `lib/services/task_service.dart` supports create/start/pause/resume/complete/abandon.
- `lib/services/habit_service.dart` supports create/update/archive and good/bad logging.
- `lib/services/streak_service.dart` already performs a simple day-close streak rollup.
- `lib/services/notification_service.dart` already schedules basic local notifications.
- `lib/views/tabs/tracker_tab.dart` is partially real and reads habits from Firestore.
- `lib/views/routine/routine_tab.dart` is partially real and reads Firestore tasks via `todayTasksProvider`.
- `functions/index.js` already exposes authenticated Gemini generation.
- `firestore.indexes.json` already contains several core indexes.
- `firestore.rules` already restricts `/users/{uid}/**` to the owner.

### What is partially implemented and needs refactoring

- `EventService` exists but does not yet match the full event envelope from the docs:
  `user_id`, `device_id`, `payload_v`, `priority`, stronger idempotency behavior, canonical payload coverage.
- `TaskService` payloads are too thin versus docs. They currently omit documented fields like `planned_duration`, `actual_duration`, `drift_pct`, `reason`.
- `HabitService` stores logs under `/users/{uid}/habits/{habitId}/logs/...`, while docs target `/users/{uid}/habit_logs/{logId}` for primary reads.
- `RoutineService.runDayCloseIfNeeded()` writes `dailySummaries`, but docs expect richer `day_closed`, `routine_day_summarized`, and downstream state updates.
- `EventOrchestrator` exists, but most branches are still TODOs.
- `RuleEngineService` and `StateAggregatorService` exist, but only in very small prototype form.
- `CoachService` exists, but current Coach flow is ahead of the PRD’s V1 scope and not aligned with the AI Master Engine contracts.
- `RoutineNotifier` emits `task_scheduled` events for routine blocks, but does not create Firestore `tasks` docs for those generated blocks.
- `LogHabitSheet` emits raw events directly instead of calling `HabitService`, so UI logging can bypass actual habit log persistence.
- `HomeTab`, `GoalsTab`, and parts of `ProfileTab` are still mostly static/demo.

### What is missing

- No `identity_profile` collection/document flow.
- No `scheduled_notifications` persistence layer.
- No day-level mission ring aggregate source of truth.
- No proper event-driven notification scheduler logic.
- No complete routine-to-task generation pipeline.
- No rule-based fallback coach message system for V1 tied to stored coach messages.
- No full scheduled Cloud Functions for day-close, inactivity, morning brief, midday pulse.
- No screen-time importer.
- No BigQuery/archive path.
- No App Check / Remote Config integration.
- No tests in `test/`.

---

## Phase 1 — Fix & Stabilize Existing Codebase (V1)

### Task 1.1 — Make Bootstrap and Auth Deterministic
**Why:** Routing must never depend on incomplete user state. This is the first production blocker.

**What to tell Antigravity:**
Modify `lib/core/providers/bootstrap_provider.dart`, `lib/core/router/app_router.dart`, `lib/services/auth_service.dart`, `lib/models/user_model.dart`, and `lib/core/constants/event_names.dart`.
Keep `/users/{uid}` as the canonical root user doc.
Ensure signup creates `/users/{uid}` with fields:
`id`, `email`, `name`, `timezone`, `createdAt`, `updatedAt`, `schemaVersion`, `hasCompletedOnboarding`, `onboardingStep`, `lastDayClosed`.
Emit `user_signed_up` after both Firebase Auth and `/users/{uid}` creation succeed.
Do not allow `/home` routing unless `hasCompletedOnboarding == true`.
Keep bootstrap as the only place that decides auth/onboarding/home routing.

**How to verify:**
UI: new user always lands on onboarding, never directly on home.
Firebase console: `/users/{uid}` appears immediately after signup with the required fields.
Logs: bootstrap state transitions should go `initializing -> needsOnboarding` for a new user.

**Estimate:** 2h
- Done

### Task 1.2 — Align Onboarding Persistence with the Docs Without Breaking Existing UI
**Why:** Onboarding UI exists, but stored data is too shallow for the target system.

**What to tell Antigravity:**
Modify `lib/providers/onboarding_provider.dart`, `lib/repositories/user_repository.dart`, `lib/views/screens/onboarding_screen.dart`, and onboarding pages under `lib/views/onboarding/`.
Keep the current UI pages.
Expand saved onboarding payload under `/users/{uid}` and add structured docs:
`/users/{uid}/onboarding/state`
`/users/{uid}/profile/main`
`/users/{uid}/identity_profile/main` as a stub
Preserve existing fields and add missing fields needed for docs:
`selectedCategories`, `badHabits`, `goodHabits`, `goals`, `coachStyle`, `coachName`, `accountabilityType`, `scheduleItems`, `completedAt`.
On final submit, keep emitting `onboarding_completed`, but include a richer payload that matches the docs as closely as possible.

**How to verify:**
UI: refresh the app during onboarding and confirm selections persist.
Firebase console: see `/users/{uid}/onboarding/state`, `/users/{uid}/profile/main`, and `/users/{uid}/identity_profile/main`.
Logs: final onboarding event should include structured onboarding fields.

**Estimate:** 4h
- Done

### Task 1.3 — Stop V1 Screens from Bypassing Services
**Why:** Some UI writes events directly instead of using the intended service layer, which breaks data consistency.

**What to tell Antigravity:**
Modify `lib/views/habits/log_habit_sheet.dart`, `lib/views/tabs/tracker_tab.dart`, `lib/core/providers.dart`, and any habit/task quick-log entry points.
Replace direct event emission from UI with service calls:
good habit logs must call `HabitService.logGood`
bad habit logs must call `HabitService.logSlip`
task actions must call `TaskService.startTask`, `pauseTask`, `resumeTask`, `completeTask`, `abandonTask`
Do not let any user-facing logging screen write `good_habit_logged` or `bad_habit_slip_logged` directly.

**How to verify:**
UI: quick-log still works from Home/Tracker.
Firebase console: habit log docs are created, not only events.
Logs: event creation happens from service layer after Firestore write batching.

**Estimate:** 2h
- Done

---

## Phase 2 — Finish the V1 Event + Tasks + Habits Core

### Task 2.1 — Harden EventService to Match the Event Spec
**Why:** Every downstream system depends on the event log being correct.

**What to tell Antigravity:**
Modify `lib/services/event_service.dart`, `lib/models/event_model.dart`, `lib/core/utils/device_id.dart`, and `lib/core/constants/event_names.dart`.
Keep writes to both:
`/users/{uid}/events/{eventId}`
`/users/{uid}/events_recent/{eventId}`
Update the event envelope to include:
`eventId`, `eventName`, `ts`, `deviceLocalTs`, `deviceId`, `source`, `priority`, `payloadVersion`, `payload`, `schemaVersion`
Make duplicate writes idempotent by checking if the event doc ID already exists before creating it.
Keep replay logic from `events_recent`.
Do not redesign the service API; extend the current one.

**How to verify:**
Firebase console: new event docs contain the full envelope.
Logs: replay skips already processed events.
Manual test: double tap a habit log action should not create duplicate identical events with the same ID.

**Estimate:** 4h
- Done

### Task 2.2 — Bring TaskService Payloads and Rules Up to Contract
**Why:** Tasks already exist, but their payloads are too small for streaks, day close, and coach logic.

**What to tell Antigravity:**
Modify `lib/services/task_service.dart`, `lib/models/task_model.dart`, `lib/core/errors/app_errors.dart`, and `lib/core/constants/event_names.dart`.
Keep Firestore tasks at `/users/{uid}/tasks/{taskId}`.
Ensure task events include contract fields:
`taskId`, `type`, `plannedStart`, `plannedEnd`, `actualStart`, `actualEnd`, `plannedDurationMin`, `actualDurationMin`, `driftPct`, `reasonCategory`, `reasonTag`
Enforce only one active task at a time.
Add missing task operations for subtask checking if not finished.
Keep current task state machine and extend it instead of rewriting it.

**How to verify:**
UI: start, pause, resume, complete, skip all work from the Routine screen.
Firebase console: task docs update state correctly and event payloads are rich.
Logs: invalid transitions throw controlled errors instead of silently failing.

**Estimate:** 4h
- Done

### Task 2.3 — Normalize Habit Storage for V1 Reads
**Why:** Current habit logs are nested under each habit, but the docs require a primary per-user log stream for trackers and analytics.

**What to tell Antigravity:**
Modify `lib/services/habit_service.dart`, `lib/models/habit_log_model.dart`, `firestore.indexes.json`, and any tracker readers.
Preserve existing nested writes if needed for compatibility, but add canonical writes to:
`/users/{uid}/habit_logs/{logId}`
Each habit log must include:
`logId`, `habitId`, `habitKind`, `logType`, `occurredAt`, `loggedAt`, `quantity`, `trigger`, `note`, `source`, `schemaVersion`
Continue keeping habit configs in:
`/users/{uid}/habits/{habitId}`
Update tracker reads to use `/users/{uid}/habit_logs` where appropriate.

**How to verify:**
UI: Tracker totals and slip counts still render.
Firebase console: every log action creates a `/habit_logs/{logId}` doc.
Indexes: no missing-index errors on Tracker queries.

**Estimate:** 4h
- Done

### Task 2.4 — Make Routine Blocks Generate Real Task Documents
**Why:** Routine UI is advanced, but much of it is visual unless it creates real tasks.

**What to tell Antigravity:**
Modify `lib/providers/routine_provider.dart`, `lib/services/task_service.dart`, `lib/views/routine/routine_tab.dart`, and `lib/repositories/routine_repository.dart`.
When the user saves fixed schedule, classes, eating, and skin-care plans, create or update real task docs in:
`/users/{uid}/tasks/{taskId}`
Use `TaskModel` fields already in `lib/models/task_model.dart`.
Do not duplicate tasks on every save.
Generate deterministic IDs per routine block and date where possible.
Keep `RoutineState` as the configuration source and `tasks` as the execution source.

**How to verify:**
UI: Routine timeline shows the same blocks after app restart because real tasks exist.
Firebase console: saving a routine produces task docs, not only routine config changes.
Logs: related `task_scheduled` events fire for generated tasks.

**Estimate:** 4h
- Done

### Task 2.5 — Fix Day Close and Basic Streak Computation
**Why:** Streaks must come after logs/tasks exist. This is the core dependency chain.

**What to tell Antigravity:**
Modify `lib/services/streak_service.dart`, `lib/services/routine_service.dart`, `lib/models/streak_model.dart`, `lib/models/day_summary_model.dart`, and `lib/core/event_orchestrator.dart`.
Keep streak docs in:
`/users/{uid}/streaks/{habitId}`
Keep day summaries in:
`/users/{uid}/dailySummaries/{date}`
At day close:
1. roll up habits using `/users/{uid}/habit_logs`
2. compute streak changes
3. write/update streak docs
4. write `dailySummaries/{date}`
5. emit `streak_extended`, `streak_broken`, `streak_milestone_reached`, `day_closed`, and `routine_day_summarized` as appropriate
Do not compute streaks before habit logs are normalized.

**How to verify:**
UI: complete habits for one day, run day close, then see streak count increase next launch.
Firebase console: streak docs and daily summary docs update for the closed day.
Logs: day-close emits streak events once, not multiple times.

**Estimate:** 4h
- Done

---

## Phase 3 — Ship a Honest V1 User Experience

### Task 3.1 — Replace Static Home Tab Data with Real Firestore Aggregates
**Why:** Home is currently mostly demo data. V1 must show real counts even if simplified.

**What to tell Antigravity:**
Modify `lib/views/tabs/home_tab.dart`, `lib/core/providers.dart`, `lib/services/state_aggregator_service.dart`, and add any new Riverpod providers needed.
Replace static mission ring, habit pills, streak text, and routine summaries with real values from:
`/users/{uid}/tasks`
`/users/{uid}/habit_logs`
`/users/{uid}/streaks`
`/users/{uid}/dailySummaries`
Keep the current visual design.
If a metric is not ready, show an explicit empty/zero state instead of fake numbers.

**How to verify:**
UI: mission ring and streak cards change after logging habits and completing tasks.
Firebase console: values seen in Home match stored task/habit/streak data.
Logs: no hardcoded demo counts should remain.

**Estimate:** 4h
- Done

### Task 3.2 — Finish Notification Scheduling for V1 Core
**Why:** Tasks without reminders are not enough for the V1 promise.

**What to tell Antigravity:**
Modify `lib/services/notification_service.dart`, `lib/core/event_orchestrator.dart`, `lib/services/task_service.dart`, and create persistence for:
`/users/{uid}/scheduled_notifications/{notifId}`
For V1, support:
task reminder 5 min before start
task end reminder if task was started but not completed
basic streak milestone notification
basic bad-habit slip recovery notification
Persist scheduled notification docs with fields:
`notifId`, `category`, `scheduledFor`, `taskId`, `habitId`, `status`, `createdAt`, `schemaVersion`
Do not build the full AI notification budget yet; keep this as V1 basic scheduling.

**How to verify:**
UI: upcoming task creates a local reminder.
Firebase console: scheduled notification docs appear under the user.
Logs: notification scheduling happens from orchestrator listeners, not scattered UI code.

**Estimate:** 4h
- Done

### Task 3.3 — Add a V1 Basic Coach Fallback Instead of Full AI Chat
**Why:** PRD says full AI coach is phase 2. V1 should use rule-based fallback, not a half-finished live coach.

**What to tell Antigravity:**
Modify `lib/views/tabs/coach_tab.dart`, `lib/services/coach_service.dart`, `lib/services/rule_engine_service.dart`, `lib/services/state_aggregator_service.dart`, and `lib/core/event_orchestrator.dart`.
For V1:
store coach messages in `/users/{uid}/coach_messages/{messageId}`
render coach messages from Firestore
generate only rule-based fallback messages from local rules
disable or clearly gate freeform LLM chat behind a “Phase 2” / “Coming soon” state
Do not remove the existing Gemini plumbing; just stop making it the default V1 experience.

**How to verify:**
UI: logging a slip or hitting a milestone creates a coach message visible in Coach tab.
Firebase console: coach messages are stored.
Logs: no freeform Gemini call is required for basic V1 coach behavior.

**Estimate:** 4h
- Done

---

## Phase 4 — V2 AI Foundations

### Task 4.1 — Expand State Snapshot and Rule Engine Beyond Prototype Rules
**Why:** V2 AI quality depends on strong state inputs before any LLM wording layer.

**What to tell Antigravity:**
Modify `lib/models/context_snapshot.dart`, `lib/models/coach_rule.dart`, `lib/services/state_aggregator_service.dart`, and `lib/services/rule_engine_service.dart`.
Build a richer `ContextSnapshot` from:
`/users/{uid}/events_recent`
`/users/{uid}/streaks`
`/users/{uid}/dailySummaries`
`/users/{uid}/profile/main`
Add fields for:
`tasksCompletedToday`, `tasksAbandonedToday`, `goodHabitsLoggedToday`, `badHabitSlipsToday`, `longestActiveStreak`, `userState`, `lastCoachMessageAt`, `notificationBudgetRemaining`
Add more rules for:
missed task
multiple slips
streak milestone
ghost return
end-of-day summary
Keep rules in code, not Firestore.

**How to verify:**
UI: distinct user behaviors produce different coach messages.
Firebase console: snapshot reads come from documented collections.
Logs: rule evaluation can explain which rule fired and why.

**Estimate:** 4h
- Done

### Task 4.2 — Introduce Coach Decision Audit Logging
**Why:** Once AI-like decisions start, you need observability.

**What to tell Antigravity:**
Modify `lib/services/coach_service.dart`, `lib/core/event_orchestrator.dart`, and create writes to:
`/users/{uid}/coach_speak_log/{logId}`
For every coach decision, write:
`logId`, `triggerEventId`, `ruleId`, `decision`, `messageId`, `createdAt`, `schemaVersion`
Decisions should include at least:
`spoke`, `dropped_cooldown`, `dropped_no_rule`, `dropped_budget`

**How to verify:**
Firebase console: every coach message has a corresponding speak-log row.
Logs: you can tell whether a message was sent or suppressed.

**Estimate:** 2h
- Done

### Task 4.3 — Move Gemini Usage Behind Server-Side Coach Generation Path
**Why:** If V2 enables LLM wording, it must follow the rule engine and audit flow.

**What to tell Antigravity:**
Modify `functions/index.js`, `lib/services/gemini_service.dart`, `lib/services/coach_service.dart`, and `lib/views/tabs/coach_tab.dart`.
Keep the Cloud Function callable, but use it only after a rule has already decided to speak.
Write final generated coach output to:
`/users/{uid}/coach_messages/{messageId}`
and audit to:
`/users/{uid}/coach_speak_log/{logId}`
Do not let the LLM choose whether to speak.
Keep the system prompt grounded in onboarding, today’s tasks, habits, and streaks.

**How to verify:**
UI: coach replies still appear, but now follow a rule trigger path.
Firebase console: each generated message has both a message row and an audit row.
Logs: Cloud Function is called after rule selection, not before.

**Estimate:** 4h
- Done

---

## Phase 5 — V2 System Features on Top of Stable Events

### Task 5.1 — Add Identity Profile and Goal Progress Plumbing
**Why:** Goals exist as a concept, but the identity system from the docs is not wired.

**What to tell Antigravity:**
Modify `lib/models/goal_model.dart`, `lib/views/tabs/goals_tab.dart`, `lib/services/state_aggregator_service.dart`, `lib/core/event_orchestrator.dart`, and create/update:
`/users/{uid}/goals/{goalId}`
`/users/{uid}/identity_profile/main`
Add identity profile fields like:
`identities`, `progressPct`, `lastComputedAt`, `schemaVersion`
Use onboarding goals and daily task/habit progress to compute a first-pass identity score.
Keep it simple in V2. Do not overbuild scoring math.

**How to verify:**
UI: Goals tab shows real goal data and progress instead of placeholder content.
Firebase console: `identity_profile/main` is updated after day close or major events.
Logs: `identity_progress_changed` fires when score changes.

**Estimate:** 4h
- Done

### Task 5.2 — Add Notification Budget and Suppression Tracking
**Why:** The docs explicitly require notification fatigue control.

**What to tell Antigravity:**
Modify `lib/services/notification_service.dart`, `lib/core/event_orchestrator.dart`, `lib/services/state_aggregator_service.dart`, and user settings storage under:
`/users/{uid}/profile/main`
Track:
`dailyNotificationBudget`
`notificationsSentToday`
`quietDayMode`
Write suppression events:
`notification_suppressed`
Store them in `/users/{uid}/events` and `/users/{uid}/events_recent`.
Do not send coach or reminder notifications once budget is exhausted, except explicitly marked critical rules.

**How to verify:**
UI: set a low budget, trigger many reminders, and confirm later ones are suppressed.
Firebase console: budget fields update and suppression events appear.
Logs: suppressed notifications include the reason.

**Estimate:** 4h
- Done

---

## Phase 6 — V3 Production Hardening and Platform Expansion

### Task 6.1 — Add Scheduled Cloud Functions for Day Close, Inactivity, and Briefs
**Why:** Some time-based logic cannot depend on the app being open.

**What to tell Antigravity:**
Modify `functions/index.js` and create any needed helper files under `functions/`.
Add scheduled server-side jobs for:
day close
inactivity check
morning brief
midday pulse
These jobs should read/write user-scoped data only:
`/users/{uid}/events`
`/users/{uid}/events_recent`
`/users/{uid}/dailySummaries`
`/users/{uid}/streaks`
`/users/{uid}/coach_messages`
Do not remove the client fallback path yet; add server safety-net behavior first.

**How to verify:**
Firebase console: scheduled events and summaries appear even if the mobile app is not opened at that exact time.
Logs: scheduled jobs identify which users were processed.

**Estimate:** 4h
- Done

### Task 6.2 — Add Android Screen-Time Importer
**Why:** Screen-time and unlock data are part of the product promise and should come after the event system is stable.

**What to tell Antigravity:**
Create Android-side integration and Flutter bridge files as needed under:
`android/`
`lib/services/`
`lib/views/tabs/tracker_tab.dart`
Persist imported screen-time rows in:
`/users/{uid}/screen_time_logs/{logId}`
Emit related events into:
`/users/{uid}/events/{eventId}`
Use fields like:
`totalMinutes`, `topApps`, `unlockCount`, `capturedAt`, `schemaVersion`
Do not build iOS parity yet. Keep Android-first as the PRD states.

**How to verify:**
UI: Tracker shows real screen-time numbers on Android.
Firebase console: `screen_time_logs` rows are created.
Logs: importer emits events when sync runs.

**Estimate:** 4h
- Done

### Task 6.3 — Add App Check, Remote Config, and Production Safety Settings
**Why:** The app should not reach production without basic abuse and configuration controls.

**What to tell Antigravity:**
Modify Firebase setup files, `lib/main.dart`, and any platform config files needed.
Add Firebase App Check integration.
Add Remote Config defaults for:
coach enabled
notification budget default
AI feature flags
quiet-day defaults
Do not redesign app logic; inject configuration at startup and through providers.

**How to verify:**
UI: app still boots normally with Remote Config defaults.
Firebase console: App Check requests appear after setup.
Logs: feature flags can be read and used at runtime.

**Estimate:** 4h
- Done

---

## Phase 7 — Complete Version, QA, and Launch Readiness

### Task 7.1 — Build Delete/Export/Recovery Safety Flows
**Why:** The PRD explicitly calls out privacy and deletion expectations.

**What to tell Antigravity:**
Modify `lib/services/firestore_service.dart`, `lib/views/tabs/profile_tab.dart`, and any supporting services.
Implement a safe export/delete flow for user-owned collections:
`/users/{uid}`
`/users/{uid}/tasks`
`/users/{uid}/habits`
`/users/{uid}/habit_logs`
`/users/{uid}/goals`
`/users/{uid}/streaks`
`/users/{uid}/events`
`/users/{uid}/events_recent`
`/users/{uid}/coach_messages`
`/users/{uid}/coach_speak_log`
`/users/{uid}/dailySummaries`
Make delete explicit and user-confirmed. Do not use destructive shortcuts.

**How to verify:**
UI: Profile offers export/delete actions with clear confirmation.
Firebase console: user subtree is removed only after confirmation.
Logs: account deletion is recorded with `account_deleted`.

**Estimate:** 4h
- Done

### Task 7.2 — Add Test Coverage for the Real Core
**Why:** Production readiness is impossible without tests around the state machine and event rules.

**What to tell Antigravity:**
Create tests under `test/` for:
`EventService`
`TaskService`
`HabitService`
`StreakService`
`RuleEngineService`
Focus on:
idempotent event writing
task state transitions
habit logging correctness
day-close streak rollup
rule selection and suppression
Do not spend time snapshot-testing UI yet; prioritize logic.

**How to verify:**
Run the test suite and confirm the new tests pass.
Logs: edge cases like duplicate events and invalid task transitions are covered.

**Estimate:** 4h
- Done

### Task 7.3 — Launch Checklist Pass
**Why:** Final readiness requires one pass focused on broken flows, not features.

**What to tell Antigravity:**
Review and polish the end-to-end flows in:
signup
login
onboarding
home
routine
tracker
coach
profile
Confirm all of these use the real services and Firestore paths.
Fix any remaining fake/demo values that still show in production paths.
Do not add new features in this pass. Only stabilize and remove misleading placeholders.

**How to verify:**
UI: first-run flow works from signup to habit/task logging to day-close.
Firebase console: all major user actions write to the expected collections.
Logs: no obvious TODO-driven production behavior remains in core flows.

**Estimate:** 4h
- Done

