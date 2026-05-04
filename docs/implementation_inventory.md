# Optivus Implementation Inventory

Generated for Task 0.1. Refreshed 2026-05-04 to reflect codebase state after reviewing every file under `lib/` plus `functions/index.js` and `functions/jobs/*.js`.

This inventory is descriptive only. It does not authorize runtime changes. The current app is partially built and should be extended, not rewritten.

## Summary

- The app has a working Flutter shell, Firebase initialization, routing, auth screens, onboarding pages (0–10), six-tab home shell, routine timeline, basic task/habit/streak/routine services, notification service, coach/AI files, and Cloud Functions jobs.
- Several new screens have been added since the initial inventory: streak detail + heatmap, habit editor, habit detail, tracker variant stubs for 10 habit types, supplement setup (with Text AI mode), comeback modal, and a routine settings hub screen.
- The app is not production-complete. Most core surfaces exist, but many features are partial because service contracts, Firestore schemas, events, backend jobs, AI behavior, notifications, and verification are incomplete.
- Firestore remains the V1 source of truth. Do not migrate to Postgres for V1.
- AI provider calls must stay behind Cloud Functions/backend-controlled paths. Flutter must not expose AI secrets.

## File Sizes — Current Snapshot (2026-05-04)

Files ≥ 1 KB are listed below with byte count. Files > 1 KB are flagged for per-task verification before making large edits.

| File | Bytes | Verification note |
|---|---|---|
| `lib/views/routine/routine_tab.dart` | 61,807 | ⚠️ per-task verification |
| `lib/views/routine/skin_care_setup_screen.dart` | 58,859 | ⚠️ per-task verification |
| `lib/views/routine/class_setup_screen.dart` | 54,012 | ⚠️ per-task verification |
| `lib/views/routine/eating_setup_screen.dart` | 53,201 | ⚠️ per-task verification |
| `lib/providers/routine_provider.dart` | 50,537 | ⚠️ per-task verification |
| `lib/views/tabs/tracker_tab.dart` | 49,629 | ⚠️ per-task verification |
| `lib/views/routine/timeline_section.dart` | 48,010 | ⚠️ per-task verification |
| `lib/core/liquid_ui/liquid_ui.dart` | 44,433 | ⚠️ per-task verification |
| `lib/views/tabs/home_tab.dart` | 43,368 | ⚠️ per-task verification |
| `lib/views/tabs/coach_tab.dart` | 41,858 | ⚠️ per-task verification |
| `lib/views/routine/fixed_schedule_setup_screen.dart` | 41,505 | ⚠️ per-task verification |
| `lib/views/tabs/profile_tab.dart` | 36,733 | ⚠️ per-task verification |
| `lib/views/screens/signup_screen.dart` | 33,922 | ⚠️ per-task verification |
| `lib/services/routine_service.dart` | 33,248 | ⚠️ per-task verification |
| `lib/views/routine/ai_routine_panel.dart` | 31,888 | ⚠️ per-task verification |
| `lib/views/streaks/streak_detail_screen.dart` | 31,283 | ⚠️ per-task verification — new since last inventory |
| `lib/views/screens/onboarding_screen.dart` | 31,143 | ⚠️ per-task verification |
| `lib/views/onboarding/onboarding_page_4.dart` | 30,475 | ⚠️ per-task verification |
| `lib/views/onboarding/onboarding_page_1.dart` | 29,262 | ⚠️ per-task verification |
| `lib/repositories/user_repository.dart` | 28,847 | ⚠️ per-task verification |
| `lib/views/onboarding/onboarding_page_9.dart` | 26,626 | ⚠️ per-task verification |
| `lib/views/onboarding/onboarding_page_6.dart` | 26,341 | ⚠️ per-task verification |
| `lib/views/screens/login_screen.dart` | 26,245 | ⚠️ per-task verification |
| `lib/views/onboarding/onboarding_page_2.dart` | 25,860 | ⚠️ per-task verification |
| `lib/views/onboarding/onboarding_page_5.dart` | 25,672 | ⚠️ per-task verification |
| `lib/services/rule_engine_service.dart` | 25,672 | ⚠️ per-task verification — new since last inventory |
| `lib/services/state_aggregator_service.dart` | 25,548 | ⚠️ per-task verification |
| `lib/services/streak_service.dart` | 24,148 | ⚠️ per-task verification |
| `lib/services/task_service.dart` | 22,554 | ⚠️ per-task verification |
| `lib/views/habits/habit_editor_screen.dart` | 20,834 | ⚠️ per-task verification — new since last inventory |
| `lib/widgets/liquid_category_card.dart` | 20,181 | ⚠️ per-task verification |
| `lib/services/notification_service.dart` | 19,961 | ⚠️ per-task verification |
| `lib/views/onboarding/onboarding_page_3.dart` | 19,017 | ⚠️ per-task verification |
| `lib/views/routine/add_task_sheet.dart` | 18,513 | ⚠️ per-task verification |
| `lib/services/habit_service.dart` | 18,194 | ⚠️ per-task verification |
| `lib/core/event_orchestrator.dart` | 17,903 | ⚠️ per-task verification |
| `lib/views/onboarding/onboarding_page_7.dart` | 17,784 | ⚠️ per-task verification |
| `lib/views/habits/habit_detail_screen.dart` | 17,038 | ⚠️ per-task verification — new since last inventory |
| `lib/views/tabs/goals_tab.dart` | 16,073 | ⚠️ per-task verification |
| `lib/views/routine/supplement_setup_screen.dart` | 15,749 | ⚠️ per-task verification — new since last inventory |
| `lib/views/routine/timeline_zoom_views.dart` | 15,565 | ⚠️ per-task verification |
| `lib/views/routine/glass_filter_dropdown.dart` | 15,489 | ⚠️ per-task verification |
| `lib/views/habits/variants/tracker_variant_base.dart` | 14,703 | ⚠️ per-task verification — new since last inventory |
| `lib/widgets/app_button.dart` | 14,269 | ⚠️ per-task verification |
| `lib/models/user_model.dart` | 14,242 | ⚠️ per-task verification |
| `lib/views/habits/log_habit_sheet.dart` | 13,979 | ⚠️ per-task verification |
| `lib/services/firestore_service.dart` | 13,670 | ⚠️ per-task verification |
| `lib/widgets/liquid_glass_tabbar.dart` | 13,519 | ⚠️ per-task verification |
| `lib/providers/onboarding_provider.dart` | 12,833 | ⚠️ per-task verification |
| `lib/models/task_model.dart` | 12,737 | ⚠️ per-task verification |
| `lib/services/coach_service.dart` | 12,441 | ⚠️ per-task verification |
| `lib/widgets/liquid_glass_card.dart` | 11,872 | ⚠️ per-task verification |
| `lib/core/providers.dart` | 11,120 | ⚠️ per-task verification |
| `lib/views/streaks/streak_heatmap.dart` | 10,877 | ⚠️ per-task verification — new since last inventory |
| `lib/views/tabs/routine_settings_screen.dart` | 10,835 | ⚠️ per-task verification — new since last inventory |
| `lib/models/goal_model.dart` | 10,373 | ⚠️ per-task verification |
| `lib/views/onboarding/onboarding_page_10.dart` | 9,412 | new since last inventory |
| `lib/models/habit_model.dart` | 9,493 | — |
| `lib/views/onboarding/onboarding_page_8.dart` | 8,311 | — |
| `lib/views/screens/welcome_screen.dart` | 8,507 | — |
| `lib/models/context_snapshot.dart` | 7,706 | — |
| `lib/views/comeback/comeback_modal.dart` | 6,874 | new since last inventory |
| `lib/repositories/routine_repository.dart` | 6,722 | — |
| `lib/services/event_payload_validator.dart` | 6,654 | new since last inventory |
| `lib/models/streak_model.dart` | 6,399 | — |
| `lib/core/constants/event_names.dart` | 6,362 | — |
| `lib/models/day_summary_model.dart` | 6,111 | — |
| `lib/services/event_service.dart` | 5,922 | — |
| `lib/services/screen_time_importer.dart` | 5,637 | — |
| `lib/services/remote_config_service.dart` | 5,408 | — |
| `lib/views/screens/loading_screen.dart` | 4,878 | — |
| `lib/repositories/goal_repository.dart` | 4,780 | — |
| `lib/views/screens/home_screen.dart` | 4,631 | — |
| `lib/services/screen_time_bridge.dart` | 4,589 | — |
| `lib/services/auth_service.dart` | 4,479 | — |
| `lib/models/identity_profile_model.dart` | 4,399 | — |
| `lib/models/coach_rule.dart` | 4,392 | — |
| `lib/main.dart` | 3,901 | — |
| `lib/models/event_model.dart` | 3,837 | — |
| `lib/services/gemini_service.dart` | 3,729 | — |
| `lib/views/onboarding/onboarding_page_0.dart` | 3,625 | — |
| `lib/core/providers/bootstrap_provider.dart` | 3,339 | — |
| `lib/core/router/app_router.dart` | 3,260 | — |
| `lib/models/scheduled_notification_model.dart` | 3,100 | — |
| `lib/models/habit_log_model.dart` | 2,692 | — |
| `lib/providers/goal_provider.dart` | 1,002 | — |
| `lib/views/habits/variants/routine_completion_tracker_view.dart` | 878 | stub — new |
| `lib/views/habits/variants/procrastination_tracker_view.dart` | 827 | stub — new |
| `lib/views/habits/variants/mindful_eating_tracker_view.dart` | 821 | stub — new |
| `lib/views/habits/variants/meditation_tracker_view.dart` | 803 | stub — new |
| `lib/views/habits/variants/money_saving_tracker_view.dart` | 800 | stub — new |
| `lib/views/habits/variants/hydration_tracker_view.dart` | 798 | stub — new |
| `lib/views/habits/variants/screen_time_tracker_view.dart` | 797 | stub — new |
| `lib/views/habits/variants/smoking_tracker_view.dart` | 795 | stub — new |
| `lib/views/habits/variants/exercise_tracker_view.dart` | 791 | stub — new |
| `lib/views/habits/variants/reading_tracker_view.dart` | 782 | stub — new |
| `lib/providers/identity_provider.dart` | 768 | — |

**Cloud Functions files (non-node_modules):**

| File | Bytes | Verification note |
|---|---|---|
| `functions/jobs/dayClose.js` | 20,510 | ⚠️ per-task verification |
| `functions/jobs/utils.js` | 8,338 | — |
| `functions/jobs/inactivityCheck.js` | 7,462 | — |
| `functions/index.js` | 5,717 | — |
| `functions/jobs/morningBrief.js` | 2,840 | — |
| `functions/jobs/middayPulse.js` | 2,381 | — |

## App Startup and Routing

### `lib/main.dart`

- Initializes Flutter bindings, Firebase, App Check (play_integrity in release, debug token in emulator), Crashlytics, Remote Config, Firestore offline persistence, local notifications, and day-close startup behavior.
- Uses Riverpod with `ProviderScope`.
- Defines `OptivusApp`.
- Status: implemented/partial. Startup exists, but production release still needs full notification re-registration, migration guards, and operational kill-switch validation.

### `lib/core/router/app_router.dart`

- Defines `routerProvider` with routes for loading, welcome, login, signup, onboarding, and home.
- Uses bootstrap state to redirect based on auth and onboarding completion.
- Status: implemented/partial. Main routing exists, but many future detail/settings screens are not routed yet.

### `lib/core/providers/bootstrap_provider.dart`

- Defines `BootstrapState` and `AppBootstrapNotifier`.
- Watches Firebase auth and loads user onboarding state.
- Status: implemented/partial. Basic auth/onboarding routing exists; schema edge cases still need hardening.

## Core Providers and Orchestration

### `lib/core/providers.dart`

- Registers service providers for Remote Config, Firestore, events, tasks, habits, streaks, notifications, routine service, coach service, repositories, screen time, and read providers.
- Provides `todayTasksProvider`, `routineWindowTasksProvider`, `habitsProvider`, `allStreaksProvider`, `todayHabitLogsProvider`, `todaySummaryProvider`, `screenTimeLogProvider`.
- Status: partial. Existing providers cover core reads, but many planned screens/services need new providers.

### `lib/core/event_orchestrator.dart`

- Central local event reaction layer.
- Reacts to task, habit, streak, routine, identity, ghost/comeback, onboarding, and day events.
- Status: partial. It exists, but production event listener boundaries and backend parity are incomplete.

### `lib/core/constants/event_names.dart`

- Contains many canonical event name constants.
- Status: partial. Needs audit against Event System and Service Contracts, including routine template lifecycle, profile settings, notification missed, identity lifecycle, and weekly insights.

## Models

### Implemented model files

- `lib/models/task_model.dart`: task state, task type, alarm tier, abandon reason, subtasks, task serialization.
- `lib/models/habit_model.dart`: good/bad habit model, `HabitKind`, `BadHabitGoalType` (eliminate/reduceToTarget/awarenessOnly), state fields.
- `lib/models/habit_log_model.dart`: habit log model.
- `lib/models/streak_model.dart`: streak model, `StreakState` (active/paused/broken), `AccountabilityMode`.
- `lib/models/day_summary_model.dart`: day summary model.
- `lib/models/event_model.dart`: event envelope/model.
- `lib/models/user_model.dart`: user document model.
- `lib/models/goal_model.dart`: goal model.
- `lib/models/identity_profile_model.dart`: identity profile model.
- `lib/models/scheduled_notification_model.dart`: notification category/status/model.
- `lib/models/screen_time_log_model.dart`: screen time logs.
- `lib/models/context_snapshot.dart`: AI context snapshot.
- `lib/models/coach_rule.dart`: rule engine shapes.

### Model gaps

- Missing `SuggestionModel`.
- Missing `AiRuleLogModel`.
- Missing routine import result model.
- Missing full routine template model for fixed schedule, skin care, supplements, classes, eating, custom tasks.
- Some existing model fields do not yet cover every schema/document contract.

## State Providers

### `lib/providers/onboarding_provider.dart`

- Holds onboarding state: categories, bad habits, good habits, goals, coach style/name, accountability, schedule items, current step, completion.
- Persists onboarding state through `UserRepository`.
- Status: partial. Does not yet include full About You data or final Page 10 plan fields.

### `lib/providers/routine_provider.dart`

- Defines routine state models: fixed blocks, skin care plans, meal plans, classes, custom tasks, long-term goals.
- Loads `/users/{uid}/routine/current`.
- Materializes routine tasks for a 14-day window through `TaskService.syncRoutineTasks`.
- Status: partial. It already supports recurring fixed blocks technically, but needs production template schema, unlimited UX, future edit safety, supplement templates, and AI/import modes.

### `lib/providers/goal_provider.dart` and `lib/providers/identity_provider.dart`

- Stream goals/identity profile data from Firestore.
- Status: partial. Basic read paths exist; full identity/goal creation, editing, scoring, milestones, and archive/pause flows are incomplete.

## Repositories

### `lib/repositories/user_repository.dart`

- Saves onboarding state.
- Completes onboarding and materializes habits, goals, and fixed routine blocks.
- Writes profile and identity data.
- Status: partial. Onboarding materialization exists, but needs full About You, Page 10, strict event/schema alignment, and routine template contract hardening.

### `lib/repositories/routine_repository.dart`

- Persists `RoutineState` to `/users/{uid}/routine/current`.
- Status: partial. Simple load/save exists; full schema migration/template model is missing.

### `lib/repositories/auth_repository.dart`

- Thin wrapper around `AuthService`.
- Status: implemented/partial. Email/password wrapper exists.

### `lib/repositories/goal_repository.dart`

- Basic goal add/update/delete repository.
- Status: partial. Needs full identity/goal service contract.

## Services

### `lib/services/auth_service.dart`

- Email/password sign in, sign up, sign out.
- Creates root user doc and emits `user_signed_up`.
- Status: partial. Auth exists; provider lifecycle/schema and optional Google/Apple states need completion.

### `lib/services/event_service.dart`

- Writes events under `/users/{uid}/events` and `/users/{uid}/events_recent`.
- Includes local event bus and recent replay.
- Status: partial. Needs strict payload validation, idempotency, transaction semantics, trimming/archive, and tests.

### `lib/services/event_payload_validator.dart` *(new)*

- Validates event payloads before write.
- Status: partial. Exists at 7 KB; needs coverage of all canonical event types and integration into `EventService`.

### `lib/services/task_service.dart`

- Watches tasks for day/window.
- Creates/syncs routine tasks.
- Implements start, pause, resume, complete, abandon, skip, and subtask toggle.
- Emits task/subtask events.
- Status: partial. Strong base exists; contract names, payload validation, delete task, and UI parity need verification.

### `lib/services/habit_service.dart`

- Creates/updates/deletes habits.
- Logs good habits and bad slips.
- Writes flat and nested logs in places.
- Emits habit events.
- Status: partial. Needs pause/resume/archive, strict log schema, undo/delete log, flat canonical logs, and full tracker variants.

### `lib/services/streak_service.dart`

- Runs day-close rollup for active habits.
- Emits streak extended, milestone, broken events.
- Status: partial. Needs accountability modes, ghost pause/resume, routine streaks, bad-habit clean streaks, detailed history, and heatmaps.

### `lib/services/routine_service.dart`

- Runs day close and emits `day_closed` and `routine_day_summarized`.
- Status: partial. Needs idempotent multi-day close, routine block completion, mission ring formula, Cloud Function parity, and complete daily summaries.

### `lib/services/notification_service.dart`

- Schedules task reminders, end reminders, streak milestone, slip recovery, settings, budget reserve, suppression events.
- Writes `/scheduled_notifications` and event-like suppression docs.
- Status: partial. Needs lifecycle records for sent/tapped/dismissed/missed, notification center, settings UI, dedupe, custom alarms, and FCM dispatcher.

### `lib/services/rule_engine_service.dart` *(new — 25 KB)*

- Client-side rule engine with scored rules.
- Includes a `crisis_intervention_slips` rule (priority 1, `aiIntent=crisis_intervention_slips`) that fires at ≥3 slips today.
- Rules are defined client-side only; a server-side job is still missing.
- Status: partial. Engine and several rules exist; needs backend job, full test coverage, speak-budget enforcement, and safety route integration.

### `lib/services/state_aggregator_service.dart`

- Builds context snapshots aggregating profile, tasks, habits, goals, notifications, and safety context.
- Status: partial. Needs backend-controlled LLM calls, safety routing, speak budget, suggestion service, AI routine import endpoints, and full context.

### `lib/services/coach_service.dart` and `lib/services/gemini_service.dart`

- Coach service builds prompts/context and can persist proactive coach messages.
- Gemini service calls backend/AI helper methods.
- Status: partial. Needs backend-controlled LLM calls, safety routing, speak budget, suggestion service, AI routine import endpoints, and full context.

### Other services

- `firestore_service.dart`: general Firestore helper with user, tasks, goals, routine, coach chat, export/delete helpers; `exportUserData` and `deleteUserOwnedData` are implemented.
- `remote_config_service.dart`: remote config keys and loading.
- `global_error_handler.dart`: global error handling.
- `screen_time_bridge.dart` and `screen_time_importer.dart`: Android screen time bridge/import.
- Status: partial. Useful base; production operational controls and privacy/export lifecycle need hardening.

## UI Screens

### `lib/views/screens/*.dart`

- `welcome_screen.dart`, `login_screen.dart`, `signup_screen.dart`, `loading_screen.dart`, `onboarding_screen.dart`, `home_screen.dart`.
- Status: implemented/partial. Auth and shell exist; more detail routes/settings must be added.

### `lib/views/onboarding/*.dart`

- Pages 0–10 exist. Page 10 (`onboarding_page_10.dart`, 9 KB) is the final preview/plan-ready page showing habits, routine blocks, and notification count.
- Status: partial. User Flow calls for a stronger Page 10 AI plan ready. Current screens cover all onboarding categories.

### `lib/views/tabs/*.dart`

- Home, Routine settings, Tracker, Coach, Goals, Profile tabs exist.
- Status: partial. Main surfaces exist, but many required flows are shallow/missing.

### `lib/views/tabs/routine_settings_screen.dart` *(new — 11 KB)*

- Hub screen routing to Fixed Schedule, Skin Care, Eating, Class, and Supplement setup screens.
- Contains a Notification Settings tile (no dedicated settings screen yet).
- Status: partial. Hub navigation works; supplement and notification settings sub-screens are missing.

### `lib/views/routine/*.dart`

- Routine timeline, filter dropdown, setup screens for fixed schedule, skin care, eating, classes, Add task sheet, AI panel, supplement setup.
- `supplement_setup_screen.dart` (16 KB, new): Manual and Text AI modes. Text AI calls `routineImport` preview and shows a review dialog.
- `skin_care_setup_screen.dart`: has Manual and AI/Photo tab. AI/Photo tab supports text input and `Photo Upload with AI` button (both call `routineImport` preview with appropriate `imageMetadata`).
- `class_setup_screen.dart`: has `Upload timetable image/screenshot` button calling `routineImport` with `mode=timetable_image`.
- `eating_setup_screen.dart`: has `Generate with AI` text input and `Upload Mess Menu Photo` button (both call `routineImport` preview).
- All AI/photo modes call `routineImport` preview; a full backend callable is not yet implemented.
- Status: partial.

### `lib/views/habits/*.dart` — Habit Editor and Detail *(new)*

- `habit_editor_screen.dart` (21 KB): Full create/edit flow for good and bad habits. Supports `HabitKind`, `BadHabitGoalType`, daily target, unit, frequency goal. Calls `HabitService.createHabit` and `updateHabit`.
- `habit_detail_screen.dart` (17 KB): Detail view for a single habit. Full pause/archive/delete wiring is incomplete.
- `log_habit_sheet.dart`: Log good/bad habit quick-entry sheet.
- Status: partial. Editor and detail screens exist; pause/archive lifecycle, delete-log, and variant routing need completion.

### `lib/views/habits/variants/*.dart` *(all new)*

- `tracker_variant_base.dart` (15 KB): Base widget class for all habit-type variant views.
- Ten variant stub widgets (each ~780–880 B) for: smoking, screen time, mindful eating, procrastination, hydration, meditation, money saving, reading, exercise/running, routine completion.
- Each stub shows an AI interpretation placeholder string; real analytics wiring and AI calls are missing.
- Status: partial. UI shells exist and render; real data binding and AI interpretation are missing.

### `lib/views/streaks/*.dart` *(new)*

- `streak_detail_screen.dart` (31 KB): Detail view for a single streak. Supports both habit-scope (`/streaks/{habitId}`) and routine-scope (`routine_` prefix) streaks. Shows current count, longest count, state chip, milestones strip, accountability card, and heatmap.
- `streak_heatmap.dart` (11 KB): Calendar heatmap widget for habit logs and routine daily summaries.
- Status: partial. Screens exist and render; full routing from tracker cards, routing from home, and deep linking not yet wired.

### `lib/views/comeback/comeback_modal.dart` *(new — 7 KB)*

- Modal dialog for the comeback flow after absence.
- Shows absence detection summary and a list of suggestion rows the user can pick to restart.
- Status: partial. UI shell exists; auto-trigger from the inactivity job and `SuggestionService` integration are missing.

## Cloud Functions

### `functions/index.js`

- Contains `aiGenerate` callable (enforces App Check token).
- Exports scheduled jobs: `scheduledDayClose`, `scheduledInactivityCheck`, `scheduledMorningBrief`, `scheduledMiddayPulse`.
- Status: partial. Needs structured `routineImport` endpoint, event helpers, safety routing, usage limits, notification dispatcher, weekly summary job, and exports for new jobs.

### `functions/jobs/*.js`

- `dayClose.js` (20 KB): Runs streak rollup, writes `/dailySummaries/{date}`, prunes `events_recent`. Idempotency guard exists.
- `inactivityCheck.js` (7 KB): Detects ghost days. Comeback trigger integration incomplete.
- `morningBrief.js` (3 KB): Morning brief job.
- `middayPulse.js` (2 KB): Midday pulse job.
- `utils.js` (8 KB): Shared utilities.
- Status: partial. Needs notification dispatcher, AI planner/rule engine/safety split, export/delete, cleanup/backfill, weekly summary, emulator tests.
- Verification note: `functions/package.json` currently does not define an `npm test` script, so `cd functions && npm test` is not available yet.

## Firestore Rules and Indexes

### `firestore.rules`

- Rules exist.
- Status: partial. Must be audited against final per-user schema and server-only fields.

### `firestore.indexes.json`

- Index file exists.
- Status: partial. Must be updated for task day queries, suggestions, notifications, events, summaries, habit logs.

## Known Highest-Risk Gaps

1. Event contracts are not strict enough yet.
2. Routine template schema is not formalized.
3. AI features are too direct/ad hoc and not fully backend-controlled; `routineImport` backend callable is missing.
4. Notification lifecycle is incomplete; notification center and custom alarm screens are missing.
5. Several UI entry points exist but do not complete the full user flow (goal editor, settings screens, variant wiring).
6. Tests are missing or skeletal.
7. Feature matrix must be kept current after each phase.
8. All 10 tracker variant views are stubs; real analytics and AI interpretation wiring must be added before release.
9. Weekly summary Cloud Function and job are missing.
10. Subscription/usage cap enforcement is missing from both the UI and backend.

## Testing

### Flutter contract tests

Run with:

```
flutter test test/services/
```

All 7 service contract test files exist under `test/services/`. As of Task 0.2 all
tests are skipped (`~190 skipped, +0 passed`). They define the intended public
surface and state-machine contracts so that implementations can be verified against
them once `fake_cloud_firestore` and `firebase_auth_mocks` are added as
dev-dependencies.

| File | Service | Groups |
|---|---|---|
| `event_service_contract_test.dart` | EventService | emit, on, onAny, replayRecentEvents, dispose |
| `task_service_contract_test.dart` | TaskService | tasksFor, tasksForWindow, createTask, syncRoutineTasks, startTask, pauseTask, resumeTask, completeTask, abandonTask, skipTask, toggleSubtask |
| `routine_service_contract_test.dart` | RoutineService | runDayCloseIfNeeded (guard, happy path, idempotency, error resilience) |
| `habit_service_contract_test.dart` | HabitService | habits, getHabit, dailyLogCount, dailyTotal, createHabit, updateHabit, deleteHabit, logGood, logSlip |
| `streak_service_contract_test.dart` | StreakService | runDayCloseRollup, event emission, bad-habit goal types, error resilience, watchAllStreaks, watchStreak, getStreak |
| `notification_service_contract_test.dart` | NotificationService | init, scheduleTaskReminder, scheduleTaskEndReminder, cancelTaskEndReminder, scheduleStreakMilestone, scheduleSlipRecovery, ensureNotificationSettings, reserveNotificationSlot, writeSuppressionEvent |
| `suggestion_service_contract_test.dart` | SuggestionService (planned) | fetchSuggestions, dismissSuggestion, acceptSuggestion, watchPendingSuggestions |

### Cloud Functions contract tests

Three JS contract test files exist under `functions/test/`:

| File | Surface |
|---|---|
| `events.contract.test.js` | Event helper doc shape, dual-write, idempotency, auth guard, events_recent trimming |
| `jobs.contract.test.js` | scheduledDayClose, scheduledInactivityCheck, scheduledMorningBrief, scheduledMiddayPulse |
| `routineImport.contract.test.js` | Planned `routineImport` callable — auth, validation, Firestore writes, event emission, return shape, idempotency |

> [!WARNING]
> `functions/package.json` does **not** define an `npm test` script.
> `cd functions && npm test` will fail with `Missing script: "test"`.
>
> To enable JS tests, install a test runner (e.g. Jest) and add a test script:
>
> ```json
> // functions/package.json — scripts section
> "scripts": {
>   "test": "jest --testPathPattern=test/"
> }
> ```
>
> Then install: `npm install --save-dev jest`
>
> This is deferred to a later task (test infrastructure wiring).
