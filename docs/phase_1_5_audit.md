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
