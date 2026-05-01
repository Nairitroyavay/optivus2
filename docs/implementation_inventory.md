# Optivus Implementation Inventory

Generated for Task 0.1 after reading the current Flutter/Firebase codebase paths requested in `todo_V1_(fixed)_All_Features.md`.

This inventory is descriptive only. It does not authorize runtime changes. The current app is partially built and should be extended, not rewritten.

## Summary

- The app has a working Flutter shell, Firebase initialization, routing, auth screens, onboarding pages, six-tab home shell, routine timeline, basic task/habit/streak/routine services, notification service, coach/AI files, and Cloud Functions jobs.
- The app is not production-complete. Most core surfaces exist, but many features are partial because service contracts, Firestore schemas, events, backend jobs, AI behavior, notifications, and verification are incomplete.
- The most important current product gap is routine setup and materialization: fixed schedule must be unlimited and repeat daily from reusable templates, and the routine setup modes need manual/AI/upload paths.
- Firestore remains the V1 source of truth. Do not migrate to Postgres for V1.
- AI provider calls must stay behind Cloud Functions/backend-controlled paths. Flutter must not expose AI secrets.

## App Startup and Routing

### `lib/main.dart`

- Initializes Flutter bindings, Firebase, App Check, Crashlytics, Remote Config, Firestore offline persistence, local notifications, and day-close startup behavior.
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
- `lib/models/habit_model.dart`: good/bad habit model and state fields.
- `lib/models/habit_log_model.dart`: habit log model.
- `lib/models/streak_model.dart`: streak model and state.
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

### `lib/services/coach_service.dart`, `gemini_service.dart`, `rule_engine_service.dart`, `state_aggregator_service.dart`

- Coach service builds prompts/context and can persist proactive coach messages.
- Gemini service calls backend/AI helper methods.
- Rule engine has some rules.
- State aggregator builds partial context snapshots.
- Status: partial. Needs backend-controlled LLM calls, safety routing, speak budget, suggestion service, AI routine import endpoints, and full context.

### Other services

- `firestore_service.dart`: general Firestore helper with user, tasks, goals, routine, coach chat, export/delete helpers.
- `remote_config_service.dart`: remote config keys and loading.
- `global_error_handler.dart`: global error handling.
- `screen_time_bridge.dart` and `screen_time_importer.dart`: Android screen time bridge/import.
- Status: partial. Useful base; production operational controls and privacy/export lifecycle need hardening.

## UI Screens

### `lib/views/screens/*.dart`

- `welcome_screen.dart`, `login_screen.dart`, `signup_screen.dart`, `loading_screen.dart`, `onboarding_screen.dart`, `home_screen.dart`.
- Status: implemented/partial. Auth and shell exist; more detail routes/settings must be added.

### `lib/views/onboarding/*.dart`

- Pages 0-9 exist.
- Page 8 is current fixed schedule setup.
- Page 9 is current AI plan preview/final page.
- Status: partial. User Flow calls for a stronger About You Page 5 and Page 10 AI plan ready. Current numbering differs from docs and must be handled carefully.

### `lib/views/tabs/*.dart`

- Home, Routine settings, Tracker, Coach, Goals, Profile tabs exist.
- Status: partial. Main surfaces exist, but many required flows are shallow/missing.

### `lib/views/routine/*.dart`

- Routine timeline, filter dropdown, setup screens for fixed schedule, skin care, eating, classes, Add task sheet, AI panel.
- Status: partial. Fixed schedule now has an Add task path in onboarding, but routine setup still needs production templates, supplement setup, review-before-save AI/import flows, and real suggestion service.

### `lib/views/habits/*.dart`

- `log_habit_sheet.dart` exists.
- Status: partial. Missing editor/detail/variant screens.

## Cloud Functions

### `functions/index.js`

- Contains callable AI generation entry point.
- Status: partial. Needs structured routine import endpoint, event helpers, safety, usage limits, and exports for new jobs.

### `functions/jobs/*.js`

- Existing jobs: morning brief, midday pulse, day close, inactivity check, utilities.
- Status: partial. Needs notification dispatcher, AI planner/rule engine/safety split, export/delete, cleanup/backfill, weekly summary, emulator tests.
- Verification note for Task 0.2: `functions/package.json` currently does not define an `npm test` script, so `cd functions && npm test` is not available yet. Add a test script before enabling the Cloud Functions contract test command.

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
3. AI features are too direct/ad hoc and not fully backend-controlled.
4. Notification lifecycle is incomplete.
5. Several UI entry points exist but do not complete the full user flow.
6. Tests are missing or skeletal.
7. Feature matrix must be kept current after each phase.

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
