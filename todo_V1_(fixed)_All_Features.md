# Optivus V1 Fixed - Full Step-by-Step Antigravity TODO

This file is the implementation plan for the existing Optivus Flutter/Firebase app.

Use this file as copy-paste instructions for Antigravity. Do not treat Optivus as a fresh project. Extend the existing codebase, preserve working screens, and only refactor where the task says the current contract is broken.

## 1. Short Summary

1. Optivus already has a Flutter shell, Firebase startup, auth screens, onboarding pages 0-9, six main tabs, routine screens, task/habit/streak/routine services, notification service, AI coach files, and Cloud Functions jobs.
2. The app is partially built, but the current implementation is not production-ready because contracts are incomplete across Firestore, events, services, daily lifecycle, notifications, AI, and analytics.
3. The User Flow document is the product source of truth for what users see and do.
4. The Event System and Service Contracts documents are the source of truth for event names, payloads, service behavior, and side effects.
5. The Database Schema document must be adapted to the current Firestore-first implementation. Do not migrate to Postgres for V1.
6. The existing `/users/{uid}/routine/current` document should stay as the canonical routine config unless a migration task explicitly changes it.
7. The biggest urgent bug is fixed schedule: onboarding currently behaves like fixed schedule is a small one-time setup instead of an unlimited reusable daily template.
8. Fixed schedule must support unlimited items and repeat every day automatically in the Routine timeline.
9. Routine tab must expose a clear Add button for any selected day.
10. Routine tab must expose a clear AI button that shows editable suggestions before applying them.
11. Skin care setup must support manual, text AI, and photo AI.
12. Supplements must support manual and text AI.
13. Class routine must support manual and timetable image upload.
14. Eating routine must support manual, mess menu photo upload, and AI-generated routine.
15. Every routine setup must save reusable templates, not only one-time task docs.
16. Daily task instances must be materialized idempotently from routine templates.
17. Events must be append-only and schema validated before AI, notifications, analytics, and streaks depend on them.
18. Backend and Firestore contracts must be fixed before UI polish.
19. AI must not call provider APIs directly from Flutter. Cloud Functions must own AI calls and secrets.
20. A feature is complete only when UI, state, Firestore, backend if needed, events, notifications if needed, verification, and user-visible entry point are all present.

## 2. Codebase Analysis

### Already Implemented

- App startup: `lib/main.dart`.
- Router: `lib/core/router/app_router.dart`.
- Bootstrap routing: `lib/core/providers/bootstrap_provider.dart`.
- Auth screens: `lib/views/screens/signup_screen.dart`, `lib/views/screens/login_screen.dart`, `lib/views/screens/welcome_screen.dart`.
- Home shell: `lib/views/screens/home_screen.dart`.
- Main tabs: `lib/views/tabs/home_tab.dart`, `routine_settings_screen.dart`, `tracker_tab.dart`, `coach_tab.dart`, `goals_tab.dart`, `profile_tab.dart`.
- Onboarding pages 0-9: `lib/views/onboarding/onboarding_page_0.dart` through `onboarding_page_9.dart`.
- Onboarding provider/repository: `lib/providers/onboarding_provider.dart`, `lib/repositories/user_repository.dart`.
- Routine setup screens: `lib/views/routine/fixed_schedule_setup_screen.dart`, `skin_care_setup_screen.dart`, `eating_setup_screen.dart`, `class_setup_screen.dart`.
- Routine tab and timeline: `lib/views/routine/routine_tab.dart`, `timeline_section.dart`, `timeline_zoom_views.dart`, `add_task_sheet.dart`, `ai_routine_panel.dart`, `routine_settings_sheet.dart`.
- Routine state/repository: `lib/providers/routine_provider.dart`, `lib/repositories/routine_repository.dart`.
- Task model/service: `lib/models/task_model.dart`, `lib/services/task_service.dart`.
- Habit model/log/service: `lib/models/habit_model.dart`, `lib/models/habit_log_model.dart`, `lib/services/habit_service.dart`.
- Streak service/model: `lib/services/streak_service.dart`, `lib/models/streak_model.dart`.
- Routine day-close service/model: `lib/services/routine_service.dart`, `lib/models/day_summary_model.dart`.
- Event model/service/constants: `lib/models/event_model.dart`, `lib/services/event_service.dart`, `lib/core/constants/event_names.dart`.
- Notifications: `lib/services/notification_service.dart`, `lib/models/scheduled_notification_model.dart`.
- AI files: `lib/services/gemini_service.dart`, `lib/services/coach_service.dart`, `lib/services/rule_engine_service.dart`, `lib/services/state_aggregator_service.dart`, `lib/models/context_snapshot.dart`, `lib/models/coach_rule.dart`.
- Cloud Functions: `functions/index.js`, `functions/jobs/morningBrief.js`, `middayPulse.js`, `dayClose.js`, `inactivityCheck.js`, `utils.js`.
- Goals/identity files: `lib/models/goal_model.dart`, `lib/models/identity_profile_model.dart`, `lib/repositories/goal_repository.dart`, `lib/providers/goal_provider.dart`, `lib/providers/identity_provider.dart`.
- Firebase rules/index files exist: `firestore.rules`, `firestore.indexes.json`.

### Partially Implemented

- EventService writes events but needs production validation, idempotency, exact payload contracts, and consistent archive/recent behavior.
- TaskService has lifecycle methods, but contracts and UI coverage must be verified against service docs.
- RoutineProvider already materializes tasks from routine state, but fixed schedule and other routines need formal reusable templates, no item cap, future-day idempotency, and edit-history safety.
- NotificationService schedules some local notifications but needs full lifecycle logs, notification center, deep links, caps, dedupe, quiet hours, and custom alarms.
- Coach/AI exists, but it must become backend-controlled, event/context/rule driven, and safe.
- Home, Tracker, Goals, and Profile exist, but many flows are read-only or shallow.
- Cloud Functions exist but need event-triggered jobs, AI import endpoints, notification dispatcher, export/delete jobs, cleanup/backfill, and emulator tests.

### Not Implemented

- Onboarding Page 10 AI plan ready screen.
- Full About You Page 5 with body basics, lifestyle, sensitive context.
- Unlimited onboarding fixed schedule items.
- Fixed schedule as daily repeating reusable templates.
- Routine Add button for any selected day.
- Routine AI button with reviewable suggestions.
- Supplement setup screen.
- Skin care text AI/photo AI setup.
- Class timetable image upload.
- Eating mess menu upload and AI-generated eating routine.
- Full notification center/settings/custom alarm ringing flow.
- Full tracker variant detail screens.
- Full goal editor/detail/milestone/why-score/identity connection flows.
- Full profile settings, privacy export/delete, subscription limits.
- Full AI rule engine, suggestion service, routine import AI endpoints, safety routing.
- Full analytics summaries, monitoring, QA, emulator tests, and release checks.

### Needs Refactoring

- `lib/services/event_service.dart`: schema validation, idempotency, append-only semantics.
- `lib/services/task_service.dart`: exact payloads, state machine, active task exclusivity, subtask events.
- `lib/providers/routine_provider.dart`: reusable routine templates, unlimited items, idempotent daily materialization.
- `lib/services/routine_service.dart`: multi-day close, routine block completion, daily summaries, mission ring.
- `lib/services/notification_service.dart`: durable lifecycle and dedupe.
- `lib/services/habit_service.dart`: lifecycle events, flat canonical logs, pause/resume/delete.
- `lib/services/streak_service.dart`: accountability, ghost pause/resume, milestones.
- `lib/services/state_aggregator_service.dart`: complete context snapshots for AI.
- `functions/index.js` and `functions/jobs/*.js`: split callable AI, jobs, notification dispatcher, cleanup, and tests.

### Do Not Touch Unless Required

- Do not replace Flutter.
- Do not replace Firebase Auth, Firestore, or Cloud Functions.
- Do not migrate to Postgres in V1.
- Do not rewrite the UI shell.
- Do not remove working onboarding/routine/task/habit code.
- Do not expose AI API keys in Flutter.
- Do not weaken Firestore rules.
- Do not create shared user data outside `/users/{uid}` except safe operational/config collections.

## 3. User Flow Breakdown

### Onboarding Flow

| Step | User action | UI screen | Backend action | Firestore write | Event |
|---|---|---|---|---|---|
| 1 | Opens app | `WelcomeScreen` | Bootstrap reads auth | none | none |
| 2 | Signs up | `SignupScreen` | `AuthService.signUp` creates Firebase Auth user | `/users/{uid}` | `user_signed_up` |
| 3 | Starts onboarding | `OnboardingScreen` | Load saved progress | `/users/{uid}/onboarding/state` read | none |
| 4 | Picks focus areas | `onboarding_page_0.dart` | Save draft | `/onboarding/state.focusAreas` | none |
| 5 | Picks bad habits | `onboarding_page_1.dart` | Save draft | `/onboarding/state.badHabits` | none |
| 6 | Picks good habits | `onboarding_page_2.dart` | Save draft | `/onboarding/state.goodHabits` | none |
| 7 | Picks goals | `onboarding_page_3.dart` | Save draft | `/onboarding/state.goals` | none |
| 8 | Completes About You | `onboarding_page_5.dart` | Validate body/lifestyle/safety | `/profile/main`, `/onboarding/state.aboutYou` | none during draft |
| 9 | Chooses coach | pages 6-8 | Save coach/accountability | `/profile/main.coach*`, `/profile/main.accountabilityMode` | none during draft |
| 10 | Creates fixed schedule | `onboarding_page_9.dart` | Save unlimited reusable templates | `/routine/current.templates.fixed_schedule` | none during draft |
| 11 | Reviews plan | new `onboarding_page_10.dart` | Materialize first day, schedule reminders | `/tasks/*`, `/habits/*`, `/goals/*`, `/scheduled_notifications/*`, `/ai_context_snapshots/*` | `onboarding_completed`, `task_scheduled`, `notification_scheduled`, `suggestion_generated` |
| 12 | Enters app | Home tab | Bootstrap routes home | `/users/{uid}.hasCompletedOnboarding=true` | `day_started` if first day |

### First Day Experience

| Step | User action | UI screen | Backend action | Firestore write | Event |
|---|---|---|---|---|---|
| 1 | Opens Home | `HomeTab` | Start day and build context | `/ai_context_snapshots/{id}` | `day_started` |
| 2 | Opens Routine | `RoutineTab` | Materialize missing selected-day tasks from templates | `/tasks/{taskId}` | `task_scheduled` only for new docs |
| 3 | Starts task | Timeline row | Enforce active task rules | `/tasks/{taskId}` | `task_started` |
| 4 | Checks subtasks | Timeline/detail | Persist subtask state | `/tasks/{taskId}.subtasks` | `subtask_checked` / `subtask_unchecked` |
| 5 | Completes task | Timeline row | Write outcome and update projections | `/tasks/{taskId}`, `/task_outcomes/{id}` | `task_completed`, possible `routine_block_completed` |
| 6 | Logs habit | Home/Tracker sheet | Write log and recompute totals | `/habit_logs/{logId}` | `good_habit_logged` or `bad_habit_slip_logged` |
| 7 | Uses AI panel | Routine AI button | Read suggestions or request backend suggestions | `/suggestions/{id}` | `suggestion_generated` |
| 8 | Accepts AI suggestion | Routine AI panel | Create template or selected-date task | `/routine/current`, `/tasks/*` | `suggestion_accepted`, `task_scheduled` |
| 9 | Receives notification | OS notification | Deep link and lifecycle log | `/notificationLog/{id}` | `notification_tapped` / `notification_dismissed` |

### Daily Usage Loop

| Loop | User action | UI screen | Backend action | Firestore write | Event |
|---|---|---|---|---|---|
| Morning | Opens app | Home | Ensure day exists and tasks materialized | `/tasks/*`, `/dailySummaries/{date}` projection | `day_started` |
| During day | Executes tasks | Routine | State machine transitions | `/tasks/{taskId}` | task events |
| Habit moment | Logs good/slip | Home/Tracker | Log and update streak inputs | `/habit_logs/{logId}` | habit events |
| AI moment | Accepts/dismisses | Routine/Coach/Home | Save learning signal | `/suggestions/{id}` | suggestion events |
| Notification | Opens/dismisses | system deep link | Log lifecycle | `/notificationLog/{id}` | notification events |
| Evening | Reviews day | Home/Coach/Routine | Close day and summarize | `/dailySummaries/{date}` | `day_closed`, `routine_day_summarized` |
| Long term | Reviews identity | Goals/Profile | Recompute progress | `/identity_profile/main`, `/goals/*` | identity events |

### Event Trigger Points

- Auth: `user_signed_up`, `user_signed_out`.
- Onboarding: `onboarding_completed`.
- Routine templates: `routine_template_created`, `routine_template_updated`, `routine_template_deleted` after adding them to event contracts.
- Routine materialization: `task_scheduled`.
- Task controls: `task_started`, `task_paused`, `task_resumed`, `task_completed`, `task_abandoned`, `task_skipped`, `task_deleted`.
- Subtasks: `subtask_checked`, `subtask_unchecked`.
- Habit lifecycle: `habit_created`, `habit_updated`, `habit_paused`, `habit_resumed`, `habit_archived`, `habit_deleted`.
- Habit logs: `good_habit_logged`, `bad_habit_slip_logged`, `habit_log_deleted`, `slip_streak_detected`.
- Routine analytics: `routine_block_completed`, `routine_day_summarized`.
- Streaks: `streak_extended`, `streak_broken`, `streak_milestone_reached`, `streak_paused`, `streak_resumed`.
- Coach: `coach_message_sent`, `coach_replied`.
- Suggestions: `suggestion_generated`, `suggestion_accepted`, `suggestion_dismissed`.
- Notifications: `notification_scheduled`, `notification_sent`, `notification_tapped`, `notification_dismissed`, `notification_suppressed`, `notification_missed`.
- Day lifecycle: `day_started`, `day_closed`.
- Identity/settings: `identity_created`, `identity_updated`, `identity_paused`, `identity_archived`, `identity_habit_linked`, `identity_progress_changed`, `identity_statement_updated`, `milestone_completed`, `coach_settings_changed`, `accountability_changed`, `notification_settings_changed`, `biometrics_updated`.
- Retention: `ghost_day_detected`, `comeback_initiated`.
- Analytics: `weekly_insight_ready` after adding to contracts.

### AI Interaction Points

- Onboarding plan preview.
- Routine AI button suggestions.
- Text AI routine setup for skin care, supplements, eating goals.
- Photo AI routine setup for skin care products, class timetable, mess menu.
- Coach chat.
- Habit slip recovery.
- End-of-day summary.
- Tomorrow setup.
- Ghost/comeback restart plan.
- Goal why-score explanation.
- Notification copy, only after rule engine allows speaking.
- Safety routing for crisis/self-harm and medical/legal/financial boundaries.

### Feature Entry Points

- Home: mission ring, habit quick logs, streak card, calendar, today's routine, recurring routines, notification bell, coach card.
- Routine: timeline, date selector, filter, Add button, AI button, settings gear, setup empty states.
- Tracker: habit cards, detail screens, add/edit habit, good/bad logging, screen time, money saved, analytics.
- Coach: chat, topic modes, proactive messages, suggestion history.
- Goals: identity hero, goals grid, detail, milestones, why score, add/edit/archive.
- Profile: identity statement, coach settings, accountability, notifications, About You, routines, privacy/export/delete, subscription, signout.
- Notifications: deep links into tasks, habits, coach, goals, comeback.

### Retention Loops

| Loop | Trigger | User-visible path | Backend action | Firestore write | Event |
|---|---|---|---|---|---|
| Streak reinforcement | Task/habit success | Home/Tracker | Update streak and milestone | `/streaks/*` | `streak_extended`, `streak_milestone_reached` |
| Slip recovery | Bad habit slip | Tracker/Coach/notification | Detect repeated slips | `/habit_logs/*`, `/suggestions/*` | `bad_habit_slip_logged`, `slip_streak_detected` |
| Mission recovery | Low completion | Home/Routine AI card | Suggest lighter plan | `/suggestions/*` | `suggestion_generated` |
| Ghost comeback | Inactivity | Comeback modal | Pause/resume streaks, restart plan | `/streaks/*`, `/suggestions/*` | `ghost_day_detected`, `comeback_initiated` |
| Identity progress | Consistent behavior | Goals/Profile/Home | Recompute identity | `/identity_profile/main` | `identity_progress_changed` |
| Notification learning | Tap/dismiss/suppress | Notification settings/center | Update budgets | `/notificationLog/*` | notification lifecycle events |

## 4. Dependency Map

1. Auth and `/users/{uid}` schema before onboarding completion.
2. Onboarding and About You before personalized routines, notifications, and AI.
3. Firestore schema/rules/indexes before Cloud Functions rely on paths.
4. EventService validation/idempotency before expanding events.
5. TaskService state machine before Routine timeline controls.
6. Routine templates before fixed schedule daily repeat.
7. Daily task materialization before reminders and day close.
8. Habit logs before streaks, tracker analytics, and recovery.
9. Day start/day close before mission ring, daily summaries, identity scoring, and AI daily planning.
10. Notification lifecycle before custom alarms, caps, dedupe, and AI nudges.
11. Goals/identity schema before identity mission ring and AI context.
12. Context snapshots before rule engine and LLM calls.
13. Rule engine before proactive AI suggestions.
14. Suggestion storage before Routine AI accept/dismiss.
15. Export/delete/privacy depend on stable schema paths.
16. Production release depends on emulator, unit, widget, integration, rules, and function tests.

## 5. Production Build Plan

- Pre-Phase 0: Add urgent routine/onboarding fixes to scope.
- Phase 0: Build inventory and test guardrails.
- Phase 1: Auth, user schema, onboarding, About You, first plan.
- Phase 2: Event spine, Firestore schema, rules, indexes.
- Phase 3: Tasks, routines, fixed schedule repeat, routine setup modes, day lifecycle.
- Phase 4: Habits and Tracker.
- Phase 5: Streaks, accountability, ghost, comeback.
- Phase 6: Goals and identity.
- Phase 7: Notifications and custom alarms.
- Phase 8: AI Master Engine, Coach, AI routine imports.
- Phase 9: Profile, privacy, export/delete, subscription.
- Phase 10: Analytics, Cloud Functions, operations.
- Phase 11: QA and release readiness.

## 6. Phase-wise Antigravity TODO List

## Pre-Phase 0 - Urgent Routine and Onboarding Fix Scope

### Task P0.1 - Add fixed schedule and routine import requirements to scope

**Status:** Completed on 2026-05-01.

#### Why

The current fixed schedule behaves like a small one-time setup. The product requires unlimited reusable daily schedules and easier AI-assisted routine creation.

#### What to tell Antigravity

- MODIFY only planning docs if implementation has not started.
- Include these requirements in every later inventory and implementation task:
  - Fixed schedule supports unlimited items during onboarding and after onboarding.
  - Fixed schedule saves reusable templates in `/users/{uid}/routine/current`.
  - Fixed schedule materializes every day into `/users/{uid}/tasks/{taskId}`.
  - Routine tab has Add button for any selected day.
  - Routine tab has AI button for editable suggestions.
  - Skin care setup supports Manual, Text Input with AI, Photo Upload with AI.
  - Supplement setup supports Manual and Text Input with AI.
  - Class setup supports Manual and timetable image/screenshot upload.
  - Eating setup supports Manual, Upload Mess Menu Photo, Generate with AI.
- Do not write app code in this task.

#### Dependencies

- None.

#### How to verify

- Search the TODO file for each requirement.
- Confirm every requirement appears again in Phase 0, Phase 1, Phase 3, Phase 7, Phase 8, and Phase 11.

#### Verification completed

- Phase 0: Task 0.1 requires feature matrix rows for fixed schedule repeat, Routine Add, Routine AI, skin care AI, supplement AI, class upload, and eating AI.
- Phase 1: Tasks 1.3 and 1.4 require unlimited onboarding fixed schedule templates and first-day materialization.
- Phase 3: Tasks 3.2, 3.3, and 3.4 require reusable template materialization, Routine Add/AI buttons, and all manual/AI/upload routine setup modes.
- Phase 7: Tasks 7.1, 7.2, and 7.3 require notifications/settings/alarms for template-generated and selected-date routine tasks.
- Phase 8: Tasks 8.3 and 8.4 require Routine AI suggestions and backend AI routine import/generation.
- Phase 11: Tasks 11.1, 11.2, and 11.3 require tests, migration seeds, and final completeness audit for all urgent routine fixes.

#### Estimate

30m

#### Done Criteria

- [x] Unlimited fixed schedule is explicitly scoped.
- [x] Daily repeat templates are explicitly scoped.
- [x] Routine Add and AI buttons are explicitly scoped.
- [x] Skin care, supplement, class, and eating setup modes are explicitly scoped.

## Phase 0 - Audit Guardrails

### Task 0.1 - Create implementation inventory and feature matrix

#### Why

Antigravity must understand the current app before changing it.

#### What to tell Antigravity

- CREATE `docs/implementation_inventory.md`.
- CREATE `docs/feature_matrix.md`.
- Read and summarize these paths:
  - `lib/main.dart`
  - `lib/core/router/app_router.dart`
  - `lib/core/providers.dart`
  - `lib/core/providers/bootstrap_provider.dart`
  - `lib/core/event_orchestrator.dart`
  - `lib/core/constants/event_names.dart`
  - `lib/models/*.dart`
  - `lib/providers/*.dart`
  - `lib/repositories/*.dart`
  - `lib/services/*.dart`
  - `lib/views/screens/*.dart`
  - `lib/views/onboarding/*.dart`
  - `lib/views/tabs/*.dart`
  - `lib/views/routine/*.dart`
  - `lib/views/habits/*.dart`
  - `functions/index.js`
  - `functions/jobs/*.js`
  - `firestore.rules`
  - `firestore.indexes.json`
- In `docs/feature_matrix.md`, create rows for every feature from all 7 docs plus the urgent routine fixes.
- Columns required:
  - Feature
  - User-visible UI path
  - Flutter file
  - Provider/state
  - Service/repository
  - Firestore path
  - Event
  - Cloud Function/backend
  - Notification need
  - AI need
  - Status: implemented, partial, missing
  - Verification
- Do not change app runtime code.

#### Dependencies

- Task P0.1.

#### How to verify

- Open both docs.
- Confirm every PRD/User Flow feature has a row.
- Confirm fixed schedule repeat, Routine Add, Routine AI, skin care AI, supplement AI, class upload, eating AI are rows.
- Confirm `git diff` only shows docs.

#### Estimate

2h

#### Status

Completed on 2026-05-01.

#### Done Criteria

- [x] Inventory doc exists.
- [x] Feature matrix exists.
- [x] Every feature has UI, backend, Firestore, event, verification columns.
- [x] No runtime code changed.

### Task 0.2 - Add contract test skeletons

#### Why

Each phase needs a safe place to add tests without blocking on full implementation.

#### What to tell Antigravity

- CREATE `test/services/event_service_contract_test.dart`.
- CREATE `test/services/task_service_contract_test.dart`.
- CREATE `test/services/routine_service_contract_test.dart`.
- CREATE `test/services/habit_service_contract_test.dart`.
- CREATE `test/services/streak_service_contract_test.dart`.
- CREATE `test/services/notification_service_contract_test.dart`.
- CREATE `test/services/suggestion_service_contract_test.dart`.
- CREATE `functions/test/events.contract.test.js`.
- CREATE `functions/test/jobs.contract.test.js`.
- CREATE `functions/test/routineImport.contract.test.js`.
- Add skipped/TODO test groups only.
- Do not modify production services.

#### Dependencies

- Task 0.1.

#### How to verify

- Run `flutter test`.
- Run `cd functions && npm test` if a script exists.
- If a script does not exist, document that in `docs/implementation_inventory.md`.

#### Estimate

1h

#### Status

Completed on 2026-05-01.

#### Done Criteria

- [x] Test skeletons exist — 7 Dart files (~190 skipped tests) + 3 JS files.
- [x] Tests do not fail because of empty TODO groups (`flutter test` → +0, ~190 skipped).
- [x] Missing npm script documented in `docs/implementation_inventory.md`.

## Phase 1 - Auth, User Schema, and Onboarding

### Task 1.1 - Align auth lifecycle and root user schema

#### Why

Every feature depends on a stable `/users/{uid}` document and auth lifecycle.

#### What to tell Antigravity

- MODIFY `lib/services/auth_service.dart`.
- MODIFY `lib/repositories/auth_repository.dart`.
- MODIFY `lib/models/user_model.dart`.
- MODIFY `lib/views/screens/signup_screen.dart`.
- MODIFY `lib/views/screens/login_screen.dart`.
- MODIFY `lib/core/constants/event_names.dart` only if constants are missing.
- Ensure `/users/{uid}` contains:
  - `uid`, `email`, `displayName`, `createdAt`, `updatedAt`, `schemaVersion`, `timezone`
  - `hasCompletedOnboarding`, `onboardingStep`, `lastDayClosed`
  - `coachName`, `coachStyle`, `accountabilityMode`
  - `notificationSettings`
- Emit `user_signed_up` exactly once per account.
- Keep email/password working.
- Add disabled Google/Apple UI only if config is absent; do not break login.
- Show loading, error, invalid email, weak password, forgot password states.

#### Dependencies

- Task 0.1.

#### How to verify

- UI: sign up, sign out, sign in.
- Firebase console: `/users/{uid}` has required fields.
- Events: `/users/{uid}/events_recent` has one `user_signed_up`.
- Navigation: unfinished onboarding routes to onboarding; completed routes home.

#### Estimate

2h

#### Done Criteria

- [ ] Signup works.
- [ ] Login works.
- [ ] Root user schema is complete.
- [ ] `user_signed_up` is emitted once.

### Task 1.2 - Complete About You onboarding page

#### Why

AI, nutrition, routine timing, safety, and notification tone need real user context.

#### What to tell Antigravity

- MODIFY `lib/views/onboarding/onboarding_page_5.dart`.
- MODIFY `lib/providers/onboarding_provider.dart`.
- MODIFY `lib/repositories/user_repository.dart`.
- MODIFY `lib/models/user_model.dart`.
- MODIFY `lib/models/identity_profile_model.dart`.
- Implement three sub-pages:
  - Body basics: age range, height, weight, optional gender, wake time, sleep time, timezone.
  - Lifestyle: school/work type, exercise level, water intake, diet preference, stress level, sleep quality.
  - Sensitive context: eating disorder flag, crisis/self-harm flag, medical disclaimer acknowledgement, coach boundary preference.
- Firestore writes:
  - `/users/{uid}/onboarding/state.aboutYou`
  - `/users/{uid}/profile/main.biometrics`
  - `/users/{uid}/profile/main.lifestyle`
  - `/users/{uid}/profile/main.sensitiveContext`
- Validation:
  - impossible age/height/weight rejected.
  - sensitive fields can be skipped as `null`.
- No `biometrics_updated` event during initial onboarding draft saves.

#### Dependencies

- Task 1.1.

#### How to verify

- UI: complete sub-pages, go back/forward, restart app, data remains.
- Firebase console: profile and onboarding docs have typed fields.
- Logs: skipped sensitive answers do not crash.
- Navigation: onboarding continues.

#### Estimate

4h

#### Done Criteria

- [ ] Page 5 has three sub-pages.
- [ ] Data persists.
- [ ] Validation works.
- [ ] Firestore paths match.

### Task 1.3 - Fix onboarding fixed schedule as unlimited daily templates

#### Why

Users must add more than 3 fixed schedule tasks, and those tasks must repeat every day.

#### What to tell Antigravity

- MODIFY `lib/views/onboarding/onboarding_page_9.dart`.
- MODIFY `lib/providers/onboarding_provider.dart`.
- MODIFY `lib/repositories/user_repository.dart`.
- MODIFY `lib/providers/routine_provider.dart`.
- MODIFY `lib/repositories/routine_repository.dart`.
- Remove any hard-coded 3-item limit.
- UI behavior:
  - Add unlimited schedule blocks.
  - Edit title, start time, end time or duration, category, notes.
  - Delete blocks.
  - Reorder blocks.
  - Show validation for blank title, invalid time, overlapping time only if overlap is not allowed.
- Firestore:
  - Draft: `/users/{uid}/onboarding/state.fixedSchedule`
  - Final template config: `/users/{uid}/routine/current.templates.fixed_schedule`
- Template fields:
  - `templateId`, `title`, `routineType=fixed_schedule`, `startTime`, `endTime`, `repeatRule=daily`, `category`, `notes`, `isActive`, `createdAt`, `updatedAt`.
- Do not create only one-time tasks from onboarding.

#### Dependencies

- Task 1.2.

#### How to verify

- UI: add 6+ fixed schedule blocks during onboarding.
- Firebase console: all blocks saved as templates.
- Restart app during onboarding and confirm all blocks reload.
- No 3-item cap remains.

#### Estimate

4h

#### Done Criteria

- [ ] User can add more than 3 blocks.
- [ ] Blocks persist as templates.
- [ ] Validation exists.
- [ ] No one-time-only fixed schedule behavior remains.

### Task 1.4 - Add final AI plan ready onboarding page

#### Why

The User Flow requires the user to see the first plan before entering Home.

#### What to tell Antigravity

- CREATE `lib/views/onboarding/onboarding_page_10.dart`.
- MODIFY `lib/views/screens/onboarding_screen.dart`.
- MODIFY `lib/providers/onboarding_provider.dart`.
- MODIFY `lib/repositories/user_repository.dart`.
- MODIFY `lib/providers/routine_provider.dart`.
- UI behavior:
  - Show Today's routine preview.
  - Show habit focus.
  - Show top goals.
  - Show notification summary.
  - Show coach style.
  - CTA: `Enter Optivus` or `Start Today`.
  - Secondary action: go back and edit.
  - Empty state: minimal starter plan.
- Firestore on completion:
  - `/users/{uid}.hasCompletedOnboarding=true`
  - `/users/{uid}.onboardingStep=10`
  - `/users/{uid}/onboarding/state.status=completed`
  - `/users/{uid}/profile/main`
  - `/users/{uid}/routine/current`
  - `/users/{uid}/tasks/{taskId}`
  - `/users/{uid}/habits/{habitId}`
  - `/users/{uid}/goals/{goalId}`
  - `/users/{uid}/scheduled_notifications/{notificationId}`
  - `/users/{uid}/ai_context_snapshots/{snapshotId}`
- Events:
  - `onboarding_completed`
  - `task_scheduled`
  - `notification_scheduled`
  - `suggestion_generated` for first deterministic plan suggestions.
- Backend:
  - No external LLM required here. Generate deterministic plan from onboarding inputs.

#### Dependencies

- Task 1.3.
- Task 2.1 should revalidate events later.

#### How to verify

- UI: new user reaches Page 10 and taps Start Today.
- Firebase console: user, profile, routine, tasks, habits, goals, notifications, snapshot exist.
- Routine tab: today's fixed schedule appears.
- Events: onboarding and task/notification events exist.
- Navigation: lands Home.

#### Estimate

1 day

#### Done Criteria

- [ ] Page 10 exists.
- [ ] Start Today completes onboarding.
- [ ] Fixed schedule appears in Routine today.
- [ ] Required docs/events exist.

## Phase 2 - Event Spine and Firestore Contracts

### Task 2.1 - Make EventService production-grade

#### Why

AI, notifications, analytics, streaks, and retention depend on reliable events.

#### What to tell Antigravity

- MODIFY `lib/services/event_service.dart`.
- MODIFY `lib/models/event_model.dart`.
- MODIFY `lib/core/constants/event_names.dart`.
- CREATE `lib/services/event_payload_validator.dart`.
- MODIFY `lib/core/utils/uuid_generator.dart`.
- MODIFY `test/services/event_service_contract_test.dart`.
- Firestore:
  - `/users/{uid}/events/{eventId}`
  - `/users/{uid}/events_recent/{eventId}`
- Event envelope fields:
  - `eventId`, `eventName`, `uid`, `timestamp`, `source`, `schemaVersion`, `payloadVersion`, `payload`, `deviceId`, `appVersion`.
- Add validation for all events listed in Section 3 of this file.
- Add routine template events only after adding them to constants and validator:
  - `routine_template_created`
  - `routine_template_updated`
  - `routine_template_deleted`
- Idempotency:
  - duplicate `eventId` must not create another event.
  - writes to `events` and `events_recent` must be transactional or batch-consistent.
- Error/loading:
  - validation errors should be logged and surfaced in debug builds.

#### Dependencies

- Task 0.2.

#### How to verify

- Tests: valid events write; invalid payload rejected; duplicate event ignored/rejected safely.
- Firebase console: both event collections receive the same envelope.
- Logs: no duplicate side effects.

#### Estimate

1 day

#### Done Criteria

- [ ] Event envelope is consistent.
- [ ] Payload validation exists.
- [ ] Idempotency exists.
- [ ] Tests cover core events.

### Task 2.2 - Align Firestore schema, rules, and indexes

#### Why

Client, services, and Cloud Functions must use the same paths.

#### What to tell Antigravity

- MODIFY `firestore.rules`.
- MODIFY `firestore.indexes.json`.
- MODIFY `lib/services/firestore_service.dart`.
- CREATE `docs/firestore_schema_v1_mapping.md`.
- Standardize per-user paths:
  - `/users/{uid}`
  - `/users/{uid}/profile/main`
  - `/users/{uid}/onboarding/state`
  - `/users/{uid}/routine/current`
  - `/users/{uid}/tasks/{taskId}`
  - `/users/{uid}/task_outcomes/{taskId}`
  - `/users/{uid}/habits/{habitId}`
  - `/users/{uid}/habit_logs/{logId}`
  - `/users/{uid}/streaks/{streakId}`
  - `/users/{uid}/goals/{goalId}`
  - `/users/{uid}/identity_profile/main`
  - `/users/{uid}/events/{eventId}`
  - `/users/{uid}/events_recent/{eventId}`
  - `/users/{uid}/scheduled_notifications/{notificationId}`
  - `/users/{uid}/notificationLog/{logId}`
  - `/users/{uid}/suggestions/{suggestionId}`
  - `/users/{uid}/coach_messages/{messageId}`
  - `/users/{uid}/coach_speak_log/{logId}`
  - `/users/{uid}/ai_context_snapshots/{snapshotId}`
  - `/users/{uid}/dailySummaries/{date}`
  - `/users/{uid}/weeklySummaries/{weekKey}`
  - `/users/{uid}/devices/{deviceId}`
  - `/users/{uid}/data_exports/{exportId}`
  - `/users/{uid}/deletion_requests/{requestId}`
  - `/users/{uid}/usage/{monthKey}`
- Document routine template structure in `/routine/current`:
  - fixed schedule
  - skin care
  - supplements
  - classes
  - eating
  - custom one-off/repeating templates
- Required task materialization fields:
  - `sourceRoutineType`, `routineTemplateId`, `scheduledDate`, `plannedStart`, `plannedEnd`, `repeatRule`, `materializedFromTemplateAt`.
- Rules:
  - Users can read/write only their own subtree.
  - Events are create-only after creation.
  - Server-only fields are protected where practical.
- Indexes:
  - tasks by `scheduledDate`, `plannedStart`, `status`, `sourceRoutineType`.
  - events_recent by `eventName`, `timestamp`.
  - suggestions by `status`, `createdAt`.
  - scheduled_notifications by `status`, `fireAt`.

#### Dependencies

- Task 2.1.

#### How to verify

- UI: app still loads all six tabs.
- Firebase console: new writes use documented paths.
- Emulator/rules: user cannot access another user's data.
- Logs: no missing-index errors.

#### Estimate

4h

#### Done Criteria

- [ ] Schema mapping exists.
- [ ] Rules protect user data.
- [ ] Indexes cover production queries.
- [ ] Paths are consistent.

## Phase 3 - Task, Routine, and Day Lifecycle

### Task 3.1 - Complete TaskService contract

#### Why

Routine execution, notifications, day close, and AI learning depend on task correctness.

#### What to tell Antigravity

- MODIFY `lib/services/task_service.dart`.
- MODIFY `lib/models/task_model.dart`.
- MODIFY `lib/core/constants/event_names.dart`.
- MODIFY `test/services/task_service_contract_test.dart`.
- Required methods:
  - `createTask`
  - `watchTask`
  - `watchTasksForDay`
  - `watchTasksForWindow`
  - `watchActiveTask`
  - `startTask`
  - `pauseTask`
  - `resumeTask`
  - `completeTask`
  - `abandonTask`
  - `skipTask`
  - `deleteTask`
  - `checkSubtask`
  - `uncheckSubtask`
  - `syncRoutineTasks`
- Firestore:
  - `/users/{uid}/tasks/{taskId}`
  - `/users/{uid}/task_outcomes/{taskId}`
- State machine:
  - scheduled -> started -> paused/resumed -> completed
  - scheduled -> skipped
  - started/paused -> abandoned
  - completed/skipped/abandoned are terminal.
- Enforce only one active task unless product explicitly allows multiple.
- Events:
  - task and subtask events from Section 3.
- Error states:
  - missing task
  - invalid transition
  - active task conflict
  - offline write queued

#### Dependencies

- Task 2.1.
- Task 2.2.

#### How to verify

- Tests cover each transition.
- Firebase console: task status/timestamps update.
- Events: each action creates one valid event.
- UI: Routine tab still reads tasks.

#### Estimate

1 day

#### Done Criteria

- [ ] Task methods exist.
- [ ] State machine is enforced.
- [ ] Subtasks persist.
- [ ] Events match contracts.

### Task 3.2 - Fix daily routine materialization from reusable templates

#### Why

Fixed schedule, skin care, supplements, classes, and eating must appear automatically on the correct day.

#### What to tell Antigravity

- MODIFY `lib/providers/routine_provider.dart`.
- MODIFY `lib/repositories/routine_repository.dart`.
- MODIFY `lib/services/task_service.dart` only through existing contract methods.
- Firestore:
  - Read `/users/{uid}/routine/current`.
  - Write `/users/{uid}/tasks/{taskId}`.
- Implement idempotent materialization:
  - For selected date in Routine tab.
  - For today after onboarding.
  - For app start/day start.
  - For routine edit.
- Deterministic task id pattern:
  - include `scheduledDate`, `routineType`, and `templateId`.
- Preserve history:
  - Do not overwrite completed/skipped/abandoned historical tasks.
  - Edits update future days only.
- Fixed schedule:
  - repeat daily.
- Classes:
  - repeat by weekday/date rule.
- Eating:
  - repeat daily or by mess menu weekday rule.
- Skin care/supplements:
  - repeat by configured day/time/timing rule.
- Events:
  - `task_scheduled` only for newly created task instances.

#### Dependencies

- Task 1.3.
- Task 3.1.

#### How to verify

- UI: choose tomorrow in Routine tab and see fixed schedule tasks.
- Firebase console: tasks exist once per date/template.
- Run materialization twice: no duplicates.
- Complete today's task, edit template, completed task remains unchanged.

#### Estimate

1 day

#### Done Criteria

- [ ] Fixed schedule repeats every day.
- [ ] No duplicate tasks.
- [ ] Future edits preserve history.
- [ ] All routine types can materialize.

### Task 3.3 - Build Routine tab controls: Add button, AI button, selected day

#### Why

Users need to add tasks to any day and access AI suggestions clearly.

#### What to tell Antigravity

- MODIFY `lib/views/routine/routine_tab.dart`.
- MODIFY `lib/views/routine/add_task_sheet.dart`.
- MODIFY `lib/views/routine/ai_routine_panel.dart`.
- MODIFY `lib/views/routine/timeline_section.dart`.
- MODIFY `lib/views/routine/timeline_zoom_views.dart`.
- MODIFY `lib/core/providers.dart`.
- UI behavior:
  - Replace confusing add toggle with clear Add button.
  - Add button opens sheet for selected date.
  - User enters title, date, time, duration, routine type/category, notes, reminder toggle.
  - User chooses one-off task or repeating routine template.
  - AI button opens suggestions panel.
  - Timeline shows tasks for selected day.
  - Task rows expose Start, Pause, Resume, Complete, Skip, Abandon as status allows.
  - Loading/error/empty states exist.
- Firestore:
  - One-off: `/users/{uid}/tasks/{taskId}` with `scheduledDate`.
  - Repeating: `/users/{uid}/routine/current.templates.custom`.
  - Suggestions: `/users/{uid}/suggestions/{suggestionId}`.
- Events:
  - `task_scheduled`
  - task lifecycle events
  - suggestion events
  - `notification_scheduled` if reminder enabled.

#### Dependencies

- Task 3.1.
- Task 3.2.
- Task 8.3 for final AI suggestions.

#### How to verify

- UI: add task to tomorrow; it appears tomorrow only.
- UI: add repeating task; it appears on future selected days.
- UI: AI button opens panel.
- Firebase console: correct task/template docs.
- Events: expected events emitted.

#### Estimate

1 day

#### Done Criteria

- [ ] Add button exists.
- [ ] Any selected day task creation works.
- [ ] AI button exists.
- [ ] Status-aware task controls work.

### Task 3.4 - Complete routine setup screens and new supplement setup

#### Why

Routine setup must be fast and not require users to manually create too many tasks.

#### What to tell Antigravity

- MODIFY `lib/views/routine/fixed_schedule_setup_screen.dart`.
- MODIFY `lib/views/routine/skin_care_setup_screen.dart`.
- MODIFY `lib/views/routine/eating_setup_screen.dart`.
- MODIFY `lib/views/routine/class_setup_screen.dart`.
- CREATE `lib/views/routine/supplement_setup_screen.dart`.
- MODIFY `lib/views/routine/routine_settings_sheet.dart`.
- MODIFY `lib/views/tabs/routine_settings_screen.dart`.
- MODIFY `lib/providers/routine_provider.dart`.
- MODIFY `lib/repositories/routine_repository.dart`.
- UI setup modes:
  - Fixed schedule: manual unlimited daily blocks.
  - Skin care: Manual, Text Input with AI, Photo Upload with AI.
  - Supplements: Manual, Text Input with AI.
  - Classes: Manual, Upload timetable image/screenshot.
  - Eating: Manual, Upload Mess Menu Photo, Generate with AI.
- Manual fields:
  - title/name, time/timing rule, duration if relevant, dosage/food/class room/product notes, repeat days, reminder.
- AI/import behavior:
  - upload or text input goes to backend endpoint from Task 8.5.
  - generated items display in review/edit screen before saving.
  - user can edit, remove, accept all, regenerate.
- Firestore:
  - `/users/{uid}/routine/current.templates.{routineType}`
  - `/users/{uid}/routine/current.imports.{routineType}` for source text/image metadata if needed.
- Events:
  - routine template events after added to contract.
  - `task_scheduled` when materialized.
  - `notification_scheduled` for reminders.

#### Dependencies

- Task 3.2.
- Task 8.5 for AI/photo modes.

#### How to verify

- UI: each setup screen opens from Routine settings.
- UI: manual save updates Routine timeline.
- UI: generated items can be reviewed before save.
- Firebase console: routine templates saved.
- Expected data: selected-day tasks materialize without duplicates.

#### Estimate

2 days

#### Done Criteria

- [ ] Fixed schedule unlimited setup works.
- [ ] Skin care has 3 setup modes.
- [ ] Supplement setup exists with 2 modes.
- [ ] Class setup supports upload mode.
- [ ] Eating setup has 3 modes.
- [ ] Review-before-save exists.

### Task 3.5 - Implement day start, day close, and mission ring

#### Why

Daily summaries, streaks, identity progress, AI, and analytics depend on day lifecycle.

#### What to tell Antigravity

- MODIFY `lib/services/routine_service.dart`.
- MODIFY `lib/models/day_summary_model.dart`.
- MODIFY `lib/views/tabs/home_tab.dart`.
- MODIFY `lib/core/providers.dart`.
- MODIFY `functions/jobs/dayClose.js`.
- Firestore:
  - `/users/{uid}/dailySummaries/{date}`
  - `/users/{uid}/tasks/{taskId}`
  - `/users/{uid}/habit_logs/{logId}`
  - `/users/{uid}/streaks/{streakId}`
  - `/users/{uid}/identity_profile/main`
- Day start:
  - Emit `day_started` once per local date.
  - Materialize today's templates.
  - Build context snapshot.
- Day close:
  - Close all missed days in order.
  - Mark overdue tasks abandoned/skipped by contract.
  - Compute task completion, routine completion, focus minutes, habit completion, slips, streak inputs, identity inputs, mission score.
  - Emit `routine_block_completed`, `routine_day_summarized`, `day_closed`.
- UI:
  - Home mission ring uses documented formula.
  - End-of-day prompt appears after sleep block or configured time.
  - Empty/loading states for new users.

#### Dependencies

- Task 3.1.
- Task 3.2.
- Task 4.1.
- Task 5.1.

#### How to verify

- UI: completing tasks/habits updates mission ring.
- Firebase console: daily summary contains all fields.
- Run day close twice: no duplicate events.
- Cloud Functions emulator writes same shape.

#### Estimate

1 day

#### Done Criteria

- [ ] Day start is idempotent.
- [ ] Day close handles missed days.
- [ ] Mission ring works.
- [ ] Summaries are complete.

## Phase 4 - Habit and Tracker System

### Task 4.1 - Complete HabitService lifecycle

#### Why

Tracker, streaks, recovery, identity, and AI need reliable habit logs.

#### What to tell Antigravity

- MODIFY `lib/services/habit_service.dart`.
- MODIFY `lib/models/habit_model.dart`.
- MODIFY `lib/models/habit_log_model.dart`.
- MODIFY `test/services/habit_service_contract_test.dart`.
- Required methods:
  - `createHabit`, `updateHabit`, `pauseHabit`, `resumeHabit`, `archiveHabit`, `deleteHabit`
  - `logGood`, `logSlip`, `deleteLog`
  - `watchHabits`, `watchHabitLogsForDate`, `dailyTotal`
- Firestore:
  - canonical: `/users/{uid}/habit_logs/{logId}`
  - habit docs: `/users/{uid}/habits/{habitId}`
  - keep nested logs only for migration compatibility.
- Events:
  - habit lifecycle and habit log events from Section 3.
- Validation:
  - blank name rejected.
  - invalid target rejected.
  - negative log amount rejected.
  - delete requires confirmation if destructive.

#### Dependencies

- Task 2.1.
- Task 2.2.

#### How to verify

- Tests pass.
- Firebase console: habit docs and log docs match schema.
- Events: each lifecycle/log action emits valid event.
- Totals update after delete/undo.

#### Estimate

1 day

#### Done Criteria

- [ ] Full lifecycle works.
- [ ] Logs are canonical.
- [ ] Events match contract.
- [ ] Undo/delete works.

### Task 4.2 - Build Home and Tracker quick logging

#### Why

Logging must be one-tap fast from daily surfaces.

#### What to tell Antigravity

- MODIFY `lib/views/tabs/home_tab.dart`.
- MODIFY `lib/views/tabs/tracker_tab.dart`.
- MODIFY `lib/views/habits/log_habit_sheet.dart`.
- MODIFY `lib/core/providers.dart`.
- UI:
  - Home habit pills/cards are tappable.
  - Good habit sheet supports amount, unit, note.
  - Bad habit sheet supports trigger, count, note, recovery copy.
  - Tracker cards show Log, Undo latest, Details.
  - Loading/error/empty states exist.
- Firestore:
  - `/users/{uid}/habit_logs/{logId}`.
- Events:
  - `good_habit_logged`
  - `bad_habit_slip_logged`
  - `habit_log_deleted`

#### Dependencies

- Task 4.1.

#### How to verify

- UI: log good habit from Home.
- UI: log bad habit from Tracker.
- Firebase console: one log per action.
- Events exist.
- Totals update.

#### Estimate

4h

#### Done Criteria

- [ ] Home quick log works.
- [ ] Tracker quick log works.
- [ ] Undo latest is visible.
- [ ] Empty/loading/error states exist.

### Task 4.3 - Add habit management UI

#### Why

Users need to manage habits after onboarding.

#### What to tell Antigravity

- CREATE `lib/views/habits/habit_editor_screen.dart`.
- CREATE `lib/views/habits/habit_detail_screen.dart`.
- MODIFY `lib/views/tabs/tracker_tab.dart`.
- MODIFY `lib/core/router/app_router.dart`.
- UI:
  - Add Habit entry point.
  - Editor supports type, category, name, target, unit, schedule, money value, accountability, reminders.
  - Detail supports Edit, Pause, Resume, Archive.
  - Delete only from Profile or double-confirmed admin path.
- Firestore:
  - `/users/{uid}/habits/{habitId}`
  - `/users/{uid}/scheduled_notifications/{notificationId}` if reminders.
- Events:
  - `habit_created`, `habit_updated`, `habit_paused`, `habit_resumed`, `habit_archived`, optional `habit_deleted`.

#### Dependencies

- Task 4.1.
- Task 7.1 for final reminders.

#### How to verify

- UI: create/edit/pause/resume/archive.
- Firebase console: status updates.
- Events exist.
- Archived habits not shown in active daily cards.

#### Estimate

1 day

#### Done Criteria

- [ ] Habit editor exists.
- [ ] Habit detail exists.
- [ ] Pause/resume/archive works.
- [ ] Validation works.

### Task 4.4 - Build tracker-specific variants

#### Why

The Tracker must be more than generic counters.

#### What to tell Antigravity

- MODIFY `lib/views/tabs/tracker_tab.dart`.
- MODIFY `lib/views/habits/habit_detail_screen.dart`.
- CREATE:
  - `lib/views/habits/variants/smoking_tracker_view.dart`
  - `lib/views/habits/variants/screen_time_tracker_view.dart`
  - `lib/views/habits/variants/mindful_eating_tracker_view.dart`
  - `lib/views/habits/variants/procrastination_tracker_view.dart`
  - `lib/views/habits/variants/hydration_tracker_view.dart`
  - `lib/views/habits/variants/meditation_tracker_view.dart`
  - `lib/views/habits/variants/money_saving_tracker_view.dart`
  - `lib/views/habits/variants/reading_tracker_view.dart`
  - `lib/views/habits/variants/exercise_tracker_view.dart`
  - `lib/views/habits/variants/routine_completion_tracker_view.dart`
- Each variant must show:
  - today status
  - 7-day history
  - log action
  - insight/AI interpretation placeholder
  - empty/loading/error states.
- Firestore:
  - read `/habits`, `/habit_logs`, `/streaks`, `/dailySummaries`.
- Events:
  - use HabitService only for writes.

#### Dependencies

- Task 4.2.
- Task 5.1 for streak data.

#### How to verify

- UI: open every variant from Tracker.
- Firebase console: logs update for each log action.
- Expected data: routine completion variant reads daily summaries, not manual-only logs.

#### Estimate

2 days

#### Done Criteria

- [ ] Variant screens exist.
- [ ] Each has user-visible path.
- [ ] Logging works where relevant.
- [ ] Empty states are safe.

## Phase 5 - Streaks, Accountability, and Retention

### Task 5.1 - Implement production streak rules

#### Why

Streaks must respect accountability mode, grace, bad habits, routines, and ghost days.

#### What to tell Antigravity

- MODIFY `lib/services/streak_service.dart`.
- MODIFY `lib/models/streak_model.dart`.
- MODIFY `test/services/streak_service_contract_test.dart`.
- Firestore:
  - `/users/{uid}/streaks/{streakId}`
  - `/users/{uid}/habit_logs/{logId}`
  - `/users/{uid}/dailySummaries/{date}`
- Implement:
  - good habit streaks
  - bad habit clean streaks
  - routine completion streaks
  - milestone detection: 3, 7, 14, 30, 60, 90, 180, 365
  - Forgiving, Strict, Ruthless accountability
  - ghost pause/resume behavior
- Events:
  - `streak_extended`, `streak_broken`, `streak_milestone_reached`, `streak_paused`, `streak_resumed`.

#### Dependencies

- Task 4.1.
- Task 3.5.

#### How to verify

- Tests cover each accountability mode.
- Firebase console: streak docs update.
- Events emitted once.
- UI cards reflect changes.

#### Estimate

1 day

#### Done Criteria

- [ ] Streak rules match docs.
- [ ] Milestones work.
- [ ] Accountability modes work.
- [ ] Ghost pause/resume works.

### Task 5.2 - Build streak detail and heatmap UI

#### Why

Users need to see history and trust the streak math.

#### What to tell Antigravity

- CREATE `lib/views/streaks/streak_detail_screen.dart`.
- CREATE `lib/views/streaks/streak_heatmap.dart`.
- MODIFY `lib/views/tabs/home_tab.dart`.
- MODIFY `lib/views/tabs/tracker_tab.dart`.
- MODIFY `lib/core/router/app_router.dart`.
- UI:
  - Home streak card opens detail.
  - Tracker habit detail links to streak detail.
  - Detail shows heatmap, milestones, accountability mode, history, pause status.
- Firestore:
  - read `/streaks`, `/habit_logs`, `/dailySummaries`.

#### Dependencies

- Task 5.1.

#### How to verify

- UI: open from Home and Tracker.
- Empty state: new user no streaks.
- Data: heatmap matches logs.

#### Estimate

4h

#### Done Criteria

- [ ] Detail screen exists.
- [ ] Heatmap exists.
- [ ] Data matches logs.

### Task 5.3 - Implement ghost-day and comeback flow

#### Why

Retention must be humane and preserve user continuity.

#### What to tell Antigravity

- MODIFY `lib/services/routine_service.dart`.
- MODIFY `lib/services/streak_service.dart`.
- MODIFY `functions/jobs/inactivityCheck.js`.
- CREATE `lib/views/comeback/comeback_modal.dart`.
- MODIFY `lib/views/screens/home_screen.dart`.
- Firestore:
  - `/users/{uid}/dailySummaries/{date}`
  - `/users/{uid}/streaks/{streakId}`
  - `/users/{uid}/suggestions/{suggestionId}`
- Behavior:
  - detect 1/3/7/14/30 day absence.
  - pause streaks for ghost grace.
  - show comeback modal after return.
  - offer easy day restart plan.
  - force supportive coach tone temporarily.
- Events:
  - `ghost_day_detected`
  - `comeback_initiated`
  - `streak_paused`
  - `streak_resumed`

#### Dependencies

- Task 5.1.
- Task 8.3 for suggestions.

#### How to verify

- Emulator: seed lastSeen 4 days ago.
- UI: comeback modal appears.
- Firebase console: streaks paused/resumed and suggestions exist.
- Events emitted.

#### Estimate

1 day

#### Done Criteria

- [ ] Ghost detection works.
- [ ] Comeback modal exists.
- [ ] Restart plan is visible.
- [ ] Streak rules are respected.

## Phase 6 - Goals and Identity

### Task 6.1 - Complete identity and goal services

#### Why

Goals must drive daily tasks, habits, mission ring, and AI context.

#### What to tell Antigravity

- MODIFY `lib/models/goal_model.dart`.
- MODIFY `lib/models/identity_profile_model.dart`.
- MODIFY `lib/repositories/goal_repository.dart`.
- MODIFY `lib/providers/goal_provider.dart`.
- MODIFY `lib/providers/identity_provider.dart`.
- MODIFY `lib/services/state_aggregator_service.dart`.
- Firestore:
  - `/users/{uid}/goals/{goalId}`
  - `/users/{uid}/identity_profile/main`
  - `/users/{uid}/habits/{habitId}`
  - `/users/{uid}/tasks/{taskId}`
- Goal fields:
  - `goalId`, `title`, `identityTag`, `why`, `status`, `weight`, `progress`, `targetDate`, `milestones`, `connectedHabitIds`, `connectedRoutineTypes`, `createdAt`, `updatedAt`, `archivedAt`.
- Events:
  - `identity_created`, `identity_updated`, `identity_paused`, `identity_archived`, `identity_habit_linked`, `identity_progress_changed`, `milestone_completed`.

#### Dependencies

- Task 3.5.
- Task 4.1.
- Task 5.1.

#### How to verify

- Firebase console: goal and identity docs match schema.
- Aggregator handles no-goal users.
- Event emitted when progress changes.

#### Estimate

1 day

#### Done Criteria

- [ ] Goal schema complete.
- [ ] Identity schema complete.
- [ ] Progress computation works.

### Task 6.2 - Build full Goals tab flows

#### Why

Users need to create and maintain identities from the Goals tab.

#### What to tell Antigravity

- MODIFY `lib/views/tabs/goals_tab.dart`.
- CREATE `lib/views/goals/goal_editor_screen.dart`.
- CREATE `lib/views/goals/goal_detail_screen.dart`.
- CREATE `lib/views/goals/milestone_editor_sheet.dart`.
- MODIFY `lib/core/router/app_router.dart`.
- UI:
  - identity statement
  - today's identity push
  - active goals grid
  - archived goals section
  - add/edit/detail goal
  - milestones
  - why score explanation
  - connect habits/routine types
  - pause/archive
- Firestore:
  - `/goals`, `/identity_profile/main`.
- Events:
  - identity and milestone events.
- AI:
  - placeholder area until Phase 8 suggestions.

#### Dependencies

- Task 6.1.

#### How to verify

- UI: create goal, add milestone, complete milestone, connect habit, archive.
- Firebase console: fields update.
- Navigation works.

#### Estimate

1 day

#### Done Criteria

- [ ] Goal flows exist.
- [ ] Milestones work.
- [ ] Why score visible.
- [ ] User can access all flows.

### Task 6.3 - Connect identity to Home, Profile, and AI context

#### Why

Identity must be visible across the product, not isolated in Goals.

#### What to tell Antigravity

- MODIFY `lib/views/tabs/home_tab.dart`.
- MODIFY `lib/views/tabs/profile_tab.dart`.
- MODIFY `lib/services/state_aggregator_service.dart`.
- MODIFY `lib/models/context_snapshot.dart`.
- Firestore:
  - read `/identity_profile/main`
  - write `/ai_context_snapshots/{snapshotId}`
- UI:
  - Home shows today's identity push.
  - Profile shows identity hero, strengths, areas to improve.
  - Mission ring weights identity-aligned work.
- Events:
  - `identity_progress_changed`.

#### Dependencies

- Task 6.1.
- Task 3.5.

#### How to verify

- Complete connected task/habit.
- Home and Profile update.
- Context snapshot includes identity tags.

#### Estimate

4h

#### Done Criteria

- [ ] Home identity push exists.
- [ ] Profile identity hero exists.
- [ ] AI context includes identity.

## Phase 7 - Notifications and Custom Alarms

### Task 7.1 - Complete notification lifecycle service

#### Why

Notifications need durable records and lifecycle events, not only local scheduling.

#### What to tell Antigravity

- MODIFY `lib/services/notification_service.dart`.
- MODIFY `lib/models/scheduled_notification_model.dart`.
- MODIFY `lib/core/event_orchestrator.dart`.
- MODIFY `lib/main.dart`.
- Firestore:
  - `/users/{uid}/scheduled_notifications/{notificationId}`
  - `/users/{uid}/notificationLog/{logId}`
  - `/users/{uid}/events_recent/{eventId}`
- Methods:
  - `requestPermissions`
  - `scheduleForTask`
  - `scheduleForRoutineTemplate`
  - `scheduleCustom`
  - `cancel`
  - `reRegisterAllOnAppStart`
  - `recordSent`
  - `recordTapped`
  - `recordDismissed`
  - `recordSuppressed`
  - `recordMissed`
- Support template-generated notifications with dedupe by routine template id, date, time.
- Template-generated notifications must support fixed schedule, skin care, supplements, classes, eating, selected-date one-off tasks, and custom repeating tasks.
- Events:
  - notification lifecycle events.

#### Dependencies

- Task 2.1.
- Task 2.2.
- Task 3.2.

#### How to verify

- UI: schedule task reminder and tap notification.
- Firebase console: scheduled and log docs exist.
- App restart: pending notifications re-register.
- No duplicate reminders for same template/date/time.

#### Estimate

1 day

#### Done Criteria

- [ ] Lifecycle methods exist.
- [ ] Deep links work.
- [ ] Re-registration works.
- [ ] Dedupe works.

### Task 7.2 - Build notification center and settings

#### Why

Users need control over notification budget, quiet hours, and categories.

#### What to tell Antigravity

- CREATE `lib/views/notifications/notification_center_screen.dart`.
- CREATE `lib/views/settings/notification_settings_screen.dart`.
- MODIFY `lib/views/tabs/home_tab.dart`.
- MODIFY `lib/views/tabs/profile_tab.dart`.
- MODIFY `lib/core/router/app_router.dart`.
- MODIFY `lib/services/notification_service.dart`.
- Firestore:
  - `/users/{uid}/profile/main.notificationSettings`
  - `/users/{uid}/scheduled_notifications/{notificationId}`
  - `/users/{uid}/notificationLog/{logId}`
- UI:
  - Home bell opens notification center.
  - Profile opens notification settings.
  - category toggles.
  - routine category controls include fixed schedule, skin care, supplements, classes, eating, and custom tasks.
  - quiet hours.
  - daily cap.
  - rolling 60-minute cap display.
  - permission status.
- Events:
  - `notification_settings_changed`.

#### Dependencies

- Task 7.1.

#### How to verify

- UI: change settings, return, values persist.
- Firebase console: settings update.
- Disabled category cancels/suppresses notifications.

#### Estimate

1 day

#### Done Criteria

- [ ] Notification center exists.
- [ ] Settings screen exists.
- [ ] Caps and quiet hours persist.

### Task 7.3 - Add custom alarm UX

#### Why

Custom alarms are a core promise for routine enforcement.

#### What to tell Antigravity

- CREATE `lib/views/alarms/alarm_editor_screen.dart`.
- CREATE `lib/views/alarms/alarm_ringing_screen.dart`.
- CREATE `lib/views/alarms/snooze_reason_sheet.dart`.
- MODIFY `lib/views/routine/add_task_sheet.dart`.
- MODIFY `lib/views/routine/timeline_section.dart`.
- MODIFY `lib/services/notification_service.dart`.
- Firestore:
  - `/scheduled_notifications/{notificationId}`
  - `/notificationLog/{logId}`
- UI:
  - create alarm for task/routine.
  - ringing screen with stop/snooze.
  - snooze requires reason.
  - reason feeds AI context later.
- Events:
  - notification events.
  - `task_started` if user starts from alarm.

#### Dependencies

- Task 7.1.
- Task 3.3.

#### How to verify

- UI: create alarm, simulate ringing, snooze with reason, stop.
- Firebase console: lifecycle logs and snooze reason.
- Deep link opens task.

#### Estimate

1 day

#### Done Criteria

- [ ] Alarm editor exists.
- [ ] Ringing screen exists.
- [ ] Snooze reason is saved.

## Phase 8 - AI Master Engine and Coach

### Task 8.1 - Complete context snapshots and rule engine

#### Why

AI must decide from structured state, not raw chat guesses.

#### What to tell Antigravity

- MODIFY `lib/services/state_aggregator_service.dart`.
- MODIFY `lib/services/rule_engine_service.dart`.
- MODIFY `lib/models/context_snapshot.dart`.
- MODIFY `lib/models/coach_rule.dart`.
- CREATE `lib/models/ai_rule_log_model.dart`.
- Firestore:
  - `/users/{uid}/ai_context_snapshots/{snapshotId}`
  - `/users/{uid}/coach_speak_log/{logId}`
  - `/users/{uid}/events_recent/{eventId}`
- Snapshot includes:
  - profile/About You, goals, identity, routine templates, today tasks, habit logs, streaks, notifications, recent events, screen time, safety flags.
- Rule engine:
  - evaluates events.
  - respects speak budget, cooldowns, quiet hours, safety.
  - can generate suggestions or coach messages.

#### Dependencies

- Phases 2 through 7.

#### How to verify

- Seed user data.
- Build snapshot.
- Run rules.
- Logs show why rule spoke or stayed silent.

#### Estimate

1 day

#### Done Criteria

- [ ] Context snapshot complete.
- [ ] Rules use structured state.
- [ ] Speak budget works.

### Task 8.2 - Complete Coach chat and topic modes

#### Why

Coach must be evented, persistent, safe, and mode-aware.

#### What to tell Antigravity

- MODIFY `lib/views/tabs/coach_tab.dart`.
- MODIFY `lib/services/coach_service.dart`.
- MODIFY `lib/services/gemini_service.dart`.
- MODIFY `functions/index.js`.
- Firestore:
  - `/users/{uid}/coach_messages/{messageId}`
  - `/users/{uid}/coach_speak_log/{logId}`
  - `/users/{uid}/events_recent/{eventId}`
- UI:
  - chat history.
  - topic modes: Recovery, Study, Fitness, Calm, Ask Anything.
  - loading/streaming state.
  - error retry.
  - safety response state.
- Events:
  - `coach_message_sent`
  - `coach_replied`
- Backend:
  - Cloud Function owns Gemini call.
  - no API key in Flutter.
  - crisis/self-harm uses safe non-LLM handoff.
  - medical/legal/financial advice boundary.

#### Dependencies

- Task 8.1.
- Task 1.2.

#### How to verify

- UI: send message in each mode.
- Firebase console: messages persist.
- Events exist.
- Crisis-like input returns safe path.

#### Estimate

1 day

#### Done Criteria

- [ ] Chat persists.
- [ ] Topic modes work.
- [ ] Events emitted.
- [ ] Safety path exists.

### Task 8.3 - Implement SuggestionService and Routine AI panel

#### Why

Routine AI suggestions must be reviewable, accepted, edited, or dismissed.

#### What to tell Antigravity

- CREATE `lib/models/suggestion_model.dart`.
- CREATE `lib/services/suggestion_service.dart`.
- CREATE `lib/views/suggestions/suggestion_detail_sheet.dart`.
- MODIFY `lib/views/routine/ai_routine_panel.dart`.
- MODIFY `lib/views/routine/routine_tab.dart`.
- MODIFY `lib/core/providers.dart`.
- Firestore:
  - `/users/{uid}/suggestions/{suggestionId}`
- Suggestion fields:
  - `suggestionId`, `type`, `title`, `body`, `reason`, `targetPath`, `status`, `priority`, `targetDate`, `createdAt`, `expiresAt`, `acceptedAt`, `dismissedAt`, `sourceRuleId`.
- UI:
  - AI button opens panel.
  - suggestions for gym, coding, reading, meditation, strong body, language learning, recovery.
  - accept/edit/dismiss.
  - ask AI text bar returns suggestion cards.
- Events:
  - `suggestion_generated`
  - `suggestion_accepted`
  - `suggestion_dismissed`
- Accepting:
  - can create selected-date task or reusable routine template.

#### Dependencies

- Task 8.1.
- Task 3.3.

#### How to verify

- Seed suggestion.
- UI: accept, edit, dismiss.
- Firebase console: status updates.
- Accepted routine suggestion changes future tasks only.

#### Estimate

1 day

#### Done Criteria

- [ ] Suggestion model/service exists.
- [ ] Routine AI panel uses Firestore suggestions.
- [ ] Accept/edit/dismiss works.

### Task 8.4 - Implement AI routine import and generation endpoints

#### Why

Skin care, supplements, class timetables, and eating routines need AI without exposing keys in Flutter.

#### What to tell Antigravity

- CREATE `functions/ai/routineImport.js`.
- MODIFY `functions/index.js`.
- MODIFY `lib/services/gemini_service.dart` or create `lib/services/routine_ai_service.dart`.
- MODIFY setup screens from Task 3.4.
- Supported modes:
  - `skin_care_text`
  - `skin_care_photo`
  - `supplement_text`
  - `class_timetable_photo`
  - `eating_mess_photo`
  - `eating_goal_text`
  - `routine_goal_suggestions`
- Input:
  - user text, image reference, routine type, timezone, profile context, goals.
- Output:
  - structured items: title, routineType, suggested time, timing rule, weekday/date rule, dosage/food/product/class fields, notes, confidence, warnings.
- UI:
  - show review/edit screen before save.
  - accept all, edit, remove, regenerate.
  - extraction failure shows safe error and saves nothing.
- Events:
  - `suggestion_generated`
  - `suggestion_accepted`
  - `suggestion_dismissed`
- Backend:
  - validate AI JSON schema.
  - enforce usage caps later.
  - store no provider key in Flutter.

#### Dependencies

- Task 3.4.
- Task 8.1.
- Task 8.3.

#### How to verify

- Text: generate supplements/eating/skin care from typed list.
- Image: upload sample timetable/mess/skin care photo.
- UI: review before save.
- Firebase console: accepted items become templates and tasks.
- Logs: invalid AI output rejected.

#### Estimate

2 days

#### Done Criteria

- [ ] Endpoint exists.
- [ ] Text modes work.
- [ ] Image modes work.
- [ ] Review-before-save works.
- [ ] Accepted items materialize without duplicates.

### Task 8.5 - Implement strategic AI scheduled jobs

#### Why

The AI planner must run at day start, midday, day close, inactivity, and safety moments.

#### What to tell Antigravity

- MODIFY `functions/jobs/morningBrief.js`.
- MODIFY `functions/jobs/middayPulse.js`.
- MODIFY `functions/jobs/dayClose.js`.
- MODIFY `functions/jobs/inactivityCheck.js`.
- CREATE `functions/jobs/aiPlanner.js`.
- CREATE `functions/jobs/ruleEngine.js`.
- CREATE `functions/jobs/safety.js`.
- Firestore:
  - `/ai_context_snapshots`, `/coach_messages`, `/coach_speak_log`, `/suggestions`, `/scheduled_notifications`, `/events_recent`.
- Jobs:
  - morning creates day plan and suggestions.
  - midday checks drift.
  - day close writes summary.
  - inactivity creates comeback suggestions.
  - safety blocks unsafe normal coaching.
- Events:
  - `coach_replied`, `suggestion_generated`, `notification_scheduled`, `notification_suppressed`, `ghost_day_detected`, `day_closed`.

#### Dependencies

- Tasks 8.1 to 8.4.
- Task 7.2.

#### How to verify

- Run scheduled functions in emulator.
- Firebase console: messages/suggestions appear.
- Logs: users without data skipped safely.
- UI: Home/Coach/Routine show outputs.

#### Estimate

2 days

#### Done Criteria

- [ ] Jobs exist.
- [ ] Jobs use same schema.
- [ ] Outputs are user-visible.

## Phase 9 - Profile, Settings, Privacy, and Subscription

### Task 9.1 - Complete Profile settings hub

#### Why

Profile is the control center for identity, coach, accountability, About You, notifications, and account.

#### What to tell Antigravity

- MODIFY `lib/views/tabs/profile_tab.dart`.
- CREATE `lib/views/settings/coach_settings_screen.dart`.
- CREATE `lib/views/settings/accountability_settings_screen.dart`.
- CREATE `lib/views/settings/about_you_settings_screen.dart`.
- MODIFY `lib/core/router/app_router.dart`.
- Firestore:
  - `/users/{uid}/profile/main`
  - `/users/{uid}/identity_profile/main`
- UI:
  - identity statement editor.
  - strengths/areas to improve.
  - coach name/style/topic modes.
  - accountability settings.
  - About You editor.
  - notification settings link.
  - routine settings link.
- Events:
  - `identity_statement_updated`
  - `coach_settings_changed`
  - `accountability_changed`
  - `biometrics_updated`

#### Dependencies

- Task 6.3.
- Task 7.2.

#### How to verify

- UI: open every settings screen.
- Firebase console: edits persist.
- Events emitted.
- Navigation returns Profile.

#### Estimate

1 day

#### Done Criteria

- [ ] Profile exposes all settings.
- [ ] Settings persist.
- [ ] Events emit.

### Task 9.2 - Implement privacy, export, and deletion lifecycle

#### Why

Production apps need safe user data controls.

#### What to tell Antigravity

- CREATE `lib/views/settings/privacy_data_screen.dart`.
- MODIFY `lib/views/tabs/profile_tab.dart`.
- CREATE `functions/jobs/exportUserData.js`.
- CREATE `functions/jobs/deleteUserData.js`.
- MODIFY `functions/index.js`.
- MODIFY `firestore.rules`.
- Firestore:
  - `/users/{uid}/data_exports/{exportId}`
  - `/users/{uid}/deletion_requests/{requestId}`
- UI:
  - request export.
  - export status queued/processing/ready/failed.
  - request deletion with confirmation.
  - deletion has recovery window.
  - cancel pending deletion.
- Events:
  - `account_deleted` only after backend completes.
- Backend:
  - Cloud Function exports user subtree.
  - Cloud Function deletes after recovery window.
  - client must not recursively hard-delete directly.

#### Dependencies

- Task 2.2.

#### How to verify

- Emulator: request export/delete.
- Firebase console: request docs update status.
- Cancel deletion prevents delete.

#### Estimate

1 day

#### Done Criteria

- [ ] Privacy screen exists.
- [ ] Export lifecycle exists.
- [ ] Deletion queue exists.

### Task 9.3 - Add subscription and AI usage limits

#### Why

AI and notification costs need product and backend gates.

#### What to tell Antigravity

- CREATE `lib/views/settings/subscription_screen.dart`.
- MODIFY `lib/views/tabs/profile_tab.dart`.
- MODIFY `lib/services/coach_service.dart`.
- MODIFY `lib/services/notification_service.dart`.
- MODIFY `functions/index.js`.
- Firestore:
  - `/users/{uid}/profile/main.subscription`
  - `/users/{uid}/usage/{monthKey}`
- UI:
  - show plan.
  - show limits.
  - disabled upgrade CTA if payments not integrated.
- Backend:
  - enforce AI/routine import caps in Cloud Functions.
  - do not rely only on UI.

#### Dependencies

- Task 8.4.
- Task 7.2.

#### How to verify

- UI: subscription screen opens.
- Firebase console: usage counters increment.
- Backend blocks over-limit AI call with friendly error.

#### Estimate

1 day

#### Done Criteria

- [ ] Subscription screen exists.
- [ ] Usage counters exist.
- [ ] Backend cap exists.

## Phase 10 - Analytics, Cloud Functions, and Operations

### Task 10.1 - Implement analytics summaries

#### Why

Users and AI need daily/weekly summaries and product health needs metrics.

#### What to tell Antigravity

- CREATE `lib/services/analytics_service.dart`.
- MODIFY `lib/services/routine_service.dart`.
- MODIFY `lib/services/state_aggregator_service.dart`.
- MODIFY `functions/jobs/dayClose.js`.
- CREATE `functions/jobs/weeklySummary.js`.
- Firestore:
  - `/users/{uid}/dailySummaries/{date}`
  - `/users/{uid}/weeklySummaries/{weekKey}`
  - `/users/{uid}/events_recent/{eventId}`
- Metrics:
  - task completion
  - routine completion
  - habit completion
  - slip count
  - screen time
  - streak changes
  - identity score
  - notification lifecycle counts
  - AI messages/suggestions generated/accepted/dismissed
- UI:
  - daily summary on Home/Profile.
  - weekly summary in Profile or Tracker.
- Events:
  - `routine_day_summarized`
  - `weekly_insight_ready` if user-visible insight generated.

#### Dependencies

- Phases 3 through 8.

#### How to verify

- Seed data.
- Run day/weekly summary.
- UI shows summaries.
- Counts match event logs.

#### Estimate

1 day

#### Done Criteria

- [ ] Daily summary complete.
- [ ] Weekly summary complete.
- [ ] UI surfaces summaries.

### Task 10.2 - Implement server notification dispatcher

#### Why

Some reminders and re-engagement pushes need reliable backend delivery.

#### What to tell Antigravity

- CREATE `functions/jobs/notificationDispatcher.js`.
- MODIFY `functions/index.js`.
- MODIFY `lib/services/notification_service.dart`.
- Firestore:
  - `/scheduled_notifications`
  - `/notificationLog`
  - `/profile/main.notificationSettings`
  - `/devices/{deviceId}`
- Backend:
  - query due notifications.
  - respect caps, quiet hours, dedupe, settings.
  - send FCM if token exists.
  - mark pending_local if no token.
  - emit lifecycle events.

#### Dependencies

- Task 7.1.
- Task 7.2.

#### How to verify

- Emulator: seed due notification.
- Run dispatcher.
- Status becomes sent/suppressed/pending_local.
- Missing token handled safely.

#### Estimate

1 day

#### Done Criteria

- [ ] Dispatcher exists.
- [ ] Settings enforced server-side.
- [ ] Lifecycle logs written.

### Task 10.3 - Add cleanup, archive, and backfill jobs

#### Why

Production needs event trimming, schema migration, and safe backfills.

#### What to tell Antigravity

- CREATE `functions/jobs/eventMaintenance.js`.
- CREATE `functions/jobs/schemaBackfill.js`.
- MODIFY `functions/index.js`.
- Firestore:
  - `/events_recent`
  - `/events`
  - old paths documented in `docs/firestore_schema_v1_mapping.md`
- Backend:
  - trim `events_recent`.
  - preserve full `events`.
  - backfill missing `schemaVersion`, `uid`, normalized fields.
  - dry-run mode before write mode.

#### Dependencies

- Task 2.1.
- Task 2.2.

#### How to verify

- Emulator: seed old data.
- Dry-run logs exact changes.
- Write mode updates docs safely.

#### Estimate

1 day

#### Done Criteria

- [ ] Maintenance job exists.
- [ ] Backfill job exists.
- [ ] Dry-run exists.

### Task 10.4 - Add remote config and monitoring controls

#### Why

Production AI, notifications, imports, and experiments need kill switches.

#### What to tell Antigravity

- MODIFY `lib/services/remote_config_service.dart`.
- MODIFY `lib/main.dart`.
- MODIFY `lib/services/global_error_handler.dart`.
- MODIFY `functions/index.js`.
- Config keys:
  - `ai_enabled`
  - `routine_ai_import_enabled`
  - `image_upload_ai_enabled`
  - `proactive_coach_enabled`
  - `notifications_enabled`
  - `custom_alarms_enabled`
  - `screen_time_enabled`
  - `subscription_limits_enabled`
- UI:
  - disabled states are graceful.
- Backend:
  - functions check kill switches before generating AI/notifications.

#### Dependencies

- Tasks 7.2, 8.4, 10.2.

#### How to verify

- Disable AI import.
- UI shows disabled state.
- Function skips work.
- Logs explain skip reason.

#### Estimate

4h

#### Done Criteria

- [ ] Config keys exist.
- [ ] UI handles disabled features.
- [ ] Backend respects flags.

## Phase 11 - Production QA and Release

### Task 11.1 - Build full test suite

#### Why

Optivus handles identity, routines, habits, AI, and notifications. Release without tests is unsafe.

#### What to tell Antigravity

- ADD/UPDATE tests for:
  - auth and onboarding
  - unlimited fixed schedule
  - daily fixed schedule repeat
  - selected-day Add button
  - routine setup manual/AI/upload review flow
  - event validation/idempotency
  - task state machine
  - habit logs
  - streak rules
  - notification lifecycle
  - suggestions accept/dismiss
  - AI import endpoint schema
  - privacy export/delete
- Test locations:
  - `test/services/*`
  - `test/widgets/*`
  - `integration_test/*`
  - `functions/test/*`
- Do not skip meaningful assertions once feature is implemented.

#### Dependencies

- All implementation phases.

#### How to verify

- Run `flutter test`.
- Run integration tests.
- Run Firebase emulator function tests.
- Rules tests pass.

#### Estimate

2 days

#### Done Criteria

- [ ] Unit tests pass.
- [ ] Widget tests pass.
- [ ] Function tests pass.
- [ ] Critical integration smoke passes.

### Task 11.2 - Production migration and seed checklist

#### Why

Existing user data must not break after schema changes.

#### What to tell Antigravity

- CREATE `docs/migration_checklist.md`.
- CREATE `docs/seed_data_checklist.md`.
- Include:
  - old routine shapes to new template shape.
  - existing onboarding schedule to fixed templates.
  - existing tasks preserved.
  - existing habits/logs preserved.
  - notification paths normalized.
  - event schema versions backfilled.
- Provide emulator seed scenarios:
  - new user
  - existing onboarding user
  - completed onboarding user with fixed schedule
  - user with habits/streaks
  - ghost user
  - user with AI disabled.

#### Dependencies

- Task 10.3.

#### How to verify

- Run migration in emulator.
- Inspect seeded users.
- App opens each user without crash.

#### Estimate

1 day

#### Done Criteria

- [ ] Migration checklist exists.
- [ ] Seed checklist exists.
- [ ] Existing data preserved.

### Task 11.3 - Final completeness audit

#### Why

The product is only complete when every document feature has UI, backend, Firestore, events, and verification.

#### What to tell Antigravity

- MODIFY `docs/feature_matrix.md`.
- For every feature, verify:
  - user-visible UI path exists.
  - state/provider exists.
  - service/repository exists.
  - Firestore path exists.
  - event exists where needed.
  - Cloud Function/backend exists where needed.
  - AI integration exists where applicable.
  - notification integration exists where applicable.
  - tests or manual verification exist.
- Must include the urgent routine fixes:
  - unlimited fixed schedule
  - daily fixed schedule repeat
  - Routine Add button
  - Routine AI button
  - skin care manual/text/photo AI
  - supplement manual/text AI
  - class manual/upload
  - eating manual/mess photo/AI.

#### Dependencies

- All phases.

#### How to verify

- Open feature matrix.
- No row is `missing`.
- Every `partial` row has a blocking issue listed.
- Run full QA checklist.

#### Estimate

1 day

#### Done Criteria

- [ ] Every feature has UI.
- [ ] Every feature has Firestore/backend coverage.
- [ ] Every feature has verification.
- [ ] Release blockers are explicit.

## 7. Completeness Check

Before marking Optivus V1 production-ready, verify:

- [ ] Onboarding 0-10 exists and persists.
- [ ] Fixed schedule supports unlimited items.
- [ ] Fixed schedule repeats every day automatically.
- [ ] Routine tab Add button works for any selected day.
- [ ] Routine tab AI button works with reviewable suggestions.
- [ ] Skin care setup supports manual, text AI, photo AI.
- [ ] Supplement setup supports manual, text AI.
- [ ] Class setup supports manual and timetable upload.
- [ ] Eating setup supports manual, mess photo, AI generation.
- [ ] Events are validated and idempotent.
- [ ] Firestore rules and indexes match schema.
- [ ] Tasks, habits, streaks, goals, notifications, AI, analytics all have UI and backend paths.
- [ ] Cloud Functions run in emulator.
- [ ] No API keys are exposed in Flutter.
- [ ] Feature matrix has no missing production feature.

## 8. File Output

This is the required output file:

`todo_V1_(fixed)_All_Features.md`
