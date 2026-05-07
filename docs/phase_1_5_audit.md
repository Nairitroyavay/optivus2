# Phase 1–5 Audit Report

> Generated: 2026-05-04
> Scope: Tasks 1.1 → 5.3 as defined in `todo_V1_(fixed)_All_Features.md`
> Constraint: Read-only audit — no Dart or JS files modified.

---

## Task 1.1 — Auth lifecycle + root user schema

### Files inspected

- `lib/services/auth_service.dart`
- `lib/repositories/user_repository.dart`
- `lib/models/user_model.dart`
- `lib/views/screens/signup_screen.dart`
- `lib/views/screens/login_screen.dart`
- `lib/core/constants/event_names.dart`
- `firestore.rules`

### What is implemented

| Requirement | Status | Citation |
|---|---|---|
| Signup creates `/users/{uid}` | ✅ | `auth_service.dart:60-95` — `signUp()` creates user doc via batch |
| Root schema fields (uid, email, displayName, createdAt, updatedAt, schemaVersion, timezone, hasCompletedOnboarding, onboardingStep, lastDayClosed, coachName, coachStyle, accountabilityMode, notificationSettings) | ✅ | `user_model.dart` — full field set with `fromFirestore`/`toFirestore` |
| `user_signed_up` emitted once | ✅ | `auth_service.dart:80-87` — emits `EventNames.userSignedUp` in batch |
| Login works | ✅ | `auth_service.dart:97-120` — `signIn()` via FirebaseAuth |
| Rules deny cross-user | ✅ | `firestore.rules:5-7` — `isOwner(userId)` checks `request.auth.uid == userId` |

### What is missing

- **Rules-test for unauthenticated denial**: No dedicated Firestore rules test file exists. Deferred to Task 0.3.

### Tests

| Test | Status |
|---|---|
| `test/services/event_service_contract_test.dart` | ✅ 13 passing tests covering emit, dedup, batch |
| Firestore rules unit test | ❌ Missing — owned by Task 0.3 |

### Risk if shipped as-is

**LOW.** Auth works; event fires. Missing rules-test is a QA gap, not a runtime bug.

---

## Task 1.2 — About You onboarding (3 sub-pages)

### Files inspected

- `lib/views/onboarding/onboarding_page_5.dart`
- `lib/providers/onboarding_provider.dart`
- `lib/repositories/user_repository.dart`
- `lib/models/user_model.dart`
- `lib/models/identity_profile_model.dart`

### What is implemented

| Requirement | Status | Citation |
|---|---|---|
| Three sub-pages (Body basics, Lifestyle, Sensitive context) | ✅ | `onboarding_page_5.dart` — 3 sub-page widget tree |
| Sensitive-context skip (fields nullable) | ✅ | `onboarding_provider.dart` — sensitive fields default `null` |
| Data persists to Firestore paths | ✅ | `user_repository.dart:200+` — writes `state.aboutYou`, `main.biometrics`, `main.lifestyle`, `main.sensitiveContext` |
| No `biometrics_updated` during draft | ✅ | Draft saves only touch onboarding state path, not profile |
| Validation on body data | ✅ | `onboarding_provider.dart` — validates height/weight ranges |

### What is missing

- **Eating-disorder flag gating calorie tracking**: Flag is stored but consumption by Tracker variants (Task 7.6) is **not yet implemented**. No runtime guard exists.

### Tests

| Test | Status |
|---|---|
| Unit tests for onboarding provider | ❌ Missing — no `onboarding_provider_test.dart` exists |

### Risk if shipped as-is

**MEDIUM.** Eating-disorder flag is stored but ignored downstream. Users with ED history could see calorie-tracking features. Task 7.6 must land before shipping.

---

## Task 1.3 — Onboarding fixed schedule unlimited templates

### Files inspected

- `lib/views/onboarding/onboarding_page_9.dart`
- `lib/providers/onboarding_provider.dart`
- `lib/providers/routine_provider.dart`
- `lib/repositories/routine_repository.dart`

### What is implemented

| Requirement | Status | Citation |
|---|---|---|
| No 3-item cap | ✅ | `onboarding_page_9.dart` — dynamic list, no length guard |
| 6+ blocks persist as templates | ✅ | `routine_repository.dart` — `saveFixedScheduleTemplates()` writes array |
| Onboarding creates templates only (no one-time tasks) | ✅ | Writes to `/routine/current.templates.fixed_schedule` |
| Validation (empty title, invalid times) | ✅ | `onboarding_page_9.dart` — overlap + empty-title checks |

### What is missing

- **Shared widget extraction** (Task 4.2): Onboarding page 9 and `fixed_schedule_setup_screen.dart` are separate implementations. Behavioral drift risk.

### Tests

| Test | Status |
|---|---|
| `routine_service_contract_test.dart` | ⚠️ 17 tests all `skip: 'Not yet implemented'` |

### Risk if shipped as-is

**LOW–MEDIUM.** Templates save correctly. Risk: Settings screen may drift from onboarding behavior until Task 4.2 extracts the shared widget.

---

## Task 1.4 — Onboarding page 10 plan-ready

### Files inspected

- `lib/views/onboarding/onboarding_page_10.dart`
- `lib/views/screens/onboarding_screen.dart`
- `lib/providers/onboarding_provider.dart`
- `lib/repositories/user_repository.dart`
- `lib/providers/routine_provider.dart`

### What is implemented

| Requirement | Status | Citation |
|---|---|---|
| Page 10 exists | ✅ | `onboarding_page_10.dart` present |
| Start Today completes onboarding | ✅ | `onboarding_provider.dart:300+` — `completeOnboarding()` sets `hasCompletedOnboarding=true` |
| Fixed schedule appears in Routine today | ✅ | `routine_provider.dart` — `materializeForDate()` called after onboarding |
| `onboarding_completed` event | ✅ | `onboarding_provider.dart` — emits event in completion flow |
| Profile/identity docs written | ✅ | `user_repository.dart` — materializes `profile/main`, `identity_profile/main` |

### What is missing

- **`task_scheduled` events during first-day materialisation**: Templates are materialised but individual `task_scheduled` events may not fire for every task on the very first materialisation call — needs manual verification.
- **`notification_scheduled`/`suggestion_generated`**: Not confirmed to fire during first-day materialisation; depends on downstream orchestrator wiring.

### Tests

| Test | Status |
|---|---|
| Onboarding completion integration test | ❌ Missing |

### Risk if shipped as-is

**LOW.** Core flow works. Missing first-day event emissions are an analytics gap, not a user-facing bug.

---

## Task 2.1 — EventService production-grade

### Files inspected

- `lib/services/event_service.dart`
- `lib/services/event_payload_validator.dart`
- `lib/models/event_model.dart`
- `lib/core/constants/event_names.dart`
- `lib/core/utils/uuid_generator.dart`
- `test/services/event_service_contract_test.dart`

### What is implemented

| Requirement | Status | Citation |
|---|---|---|
| Event envelope (eventId, eventName, uid, timestamp, source, schemaVersion, payloadVersion, payload, deviceId, appVersion) | ✅ | `event_service.dart:80-120` — full envelope built in `emit()` |
| Duplicate eventId is no-op | ✅ | `event_service.dart:60-75` — checks Firestore doc existence before write |
| Both `events` + `events_recent` receive identical envelope | ✅ | `event_service.dart:100-115` — batch writes to both collections |
| Deterministic ID generation | ✅ | `uuid_generator.dart` — `generateDeterministicId()` from name+ts+uid+source |
| Local event bus (on/onAny) | ✅ | `event_service.dart` — StreamController-based bus |
| Replay recent events | ✅ | `event_service.dart` — `replayRecentEvents()` reads `events_recent` |
| Payload validation | ✅ | `event_payload_validator.dart` — covers core events |

### What is missing

- **Unvalidated event names**: Several newer events lack validator schemas — owned by Task 2.3. List: `screen_time_synced`, `slip_log_dismissed`, `bad_day_detected`, `weekly_insight_ready`, `comeback_path_chosen`, `account_deleted`, `notification_missed`, `coach_re_enabled`.

### Tests

| Test | Status |
|---|---|
| `event_service_contract_test.dart` | ✅ 13 tests passing (emit, dedup, batch, replay, dispose) |

### Risk if shipped as-is

**LOW.** Core event system is solid. Unvalidated event names ship without payload guards — listeners could receive malformed data. Task 2.3 addresses this.

---

## Task 2.2 — Firestore schema, rules, indexes alignment

### Files inspected

- `firestore.rules`
- `firestore.indexes.json`
- `docs/firestore_schema_v1_mapping.md`

### What is implemented

| Requirement | Status | Citation |
|---|---|---|
| Rules deny cross-user reads/writes | ✅ | `firestore.rules:5-7` — `isOwner()` on all user paths |
| Append-only on `/events` and `/events_recent` | ✅ | `firestore.rules:66-82` — `allow update, delete: if false` |
| Indexes for `events_recent` (eventName+timestamp) | ✅ | `firestore.indexes.json:4-9` |
| Indexes for `tasks` (scheduledDate+plannedStart, status+plannedStart) | ✅ | `firestore.indexes.json:27-69` |
| Indexes for `habit_logs` (habitId+occurredAt) | ✅ | `firestore.indexes.json:79-100` |
| Indexes for `streaks`, `coach_messages`, `suggestions`, `scheduled_notifications` | ✅ | `firestore.indexes.json:102-155` |

### What is missing

- **Missing indexes**: `notificationLog`, `weeklySummaries`, `usage` — owned by Task 2.4.
- **Missing explicit rules**: `suggestions`, `coach_messages`, `coach_speak_log` fall under the wildcard rule (lines 45-62) which grants full owner access. Task 17.1 should tighten these.

### Tests

| Test | Status |
|---|---|
| Firestore rules emulator test | ❌ Missing — owned by Task 0.3 |

### Risk if shipped as-is

**LOW.** Wildcard rule is permissive but not insecure (owner-only). Missing indexes will cause query failures for Phase 10+ features when they ship.

---

## Task 3.1 — TaskService contract

### Files inspected

- `lib/services/task_service.dart`
- `lib/models/task_model.dart`
- `lib/core/constants/event_names.dart`
- `test/services/task_service_contract_test.dart`

### What is implemented

| Requirement | Status | Citation |
|---|---|---|
| Full state machine (scheduled→started→paused/resumed→completed/skipped/abandoned) | ✅ | `task_service.dart:150-450` — all transitions with guards |
| Only one active task at a time | ✅ | `task_service.dart:180-195` — `MultipleActiveTasksError` thrown |
| Subtask check/uncheck | ✅ | `task_service.dart:460-540` — `checkSubtask()`/`uncheckSubtask()` |
| Task events per state change | ✅ | All transitions emit: `task_scheduled`, `task_started`, `task_paused`, `task_resumed`, `task_completed`, `task_abandoned`, `task_skipped`, `task_deleted`, `subtask_checked`, `subtask_unchecked` |
| Outcome docs written | ✅ | `task_service.dart:300-350` — writes `/task_outcomes/{taskId}` on terminal states |

### What is missing

- **Auto-complete parent when all subtasks checked**: `checkSubtask()` emits `allSubtasksChecked` flag in payload (line 516 of test) but does NOT auto-transition the parent task to `completed`. This is a design choice documented in the service, but the TODO requirement is ambiguous.

### Tests

| Test | Status |
|---|---|
| `task_service_contract_test.dart` | ✅ 25+ tests passing — covers create, start, pause, resume, complete, abandon, skip, delete, subtask check/uncheck, sync |

### Risk if shipped as-is

**LOW.** Best-tested service in the codebase. Auto-complete behavior is a UX gap, not a bug.

---

## Task 3.2 — Daily materialisation from reusable templates

### Files inspected

- `lib/providers/routine_provider.dart`
- `lib/repositories/routine_repository.dart`
- `lib/services/task_service.dart`

### What is implemented

| Requirement | Status | Citation |
|---|---|---|
| Idempotent materialisation | ✅ | `routine_provider.dart` — `materializeForDate()` uses deterministic task IDs; `syncRoutineTasks()` merges without clobber |
| Deterministic task ID pattern | ✅ | ID = `scheduledDate_routineType_templateId` pattern |
| Completed/skipped/abandoned past tasks preserved | ✅ | `task_service.dart:581-602` — `syncRoutineTasks` preserves in-progress state |
| `task_scheduled` emitted for new instances | ✅ | Via `createTask()` in materialisation flow |

### What is missing

- **Idempotency proof tests**: No dedicated test file for materialisation edge cases (DST, timezone change, 14-day window boundary). Owned by Task 5.1.

### Tests

| Test | Status |
|---|---|
| `routine_service_contract_test.dart` | ⚠️ 17 tests ALL `skip: 'Not yet implemented'` |
| `routine_notifier_test.dart` | ❌ Does not exist — owned by Task 5.1 |

### Risk if shipped as-is

**MEDIUM.** Materialisation logic works in practice but has zero automated test coverage. DST edge cases, timezone changes, and duplicate-prevention are unproven. Task 5.1 is critical.

---

## Task 3.3 — Routine tab Add + AI buttons + selected day

### Files inspected

- `lib/views/routine/routine_tab.dart`
- `lib/views/routine/add_task_sheet.dart`
- `lib/views/routine/ai_routine_panel.dart`
- `lib/views/routine/timeline_section.dart`

### What is implemented

| Requirement | Status | Citation |
|---|---|---|
| Add button visible, opens sheet | ✅ | `routine_tab.dart` — FAB opens `AddTaskSheet` |
| AI button opens panel | ✅ | `ai_routine_panel.dart` exists and is reachable |
| Task rows expose Start/Pause/Resume/Complete/Skip/Abandon | ✅ | `timeline_section.dart` — action buttons per task state |
| Selected-day task filtering | ✅ | `routine_tab.dart` — date picker filters `watchTasksForDay` |

### What is missing

- **Add button polish** (Task 5.2): Repeat-rule presets, reminder toggle, empty state copy — all deferred.
- **AI round-trip** (Task 11.3): AI panel exists but suggestion accept/dismiss does not write back.

### Tests

| Test | Status |
|---|---|
| Widget tests for routine_tab | ❌ Missing |

### Risk if shipped as-is

**LOW.** Core UI works. Polish items are UX improvements, not blockers.

---

## Task 3.4 — Routine setup screens & supplement screen (manual modes)

### Files inspected

- `lib/views/routine/fixed_schedule_setup_screen.dart`
- `lib/views/routine/skin_care_setup_screen.dart`
- `lib/views/routine/eating_setup_screen.dart`
- `lib/views/routine/class_setup_screen.dart`
- `lib/views/routine/supplement_setup_screen.dart`
- `lib/providers/routine_provider.dart`
- `lib/repositories/routine_repository.dart`

### What is implemented

| Requirement | Status | Citation |
|---|---|---|
| 5 setup screens render and save manual templates | ✅ | Each screen writes to `routine/current.templates.{type}` via `RoutineRepository` |
| AI text/photo tabs scaffolded | ✅ | Tab bars present; real AI wiring deferred to Phase 12 |
| `routine_template_created/updated/deleted` events | ✅ | `routine_repository.dart` — emits via EventService |

### What is missing

- **AI text/photo modes**: Scaffolded only — Phase 12 tasks (12.2–12.7) own the real wiring.
- **Settings entry-point**: Task 4.3 must wire Profile → setup screens.
- **Review-before-save widget**: Task 12.2 will harden.

### Tests

| Test | Status |
|---|---|
| Setup screen tests | ❌ Missing — no widget tests for any setup screen |

### Risk if shipped as-is

**LOW.** Manual modes work. AI modes are correctly deferred. No runtime risk.

---

## Task 3.5 — Day start, day close, mission ring

### Files inspected

- `lib/services/routine_service.dart`
- `lib/services/streak_service.dart`
- `lib/models/day_summary_model.dart`
- `lib/views/tabs/home_tab.dart`
- `functions/jobs/dayClose.js`

### What is implemented

| Requirement | Status | Citation |
|---|---|---|
| `day_started` emits once per date (idempotent) | ✅ | `routine_service.dart:94-119` — checks event doc existence before write |
| Day-close handles missed days in order | ✅ | `routine_service.dart:78-87` — while-loop walks `lastDayClosed` forward |
| Summary contains full metrics | ✅ | `day_summary_model.dart:10-37` — 30+ fields including task/habit/streak/identity/mission data |
| Server-side day-close (safety net) | ✅ | `functions/jobs/dayClose.js:420-630` — hourly Cloud Function |
| Mission ring with identity-aligned weighting | ✅ | `home_tab.dart:266-296` — `identityTags` overlap check, weight 1.0 vs 0.5 |
| Streak rollup via StreakService | ✅ | `streak_service.dart:217-264` — `runDayCloseRollup()` iterates habits + routines |
| Events: `day_started`, `day_closed`, `routine_block_completed`, `routine_day_summarized` | ✅ | Client: `routine_service.dart`; Server: `dayClose.js:547-600` |

### What is missing

- **Mission ring identity-weighted formula verification** (Task 5.3): The formula is implemented in `home_tab.dart:286-296` but lacks a unit test to prove correctness. Task 5.3 owns the proof.

### Tests

| Test | Status |
|---|---|
| `streak_service_contract_test.dart` | ⚠️ Present but many skipped (6 grep hits for skip/TODO) |
| Day-close integration test | ❌ Missing |
| Mission ring formula unit test | ❌ Missing — owned by Task 5.3 |

### Risk if shipped as-is

**LOW–MEDIUM.** Day-close works on both client and server. Risk: untested streak rollup edge cases (e.g., accountability mode interactions, forgiving-mode grace days). Formula is implemented but unproven.

---

## Task 4.1 — Audit & document fixed-schedule data flow

### Files inspected

- `todo_V1_(fixed)_All_Features.md` (lines 2245-2316)

### What is implemented

**Nothing.** Status: `[ ] Not started`.

### What is missing

- The audit document `docs/fixed_schedule_audit.md` does not exist.
- No widget-tree comparison between `onboarding_page_9.dart` and `fixed_schedule_setup_screen.dart`.

### Tests

N/A — documentation task only.

### Risk if shipped as-is

**LOW.** This is a documentation prerequisite for Task 4.2. No runtime impact, but blocks the shared widget extraction.

---

## Task 4.2 — Extract shared FixedScheduleEditor widget

### Files inspected

- `todo_V1_(fixed)_All_Features.md` (lines 2318-2415)
- `lib/views/onboarding/onboarding_page_9.dart`
- `lib/views/routine/fixed_schedule_setup_screen.dart`

### What is implemented

**Nothing.** Status: `[ ] Not started`.

### What is missing

- `lib/views/routine/widgets/fixed_schedule_editor.dart` does not exist.
- Both screens remain separate implementations with potential behavioral drift.

### Tests

N/A — not started.

### Risk if shipped as-is

**MEDIUM.** Two separate implementations writing to the same Firestore path. Validation logic, sort order, and field shape may diverge. Onboarding vs Settings could produce inconsistent data.

---

## Task 4.3 — Wire Settings → Fixed Schedule entry-point

### Files inspected

- `todo_V1_(fixed)_All_Features.md` (lines 2418-2494)

### What is implemented

**Nothing.** Status: `[ ] Not started`. Blocked by Task 4.2.

### What is missing

- Profile tab → Routine settings → Fixed Schedule navigation path.
- Routine settings sheet → "Fixed schedule" row with chevron.

### Tests

N/A — not started.

### Risk if shipped as-is

**LOW.** Users can still use fixed schedule via onboarding. Post-onboarding editing is not possible, which is a UX gap.

---

## Task 4.4 — (No Task 4.4 defined in master TODO)

> The master TODO defines Phase 4 as Tasks 4.1, 4.2, 4.3 only. No Task 4.4 exists.

---

## Task 5.1 — Idempotency & timezone proof for fixed-schedule daily repeat

### Files inspected

- `todo_V1_(fixed)_All_Features.md` (lines 2497-2578)
- `lib/providers/routine_provider.dart`
- `test/providers/` (directory listing)

### What is implemented

**Nothing.** Status: `[ ] Not started`.

The materialisation logic exists (Task 3.2) but this task's **proof** — the test suite — does not.

### What is missing

- `test/providers/routine_notifier_test.dart` — does not exist.
- Test cases: idempotency, DST transitions, timezone changes, 14-day window boundary, history preservation.
- `test/services/routine_service_contract_test.dart` has 17 tests **all skipped** (`skip: 'Not yet implemented'`).

### Tests

| Test | Status |
|---|---|
| `routine_notifier_test.dart` | ❌ Does not exist |
| `routine_service_contract_test.dart` | ⚠️ 17/17 tests skipped |

### Risk if shipped as-is

**HIGH.** Materialisation is the backbone of the daily routine. Zero test coverage means DST bugs, duplicate tasks, and timezone-crossing issues could reach production undetected. This is the highest-risk gap in Phases 1–5.

---

## Task 5.2 — Routine Add button polish

### Files inspected

- `todo_V1_(fixed)_All_Features.md` (lines 2581-2664)
- `lib/views/routine/add_task_sheet.dart`
- `lib/views/routine/routine_tab.dart`

### What is implemented

**Nothing new.** Status: `[ ] Not started`.

The base `add_task_sheet.dart` exists (Task 3.3) but the polish items are not done.

### What is missing

- Repeat-rule presets (daily / weekdays / weekends / weekly).
- Reminder toggle wired to `scheduled_notifications`.
- Clear validation copy (blank title, end < start, duration > 24h).
- Empty state on Routine tab ("Nothing planned" + Add).
- Loading/error states during save.

### Tests

| Test | Status |
|---|---|
| Widget tests for add_task_sheet | ❌ Missing |

### Risk if shipped as-is

**LOW–MEDIUM.** Users can add tasks but without repeat rules or reminders. This is a feature gap, not a bug. The empty state issue could confuse new users.

---

## Task 5.3 — Mission ring identity-aligned weighting

### Files inspected

- `todo_V1_(fixed)_All_Features.md` (lines 2667-2741)
- `lib/views/tabs/home_tab.dart` (lines 266-296)
- `lib/models/day_summary_model.dart`
- `functions/jobs/dayClose.js` (lines 143-204)

### What is implemented

The formula is **already coded** in `home_tab.dart:286-296`:

```dart
var completedValue = 0.0;
var maxValue = 0.0;
for (final task in scoredTasks) {
  final aligned = task.identityTags
      .map((tag) => tag.trim().toLowerCase())
      .any(identities.contains);
  final weight = aligned ? 1.0 : 0.5;
  maxValue += weight;
  if (task.state == TaskState.completed) completedValue += weight;
}
final progress = maxValue > 0 ? completedValue / maxValue : 0.0;
```

Server-side mirror in `dayClose.js:143-204` — `computeTaskMetrics()` uses identical `weight = aligned ? 1 : 0.5` logic.

**However**, the TODO marks this as `[ ] Not started` — the task asks for **verification + unit test**, which are missing.

### What is missing

- Unit test proving the formula matches EventSystem §10.1.
- Edge case: 100% with 0 identity-aligned tasks should surface as a Tracker insight (Phase 15).

### Tests

| Test | Status |
|---|---|
| Mission ring formula unit test | ❌ Missing |

### Risk if shipped as-is

**LOW.** The formula is implemented and matches the spec on both client and server. The missing unit test is a coverage gap, not a correctness concern.

---

## Summary Matrix

| Task | Status | Test Coverage | Risk |
|---|---|---|---|
| 1.1 Auth lifecycle | ✅ Done | ⚠️ Partial (no rules test) | LOW |
| 1.2 About You onboarding | ✅ Done | ❌ No provider test | MEDIUM |
| 1.3 Fixed schedule templates | ✅ Done | ❌ All routine tests skipped | LOW–MEDIUM |
| 1.4 Page 10 plan-ready | ✅ Done | ❌ No integration test | LOW |
| 2.1 EventService | ✅ Done | ✅ 13 tests passing | LOW |
| 2.2 Schema/rules/indexes | ✅ Done | ❌ No rules emulator test | LOW |
| 3.1 TaskService contract | ✅ Done | ✅ 25+ tests passing | LOW |
| 3.2 Daily materialisation | ✅ Done | ❌ 17/17 skipped | MEDIUM |
| 3.3 Routine tab UI | ✅ Done | ❌ No widget tests | LOW |
| 3.4 Setup screens (manual) | ✅ Done | ❌ No widget tests | LOW |
| 3.5 Day start/close/ring | ✅ Done | ⚠️ Partial | LOW–MEDIUM |
| 4.1 Fixed-schedule audit | ❌ Not started | N/A | LOW |
| 4.2 Shared widget extract | ❌ Not started | N/A | MEDIUM |
| 4.3 Settings entry-point | ❌ Not started | N/A | LOW |
| 5.1 Idempotency proof | ❌ Not started | ❌ Zero coverage | **HIGH** |
| 5.2 Add button polish | ❌ Not started | N/A | LOW–MEDIUM |
| 5.3 Mission ring verify | ⚠️ Impl done / test missing | ❌ No unit test | LOW |

### Top 3 Shipping Risks

1. **Task 5.1 (HIGH)** — Materialisation has zero test coverage. DST/timezone/duplicate bugs are unproven.
2. **Task 4.2 (MEDIUM)** — Two divergent implementations write to the same Firestore path.
3. **Task 1.2 (MEDIUM)** — Eating-disorder flag stored but not consumed; calorie tracking may surface for ED users.

### Firestore Paths Verified

All paths below are confirmed written by inspected code:

- `/users/{uid}` — root user doc
- `/users/{uid}/events/{eventId}` — append-only audit log
- `/users/{uid}/events_recent/{eventId}` — trimmed cache
- `/users/{uid}/onboarding/state.aboutYou`
- `/users/{uid}/profile/main.biometrics`
- `/users/{uid}/profile/main.lifestyle`
- `/users/{uid}/profile/main.sensitiveContext`
- `/users/{uid}/routine/current.templates.fixed_schedule`
- `/users/{uid}/tasks/{taskId}`
- `/users/{uid}/task_outcomes/{taskId}`
- `/users/{uid}/habits/{habitId}`
- `/users/{uid}/habit_logs/{logId}`
- `/users/{uid}/streaks/{streakId}`
- `/users/{uid}/dailySummaries/{date}`
- `/users/{uid}/identity_profile/main`
- `/users/{uid}/ai_context_snapshots/{snapshotId}`

---

## Re-Verification: Task 1.1 — Auth lifecycle + root user schema

> Date: 2026-05-04
> Status: Re-verified against codebase. No changes made.

### Files inspected
- `lib/services/auth_service.dart`
- `lib/repositories/auth_repository.dart`
- `lib/models/user_model.dart`
- `lib/views/screens/signup_screen.dart`
- `lib/views/screens/login_screen.dart`
- `lib/core/constants/event_names.dart`
- `firestore.rules`

### What is implemented

| Requirement | Status | Citation |
|---|---|---|
| Root schema fields | ✅ | `lib/models/user_model.dart:181-196` — full field set with `fromFirestore`/`toFirestore` (includes uid, email, displayName, createdAt, updatedAt, schemaVersion, timezone, hasCompletedOnboarding, onboardingStep, lastDayClosed, coachName, coachStyle, accountabilityMode, notificationSettings). |
| `user_signed_up` emitted once | ✅ | `lib/services/auth_service.dart:80-87` — exactly one emission via deterministic eventId. |
| Rules deny cross-user | ✅ | `firestore.rules:5-7` — `isOwner(userId)` enforces unauthenticated denial and cross-user read/write protection. |

### What is missing

- **Rules-test for unauthenticated denial**: `firestore.rules` correctly guards access, but no automated emulator test exists to confirm this behavior. (Owned by Task 0.3)

### Tests
- **Task 0.3 Dependency**: Rules emulator tests are missing.

### Risk if shipped as-is
**LOW.** Implementation meets requirements and limits access appropriately, but lacks test coverage for `firestore.rules`.

---

## Re-Verification: Task 1.2 — About You onboarding (3 sub-pages)

> Date: 2026-05-04
> Status: Re-verified against codebase. No changes made.

### Files inspected
- `lib/views/onboarding/onboarding_page_5.dart`
- `lib/providers/onboarding_provider.dart`
- `lib/repositories/user_repository.dart`
- `lib/models/user_model.dart`
- `lib/models/identity_profile_model.dart`

### What is implemented

| Requirement | Status | Citation |
|---|---|---|
| Three sub-pages exist (Body basics, Lifestyle rhythm, Sensitive context) | ✅ | `lib/views/onboarding/onboarding_page_5.dart:118-132` — `PageView` renders `_BodyBasicsView`, `_LifestyleView`, and `_SensitiveContextView`. |
| Sensitive-context skip works (fields nullable) | ✅ | `lib/models/user_model.dart:185-188` — sensitive fields are `bool?` and `String?`. `lib/views/onboarding/onboarding_page_5.dart:514-518` — 'Skip' sets `value == null`. |
| No `biometrics_updated` emitted during draft | ✅ | `lib/repositories/user_repository.dart:288-348` — `saveOnboardingData` saves directly to Firestore via batch subdocument operations without emitting events. |

### What is missing

- **Eating-disorder flag is consumed downstream by Tracker (Task 7.6)**: ❌ Missing dependency. The `eatingDisorderFlag` is stored but a codebase search confirms it is never read or used outside the onboarding flow and user models. Tracker consumption is missing.

### Tests
- `flutter analyze` passes.

### Risk if shipped as-is
**MEDIUM.** The eating-disorder flag is saved but completely ignored downstream. Users with an ED history could be exposed to sensitive tracker features (e.g., calorie counting) until Task 7.6 is implemented.

---

## Re-Verification: Task 1.3 — Onboarding fixed schedule unlimited templates

> Date: 2026-05-04
> Status: Re-verified against codebase. No changes made.

### Files inspected
- `lib/views/onboarding/onboarding_page_9.dart`
- `lib/providers/onboarding_provider.dart`
- `lib/providers/routine_provider.dart`
- `lib/repositories/routine_repository.dart`

### What is implemented

| Requirement | Status | Citation |
|---|---|---|
| No 3-item cap | ✅ | `lib/views/onboarding/onboarding_page_9.dart:450-506` — dynamic list (`_blocks`) built with `ReorderableListView.builder`, no length cap. |
| 6+ blocks persist as templates | ✅ | `lib/repositories/routine_repository.dart:21-36` — `saveFixedScheduleTemplates()` writes array to `/users/{uid}/routine/current.templates.fixed_schedule` without constraints. |
| Onboarding creates templates only | ✅ | `lib/providers/onboarding_provider.dart:21-38` — normalizes as fixed schedule blocks and saves them to onboarding state, eventually saving as templates. No single `task` doc is created directly during setup. |

### What is missing

- **Shared widget extraction (Task 4.2)**: ❌ Missing dependency. `lib/views/onboarding/onboarding_page_9.dart` has its own embedded editor dialog (`_showEditDialog`), meaning the widget has not been extracted into a shared component yet.

### Events

| Event | Status | Note |
|---|---|---|
| `routine_template_created` | ✅ | Supported by Event system. Emitted via `lib/providers/routine_provider.dart` (`_emitTemplateCreated`). |
| `routine_template_updated` | ⚠️ | Supported by Event system, but not explicitly emitted during onboarding save; relies on direct Firestore writes or `onboarding_completed`. |
| `routine_template_deleted` | ⚠️ | Supported by Event system, but not explicitly emitted during onboarding save. |

### Dependencies
- **Task 4.2**: Extract shared FixedScheduleEditor widget is missing.

### Tests
- `flutter analyze` passes.

### Risk if shipped as-is
**MEDIUM.** Data saves correctly, but the editor logic is duplicated between onboarding and the settings screen. They may drift apart until Task 4.2 extracts the shared widget.

---

## Re-Verification: Task 1.4 — Onboarding page 10 plan-ready

> Date: 2026-05-04
> Status: Re-verified against codebase. No changes made.

### Files inspected
- `lib/views/onboarding/onboarding_page_10.dart`
- `lib/views/screens/onboarding_screen.dart`
- `lib/providers/onboarding_provider.dart`
- `lib/repositories/user_repository.dart`
- `lib/providers/routine_provider.dart`

### What is implemented

| Requirement | Status | Citation |
|---|---|---|
| onboarding completion writes all required docs | ✅ | `lib/repositories/user_repository.dart:362-386` — `completeOnboarding` writes `hasCompletedOnboarding: true` to profile/main, saves routine, writes tasks to `/users/{uid}/tasks/{taskId}`, habits, goals, scheduled_notifications, and ai_context_snapshots. |
| `task_scheduled`, `notification_scheduled`, `suggestion_generated` emit during first-day materialisation | ✅ | `lib/providers/onboarding_provider.dart:257-293` — `_emitCompletionEvents` loops over tasks, notifications, and suggestions returned by `completeOnboarding` and emits corresponding events. |
| Routine tab shows fixed schedule today after Page 10 | ✅ | `lib/repositories/user_repository.dart:513-524` — `_materializeOnboardingSelections` writes the fixed schedule to `routine/current.templates.fixed_schedule`. `lib/providers/routine_provider.dart:676-681` — the provider loads the new routine and materializes the future tasks. |

### What is missing

- **First-day exact timing nuances**: The requirements state that these events should emit during materialisation. They are currently emitted from `_emitCompletionEvents` manually after `completeOnboarding()`, not generically inside the materializer, but this fulfills the requirement.

### Events

| Event | Status | Note |
|---|---|---|
| `onboarding_completed` | ✅ | Emitted correctly in `_emitCompletionEvents`. |
| `task_scheduled` | ✅ | Emitted correctly for created tasks in `_emitCompletionEvents`. |
| `notification_scheduled` | ✅ | Emitted correctly for created notifications in `_emitCompletionEvents`. |
| `suggestion_generated` | ✅ | Emitted correctly for suggestions in `_emitCompletionEvents`. |

### Dependencies
- **Task 2.1 (EventService production-grade)**: The events are generated and dispatched correctly via the `EventService` and the `onboarding_completed` payload passes existing validation rules, indicating dependency 2.1 is integrated.

### Tests
- `flutter analyze` passes without issues.

### Risk if shipped as-is
**LOW.** The onboarding completion process accurately persists the scheduled documents and fires the specified events. The routine correctly surfaces the fixed schedule blocks configured during onboarding.

---

## Re-Verification: Task 2.1 — EventService production-grade

> Date: 2026-05-04
> Status: Re-verified against codebase. No changes made.

### Files inspected
- `lib/services/event_service.dart`
- `lib/services/event_payload_validator.dart`
- `lib/models/event_model.dart`
- `lib/core/constants/event_names.dart`
- `lib/core/utils/uuid_generator.dart`
- `test/services/event_service_contract_test.dart`

### What is implemented

| Requirement | Status | Citation |
|---|---|---|
| Event envelope fields | ✅ | `lib/services/event_service.dart:67-78` — creates `EventModel` with `eventId`, `eventName`, `uid`, `timestamp`, `source`, `schemaVersion`, `payloadVersion`, `payload`, `deviceId`, and `appVersion`. |
| Duplicate eventId is a no-op | ✅ | `lib/services/event_service.dart:88-92` — `_firestore.runTransaction` calls `transaction.get(eventRef)` and returns `false` (no-op) if `existingSnap.exists`. |
| Transactional identical writes | ✅ | `lib/services/event_service.dart:94-95` — `transaction.set(eventRef, eventDoc)` and `transaction.set(_eventsRecentRef.doc(generatedId), eventDoc)` executed in the same transaction block. |

### What is missing

- **Unvalidated / Missing Event Names**: `slip_log_dismissed`, `bad_day_detected`, `weekly_insight_ready`, `comeback_path_chosen`, `notification_missed`, and `coach_re_enabled` are documented as needed but are completely missing from both `lib/core/constants/event_names.dart` and `lib/services/event_payload_validator.dart`. These will be patched in Task 2.3.

### Events

- (Read-only re-verification — emit nothing. Verified existing logic handles event names robustly.)

### Dependencies
- **Task 2.3**: Unvalidated event names need to be added to `event_names.dart` and `event_payload_validator.dart` validation rules.

### Tests
- `flutter analyze` passes.

### Risk if shipped as-is
**LOW.** The core transactional logic, duplicate prevention, and envelope creation are fully implemented and robust. The missing event schemas mean dependent Phase 2+ features will either fail validation or fail to track properly, which will be resolved in Task 2.3.

---

## Re-Verification: Task 3.1 — TaskService contract

> Date: 2026-05-04
> Status: Re-verified against codebase. No changes made.

### Files inspected

- `lib/services/task_service.dart`
- `lib/models/task_model.dart`
- `lib/core/constants/event_names.dart`
- `lib/core/errors/app_errors.dart`
- `test/services/task_service_contract_test.dart`

### Requirement 1 — Full state machine

| Transition | Method | Guard | Citation |
|---|---|---|---|
| → scheduled (create) | `createTask()` | `plannedEnd > plannedStart`, `durationMin ≤ 480` | `task_service.dart:226-245` |
| scheduled → started | `startTask()` | `state == scheduled` else `InvalidStateTransitionError` | `task_service.dart:314-319` |
| started → paused | `pauseTask()` | `state == started` else `InvalidStateTransitionError` | `task_service.dart:345-350` |
| paused → started (resume) | `resumeTask()` | `state == paused` else `InvalidStateTransitionError` | `task_service.dart:376-381` |
| started\|paused → completed | `completeTask()` | `state in {started, paused}` else `InvalidStateTransitionError` | `task_service.dart:413-418` |
| started\|paused → abandoned | `abandonTask()` | `!state.isTerminal && state != scheduled` else `InvalidStateTransitionError` | `task_service.dart:476-489` |
| scheduled → skipped | `skipTask()` | `state == scheduled` else `TaskSkippedFromInvalidStateError` | `task_service.dart:555-559` |
| Terminal guard | `TaskState.isTerminal` | Returns true for completed, skipped, abandoned | `task_model.dart:44-47` |

**Status: ✅ CONFIRMED** — all transitions are implemented with typed guards. Terminal states cannot be re-entered.

### Requirement 2 — Only one active task at a time

**What is confirmed:**
- `startTask()` calls `_activeTaskId()` (task_service.dart:308-311) which queries `where('state', isEqualTo: 'started').limit(1)` and throws `MultipleActiveTasksError` if any other task is already in `started` state.
- Contract test covers this: `'throws MultipleActiveTasksError when another task is started'` (task_service_contract_test.dart:222-232).

**Gap identified — `resumeTask()` does not re-check for a started peer:**

The sequence `startTask(A)` → `pauseTask(A)` → `startTask(B)` → `resumeTask(A)` is permitted by the current code:

1. After `pauseTask(A)`: A is `paused`; no `started` tasks exist.
2. `startTask(B)` passes `_activeTaskId()` (no `started` tasks) → B becomes `started`.
3. `resumeTask(A)` enforces only `state == paused` (task_service.dart:376-381), then transitions A to `started` without querying for an already-started peer.

Result: both A and B are in `started` state simultaneously — violating the declared invariant in the service header (task_service.dart:12).

`MultipleActiveTasksError` is defined in `app_errors.dart:56-61` but is only thrown from `startTask()`.

No test in `task_service_contract_test.dart` exercises the "pause A → start B → resume A" sequence.

**Status: ⚠️ PARTIAL GAP** — `startTask()` enforces the invariant; `resumeTask()` does not. Follow-up: add `_activeTaskId()` check to `resumeTask()` and a corresponding contract test.

### Requirement 3 — Subtask check auto-completes parent

**What is confirmed:**
- `_setSubtaskChecked()` computes `allDone = updated.every((s) => s.checked)` (task_service.dart:656).
- `allSubtasksChecked: allDone` is included in the event payload (task_service.dart:672).
- Contract test at line 516 asserts `payload['allSubtasksChecked'] == true` when the single subtask is checked.

**Gap confirmed:**
- When `allDone == true`, the code emits the flag but takes no further action. The parent task remains in `started` (or `paused`) state.
- Auto-transition (`completeTask()` call inside `_setSubtaskChecked()`) is absent.
- No test covers "all subtasks checked → parent auto-completes."

This gap also appeared in the original Task 3.1 audit (line 251-253 of this doc). It is not a regression — it was never implemented. The requirement is unambiguous: "confirm subtask check auto-completes parent."

**Status: ❌ NOT IMPLEMENTED** — Follow-up: a new Task (tentatively Task 3.1b or the next available slot) should implement `if (allDone) await completeTask(taskId)` within `_setSubtaskChecked()`, gated on `checked == true` only, plus a contract test for this path. Consider whether auto-complete should also be guarded (e.g., only when task state is `started`).

### Requirement 4 — Task and subtask events emit per state change

All 10 required event names are defined as constants in `event_names.dart:25-37` and are emitted inside the same `WriteBatch` as the Firestore mutation.

| Event | Emitted in | Citation |
|---|---|---|
| `task_scheduled` | `createTask()`, `syncRoutineTasks()` | task_service.dart:236, 291 |
| `task_started` | `startTask()` | task_service.dart:332 |
| `task_paused` | `pauseTask()` | task_service.dart:362 |
| `task_resumed` | `resumeTask()` | task_service.dart:398 |
| `task_completed` | `completeTask()` | task_service.dart:454 |
| `task_abandoned` | `abandonTask()` | task_service.dart:531 |
| `task_skipped` | `skipTask()` | task_service.dart:591 |
| `task_deleted` | `deleteTask()` | task_service.dart:616 |
| `subtask_checked` | `checkSubtask()` (via `_setSubtaskChecked`) | task_service.dart:666 |
| `subtask_unchecked` | `uncheckSubtask()` (via `_setSubtaskChecked`) | task_service.dart:666 |

Idempotency: `checkSubtask()` / `uncheckSubtask()` return early without emitting when `subtask.checked == checked` (task_service.dart:652), so no duplicate events fire on a no-op toggle.

**Status: ✅ CONFIRMED** — all 10 events confirmed; no extra events invented.

### Firestore paths

| Path | Written by | Notes |
|---|---|---|
| `/users/{uid}/tasks/{taskId}` | All state transitions | Confirmed — `_tasksRef.doc(taskId)` in every method |
| `/users/{uid}/task_outcomes/{taskId}` | `completeTask()`, `abandonTask()`, `skipTask()` | Written via `_writeTaskOutcome()` inside the same batch |

### Tests

| Test group | Tests | Status |
|---|---|---|
| `createTask` | 4 | ✅ Passing |
| `watchTask / watchTasksForDay / watchTasksForWindow / watchActiveTask` | 4 | ✅ Passing |
| `startTask` | 5 | ✅ Passing |
| `pauseTask / resumeTask` | 4 | ✅ Passing |
| `completeTask` | 5 | ✅ Passing |
| `abandonTask` | 5 | ✅ Passing |
| `skipTask` | 4 | ✅ Passing |
| `deleteTask` | 2 | ✅ Passing |
| `checkSubtask` | 4 | ✅ Passing |
| `uncheckSubtask` | 1 | ✅ Passing |
| `syncRoutineTasks` | 2 | ✅ Passing |
| resume-while-peer-started scenario | 0 | ❌ Missing |
| all-subtasks-checked → parent completes | 0 | ❌ Missing |

### Analyzer result

```
flutter analyze → No issues found! (ran in 5.5s)
```

No production Dart files were modified. No issues introduced or pre-existing.

### Gaps and follow-ups

| # | Gap | Severity | Suggested follow-up |
|---|---|---|---|
| G1 | `resumeTask()` does not call `_activeTaskId()` before transitioning `paused → started`. The sequence start→pause→start-peer→resume results in two simultaneous `started` tasks, violating the declared invariant. | MEDIUM | Add `_activeTaskId()` guard to `resumeTask()` (throw `MultipleActiveTasksError` if a different task is started). Add contract test for this path. |
| G2 | `allSubtasksChecked == true` in event payload does not auto-complete the parent task. Requirement says "subtask check auto-completes parent." | MEDIUM | Implement auto-completion: call `completeTask(taskId)` inside `_setSubtaskChecked()` when `checked && allDone`. Add contract test. |

### Risk if shipped as-is

**LOW–MEDIUM.** G1 requires an unusual multi-task flow (start → pause → start peer → resume) to trigger; most users will not hit it. G2 is a missing UX feature (users must manually complete tasks even after all subtasks are done). Neither gap causes data loss or security issues.

---

## Re-Verification: Task 2.2 — Firestore schema, rules, indexes alignment

> Date: 2026-05-04
> Status: Re-verified against codebase. No changes made.

### Files inspected
- `firestore.rules`
- `firestore.indexes.json`
- `lib/services/firestore_service.dart`
- `docs/firestore_schema_v1_mapping.md`

### What is implemented

| Requirement | Status | Citation |
|---|---|---|
| Rules deny cross-user reads/writes | ✅ | `firestore.rules:24-52` — `isOwner(userId)` enforces that all `/users/{userId}/*` collections require the current `request.auth.uid` to match `userId`. |
| Append-only enforcement on `/events` and `/events_recent` | ✅ | `firestore.rules:56-72` — explicitly sets `allow update, delete: if false;` for both `events` and `events_recent` while allowing `create`. |
| Indexes cover queries used by app today | ✅ | `firestore.indexes.json` — contains appropriate composite indexes used by `FirestoreService`, such as `scheduledDate`/`plannedStart`/`status`/`sourceRoutineType` for tasks, and `sessionId`/`createdAt` for coach messages. |

### What is missing

- **Missing explicit rules**: The wildcard rule (`firestore.rules:33-52`) handles all unspecified collections by granting full owner read/write access. As a result, system-generated or AI-generated collections such as `suggestions`, `coach_messages`, `coach_speak_log`, `ai_context_snapshots`, `dailySummaries`, and `weeklySummaries` lack tighter restrictions (e.g., read-only for the user) and rely on the general rule. (Owned by Task 17.1).
- **Missing indexes**: Specific indexes for `notificationLog`, `weeklySummaries`, and `usage` are not present in `firestore.indexes.json`. (Owned by Task 2.4).

### Events
- (Read-only re-verification — emit nothing.)

### Dependencies
- **Task 17.1**: Update `firestore.rules` to apply strict read-only constraints for AI-managed collections (like `suggestions`, `coach_messages`).
- **Task 2.4**: Add missing composite indexes for `notificationLog`, `weeklySummaries`, and `usage`.

### Tests
- `flutter analyze` passes.

### Risk if shipped as-is
**LOW.** Cross-user data isolation is correctly enforced and the event log is strictly append-only. The reliance on the wildcard rule for AI collections is secure (owner-only access), but users could theoretically mutate their own system-generated data until Task 17.1 tightens it. Missing indexes will only cause errors when newer unreleased UI starts querying them.

---

## Re-Verification: Task 3.2 — Daily materialisation from reusable templates

> Date: 2026-05-04
> Status: Re-verified against codebase. No changes made.

### Files inspected

- `lib/providers/routine_provider.dart`
- `lib/repositories/routine_repository.dart`
- `lib/services/task_service.dart`
- `test/services/routine_service_contract_test.dart`
- `test/services/task_service_contract_test.dart`

### Firestore paths

- `/users/{uid}/routine/current` — read by `RoutineRepository.loadRoutine()` (routine_repository.dart:115-119), written by `saveRoutine()` (routine_repository.dart:18-27)
- `/users/{uid}/tasks/{taskId}` — written by `TaskService.createTask()` and `RoutineRepository.mergeTaskFields()` during materialisation

### Requirement 1 — Idempotent: re-running materialise does not create duplicates

**Mechanism — three-layer guard in `materializeForDate()`:**

**Layer 1 — Deterministic ID.** Every candidate is assigned a stable ID before any Firestore interaction:

```
routine_{YYYY-MM-DD}_{routineType_slug}_{templateId_slug}
```

Function `_routineTaskId()` (routine_provider.dart:76-81). The same template on the same calendar day always yields the same string, regardless of wall-clock time or how many times materialisation runs.

**Layer 2 — Within-run dedup.** `_candidatesForDate()` maintains a local `seenIds` set (routine_provider.dart:751, 777). If `_routineTaskId()` produces a colliding ID for two templates on the same day (only possible with duplicate `templateId + routineType` combos), the second candidate is silently dropped.

**Layer 3 — Cross-run existence check.** `materializeForDate()` (routine_provider.dart:1147-1175):
1. Batch-fetches existing task states for the target date via `existingRoutineTaskStatesForDate()` (routine_repository.dart:127-140) — one query covers most tasks.
2. Falls back to a per-document read `_repo.taskState(c.task.id)` (routine_repository.dart:145-149) for any candidate not found in the batch — handles tasks whose `plannedStart` moved outside the date window.
3. `existingState == null` → `createTask()` (new task; emits `task_scheduled`)
4. `existingState != null` + non-terminal → `mergeTaskFields()` with `SetOptions(merge: true)` (no event, no overwrite)
5. `existingState != null` + terminal → `continue` (history preserved)

**Status: ✅ CONFIRMED** — repeated calls to `materializeForDate()` for the same date will create the task once and merge-update it on every subsequent run.

**Gap — unchecked race window:**
`materializeForDate()` is not wrapped in a Firestore transaction. Between the `existingRoutineTaskStatesForDate()` read and the `createTask()` write, a concurrent materialise call for the same date (e.g., two quick app launches) could both observe `existingState == null` and both call `createTask()`. The second `createTask()` call uses `batch.set()` (full overwrite, no merge) and would clobber any execution state written by the first call. In practice this is low risk for a single-user mobile app, but it is a latent data-integrity hole.

**Gap — `syncRoutineTasks()` is dead code in the materialisation path:**
`task_service.dart:253-304` defines `syncRoutineTasks()`, and the previous Task 3.2 audit cited it as part of the idempotency story. In the current code, `syncRoutineTasks()` is **not called from `routine_provider.dart`** or any other production caller — a codebase-wide grep confirms it is only referenced in `task_service.dart` (definition) and `test/services/task_service_contract_test.dart` (tests). The actual materialiser path uses `createTask()` + `mergeTaskFields()` instead. The contract tests for `syncRoutineTasks` are still valid, but they test a method that is unreachable from the materialiser as currently wired.

### Requirement 2 — Completed/skipped/abandoned past tasks are preserved

**Terminal-state guard in `materializeForDate()`:**
```dart
const _kTerminalTaskStates = {'completed', 'skipped', 'abandoned'};
// routine_provider.dart:726

if (existingState != null &&
    _kTerminalTaskStates.contains(existingState)) {
  continue; // do not overwrite history
}
// routine_provider.dart:1153-1155
```

When a task in `completed`, `skipped`, or `abandoned` state is encountered, materialisation skips the write entirely — neither `createTask()` nor `mergeTaskFields()` is called.

**`mergeTaskFields()` — safe for non-terminal tasks:**
`routine_repository.dart:154-161` uses `SetOptions(merge: true)` for all non-terminal merges. The fields written (`configFields` + `materializationMeta`) do not include `state`, `actualStart`, `actualEnd`, `pausedAt`, `abandonedAt`, or `driftPct` — so a `started` or `paused` task's execution state is never touched.

**`syncRoutineTasks()` — also safe (but unreachable from materialiser):**
`task_service.dart:272-287` uses `batch.set(docRef, updates, SetOptions(merge: true))` and the update map only contains config/schedule fields, not execution fields. Safe in isolation but not in the current call graph.

**Status: ✅ CONFIRMED** — terminal tasks are skipped at the caller level; non-terminal tasks are updated via merge-only writes that explicitly exclude execution fields.

### Requirement 3 — Deterministic task ID: scheduledDate + routineType + templateId

**Function `_routineTaskId()` (routine_provider.dart:76-81):**

```dart
String _routineTaskId({
  required String scheduledDate,  // e.g. "2026-05-04"
  required String routineType,    // e.g. "fixed_schedule"
  required String templateId,     // e.g. "template_abc"
}) =>
    'routine_${scheduledDate}_${_routineSlug(routineType)}_${_routineSlug(templateId)}';
```

`scheduledDate` is produced by `_routineDateKey(date)` (routine_provider.dart:62-65), which formats as `YYYY-MM-DD` (zero-padded, locale-independent).

`_routineSlug()` (routine_provider.dart:67-74) lowercases and replaces non-alphanumeric runs with underscores, ensuring a stable slug even if titles or type strings contain spaces or mixed case.

**Status: ✅ CONFIRMED** — ID = `routine_{YYYY-MM-DD}_{routineType}_{templateId}`, all three components are included and the format is stable.

**Minor gap — fallback templateId for generic templates:**
For templates in the `routineTemplates` map that lack a `templateId` field, the code falls back to `'${routineType}_$i'` (routine_provider.dart:985), where `$i` is the list index. If templates are reordered, the index changes, producing a different ID and a new task doc. This affects generic/custom templates only; the `FixedScheduleTemplate` always has a `templateId`.

### Requirement 4 — Task 5.1 idempotency tests: status

| Artefact | Status |
|---|---|
| `test/providers/routine_notifier_test.dart` | ❌ Does not exist |
| `test/services/routine_service_contract_test.dart` | ⚠️ Exists — 17/17 tests skipped (`skip: 'Not yet implemented'`) |
| Tests for: idempotency (re-run same date) | ❌ Missing |
| Tests for: terminal state preservation | ❌ Missing |
| Tests for: DST / timezone edge cases | ❌ Missing |
| Tests for: 14-day window boundary | ❌ Missing |
| Tests for: fallback `taskState()` single-doc read | ❌ Missing |
| Tests for: race window (concurrent materialise) | ❌ Missing |

**Status: ❌ CONFIRMED STILL PENDING** — Task 5.1 has not been implemented. Zero automated coverage exists for the materialisation logic itself. The only indirect coverage is the two `syncRoutineTasks` tests in `task_service_contract_test.dart` (lines 573-603), which test a method that is not currently called by the materialiser.

### Events

| Event | Path | Status |
|---|---|---|
| `task_scheduled` | `createTask()` → emits once per new task | ✅ Confirmed |
| `task_scheduled` (re-run) | `mergeTaskFields()` → no event emitted | ✅ Correct — no duplicate event |
| `task_scheduled` (terminal skip) | `continue` branch → no event | ✅ Correct — history preserved |

`EventNames.taskScheduled = 'task_scheduled'` is defined at `event_names.dart:25`.

### Tests

| Test | Status |
|---|---|
| `syncRoutineTasks` — returns early for empty list | ✅ Passing (task_service_contract_test.dart:574-579) |
| `syncRoutineTasks` — merges without clobbering in-progress state | ✅ Passing (task_service_contract_test.dart:581-603) |
| `materializeForDate` — idempotency (run twice, same date) | ❌ Missing |
| `materializeForDate` — terminal task preservation | ❌ Missing |
| `materializeForDate` — fallback single-doc read | ❌ Missing |
| Routine notifier tests (Task 5.1) | ❌ Missing — file does not exist |

### Analyzer result

```
flutter analyze → No issues found! (ran in 5.3s)
```

No production Dart files were modified.

### Gaps and follow-ups

| # | Gap | Severity | Follow-up |
|---|---|---|---|
| G1 | `syncRoutineTasks()` is a dead method — defined and tested but not called by the materialiser. The previous audit cited it as the idempotency mechanism; it is not. The actual mechanism is `createTask()` + `mergeTaskFields()`. | LOW | Document this in a code comment or remove from contract tests if the method is not needed. If it was intended as the materialisation entry point, wire it in. |
| G2 | Race window: `materializeForDate()` reads existence then calls `createTask()` without a transaction. Concurrent calls for the same date could double-create and clobber a task. | LOW | Wrap the check + write for each candidate in a Firestore transaction, or use a merge-safe `set()` inside `createTask()` when called from the materialiser. Track as part of Task 5.1. |
| G3 | Fallback `templateId` uses list index `$i` for generic templates — unstable if templates are reordered. | LOW | Require `templateId` to be non-empty on all templates before saving; reject or assign a UUID at write time. |
| G4 | Task 5.1 idempotency proof (routine notifier tests) — 0 tests, file missing. | HIGH | Implement `test/providers/routine_notifier_test.dart` per Task 5.1. Priority: idempotency, terminal preservation, 14-day window boundary. |

### Risk if shipped as-is

**MEDIUM.** The materialisation logic is functionally correct for normal single-user flows. The race window (G2) and the missing test coverage (G4) are the primary risks. G4 remains the highest-risk gap in the project: DST bugs, duplicate tasks, and timezone-crossing issues are unproven. No regression has been observed yet, but no automated test would catch one either.

---

## Re-Verification: Task 3.3 — Routine tab Add + AI buttons + selected day

> Date: 2026-05-04
> Status: Re-verified against codebase. No changes made.

### Files inspected

- `lib/views/routine/routine_tab.dart`
- `lib/views/routine/add_task_sheet.dart`
- `lib/views/routine/ai_routine_panel.dart`
- `lib/views/routine/timeline_section.dart`

### What is implemented

| Requirement | Status | Citation |
|---|---|---|
| Add button visible and opens sheet for selected date | ✅ | `lib/views/routine/routine_tab.dart:673-677` — `_HeaderActionButton(icon: Icons.add_rounded...)` calls `_openAddTaskSheet(selectedDate)`. |
| AI button opens panel | ✅ | `lib/views/routine/routine_tab.dart:667-671` — `_HeaderActionButton(icon: Icons.hub_rounded...)` sets `_aiOpen = true`. |
| Task rows expose Start/Pause/Resume/Complete/Skip/Abandon | ✅ | `lib/views/routine/timeline_section.dart:738-892` — `_TaskActionRow` renders buttons correctly depending on `TaskState` (scheduled, started, paused). |

### What is missing / Dependencies

- **Task 5.2 (Routine Add polish)**: ⚠️ Partially implemented. The `add_task_sheet.dart` contains basic fields (title, date, time, duration, category) and a reminder toggle, but it lacks advanced UI polish like full repeat-rule presets (weekdays/weekends) and distinct empty states for 'Nothing planned' beyond the basic placeholders in the timeline. 
- **Task 11.3 (AI round-trip)**: ✅ Fully implemented. The AI panel in `lib/views/routine/ai_routine_panel.dart` processes suggestions. Accepting or dismissing a suggestion triggers `_saveSuggestion`, `_acceptSuggestion`, or `_dismissSuggestion` in `routine_tab.dart`, which successfully round-trips data to Firestore and emits events.

### Events

| Event | Path | Status |
|---|---|---|
| `task_scheduled` | Created manually via `add_task_sheet` or accepted suggestion. | ✅ Supported |
| `task_started` | Clicked in timeline `_TaskActionRow`. | ✅ Supported |
| `task_completed` | Clicked in timeline `_TaskActionRow`. | ✅ Supported |
| `task_abandoned` | Clicked in timeline `_TaskActionRow`. | ✅ Supported |
| `suggestion_generated` | Output from `AiRoutinePanel`. | ✅ Supported |
| `suggestion_accepted` | Accepted in `AiRoutinePanel`. | ✅ Supported |
| `suggestion_dismissed` | Dismissed in `AiRoutinePanel`. | ✅ Supported |

*(Note: `task_*` events are verified as supported by the `TaskService` implementation; `suggestion_*` events are actively emitted by `_saveSuggestion`, `_acceptSuggestion`, and `_dismissSuggestion` in `routine_tab.dart`.)*

### Firestore paths

| Path | Notes |
|---|---|
| `/users/{uid}/tasks/{taskId}` | Written when adding a one-off task or accepting an AI suggestion. |
| `/users/{uid}/routine/current.templates.custom` | Written when adding a repeating template from the Add sheet. |
| `/users/{uid}/suggestions/{suggestionId}` | Written when generating, accepting, or dismissing an AI suggestion. |

### Tests

- `flutter analyze` passes.

### Risk if shipped as-is

**LOW.** The requested UI elements (Add button, AI button, Timeline actions) are fully functional. Task 11.3 (AI round-trip) works correctly. The minor missing polish from Task 5.2 (like explicit repeating rules) is a UX feature gap, not a runtime bug.

---

## Re-Verification: Task 3.3 — Routine tab Add + AI buttons + selected day

> Date: 2026-05-04 (second pass)
> Status: Re-verified against current code. No production files modified.

### Files inspected

- `lib/views/routine/routine_tab.dart`
- `lib/views/routine/add_task_sheet.dart`
- `lib/views/routine/ai_routine_panel.dart`
- `lib/views/routine/timeline_section.dart`
- `lib/views/routine/timeline_zoom_views.dart`
- `lib/core/constants/event_names.dart` (grep only)
- `lib/providers/routine_provider.dart` (addCustomRoutineTemplate, lines 1362–1374)

### Files changed

- `docs/phase_1_5_audit.md` (this section appended)

### Requirement verification

#### R1 — Add button visible and opens sheet for selected date

| Item | Citation | Status |
|---|---|---|
| Add button rendered in header | `routine_tab.dart:838-843` — `_HeaderActionButton(icon: Icons.add_rounded, label: 'Add', onTap: () => _openAddTaskSheet(selectedDate))` | ✅ |
| Sheet opens with correct date | `routine_tab.dart:539-548` — `_openAddTaskSheet(DateTime selectedDate)` passes `initialDate: selectedDate` to `AddTaskSheet` | ✅ |
| `selectedDate` tracks date-strip selection | `routine_tab.dart:767` — `ref.watch(selectedRoutineDateProvider)`; updated by `_selectDate()` at line 532 | ✅ |
| Empty-day state also has Add button | `routine_tab.dart:977-981` — `TimelineDayEmptyState(onAdd: () => _openAddTaskSheet(entry.key))` passes the specific day key | ✅ |

**Confirmed.** The Add button is always visible in the header and the date passed to the sheet is always the currently selected date, including from the empty-day fallback.

#### R2 — AI button opens panel

| Item | Citation | Status |
|---|---|---|
| AI button rendered in header | `routine_tab.dart:831-836` — `_HeaderActionButton(icon: Icons.hub_rounded, label: 'AI', onTap: () => setState(() => _aiOpen = true))` | ✅ |
| Panel renders when `_aiOpen` is true | `routine_tab.dart:1063-1106` — `if (_aiOpen) Positioned(... AiRoutinePanel(...))` | ✅ |
| Dim overlay and tap-to-close | `routine_tab.dart:1053-1060` — `if (_aiOpen) GestureDetector(onTap: () => setState(() => _aiOpen = false), ...)` | ✅ |
| Panel auto-fetches on open | `ai_routine_panel.dart:100` — `Future.delayed(400ms, _fetchSuggestions)` inside `initState` | ✅ |

**Confirmed.** AI button correctly opens the panel as an overlay anchored at the bottom.

**Note:** `ai_routine_panel.dart:260-275` has a comment `// ── Claude API call ──` but the implementation calls `GeminiService().generate()` not the Claude SDK. This is a stale comment, not a functionality issue, and is outside Task 3.3's scope.

#### R3 — Task rows expose Start / Pause / Resume / Complete / Skip / Abandon as status allows

`_TaskActionRow` in `timeline_section.dart:917-1098` is the single switch that controls which actions are visible:

| State | Actions exposed | Citation |
|---|---|---|
| `scheduled` | Start, Skip | `timeline_section.dart:941-970` |
| `started` | Pause, Complete, Abandon (+ live elapsed timer) | `timeline_section.dart:971-1009` |
| `paused` | Resume, Complete, Abandon | `timeline_section.dart:1060-1096` |
| `completed` | "Completed" badge — no mutable actions | `timeline_section.dart:1011-1035` |
| `abandoned` / `skipped` | "Skipped" badge — no mutable actions | `timeline_section.dart:1036-1059` |

All six callbacks are non-null for materialized blocks and wire directly to `taskServiceProvider` in `routine_tab.dart:1008-1033`:

```dart
onStart:    (taskId) => ref.read(taskServiceProvider).startTask(taskId),
onPause:    (taskId) => ref.read(taskServiceProvider).pauseTask(taskId),
onResume:   (taskId) => ref.read(taskServiceProvider).resumeTask(taskId),
onComplete: (taskId) => ref.read(taskServiceProvider).completeTask(taskId),
onSkip:     (taskId) => ref.read(taskServiceProvider).skipTask(taskId),
onAbandon:  (taskId) => ref.read(taskServiceProvider).abandonTask(taskId),
```

**Confirmed** — all six transitions render and fire correctly per state.

**Caveat:** `_TaskActionRow` only renders when `b.taskId != null` (`timeline_section.dart:655`). Template-only blocks (skin care, meals, classes, fixed — not yet materialized as Firestore tasks) show no action buttons. Materialization is triggered when a date is selected (`routine_tab.dart:536` — `materializeForDate(day)`), so the buttons should appear after the stream updates. This is expected design behavior, not a gap.

#### R4 — Flag dependency status: Task 5.2 and Task 11.3

**Task 5.2 (Routine Add polish) — STILL PARTIALLY PENDING**

| Item | Status | Detail |
|---|---|---|
| Repeat-rule presets (daily / weekdays / weekends / weekly) | ❌ Pending | `routine_tab.dart:609` hard-codes `'repeatRule': 'daily'`; `add_task_sheet.dart` has no repeat-preset picker |
| Reminder toggle | ✅ Done | `add_task_sheet.dart:387-396` toggle present; wired through `AddTaskRequest.reminderEnabled` to `_scheduleReminder()` at `routine_tab.dart:590-598` |
| Empty state for "Nothing planned" | ✅ Done | `TimelineDayEmptyState` at `timeline_section.dart:1141-1193` with Add Task button |
| Save loading / error states | ✅ Done | `add_task_sheet.dart:194-221` — `_saving` spinner + `_error` message |
| Validation copy (blank title, bad duration) | ✅ Done | `add_task_sheet.dart:184-191` — guards title empty and duration 1–480 |

Gap: only the repeat-rule presets are missing from Task 5.2.

**Task 11.3 (AI round-trip) — CONFIRMED DONE**

| Event path | Method | Firestore write | Event emitted | Citation |
|---|---|---|---|---|
| Suggestion generated | `_saveSuggestion()` | `suggestions/{id}` with `status: 'generated'` | `suggestion_generated` | `routine_tab.dart:682-703` |
| Suggestion accepted | `_acceptSuggestion()` | `suggestions/{id}` merge `{status: 'accepted', acceptedAt}` | `suggestion_accepted` | `routine_tab.dart:705-718` |
| Suggestion dismissed | `_dismissSuggestion()` | `suggestions/{id}` merge `{status: 'dismissed', dismissedAt}` | `suggestion_dismissed` | `routine_tab.dart:720-733` |

All three callbacks are wired from `AiRoutinePanel` at `routine_tab.dart:1103-1105`. Both `_fetchSuggestions` (auto) and `_sendUserMessage` (natural-language) paths call `onSuggestionGenerated` for each suggestion returned (`ai_routine_panel.dart:165-167`, `220-224`).

**Task 11.3 is complete.**

### Events

All seven required event names exist as constants in `lib/core/constants/event_names.dart`:

| Event | Constant | Emitted by | Status |
|---|---|---|---|
| `task_scheduled` | `EventNames.taskScheduled` (line 25) | `TaskService.createTask()` called from `_createOneOffTask()` | ✅ |
| `task_started` | `EventNames.taskStarted` (line 26) | `TaskService.startTask()` via `onStart` callback | ✅ |
| `task_completed` | `EventNames.taskCompleted` (line 29) | `TaskService.completeTask()` via `onComplete` callback | ✅ |
| `task_abandoned` | `EventNames.taskAbandoned` (line 30) | `TaskService.abandonTask()` via `onAbandon` callback | ✅ |
| `suggestion_generated` | `EventNames.suggestionGenerated` (line 73) | `_saveSuggestion()` in `routine_tab.dart:699` | ✅ |
| `suggestion_accepted` | `EventNames.suggestionAccepted` (line 74) | `_acceptSuggestion()` in `routine_tab.dart:713` | ✅ |
| `suggestion_dismissed` | `EventNames.suggestionDismissed` (line 75) | `_dismissSuggestion()` in `routine_tab.dart:729` | ✅ |

### Firestore paths

| Path | Written by | Verified |
|---|---|---|
| `/users/{uid}/tasks/{taskId}` | `taskService.createTask()` + `firestoreService.saveUserSubdocument('tasks', taskId, {...})` in `_createOneOffTask()` | ✅ |
| `/users/{uid}/routine/current.templates.custom` | `routineProvider.notifier.addCustomRoutineTemplate()` → `_repo.saveRoutine(state)` (routine_provider.dart:1372) | ✅ |
| `/users/{uid}/suggestions/{suggestionId}` | `_saveSuggestion()`, `_acceptSuggestion()`, `_dismissSuggestion()` via `firestoreService.saveSuggestion()` | ✅ |

**Note on task creation atomicity:** `_createOneOffTask()` writes in two sequential Firestore calls — `taskService.createTask()` then `firestoreService.saveUserSubdocument('tasks', taskId, {...})`. These are not wrapped in a transaction. A crash between the two writes would leave a task doc without `scheduledDate`, `status`, or `category` fields. Low probability but worth noting.

### Analyzer result

```
flutter analyze lib/views/routine/
Analyzing routine...
No issues found! (ran in 1.9s)
```

No production Dart files were modified. No issues introduced.

### Gaps and remaining risks

| # | Gap | Severity | Owning task |
|---|---|---|---|
| G1 | Repeat-rule presets (daily/weekdays/weekends/weekly) are not implemented; `repeatRule` is hard-coded to `'daily'` in `_createRepeatingTemplate()` (`routine_tab.dart:609`). | LOW–MEDIUM | Task 5.2 |
| G2 | `_createOneOffTask()` uses two non-atomic Firestore writes (`createTask` + `saveUserSubdocument`). A crash between them leaves a partial task document. | LOW | No current task owns this; recommend wrapping in a WriteBatch |
| G3 | Template-only blocks (unmaterialized) show no action buttons. Materialization is triggered on date selection but stream latency means buttons may not appear instantly on first tap. | LOW | Expected behavior; no gap |
| G4 | `ai_routine_panel.dart` comment says "Claude API call" but code calls `GeminiService().generate()` — stale comment. | INFO | Cleanup only |

### Summary

| Requirement | Status |
|---|---|
| Add button visible, opens sheet for selected date | ✅ Confirmed |
| AI button opens panel | ✅ Confirmed |
| Task rows expose Start/Pause/Resume/Complete/Skip/Abandon per state | ✅ Confirmed |
| Task 5.2 (Routine Add polish) | ⚠️ Pending — repeat-rule presets only |
| Task 11.3 (AI round-trip to Firestore) | ✅ Confirmed done |

**Risk if shipped as-is: LOW.** All required UI paths work. The only actionable gap is Task 5.2's repeat-rule presets.

---

## Task 3.4 — Re-verification (2026-05-04)

### Files inspected

- `lib/views/routine/fixed_schedule_setup_screen.dart`
- `lib/views/routine/skin_care_setup_screen.dart`
- `lib/views/routine/eating_setup_screen.dart`
- `lib/views/routine/class_setup_screen.dart`
- `lib/views/routine/supplement_setup_screen.dart`
- `lib/views/routine/routine_settings_sheet.dart`
- `lib/views/tabs/routine_settings_screen.dart`
- `lib/providers/routine_provider.dart`
- `lib/repositories/routine_repository.dart`

### Files changed

- `docs/phase_1_5_audit.md` (this section only)

### Requirement 1 — 5 setup screens render and save manual templates

| Screen | Save path | Firestore key | Status |
|---|---|---|---|
| `FixedScheduleSetupScreen` | `setFixedBlocks()` → `setFixedScheduleTemplates()` → `_saveDebounced()` → `_repo.saveRoutine(state)` | `templates.fixed_schedule` | ✅ |
| `SkinCareSetupScreen` | `_save()` (line 811) → `notifier.setRoutineTemplates('skin_care', ...)` → `_repo.saveRoutineTemplates(...)` | `templates.skin_care` | ✅ |
| `EatingSetupScreen` | `_save()` (line 729) → `notifier.setRoutineTemplates('eating', ...)` + `setMealPlan()` | `templates.eating` | ✅ |
| `ClassSetupScreen` | `_save()` (line 749) → `notifier.setRoutineTemplates('classes', ...)` + `setClasses()` | `templates.classes` | ✅ |
| `SupplementSetupScreen` | `_save()` (line 234) → `notifier.setRoutineTemplates('supplements', ...)` | `templates.supplements` | ✅ |

All five screens render a timeline or list UI and write to `/users/{uid}/routine/current.templates.{routineType}` via `RoutineRepository`. **Confirmed PASS.**

**Gap noted:** `FixedScheduleSetupScreen` uses the full-state save path (`saveRoutine`) instead of the targeted `saveRoutineTemplates` path, so it does **not** emit `routine_template_created` events (see Requirement 5 below) and does not record `importMetadata`. This is consistent with the screen having no AI import UI, but is a divergence from the other four screens.

### Requirement 2 — AI text/photo tabs scaffolded; real wiring deferred to Phase 12

| Screen | AI UI present | Mechanism | Status |
|---|---|---|---|
| `SkinCareSetupScreen` | ✅ FAB "AI / Photo" (line 1124); bottom-sheet with text field + two buttons (lines 882–929) | Calls `_repo.previewRoutineImport('skin_care', mode, ...)` with try/catch fallback | ⚠️ Beyond scaffold — Firebase Function `routineImport` is invoked |
| `EatingSetupScreen` | ✅ FAB "AI / Menu" (line 1011); bottom-sheet with text field + photo button (lines 793–838) | Same pattern | ⚠️ Beyond scaffold |
| `ClassSetupScreen` | ✅ FAB "Upload" (line 1018); bottom-sheet with notes field + image button (lines 819–855) | Same pattern | ⚠️ Beyond scaffold |
| `SupplementSetupScreen` | ✅ `SegmentedButton` Manual/Text AI tabs (lines 285–293); text-area + generate icon (lines 295–317) | Same pattern | ⚠️ Beyond scaffold |
| `FixedScheduleSetupScreen` | ❌ **No AI button or tab present** | n/a | ❌ Gap |

**Summary:** Four of five screens call `previewRoutineImport` (which forwards to `FirebaseFunctions.instance.httpsCallable('routineImport')`). This is a live Firebase Function call with a graceful fallback to locally-generated stub items, not a purely deferred placeholder. The original Task 3.4 audit described this as "scaffolded only," which understates the current state. If the `routineImport` Cloud Function is not deployed, all four screens degrade silently to local fallback — behaviour is safe.

`FixedScheduleSetupScreen` has no AI UI at all. This is a **real gap** if Phase 12 AI support is intended for that screen. Follow-up owner: whoever implements Task 12.3+ for fixed-schedule.

### Requirement 3 — Review-before-save widget is reusable

Each setup screen defines its own inline review modal bottom sheet:

| Screen | Method | Reusable? |
|---|---|---|
| `SkinCareSetupScreen` | `_showSkinReview()` (line 1016) | ❌ Local private method |
| `EatingSetupScreen` | `_showMealReview()` (line 911) | ❌ Local private method |
| `ClassSetupScreen` | `_showClassReview()` (line 916) | ❌ Local private method |
| `SupplementSetupScreen` | `_showSupplementReview()` (line 163) | ❌ Local private method |

No shared `ReviewBeforeSaveSheet` or equivalent widget exists anywhere in the codebase. All four inline sheets share the same structure (editable list, Remove/Regenerate/Accept-all buttons, `StatefulBuilder` for live state) and could be extracted. **Task 12.2 owns this extraction.** Confirmed NOT yet reusable.

### Requirement 4 — All setup screens listed in Routine settings hub

**`RoutineSettingsSheet` (`routine_settings_sheet.dart:23–64`):**

| Entry | `RoutineFilter` | Present |
|---|---|---|
| Skin Care Routine | `RoutineFilter.skinCare` | ✅ |
| Class Routine | `RoutineFilter.classes` | ✅ |
| Supplements | `RoutineFilter.supplements` | ✅ |
| Eating Routine | `RoutineFilter.eating` | ✅ |
| Fixed Schedule | `RoutineFilter.fixedSchedule` | ✅ |

**`RoutineSettingsScreen` (`routine_settings_screen.dart:73–129`):** same five entries, each wired to `_doSetup()` (lines 14–29) which pushes the corresponding setup screen.

No setup screen is missing from either hub entry-point. **Task 6.5 is IMPLEMENTED** for this aspect. Full Task 6.5 audit is out of scope here.

### Firestore paths

| Path | Confirmed write site |
|---|---|
| `/users/{uid}/routine/current.templates.skin_care` | `SkinCareSetupScreen._save()` → `setRoutineTemplates('skin_care', ...)` → `repo.saveRoutineTemplates()` |
| `/users/{uid}/routine/current.templates.eating` | `EatingSetupScreen._save()` → `setRoutineTemplates('eating', ...)` |
| `/users/{uid}/routine/current.templates.classes` | `ClassSetupScreen._save()` → `setRoutineTemplates('classes', ...)` |
| `/users/{uid}/routine/current.templates.supplements` | `SupplementSetupScreen._save()` → `setRoutineTemplates('supplements', ...)` |
| `/users/{uid}/routine/current.templates.fixed_schedule` | `FixedScheduleSetupScreen._saveToProvider()` → `setFixedBlocks()` → `_saveDebounced()` → `saveRoutine()` (full-doc write) |

All paths confirmed. The fixed-schedule path uses a full-doc overwrite rather than a targeted field merge; the others use `saveRoutineTemplates` which does a targeted merge of only `templates.{type}` and the corresponding setup flag.

### Events

| Event | Constant | Emitted | Call site |
|---|---|---|---|
| `routine_template_created` | `EventNames.routineTemplateCreated` (event_names.dart:62) | ✅ | `RoutineNotifier._emitTemplateCreated()` (routine_provider.dart:1403–1419), called from `setRoutineTemplates` and `addCustomRoutineTemplate` |
| `routine_template_updated` | `EventNames.routineTemplateUpdated` (event_names.dart:63) | ❌ | Constant defined; validator rule registered (event_payload_validator.dart:141); no emit call site found anywhere in `lib/` |
| `routine_template_deleted` | `EventNames.routineTemplateDeleted` (event_names.dart:64) | ❌ | Constant defined; validator rule registered (event_payload_validator.dart:142); no emit call site found anywhere in `lib/` |

**Note on `routine_template_created` scope:** The event is only emitted by `setRoutineTemplates` and `addCustomRoutineTemplate`. `FixedScheduleSetupScreen` goes through `setFixedBlocks` → `setFixedScheduleTemplates` → `_saveDebounced`, which does **not** call `_emitTemplateCreated`. Fixed-schedule template saves produce **no** `routine_template_created` events.

### Dependencies

| Task | Status | Evidence |
|---|---|---|
| Task 6.5 (Routine Settings Hub) | ✅ Implemented | Both `RoutineSettingsSheet` and `RoutineSettingsScreen` list all 5 screens with correct `RoutineFilter` dispatch |
| Task 12.2 (Harden review-before-save widget) | ❌ Not done | No shared widget exists; each screen has its own inline review sheet |
| Task 12.3 (AI wiring for skin care) | ❌ Not done | `previewRoutineImport` call exists but relies on unverified Cloud Function deployment |
| Task 12.4 (AI wiring for eating) | ❌ Not done | Same |
| Task 12.5 (AI wiring for classes) | ❌ Not done | Same |
| Task 12.6 (AI wiring for supplements) | ❌ Not done | Same |
| Task 12.7 (AI wiring for fixed schedule) | ❌ Not done | No AI UI on `FixedScheduleSetupScreen` at all |

### Analyzer result

```
Analyzing 9 items...
No issues found! (ran in 2.7s)
```

No production Dart or JS files were modified.

### Gaps and remaining risks

| # | Gap | Severity | Owning task |
|---|---|---|---|
| G1 | `FixedScheduleSetupScreen` has no AI button/tab; all other screens scaffold Phase 12 AI via `previewRoutineImport`. | MEDIUM | Task 12.7 |
| G2 | Fixed-schedule saves go through full-state `saveRoutine()` instead of `saveRoutineTemplates()`, so `routine_template_created` is never emitted for fixed-schedule blocks. | LOW | No current owner; could be resolved by routing `setFixedScheduleTemplates` through `setRoutineTemplates`. |
| G3 | `routine_template_updated` and `routine_template_deleted` events have constants + validator rules but zero emit call sites. Any edit or delete of a template is silently untracked. | LOW | No current owner |
| G4 | Review-before-save sheets are duplicated across four screens with near-identical code. Extraction deferred to Task 12.2. | LOW | Task 12.2 |
| G5 | AI modes call a live Firebase Function (`routineImport`) — if the function is not deployed or returns unexpected shape, all four screens fall back to locally-constructed stub items silently. No user-facing error is shown. | LOW–MEDIUM | Task 12.3–12.6 |

### Summary

| Requirement | Result |
|---|---|
| 5 setup screens render and save manual templates | ✅ All confirmed |
| AI text/photo tabs scaffolded, defer to Phase 12 | ⚠️ 4/5 screens; FixedSchedule missing AI UI entirely; live Firebase Function call present (not pure scaffold) |
| Review-before-save widget is reusable | ❌ Not yet — four inline duplicates; Task 12.2 owns extraction |
| All setup screens in Routine Settings hub (Task 6.5) | ✅ All 5 listed in both sheet and screen variants |
| `routine_template_created` event | ✅ Emitted for 4/5 types; fixed_schedule excluded |
| `routine_template_updated` / `_deleted` events | ❌ Constants + validator exist; zero emit call sites |

**Risk if shipped as-is: LOW.** Manual modes are production-ready for all five screens. AI paths degrade gracefully. The main action items are Task 12.7 (add AI UI to Fixed Schedule) and Task 12.2 (extract shared review widget).

---

## Task 3.5 — Day lifecycle: day_started / day_closed / summary rollup

> Re-verification run: 2026-05-04
> Constraint: read-only audit — no Dart or JS files modified.

### Files inspected

- `lib/services/routine_service.dart`
- `lib/models/day_summary_model.dart`
- `lib/views/tabs/home_tab.dart`
- `lib/core/providers.dart`
- `functions/jobs/dayClose.js`
- `lib/core/constants/event_names.dart` (supplementary)
- `lib/models/identity_profile_model.dart` (supplementary)

### Files changed

- `docs/phase_1_5_audit.md` (this file — new section appended)

---

### Requirement 1 — `day_started` emits once per local date (idempotent)

**Status: ✅ SATISFIED**

| Check | Evidence |
|---|---|
| Idempotency gate | `routine_service.dart:100–107` — `eventId = _eventId('day_started', uid, dateStr)` produces a deterministic doc ID; `eventRef.get()` is checked before any write; returns early if doc already exists |
| Called on launch | `routine_service.dart:71` — `runDayStartIfNeeded()` is called inside `runDayCloseIfNeeded()` on every app open |
| EventService writes the gate doc | `event_service.dart` (not in scope) is called with `eventId`; the same doc ID is used as the Firestore event record, making double-emit impossible across restarts |
| Constant defined | `event_names.dart:95` — `dayStarted = 'day_started'` |

**Gap noted:** `day_started` is **client-only**. The server safety-net (`dayClose.js`) never emits it. A day on which the user does not open the app produces no `day_started` event. Downstream listeners that strictly require `day_started` before acting will silently miss those days.

---

### Requirement 2 — `day_close` handles missed days in chronological order

**Status: ✅ SATISFIED (both client and server)**

**Client (`routine_service.dart:54–91`):**

| Step | Line | Behaviour |
|---|---|---|
| Read `lastDayClosed` from user doc | 64 | Starting anchor |
| Compute yesterday | 68 | `now - 1 day` |
| Set `dateToClose` to either `lastDayClosed+1` or yesterday | 78–80 | Handles null (first run) |
| While `dateToClose < today` → call `_closeDate()` → advance by 1 day | 82–87 | Chronological, one day at a time |
| `_closeDate()` skips already-written summaries | 337–343 | Idempotent on re-run |

**Server (`dayClose.js:441–616`):**

| Step | Line | Behaviour |
|---|---|---|
| Runs hourly, gates on user-local hour == 1 | 435 | Safety-net at 1am local |
| Same `lastDayClosed + 1` / yesterday anchor | 441–443 | Matches client logic |
| `while (dateStr <= yesterday)` loop | 445 | Chronological |
| Skips existing summary docs | 451–460 | Idempotent |
| `batch.commit()` + advance `dateStr` | 611–616 | Atomic per day |

---

### Requirement 3 — Summary fields

**Status: ✅ SATISFIED — all 8 required field groups present and populated**

Verification against `day_summary_model.dart` fields and `computeDailySummary()` in `routine_service.dart`:

| Required group | Model field(s) | Populated from | Client cite | Server cite |
|---|---|---|---|---|
| Task completion | `tasksCompleted`, `tasksAbandoned`, `tasksSkipped`, `tasksScheduled` | Task query on `plannedStart` range | `routine_service.dart:439–441` | `dayClose.js:155–157` |
| Routine completion | `routinesCompleted`, `routinesMissed`, `perRoutinePct`, `overallPct` | Per-task `_routineContribution()` | `routine_service.dart:464–472, 504–506` | `dayClose.js:179–202` |
| Focus minutes | `focusMinutes` | `task.actualDurationMin` | `routine_service.dart:433` | `dayClose.js:158` |
| Habit completion | `habitsCompleted`, `habitsBadLogged` | `StreakService.runDayCloseRollup()` result | `routine_service.dart:497–498` | `dayClose.js:467–473` |
| Slips | `slipCounts` (Map\<String,int\>) | `habit_logs` where `logType == 'slip'` | `routine_service.dart:478–484` | `dayClose.js:519–521` |
| Streak inputs | `streaksActive`, `streaksMilestonesHit` | Rollup result / `updateStreaksFromProgress()` | `routine_service.dart:507–508` | `dayClose.js:494–498` |
| Identity inputs | `identityProgress`, `identityAlignedCompletedValue`, `nonAlignedCompletedValue`, `maxPossibleValueToday` | `/users/{uid}/identity_profile/main` read | `routine_service.dart:413–427, 493–496` | `dayClose.js:483–510` |
| Mission score | `missionScore`, `missionPct` | `(alignedCompleted + nonAligned) / maxPossible` | `routine_service.dart:473–477, 488–489` | `dayClose.js:70–84` |

All `toFirestore()` keys confirmed at `day_summary_model.dart:107–136`. Server summary write at `dayClose.js:512–545` uses the same key names.

---

### Requirement 4 — Mission-ring identity-aligned weighting (Task 5.3) still pending

**Status: ✅ CONFIRMED PENDING — flag raised**

The current implementation in both client and server uses a **binary proxy weight**:

- `weight = aligned ? 1.0 : 0.5` — `routine_service.dart:453`
- `const weight = aligned ? 1 : 0.5` — `dayClose.js:171`

`identityProgress` stored in the summary is populated as `{identityName: progressPct}` where `progressPct` is a **single shared scalar** from the identity profile doc (not per-identity):

- `routine_service.dart:422–427` — all identities receive the same `identityProfile.data()?['progressPct']` value
- `dayClose.js:507–510` — same: `identityProgress[identity] = Number(identityProfile.progressPct || 0)`
- `identity_profile_model.dart:5` — `progressPct` is a single `int` field on the profile, not a per-identity map

**Task 5.3 (identity-aligned weighting for mission ring) is not implemented.** The infrastructure for per-identity weights (a `Map<String, double>` in the summary model) exists but is populated with the same global value for every identity. A proper Task 5.3 implementation would need:
1. Per-identity weight factors (e.g. derived from individual identity progress or user-configured priority)
2. Gradient weighting (not just binary 1.0/0.5) in the mission score formula
3. The `_MissionRing` widget in `home_tab.dart:991–1029` currently renders a single aggregate progress value — no per-identity breakdown

**The `home_tab.dart:266–358` mission ring** reads live from `todayTasksProvider` and `identityProvider`, not from the saved `DaySummary.missionScore`. It applies the same binary weight. So even the real-time display is Task-5.3-incomplete.

---

### Events

| Event name | Constant | Client emitted | Server emitted | Citation |
|---|---|---|---|---|
| `day_started` | `EventNames.dayStarted` (`event_names.dart:95`) | ✅ | ❌ | `routine_service.dart:111–119` |
| `day_closed` | `EventNames.dayClosed` (`event_names.dart:96`) | ✅ | ✅ | `routine_service.dart:385–399`; `dayClose.js:585–601` |
| `routine_block_completed` | `EventNames.routineBlockCompleted` (`event_names.dart:60`) | ✅ | ✅ | `routine_service.dart:614–625`; `dayClose.js:547–565` |
| `routine_day_summarized` | `EventNames.routineDaySummarized` (`event_names.dart:61`) | ✅ | ✅ | `routine_service.dart:368–384`; `dayClose.js:566–584` |

Event system exists and is used throughout. All four required events are registered constants and have emit call sites.

---

### Firestore paths

| Path | Operation | Citation |
|---|---|---|
| `/users/{uid}/dailySummaries/{date}` | Write (batch.set) once per closed day | `routine_service.dart:335–336, 355–356`; `dayClose.js:447–461, 512–545` |
| `/users/{uid}/tasks/{taskId}` | Read (query by `plannedStart` range); write (overdue mark) | `routine_service.dart:628–639` (read), `571–578` (write); `dayClose.js:123–133` (read), `221–242` (write) |
| `/users/{uid}/habit_logs/{logId}` | Read (query by `occurredAt` range) | `routine_service.dart:642–654`; `dayClose.js:465` via `getEventsForLocalDay` |
| `/users/{uid}/streaks/{streakId}` | Read + write (via StreakService rollup / `updateStreaksFromProgress`) | `routine_service.dart:348` (calls `StreakService.runDayCloseRollup`); `dayClose.js:305–418` |
| `/users/{uid}/identity_profile/main` | Read (identities + progressPct for mission score) | `routine_service.dart:413–421`; `dayClose.js:483–490` |

---

### Dependencies

| Task | Status | Evidence |
|---|---|---|
| Task 5.3 (mission-ring identity-aligned weighting) | ❌ NOT IMPLEMENTED | Binary 1.0/0.5 proxy in place; per-identity weights, gradient scoring, and ring breakdown absent from both client and server |

---

### Analyzer result

```
Analyzing optivus2...
No issues found! (ran in 5.4s)
```

No production Dart or JS files were modified.

---

### Gaps and remaining risks

| # | Gap | Severity | Owning task |
|---|---|---|---|
| G1 | `day_started` is client-only; server safety-net (`dayClose.js`) never emits it. Days where the user does not open the app have no `day_started` event — any downstream listener requiring the event will silently miss those days. | LOW | No current owner; could be added to `dayClose.js` safety-net as a server-originated `day_started` with `source: 'server_backfill'` |
| G2 | `identityProgress` in the summary is populated as `{identity: globalProgressPct}` — same scalar for every identity, not per-identity. Task 5.3 per-identity weighting is the fix. | MEDIUM | Task 5.3 |
| G3 | Mission ring in `home_tab.dart` reads live tasks, not `DaySummary.missionScore`. If Task 5.3 adds per-identity weights to the summary, the real-time ring must also be updated to match. | MEDIUM | Task 5.3 |
| G4 | `_closeDate()` reads tasks with a UTC `plannedStart` range (`routine_service.dart:628–639`). If the user's local timezone differs from UTC, tasks near midnight may fall into the wrong day's close. The server resolves this via `getLocalDayBounds(dateStr, timeZone)` (`dayClose.js:6`); the client does not. | MEDIUM | No current owner |
| G5 | `routine_day_summarized` payload emits `perRoutinePct` but the event payload in `dayClose.js:576` uses the same key (consistent). Both sides match schema. Low risk, confirming no drift. | INFO | None |

### Summary

| Requirement | Status | Notes |
|---|---|---|
| `day_started` emits once per local date (idempotent) | ✅ | Firestore event doc gates duplicate emits; client-only — no server coverage |
| `day_close` handles missed days in order | ✅ | While-loop on both client and server; chronological; idempotent |
| Summary contains all required fields | ✅ | All 8 field groups present in model and populated by both client and server |
| Task 5.3 mission-ring identity-aligned weighting | ❌ PENDING | Binary 1.0/0.5 proxy in place; per-identity gradient weighting not implemented |

**Risk if shipped as-is: LOW–MEDIUM.** The day lifecycle, rollup, and summary write are production-ready. The `day_started` server gap and UTC timezone handling for client day-close are worth a follow-up before scaling to multi-timezone users. Task 5.3 is the only significant feature gap.

---

## Task 6.1 — Skin Care Setup Screen (manual mode)

> Audit date: 2026-05-05
> Auditor: re-verify pass (read-only — no Dart or JS files modified)

### Files inspected

- `lib/views/routine/skin_care_setup_screen.dart`
- `lib/providers/routine_provider.dart` (lines 1389–1431)
- `lib/repositories/routine_repository.dart` (lines 50–76)
- `lib/views/tabs/routine_settings_screen.dart` (lines 1–30)
- `lib/core/constants/event_names.dart` (line 62)
- `functions/test/routineImport.contract.test.js` (dependency probe)

### Files changed

- `docs/phase_1_5_audit.md` — this section appended only.

### Firestore paths affected

- `/users/{uid}/routine/current.templates.skin_care` — written by `routine_repository.dart:63–75` via `saveRoutine({..., 'templates': {..., 'skin_care': templates}})`.

### Requirements verification

| Requirement | Status | Citation |
|---|---|---|
| Manual mode saves **title** | ✅ | `skin_care_setup_screen.dart:831` — `'title': item.title` |
| Manual mode saves **time** | ✅ | `skin_care_setup_screen.dart:833–834` — `startTime` / `endTime` in HH:mm (24 h) |
| Manual mode saves **weekday** | ⚠️ PARTIAL | `skin_care_setup_screen.dart:835` — encoded as `'repeatRule': 'weekly:${d + 1}'`; no explicit `weekday` key. Value is recoverable by parsing the rule string, but downstream consumers must parse it themselves. |
| Manual mode saves **steps** | ✅ | `skin_care_setup_screen.dart:836` — `[{'name': step.name}, ...]` |
| Manual mode saves **notes** | ⚠️ PARTIAL | `skin_care_setup_screen.dart:837` — field exists as `'notes': item.steps.map((step) => step.name).join(', ')`. It is auto-derived from step names; no dedicated notes text field exists in `SkinCareRoutineBlock` or the edit dialog (`_showEditDialog`). |

### Dependency status

| Dependency | Status | Evidence |
|---|---|---|
| **Task 4.3** — Settings entry-point | ✅ IMPLEMENTED | `routine_settings_screen.dart:15–18` — `RoutineFilter.skinCare` branch pushes `SkinCareSetupScreen`. |
| **Task 12.2** — AI text mode | ⚠️ UI STUB ONLY | `skin_care_setup_screen.dart:867–929` wires a text input → `previewRoutineImport` (mode `text_ai`) → `routineImport` Cloud Function. The CF **does not exist** (`functions/src/` directory is absent). The contract-test file (`functions/test/routineImport.contract.test.js:4–6`) explicitly states the CF is "planned" with all tests skipped. Client falls back to a locally generated dummy block on failure (`skin_care_setup_screen.dart:951–952`), so the UI does not crash. |
| **Task 12.3** — AI photo mode | ⚠️ UI STUB ONLY | `skin_care_setup_screen.dart:912–928` wires a "Photo Upload with AI" button. No camera/gallery picker is invoked — the call passes hardcoded metadata (`'source': 'skin_care_photo_upload'`) with no real image bytes. Same CF dependency gap as Task 12.2. |

### Event system

| Event | Status | Citation |
|---|---|---|
| `routine_template_created` | ✅ IMPLEMENTED | `event_names.dart:62` defines `EventNames.routineTemplateCreated = 'routine_template_created'`. `routine_provider.dart:1409–1411` calls `_emitTemplateCreated()` for every template saved by `setRoutineTemplates()`, which is the exact method called by `skin_care_setup_screen.dart:859`. Event payload contains `templateId` and `routineType`. |

### Gaps and follow-up ownership

| Gap ID | Description | Severity | Owner |
|---|---|---|---|
| G1 | `weekday` is not a top-level field — it is encoded in `repeatRule`. Any query or display code that expects a `weekday` key will fail silently. | LOW | Task 6.1 follow-up or Task 8.5 (materialization) |
| G2 | `notes` is auto-derived from step names, not user-authored. The edit dialog has no notes input. Users cannot attach free-text notes to a skin care block. | LOW | Task 6.1 follow-up |
| G3 | `routineImport` Cloud Function does not exist. Text-AI and Photo-AI modes degrade silently to a dummy block. No user-visible error is shown when the CF call fails. | HIGH | **Task 12.2 / Task 12.3** — do not ship AI import UI until CF is deployed. |
| G4 | Photo mode passes hardcoded metadata — no actual image is captured or uploaded. The "Photo Upload" button is cosmetically present but non-functional. | HIGH | **Task 12.3** |

### Analyzer result

```
flutter analyze lib/views/routine/skin_care_setup_screen.dart
No issues found! (ran in 1.6s)
```

No production Dart or JS file was modified by this audit pass.

### Risk if shipped as-is

**LOW (manual mode) / HIGH (AI import modes).** Manual mode is functionally correct — all five template fields are written to Firestore and `routine_template_created` fires per template. The two gaps (weekday encoding, notes derivation) are minor schema conventions, not runtime errors. AI import modes (Tasks 12.2/12.3) must not be surfaced to users until the `routineImport` Cloud Function is deployed and the photo capture flow is implemented.

---

## Task 6.3 — Class Setup Screen (manual mode)

> Audit date: 2026-05-05
> Auditor: re-verify pass (read-only — no Dart or JS files modified)

### Files inspected

- `lib/views/routine/class_setup_screen.dart`
- `lib/providers/routine_provider.dart` (lines 118–136, 444–479, 668–669, 921–950, 1343–1360, 1401–1431)
- `lib/views/routine/routine_tab.dart` (lines 255–268)
- `lib/core/constants/event_names.dart` (line 62)
- `functions/test/routineImport.contract.test.js` (dependency probe)

### Files changed

- `docs/phase_1_5_audit.md` — this section appended only. No production Dart or JS file modified.

### Firestore paths affected

- `/users/{uid}/routine/current.templates.classes` — written by `routine_repository.dart:63–75` via `saveRoutine({..., 'templates': {..., 'classes': templates}})`.
- `/users/{uid}/routine/current.classes` — also written via `state.toMap()` → `'classes': classes.map(e.toMap())`. This is the `ClassItem` list with explicit `weekday` int.

### Requirements verification

| Requirement | Status | Citation |
|---|---|---|
| Manual mode saves **subject** | ✅ | `class_setup_screen.dart:782` — `'title': item.subject`; also `ClassItem.subject` at `:771` |
| Manual mode saves **room** | ✅ | `class_setup_screen.dart:787` — `'room': item.room`; also `ClassItem.room` at `:772` |
| Manual mode saves **professor** | ✅ | `class_setup_screen.dart:788` — `'professor': item.professor`; also `ClassItem.professor` at `:773` |
| Manual mode saves **weekday** | ✅ | `class_setup_screen.dart:786` — `'repeatRule': 'weekly:$weekday'` in template. Additionally `ClassItem.weekday` (explicit int, `:777`) — unlike skin care, classes store weekday as a top-level int field in `ClassItem`. |
| Manual mode saves **start/end** | ✅ | `class_setup_screen.dart:784–785` — `'startTime': format24h(item.start)`, `'endTime': format24h(item.start + item.duration)` |

All five required fields are saved correctly. Weekday is doubly encoded: as an explicit int in `ClassItem` (used by `classesForDay`) and as `repeatRule: 'weekly:N'` in the template (used by materialization).

### Per-day class logic

| Mechanism | Status | Evidence |
|---|---|---|
| Setup: different blocks per day (Mon–Sun) | ✅ | `weeklyRoutines[0..6]` — one independent block list per day; 7-droplet day selector at `class_setup_screen.dart:1060–1086` |
| Save: weekday encoded per block | ✅ | `class_setup_screen.dart:763` — `int weekday = d + 1` iterated 0–6; written into both `ClassItem.weekday` and `repeatRule` |
| Load existing classes back into setup UI | ✅ | `class_setup_screen.dart:98–137` — `initState` reads `ref.read(routineProvider).classes` and rebuilds `weeklyRoutines` per `item.weekday` |
| Routine tab shows correct day's classes | ✅ | `routine_tab.dart:256` — `s.classesForDay(date.weekday)` filters by weekday using actual `ClassItem.weekday` int; uses real `startTime` / `endTime` — no hardcoded slots |
| Survives app restart | ✅ | `setClasses()` calls `_saveDebounced()` → `state.toMap()` includes `classes` list → persisted to Firestore; loaded back via `RoutineState.fromMap():732` |

The per-day class logic is complete and correct. A user who sets Chemistry on Monday and Art on Sunday will see only Chemistry on Mondays and only Art on Sundays in the routine tab timeline, at the exact times set.

### Dependency status

| Dependency | Status | Evidence |
|---|---|---|
| **Task 12.5** — Photo OCR timetable import | ⚠️ UI STUB ONLY | `class_setup_screen.dart:836–849` — "Upload timetable image/screenshot" button calls `_loadGeneratedClasses()` with `mode: 'timetable_image'`. No image picker is invoked — hardcoded metadata `{'source': 'class_timetable_upload', 'createdAt': ...}` is passed with no actual image bytes. Calls `previewRoutineImport` → `routineImport` Cloud Function which does not exist (`functions/src/` absent, all contract tests skipped). Falls back silently to a dummy `ClassRoutineBlock` on CF failure (`class_setup_screen.dart:873–886`). |

### Event system

| Event | Status | Citation |
|---|---|---|
| `routine_template_created` | ✅ IMPLEMENTED | `event_names.dart:62` — `EventNames.routineTemplateCreated = 'routine_template_created'`. `setRoutineTemplates('classes', templates)` at `class_setup_screen.dart:799` calls `_emitTemplateCreated()` per template (`routine_provider.dart:1409–1411`), emitting `{templateId, routineType: 'classes'}`. |

### Gaps and follow-up ownership

| Gap ID | Description | Severity | Owner |
|---|---|---|---|
| G1 | Photo OCR mode: no image picker — the "Upload" button passes hardcoded metadata with no real image. | HIGH | **Task 12.5** |
| G2 | `routineImport` Cloud Function does not exist. OCR import degrades silently to a dummy block with no user-visible error. | HIGH | **Task 12.5** |
| G3 | Review sheet (`_showClassReview`) parses edited text as `subject: room` — professor is lost during text-field edits in the review step (`class_setup_screen.dart:956–964`). Only `subject` and `room` are written back; `professor` is discarded on any edit. | LOW | Task 6.3 follow-up |

### Analyzer result

```
flutter analyze lib/views/routine/class_setup_screen.dart
No issues found! (ran in 1.7s)
```

No production Dart or JS file was modified by this audit pass.

### Risk if shipped as-is

**LOW (manual mode) / HIGH (Photo OCR mode).** Manual class entry is complete — all five fields save correctly, per-day isolation works, the routine tab shows real times at the right weekday, and `routine_template_created` fires per class. The Photo OCR "Upload" button must not be surfaced to users until Task 12.5 deploys the `routineImport` CF and wires a real image picker.

---

## Task 6.4 — Eating Setup Screen (manual mode)

> Audit date: 2026-05-05
> Auditor: re-verify pass (read-only — no Dart or JS files modified)

### Files inspected

- `lib/views/routine/eating_setup_screen.dart`
- `lib/providers/routine_provider.dart` (lines 118–136, 417–440, 664–665, 954–970, 1329–1334, 1401–1431)
- `lib/views/routine/routine_tab.dart` (lines 261–277)
- `lib/views/routine/timeline_section.dart` (lines 74–96)
- `lib/core/constants/event_names.dart` (line 62)
- `functions/test/routineImport.contract.test.js` (dependency probe)

### Files changed

- `docs/phase_1_5_audit.md` — this section appended only. No production Dart or JS file modified.

### Firestore paths affected

- `/users/{uid}/routine/current.templates.eating` — written by `routine_repository.dart:63–75` via `saveRoutine({..., 'templates': {..., 'eating': templates}})`.
- `/users/{uid}/routine/current.mealPlans` — written via `state.toMap()` → `'mealPlans'` (7-element `DayMealPlan` list); loaded back by `RoutineState.fromMap():728`.

### Requirements verification

| Requirement | Status | Citation |
|---|---|---|
| Manual mode saves **meal name** | ✅ | `eating_setup_screen.dart:751` — `'mealType': item.mealName`. Stored separately from food. |
| Manual mode saves **food** | ✅ | `eating_setup_screen.dart:752` — `'notes': item.foodName`; also `'title': item.foodName.isNotEmpty ? item.foodName : item.mealName` at `:746` |
| Manual mode saves **time** | ✅ | `eating_setup_screen.dart:748–749` — `'startTime': format24h(item.start)`, `'endTime': format24h(item.start + item.duration)` in HH:MM 24h |
| Manual mode saves **repeat** | ✅ | `eating_setup_screen.dart:750` — `'repeatRule': 'mess_menu_weekday:${d + 1}'` per weekday (1=Mon…7=Sun); matched by `_repeatRuleMatchesDate` at `routine_provider.dart:135` |

**Schema note on `title`:** The `title` field at `:746` is `foodName if non-empty else mealName`. If a user enters no food name, `title` becomes the meal name and `notes` is empty — the template loses a clean food/meal separation. The `mealType` key preserves the meal name regardless. Low severity; no data loss, just a schema convention inconsistency.

### Routine tab eating display

The routine tab reads eating from `mealPlanForDay(dayIdx).all` (`routine_tab.dart:262`), which returns `MealItem` objects. `MealItem.time` is set to `item.displayStartTime` (12h AM/PM format). `tlNormalizeTime()` (`timeline_section.dart:85`) converts it to HH:MM before display. The block title is derived from `tlMealLabel(normalizedTime)` (Breakfast / Lunch / Snack / Dinner by hour range at `:74`).

**Gap:** The routine tab uses `tlMealLabel()` to re-derive the meal label from the time rather than using `item.mealName` directly. A custom meal the user named "Pre-workout" at 3:00 PM would appear in the timeline as "Snack" (hour 15 → `< 17` → Snack). The user-set meal name is not displayed.

### Per-day eating logic

| Mechanism | Status | Evidence |
|---|---|---|
| Setup: different meals per day (Mon–Sun) | ✅ | `weeklyRoutines[0..6]` — independent block list per day; 7-droplet selector at `eating_setup_screen.dart:1053–1078` |
| Save: weekday encoded per block | ✅ | `eating_setup_screen.dart:750` — `'repeatRule': 'mess_menu_weekday:${d + 1}'` |
| Routine tab shows correct day's meals | ✅ | `mealPlanForDay(dayIdx)` at `routine_tab.dart:262` — keyed by `(date.weekday - 1)` |
| Survives app restart | ✅ | `setMealPlan()` → `_saveDebounced()` → `state.toMap()` includes `mealPlans` → Firestore; `RoutineState.fromMap():728` loads it back |

### Dependency status

| Dependency | Status | Evidence |
|---|---|---|
| **Task 12.6** — Mess Photo OCR | ⚠️ UI STUB ONLY | `eating_setup_screen.dart:819–833` — "Upload Mess Menu Photo" button calls `_loadGeneratedMeals(..., source: 'mess_menu_photo', imageMetadata: {...})`. No camera/file picker opened — hardcoded metadata only. Calls `previewRoutineImport` → `routineImport` CF which does not exist. Falls back to `_mealBlocksFromText('Mess menu photo import')` producing dummy blocks. |
| **Task 12.7** — AI Goal eating | ❌ NOT PRESENT | No AI Goal entry-point exists anywhere in `eating_setup_screen.dart` or any referenced file. `_showImportOptions()` only exposes text-AI and mess-photo. Task 12.7 is not even stubbed. |

### Event system

| Event | Status | Citation |
|---|---|---|
| `routine_template_created` | ✅ IMPLEMENTED | `event_names.dart:62` — `EventNames.routineTemplateCreated`. `setRoutineTemplates('eating', templates)` at `eating_setup_screen.dart:768` calls `_emitTemplateCreated()` per template (`routine_provider.dart:1422`), emitting `{templateId, routineType: 'eating'}`. |

### Gaps and follow-up ownership

| Gap ID | Description | Severity | Owner |
|---|---|---|---|
| G1 | `title` template field merges food and meal name — if no food is entered, `title` = meal name and `notes` = empty string, losing clean schema separation. | LOW | Task 6.4 follow-up |
| G2 | Routine tab shows `tlMealLabel()` (Breakfast/Lunch/Snack/Dinner by hour) instead of the user's actual meal name. A custom "Pre-workout" block at 3 PM appears as "Snack". | LOW | Task 6.4 follow-up |
| G3 | Task 12.6 — Mess Photo: no image picker wired; `routineImport` CF missing; silent fallback to dummy blocks. | HIGH | **Task 12.6** |
| G4 | Task 12.7 — AI Goal eating import: not present at all, not even a stub. | HIGH | **Task 12.7** |

### Analyzer result

```
flutter analyze lib/views/routine/eating_setup_screen.dart
No issues found! (ran in 2.7s)
```

No production Dart or JS file was modified by this audit pass.

### Risk if shipped as-is

**LOW (manual mode) / HIGH (AI import modes).** Manual meal entry is functionally correct — all four required fields save, per-day isolation works, persistence survives restart, and `routine_template_created` fires per template. G1 and G2 are cosmetic/schema gaps that don't cause data loss. Task 12.6 (Mess Photo) must not be surfaced until the CF and image picker are deployed. Task 12.7 (AI Goal) has no implementation at all and must be built from scratch.

---

## Feature Spec — Task 12.6 + Task 12.7 (Build Together)

> Status: NOT BUILT — full specification below. Build 12.6 and 12.7 in the same sprint; they share the `routineImport` Cloud Function and the AI eating pipeline.

---

### Task 12.6 — Mess Menu Photo OCR

#### What it does

User taps "Upload Mess Menu Photo" in the Eating Setup screen, picks a photo of a printed/digital mess menu timetable (like a weekly college canteen board), and the app parses it into a full 7-day eating schedule automatically.

#### Client-side (Flutter)

1. **Image picker** — wire `image_picker` package on "Upload Mess Menu Photo" tap.
   - Allow camera capture or gallery selection.
   - Compress to ≤ 1 MB JPEG before upload (use `flutter_image_compress`).
   - Upload to Firebase Storage at `gs://…/users/{uid}/mess_menu/{timestamp}.jpg`.
   - Pass the Storage download URL to the Cloud Function as `imageUrl`.

2. **Loading state** — show a shimmer or progress indicator while the CF processes.

3. **Review sheet** — `_showMealReview()` already exists. After CF returns parsed blocks, pass them into the review sheet for user confirmation before committing.

4. **Accept all** — calls `_save()` → `setRoutineTemplates('eating', templates)` → materialization.

#### Cloud Function — `routineImport` (mode: `timetable_image` / `mess_menu_photo`)

```
POST (callable) routineImport
Input:
  routineType: 'eating'
  mode: 'mess_menu_photo'
  imageUrl: string          // Firebase Storage URL
  commit: false             // preview only; client commits after review

Steps:
  1. Download image from Storage URL.
  2. Call Claude Vision API (claude-sonnet-4-6) with the image.
     Prompt: "Parse this mess menu timetable. Return a JSON array of
     meal templates, one per row×column cell. Each object:
     { day: 1-7 (1=Mon), mealType, food, startTime (HH:MM), endTime (HH:MM) }"
  3. Validate returned JSON — drop malformed rows.
  4. Return { templates: [...] } to client.

Output template shape:
  templateId, title (mealType), routineType: 'eating',
  startTime, endTime, repeatRule: 'mess_menu_weekday:{day}',
  mealType, notes (food items), emoji, isActive: true
```

#### Firestore path written
`/users/{uid}/routine/current.templates.eating` — same path as manual entry. No new path needed.

#### Events
- `routine_template_created` fires per template via existing `_emitTemplateCreated()`.

#### Error handling
- CF timeout / Vision API failure → return `{ templates: [], error: 'parse_failed' }`.
- Client falls back to showing an empty review sheet with a "Try again" prompt.
- Never silently produce dummy blocks (remove existing fallback to `_mealBlocksFromText`).

---

### Task 12.7 — AI Adaptive Eating (Nutritional Gap-Fill + Missed Meal Recovery)

#### Overview

After the user has a meal routine set up, the AI monitors their daily nutritional intake against their profile targets. When a gap is found — either because a meal was missed or the day's food falls short of requirements — the AI adds a food suggestion automatically. The user cannot delete AI suggestions but can steer them via a preference chat (sweet / spicy / light / etc.).

#### Two triggers

| Trigger | Condition | AI action | Recurrence |
|---|---|---|---|
| **Meal marked done** | Running daily total still below target after completion | Add a gap-fill food suggestion for the remainder of the day | Repeats every same weekday (added as a template with `mess_menu_weekday:N`) |
| **Meal marked skipped/abandoned** | A scheduled meal task goes to `skipped` or `abandoned` state | Add a one-off make-up meal for that day | One-time only (`repeatRule: 'once'`) |

#### Nutritional baseline — from user profile

Read from `/users/{uid}/main/biometrics` + `/users/{uid}/main/lifestyle`:

| Field used | Source |
|---|---|
| `weightKg`, `heightCm`, `age` | `biometrics` |
| `goal` (lose / maintain / gain) | `lifestyle.fitnessGoal` |
| `activityLevel` | `lifestyle.activityLevel` |

Derive daily targets server-side using **Mifflin-St Jeor**:

```
BMR (male)   = 10×weight + 6.25×height − 5×age + 5
BMR (female) = 10×weight + 6.25×height − 5×age − 161
TDEE         = BMR × activityMultiplier
target_kcal  = TDEE + goalOffset   // -500 lose / 0 maintain / +300 gain
target_protein_g = weight × 1.6    // standard lean mass target
```

Cache these derived targets in `/users/{uid}/routine/nutritional_targets` on first computation. Recompute only when profile changes.

#### Nutritional estimation — AI-estimated

No external food database. Claude estimates nutritional content from food names using its training data.

```
Prompt to Claude (on each meal-done event):
"The user has eaten the following today: {foods_eaten}.
 Their daily targets are {target_kcal} kcal and {target_protein_g}g protein.
 Estimate the approximate nutrition of what they ate.
 Then suggest one small food item (under 300 kcal) that fills the remaining gap.
 Consider user preferences: {preference_tags}.
 Return JSON: { estimated_kcal, estimated_protein_g, suggestion: { name, kcal, emoji } }"
```

#### Flow — meal marked done

```
User marks eating task → completed
       ↓
Client emits task_completed event
       ↓
Cloud Function: checkNutritionalGap(uid, date)
  1. Read today's completed eating tasks from /users/{uid}/tasks
  2. Fetch nutritional_targets from Firestore
  3. Fetch today's accepted AI suggestions (if any)
  4. Call Claude with foods_eaten + targets + preferences
  5. If gap > 200 kcal OR protein gap > 10g:
       a. Write suggestion to /users/{uid}/routine/ai_suggestions/{date}_{slot}
       b. Add a non-deletable eating task for today
       c. If this gap has occurred on the same weekday for 2+ consecutive weeks:
            → add a recurring template: repeatRule: 'mess_menu_weekday:{weekday}'
  6. Emit ai_meal_suggestion_created event
```

#### Flow — meal marked skipped/abandoned

```
User marks eating task → skipped | abandoned
       ↓
Cloud Function: handleMissedMeal(uid, date, missedTaskId)
  1. Read the missed meal's food from the task
  2. Call Claude: "User missed {mealType}. Suggest a quick replacement
     under {kcal} kcal. Preferences: {preference_tags}."
  3. Write a one-time task for today (repeatRule: 'once')
  4. Write to /users/{uid}/routine/ai_suggestions/{date}_missed_{taskId}
  5. Emit ai_meal_suggestion_created
```

#### User preference steering

User can type "I want something sweet" / "spicy" / "light" / "vegetarian" etc. in a preference chat panel (new small widget below the AI suggestion card in the routine tab).

```
Preference flow:
  User types preference → saved to /users/{uid}/routine/preferences.eating_tags
  Cloud Function re-runs suggestion with new tags → updates the suggestion doc
  Client shows updated suggestion → user sees new food
  No delete option. User can keep requesting until satisfied.
```

Preference tags persist and are used in all future AI suggestions.

#### Firestore paths (new)

| Path | Content |
|---|---|
| `/users/{uid}/routine/nutritional_targets` | `{ target_kcal, target_protein_g, computed_at, bmr, tdee }` |
| `/users/{uid}/routine/ai_suggestions/{date}_{slot}` | `{ suggestion, estimated_kcal, gap_kcal, weekday, source: 'gap_fill' | 'missed_meal', status: 'pending' | 'accepted', preference_tags }` |
| `/users/{uid}/routine/preferences` | `{ eating_tags: ['vegetarian', 'no_spicy', ...] }` |

#### Events (new — add to `event_names.dart`)

| Event name | Fired when |
|---|---|
| `ai_meal_suggestion_created` | CF writes a new suggestion |
| `ai_meal_preference_updated` | User updates preference tags |
| `nutritional_target_computed` | Targets computed/recomputed from profile |

#### UI changes needed

1. **Routine tab eating block** — AI-suggested blocks show a small `✦ AI` badge. No delete icon rendered. A "Steer" button opens the preference input.

2. **Preference input** — a single-line text field + submit below the AI card. Sends preference to CF; updates `eating_tags` in Firestore; re-triggers suggestion.

3. **No delete** — AI suggestion tasks must have `deletable: false` flag. Task list and routine tab both check this flag before rendering a delete/swipe option.

#### Build order

```
1. Add nutritional_targets CF helper (derive from profile on first load)
2. Extend routineImport CF to handle 'mess_menu_photo' (Task 12.6) — shared CF
3. Add checkNutritionalGap CF (Task 12.7a — gap-fill)
4. Add handleMissedMeal CF (Task 12.7b — recovery)
5. Add preference steering endpoint to CF
6. Client: wire image picker for 12.6
7. Client: render AI badge + Steer button on AI suggestion blocks
8. Client: preference input widget
9. Add new events to event_names.dart + payload validator
```

#### Dependencies before building

- Task 12.6 and 12.7 share the same `routineImport` CF — build CF first, then client.
- User profile (`biometrics`, `lifestyle.fitnessGoal`, `activityLevel`) must be populated from onboarding (Task 1.2) before nutritional targets can be derived.
- `deletable: false` flag needs to be added to `TaskModel` (new field, safe default `true`).

#### Risk

- Claude nutritional estimates will be approximate. Frame suggestions as "around X kcal" not precise values.
- Recurring gap-fill templates (same weekday) may conflict with user-set templates. Dedup by checking if a template with the same `repeatRule` + similar `startTime` already exists before inserting.
- Preference steering without a delete option can frustrate users if the AI keeps suggesting foods they dislike. Consider a "Dismiss for today" option (hides suggestion for the day without deleting the template).

---

## Task 6.2 Re-verification — Supplement Manual Setup

**Date:** 2026-05-05
**Scope:** Audit only — no production Dart or JS files modified.

---

### Files inspected

| File | Purpose |
|---|---|
| `lib/views/routine/supplement_setup_screen.dart` | Full UI and save flow |
| `lib/providers/routine_provider.dart` (lines 1401–1443) | `setRoutineTemplates` + event emission |
| `lib/repositories/routine_repository.dart` (lines 50–76) | Firestore write |
| `lib/core/constants/event_names.dart` (line 62) | `routine_template_created` constant |

---

### Requirement 1 — Manual mode saves name, dosage, time, repeat

**Result: ✅ CONFIRMED**

All four fields are captured in `_SupplementCard` and persisted end-to-end:

| Field | UI widget | `_SupplementItem` field | `toTemplate()` key | Location |
|---|---|---|---|---|
| Name | `TextFormField` (label: Name) | `title` | `'title': title.trim()` | `supplement_setup_screen.dart:379–384, 42` |
| Dosage | `TextFormField` (label: Dosage) | `dosage` | `'dosage': dosage.trim()` | `supplement_setup_screen.dart:394–400, 47` |
| Time | `TextFormField` (label: Time) | `time` | `'startTime': time` | `supplement_setup_screen.dart:404–411, 44` |
| Repeat | `DropdownButtonFormField` (label: Repeat days) | `repeatRule` | `'repeatRule': repeatRule` | `supplement_setup_screen.dart:424–438, 46` |

Save path:
1. `_save()` at `supplement_setup_screen.dart:234–246` collects `_items` → calls `setRoutineTemplates('supplements', templates, ...)`.
2. `routine_provider.dart:1401–1424` normalises and writes state, then calls `_repo.saveRoutineTemplates(...)`.
3. `routine_repository.dart:50–76` merges into the existing Firestore document and writes `templates.supplements: [...]`.

Firestore path written: `/users/{uid}/routine/current` → field `templates.supplements` (an array of template maps, each containing `title`, `dosage`, `startTime`, `repeatRule`, `dosage`, `notes`, `reminderEnabled`, `isActive`, `createdAt`, `updatedAt`, `templateId`, `routineType`).

---

### Requirement 2 — Text AI mode (Task 12.4) status

**Result: ⚠️ UI STUB ONLY — pending Cloud Function**

The Text AI tab is scaffolded in the supplement screen:

- `SegmentedButton` with `'Manual'` / `'Text AI'` segments: `supplement_setup_screen.dart:284–294`
- Text field + sparkle icon button visible when `_mode == 'Text AI'`: `supplement_setup_screen.dart:295–317`
- `_generateFromText()` at lines 108–131 calls `previewRoutineImport(routineType: 'supplements', mode: 'text_ai', sourceText: ...)` via `routine_repository.dart:81–105`
- That method calls the Firebase Function `routineImport` which **does not exist** (`functions/src/` directory absent; all contract tests skipped — confirmed in prior audit entries at lines 1491–1496 of this document)
- On CF failure the try/catch at lines 119–121 leaves `generated` empty; the fallback `_supplementsFromText()` (lines 133–148) locally parses comma/pipe/dash-delimited lines into stub items — **no crash, but no AI**

Note on task numbering: the existing audit table (line 1495 of this document) maps **Task 12.6 = AI wiring for supplements** (not Task 12.4). The prompt for this re-verification references Task 12.4 by name, which the audit table maps to **AI wiring for eating**. Regardless of the task number used, the conclusion is identical: the supplement Text AI path is a UI stub and must not be presented to users as functional until the `routineImport` Cloud Function is deployed. The owning task per the audit table is **Task 12.6**.

---

### Event — `routine_template_created`

**Result: ✅ IMPLEMENTED AND FIRES CORRECTLY**

- Constant defined: `EventNames.routineTemplateCreated = 'routine_template_created'` at `event_names.dart:62`.
- `setRoutineTemplates` iterates over all saved templates and calls `_emitTemplateCreated(template, fallbackRoutineType: 'supplements')` at `routine_provider.dart:1421–1422`.
- `_emitTemplateCreated` (lines 1427–1443) calls `_eventService.emit(eventName: EventNames.routineTemplateCreated, source: 'routine_setup', payload: {templateId, routineType: 'supplements'})`.
- Therefore one `routine_template_created` event fires per supplement template on every save. The event system exists; the event name is registered and used.

---

### Firestore paths affected

| Path | Written by | Content |
|---|---|---|
| `/users/{uid}/routine/current` → `templates.supplements` | `routine_repository.dart:saveRoutineTemplates` | Array of supplement template maps (`title`, `dosage`, `startTime`, `repeatRule`, `notes`, `reminderEnabled`, `isActive`, `createdAt`, `updatedAt`, `templateId`, `routineType`) |
| `/users/{uid}/routine/current` → `imports.supplements` | Same (when `importMetadata != null`) | Import metadata map (`mode`, `sourceText`, `createdAt`) — only written for Text AI saves |
| `/users/{uid}/routine/current` → `supplementsSetUp` | Same | `true` when at least one template exists |

---

### Dependency check — Task 12.4 / Task 12.6

| Dependency | Status | Impact |
|---|---|---|
| `routineImport` Cloud Function | ❌ Not deployed | Text AI mode degrades silently to local stub; manual mode unaffected |
| Task 12.6 (AI wiring for supplements) | ❌ Not done | Must be completed before surfacing the Text AI tab to users |

No missing dependency blocks the manual mode. Manual mode is production-ready.

---

### Analyzer result

```
flutter analyze lib/views/routine/supplement_setup_screen.dart
No issues found! (ran in 1.7s)
```

---

### Summary

| Check | Result |
|---|---|
| Manual mode saves name | ✅ `supplement_setup_screen.dart:42` |
| Manual mode saves dosage | ✅ `supplement_setup_screen.dart:47` |
| Manual mode saves time | ✅ `supplement_setup_screen.dart:44` |
| Manual mode saves repeat | ✅ `supplement_setup_screen.dart:46` |
| Firestore path confirmed | ✅ `/users/{uid}/routine/current.templates.supplements` |
| `routine_template_created` event | ✅ Fires per template via `routine_provider.dart:1422` |
| Text AI mode (Task 12.4 / Task 12.6) | ⚠️ UI stub — CF not deployed |
| Production files modified | ✅ None |

**Overall risk: LOW (manual mode) / HIGH (Text AI mode).** Manual supplement entry is complete and correct. The Text AI tab must remain hidden from users until Task 12.6 deploys the `routineImport` CF.

---

## Re-Verification: Task 7.1 — Habit Service & Models

> Date: 2026-05-05
> Status: Re-verified against codebase. No changes made.

### Files inspected

- `lib/services/habit_service.dart`
- `lib/models/habit_model.dart`
- `lib/models/habit_log_model.dart`
- `test/services/habit_service_contract_test.dart`

### What is implemented

| Requirement | Status | Citation |
|---|---|---|
| Methods exist (create/update/pause/resume/archive/delete, logGood, logSlip, deleteLog) | ✅ | `lib/services/habit_service.dart` — All required methods are present and correctly typed. |
| Canonical log path is `/habit_logs/{logId}` (flat) | ✅ | `lib/services/habit_service.dart:40-41` — `_habitLogsRef` uses `/users/{uid}/habit_logs`. Also defined in `lib/models/habit_log_model.dart:4`. Legacy nested path is maintained for backwards compatibility. |
| Validation rejects blank name, invalid target, negative log | ✅ | `lib/services/habit_service.dart:366-388` (`_validateHabit` checks names and targets). `logGood` (line 217) and `logSlip` (line 267) check `quantity <= 0` throwing `InvalidAmountError`. |

### Events

| Event | Status | Citation |
|---|---|---|
| `habit_created` | ✅ | `lib/services/habit_service.dart:138` |
| `habit_updated` | ✅ | `lib/services/habit_service.dart:160` |
| `habit_paused` | ✅ | `lib/services/habit_service.dart:184` |
| `habit_resumed` | ✅ | `lib/services/habit_service.dart:208` |
| `habit_archived` | ✅ | `lib/services/habit_service.dart:234` |
| `habit_deleted` | ✅ | `lib/services/habit_service.dart:257` |
| `good_habit_logged` | ✅ | `lib/services/habit_service.dart:239` |
| `bad_habit_slip_logged` | ✅ | `lib/services/habit_service.dart:289` |
| `habit_log_deleted` | ✅ | `lib/services/habit_service.dart:340` |
| `slip_streak_detected` | ❌ | **Not emitted by HabitService.** The constant exists in `event_names.dart`, but the frequency check (3+ slips in 30 min) is delegated to the `StreakService` or AI Coach post-commit as per Service Contracts §3, not the core CRUD service. |

### Dependencies

- **StreakService (Phase 2)**: The `slip_streak_detected` event relies on the streak evaluation system tracking slip frequencies. Its absence from `HabitService` is correct per system docs, but it is currently missing entirely and represents a follow-up gap.

### Tests
- `flutter analyze` passes.

### Risk if shipped as-is
**LOW.** The habit service and models implement all CRUD, logging, and state machine transitions correctly. Validation and events are all wired up correctly. `slip_streak_detected` not being emitted here is expected due to the event orchestration architecture.

---

## Re-Verification (2): Task 7.1 — Habit Service & Models

> Date: 2026-05-05 (second pass)
> Status: Re-verified against codebase. No production files modified.
> Previous audit: Line 2270 of this document (dated 2026-05-05, first pass).
> Reason for re-pass: Correct stale line-number citations from the first pass and confirm all requirements still hold.

### Files inspected

| File | Lines | Notes |
|---|---|---|
| `lib/services/habit_service.dart` | 583 | All CRUD, logging, guards, validation |
| `lib/models/habit_model.dart` | 292 | Model, enums, fromFirestore/toFirestore/copyWith |
| `lib/models/habit_log_model.dart` | 83 | Append-only log model |
| `test/services/habit_service_contract_test.dart` | 435 | 30+ assertions across 15 test cases |
| `lib/core/constants/event_names.dart` | 104 | Cross-reference for event constants |
| `lib/core/errors/app_errors.dart` | 156 | Cross-reference for typed errors |
| `lib/services/event_service.dart` | 200 | Cross-reference for emit/validate pipeline |

### Requirement 1 — Method existence

| Method | Status | Location |
|---|---|---|
| `createHabit` | ✅ | `habit_service.dart:152` |
| `updateHabit` | ✅ | `habit_service.dart:176` |
| `pauseHabit` | ✅ | `habit_service.dart:205` |
| `resumeHabit` | ✅ | `habit_service.dart:235` |
| `archiveHabit` | ✅ | `habit_service.dart:264` |
| `deleteHabit` | ✅ | `habit_service.dart:297` |
| `logGood` | ✅ | `habit_service.dart:323` |
| `logSlip` | ✅ | `habit_service.dart:386` |
| `deleteLog` | ✅ | `habit_service.dart:447` |

**Result: ✅ All 9 methods present.**

### Requirement 2 — Canonical log path is `/habit_logs/{logId}` (flat)

| Evidence | Citation |
|---|---|
| `_habitLogsRef` getter | `habit_service.dart:44-45` → `users/{uid}/habit_logs` |
| Service header comment | `habit_service.dart:7` — "Canonical log : users/{uid}/habit_logs/{logId}" |
| Model header comment | `habit_log_model.dart:4` — "Canonical path : users/{uid}/habit_logs/{logId}" |
| Canonical write in `logGood` | `habit_service.dart:358` — `batch.set(_habitLogsRef.doc(logId), ...)` |
| Canonical write in `logSlip` | `habit_service.dart:420` — `batch.set(_habitLogsRef.doc(logId), ...)` |
| Legacy dual-write in `logGood` | `habit_service.dart:359` — `batch.set(_itemsRef(habitId, occurred).doc(logId), ...)` |
| Legacy dual-write in `logSlip` | `habit_service.dart:421` — `batch.set(_itemsRef(habitId, occurred).doc(logId), ...)` |
| `deleteLog` reads canonical | `habit_service.dart:459` — `_habitLogsRef.doc(logId)` |
| `deleteLog` deletes both copies | `habit_service.dart:473-474` |
| Test confirms canonical path | `habit_service_contract_test.dart:70-71` — `logsColl()` = `users/{uid}/habit_logs` |

**Result: ✅ Canonical path is flat `/habit_logs/{logId}`. Legacy nested path dual-written for backward compatibility.**

### Requirement 3 — Validation rejects blank name, invalid target, negative log

| Validation rule | Status | Service citation | Test citation |
|---|---|---|---|
| Blank name → `InvalidHabitInputError` | ✅ | `habit_service.dart:515-517` | `test:113-118` |
| Good habit: `dailyGoal == null \|\| dailyGoal <= 0` → reject | ✅ | `habit_service.dart:519-525` | `test:120-125` |
| Bad habit: `reduceToTarget` with `target == null \|\| target < 0` → reject | ✅ | `habit_service.dart:529-534` | `test:127-134` |
| Bad habit: any `target < 0` → reject | ✅ | `habit_service.dart:535-537` | (covered by above) |
| Bad habit: `baselinePerDay < 0` → reject | ✅ | `habit_service.dart:538-540` | (no dedicated test) |
| Bad habit: `costPerUnit < 0` → reject | ✅ | `habit_service.dart:541-543` | (no dedicated test) |
| `logGood` with `quantity <= 0` → `InvalidAmountError` | ✅ | `habit_service.dart:336` | `test:338-344` |
| `logSlip` with `quantity <= 0` → `InvalidAmountError` | ✅ | `habit_service.dart:402` | (no dedicated test; guard runs before log creation) |
| `deleteHabit` without `confirmDestructive` → reject | ✅ | `habit_service.dart:301-305` | `test:202-211` |
| `deleteLog` without `confirmDestructive` → reject | ✅ | `habit_service.dart:452-456` | `test:401-409` |

**Result: ✅ All validation requirements met.**

**Minor test gaps:**
- `baselinePerDay < 0` and `costPerUnit < 0` validation paths have no dedicated test cases. Runtime behavior is correct (code inspection confirms throws), but a future test task could add coverage.
- `logSlip` with `quantity <= 0` has no dedicated test (the `logGood` negative-amount test exists at `test:338-344`).

### Requirement 4 — Lifecycle events emit per action

| Event | Constant location | Emit location | Test verification |
|---|---|---|---|
| `habit_created` | `event_names.dart:40` | `habit_service.dart:165-170` | `test:108-110` ✅ |
| `habit_updated` | `event_names.dart:41` | `habit_service.dart:195-200` | `test:160-162` ✅ |
| `habit_paused` | `event_names.dart:42` | `habit_service.dart:223-230` | `test:188` ✅ |
| `habit_resumed` | `event_names.dart:43` | `habit_service.dart:252-259` | `test:189` ✅ |
| `habit_archived` | `event_names.dart:47` | `habit_service.dart:280-291` | `test:199` ✅ |
| `habit_deleted` | `event_names.dart:48` | `habit_service.dart:311-316` | `test:226` ✅ |
| `good_habit_logged` | `event_names.dart:44` | `habit_service.dart:361-380` | `test:308-311` ✅ |
| `bad_habit_slip_logged` | `event_names.dart:45` | `habit_service.dart:423-441` | `test:374-377` ✅ |
| `habit_log_deleted` | `event_names.dart:46` | `habit_service.dart:476-486` | `test:431` ✅ |
| `slip_streak_detected` | `event_names.dart:49` | **Not emitted by HabitService** | **Not tested here** |

**Result: ✅ 9/10 events implemented and tested in HabitService.**

`slip_streak_detected` is correctly **not** emitted by `HabitService`. Per ServiceContracts §3, the 3+-slips-in-30-min frequency analysis belongs to the StreakService or AI Coach post-commit pipeline — not the core CRUD service. The constant exists at `event_names.dart:49` and is available for downstream consumers.

### Firestore paths verified

| Path | Purpose | Confirmed by |
|---|---|---|
| `/users/{uid}/habits/{habitId}` | Habit document (mutable) | `habit_service.dart:41-42`, `habit_model.dart:4` |
| `/users/{uid}/habit_logs/{logId}` | Canonical log (append-only) | `habit_service.dart:44-45`, `habit_log_model.dart:4` |
| `/users/{uid}/habits/{habitId}/logs/{YYYY-MM-DD}/items/{logId}` | Legacy nested copy | `habit_service.dart:47-55` |
| `/users/{uid}/events/{eventId}` | Event audit log | `event_service.dart:88` (via `emit()`) |
| `/users/{uid}/events_recent/{eventId}` | Recent event cache | `event_service.dart:99` (via `emit()`) |

### Stale citations in previous audit section (line 2270)

The previous audit (first pass, same date) listed line numbers from an earlier file snapshot. All citations were off by 150–180 lines due to file growth. The table below maps previous → actual:

| Item | Previous citation | Actual (current) | Code changed? |
|---|---|---|---|
| `_validateHabit` | lines 366-388 | lines 514-543 | No |
| `logGood` quantity check | line 217 | line 336 | No |
| `logSlip` quantity check | line 267 | line 402 | No |
| `habit_created` emit | line 138 | line 165 | No |
| `habit_updated` emit | line 160 | line 195 | No |
| `habit_paused` emit | line 184 | line 223 | No |
| `habit_resumed` emit | line 208 | line 252 | No |
| `habit_archived` emit | line 234 | line 280 | No |
| `habit_deleted` emit | line 257 | line 311 | No |
| `good_habit_logged` emit | line 239 | line 361 | No |
| `bad_habit_slip_logged` emit | line 289 | line 423 | No |
| `habit_log_deleted` emit | line 340 | line 476 | No |

**No behavioral changes detected.** The file grew from ~400 to 583 lines (additions were reads/queries at lines 67-148), shifting all downstream line numbers.

### Test summary

| Test file | Total tests | Passing | Coverage notes |
|---|---|---|---|
| `habit_service_contract_test.dart` | 15 | ✅ All pass | Covers: create, update, pause, resume, archive, delete, logGood, logSlip, deleteLog, reads, guards, validation, events |

Minor coverage gaps (non-blocking):
- No dedicated test for `logSlip` with negative count
- No dedicated test for `baselinePerDay < 0` or `costPerUnit < 0` validation
- No test for `logGood`/`logSlip` on an archived habit (only paused is tested)

### Dependencies

- **StreakService**: `slip_streak_detected` emission is delegated here. Not currently emitted anywhere in the codebase — represents a follow-up gap (not owned by Task 7.1).
- **No other missing dependencies** for Task 7.1.

### Risk if shipped as-is

**LOW.** All 9 CRUD/logging methods exist, are validated, and emit the correct lifecycle events. The canonical flat log path is confirmed. Test coverage is solid (15 tests, all passing). The only architectural gap (`slip_streak_detected`) is correctly delegated and not a HabitService concern.

---

## Re-Verification: Task 7.2 — Habit editor / detail / quick-log

> Date: 2026-05-05
> Status: Re-verified against codebase. No production files modified.

### Files inspected

| File | Lines | Purpose |
|---|---|---|
| `lib/views/tabs/home_tab.dart` | 1212 | Home tab with habit pills + `_openHabitLogSheet` |
| `lib/views/tabs/tracker_tab.dart` | 1482 | Tracker tab with habit cards + `_undoLatest` |
| `lib/views/habits/log_habit_sheet.dart` | 438 | Log sheet for good/bad habit logging |
| `lib/views/habits/habit_editor_screen.dart` | 589 | Create/edit habit form |
| `lib/views/habits/habit_detail_screen.dart` | 528 | Detail view with variant routing + lifecycle actions |
| `lib/views/habits/variants/tracker_variant_base.dart` | 477 | Shared variant base (status, history, insight, log) |
| `lib/views/habits/variants/smoking_tracker_view.dart` | 25 | Smoking variant stub |
| `lib/views/habits/variants/screen_time_tracker_view.dart` | — | Screen time variant stub |
| `lib/views/habits/variants/mindful_eating_tracker_view.dart` | — | Mindful eating variant stub |
| `lib/views/habits/variants/procrastination_tracker_view.dart` | — | Procrastination variant stub |
| `lib/views/habits/variants/hydration_tracker_view.dart` | — | Hydration variant stub |
| `lib/views/habits/variants/meditation_tracker_view.dart` | — | Meditation variant stub |
| `lib/views/habits/variants/money_saving_tracker_view.dart` | — | Money saving variant stub |
| `lib/views/habits/variants/reading_tracker_view.dart` | — | Reading variant stub |
| `lib/views/habits/variants/exercise_tracker_view.dart` | 25 | Exercise variant stub |
| `lib/views/habits/variants/routine_completion_tracker_view.dart` | 26 | Routine completion variant stub |
| `lib/services/habit_service.dart` | 583 | Service layer (cross-reference) |
| `lib/core/constants/event_names.dart` | 104 | Event constants (cross-reference) |
| `lib/core/providers.dart` | — | `habitServiceProvider`, `habitsProvider`, `todayHabitLogsProvider` |

### Files changed

- `docs/phase_1_5_audit.md` — this section appended only. No production Dart or JS file modified.

---

### Requirement 1 — Home pills render

**Status: ✅ CONFIRMED**

| Check | Citation | Notes |
|---|---|---|
| `habitsProvider` watched | `home_tab.dart:479` | StreamProvider wrapping `habitService.habits()` — returns active habits |
| `todayHabitLogsProvider` watched | `home_tab.dart:481` | StreamProvider wrapping `habitService.watchHabitLogsForDate(today)` |
| Habits render as `_HabitPill` | `home_tab.dart:543-549` | Each habit gets a pill with name, emoji, completion state, and slip count |
| Completed pills show ✅ | `home_tab.dart:865-866` | `completedToday ? '✅' : (hasSlip ? '!' : habit.emoji)` |
| Tap opens log sheet | `home_tab.dart:548` | `onTap: () => _openHabitLogSheet(h)` |
| `_openHabitLogSheet` opens `LogHabitSheet` | `home_tab.dart:558-564` | `showModalBottomSheet(builder: (_) => LogHabitSheet(habit: habit))` |
| Loading state | `home_tab.dart:498-512` | `isLoading ? CircularProgressIndicator : content` |
| Error state | `home_tab.dart:514-524` | Inline text: "Unable to load habit check-ins." |
| Empty state | `home_tab.dart:525-533` | "No habits yet." placeholder |

**Home pills render correctly with loading, error, and empty states.**

---

### Requirement 2 — Log sheet renders

**Status: ✅ CONFIRMED**

| Check | Citation | Notes |
|---|---|---|
| Sheet class | `log_habit_sheet.dart:8-15` | `LogHabitSheet` — `ConsumerStatefulWidget`, optional `habit` param |
| Habit picker (no pre-selected habit) | `log_habit_sheet.dart:126-190` | Shows scrollable list of all active habits via `habitsProvider` |
| Good habit form | `log_habit_sheet.dart:246-275` | Amount field + unit field |
| Bad habit form | `log_habit_sheet.dart:276-318` | Count field + trigger field + compassionate message |
| Note field | `log_habit_sheet.dart:320-324` | Optional note for both kinds |
| Submit calls `logGood` or `logSlip` | `log_habit_sheet.dart:70-88` | `habitService.logGood(...)` for good, `habitService.logSlip(...)` for bad |
| Amount validation | `log_habit_sheet.dart:60-63` | Rejects non-positive values |
| Loading state | `log_habit_sheet.dart:327` | Button shows "Logging..." while `_isLogging` |
| Error feedback | `log_habit_sheet.dart:91-92` | SnackBar on failure |

**The log sheet is fully functional for both good and bad habits.**

---

### Requirement 3 — Editor renders (create + edit)

**Status: ✅ CONFIRMED**

| Check | Citation | Notes |
|---|---|---|
| Create mode | `habit_editor_screen.dart:39` | `_isEditing = widget.habitId != null` — false for new habits |
| Edit mode | `habit_editor_screen.dart:76-114` | `_loadHabit()` fetches existing habit from service |
| Kind selector | `habit_editor_screen.dart:304-307` | `SegmentedButton` for Build/Break |
| Category dropdown | `habit_editor_screen.dart:309-326` | 14 categories including all tracker types |
| Name field | `habit_editor_screen.dart:328-332` | `TextField` with `_nameController` |
| Target/unit fields | `habit_editor_screen.dart:358-383` | Conditional on kind |
| Bad habit goal type | `habit_editor_screen.dart:341-357` | Dropdown for eliminate/reduce/awareness |
| Schedule days | `habit_editor_screen.dart:389-411` | 7 `FilterChip` widgets for weekdays |
| Money value | `habit_editor_screen.dart:417-424` | Optional per-unit cost |
| Reminders | `habit_editor_screen.dart:434-457` | Toggle + time input; writes to `scheduled_notifications` |
| Save creates or updates | `habit_editor_screen.dart:186-190` | `createHabit(habit)` for new, `updateHabit(habit)` for existing |
| Reminder intent written | `habit_editor_screen.dart:204-245` | Writes to `/users/{uid}/scheduled_notifications/habit_reminder_{id}` |
| Client-side validation | `habit_editor_screen.dart:119-150` | Blank name, invalid target, negative cost, bad time format |
| Error handling | `habit_editor_screen.dart:195-198` | Catches `AppError` and generic exceptions |
| Loading/error states | `habit_editor_screen.dart:292-295` | Loading spinner while fetching; error state with retry |
| Navigate on save | `habit_editor_screen.dart:194` | `context.go('/habits/${habit.id}')` |

**Editor is fully functional for both create and edit modes.**

---

### Requirement 4 — Detail screen renders

**Status: ✅ CONFIRMED**

| Check | Citation | Notes |
|---|---|---|
| Detail loads from Firestore stream | `habit_detail_screen.dart:46-52` | `StreamBuilder` on `habits/{habitId}` document |
| Header: name + kind + trackerType | `habit_detail_screen.dart:110-125` | Emoji/icon + name + "good • water" subtitle |
| State chip | `habit_detail_screen.dart:129` | Shows active/paused/archived with colour coding |
| Streak shortcut card | `habit_detail_screen.dart:134` | Links to `/streaks/{habitId}` |
| Variant view embedded | `habit_detail_screen.dart:136` | `_variantFor(habit)` — dispatches to 10 variant views |
| Target info card | `habit_detail_screen.dart:138-150` | Unit, daily target or goal type, money value |
| Schedule info card | `habit_detail_screen.dart:151-168` | Days, reminders, accountability |
| Lifecycle info card | `habit_detail_screen.dart:169-179` | Created, updated, paused, archived dates |
| Pause/Resume button | `habit_detail_screen.dart:426-448` | Calls `service.pauseHabit()` or `service.resumeHabit()` |
| Archive button + confirmation | `habit_detail_screen.dart:452-494` | Dialog confirmation → `service.archiveHabit()` |
| Edit button in AppBar | `habit_detail_screen.dart:37-41` | Routes to `/habits/$habitId/edit` |
| Loading state | `habit_detail_screen.dart:54-59` | `CircularProgressIndicator` |
| Error state | `habit_detail_screen.dart:60-66` | `_DetailError` with message |

**Detail screen renders all required information and exposes lifecycle actions.**

---

### Requirement 5 — Undo latest works

**Status: ✅ CONFIRMED**

| Check | Citation | Notes |
|---|---|---|
| `_undoLatest` method | `tracker_tab.dart:248-271` | Async method accepting habit + latest log |
| Calls `deleteLog` with `confirmDestructive: true` | `tracker_tab.dart:250-254` | `ref.read(habitServiceProvider).deleteLog(habit.id, log.logId, confirmDestructive: true)` |
| Latest log computed | `tracker_tab.dart:228-237` | `_latestLogsByHabit()` finds the most recent log per habit by `occurredAt` |
| Undo null-guarded | `tracker_tab.dart:137-139, 180-182` | `onUndoLatest: latestLog == null ? null : () => _undoLatest(...)` — button disabled when no log exists |
| Available on good habits | `tracker_tab.dart:137-139` | Wired into `_GoodHabitCard.onUndoLatest` |
| Available on bad habits | `tracker_tab.dart:180-182` | Wired into `_BadHabitCard.onUndoLatest` |
| Success feedback | `tracker_tab.dart:255-258` | SnackBar: "Latest habit log removed." |
| Error handling | `tracker_tab.dart:260-270` | SnackBar with error message |
| Service-level guard | `habit_service.dart:452-456` | `confirmDestructive: false` throws — prevents accidental deletion |
| Deletes both canonical + legacy | `habit_service.dart:473-474` | `batch.delete(canonicalRef)` + `batch.delete(_itemsRef(...))` |
| Emits `habit_log_deleted` event | `habit_service.dart:476-486` | Event includes `habitId`, `logId`, `logType`, `occurredAt` |

**Undo latest is correctly implemented end-to-end: UI → service → Firestore delete + event.**

---

### Requirement 6 — 10 tracker variants exist and route

**Status: ✅ ALL 10 FILES EXIST — ⚠️ ALL ARE STUBS**

#### Variant file inventory

| # | Variant | File | Lines | Task |
|---|---|---|---|---|
| 1 | Smoking | `smoking_tracker_view.dart` | 25 | Task 7.4 |
| 2 | Screen Time | `screen_time_tracker_view.dart` | ~25 | Task 7.5 |
| 3 | Mindful Eating | `mindful_eating_tracker_view.dart` | ~25 | Task 7.6 |
| 4 | Procrastination | `procrastination_tracker_view.dart` | ~25 | Task 7.7 |
| 5 | Hydration | `hydration_tracker_view.dart` | ~25 | Task 7.8 |
| 6 | Meditation | `meditation_tracker_view.dart` | ~25 | Task 7.9 |
| 7 | Money Saving | `money_saving_tracker_view.dart` | ~25 | Task 7.10 |
| 8 | Reading | `reading_tracker_view.dart` | ~25 | Task 7.11 |
| 9 | Exercise | `exercise_tracker_view.dart` | 25 | Task 7.12 |
| 10 | Routine Completion | `routine_completion_tracker_view.dart` | 26 | Task 7.13 |

#### Variant routing in `_variantFor()` (`habit_detail_screen.dart:190-220`)

| `trackerType` string | Routed to | Status |
|---|---|---|
| `'smoking'` | `SmokingTrackerView` | ✅ |
| `'screen_time'` | `ScreenTimeTrackerView` | ✅ |
| `'junk_food'` / `'mindful_eating'` | `MindfulEatingTrackerView` | ✅ |
| `'procrastination'` | `ProcrastinationTrackerView` | ✅ |
| `'water'` / `'hydration'` | `HydrationTrackerView` | ✅ |
| `'meditation'` | `MeditationTrackerView` | ✅ |
| `'money_saving'` | `MoneySavingTrackerView` | ✅ |
| `'reading'` | `ReadingTrackerView` | ✅ |
| `'exercise'` / `'steps'` | `ExerciseTrackerView` | ✅ |
| `'routine_completion'` | `RoutineCompletionTrackerView` | ✅ |
| Default (unknown type) | Bad→Procrastination, Good→Exercise | ✅ Fallback exists |

All 10 imports are present at `habit_detail_screen.dart:9-18`. Routing is exhaustive with a sensible fallback.

#### Stub nature confirmed

Every variant file (except `routine_completion_tracker_view.dart`) is a thin `StatelessWidget` that returns `TrackerVariantView(...)` from `tracker_variant_base.dart` with only these customizations: `title`, `statusLabel`, `emptyLabel`, `insightCopy` (placeholder text), `icon`, and `accent`. None implement the per-variant features specified in their respective tasks:

| Task | Required feature | Current state |
|---|---|---|
| 7.4 (Smoking) | Trigger picker, money-saved card, health milestones, recovery alarms | ❌ Stub only — placeholder insight text |
| 7.5 (Screen Time) | UsageStats import, per-app caps, unlock heuristic | ❌ Stub only |
| 7.6 (Mindful Eating) | ED-safe swap, mood slider, no counts/goals/streaks | ❌ Stub only — still shows counts and streaks |
| 7.7 (Procrastination) | Auto-detect via task overdue, planned-vs-actual | ❌ Stub only |
| 7.8 (Hydration) | Volume quick-add, glass animation, daily timeline | ❌ Stub only |
| 7.9 (Meditation) | Built-in timer, session history, breathing exercise | ❌ Stub only |
| 7.10 (Money Saving) | Cross-habit aggregation, savings pot, weekly goal | ❌ Stub only |
| 7.11 (Reading) | Page tracker, reading time, book/chapter log | ❌ Stub only |
| 7.12 (Exercise) | HealthKit/Google Fit import, volume chart, recovery | ❌ Stub only |
| 7.13 (Routine Completion) | `dailySummaries` data mode, per-routine breakdown | ⚠️ Partially done — uses `VariantDataMode.dailySummaries` but no breakdown |

**The `TrackerVariantView` base** (`tracker_variant_base.dart:14-223`) does provide real functionality:
- Status card with streak count (reads `/users/{uid}/streaks/{habitId}`)
- 7-day history bar chart (reads `/users/{uid}/habit_logs` for habit, or `/dailySummaries` for routine completion)
- AI insight placeholder card
- Log/Log Slip button (calls `habitServiceProvider.logGood()` or `logSlip()`)

**⚠️ IMPORTANT: `tracker_variant_base.dart:40-65` makes direct Firestore calls from a widget** — `FirebaseFirestore.instance.collection('users').doc(uid).collection('habit_logs')` — rather than going through `habitServiceProvider`. This violates GEMINI.md §3 (no direct Firestore from UI widgets). The violation exists in the base, so it affects all 10 variants.

---

### Events

| Event | Constant | UI trigger | Service emitter | Status |
|---|---|---|---|---|
| `good_habit_logged` | `event_names.dart:44` | `LogHabitSheet._submit()` → `logGood()` | `habit_service.dart:361-380` | ✅ |
| `bad_habit_slip_logged` | `event_names.dart:45` | `LogHabitSheet._submit()` → `logSlip()` | `habit_service.dart:423-441` | ✅ |
| `habit_log_deleted` | `event_names.dart:46` | `TrackerTab._undoLatest()` → `deleteLog()` | `habit_service.dart:476-486` | ✅ |
| `habit_created` | `event_names.dart:40` | `HabitEditorScreen._save()` → `createHabit()` | `habit_service.dart:165-170` | ✅ |
| `habit_updated` | `event_names.dart:41` | `HabitEditorScreen._save()` → `updateHabit()` | `habit_service.dart:195-200` | ✅ |
| `habit_paused` | `event_names.dart:42` | `HabitDetailScreen._LifecycleActions` → `pauseHabit()` | `habit_service.dart:223-230` | ✅ |
| `habit_resumed` | `event_names.dart:43` | `HabitDetailScreen._LifecycleActions` → `resumeHabit()` | `habit_service.dart:252-259` | ✅ |
| `habit_archived` | `event_names.dart:47` | `HabitDetailScreen._LifecycleActions` → `archiveHabit()` | `habit_service.dart:280-291` | ✅ |

**All 8 required events are wired end-to-end from UI → Service → Firestore.**

---

### Firestore paths

| Path | Read by | Written by | Status |
|---|---|---|---|
| `/users/{uid}/habits/{habitId}` | `habitsProvider` (via `watchHabits`), `HabitDetailScreen` (direct stream), `HabitEditorScreen._loadHabit()` | `createHabit()`, `updateHabit()`, `pauseHabit()`, `resumeHabit()`, `archiveHabit()`, `deleteHabit()` | ✅ |
| `/users/{uid}/habit_logs/{logId}` | `todayHabitLogsProvider` (via `watchHabitLogsForDate`), `TrackerVariantView` (direct query) | `logGood()`, `logSlip()`, `deleteLog()` | ✅ |
| `/users/{uid}/habits/{habitId}/logs/{date}/items/{logId}` | Not read by any UI | Dual-written by `logGood()`, `logSlip()`, deleted by `deleteLog()` | ✅ (legacy) |
| `/users/{uid}/scheduled_notifications/{notifId}` | Not read in these files | `HabitEditorScreen._writeReminderIntent()` | ✅ |
| `/users/{uid}/streaks/{habitId}` | `TrackerVariantView` (direct stream), `_StreakShortcutCard` (link only) | Not written by these files | ✅ |

---

### Dependency status — Tasks 7.3–7.13

| Task | Title | Status | Evidence |
|---|---|---|---|
| 7.3 | Tracker home with AI insight surface | ❌ NOT STARTED | `tracker_tab.dart` uses a simple good/bad list layout; no mission ring, no filter chips, no AI insight card. Task 7.3 per TODO is "Not started". |
| 7.4 | Smoking tracker variant | ❌ STUB ONLY | `smoking_tracker_view.dart` (25 lines) delegates to `TrackerVariantView` with placeholder text. No trigger picker, money-saved, health milestones, or recovery alarms. |
| 7.5 | Screen time tracker variant | ❌ STUB ONLY | `screen_time_tracker_view.dart` (~25 lines) delegates to `TrackerVariantView`. Note: `TrackerTab` already has a `_ScreenTimeSection` (lines 920-1002) with Android UsageStats import + permission flow + top-apps — but this is on the tracker home, not the detail variant. |
| 7.6 | Junk food / Mindful eating swap | ❌ STUB ONLY | `mindful_eating_tracker_view.dart` delegates to `TrackerVariantView`. No ED-safe mode, no mood slider, still shows counts/goals/streaks — violates the "no counts, no goals, no streaks" requirement for ED-flagged users. |
| 7.7 | Procrastination tracker | ❌ STUB ONLY | `procrastination_tracker_view.dart` delegates to `TrackerVariantView`. No auto-detect, no planned-vs-actual. |
| 7.8 | Hydration tracker | ❌ STUB ONLY | `hydration_tracker_view.dart` delegates to `TrackerVariantView`. No quick-add glasses, no daily timeline. |
| 7.9 | Meditation tracker + timer | ❌ STUB ONLY | `meditation_tracker_view.dart` delegates to `TrackerVariantView`. No timer, no breathing exercise. |
| 7.10 | Money saving aggregator | ❌ STUB ONLY | `money_saving_tracker_view.dart` delegates to `TrackerVariantView`. No cross-habit aggregation. |
| 7.11 | Reading tracker | ❌ STUB ONLY | `reading_tracker_view.dart` delegates to `TrackerVariantView`. No page tracker, no book log. |
| 7.12 | Exercise / running tracker | ❌ STUB ONLY | `exercise_tracker_view.dart` delegates to `TrackerVariantView`. No HealthKit/Google Fit import. |
| 7.13 | Routine completion meta-tracker | ⚠️ PARTIAL | `routine_completion_tracker_view.dart` uses `VariantDataMode.dailySummaries` — reads from `/dailySummaries` instead of `/habit_logs`. But no per-routine breakdown exists. |

**All 11 dependency tasks are either not started or stub-only.** The current stubs render safely (no crashes) but provide no per-variant functionality.

---

### Architecture observation — Direct Firestore in `TrackerVariantView`

`tracker_variant_base.dart:40-65` constructs three Firestore streams directly in the widget's `build()` method:

```dart
final logsStream = FirebaseFirestore.instance
    .collection('users').doc(uid).collection('habit_logs')
    .where('habitId', isEqualTo: habit.id)
    .where('occurredAt', isGreaterThanOrEqualTo: ...)
    .snapshots();
final streakStream = FirebaseFirestore.instance
    .collection('users').doc(uid).collection('streaks')
    .doc(habit.id).snapshots();
final summariesStream = FirebaseFirestore.instance
    .collection('users').doc(uid).collection('dailySummaries')
    .orderBy('date', descending: true).limit(7).snapshots();
```

This pattern:
1. Bypasses the service layer (`habitServiceProvider`) for habit logs
2. Bypasses any streak provider for streaks
3. Creates new Firestore stream subscriptions on every widget rebuild
4. Violates GEMINI.md §3 (no direct Firestore from UI widgets)

**Recommendation:** When implementing Tasks 7.4–7.13, refactor `TrackerVariantView` to use Riverpod providers instead of inline `StreamBuilder` + direct Firestore. This is not a Task 7.2 fix — it is a prerequisite for the variant tasks.

---

### Gaps and follow-ups

| # | Gap | Severity | Owning task |
|---|---|---|---|
| G1 | `TrackerVariantView` makes direct Firestore calls from the widget instead of using Riverpod providers — violates GEMINI.md §3. All 10 variants inherit this violation. | MEDIUM | Task 7.3 or 7.4 (first variant to be built should refactor the base) |
| G2 | All 10 tracker variants are thin stubs (~25 lines each) that delegate to the generic `TrackerVariantView`. None implement their task-specific features. | HIGH | Tasks 7.4–7.13 individually |
| G3 | Task 7.3 (tracker home layout) is not started. The current `TrackerTab` uses a simple good/bad sliver list — no mission ring, filter chips, or AI insight card. | MEDIUM | Task 7.3 |
| G4 | Mindful eating variant shows counts, goals, and streaks — violating the eating-disorder safety requirement (no counts/goals/streaks when `eatingDisorderHistory=true`). | HIGH | Task 7.6 |
| G5 | `HabitEditorScreen._writeReminderIntent()` writes directly to Firestore (`habit_editor_screen.dart:209-244`) rather than through a service. This is a minor GEMINI.md §3 deviation but is consistent with the existing notification pattern used elsewhere. | LOW | No current owner |
| G6 | `HabitDetailScreen` reads the habit document via a direct `StreamBuilder` on Firestore (`habit_detail_screen.dart:46-52`) rather than using `habitsProvider` or a dedicated provider. Same pattern as G1. | LOW | Task 7.3 follow-up |
| G7 | No test file exists for any of the five UI files inspected (no widget tests for `HomeTab` habit pills, `TrackerTab`, `LogHabitSheet`, `HabitEditorScreen`, or `HabitDetailScreen`). | LOW | Future test task |

### Summary

| Requirement | Status |
|---|---|
| Home pills render | ✅ Confirmed — `home_tab.dart:534-551` |
| Log sheet renders | ✅ Confirmed — `log_habit_sheet.dart:8-346` |
| Editor renders (create + edit) | ✅ Confirmed — `habit_editor_screen.dart:12-468` |
| Detail screen renders | ✅ Confirmed — `habit_detail_screen.dart:20-528` |
| Undo latest works | ✅ Confirmed — `tracker_tab.dart:248-254` calls `deleteLog(confirmDestructive: true)` |
| 10 tracker variant files exist | ✅ Confirmed — all 10 in `lib/views/habits/variants/` |
| 10 tracker variants route correctly | ✅ Confirmed — `_variantFor()` at `habit_detail_screen.dart:190-220` |
| 10 tracker variants have per-variant features | ❌ All stubs — Tasks 7.4–7.13 not started |
| All 8 required events wired | ✅ Confirmed |

**Risk if shipped as-is: LOW for Task 7.2 core scope.** The five UI surfaces (home pills, log sheet, editor, detail, undo) are fully functional and correctly wired to the service layer with proper event emission. The 10 tracker variants render safely via the shared base but are all stubs. **MEDIUM overall** when accounting for the eating-disorder safety gap (G4) and the GEMINI.md §3 violations (G1, G6) that should be resolved before building Tasks 7.4–7.13.

---

## Task 8.1 — Streak Engine Re-Verification (2026-05-07)

Scope: audit-only re-verification. No production Dart or JS files were modified.

### Files inspected

- `lib/services/streak_service.dart`
- `lib/models/streak_model.dart`
- `test/services/streak_service_contract_test.dart`
- Supporting reads for event/dependency verification: `lib/core/constants/event_names.dart`, `lib/services/event_service.dart`, `lib/services/event_payload_validator.dart`, `lib/services/routine_service.dart`, `lib/models/habit_model.dart`

### Requirements

| Requirement | Status | Evidence |
|---|---|---|
| Good habit streaks compute | PASS | `streak_service.dart:95-115` reads good logs from `/habit_logs`; `streak_service.dart:177-180` evaluates `dailyGoal`; `streak_service.dart:280-307` rolls a habit into `/streaks`; contract test `streak_service_contract_test.dart:187-201` confirms increment/state/lastHitDate. |
| Bad habit clean streaks compute | PASS | `streak_service.dart:117-136` counts only `logType == 'slip'`; `streak_service.dart:182-191` supports eliminate/reduceToTarget/awarenessOnly; contract tests cover eliminate, reduceToTarget, and awarenessOnly at `streak_service_contract_test.dart:411-495`. |
| Routine completion streaks compute | PASS | `streak_service.dart:382-415` groups same-day tasks by `parentRoutine`; `streak_service.dart:422-437` requires all non-excluded tasks completed; `streak_service.dart:439-515` writes routine streak docs using `routine_<routineKey>`; tests at `streak_service_contract_test.dart:594-664` cover extend, break, and valid skipped tasks. |
| Milestones are 3, 7, 14, 30, 60, 90, 180, 365 | PASS | Constant is exactly `kStreakMilestones = [3, 7, 14, 30, 60, 90, 180, 365]` at `streak_service.dart:34-35`; milestone event checks are at `streak_service.dart:328-340` and `streak_service.dart:481-494`; contract test iterates the same list at `streak_service_contract_test.dart:348-387`. |
| Forgiving mode | PASS | Enum/default parsing exists at `streak_model.dart:25-45`; user mode is read from `/users/{uid}.accountabilityMode` at `streak_service.dart:196-204`; forgiving mode spends one ISO-week skip at `streak_service.dart:541-556`; tests cover first and second miss at `streak_service_contract_test.dart:518-563`. |
| Strict mode | PASS | `AccountabilityMode.strict` is the default at `streak_model.dart:35-44` and `_resolveUserMode()` fallback at `streak_service.dart:196-204`; missed targets break at `streak_service.dart:558-565`; strict test is at `streak_service_contract_test.dart:500-516`. |
| Ruthless mode | PASS | Bad-habit slips override the bad-habit goal type at `streak_service.dart:170-175`; ruthless test confirms a slip breaks even under target at `streak_service_contract_test.dart:565-589`. |
| Per-habit override + 8+ day reset (Task 8.3) | GAP | `HabitModel` has a persisted `accountability` field (`habit_model.dart:92`, `habit_model.dart:154`, `habit_model.dart:217`), but `StreakService` only passes the resolved user mode into each habit rollup (`streak_service.dart:220-234`) and never resolves a per-habit override. Ghost/comeback code passes `gapDays` into pause/resume events (`routine_service.dart:167-179`, `streak_service.dart:572-608`, `streak_service.dart:621-660`), but there is no 8+ day reset branch; comeback thresholds are `[30, 14, 7, 3]` at `routine_service.dart:910-912`. Owned by Task 8.3. |

### Firestore paths

| Path | Status | Evidence |
|---|---|---|
| `/users/{uid}/streaks/{streakId}` | PASS | Service ref at `streak_service.dart:87-88`; model documents habit/routine streak ids at `streak_model.dart:3-10`; habit writes at `streak_service.dart:286-307`; routine writes at `streak_service.dart:445-458`; reads at `streak_service.dart:673-692`. |
| `/users/{uid}/habit_logs/{logId}` | PASS | Canonical collection ref at `streak_service.dart:83-85`; good-log query at `streak_service.dart:100-105`; slip query at `streak_service.dart:122-127`; test helper writes the same path at `streak_service_contract_test.dart:124-146`. |
| `/users/{uid}/dailySummaries/{date}` | INDIRECT PASS | `StreakService` does not write this path directly. `RoutineService._closeDate()` calls `runDayCloseRollup()` at `routine_service.dart:347-349`, then writes `dailySummaries/{date}` at `routine_service.dart:331-356` with streak metrics in the summary payload at `routine_service.dart:368-383`. |

### Events

Existing event system is present: `EventService.emit()` writes `/users/{uid}/events` and `/users/{uid}/events_recent` at `event_service.dart:37-42` and `event_service.dart:43-123`; streak event names are canonical constants at `event_names.dart:52-57`; payload validation accepts the five streak names at `event_payload_validator.dart:138-142`.

| Event | Status | Evidence |
|---|---|---|
| `streak_extended` | PASS | Constant at `event_names.dart:53`; emitted for habit streaks at `streak_service.dart:314-326` and routine streaks at `streak_service.dart:466-479`; contract test at `streak_service_contract_test.dart:302-315`. |
| `streak_broken` | PASS | Constant at `event_names.dart:54`; emitted for habit streaks at `streak_service.dart:341-353` and routine streaks at `streak_service.dart:495-508`; tests at `streak_service_contract_test.dart:317-336` and `streak_service_contract_test.dart:625-646`. |
| `streak_milestone_reached` | PASS | Constant at `event_names.dart:55`; emitted for habit milestones at `streak_service.dart:328-340` and routine milestones at `streak_service.dart:481-494`; test at `streak_service_contract_test.dart:348-387`. |
| `streak_paused` | PASS | Constant at `event_names.dart:56`; emitted by `pauseAllActiveStreaks()` at `streak_service.dart:596-608`; test at `streak_service_contract_test.dart:669-700`. |
| `streak_resumed` | PASS | Constant at `event_names.dart:57`; emitted by `resumeAllPausedStreaks()` at `streak_service.dart:647-660`; test at `streak_service_contract_test.dart:724-749`. |

### Gaps and follow-ups

| Gap | Severity | Owner |
|---|---|---|
| Per-habit accountability override is not applied by `StreakService`; only user-level `accountabilityMode` is used. | MEDIUM | Task 8.3 |
| 8+ day reset behavior is not implemented; current ghost/comeback handling pauses and resumes streaks using `gapDays` only as event/prompt metadata. | MEDIUM | Task 8.3 |

### Verification

- Every Task 8.1 requirement above is cited to file:line.
- No production Dart or JS file was modified.
- This audit doc gained a new Task 8.1 section; existing sections were not rewritten.
- `flutter analyze` passed with no issues on 2026-05-07.

---

## Task 8.2 — Streak Detail UI Re-Verification (2026-05-07)

Scope: audit-only re-verification. No production Dart or JS files were modified.

### Files inspected

- `lib/views/streaks/streak_detail_screen.dart`
- `lib/views/streaks/streak_heatmap.dart`
- `lib/views/tabs/home_tab.dart`
- `lib/views/tabs/tracker_tab.dart`
- Supporting route/provider reads: `lib/core/router/app_router.dart`, `lib/core/providers.dart`, `lib/services/streak_service.dart`, `lib/services/event_service.dart`, `lib/core/constants/event_names.dart`

### Requirements

| Requirement | Status | Evidence |
|---|---|---|
| Home streak card opens detail | PASS | Home reads all streaks via `allStreaksProvider` at `home_tab.dart:568-571`, selects the active/best featured streak at `home_tab.dart:573-588`, wires the "Longest Streak" card tap to `context.push('/streaks/${featuredStreak?.habitId ?? '_empty'}')` at `home_tab.dart:605-620`, and `_streakCard()` invokes the supplied tap handler at `home_tab.dart:676-691`. The route exists at `app_router.dart:119-123`, and the detail screen handles `_empty` with an empty state at `streak_detail_screen.dart:886-941`. |
| Tracker habit detail links to streak detail | PASS | Tracker builds good habit cards with `onStreakDetails: () => _showStreakDetails(habit)` at `tracker_tab.dart:218-232` and bad habit cards with the same callback at `tracker_tab.dart:267-284`; `_showStreakDetails()` routes to `/streaks/${habit.id}` at `tracker_tab.dart:498-500`; good/bad card action buttons expose the "Streak details" icon at `tracker_tab.dart:1056-1061` and `tracker_tab.dart:1240-1243`; the route target is `StreakDetailScreen` at `app_router.dart:119-123`. |
| Heatmap data matches logs | PASS | Habit streak detail fetches logs for the streak habit id using `habitLogsForRangeProvider((habitId: streak.habitId, days: 90))` at `streak_detail_screen.dart:76-78` and passes those logs to `StreakHeatmap` at `streak_detail_screen.dart:101-114`. The provider queries `/habit_logs` filtered by `habitId` and trailing `occurredAt` at `providers.dart:220-237`. `StreakHeatmap` groups logs by calendar day at `streak_heatmap.dart:149-158`, filters good habits to `logType == 'good'` and bad habits to `logType == 'slip'` at `streak_heatmap.dart:151-153`, sums `quantity ?? 1` at `streak_heatmap.dart:154-155`, and computes intensity from the habit goal/bad-habit goal type at `streak_heatmap.dart:160-180`. Routine streak heatmap uses `DaySummary.perRoutinePct` from daily summaries at `streak_detail_screen.dart:155-190` and `streak_heatmap.dart:205-227`. |

### Firestore paths

| Path | Status | Evidence |
|---|---|---|
| `/users/{uid}/streaks/{streakId}` | PASS | Home and Tracker consume `allStreaksProvider` (`home_tab.dart:568-571`, `tracker_tab.dart:78-81`), detail consumes `streakByIdProvider(streakId)` (`streak_detail_screen.dart:29-52`), providers delegate to `StreakService.watchAllStreaks()` / `watchStreak()` at `providers.dart:205-216`, and the service reads the streak collection/doc at `streak_service.dart:673-684`. |
| `/users/{uid}/habit_logs/{logId}` | PASS | Tracker range provider reads `habit_logs` directly at `tracker_tab.dart:35-57`; detail heatmap provider reads the habit-specific trailing range from `habit_logs` at `providers.dart:220-237`; `StreakHeatmap` consumes those logs at `streak_heatmap.dart:149-180`. |
| `/users/{uid}/dailySummaries/{date}` | PASS | Tracker weekly trend reads `recentDailySummariesProvider(7)` at `tracker_tab.dart:82-83` and renders summaries at `tracker_tab.dart:2208-2238`; routine streak detail reads `recentDailySummariesProvider(60)` at `streak_detail_screen.dart:155-190`; providers query `/dailySummaries` at `providers.dart:241-255` and today's summary doc at `providers.dart:264-280`. |

### Events

Read-only re-verification emits nothing. The event system exists (`EventService.emit()` at `event_service.dart:43-123`, canonical streak constants at `event_names.dart:52-57`), but the inspected streak detail and heatmap paths do not emit streak events. The only event emission found in the inspected UI files is unrelated suggestion dismissal in `tracker_tab.dart:502-526`.

### Gaps and follow-ups

| Gap | Severity | Owner |
|---|---|---|
| No Task 8.2 requirement gap found. | NONE | N/A |

### Verification

- Every Task 8.2 requirement above is cited to file:line.
- No production Dart or JS file was modified.
- This audit doc gained a new Task 8.2 section; existing sections were not rewritten.
- `flutter analyze` passed with no issues on 2026-05-07.
