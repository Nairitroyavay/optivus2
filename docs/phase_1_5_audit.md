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

