# Optivus Production TODO V1 Fixed - All Features

Generated after reading the current Flutter/Firebase codebase and all seven Optivus documents:

- `OPTIVUS Docs/1_Optivus_PRD.md`
- `OPTIVUS Docs/2_Optivus_UserFlow.md`
- `OPTIVUS Docs/3_Optivus_EventSystem.md`
- `OPTIVUS Docs/4_Optivus_SystemDesign_Production.md`
- `OPTIVUS Docs/5_Optivus_ServiceContracts.md`
- `OPTIVUS Docs/6_Optivus_AI_Master_Engine.md`
- `OPTIVUS Docs/7_Optivus_Database_Schema.md`

This is a planning document only. Do not write app code while using this file unless a specific task tells Antigravity to implement that task.

## 1. Short Summary

1. The app is not a fresh project. It already has a Flutter shell, Firebase setup, auth, onboarding, six main tabs, basic task/habit/streak/routine services, local notifications, and a basic AI coach.
2. The current codebase is directionally aligned with the documents but is not production-complete.
3. The biggest gap is not UI polish. The biggest gap is contract correctness across events, Firestore schema, service payloads, day lifecycle, notification lifecycle, and AI rule execution.
4. The User Flow document is the source of truth for what the user must see and do.
5. The Event System document is the source of truth for how modules communicate.
6. The Service Contracts document is the source of truth for service method behavior and event payloads.
7. The Database Schema document is the source of truth for Firestore paths.
8. The AI Master Engine document must not be implemented before the event spine and context snapshot are correct.
9. Existing working screens must be extended, not redesigned.
10. Existing services must be completed, not replaced wholesale.
11. Firestore must remain the source of truth. Do not introduce Postgres or a separate backend database.
12. All state-changing actions must write Firestore and emit a canonical event.
13. Every user-visible feature needs a UI path, state provider, Firestore path, backend/Cloud Function where needed, event triggers, verification, and done criteria.
14. Current onboarding has pages `0-9`; the docs require a stronger About You step and a final AI plan ready step.
15. Current task flows exist but are missing contract methods, strict payloads, custom alarm controls, synced subtasks, and full day-close handling.
16. Current habit flows exist but are missing create/update/archive events, edit/pause/archive UI, detail screens, undo/delete log, tracker variants, and safety behavior.
17. Current streak logic exists but is too simple for accountability, grace, ghost days, comeback, and milestone rules.
18. Current notification service exists but does not yet implement the full lifecycle: scheduled, sent, tapped, dismissed, suppressed, dedupe, caps, and deep links.
19. Current AI coach exists but is not yet the strategic AI master engine from the docs.
20. Current Goals tab is mostly read-only and needs full identity goal creation, detail, milestone, why score, and habit connection flows.
21. Current Profile tab needs settings depth: coach, accountability, notifications, About You editing, privacy, export, deletion queue, and subscription.
22. Current Cloud Functions exist but need event-triggered AI, proper scheduled jobs, FCM sends, cleanup/backfill jobs, and emulator tests.
23. Backend must come before UI polish.
24. Event system must come before AI.
25. Habit logs must come before streaks.
26. Tasks and routine logs must come before mission ring analytics.
27. Notification schema must come before custom alarms.
28. Profile/About You data must come before AI personalization.
29. Tests and emulator verification must be added phase by phase, not left until the end.
30. Completion means the user can navigate to and use every feature described in all seven documents.

## 2. Codebase Analysis

### Already Implemented

- Flutter app startup in `lib/main.dart` initializes Firebase, App Check, Firestore offline persistence, Remote Config, and Crashlytics.
- Routing exists in `lib/core/router/app_router.dart` for loading, welcome, login, signup, onboarding, and home.
- Bootstrap auth/onboarding routing exists in `lib/core/providers/bootstrap_provider.dart`.
- Email/password auth exists in `lib/services/auth_service.dart`, `lib/views/screens/signup_screen.dart`, and `lib/views/screens/login_screen.dart`.
- User root documents are created at `/users/{uid}` during signup.
- `user_signed_up` is already emitted by `AuthService.signUp`.
- Onboarding screens exist at `lib/views/onboarding/onboarding_page_0.dart` through `onboarding_page_9.dart`.
- Onboarding persistence exists in `lib/providers/onboarding_provider.dart` and `lib/repositories/user_repository.dart`.
- Onboarding writes `/users/{uid}/onboarding/state`, `/users/{uid}/profile/main`, and `/users/{uid}/identity_profile/main`.
- A six-tab home shell exists in `lib/views/screens/home_screen.dart`.
- Home, Routine, Tracker, Coach, Goals, and Profile tabs exist.
- Basic event infrastructure exists in `lib/services/event_service.dart`, `lib/models/event_model.dart`, and `lib/core/constants/event_names.dart`.
- Event replay and a local event bus exist.
- Basic task model and service exist in `lib/models/task_model.dart` and `lib/services/task_service.dart`.
- Routine setup screens exist for fixed schedule, skin care, eating, and classes.
- Routine timeline UI exists in `lib/views/routine/routine_tab.dart`, `timeline_section.dart`, and `timeline_zoom_views.dart`.
- Basic habit model, logs, and service exist in `lib/models/habit_model.dart`, `lib/models/habit_log_model.dart`, and `lib/services/habit_service.dart`.
- Habit logging sheet exists in `lib/views/habits/log_habit_sheet.dart`.
- Basic streak model and day-close service exist in `lib/models/streak_model.dart`, `lib/services/streak_service.dart`, and `lib/services/routine_service.dart`.
- Basic local notification service exists in `lib/services/notification_service.dart`.
- Basic notification suppression events exist.
- Android screen-time bridge/importer exists in `lib/services/screen_time_bridge.dart` and `lib/services/screen_time_importer.dart`.
- Coach tab and Gemini service exist in `lib/views/tabs/coach_tab.dart`, `lib/services/coach_service.dart`, and `lib/services/gemini_service.dart`.
- Cloud Function `aiGenerate` and scheduled jobs exist in `functions/index.js` and `functions/jobs/*.js`.
- Firestore rules and indexes exist in `firestore.rules` and `firestore.indexes.json`.

### Partially Implemented

- Auth exists, but Google/Apple providers and full auth lifecycle analytics are missing.
- Onboarding exists, but Page 5 About You is incomplete and Page 10 AI plan ready is missing.
- Onboarding completion materializes habits/goals/routine, but does not fully write the documented schema or schedule all notifications.
- EventService writes `/events` and `/events_recent`, but idempotency, schema validation, payload contracts, transaction semantics, and recent trimming are incomplete.
- TaskService has start/pause/resume/complete/abandon/skip, but does not fully match the Service Contracts document.
- Subtasks are displayed but UI checkbox changes are not reliably persisted through TaskService events.
- RoutineService closes only yesterday and does not fully compute routine percentage, mission ring, focus time, or missed-day backlog.
- HabitService logs good habits and bad slips, but create/update/pause/resume/archive/delete-log contracts are incomplete.
- StreakService has simple streak updates but lacks accountability modes, grace rules, ghost pause, comeback, and all milestone rules.
- NotificationService schedules basic local notifications but lacks custom alarm tiers, lifecycle events, deep links, send-time budgets, dedupe, and re-registration on app start.
- EventOrchestrator reacts to some local events but is not yet a complete production event listener layer.
- RuleEngineService has some rules but not the full AI rulebook from the AI Master Engine.
- StateAggregatorService builds a partial context snapshot but misses many required signals.
- Coach chat exists but does not emit canonical `coach_message_sent` and `coach_replied` events for every turn.
- Goals UI reads identity/goals but does not provide creation, detail, milestones, why score, pause/archive, or habit connections.
- Profile UI has basic account actions but lacks full settings, privacy, export/delete lifecycle, subscription, and About You editing.
- Cloud Functions run scheduled jobs but do not yet implement the full event-driven AI/notification/backend system.

### Not Implemented

- Full User Flow Page 5 About You with body basics, lifestyle, and sensitive context sub-pages.
- Final onboarding AI plan ready screen.
- Full onboarding-derived AI plan generation and user-visible explanation.
- Complete event payload validation and idempotent event writes.
- Event-driven listeners for tasks, habits, streaks, identity, AI, notification, analytics, and re-engagement.
- Full task state machine enforcement including active task exclusivity, complete-from-scheduled, synced subtasks, delete task, and task outcomes.
- Full routine daily loop including day start, automatic abandoned tasks, end-of-day review, tomorrow setup, and multi-day catch-up.
- Tracker-specific detail screens and variants: smoking, screen time, junk food/mindful eating safety, procrastination, hydration, meditation, money saving, reading, exercise/running, and daily routine completion meta-tracker.
- Good habit quick log from Home cards.
- Bad habit slip recovery flow with coalesced slip streak detection.
- Habit add/edit/pause/archive/undo log UI.
- Streak detail/history/heatmap UI.
- Ghost-day detection and comeback modal.
- Identity goal add/detail/edit/milestone/why-score/connected-habit flows.
- Notification center and notification settings UI.
- Custom alarm creation, ringing screen, snooze, stop, and alarm reason flows.
- Full P1-P6 notification priority model and rolling caps.
- Strategic AI planner, suggestion collection, accept/dismiss flows, speak log budget, and adaptive learning.
- Safety/crisis routing and handoff UX.
- Profile coach settings, accountability settings, About You editor, privacy controls, export queue, deletion queue, and subscription limits.
- Analytics dashboards/summaries and production monitoring tasks.
- Emulator/unit/widget/integration tests for the contracts.

### Needs Refactoring

- `lib/services/event_service.dart`: make event writes transactional, schema-validated, idempotent, and contract-aligned.
- `lib/core/event_orchestrator.dart`: keep it as the central reaction coordinator, but move domain-specific side effects behind event listener methods so services do not call each other directly.
- `lib/services/task_service.dart`: align method names, Firestore writes, state transitions, and event payloads to Service Contracts.
- `lib/services/habit_service.dart`: complete CRUD lifecycle events and exact log payloads.
- `lib/services/streak_service.dart`: replace simple pass/fail logic with accountability and ghost/comeback rules.
- `lib/services/routine_service.dart`: make day close timezone-aware, multi-day safe, and richer.
- `lib/services/notification_service.dart`: separate scheduling records, send/tap/dismiss logs, caps, custom alarms, and deep links.
- `lib/services/rule_engine_service.dart`: expand to the AI Master Engine rules and make rule inputs match emitted payloads.
- `lib/services/state_aggregator_service.dart`: include recent events, tasks, habits, goals, profile, screen time, notification logs, coach logs, and daily summaries.
- `functions/index.js` and `functions/jobs/*.js`: split callable AI, scheduled jobs, notification sending, cleanup, and event-triggered jobs into testable modules.

### Do Not Touch Unless Required

- Do not replace Flutter with another frontend stack.
- Do not move away from Firebase Auth, Firestore, and Cloud Functions.
- Do not introduce Postgres or a separate backend database.
- Do not rewrite the whole UI shell. Extend the existing tabs and screens.
- Do not remove the existing liquid/glass design language unless a specific screen is unreadable.
- Do not delete working auth/onboarding/routine/habit/task code. Complete and align it.
- Do not expose Gemini/API keys in Flutter. Keep AI secrets in Cloud Functions.
- Do not create root-level shared user data outside `/users/{uid}` except safe config collections already covered by rules.
- Do not weaken Firestore security rules to make development easier.
- Do not skip backend work for features that appear UI-only.

## 3. User Flow Breakdown

### Onboarding Flow

| Step | User action | UI screen | Backend action | Firestore write | Event triggered |
|---|---|---|---|---|---|
| 1 | Opens app | `WelcomeScreen` | None | None | None |
| 2 | Taps Get Started | `/signup` | None | None | None |
| 3 | Creates account | `SignupScreen` | `AuthService.signUp` creates Firebase Auth user and root user doc | `/users/{uid}` with uid, email, displayName/name, timezone, createdAt, updatedAt, schemaVersion, hasCompletedOnboarding=false | `user_signed_up` |
| 4 | Lands in onboarding | `OnboardingScreen` | Bootstrap sees `hasCompletedOnboarding=false` | Reads `/users/{uid}` and `/users/{uid}/onboarding/state` | None |
| 5 | Chooses identity categories | `onboarding_page_0.dart` | `OnboardingProvider` saves progress | `/users/{uid}/onboarding/state`, `/profile/main`, root onboarding map | None until complete |
| 6 | Selects bad habits | `onboarding_page_1.dart` | Save progress | Same onboarding/profile docs | None until complete |
| 7 | Selects good habits | `onboarding_page_2.dart` | Save progress | Same onboarding/profile docs | None until complete |
| 8 | Selects goals | `onboarding_page_3.dart` | Save progress | Same onboarding/profile docs | None until complete |
| 9 | Enters routine schedule | Existing schedule onboarding pages | Save fixed schedule items | `/users/{uid}/onboarding/state.scheduleItems` | None until complete |
| 10 | Enters About You body basics | Must expand `onboarding_page_5.dart` | Validate age/height/weight/wake/sleep | `/users/{uid}/profile/main.biometrics`, `/onboarding/about_you/body` | `biometrics_updated` only if user edits after initial save; otherwise include in onboarding payload |
| 11 | Enters lifestyle context | `onboarding_page_5.dart` sub-page | Save water, sleep, exercise, diet, stress, school/work | `/users/{uid}/profile/main.lifestyle`, `/onboarding/about_you/lifestyle` | None until complete |
| 12 | Enters sensitive context | `onboarding_page_5.dart` sub-page | Save safety flags and coach boundaries | `/users/{uid}/profile/main.sensitiveContext` | None until complete |
| 13 | Chooses coach/accountability | Existing coach onboarding pages | Save coach style/name and accountability mode | `/users/{uid}/profile/main.coachStyle`, `coachName`, `accountabilityMode` | None until complete |
| 14 | Views AI plan ready | Create `onboarding_page_10.dart` | Generate deterministic first plan from onboarding; do not call paid AI unless configured | `/users/{uid}/routine/current`, `/habits/*`, `/goals/*`, `/scheduled_notifications/*`, `/ai_context_snapshots/{id}` | `onboarding_completed`, `task_scheduled` for generated tasks, `suggestion_generated` for initial plan |
| 15 | Taps Start Today | `OnboardingScreen` final CTA | Marks onboarding complete and routes home | `/users/{uid}.hasCompletedOnboarding=true`, `/onboarding/state.status=completed` | `onboarding_completed`, then `day_started` if first app day |

### First Day Experience

| Step | User action | UI screen | Backend action | Firestore write | Event triggered |
|---|---|---|---|---|---|
| 1 | Opens Home after onboarding | `HomeTab` | Start/replay event orchestrator, build today context | `/events_recent/day_started`, `/ai_context_snapshots/{id}` | `day_started` |
| 2 | Reviews mission ring | `HomeTab` | Read tasks, habits, streaks, identity score | No write unless snapshot missing | None |
| 3 | Taps habit quick check-in | `HomeTab` quick sheet | `HabitService.logGood` or `logSlip` | `/habit_logs/{logId}`, `/habits/{habitId}/logs/{date}/items/{logId}` | `good_habit_logged` or `bad_habit_slip_logged` |
| 4 | Opens routine task | `RoutineTab` | Read today's `/tasks` | None | None |
| 5 | Starts task | Task row | `TaskService.startTask` enforces active task | `/tasks/{taskId}.status=started`, active timestamps | `task_started` |
| 6 | Completes task/subtasks | Task row/detail | `TaskService.completeTask`, auto-check required subtasks | `/tasks/{taskId}.status=completed`, `/task_outcomes/{id}` if created | `subtask_checked`, `task_completed` |
| 7 | Logs slip | Tracker/Home slip sheet | `HabitService.logSlip`, checks slip streak | `/habit_logs/{logId}` | `bad_habit_slip_logged`, possible `slip_streak_detected` |
| 8 | Receives coach reply | Coach tab or proactive card | Rule engine evaluates event | `/coach_messages/{messageId}`, `/coach_speak_log/{logId}` | `coach_replied` or `suggestion_generated` |
| 9 | Receives reminder | Local notification or FCM | Notification send/tap lifecycle | `/scheduled_notifications/{id}`, `/notificationLog/{id}` or `/notification_log/{id}` consistently | `notification_sent`, `notification_tapped`, `notification_dismissed`, or `notification_suppressed` |
| 10 | Ends day | End-of-day sheet/Home prompt | Day close computes tasks, routine, streaks, goals | `/dailySummaries/{date}`, `/streaks/{id}`, `/goals/{id}`, `/events_recent` | `day_closed`, `routine_day_summarized`, streak events, identity events |

### Daily Usage Loop

| Loop step | User action | UI screen | Backend action | Firestore write | Event triggered |
|---|---|---|---|---|---|
| Morning | Opens app or receives brief | Home notification card | Build context and morning plan | `/ai_context_snapshots/{id}`, `/coach_messages/{id}` | `day_started`, optional `coach_replied` |
| During task window | Starts, pauses, resumes, completes, skips | Routine timeline | Enforce task state machine | `/tasks/{taskId}` | `task_started`, `task_paused`, `task_resumed`, `task_completed`, `task_skipped` |
| Habit moment | Logs good habit or slip | Home/Tracker/detail | Update logs and streak inputs | `/habit_logs/{logId}` | `good_habit_logged`, `bad_habit_slip_logged` |
| AI intervention | Accepts/dismisses suggestion | Coach/Home/Routine AI panel | Save learning signal | `/suggestions/{id}` | `suggestion_accepted` or `suggestion_dismissed` |
| Notification | Opens, dismisses, or ignores | System notification -> deep link | Record lifecycle and cap data | `/notificationLog/{id}` | `notification_tapped`, `notification_dismissed`, `notification_suppressed` |
| Evening | Reviews day and tomorrow | Home/Routine end-of-day sheet | Close day and schedule tomorrow | `/dailySummaries/{date}`, `/scheduled_notifications/*`, `/tasks/*` | `day_closed`, `task_scheduled` |
| Long-term | Reviews streaks/goals/profile | Tracker/Goals/Profile | Recompute identity and progress | `/streaks/*`, `/goals/*`, `/identity_profile/main` | `identity_progress_changed`, milestone events |

### Event Trigger Points

- Signup: `user_signed_up`.
- Onboarding final submit: `onboarding_completed`.
- Routine materialization: `task_scheduled`.
- Task controls: `task_started`, `task_paused`, `task_resumed`, `task_completed`, `task_abandoned`, `task_skipped`, `task_deleted`.
- Subtask controls: `subtask_checked`, `subtask_unchecked`.
- Habit lifecycle: `habit_created`, `habit_updated`, `habit_archived`.
- Habit logs: `good_habit_logged`, `bad_habit_slip_logged`, `habit_log_deleted`, `slip_streak_detected`.
- Streak lifecycle: `streak_extended`, `streak_broken`, `streak_milestone_reached`, `streak_paused`, `streak_resumed`.
- Coach: `coach_message_sent`, `coach_replied`.
- Suggestions: `suggestion_generated`, `suggestion_accepted`, `suggestion_dismissed`.
- Notifications: `notification_scheduled`, `notification_sent`, `notification_tapped`, `notification_dismissed`, `notification_suppressed`.
- Day lifecycle: `day_started`, `day_closed`.
- Identity: `identity_progress_changed`, `milestone_completed`.
- Retention: `ghost_day_detected`, `comeback_initiated`.

### AI Interaction Points

- First plan ready after onboarding.
- Home mission ring explanation.
- Routine AI panel for schedule/routine improvement.
- Coach chat direct messages.
- Proactive coach messages after meaningful events.
- Habit slip recovery coaching.
- Missed task recovery and routine adjustment.
- End-of-day summary and tomorrow setup.
- Ghost-day comeback flow.
- Goal/identity why-score explanations.
- Notification copy generation within rule-based boundaries.
- Safety/crisis routing with non-LLM emergency/handoff behavior.

### Feature Entry Points

- Home tab: mission ring, habit quick check-ins, streak cards, calendar, today's routine, notification center, proactive coach card.
- Routine tab: timeline, filters, setup screens, active task controls, custom alarms, Routine AI panel.
- Tracker tab: habit cards, good/bad habit details, add/edit habit, screen time, analytics, money saved.
- Coach tab: chat, topic modes, proactive messages, suggestions history.
- Goals tab: identity hero, today's identity push, goal grid, goal detail, milestones, why score, add/edit goals.
- Profile tab: identity profile, coach settings, accountability settings, notification settings, About You editor, privacy/export/delete, subscription, signout.
- System notifications: deep link into tasks, habits, coach, goals, or comeback flow.

### Retention Loops

| Loop | Trigger | User-visible path | Backend action | Firestore write | Event |
|---|---|---|---|---|---|
| Streak reinforcement | Good habit logged or task completed | Home streak card, Tracker detail | Update streak and milestone | `/streaks/{id}` | `streak_extended`, milestone event |
| Slip recovery | Bad habit slip logged | Slip recovery sheet, Coach card | Detect repeated slips | `/habit_logs/*`, `/coach_messages/*` | `bad_habit_slip_logged`, `slip_streak_detected` |
| Mission recovery | Missed tasks or low routine pct | Home/Routine AI prompt | Suggest reduced plan | `/suggestions/{id}` | `suggestion_generated` |
| Ghost comeback | No activity for 1/3/7/14/30 days | Comeback modal | Pause streaks, create restart plan | `/streaks/*`, `/suggestions/*` | `ghost_day_detected`, `comeback_initiated` |
| Identity progress | Consistent habits/tasks | Goals/Profile identity hero | Recompute identity score | `/identity_profile/main`, `/goals/*` | `identity_progress_changed` |
| Notification learning | User taps/dismisses/ignores | Settings and notification center | Update delivery budget and timing | `/notificationLog/*`, `/profile/main.notificationSettings` | notification lifecycle events |

## 4. Codebase vs Document Analysis

### Already Implemented

- Firebase app bootstrap, auth bootstrap, and route redirect are already usable.
- The app already has the six-tab product shell required by the PRD.
- The project already has the main service/module names required by the architecture docs.
- Firestore already uses per-user subcollections for most user data.
- Event names already include almost all canonical names from the docs.
- AI/Coach is already present enough to extend, not rebuild.
- Cloud Functions already exist and should be extended, not replaced.

### Partially Implemented

- Event storage paths exist, but event contracts are not strict enough.
- Task and habit services emit some events, but payloads do not always match service contracts.
- Routine setup exists, but routine execution is not fully connected to daily review, alarms, AI suggestions, and analytics.
- Home UI exists, but several widgets are read-only or incomplete.
- Tracker UI exists, but lacks detail screens, variants, and habit management.
- Coach UI exists, but lacks evented chat, safety, modes, and suggestion acceptance.
- Goals/Profile are present but shallow.
- Notification service exists but lifecycle and custom alarm behavior are incomplete.
- Scheduled Cloud Functions exist but are too simple and not fully event-driven.

### Not Implemented

- The full User Flow document is not yet implemented end to end.
- Full production event-driven architecture is not implemented.
- Full database schema v1 is not implemented consistently.
- Full AI Master Engine is not implemented.
- Full analytics/notification/re-engagement loops are not implemented.
- Full production test and emulator verification are missing.

### Needs Refactoring

- Refactor contracts before adding more UI. Otherwise new UI will write inconsistent Firestore data.
- Refactor EventService first, then TaskService/HabitService, then Streak/Routine/Notification, then AI.
- Refactor only around the requested feature boundaries. Do not rewrite screens that already work.

### Do Not Touch

- Keep `lib/views/screens/home_screen.dart` as the main shell.
- Keep existing tab files and add routes/screens around them.
- Keep `routine/current` unless a task explicitly adds backward-compatible support for other routine docs.
- Keep Gemini calls in Cloud Functions and `GeminiService`.
- Keep Firebase Auth as the auth provider source.
- Keep App Check, Firestore offline persistence, Crashlytics, and Remote Config initialization.

## 5. Dependency Map

1. Auth/user root schema must exist before onboarding can complete.
2. Onboarding/About You data must exist before personalized routines, goals, notifications, and AI context can be reliable.
3. EventService contract must be fixed before service events are expanded.
4. Firestore schema/rules/indexes must be aligned before backend jobs rely on queries.
5. Habit logs must exist before streaks, money saved, bad-habit recovery, and tracker analytics.
6. Task lifecycle must exist before routine completion, mission ring, notification deep links, and day close.
7. Day start/day close must exist before daily summaries, identity progress, retention loops, and AI daily planning.
8. Notification records must exist before custom alarms, caps, dedupe, and notification analytics.
9. Context snapshots must exist before AI rule engine and LLM calls.
10. Rule engine must exist before proactive AI and suggestions.
11. Suggestions storage must exist before Routine AI panel accept/dismiss flows.
12. Goals/identity schema must exist before mission ring identity scoring and why-score UI.
13. Ghost/comeback detection depends on event logs, daily summaries, streak state, and notification rules.
14. Privacy/export/delete flows depend on stable schema paths.
15. Production release depends on emulator tests, unit tests, widget tests, integration smoke tests, rules tests, and function tests.

## 6. Production Build Plan

- Phase 0: Freeze the current map and add guardrail docs/tests for existing behavior.
- Phase 1: Complete auth, user schema, onboarding, About You, and first plan materialization.
- Phase 2: Fix the event spine and Firestore schema consistency.
- Phase 3: Complete task/routine/day lifecycle.
- Phase 4: Complete habit/tracker system.
- Phase 5: Complete streak, accountability, ghost, and comeback loops.
- Phase 6: Complete goals and identity system.
- Phase 7: Complete notifications and custom alarms.
- Phase 8: Complete AI Master Engine and Coach.
- Phase 9: Complete Profile, settings, privacy, export/delete, and subscription.
- Phase 10: Complete analytics, Cloud Functions, monitoring, and cleanup.
- Phase 11: Complete production QA and release readiness.

## 7. Phase-wise Antigravity TODO List

## Phase 0 - Audit Guardrails

### Task 0.1 — Create implementation inventory and feature matrix

#### Why

The project already has working pieces. Antigravity must know what to extend and what not to rewrite before making changes.

#### What to tell Antigravity

- CREATE `docs/implementation_inventory.md`.
- CREATE `docs/feature_matrix.md`.
- Read these paths and summarize what exists:
  - `lib/main.dart`
  - `lib/core/router/app_router.dart`
  - `lib/core/providers.dart`
  - `lib/core/providers/bootstrap_provider.dart`
  - `lib/services/*.dart`
  - `lib/views/screens/*.dart`
  - `lib/views/tabs/*.dart`
  - `lib/views/routine/*.dart`
  - `lib/views/onboarding/*.dart`
  - `functions/index.js`
  - `functions/jobs/*.js`
  - `firestore.rules`
  - `firestore.indexes.json`
- In `docs/feature_matrix.md`, create rows for every feature from all seven docs.
- For every feature, include columns: UI path, Flutter state/provider, service method, Firestore path, event name, Cloud Function/backend, verification.
- Mark each row as `implemented`, `partial`, or `missing`.
- Do not change app runtime code in this task.

#### Dependencies

- None.

#### How to verify

- Open `docs/implementation_inventory.md` and confirm it names current files accurately.
- Open `docs/feature_matrix.md` and confirm every PRD/User Flow feature has a row.
- Confirm `git diff` shows only the two docs files for this task.

#### Estimate

2h

#### Done Criteria

- [ ] Current code paths are listed.
- [ ] All seven docs are reflected.
- [ ] No runtime code changed.
- [ ] Each feature has UI/backend/Firestore/event/verification columns.

### Task 0.2 — Add contract test skeletons without changing behavior

#### Why

The production plan needs verification from the start. Skeleton tests provide places to add assertions as contracts are completed.

#### What to tell Antigravity

- CREATE `test/services/event_service_contract_test.dart`.
- CREATE `test/services/task_service_contract_test.dart`.
- CREATE `test/services/habit_service_contract_test.dart`.
- CREATE `test/services/streak_service_contract_test.dart`.
- CREATE `test/services/notification_service_contract_test.dart`.
- CREATE `functions/test/events.contract.test.js`.
- CREATE `functions/test/jobs.contract.test.js`.
- Each file should contain TODO test groups only. Do not test behavior that is not implemented yet.
- Add comments listing required contract areas from `OPTIVUS Docs/5_Optivus_ServiceContracts.md`.
- Do not modify production services in this task.

#### Dependencies

- Task 0.1.

#### How to verify

- Run `flutter test`.
- Run `cd functions && npm test` if package scripts exist; otherwise document the missing test script in `docs/implementation_inventory.md`.
- Confirm test files compile or are marked skipped without failing.

#### Estimate

1h

#### Done Criteria

- [ ] Test skeleton files exist.
- [ ] Tests do not fail due to missing implementation.
- [ ] Contract gaps are documented in test TODOs.

## Phase 1 - Auth, User Schema, and Onboarding

### Task 1.1 — Align user root and auth lifecycle

#### Why

Every later feature depends on a stable `/users/{uid}` root doc and canonical auth events.

#### What to tell Antigravity

- MODIFY `lib/services/auth_service.dart`.
- MODIFY `lib/repositories/auth_repository.dart`.
- MODIFY `lib/models/user_model.dart`.
- MODIFY `lib/views/screens/signup_screen.dart`.
- MODIFY `lib/views/screens/login_screen.dart`.
- MODIFY `lib/core/constants/event_names.dart` only if a missing event constant is required.
- Keep current email/password login working.
- Ensure `/users/{uid}` contains:
  - `uid`
  - `email`
  - `displayName`
  - `createdAt`
  - `updatedAt`
  - `schemaVersion`
  - `timezone`
  - `hasCompletedOnboarding`
  - `onboardingStep`
  - `lastDayClosed`
- Ensure `user_signed_up` payload contains:
  - `authProvider`
  - `email`
  - `timezone`
  - `schemaVersion`
  - `createdAt`
- Add Google/Apple sign-in only if Firebase config already supports it; otherwise add disabled UI states with clear TODO comments and do not break email/password.
- State management: expose auth loading/error through existing screen state or provider, not global mutable state.
- Backend: no Cloud Function needed.
- Validation: keep existing password validation and login errors.

#### Dependencies

- Task 0.1.

#### How to verify

- UI behavior: create an account from `SignupScreen`; confirm redirect goes to onboarding.
- Firebase console: `/users/{uid}` has all required fields.
- Events: `/users/{uid}/events_recent` contains `user_signed_up`.
- Logs: no Crashlytics/runtime errors during signup.
- Navigation: sign out from Profile and sign in again; route returns to onboarding or home depending on onboarding status.

#### Estimate

2h

#### Done Criteria

- [ ] Email/password signup still works.
- [ ] Root user doc matches schema.
- [ ] `user_signed_up` is emitted exactly once per account.
- [ ] Login and forgot password still work.

### Task 1.2 — Complete About You onboarding data model and UI

#### Why

AI personalization, hydration, routine timing, safety behavior, and notification tone all depend on About You data.

#### What to tell Antigravity

- MODIFY `lib/views/onboarding/onboarding_page_5.dart`.
- MODIFY `lib/providers/onboarding_provider.dart`.
- MODIFY `lib/repositories/user_repository.dart`.
- MODIFY `lib/models/identity_profile_model.dart`.
- MODIFY `lib/models/user_model.dart` only if needed for typed fields.
- Keep the screen inside the current onboarding flow.
- Implement three sub-pages inside Page 5:
  - Body basics: age range, height, weight, gender optional, wake time, sleep time, timezone.
  - Lifestyle: work/school type, exercise level, water intake, diet preference, stress level, sleep quality.
  - Sensitive context: eating disorder flag, crisis/self-harm flag, medical disclaimer acknowledgement, coach boundary preference.
- Firestore writes:
  - `/users/{uid}/onboarding/state.aboutYou`
  - `/users/{uid}/profile/main.biometrics`
  - `/users/{uid}/profile/main.lifestyle`
  - `/users/{uid}/profile/main.sensitiveContext`
- State management:
  - Add typed fields to existing `OnboardingProvider`.
  - Persist progress on page changes using existing repository methods.
- Backend:
  - No Cloud Function required.
- Events:
  - Do not emit `biometrics_updated` during initial onboarding partial saves.
  - Later Profile edits should emit `biometrics_updated`.
- Error/loading/empty states:
  - Show validation errors for impossible age/height/weight values.
  - Allow sensitive questions to be skipped with explicit null/unknown values.
  - Show loading while saving.

#### Dependencies

- Task 1.1.

#### How to verify

- UI behavior: complete all three sub-pages and navigate forward/back without losing data.
- Firebase console: confirm `aboutYou`, `biometrics`, `lifestyle`, and `sensitiveContext` exist.
- Logs: no exceptions when values are skipped.
- Navigation: onboarding can continue after Page 5.
- Expected data: sensitive flags are booleans/nulls, not display strings.

#### Estimate

4h

#### Done Criteria

- [ ] Page 5 has three sub-pages.
- [ ] Data persists across app restart.
- [ ] Firestore paths match this task.
- [ ] Validation works.

### Task 1.3 — Add final AI plan ready onboarding step

#### Why

The User Flow requires the user to see their first plan before entering the daily loop.

#### What to tell Antigravity

- CREATE `lib/views/onboarding/onboarding_page_10.dart`.
- MODIFY `lib/views/screens/onboarding_screen.dart`.
- MODIFY `lib/providers/onboarding_provider.dart`.
- MODIFY `lib/repositories/user_repository.dart`.
- MODIFY `lib/services/task_service.dart` only to call existing task creation safely if needed.
- MODIFY `lib/services/habit_service.dart` only to call existing habit creation safely if needed.
- UI behavior:
  - Show generated plan sections: Today's routine, habits to track, first identity goals, notification summary, coach style.
  - CTA: `Start Today`.
  - Secondary action: edit selections by going back.
  - Empty state: if no routine/habits/goals selected, show a minimal starter plan.
- Firestore writes on completion:
  - `/users/{uid}.hasCompletedOnboarding=true`
  - `/users/{uid}.onboardingStep=10`
  - `/users/{uid}/onboarding/state.status=completed`
  - `/users/{uid}/profile/main`
  - `/users/{uid}/routine/current`
  - `/users/{uid}/habits/{habitId}`
  - `/users/{uid}/goals/{goalId}`
  - `/users/{uid}/scheduled_notifications/{notificationId}`
  - `/users/{uid}/ai_context_snapshots/{snapshotId}`
- Events:
  - `onboarding_completed`
  - `task_scheduled` for each materialized task.
  - `notification_scheduled` for generated reminders.
  - `suggestion_generated` for first plan suggestions.
- Backend:
  - No external LLM required for this task. Generate deterministic plan from onboarding selections.

#### Dependencies

- Task 1.2.
- Task 2.1 should be done before final production release, but this task can initially use current EventService and be revalidated after Phase 2.

#### How to verify

- UI behavior: new user reaches AI plan ready page and taps Start Today.
- Firebase console: habits, goals, routine, scheduled notifications, and context snapshot are created.
- Events: onboarding and scheduled task events are present in `/events_recent`.
- Navigation: user lands on Home after tapping Start Today.
- Expected data: generated plan is visible on Home/Routine/Tracker/Goals.

#### Estimate

1 day

#### Done Criteria

- [ ] Page 10 exists and is reachable.
- [ ] Start Today completes onboarding.
- [ ] User-visible plan appears across tabs.
- [ ] Required Firestore docs and events exist.

## Phase 2 - Event Spine and Firestore Contracts

### Task 2.1 — Make EventService production-grade

#### Why

All backend, AI, notification, analytics, streak, and retention logic depends on reliable events.

#### What to tell Antigravity

- MODIFY `lib/services/event_service.dart`.
- MODIFY `lib/models/event_model.dart`.
- MODIFY `lib/core/constants/event_names.dart`.
- MODIFY `lib/core/utils/uuid_generator.dart`.
- CREATE `lib/services/event_payload_validator.dart`.
- MODIFY tests in `test/services/event_service_contract_test.dart`.
- Firestore paths:
  - Write every event to `/users/{uid}/events/{eventId}`.
  - Write the same envelope to `/users/{uid}/events_recent/{eventId}`.
- Event envelope fields:
  - `eventId`
  - `eventName`
  - `uid`
  - `timestamp`
  - `source`
  - `schemaVersion`
  - `payload`
  - `deviceId`
  - `appVersion` if available
- Idempotency:
  - Use stable event IDs supplied by the caller when retrying user actions.
  - For one-time actions, generate UUIDv7 or existing sortable UUID equivalent.
  - Use a Firestore transaction: if `/events/{eventId}` exists, do not write duplicate events.
- Local bus:
  - Emit locally only after Firestore write is queued/committed successfully.
  - Keep replay of `/events_recent`.
- Validation:
  - Reject unknown event names.
  - Validate required payload keys for high-risk events: task, habit, notification, coach, day lifecycle.
- Error/loading:
  - Throw typed app errors, not raw strings.

#### Dependencies

- Task 0.2.

#### How to verify

- UI behavior: signup/onboarding/task/habit actions still work.
- Firebase console: each event appears in both `/events` and `/events_recent`.
- Logs: duplicate retries do not create duplicate docs.
- Tests: `flutter test test/services/event_service_contract_test.dart`.
- Expected data: event envelope contains `uid`, `source`, `schemaVersion`, and `payload`.

#### Estimate

1 day

#### Done Criteria

- [ ] Event writes are transactional/idempotent.
- [ ] Event payload validation exists.
- [ ] Existing flows still emit events.
- [ ] Tests cover duplicate event IDs.

### Task 2.2 — Align Firestore schema, rules, and indexes

#### Why

The schema document is the production contract. UI and Cloud Functions must query the same paths.

#### What to tell Antigravity

- MODIFY `firestore.rules`.
- MODIFY `firestore.indexes.json`.
- MODIFY `lib/services/firestore_service.dart`.
- CREATE `docs/firestore_schema_v1_mapping.md`.
- Audit and standardize these per-user paths:
  - `/users/{uid}/profile/main`
  - `/users/{uid}/onboarding/state`
  - `/users/{uid}/routine/current`
  - `/users/{uid}/habits/{habitId}`
  - `/users/{uid}/habit_logs/{logId}`
  - `/users/{uid}/tasks/{taskId}`
  - `/users/{uid}/goals/{goalId}`
  - `/users/{uid}/streaks/{streakId}`
  - `/users/{uid}/events_recent/{eventId}`
  - `/users/{uid}/events/{eventId}`
  - `/users/{uid}/coach_messages/{messageId}`
  - `/users/{uid}/coach_speak_log/{logId}`
  - `/users/{uid}/ai_context_snapshots/{snapshotId}`
  - `/users/{uid}/scheduled_notifications/{notificationId}`
  - `/users/{uid}/notificationLog/{logId}` or rename consistently with a migration plan.
  - `/users/{uid}/journal_entries/{entryId}`
  - `/users/{uid}/screen_time_logs/{logId}`
  - `/users/{uid}/addiction_logs/{logId}`
  - `/users/{uid}/suggestions/{suggestionId}`
  - `/users/{uid}/dailySummaries/{date}`
- Security rules:
  - User can read/write only their own subtree.
  - Event docs should be append-only from client after creation where practical.
  - Protect server-only fields if possible.
- Indexes:
  - Add required compound indexes for `tasks`, `habit_logs`, `events_recent`, `coach_messages`, `scheduled_notifications`, `screen_time_logs`, `suggestions`, and `dailySummaries`.
- Backend:
  - No Cloud Function required unless a migration is needed.

#### Dependencies

- Task 2.1.

#### How to verify

- UI behavior: app still loads Home/Routine/Tracker/Coach/Goals/Profile.
- Firebase console: new writes use documented paths.
- Logs: no missing-index runtime errors.
- Tests: run Firestore rules tests if present; otherwise document missing emulator test command.
- Expected data: `docs/firestore_schema_v1_mapping.md` lists every actual path.

#### Estimate

4h

#### Done Criteria

- [ ] Schema mapping exists.
- [ ] Rules protect per-user data.
- [ ] Indexes cover production queries.
- [ ] No screen has permission errors.

## Phase 3 - Task, Routine, and Day Lifecycle

### Task 3.1 — Complete TaskService contract

#### Why

Tasks drive routines, notifications, mission ring, day close, AI decisions, and analytics.

#### What to tell Antigravity

- MODIFY `lib/services/task_service.dart`.
- MODIFY `lib/models/task_model.dart`.
- MODIFY `lib/core/constants/event_names.dart` only if a constant is missing.
- MODIFY `test/services/task_service_contract_test.dart`.
- Required methods:
  - `createTask`
  - `watchTask`
  - `watchTasksForDay`
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
- Firestore path:
  - `/users/{uid}/tasks/{taskId}`
- Required fields:
  - `taskId`, `title`, `routineType`, `status`, `dateKey`, `scheduledStart`, `scheduledEnd`, `actualStart`, `actualEnd`, `durationMin`, `subtasks`, `alarmTier`, `customAlarm`, `createdAt`, `updatedAt`, `source`.
- State rules:
  - Only one `started` task can be active unless current active task is paused/abandoned/completed first.
  - Completing a scheduled task without pressing start is allowed and must set reasonable actual timestamps.
  - Skipping applies before start; abandoning applies after start.
  - Subtask completion must persist and emit events.
- Events:
  - `task_scheduled`
  - `task_started`
  - `task_paused`
  - `task_resumed`
  - `task_completed`
  - `task_abandoned`
  - `task_skipped`
  - `task_deleted`
  - `subtask_checked`
  - `subtask_unchecked`
- Backend:
  - No Cloud Function required in this task.

#### Dependencies

- Task 2.1.
- Task 2.2.

#### How to verify

- UI behavior: task status changes still appear in Routine.
- Firebase console: `/tasks/{taskId}` status/timestamps update correctly.
- Events: each task action creates one event with contract payload.
- Logs: attempting to start a second active task resolves predictably.
- Tests: task contract test covers each state transition.

#### Estimate

1 day

#### Done Criteria

- [ ] All required methods exist.
- [ ] State machine rules are enforced.
- [ ] Subtasks persist.
- [ ] Events match contracts.

### Task 3.2 — Complete Routine timeline task controls

#### Why

User-visible task execution must expose the full task state machine.

#### What to tell Antigravity

- MODIFY `lib/views/routine/routine_tab.dart`.
- MODIFY `lib/views/routine/timeline_section.dart`.
- MODIFY `lib/views/routine/timeline_zoom_views.dart`.
- MODIFY `lib/views/routine/add_task_sheet.dart`.
- MODIFY `lib/core/providers.dart`.
- UI behavior:
  - Each task row shows correct actions for its current status.
  - Scheduled: Start, Complete, Skip.
  - Started: Pause, Complete, Abandon.
  - Paused: Resume, Complete, Abandon.
  - Completed/Skipped/Abandoned: read-only result state.
  - Subtask checkboxes call TaskService and update Firestore.
  - Show active task pinned at top of Routine and Home.
  - Add error/loading states per action.
- Firestore:
  - Read/write `/users/{uid}/tasks/{taskId}`.
- Events:
  - Use TaskService only; UI must not emit task events directly.
- Backend:
  - No Cloud Function required.

#### Dependencies

- Task 3.1.

#### How to verify

- UI behavior: run through every task action from Routine.
- Firebase console: task status/timestamps/subtasks update.
- Events: all expected task events appear.
- Navigation: tapping calendar day shows that date's tasks.
- Expected data: no local-only subtask changes remain.

#### Estimate

4h

#### Done Criteria

- [ ] Routine UI exposes all task actions.
- [ ] Task controls are status-aware.
- [ ] Subtasks are synced.
- [ ] Active task is visible.

### Task 3.3 — Complete routine setup and materialization

#### Why

The docs require fixed, skin, eating, and class routines to create user-visible tasks and notifications.

#### What to tell Antigravity

- MODIFY `lib/repositories/routine_repository.dart`.
- MODIFY `lib/providers/routine_provider.dart`.
- MODIFY `lib/views/routine/fixed_schedule_setup_screen.dart`.
- MODIFY `lib/views/routine/skin_care_setup_screen.dart`.
- MODIFY `lib/views/routine/eating_setup_screen.dart`.
- MODIFY `lib/views/routine/class_setup_screen.dart`.
- MODIFY `lib/views/routine/routine_settings_sheet.dart`.
- MODIFY `lib/services/task_service.dart` only through existing contract methods.
- Firestore:
  - Store canonical routine config at `/users/{uid}/routine/current`.
  - Materialize daily task instances at `/users/{uid}/tasks/{taskId}`.
  - Store scheduled reminders at `/users/{uid}/scheduled_notifications/{notificationId}`.
- UI behavior:
  - Setup screens show save/loading/error.
  - Existing routine config loads on reopen.
  - User can edit fixed schedule, skin care, eating, and classes.
  - Saving updates future task materialization without deleting historical completed tasks.
- Events:
  - `task_scheduled` for new generated tasks.
  - `notification_scheduled` for generated reminders.
- Backend:
  - Client can materialize near-term tasks; Cloud Functions will later re-materialize future schedule.

#### Dependencies

- Task 3.1.
- Task 7.1 for final notification lifecycle; this task may create provisional notification records first.

#### How to verify

- UI behavior: edit each routine type and see Timeline update.
- Firebase console: `/routine/current`, `/tasks`, and `/scheduled_notifications` update.
- Events: new tasks emit `task_scheduled`.
- Navigation: Routine tab reflects edits without app restart.
- Expected data: completed historical tasks are preserved.

#### Estimate

1 day

#### Done Criteria

- [ ] All setup screens persist/load.
- [ ] Routine edits create/update future tasks.
- [ ] Historical task records are preserved.
- [ ] Notifications are scheduled or queued.

### Task 3.4 — Implement day start, day close, and mission ring

#### Why

The daily loop depends on correct day lifecycle, routine completion, and summary analytics.

#### What to tell Antigravity

- MODIFY `lib/services/routine_service.dart`.
- MODIFY `lib/models/day_summary_model.dart`.
- MODIFY `lib/views/tabs/home_tab.dart`.
- MODIFY `lib/core/providers.dart`.
- MODIFY `functions/jobs/dayClose.js`.
- Firestore:
  - `/users/{uid}/dailySummaries/{date}`
  - `/users/{uid}/events_recent/{eventId}`
  - `/users/{uid}/tasks/{taskId}`
  - `/users/{uid}/streaks/{streakId}`
- Day start:
  - Emit `day_started` once per local date when app opens or scheduled job runs.
  - Build `/ai_context_snapshots/{snapshotId}` for the day.
- Day close:
  - Close every unclosed past day, not just yesterday.
  - Mark overdue started/scheduled tasks as abandoned/skipped according to contract.
  - Compute task completion %, routine completion %, focus minutes, habit completion, slips, streak outcomes, identity progress input, mission score.
  - Write `dailySummaries/{date}`.
  - Emit `day_closed` and `routine_day_summarized`.
- UI:
  - Home mission ring uses the summary/real-time projection, not only task count.
  - Show empty state if no tasks/habits exist.
  - Show end-of-day prompt after configured sleep block.
- Backend:
  - Cloud Function day close must use same schema as Flutter service.

#### Dependencies

- Task 3.1.
- Task 4.1.
- Task 5.1.

#### How to verify

- UI behavior: Home mission ring updates after completing tasks/habits.
- Firebase console: `dailySummaries/{date}` has routine, task, habit, streak, identity fields.
- Logs: day close can run twice without duplicate day events.
- Cloud Functions: emulator/scheduled job writes same summary shape.
- Expected data: missed days are closed in order.

#### Estimate

1 day

#### Done Criteria

- [ ] `day_started` and `day_closed` are idempotent.
- [ ] Mission ring uses documented formula inputs.
- [ ] Daily summaries are complete.
- [ ] Client and Function day close agree.

## Phase 4 - Habit and Tracker System

### Task 4.1 — Complete HabitService lifecycle contract

#### Why

Tracker, streaks, AI, money saved, and recovery flows depend on correct habit events and logs.

#### What to tell Antigravity

- MODIFY `lib/services/habit_service.dart`.
- MODIFY `lib/models/habit_model.dart`.
- MODIFY `lib/models/habit_log_model.dart`.
- MODIFY `test/services/habit_service_contract_test.dart`.
- Required methods:
  - `createHabit`
  - `updateHabit`
  - `pauseHabit`
  - `resumeHabit`
  - `archiveHabit`
  - `logGood`
  - `logSlip`
  - `deleteLog`
  - `watchHabits`
  - `watchHabitLogsForDate`
- Firestore:
  - `/users/{uid}/habits/{habitId}`
  - `/users/{uid}/habit_logs/{logId}`
  - Keep nested logs only if needed for compatibility; flat `habit_logs` must be canonical.
- Required habit fields:
  - `habitId`, `name`, `type`, `category`, `target`, `unit`, `status`, `visibility`, `accountabilityMode`, `moneyValue`, `createdAt`, `updatedAt`, `archivedAt`.
- Required log fields:
  - `logId`, `habitId`, `habitType`, `dateKey`, `amount`, `unit`, `note`, `createdAt`, `source`, `undoUntil`.
- Events:
  - `habit_created`
  - `habit_updated`
  - `habit_archived`
  - `good_habit_logged` with `amount`, `unit`, `todayTotalAfter`, `goalHitToday`.
  - `bad_habit_slip_logged` with `countTodayAfter`.
  - `habit_log_deleted`.
  - `slip_streak_detected` when rule threshold is crossed.

#### Dependencies

- Task 2.1.
- Task 2.2.

#### How to verify

- UI behavior: existing Log Habit sheet still works.
- Firebase console: habit docs and flat habit logs match schema.
- Events: every lifecycle/log action emits expected event.
- Logs: deleting/undoing a log updates totals.
- Tests: habit service contract tests pass.

#### Estimate

1 day

#### Done Criteria

- [ ] Full habit lifecycle exists.
- [ ] Good and bad log payloads match contracts.
- [ ] Undo/delete log exists.
- [ ] Slip streak detection emits once per threshold window.

### Task 4.2 — Add Home and Tracker good habit quick logging

#### Why

The daily loop requires fast check-ins from Home and Tracker.

#### What to tell Antigravity

- MODIFY `lib/views/tabs/home_tab.dart`.
- MODIFY `lib/views/tabs/tracker_tab.dart`.
- MODIFY `lib/views/habits/log_habit_sheet.dart`.
- MODIFY `lib/core/providers.dart`.
- UI behavior:
  - Home habit cards are tappable.
  - Good habit tap opens quick sheet with amount, unit, note optional.
  - Bad habit tap opens slip sheet with count/note and recovery copy.
  - Tracker cards expose Log, Undo latest, Details.
  - Loading and error states appear inline.
  - Empty state tells user to add habits from Tracker.
- Firestore:
  - `/users/{uid}/habit_logs/{logId}`.
- Events:
  - Use HabitService only.
- Backend:
  - No Cloud Function required.

#### Dependencies

- Task 4.1.

#### How to verify

- UI behavior: log a good habit from Home and Tracker.
- Firebase console: log is created once.
- Events: `good_habit_logged` or `bad_habit_slip_logged` exists.
- Navigation: Details button opens detail screen after Task 4.5; before then, disabled state is acceptable.
- Expected data: progress totals update immediately.

#### Estimate

4h

#### Done Criteria

- [ ] Home cards support quick log.
- [ ] Tracker cards support quick log.
- [ ] Undo latest log is visible.
- [ ] Empty/loading/error states exist.

### Task 4.3 — Add habit add/edit/pause/archive UI

#### Why

Users must manage their habits after onboarding.

#### What to tell Antigravity

- CREATE `lib/views/habits/habit_editor_screen.dart`.
- CREATE `lib/views/habits/habit_detail_screen.dart` if not created in Task 4.5.
- MODIFY `lib/views/tabs/tracker_tab.dart`.
- MODIFY `lib/core/router/app_router.dart`.
- MODIFY `lib/core/providers.dart`.
- UI behavior:
  - Tracker has Add Habit entry point.
  - Editor supports good/bad habit type, category, name, target, unit, schedule, money value, accountability mode, reminders, status.
  - Detail screen supports Edit, Pause/Resume, Archive.
  - Archived habits leave historical logs visible but are not active in daily cards.
  - Validation prevents blank name and invalid target.
- Firestore:
  - `/users/{uid}/habits/{habitId}`.
  - `/users/{uid}/scheduled_notifications/{notificationId}` if reminders are configured.
- Events:
  - `habit_created`, `habit_updated`, `habit_archived`.
  - `notification_scheduled` if reminder is created.
- Backend:
  - No Cloud Function required.

#### Dependencies

- Task 4.1.
- Task 7.1 for final reminder lifecycle.

#### How to verify

- UI behavior: create, edit, pause, resume, archive a habit.
- Firebase console: habit `status` updates.
- Events: lifecycle events are emitted.
- Navigation: Tracker list reflects status changes.
- Expected data: archived habit logs remain in history.

#### Estimate

1 day

#### Done Criteria

- [ ] Habit editor exists.
- [ ] Pause/resume/archive exists.
- [ ] Validation exists.
- [ ] Tracker only shows active habits in daily cards.

### Task 4.4 — Implement tracker-specific habit variants

#### Why

The User Flow requires tailored tracking behavior, not generic cards only.

#### What to tell Antigravity

- MODIFY `lib/models/habit_model.dart`.
- MODIFY `lib/views/tabs/tracker_tab.dart`.
- MODIFY `lib/views/habits/habit_detail_screen.dart`.
- CREATE `lib/views/habits/variants/smoking_tracker_view.dart`.
- CREATE `lib/views/habits/variants/screen_time_tracker_view.dart`.
- CREATE `lib/views/habits/variants/mindful_eating_tracker_view.dart`.
- CREATE `lib/views/habits/variants/procrastination_tracker_view.dart`.
- CREATE `lib/views/habits/variants/hydration_tracker_view.dart`.
- CREATE `lib/views/habits/variants/meditation_tracker_view.dart`.
- CREATE `lib/views/habits/variants/money_saving_tracker_view.dart`.
- CREATE `lib/views/habits/variants/reading_tracker_view.dart`.
- CREATE `lib/views/habits/variants/exercise_tracker_view.dart`.
- CREATE `lib/views/habits/variants/routine_completion_tracker_view.dart`.
- Firestore:
  - `/users/{uid}/habits/{habitId}.variant`
  - `/users/{uid}/habit_logs/{logId}`
  - `/users/{uid}/screen_time_logs/{logId}`
  - `/users/{uid}/addiction_logs/{logId}` for addiction-specific context if needed.
- UI behavior:
  - Smoking: cigarette count, time since last, money saved, slip recovery.
  - Screen time: manual and Android imported minutes, app/category breakdown when available.
  - Mindful eating: no calorie shaming if eatingDisorderFlag is true; use mindful check-in language.
  - Procrastination: task avoided, replacement action, recovery timer.
  - Hydration: water amount quick buttons and daily target.
  - Meditation: timer and completed minutes.
  - Money saving: amount saved and streak.
  - Reading: pages/minutes and book note.
  - Exercise/running: minutes/distance/intensity.
  - Routine completion: meta tracker from daily summaries, not manual-only.
- Events:
  - Use good/bad habit log events.
  - Screen time import emits `screen_time_synced`.
- Backend:
  - No Cloud Function required for manual variants.

#### Dependencies

- Task 4.1.
- Task 1.2 for sensitive eating flag.
- Task 3.4 for routine completion variant.

#### How to verify

- UI behavior: create one habit for each variant and log it.
- Firebase console: logs have correct units and variant metadata.
- Events: expected habit/screen-time events exist.
- Navigation: each variant detail is reachable from Tracker.
- Expected data: mindful eating safety mode changes copy/behavior when flag is true.

#### Estimate

2 days

#### Done Criteria

- [ ] All listed variants exist.
- [ ] Each variant has a user-visible detail path.
- [ ] Each variant writes canonical logs.
- [ ] Safety behavior exists for mindful eating.

### Task 4.5 — Complete screen time import and UI

#### Why

Screen time is a core bad-habit signal and AI trigger.

#### What to tell Antigravity

- MODIFY `lib/services/screen_time_bridge.dart`.
- MODIFY `lib/services/screen_time_importer.dart`.
- MODIFY `lib/models/screen_time_log_model.dart`.
- MODIFY `lib/views/habits/variants/screen_time_tracker_view.dart`.
- MODIFY `lib/views/tabs/tracker_tab.dart`.
- Firestore:
  - `/users/{uid}/screen_time_logs/{logId}`
  - `/users/{uid}/habit_logs/{logId}` if mapped to a habit.
- UI behavior:
  - Show Android permission state.
  - Show manual fallback on unsupported platforms.
  - Show daily total, target, app/category breakdown if available.
  - Show loading/error/empty permission states.
- Events:
  - `screen_time_synced`.
  - `bad_habit_slip_logged` only if screen time exceeds configured threshold and maps to a bad habit.
- Backend:
  - No Cloud Function required.

#### Dependencies

- Task 4.1.
- Task 4.4.

#### How to verify

- UI behavior: unsupported platform shows manual fallback.
- Firebase console: screen time logs write with source.
- Events: `screen_time_synced` appears after import/manual save.
- Logs: permission denial does not crash.
- Expected data: over-threshold day can trigger AI after Phase 8.

#### Estimate

1 day

#### Done Criteria

- [ ] Permission states are visible.
- [ ] Manual fallback exists.
- [ ] Logs write to schema path.
- [ ] Event is emitted.

## Phase 5 - Streaks, Accountability, and Retention

### Task 5.1 — Implement production streak rules

#### Why

Streaks are central to retention and identity progress, and current logic is too simple.

#### What to tell Antigravity

- MODIFY `lib/services/streak_service.dart`.
- MODIFY `lib/models/streak_model.dart`.
- MODIFY `test/services/streak_service_contract_test.dart`.
- Firestore:
  - `/users/{uid}/streaks/{streakId}`
  - `/users/{uid}/habit_logs/{logId}`
  - `/users/{uid}/dailySummaries/{date}`
- Implement:
  - Good habit streaks.
  - Bad habit no-slip streaks.
  - Routine completion streaks.
  - Accountability modes from `/profile/main.accountabilityMode`.
  - Grace days/weekly skips if allowed by mode.
  - Milestones: 3, 7, 14, 30, 60, 90, 180, 365.
  - Ghost-day pause/resume.
  - Comeback handling.
- Events:
  - `streak_extended`
  - `streak_broken`
  - `streak_milestone_reached`
  - `streak_paused`
  - `streak_resumed`

#### Dependencies

- Task 4.1.
- Task 3.4.

#### How to verify

- UI behavior: streak cards update after day close.
- Firebase console: streak doc records current, best, lastDate, status, grace usage.
- Events: milestone events fire at 3/7/14/etc.
- Logs: ghost days pause instead of incorrectly breaking streaks when rule says pause.
- Tests: streak contract tests pass.

#### Estimate

1 day

#### Done Criteria

- [ ] Accountability modes affect streaks.
- [ ] Milestones match docs.
- [ ] Ghost pause/resume exists.
- [ ] Tests cover good and bad habit streaks.

### Task 5.2 — Add streak detail, history, and heatmaps

#### Why

The User Flow requires users to inspect streak history and understand progress.

#### What to tell Antigravity

- CREATE `lib/views/streaks/streak_detail_screen.dart`.
- CREATE `lib/views/streaks/streak_history_sheet.dart`.
- MODIFY `lib/views/tabs/home_tab.dart`.
- MODIFY `lib/views/tabs/tracker_tab.dart`.
- MODIFY `lib/core/router/app_router.dart`.
- Firestore:
  - Read `/users/{uid}/streaks/{streakId}`.
  - Read `/users/{uid}/habit_logs`.
  - Read `/users/{uid}/dailySummaries`.
- UI behavior:
  - Home streak cards are tappable.
  - Detail shows current streak, best streak, milestones, calendar heatmap, misses, grace usage.
  - Empty state for new streak.
  - Loading/error state for failed reads.
- Events:
  - No direct event emission unless user starts comeback from the detail screen.
- Backend:
  - No Cloud Function required.

#### Dependencies

- Task 5.1.

#### How to verify

- UI behavior: tap streak card from Home and Tracker.
- Firebase console: detail values match streak/log data.
- Navigation: back navigation returns to original tab.
- Expected data: heatmap matches logs.

#### Estimate

1 day

#### Done Criteria

- [ ] Streak cards are tappable.
- [ ] Detail screen exists.
- [ ] Heatmap/history works.
- [ ] Empty/loading/error states exist.

### Task 5.3 — Implement ghost-day and comeback flow

#### Why

Long-term retention depends on graceful re-entry after inactivity.

#### What to tell Antigravity

- CREATE `lib/views/retention/comeback_modal.dart`.
- MODIFY `lib/core/event_orchestrator.dart`.
- MODIFY `lib/services/routine_service.dart`.
- MODIFY `lib/services/streak_service.dart`.
- MODIFY `functions/jobs/inactivityCheck.js`.
- Firestore:
  - `/users/{uid}/events_recent/{eventId}`
  - `/users/{uid}/dailySummaries/{date}`
  - `/users/{uid}/streaks/{streakId}`
  - `/users/{uid}/suggestions/{suggestionId}`
- Detect inactivity at 1, 3, 7, 14, and 30 days.
- UI behavior:
  - On app return after ghost period, show comeback modal before normal Home content.
  - Modal offers restart today, reduce plan, or review missed days.
  - User can accept a reduced plan.
- Events:
  - `ghost_day_detected`
  - `comeback_initiated`
  - `suggestion_generated`
  - `suggestion_accepted` or `suggestion_dismissed`
- Backend:
  - Cloud Function detects inactive users and writes ghost event/suggestion.
  - Client also detects on app open for offline/late cases.

#### Dependencies

- Task 3.4.
- Task 5.1.
- Task 8.4 for final suggestions UX; this task can write simple suggestions first.

#### How to verify

- UI behavior: seed last activity 3 days ago and reopen app; comeback modal appears.
- Firebase console: ghost/comeback events and suggestion docs exist.
- Logs: duplicate app opens do not duplicate ghost events.
- Navigation: accepting restart routes to Home/Routine with reduced plan visible.

#### Estimate

1 day

#### Done Criteria

- [ ] Ghost thresholds are detected.
- [ ] Comeback modal exists.
- [ ] Restart/reduce plan actions write Firestore.
- [ ] Events are idempotent.

## Phase 6 - Goals and Identity

### Task 6.1 — Complete identity and goal schema/services

#### Why

Goals must become active identity systems, not read-only cards.

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
  - `/users/{uid}/habits/{habitId}` for connected habits.
  - `/users/{uid}/tasks/{taskId}` for connected tasks.
- Goal fields:
  - `goalId`, `title`, `identityTag`, `why`, `status`, `progress`, `targetDate`, `milestones`, `connectedHabitIds`, `connectedRoutineTypes`, `createdAt`, `updatedAt`, `archivedAt`.
- Identity profile fields:
  - `identityStatement`, `identityTags`, `strengths`, `areasToImprove`, `score`, `lastComputedAt`, `coachStyle`, `accountabilityMode`.
- Events:
  - `identity_progress_changed`
  - `milestone_completed`
- Backend:
  - No Cloud Function required; state aggregator can compute from Firestore/events.

#### Dependencies

- Task 3.4.
- Task 4.1.
- Task 5.1.

#### How to verify

- UI behavior: existing Goals/Profile still load after schema update.
- Firebase console: goals and identity profile have required fields.
- Events: identity progress event fires when score changes.
- Logs: aggregator handles users with no goals.

#### Estimate

1 day

#### Done Criteria

- [ ] Goal schema is complete.
- [ ] Identity profile schema is complete.
- [ ] Aggregator computes identity progress.
- [ ] Empty state is safe.

### Task 6.2 — Build full Goals tab flows

#### Why

Users need to create, inspect, and maintain identity goals from the Goals tab.

#### What to tell Antigravity

- MODIFY `lib/views/tabs/goals_tab.dart`.
- CREATE `lib/views/goals/goal_editor_screen.dart`.
- CREATE `lib/views/goals/goal_detail_screen.dart`.
- CREATE `lib/views/goals/milestone_editor_sheet.dart`.
- MODIFY `lib/core/router/app_router.dart`.
- UI behavior:
  - Goals tab shows identity statement, today's identity push, active goals grid, archived section.
  - Add Goal opens editor.
  - Goal detail shows progress, why score, milestones, connected habits/tasks, AI suggestion area, pause/archive.
  - Milestones can be added/completed.
  - User can connect habits/routine types to a goal.
  - Empty/loading/error states exist.
- Firestore:
  - `/users/{uid}/goals/{goalId}`
  - `/users/{uid}/identity_profile/main`
- Events:
  - `identity_progress_changed`
  - `milestone_completed`
  - `suggestion_generated` only when AI recommendation is created.
- Backend:
  - No Cloud Function required until AI suggestion generation in Phase 8.

#### Dependencies

- Task 6.1.

#### How to verify

- UI behavior: create a goal, add milestone, connect a habit, complete milestone, archive goal.
- Firebase console: goal fields update.
- Events: milestone and identity events appear.
- Navigation: all goal screens are reachable from Goals tab.
- Expected data: archived goals do not count toward active identity push.

#### Estimate

1 day

#### Done Criteria

- [ ] Add/edit/detail goal flows exist.
- [ ] Milestones work.
- [ ] Habit connections work.
- [ ] Why score is visible.

### Task 6.3 — Connect identity to Home/Profile/AI context

#### Why

Identity is a core product promise and must appear outside the Goals tab.

#### What to tell Antigravity

- MODIFY `lib/views/tabs/home_tab.dart`.
- MODIFY `lib/views/tabs/profile_tab.dart`.
- MODIFY `lib/services/state_aggregator_service.dart`.
- MODIFY `lib/models/context_snapshot.dart`.
- Firestore:
  - Read `/users/{uid}/identity_profile/main`.
  - Write `/users/{uid}/ai_context_snapshots/{snapshotId}` with identity context.
- UI behavior:
  - Home shows today's identity push.
  - Profile shows identity hero, strengths, and areas to improve.
  - Mission ring includes identity-aligned task/habit contribution.
  - Loading/empty states for new users.
- Events:
  - `identity_progress_changed` when score changes.
- Backend:
  - No Cloud Function required in this task.

#### Dependencies

- Task 6.1.
- Task 3.4.

#### How to verify

- UI behavior: complete a connected habit/task and see identity progress update.
- Firebase console: identity profile score changes.
- Events: identity event appears once per meaningful score change.
- Expected data: context snapshot includes identity tags and active goals.

#### Estimate

4h

#### Done Criteria

- [ ] Identity appears on Home.
- [ ] Identity appears on Profile.
- [ ] Context snapshot includes identity.
- [ ] Mission ring uses identity contribution.

## Phase 7 - Notifications and Custom Alarms

### Task 7.1 — Complete notification lifecycle service

#### Why

Notifications are a core user loop and AI signal. They need lifecycle records, not just local scheduling.

#### What to tell Antigravity

- MODIFY `lib/services/notification_service.dart`.
- MODIFY `lib/models/scheduled_notification_model.dart`.
- MODIFY `lib/core/event_orchestrator.dart`.
- MODIFY `lib/main.dart`.
- MODIFY `functions/index.js` or create `functions/jobs/notificationDispatcher.js`.
- Firestore:
  - `/users/{uid}/scheduled_notifications/{notificationId}`
  - `/users/{uid}/notificationLog/{logId}`
  - `/users/{uid}/events_recent/{eventId}`
- Implement:
  - `requestPermissions`
  - `scheduleForTask`
  - `scheduleCustom`
  - `cancel`
  - `reRegisterAllOnAppStart`
  - `recordSent`
  - `recordTapped`
  - `recordDismissed`
  - `recordSuppressed`
- UI behavior:
  - Deep links route to task, habit, coach, goal, or comeback screen.
- Events:
  - `notification_scheduled`
  - `notification_sent`
  - `notification_tapped`
  - `notification_dismissed`
  - `notification_suppressed`
- Backend:
  - Cloud Functions can dispatch server notifications later; local notifications must still write lifecycle logs where possible.

#### Dependencies

- Task 2.1.
- Task 2.2.

#### How to verify

- UI behavior: schedule a task reminder and tap notification to open task.
- Firebase console: scheduled notification and notification log docs exist.
- Events: all available lifecycle events are emitted.
- Logs: app restart re-registers pending notifications.
- Expected data: notification records include category, priority, scheduledFor, status, deepLink.

#### Estimate

1 day

#### Done Criteria

- [ ] Lifecycle methods exist.
- [ ] Deep links work.
- [ ] Re-registration runs on app start.
- [ ] Notification events write to Firestore.

### Task 7.2 — Implement notification priority, caps, dedupe, and settings

#### Why

The docs require adaptive notifications with priority and restraint.

#### What to tell Antigravity

- MODIFY `lib/services/notification_service.dart`.
- MODIFY `lib/models/scheduled_notification_model.dart`.
- MODIFY `lib/views/tabs/profile_tab.dart`.
- CREATE `lib/views/settings/notification_settings_screen.dart`.
- MODIFY `lib/core/router/app_router.dart`.
- Firestore:
  - `/users/{uid}/profile/main.notificationSettings`
  - `/users/{uid}/scheduled_notifications/{notificationId}`
  - `/users/{uid}/notificationLog/{logId}`
- Implement priorities:
  - P1 custom alarms.
  - P2 active task reminders.
  - P3 schedule-critical reminders.
  - P4 habit/streak reminders.
  - P5 AI nudges.
  - P6 summaries.
- Implement caps:
  - Daily cap.
  - Rolling 60-minute cap.
  - Category cap.
  - Quiet hours/sleep block.
  - Dedupe/coalescing similar notifications.
- UI behavior:
  - Profile -> Notification Settings.
  - Toggles by category.
  - Quiet hours picker.
  - Daily cap control.
  - Permission state.
  - Loading/error states.
- Events:
  - `notification_suppressed` when cap/quiet/dedupe blocks a notification.
- Backend:
  - Cloud Functions must read the same settings before sending server notifications.

#### Dependencies

- Task 7.1.
- Task 1.2 for sleep block.

#### How to verify

- UI behavior: change quiet hours and daily cap.
- Firebase console: settings save under profile.
- Logs: duplicate notification attempts create suppression event.
- Expected data: notifications during quiet hours are suppressed unless P1.

#### Estimate

1 day

#### Done Criteria

- [ ] Settings screen exists.
- [ ] Priority model exists.
- [ ] Caps and dedupe work.
- [ ] Suppression events are logged.

### Task 7.3 — Add custom alarm UX

#### Why

Custom alarms are explicitly required in the daily routine flow.

#### What to tell Antigravity

- CREATE `lib/views/alarms/custom_alarm_sheet.dart`.
- CREATE `lib/views/alarms/alarm_ringing_screen.dart`.
- CREATE `lib/views/alarms/alarm_reason_sheet.dart`.
- MODIFY `lib/views/routine/routine_tab.dart`.
- MODIFY `lib/services/notification_service.dart`.
- MODIFY `lib/services/task_service.dart`.
- Firestore:
  - `/users/{uid}/scheduled_notifications/{notificationId}`
  - `/users/{uid}/tasks/{taskId}.customAlarm`
  - `/users/{uid}/notificationLog/{logId}`
- UI behavior:
  - User can add custom alarm to task/routine item.
  - Alarm ringing screen has Start, Snooze, Stop.
  - If user stops without starting task, ask reason.
  - Snooze updates notification record.
  - Stop reason can create `task_skipped` or leave task scheduled depending choice.
- Events:
  - `notification_scheduled`
  - `notification_tapped`
  - `task_started`
  - `task_skipped`
  - `notification_dismissed`
- Backend:
  - Local notification first. FCM/server send can be added in Task 10.2.

#### Dependencies

- Task 3.1.
- Task 7.1.

#### How to verify

- UI behavior: add an alarm to a task, receive it, tap Start, then repeat and Snooze/Stop.
- Firebase console: task customAlarm and notification docs update.
- Events: start/snooze/stop produce expected events.
- Navigation: ringing/tap routes to correct screen.

#### Estimate

1 day

#### Done Criteria

- [ ] Custom alarm sheet exists.
- [ ] Ringing screen exists.
- [ ] Snooze/stop/start work.
- [ ] Stop reason updates task/event data.

## Phase 8 - AI Master Engine and Coach

### Task 8.1 — Expand context snapshots and rule engine

#### Why

The AI must make decisions from structured state, not raw chat only.

#### What to tell Antigravity

- MODIFY `lib/services/state_aggregator_service.dart`.
- MODIFY `lib/services/rule_engine_service.dart`.
- MODIFY `lib/models/context_snapshot.dart`.
- MODIFY `lib/models/coach_rule.dart`.
- CREATE `docs/ai_rulebook_mapping.md`.
- Firestore:
  - `/users/{uid}/ai_context_snapshots/{snapshotId}`
  - `/users/{uid}/events_recent/{eventId}`
  - `/users/{uid}/tasks/{taskId}`
  - `/users/{uid}/habits/{habitId}`
  - `/users/{uid}/habit_logs/{logId}`
  - `/users/{uid}/dailySummaries/{date}`
  - `/users/{uid}/goals/{goalId}`
  - `/users/{uid}/notificationLog/{logId}`
  - `/users/{uid}/coach_speak_log/{logId}`
- Implement rule inputs for:
  - Missed gym.
  - Instagram/screen-time overuse.
  - Smoking 4 cigarettes.
  - Missed routines.
  - Good progress.
  - Bad habit slip patterns.
  - Stress/sleep risk.
  - Crisis/safety.
  - Inactivity/ghost.
  - Bad-day pattern.
  - Streak milestone.
  - End-of-day summary.
- Events:
  - Rule engine reacts to existing events; it emits `suggestion_generated` or queues coach reply through CoachService.
- Backend:
  - No direct LLM call in this task. Rules decide whether AI is allowed to speak.

#### Dependencies

- Phase 2.
- Phase 3.
- Phase 4.
- Phase 5.
- Phase 6.
- Phase 7.

#### How to verify

- UI behavior: trigger sample missed task/slip/streak and see proactive card or suggestion where expected.
- Firebase console: context snapshots include all required state.
- Logs: rule evaluation includes matched rule ID and suppression reason.
- Expected data: speak log prevents repeated nudges.

#### Estimate

2 days

#### Done Criteria

- [ ] Context snapshot is complete.
- [ ] Rulebook mapping exists.
- [ ] Required rules are implemented.
- [ ] Speak budget is respected.

### Task 8.2 — Complete Coach chat contracts and topic modes

#### Why

Coach chat is user-facing and must be evented, safe, and mode-aware.

#### What to tell Antigravity

- MODIFY `lib/views/tabs/coach_tab.dart`.
- MODIFY `lib/services/coach_service.dart`.
- MODIFY `lib/services/gemini_service.dart`.
- MODIFY `functions/index.js`.
- Firestore:
  - `/users/{uid}/coach_messages/{messageId}`
  - `/users/{uid}/coach_speak_log/{logId}`
  - `/users/{uid}/events_recent/{eventId}`
- UI behavior:
  - Add topic modes: Today, Habits, Routine, Goals, Recovery, Ask Anything.
  - Show loading, retry, offline, and empty states.
  - Persist both user and coach messages.
  - Safety/crisis content routes to safe response and optional handoff, not generic coaching.
- Events:
  - `coach_message_sent`
  - `coach_replied`
- Backend:
  - `aiGenerate` callable receives mode, recent context snapshot, safety flags, and user message.
  - Function returns structured response: text, mode, safetyLevel, suggestedActions.
  - Do not expose API key in Flutter.

#### Dependencies

- Task 8.1.
- Task 1.2 for safety flags.

#### How to verify

- UI behavior: send a message in each mode.
- Firebase console: user and coach messages persist.
- Events: sent/replied events exist.
- Logs: crisis-like input returns safe response path.
- Expected data: `coach_speak_log` records reply metadata.

#### Estimate

1 day

#### Done Criteria

- [ ] Topic modes exist.
- [ ] Chat emits events.
- [ ] Safety path exists.
- [ ] Function response is structured.

### Task 8.3 — Implement suggestions system and Routine AI panel

#### Why

The docs require AI suggestions that users can accept or dismiss.

#### What to tell Antigravity

- MODIFY `lib/views/routine/ai_routine_panel.dart`.
- MODIFY `lib/core/event_orchestrator.dart`.
- CREATE `lib/models/suggestion_model.dart`.
- CREATE `lib/services/suggestion_service.dart`.
- CREATE `lib/views/suggestions/suggestion_detail_sheet.dart`.
- MODIFY `lib/core/providers.dart`.
- Firestore:
  - `/users/{uid}/suggestions/{suggestionId}`
  - `/users/{uid}/events_recent/{eventId}`
- Suggestion fields:
  - `suggestionId`, `type`, `title`, `body`, `reason`, `targetPath`, `status`, `priority`, `expiresAt`, `createdAt`, `acceptedAt`, `dismissedAt`, `sourceRuleId`.
- UI behavior:
  - Routine AI panel reads real suggestions.
  - User can accept or dismiss.
  - Accepting routine suggestion updates future routine/tasks.
  - Empty state appears when no suggestions.
  - Loading/error states exist.
- Events:
  - `suggestion_generated`
  - `suggestion_accepted`
  - `suggestion_dismissed`
- Backend:
  - Rule engine creates suggestions.
  - LLM may write copy only after rule decides suggestion type.

#### Dependencies

- Task 8.1.
- Task 3.3.

#### How to verify

- UI behavior: seed a suggestion and accept/dismiss it in Routine AI panel.
- Firebase console: suggestion status updates.
- Events: accept/dismiss events exist.
- Navigation: targetPath opens correct screen.
- Expected data: accepted routine suggestion changes future tasks only.

#### Estimate

1 day

#### Done Criteria

- [ ] Suggestion model/service exists.
- [ ] Routine AI panel uses Firestore suggestions.
- [ ] Accept/dismiss works.
- [ ] Events are emitted.

### Task 8.4 — Implement strategic AI scheduled jobs

#### Why

The AI Master Engine requires morning, midday, day-close, inactivity, and safety jobs.

#### What to tell Antigravity

- MODIFY `functions/index.js`.
- MODIFY `functions/jobs/morningBrief.js`.
- MODIFY `functions/jobs/middayPulse.js`.
- MODIFY `functions/jobs/dayClose.js`.
- MODIFY `functions/jobs/inactivityCheck.js`.
- CREATE `functions/jobs/aiPlanner.js`.
- CREATE `functions/jobs/ruleEngine.js`.
- CREATE `functions/jobs/safety.js`.
- CREATE `functions/jobs/notifications.js`.
- Firestore:
  - `/users/{uid}/ai_context_snapshots/{snapshotId}`
  - `/users/{uid}/coach_messages/{messageId}`
  - `/users/{uid}/coach_speak_log/{logId}`
  - `/users/{uid}/suggestions/{suggestionId}`
  - `/users/{uid}/scheduled_notifications/{notificationId}`
  - `/users/{uid}/events_recent/{eventId}`
- Backend behavior:
  - Morning job emits/uses `day_started`.
  - Midday job checks drift and suggestions.
  - Day-close job summarizes and writes coach message if allowed.
  - Inactivity job writes ghost/comeback suggestions.
  - Safety job detects crisis markers and avoids normal coaching.
  - Notification job respects priority/caps/settings.
- Events:
  - `coach_replied`, `suggestion_generated`, `notification_scheduled`, `notification_suppressed`, `ghost_day_detected`, `day_closed`.
- UI:
  - Home/Coach/Routine should display generated coach messages and suggestions.

#### Dependencies

- Task 8.1.
- Task 8.2.
- Task 8.3.
- Task 7.2.

#### How to verify

- Run Firebase emulator scheduled functions manually.
- Firebase console/emulator: generated messages/suggestions appear under user.
- Logs: jobs skip users without required data safely.
- UI behavior: generated items appear in Home/Coach/Routine.
- Expected data: speak log prevents over-messaging.

#### Estimate

2 days

#### Done Criteria

- [ ] Scheduled AI jobs are schema-aligned.
- [ ] Jobs respect notification/speak budgets.
- [ ] Generated outputs are user-visible.
- [ ] Emulator tests cover jobs.

## Phase 9 - Profile, Settings, Privacy, and Subscription

### Task 9.1 — Complete Profile identity and settings hub

#### Why

Profile is the user's control center for identity, coach, accountability, notifications, and account.

#### What to tell Antigravity

- MODIFY `lib/views/tabs/profile_tab.dart`.
- CREATE `lib/views/settings/coach_settings_screen.dart`.
- CREATE `lib/views/settings/accountability_settings_screen.dart`.
- CREATE `lib/views/settings/about_you_settings_screen.dart`.
- MODIFY `lib/core/router/app_router.dart`.
- Firestore:
  - `/users/{uid}/profile/main`
  - `/users/{uid}/identity_profile/main`
- UI behavior:
  - Profile hero shows identity statement, strengths, areas to improve.
  - Coach card opens coach settings.
  - Accountability card opens accountability settings.
  - About You opens editable body/lifestyle/sensitive data.
  - Notification settings links to Task 7.2 screen.
  - Loading/error/empty states exist.
- Events:
  - `biometrics_updated` for About You edits.
  - `identity_progress_changed` if settings change score.
- Backend:
  - No Cloud Function required.

#### Dependencies

- Task 6.3.
- Task 7.2.

#### How to verify

- UI behavior: open every settings screen from Profile.
- Firebase console: edited settings persist.
- Events: biometrics event fires on About You edit.
- Navigation: back returns to Profile.

#### Estimate

1 day

#### Done Criteria

- [ ] Profile hub exposes all required settings.
- [ ] Identity hero uses real data.
- [ ] About You editor exists.
- [ ] Settings persist.

### Task 9.2 — Implement privacy, export, and deletion lifecycle

#### Why

Production apps need safe account data controls. Current hard-delete behavior is not enough.

#### What to tell Antigravity

- MODIFY `lib/views/tabs/profile_tab.dart`.
- CREATE `lib/views/settings/privacy_data_screen.dart`.
- CREATE `functions/jobs/exportUserData.js`.
- CREATE `functions/jobs/deleteUserData.js`.
- MODIFY `firestore.rules` if new server-only paths are added.
- Firestore:
  - `/users/{uid}/data_exports/{exportId}`
  - `/users/{uid}/deletion_requests/{requestId}`
  - Existing user subtree for export/delete.
- UI behavior:
  - User can request export.
  - User sees export status: queued, processing, ready, failed.
  - User can request account deletion with confirmation.
  - Deletion is queued with recovery window, not immediate destructive client delete.
  - User can cancel pending deletion before cutoff.
- Events:
  - `account_deleted` only after backend deletion completes.
- Backend:
  - Cloud Function creates export file/record.
  - Cloud Function processes deletion after recovery window.
  - Client must not recursively delete all data directly.

#### Dependencies

- Task 2.2.

#### How to verify

- UI behavior: request export and deletion in emulator.
- Firebase console: request docs are created.
- Logs: function updates status.
- Expected data: canceling deletion changes request status and does not delete user data.

#### Estimate

1 day

#### Done Criteria

- [ ] Privacy/data screen exists.
- [ ] Export request lifecycle exists.
- [ ] Deletion request lifecycle exists.
- [ ] Immediate client hard-delete is removed or gated behind backend flow.

### Task 9.3 — Add subscription and limit gates

#### Why

The PRD includes subscription-related product surfaces and AI/notification costs need limits.

#### What to tell Antigravity

- CREATE `lib/views/settings/subscription_screen.dart`.
- MODIFY `lib/views/tabs/profile_tab.dart`.
- MODIFY `lib/services/coach_service.dart`.
- MODIFY `lib/services/notification_service.dart`.
- MODIFY `lib/services/habit_service.dart` if free-tier habit count is limited.
- Firestore:
  - `/users/{uid}/profile/main.subscription`
  - `/users/{uid}/usage/{monthKey}` if usage counters are added.
- UI behavior:
  - Profile shows subscription status.
  - Subscription screen shows current plan and limits.
  - If payments are not integrated yet, show a disabled upgrade CTA with clear internal TODO.
  - Free limits can cap AI messages, proactive nudges, or active habits.
- Events:
  - No new canonical event required unless subscription event names are added intentionally.
- Backend:
  - Cloud Functions should enforce AI usage caps, not only UI.

#### Dependencies

- Task 8.2.
- Task 7.2.

#### How to verify

- UI behavior: open subscription screen and see plan state.
- Firebase console: subscription fields exist.
- Logs: AI usage cap blocks extra call and returns user-friendly UI state.
- Expected data: limits are enforced in backend and UI.

#### Estimate

1 day

#### Done Criteria

- [ ] Subscription screen exists.
- [ ] Profile links to subscription.
- [ ] Usage limits are visible.
- [ ] Backend enforces AI cap if cap is enabled.

## Phase 10 - Analytics, Cloud Functions, and Operations

### Task 10.1 — Implement analytics summaries

#### Why

Production needs analytics for user progress, AI decisions, and product health.

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
- Analytics fields:
  - Task completion rate.
  - Routine completion rate.
  - Habit completion.
  - Slip count.
  - Screen time total.
  - Streak changes.
  - Identity score.
  - Notification sent/tapped/dismissed/suppressed counts.
  - AI messages/suggestions generated/accepted/dismissed.
- UI:
  - Surface daily summary on Home/Profile.
  - Surface weekly summary in Profile or Tracker.
- Events:
  - Use existing day/suggestion/notification events.
- Backend:
  - Weekly Cloud Function computes weekly summary.

#### Dependencies

- Phases 3 through 8.

#### How to verify

- UI behavior: daily/weekly summaries appear after seeded data.
- Firebase console: summary docs have all metrics.
- Logs: weekly summary job handles empty weeks.
- Expected data: counts match event logs.

#### Estimate

1 day

#### Done Criteria

- [ ] Daily analytics complete.
- [ ] Weekly summary job exists.
- [ ] UI exposes summaries.
- [ ] Metrics match source data.

### Task 10.2 — Implement server notification dispatcher

#### Why

Production reminders need reliable backend delivery where local scheduling is insufficient.

#### What to tell Antigravity

- CREATE `functions/jobs/notificationDispatcher.js`.
- MODIFY `functions/index.js`.
- MODIFY `lib/services/notification_service.dart`.
- Firestore:
  - `/users/{uid}/scheduled_notifications/{notificationId}`
  - `/users/{uid}/notificationLog/{logId}`
  - `/users/{uid}/profile/main.notificationSettings`
- Backend:
  - Query due scheduled notifications.
  - Respect priority, caps, quiet hours, dedupe, and user settings.
  - Send FCM if device token storage exists; otherwise mark as pending_local and do not crash.
  - Emit/write notification lifecycle events using server event helper.
- UI:
  - Existing notification center/settings display sent/suppressed status.
- Events:
  - `notification_sent`
  - `notification_suppressed`

#### Dependencies

- Task 7.1.
- Task 7.2.

#### How to verify

- Emulator: seed due notification and run dispatcher.
- Firebase console: status changes to sent or suppressed.
- Logs: no send occurs during quiet hours unless P1.
- UI behavior: notification center reflects status.

#### Estimate

1 day

#### Done Criteria

- [ ] Dispatcher exists.
- [ ] Caps/settings are enforced server-side.
- [ ] Lifecycle logs are written.
- [ ] Missing FCM token is handled safely.

### Task 10.3 — Add cleanup, archive, and backfill jobs

#### Why

The event schema uses recent and archive collections; production needs cleanup/backfill.

#### What to tell Antigravity

- CREATE `functions/jobs/eventMaintenance.js`.
- CREATE `functions/jobs/schemaBackfill.js`.
- MODIFY `functions/index.js`.
- Firestore:
  - `/users/{uid}/events_recent/{eventId}`
  - `/users/{uid}/events/{eventId}`
  - Any old/mismatched paths documented in `docs/firestore_schema_v1_mapping.md`.
- Backend:
  - Trim or TTL-manage `events_recent`.
  - Keep full `events` archive.
  - Backfill old docs missing `schemaVersion`, `uid`, or normalized fields.
  - Dry-run mode must exist before write mode.
- UI:
  - No user-facing UI required.
- Events:
  - Do not emit user behavior events for maintenance changes.

#### Dependencies

- Task 2.1.
- Task 2.2.

#### How to verify

- Emulator: seed old data and run dry-run.
- Logs: dry-run reports exact changes.
- Run write mode in emulator and inspect docs.
- Expected data: recent events are trimmed without deleting archive events.

#### Estimate

1 day

#### Done Criteria

- [ ] Maintenance jobs exist.
- [ ] Dry-run exists.
- [ ] Backfill handles old schema.
- [ ] Archive is preserved.

### Task 10.4 — Add monitoring and remote config controls

#### Why

Production AI, notifications, and experiments need operational kill switches.

#### What to tell Antigravity

- MODIFY `lib/services/remote_config_service.dart`.
- MODIFY `lib/main.dart`.
- MODIFY `lib/services/global_error_handler.dart`.
- MODIFY `functions/index.js`.
- Firestore/Remote Config:
  - Add config keys for AI enabled, proactive coach enabled, notifications enabled, custom alarms enabled, screen time enabled, subscription limits enabled.
  - Keep local fallback defaults.
- UI:
  - If a feature is disabled, show graceful disabled state, not broken UI.
- Backend:
  - Functions check kill-switch flags before generating AI messages or notifications.
- Events:
  - `notification_suppressed` can be used if notification feature disabled.
  - Do not emit fake user events for disabled features.

#### Dependencies

- Phases 7 and 8.

#### How to verify

- Toggle local/default config and confirm feature disables gracefully.
- Logs: disabled AI job skips work.
- UI behavior: Coach and notifications show disabled state.
- Expected data: no new AI/notification docs are created when disabled.

#### Estimate

4h

#### Done Criteria

- [ ] Remote config keys exist.
- [ ] App has graceful disabled states.
- [ ] Functions honor kill switches.
- [ ] Crash/error logging remains active.

## Phase 11 - Production QA and Release

### Task 11.1 — Build full test suite

#### Why

The app touches user identity, routines, addiction tracking, AI, and notifications. Release without tests is unsafe.

#### What to tell Antigravity

- MODIFY existing test files under `test/services/`.
- CREATE widget tests:
  - `test/widgets/onboarding_flow_test.dart`
  - `test/widgets/home_tab_test.dart`
  - `test/widgets/routine_tab_test.dart`
  - `test/widgets/tracker_tab_test.dart`
  - `test/widgets/coach_tab_test.dart`
  - `test/widgets/goals_tab_test.dart`
  - `test/widgets/profile_tab_test.dart`
- CREATE integration smoke tests if project supports them:
  - `integration_test/onboarding_to_home_test.dart`
  - `integration_test/daily_loop_test.dart`
- MODIFY `functions/test/*.test.js`.
- Test coverage:
  - Auth/onboarding.
  - Event idempotency.
  - Task lifecycle.
  - Habit logging.
  - Streak/accountability.
  - Day close.
  - Notifications.
  - Coach safety.
  - Suggestions.
  - Goals/identity.
  - Privacy/export/delete.
- Backend:
  - Firebase emulator tests for rules and functions.

#### Dependencies

- All implementation phases.

#### How to verify

- Run `flutter test`.
- Run `flutter test integration_test` if configured.
- Run `cd functions && npm test`.
- Run Firebase emulator rules/functions tests.
- Expected data: tests use isolated fake/emulator users.

#### Estimate

2 days

#### Done Criteria

- [ ] Service tests pass.
- [ ] Widget tests pass.
- [ ] Function tests pass.
- [ ] Integration smoke test passes or documented blocker exists.

### Task 11.2 — Production data migration and seed checklist

#### Why

Existing partial users may have older data shapes. Production launch must not break them.

#### What to tell Antigravity

- CREATE `docs/migration_checklist.md`.
- CREATE `docs/seed_data_checklist.md`.
- MODIFY `functions/jobs/schemaBackfill.js` if needed.
- Include migrations for:
  - User root fields.
  - `profile/main`.
  - `onboarding/state`.
  - `routine/current`.
  - Habits and flat habit logs.
  - Tasks missing date/status fields.
  - Streak docs.
  - Events missing envelope fields.
  - Notification path naming.
  - Coach messages.
  - Goals/identity.
- Include seed users:
  - New user.
  - Existing partial onboarding user.
  - Active routine user.
  - Habit-heavy user.
  - Ghost user.
  - Safety-flag user.
- UI:
  - No direct UI unless migration status screen is desired for internal builds.
- Backend:
  - Backfill must support dry-run.

#### Dependencies

- Task 10.3.

#### How to verify

- Emulator: run migration dry-run on seed users.
- Logs: checklist records every path touched.
- UI behavior: all seed users can open app without crash.
- Expected data: migrated docs match schema.

#### Estimate

1 day

#### Done Criteria

- [ ] Migration checklist exists.
- [ ] Seed checklist exists.
- [ ] Dry-run migration works.
- [ ] Seed users cover major flows.

### Task 11.3 — Final completeness audit

#### Why

The final goal is 100% implementation from all seven documents.

#### What to tell Antigravity

- MODIFY `docs/feature_matrix.md`.
- CREATE `docs/release_readiness_report.md`.
- For every feature row, confirm:
  - UI exists.
  - State management exists.
  - Firestore path exists.
  - Backend/Cloud Function exists if needed.
  - Event triggers exist.
  - AI integration exists if applicable.
  - Notifications exist if applicable.
  - Analytics exists if applicable.
  - Verification exists.
  - User-visible path exists.
- Run manual flows:
  - Signup -> onboarding -> AI plan -> Home.
  - First day routine start/complete/skip.
  - Habit good log and bad slip.
  - Streak milestone.
  - Notification tap.
  - Coach chat and proactive suggestion.
  - Goal creation and milestone.
  - Profile settings edit.
  - Export/delete request.
  - Ghost comeback.
- Do not mark release ready while any row is partial/missing.

#### Dependencies

- Tasks 0.1 through 11.2.

#### How to verify

- UI behavior: all manual flows complete.
- Firebase console: all required paths contain expected data.
- Logs: no unhandled exceptions.
- Tests: all automated suites pass.
- Expected data: `docs/release_readiness_report.md` has no unresolved critical gaps.

#### Estimate

1 day

#### Done Criteria

- [ ] Feature matrix has no missing rows.
- [ ] Release report exists.
- [ ] Manual flows pass.
- [ ] Automated tests pass.
- [ ] Every feature has UI/backend/Firestore/event/verification coverage.

## 8. Completeness Check

Use this checklist after every phase:

- [ ] Every feature touched has a user-visible UI path.
- [ ] Every state-changing UI action writes Firestore.
- [ ] Every state-changing UI action emits a canonical event.
- [ ] Every Firestore path matches `OPTIVUS Docs/7_Optivus_Database_Schema.md`.
- [ ] Every service method matches `OPTIVUS Docs/5_Optivus_ServiceContracts.md`.
- [ ] Every AI behavior waits for event/context/rule prerequisites.
- [ ] Every notification behavior records scheduled/sent/tapped/dismissed/suppressed when applicable.
- [ ] Every feature has loading, error, and empty states.
- [ ] Every feature has verification steps.
- [ ] Existing working code was extended, not rewritten unnecessarily.

## 9. File Output

This file is the required output:

`todo_V1_(fixed)_All_Features.md`

