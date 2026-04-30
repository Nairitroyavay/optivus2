# Optivus Production TODO V1 Fixed All Features

Date: 2026-04-30
Scope: planning and Antigravity task instructions only. No implementation code is included.

## 1. Short Summary

1. The current Optivus app is a real Flutter/Firebase codebase, not a fresh project.
2. The code already has Firebase initialization, Auth, Firestore, Riverpod providers, GoRouter, six main tabs, onboarding, tasks, habits, streaks, routine, coach, notifications, export/delete, and some Cloud Functions.
3. The codebase is ahead of a prototype, but it is not yet production-complete against the seven system documents.
4. Firestore-first is the canonical v1 architecture. Postgres references in V2 docs are future-state only and must not drive v1 migrations.
5. The most important gap is consistency: some flows use real services, some use partial data, and some production paths still rely on incomplete defaults or TODO behavior.
6. The user flow document requires a connected loop from signup to onboarding to routine/habit/task logging to day close to coaching to retention.
7. Onboarding currently covers core choices, but it does not fully implement the 11-step documented flow, especially About You, safety-sensitive questions, notification preferences, and resilient resume behavior.
8. Auth works for email/password and creates a user document, but it needs production polish around display name, sign-out events, deletion, provider linking, and account lifecycle verification.
9. Home exists and reads real providers, but the mission ring, calendar, progress, and coach prompts need to be backed by canonical summaries and events.
10. Routine setup and task generation exist, but routine completion, drift analysis, full alarms, timeline accuracy, and server/client day-close alignment are incomplete.
11. Task lifecycle is partially implemented with scheduled, started, paused, resumed, completed, skipped, and abandoned states.
12. Habit logging is partially implemented and writes both nested and flat logs, but habit CRUD events and tracker-specific schemas are incomplete.
13. Streaks exist but need documented grace, pause, ghost-day, comeback, and milestone rules.
14. Tracker coverage is partial. Water, smoking, screen time, junk food, procrastination, meditation, reading, exercise, money saving, and routine completion each need complete UI, schema, events, backend, and verification.
15. Goals and identity exist in early form but need documented identity scoring, milestones, habit links, weekly review, and UI paths.
16. The event service already writes to `/users/{uid}/events` and `/users/{uid}/events_recent`, but it needs strict event contracts, idempotency, schema validation, and failure behavior.
17. Cloud Functions exist for AI generation and scheduled jobs, but they are not yet the authoritative production event processors.
18. The AI coach has a rule engine and Gemini function, but the AI Master Engine requirements are much broader: rule-first decisions, speak budget, safety, crisis SOP, memory, output validation, and cost controls.
19. Notifications exist locally, but custom alarms, server pushes, token/device handling, tap/dismiss events, quiet hours, and budgets need completion.
20. Profile has privacy/export/delete work started, but the export/delete scope must match the final Firestore schema and the UI must explain account deletion clearly.
21. Account deletion must delete the Firebase Auth user as well as Firestore data. After the Auth user is deleted, the same Gmail can create a new account, subject to Firebase provider rules and any provider-specific identity constraints.
22. Analytics is mostly missing beyond events and daily summaries.
23. Tests are currently not sufficient for production readiness.
24. The first implementation priority is not UI polish. It is schema, events, services, security rules, indexes, and test scaffolding.
25. Backend and Firestore contracts must be stabilized before adding new screens.
26. Event system must be stable before AI.
27. Habit logs and task events must be stable before streaks and day close.
28. Day close must be stable before dashboard summaries and coaching insights.
29. Notification budgets and scheduled notification persistence must be stable before proactive coach behavior.
30. The phase plan below starts from the current codebase and finishes at a production-ready app with frontend, backend, Firestore, events, AI, notifications, analytics, and tests.

## 2. Sources Read

Documents read:

- `OPTIVUS Docs/1_Optivus_PRD.md`
- `OPTIVUS Docs/2_Optivus_UserFlow.md`
- `OPTIVUS Docs/3_Optivus_EventSystem.md`
- `OPTIVUS Docs/4_Optivus_SystemDesign_Production.md`
- `OPTIVUS Docs/5_Optivus_ServiceContracts.md`
- `OPTIVUS Docs/6_Optivus_AI_Master_Engine.md`
- `OPTIVUS Docs/7_Optivus_Database_Schema.md`
- V2 patch documents for PRD, User Flow, Event System, System Design, Service Contracts, AI Master Engine, and Database Schema.

Code areas reviewed:

- `lib/main.dart`
- `lib/core/providers.dart`
- `lib/core/router/app_router.dart`
- `lib/core/providers/bootstrap_provider.dart`
- `lib/core/event_orchestrator.dart`
- `lib/models/*`
- `lib/providers/*`
- `lib/repositories/*`
- `lib/services/*`
- `lib/views/screens/*`
- `lib/views/tabs/*`
- `functions/index.js`
- `functions/jobs/*`
- `functions/utils.js`

## 3. Codebase Analysis

### Already Implemented

- Flutter app boots Firebase, Firestore persistence, Crashlytics, Remote Config, App Check, and Riverpod.
- Auth flow exists with email/password signup and login.
- Router/bootstrap flow exists for unauthenticated, onboarding, and ready states.
- `/users/{uid}` root document is created on signup.
- Onboarding screen exists and saves partial onboarding progress.
- Home screen exists with the six-tab app shell.
- Tabs exist for Home, Routine, Tracker, Coach, Goals, and Profile.
- Task service exists and uses `/users/{uid}/tasks`.
- Habit service exists and uses `/users/{uid}/habits` plus `/users/{uid}/habit_logs`.
- Streak service exists and uses `/users/{uid}/streaks`.
- Event service exists and writes to `/users/{uid}/events` and `/users/{uid}/events_recent`.
- Routine service and repository exist and use `/users/{uid}/routine/current`.
- Notification service exists and persists scheduled notifications under `/users/{uid}/scheduled_notifications`.
- Coach service, rule engine, context aggregator, and Gemini Cloud Function exist.
- Cloud Functions exist for AI generation, day close, inactivity, morning brief, and midday pulse.
- Profile export/delete work exists for a subset of user-owned collections.
- Current implementation has real service integration in many core flows, not only demo UI.

### Partially Implemented

- Signup/login: real Firebase Auth and Firestore user creation exist, but lifecycle events and display name consistency need hardening.
- Onboarding: core preference pages exist, but the full documented flow, About You, safety questions, notification settings, and skip/resume logic are incomplete.
- Home: reads providers, but mission ring and summary data are not fully canonical.
- Routine: supports some setup and task syncing, but completion analytics, drift, server authority, and alarms are incomplete.
- Tasks: lifecycle exists, but quick-complete, auto-abandon, alarm tiers, skip semantics, and server idempotency need alignment.
- Habits: logging exists, but CRUD events, pause/resume, archive/delete semantics, tracker-specific details, and validation need completion.
- Streaks: current/longest streak updates exist, but grace, ghost, comeback, milestone rules, and server/client consistency need completion.
- Coach: rule engine and Gemini function exist, but safety, memory, output validation, cost control, and rule coverage are incomplete.
- Notifications: local notifications exist, but production scheduling, tap/dismiss events, FCM, quiet hours, budgets, and custom alarms are incomplete.
- Profile: export/delete exists, but the final collection list is incomplete and delete must include Firebase Auth account deletion confirmation.
- Cloud Functions: scheduled jobs exist, but they overlap with client logic and are not yet the canonical event processors.

### Not Implemented

- Full 11-step onboarding with all documented fields.
- About You editor and sensitive data controls.
- Complete tracker detail screens for every documented tracker.
- Full identity goals system with why score, milestones, and habit connections.
- Complete AI Master Engine with rule-first, LLM-wording-only mode.
- Crisis detection SOP and handoff records.
- Coach memory snapshots and user-readable memory controls.
- Notification device registry and FCM push pipeline.
- BigQuery analytics and production dashboards.
- Comprehensive Firestore security rules and index verification.
- Emulator-based integration tests for signup to day close.
- Complete QA release checklist and production smoke automation.

### Needs Refactoring

- Align all event names and payloads to the Event System catalog.
- Make `EventService` transaction-safe and schema-validated.
- Remove duplicate or conflicting day-close authority between client and Cloud Functions.
- Convert TODO-driven coach orchestration into explicit supported cases.
- Ensure every write path emits a documented event or intentionally documents why no event is required.
- Expand export/delete to cover every final user-owned collection.
- Replace any UI default that appears as real user data with empty/loading/error states.
- Normalize Firestore paths across providers, services, and Cloud Functions.

### Do Not Touch Unless Required

- Firebase initialization in `lib/main.dart`, except for production hardening tasks.
- Existing Riverpod/provider structure.
- Existing GoRouter bootstrap pattern.
- Existing six-tab navigation shell.
- Existing Firestore-first v1 direction.
- Existing task, habit, event, notification, and coach services as extension points.
- Existing user-owned subtree model under `/users/{uid}`.

## 4. User Flow Breakdown

### Onboarding Flow

Step: Signup

- User action: enters name, email, password, and taps create account.
- UI screen: `lib/views/screens/signup_screen.dart`
- Backend action: Firebase Auth creates user; app creates `/users/{uid}`.
- Firestore write: `/users/{uid}` with email, name, onboarding flags, timestamps.
- Event triggered: `user_signed_up`.

Step: Welcome and focus areas

- User action: chooses why they are using Optivus.
- UI screen: `lib/views/screens/onboarding_screen.dart`
- Backend action: save onboarding draft.
- Firestore write: `/users/{uid}/onboarding/state`.
- Event triggered: no final event yet; draft update can emit `onboarding_step_saved` if added.

Step: Bad habits

- User action: selects habits to reduce such as smoking, screen time, junk food, procrastination.
- UI screen: onboarding bad habit page.
- Backend action: save selected bad habits.
- Firestore write: `/users/{uid}/onboarding/state`.
- Event triggered: `onboarding_step_saved`.

Step: Good habits

- User action: selects habits to build such as water, meditation, reading, exercise.
- UI screen: onboarding good habit page.
- Backend action: save selected good habits.
- Firestore write: `/users/{uid}/onboarding/state`.
- Event triggered: `onboarding_step_saved`.

Step: Identity goals

- User action: chooses identities and goals.
- UI screen: onboarding identity page.
- Backend action: save goals draft.
- Firestore write: `/users/{uid}/onboarding/state`.
- Event triggered: `onboarding_step_saved`.

Step: About You

- User action: enters biometrics, lifestyle, and optional sensitive context.
- UI screen: onboarding About You pages.
- Backend action: validate optional fields and privacy flags.
- Firestore write: `/users/{uid}/profile/main`.
- Event triggered: `biometrics_updated` and `profile_preferences_updated`.

Step: Coach style and coach name

- User action: selects tone and name.
- UI screen: onboarding coach page.
- Backend action: save coach settings.
- Firestore write: `/users/{uid}/profile/main`.
- Event triggered: `coach_preferences_updated`.

Step: Accountability and notifications

- User action: chooses accountability type, notification permission, quiet hours, budget.
- UI screen: onboarding accountability page.
- Backend action: save settings and request local permission.
- Firestore write: `/users/{uid}/profile/main`.
- Event triggered: `notification_preferences_updated`.

Step: Schedule and routine

- User action: adds fixed blocks and routine preferences.
- UI screen: onboarding schedule page.
- Backend action: save routine and generate initial tasks.
- Firestore write: `/users/{uid}/routine/current`, `/users/{uid}/tasks`.
- Event triggered: `routine_created`, `task_scheduled`.

Step: Plan ready

- User action: taps finish.
- UI screen: onboarding final page.
- Backend action: materialize habits, goals, routine, notification settings.
- Firestore write: `/users/{uid}`, `/users/{uid}/habits`, `/users/{uid}/goals`, `/users/{uid}/routine/current`.
- Event triggered: `onboarding_completed`.

### First Day Experience

- User action: lands on Home after onboarding.
- UI screen: `lib/views/tabs/home_tab.dart`.
- Backend action: load today tasks, active habits, streaks, coach prompts.
- Firestore read: `/users/{uid}/tasks`, `/users/{uid}/habits`, `/users/{uid}/habit_logs`, `/users/{uid}/streaks`, `/users/{uid}/coach_messages`.
- Event triggered: `day_started` if this is the first daily session.

- User action: starts first task.
- UI screen: Home task card or Routine timeline.
- Backend action: update task state.
- Firestore write: `/users/{uid}/tasks/{taskId}`.
- Event triggered: `task_started`.

- User action: logs first good habit or bad habit slip.
- UI screen: Home log sheet or Tracker tab.
- Backend action: create flat habit log and nested habit log.
- Firestore write: `/users/{uid}/habit_logs/{logId}` and `/users/{uid}/habits/{habitId}/logs/{date}/items/{logId}`.
- Event triggered: `good_habit_logged` or `bad_habit_slip_logged`.

- User action: closes the day or returns after midnight.
- UI screen: Home/day close summary.
- Backend action: aggregate tasks, habits, streaks, routine, identity.
- Firestore write: `/users/{uid}/dailySummaries/{yyyy-MM-dd}`, `/users/{uid}/streaks/{habitId}`.
- Event triggered: `day_closed`, `routine_day_summarized`, streak events.

### Daily Usage Loop

- Morning: app opens, morning brief loads, today's tasks and habits are shown.
- Work block: user starts, pauses, resumes, completes, skips, or abandons tasks.
- Habit loop: user logs good habits, bad habit slips, tracker details, and notes.
- Coach loop: rule engine reacts to important events and writes coach messages.
- Routine loop: timeline shows schedule, current block, next task, alarms, and completion.
- Evening: day close aggregates behavior and asks for tomorrow planning.
- Retention: ghost-day, comeback, streak, milestone, and identity events drive reengagement.

### Event Trigger Points

- Auth: `user_signed_up`, `user_signed_in`, `user_signed_out`, `account_deleted`.
- Onboarding: `onboarding_step_saved`, `onboarding_completed`, `biometrics_updated`.
- Routine: `routine_created`, `routine_updated`, `routine_day_started`, `routine_day_summarized`.
- Tasks: `task_scheduled`, `task_started`, `task_paused`, `task_resumed`, `task_completed`, `task_abandoned`, `task_skipped`, `subtask_checked`.
- Habits: `habit_created`, `habit_updated`, `habit_paused`, `habit_resumed`, `habit_archived`, `good_habit_logged`, `bad_habit_slip_logged`.
- Trackers: `screen_time_imported`, `screen_time_spike_detected`, `water_logged`, `meditation_completed`, `reading_logged`, `exercise_logged`, `money_saved_logged`, `junk_food_logged`, `procrastination_logged`.
- Streaks: `streak_extended`, `streak_broken`, `streak_milestone_reached`, `ghost_day_detected`, `comeback_detected`.
- Coach: `coach_message_sent`, `coach_message_replied`, `coach_suggestion_shown`, `coach_suggestion_accepted`, `coach_suggestion_dismissed`.
- Notifications: `notification_scheduled`, `notification_delivered`, `notification_opened`, `notification_dismissed`, `notification_suppressed`.
- Summaries: `day_closed`, `weekly_summary_generated`.

### AI Interaction Points

- After important events through `EventOrchestrator`.
- On Coach tab user messages.
- During routine planning suggestions.
- During failure recovery after slips or abandoned tasks.
- During end-of-day reflection.
- During weekly review and identity progress.
- During comeback after inactivity.
- During crisis or sensitive language detection, with strict safety behavior.

### Feature Entry Points

- Signup: `/signup`
- Login: `/login`
- Onboarding: `/onboarding`
- Main app: `/home`
- Home tab: mission ring, today's tasks, habit check-ins, coach prompt.
- Routine tab: timeline, routine setup, active task controls.
- Tracker tab: tracker home, habit logs, tracker detail screens.
- Coach tab: messages, suggestions, user replies.
- Goals tab: identity goals, milestones, linked habits.
- Profile tab: settings, About You, notifications, privacy, export/delete, sign out.

### Retention Loops

- Streak milestone loop: logs -> streak update -> message/notification -> next log.
- Failure recovery loop: slip/missed task -> coach support -> smaller next action -> comeback.
- Routine completion loop: scheduled tasks -> completed tasks -> day summary -> tomorrow plan.
- Identity loop: habit/task proof -> goal progress -> identity score -> next recommended action.
- Ghost-day loop: inactivity detection -> gentle reentry -> reduced plan -> resumed usage.

## 5. Feature Inventory and Completion Score

| Feature | Status | Score |
|---|---|---:|
| Firebase boot/App Check/Crashlytics | Partially complete | 75 |
| Email signup/login | Partially complete | 70 |
| Auth account lifecycle/delete/recreate | Partially complete | 55 |
| Router/bootstrap flow | Partially complete | 75 |
| Full onboarding | Partially complete | 45 |
| About You profile | Mostly missing | 15 |
| Home mission dashboard | Partially complete | 45 |
| Routine builder | Partially complete | 55 |
| Task lifecycle | Partially complete | 65 |
| Habit core logging | Partially complete | 60 |
| Habit CRUD events | Mostly missing | 25 |
| Smoking tracker | Partially complete | 35 |
| Screen time tracker | Partially complete | 30 |
| Junk food tracker | Mostly missing | 15 |
| Procrastination tracker | Mostly missing | 10 |
| Water tracker | Partially complete | 45 |
| Meditation tracker | Mostly missing | 15 |
| Reading tracker | Mostly missing | 10 |
| Exercise/running tracker | Mostly missing | 20 |
| Money saving tracker | Mostly missing | 10 |
| Routine completion tracker | Mostly missing | 20 |
| Streak system | Partially complete | 45 |
| Goals and identity | Partially complete | 35 |
| Event system | Partially complete | 55 |
| Cloud Functions jobs | Partially complete | 35 |
| Coach chat | Partially complete | 45 |
| AI Master Engine | Mostly missing | 15 |
| AI safety/crisis/cost/memory | Mostly missing | 10 |
| Notifications | Partially complete | 35 |
| Analytics/BigQuery | Mostly missing | 10 |
| Profile/settings/privacy | Partially complete | 50 |
| Export/delete | Partially complete | 55 |
| Security rules/indexes | Partially complete | 30 |
| Tests/QA | Mostly missing | 5 |
| Release hardening | Mostly missing | 10 |

## 6. Dependency Map

1. Firebase config, security rules, indexes, and emulator setup must come first.
2. Auth and bootstrap must be stable before onboarding and main app flows.
3. Firestore schema constants and model contracts must exist before services are expanded.
4. Event service idempotency and event catalog validation must exist before downstream automations.
5. Habit logs and task events must exist before streaks, summaries, home metrics, and AI.
6. Routine schedule and generated tasks must exist before routine completion scoring.
7. Streak service must depend on habit logs and day-close summaries.
8. Day close must depend on task states, habit logs, routine data, and streaks.
9. Home dashboard must depend on daily summaries, today tasks, active habits, streaks, and coach messages.
10. Goals and identity scoring must depend on habits, tasks, streaks, and events.
11. Notifications must depend on task schedules, habit reminders, budgets, quiet hours, and device tokens.
12. Coach rule engine must depend on event history, context snapshots, notification budget, and safety settings.
13. LLM generation must come after rule selection, context building, safety checks, and output validation.
14. Cloud Functions must become canonical for scheduled jobs before production release.
15. Analytics must depend on stable event taxonomy and summaries.
16. Export/delete must include all final user-owned collections after schema is finalized.
17. Integration tests must cover signup, onboarding, home, routine, tracker, coach, profile, and day close before release.

## 7. Phase-Wise TODO List

### Phase 1 - Stabilize Firebase Foundation

#### Task 1.1 - Verify Firebase Setup, Security Rules, and Indexes

##### Why
Production behavior depends on correct Firebase configuration before feature work.

##### What to tell Antigravity
MODIFY `firebase.json`, `firestore.rules`, `firestore.indexes.json`, `lib/main.dart`, and any existing Firebase config files. Confirm the app uses Firebase Auth, Firestore persistence, Crashlytics, Remote Config, and App Check without demo bypasses. Add or verify indexes for `/users/{uid}/events`, `/events_recent`, `/habit_logs`, `/tasks`, `/coach_messages`, `/addiction_logs`, and `/scheduled_notifications`. Ensure Firestore rules only allow authenticated users to read/write their own `/users/{uid}` subtree and protect append-only event assumptions.

##### Dependencies
None.

##### How to verify
Run Firebase emulator rules tests or manual emulator writes. Confirm one user cannot read another user's subtree. Confirm queries used by providers do not require missing indexes.

##### Estimate
4h

##### Done Criteria
- [ ] Firestore rules match the v1 schema.
- [ ] All required indexes are declared.
- [ ] App Check has debug/dev and production behavior documented.
- [ ] No Firebase demo project paths are used in production config.

#### Task 1.2 - Add Test Harness and Emulator Baseline

##### Why
Every later feature needs repeatable verification.

##### What to tell Antigravity
CREATE or MODIFY `test/`, `integration_test/`, `functions/test/`, `pubspec.yaml`, and Firebase emulator scripts. Add a beginner-friendly test README. Add emulator seed data for one user with onboarding complete, habits, tasks, routine, streaks, coach messages, and scheduled notifications. Do not change production behavior.

##### Dependencies
Task 1.1.

##### How to verify
Run Flutter unit tests, widget tests, and Firebase emulator tests. Confirm tests can create and delete an isolated test user subtree.

##### Estimate
1 day

##### Done Criteria
- [ ] Test folders exist.
- [ ] Emulator can run locally.
- [ ] Seed data matches documented Firestore paths.
- [ ] CI or local command list is documented.

#### Task 1.3 - Remove Misleading Production Placeholders

##### Why
The app must not show fake values as if they are user data.

##### What to tell Antigravity
MODIFY `lib/views/screens/signup_screen.dart`, `lib/views/screens/login_screen.dart`, `lib/views/screens/onboarding_screen.dart`, `lib/views/tabs/home_tab.dart`, `lib/views/tabs/routine_tab.dart`, `lib/views/tabs/tracker_tab.dart`, `lib/views/tabs/coach_tab.dart`, `lib/views/tabs/profile_tab.dart`, and supporting widgets. Replace fake/demo values in production paths with loading, empty, or setup states. Keep visual placeholders only where clearly labeled as sample copy or onboarding previews.

##### Dependencies
Task 1.1.

##### How to verify
Create a brand-new account in emulator. Every empty state should say what the user can do next, not show fake completed stats.

##### Estimate
4h

##### Done Criteria
- [ ] No fake streaks, fake tasks, fake coach history, or fake profile stats appear for new users.
- [ ] Empty states are clear.
- [ ] Existing real provider wiring remains intact.

### Phase 2 - Auth, Bootstrap, and Account Lifecycle

#### Task 2.1 - Harden Signup, Login, Sign Out, and Account Events

##### Why
Auth is the first production user flow and must create trustworthy data.

##### What to tell Antigravity
MODIFY `lib/services/auth_service.dart`, `lib/core/providers/bootstrap_provider.dart`, `lib/core/router/app_router.dart`, `lib/views/screens/signup_screen.dart`, and `lib/views/screens/login_screen.dart`. On signup, set Firebase Auth display name, create `/users/{uid}`, create `/users/{uid}/profile/main`, and emit `user_signed_up`. On login, update `lastLoginAt` and emit `user_signed_in`. On sign out, emit `user_signed_out` before signing out. Keep validation, loading, and error states visible.

##### Dependencies
Phase 1.

##### How to verify
UI: signup, logout, login work. Firebase console: `/users/{uid}` and `/profile/main` exist. Logs: `user_signed_up`, `user_signed_in`, and `user_signed_out` appear in `/events`.

##### Estimate
4h

##### Done Criteria
- [ ] Auth display name and Firestore name match.
- [ ] Auth screens show errors safely.
- [ ] Auth lifecycle events are recorded.
- [ ] Bootstrap redirects correctly.

#### Task 2.2 - Make Account Deletion Complete and Re-Signup Safe

##### Why
Users must own their data, and same Gmail signup must work after deletion.

##### What to tell Antigravity
MODIFY `lib/services/firestore_service.dart`, `lib/services/auth_service.dart`, `lib/views/tabs/profile_tab.dart`, and any supporting profile services. Delete only after explicit typed confirmation. Export and delete all final user-owned paths: `/users/{uid}`, `/profile`, `/onboarding`, `/routine`, `/tasks`, `/habits`, `/habit_logs`, `/goals`, `/streaks`, `/events`, `/events_recent`, `/coach_messages`, `/coach_chats`, `/coach_speak_log`, `/dailySummaries`, `/scheduled_notifications`, `/screen_time_logs`, `/addiction_logs`, `/ai_context_snapshots`, `/journal_entries`, and any final profile subcollections. Emit `account_deleted`, then delete Firestore subtree in safe batches, then delete Firebase Auth user. If recent login is required, show re-auth UI. Document that same Gmail can sign up again only after Firebase Auth user deletion succeeds.

##### Dependencies
Task 2.1 and final schema tasks.

##### How to verify
UI: deletion requires explicit confirmation. Firebase console: user subtree is gone. Auth console: user is gone. Signup with the same Gmail creates a new uid or account according to Firebase provider behavior. Logs: `account_deleted` exists before deletion or in audit destination if retained.

##### Estimate
1 day

##### Done Criteria
- [ ] No destructive shortcut is used.
- [ ] Export includes every user-owned collection.
- [ ] Delete handles pagination/batches.
- [ ] Auth user is deleted.
- [ ] Same email re-signup is verified.

#### Task 2.3 - Stabilize Bootstrap and First-Run Routing

##### Why
Users must never get stuck between onboarding and home.

##### What to tell Antigravity
MODIFY `lib/core/providers/bootstrap_provider.dart`, `lib/core/router/app_router.dart`, `lib/repositories/user_repository.dart`, and onboarding completion calls. Treat `/users/{uid}.hasCompletedOnboarding` as the routing flag and `/users/{uid}/onboarding/state` as draft state. Handle missing user doc repair, missing profile doc repair, loading, auth expired, and offline cached state.

##### Dependencies
Task 2.1.

##### How to verify
UI: fresh signup goes to onboarding; completed user goes to home; deleted/missing user doc shows a repair-safe state. Firebase console: flags update exactly once.

##### Estimate
4h

##### Done Criteria
- [ ] No route loops.
- [ ] Offline cached ready state works.
- [ ] Missing docs are repaired or surfaced safely.

### Phase 3 - Full Onboarding

#### Task 3.1 - Expand Onboarding State Model

##### Why
The documented onboarding requires more data than the current provider stores.

##### What to tell Antigravity
MODIFY `lib/providers/onboarding_provider.dart`, `lib/repositories/user_repository.dart`, and onboarding models. Add fields for focus areas, bad habits, good habits, identity goals, biometrics, lifestyle, sensitive flags, coach style, coach name, accountability type, notification preferences, quiet hours, daily notification budget, fixed schedule, timezone, version, currentStep, skippedSteps, and completedAt. Save drafts to `/users/{uid}/onboarding/state`.

##### Dependencies
Phase 2.

##### How to verify
UI: leave onboarding halfway, restart app, continue from last step. Firebase console: `/onboarding/state` has all fields and currentStep.

##### Estimate
1 day

##### Done Criteria
- [ ] All documented onboarding fields are represented.
- [ ] Draft save is debounced and resilient.
- [ ] Skip behavior is explicit.

#### Task 3.2 - Implement the Complete Onboarding UI Flow

##### Why
The User Flow document defines what the user sees before first use.

##### What to tell Antigravity
MODIFY `lib/views/screens/onboarding_screen.dart` and existing onboarding widgets. Add the full 11-step flow: welcome, focus areas, bad habits, good habits, identity goals, About You biometrics, About You lifestyle, About You sensitive optional, coach style/name, accountability/notifications, schedule/routine, plan ready. Use existing styling. Add validation, back/next, progress, skip where allowed, loading, and error states.

##### Dependencies
Task 3.1.

##### How to verify
UI: complete onboarding from a new account. Firebase console: draft updates on each step. Logs: final `onboarding_completed` only fires once.

##### Estimate
1 day

##### Done Criteria
- [ ] All documented screens are accessible.
- [ ] Required fields block next until valid.
- [ ] Optional sensitive fields are clearly optional.
- [ ] Resume works.

#### Task 3.3 - Materialize Onboarding into Production Collections

##### Why
Onboarding must create real app state, not only save answers.

##### What to tell Antigravity
MODIFY `lib/repositories/user_repository.dart`, `lib/services/habit_service.dart`, `lib/services/task_service.dart`, `lib/repositories/routine_repository.dart`, and `lib/services/event_service.dart`. On finish, create `/profile/main`, `/routine/current`, `/habits/{habitId}`, `/goals/{goalId}`, initial `/tasks/{taskId}` if schedule requires, and notification preferences. Emit `onboarding_completed`, `habit_created`, `goal_created`, `routine_created`, and `task_scheduled` where applicable.

##### Dependencies
Tasks 3.1, 3.2, 4.1.

##### How to verify
Firebase console: new user has real habits, goals, profile, and routine. UI: Home, Routine, Tracker, Goals, and Profile all show the same data.

##### Estimate
1 day

##### Done Criteria
- [ ] No onboarding answer is lost.
- [ ] Materialization is idempotent.
- [ ] Events are emitted once.

### Phase 4 - Event System Foundation

#### Task 4.1 - Make EventService Idempotent and Contract-Validated

##### Why
Every automation depends on trustworthy events.

##### What to tell Antigravity
MODIFY `lib/services/event_service.dart`, `lib/models/app_event.dart`, and `lib/core/providers.dart`. CREATE `lib/core/events/event_catalog.dart`. Implement canonical event names, payload versions, required fields, and safe validation. Use transaction or deterministic idempotent writes so retries do not duplicate events. Always write to `/users/{uid}/events/{eventId}` and `/users/{uid}/events_recent/{eventId}`. Do not publish local events until the write succeeds unless explicitly documented as optimistic.

##### Dependencies
Phase 1.

##### How to verify
Emit the same event twice with same idempotency key. Firebase console shows one event. Invalid payload is rejected and logged.

##### Estimate
1 day

##### Done Criteria
- [ ] Event names are centralized.
- [ ] Payload validation exists.
- [ ] Idempotency is tested.
- [ ] Events and events_recent stay in sync.

#### Task 4.2 - Align All Services to Event Catalog

##### Why
Services currently emit some events with incomplete or inconsistent payloads.

##### What to tell Antigravity
MODIFY `lib/services/task_service.dart`, `lib/services/habit_service.dart`, `lib/services/streak_service.dart`, `lib/services/routine_service.dart`, `lib/services/notification_service.dart`, `lib/services/coach_service.dart`, and `functions/utils.js`. Replace string literals with catalog constants. Ensure every payload includes required ids, names, timestamps, source, and metadata. Add missing CRUD events.

##### Dependencies
Task 4.1.

##### How to verify
Run emulator flows for task complete, habit log, notification schedule, coach message, and day close. Firebase console events match the catalog exactly.

##### Estimate
1 day

##### Done Criteria
- [ ] No unmanaged event names remain in core services.
- [ ] Missing service events are added.
- [ ] Cloud Functions use the same names.

#### Task 4.3 - Add Event Replay, Recent Pruning, and Failure Logging

##### Why
The app needs bounded UI reads and recoverable event processing.

##### What to tell Antigravity
MODIFY `lib/core/event_orchestrator.dart`, `lib/services/event_service.dart`, `functions/jobs/dayClose.js`, and `functions/utils.js`. Keep `/events_recent` for UI and short-term rules. Keep `/events` as append-only history. Add pruning for recent events by age/count. Log processing failures to `/users/{uid}/event_errors/{errorId}` without crashing user flows.

##### Dependencies
Task 4.1.

##### How to verify
Seed more than the recent retention limit. Recent collection prunes; full events remain. Simulated processor failure creates an event error.

##### Estimate
4h

##### Done Criteria
- [ ] Recent retention is documented.
- [ ] Replay is bounded.
- [ ] Failures are visible.

### Phase 5 - Task Engine

#### Task 5.1 - Complete Task Model and Lifecycle

##### Why
Tasks are central to routine, home, day close, and AI context.

##### What to tell Antigravity
MODIFY `lib/models/task_model.dart`, `lib/services/task_service.dart`, `lib/views/tabs/home_tab.dart`, `lib/views/tabs/routine_tab.dart`, and task widgets. Support scheduled, started, paused, resumed, completed, skipped, and abandoned. Add fields: title, notes, category, source, routineBlockId, goalId, habitId, plannedStart, plannedEnd, startedAt, completedAt, state, priority, alarmTier, subtasks, createdAt, updatedAt. Store at `/users/{uid}/tasks/{taskId}`. Emit all task events.

##### Dependencies
Phase 4.

##### How to verify
UI: user can start, pause, resume, complete, skip, and abandon a task. Firebase console: task state and event history match each action.

##### Estimate
1 day

##### Done Criteria
- [ ] All lifecycle states work.
- [ ] Invalid transitions are blocked.
- [ ] Subtask checks emit events.
- [ ] Home and Routine show current state.

#### Task 5.2 - Add Task Auto-Abandon and End Reminder Logic

##### Why
The documents require task follow-through and failure recovery.

##### What to tell Antigravity
MODIFY `lib/services/task_service.dart`, `lib/services/notification_service.dart`, `functions/jobs/dayClose.js`, and any scheduled job needed. If a task remains started past plannedEnd plus grace, mark it abandoned or prompt the user depending on notification settings. Emit `task_abandoned` with reason. Schedule end reminders in `/scheduled_notifications`.

##### Dependencies
Task 5.1 and Phase 12.

##### How to verify
Create a short task, let it pass the end time in emulator, run scheduled job. Firebase console: state changes and event appears.

##### Estimate
4h

##### Done Criteria
- [ ] Auto behavior is idempotent.
- [ ] User can still manually resolve.
- [ ] Notifications respect budget and quiet hours.

### Phase 6 - Routine System

#### Task 6.1 - Version Routine Schema and Repository

##### Why
Routine data drives generated tasks and daily summaries.

##### What to tell Antigravity
MODIFY `lib/repositories/routine_repository.dart`, `lib/providers/routine_provider.dart`, `lib/models/routine_model.dart`, and routine-related screens. Store canonical routine at `/users/{uid}/routine/current` with version, timezone, fixedBlocks, classes, meals, skincare, exercise, windDown, generatedTaskRules, updatedAt. Emit `routine_created` and `routine_updated`.

##### Dependencies
Phase 4.

##### How to verify
UI: edit schedule, restart app, routine persists. Firebase console: `/routine/current` contains versioned fields.

##### Estimate
1 day

##### Done Criteria
- [ ] Routine schema is versioned.
- [ ] Existing routine users migrate safely.
- [ ] Routine updates emit events.

#### Task 6.2 - Sync Routine to Tasks Without Duplication

##### Why
Generated tasks must not duplicate on every app open.

##### What to tell Antigravity
MODIFY `lib/services/task_service.dart`, `lib/services/routine_service.dart`, and `lib/repositories/routine_repository.dart`. Generate routine tasks for today and tomorrow using deterministic ids or generation keys. Store generated tasks in `/tasks`. Emit `task_scheduled` only for new tasks. Update changed future generated tasks safely.

##### Dependencies
Tasks 5.1 and 6.1.

##### How to verify
Open app three times. Firebase console: generated task count does not multiply. Changed routine updates future tasks.

##### Estimate
1 day

##### Done Criteria
- [ ] Task generation is idempotent.
- [ ] User-edited tasks are not overwritten unexpectedly.
- [ ] Events are not duplicated.

#### Task 6.3 - Complete Routine UI Paths

##### Why
Routine is one of the main user-visible product pillars.

##### What to tell Antigravity
MODIFY `lib/views/tabs/routine_tab.dart` and routine setup screens/widgets. Ensure users can view today timeline, current block, next task, setup fixed schedule, setup meals, setup classes, setup skincare, edit routine, and see routine completion. Use real `/routine/current` and `/tasks` data only.

##### Dependencies
Tasks 6.1 and 6.2.

##### How to verify
UI: from Routine tab, every routine setting is reachable and persists. Firebase console: edits update `/routine/current` and generated tasks.

##### Estimate
1 day

##### Done Criteria
- [ ] All routine entry points work.
- [ ] Empty states guide setup.
- [ ] No fake routine rows appear.

### Phase 7 - Habit Core

#### Task 7.1 - Complete Habit CRUD and Events

##### Why
Habit creation, editing, pausing, archiving, and deleting must be explicit and auditable.

##### What to tell Antigravity
MODIFY `lib/models/habit_model.dart`, `lib/services/habit_service.dart`, `lib/views/tabs/tracker_tab.dart`, and habit widgets/sheets. Store habits at `/users/{uid}/habits/{habitId}` with name, type, trackerType, target, unit, frequency, reminder settings, status, createdAt, updatedAt, archivedAt. Emit `habit_created`, `habit_updated`, `habit_paused`, `habit_resumed`, `habit_archived`, and `habit_deleted`.

##### Dependencies
Phase 4.

##### How to verify
UI: create, edit, pause, resume, archive a habit. Firebase console: habit status changes and events exist.

##### Estimate
1 day

##### Done Criteria
- [ ] CRUD actions are user-visible.
- [ ] Destructive delete is confirmed.
- [ ] Archive is the default non-destructive removal.

#### Task 7.2 - Standardize Habit Logs

##### Why
Streaks, trackers, summaries, and AI depend on reliable logs.

##### What to tell Antigravity
MODIFY `lib/services/habit_service.dart`, `lib/models/habit_log_model.dart`, `lib/core/providers.dart`, and logging sheets. Use `/users/{uid}/habit_logs/{logId}` as the canonical query path. Keep nested habit logs only if needed for UI convenience. Required fields: habitId, habitName, habitType, trackerType, amount, unit, mood, note, ts, localDate, source, createdAt. Emit `good_habit_logged` or `bad_habit_slip_logged`.

##### Dependencies
Task 7.1.

##### How to verify
Log good and bad habits. Firebase console: flat logs contain complete fields and events reference the same logId.

##### Estimate
4h

##### Done Criteria
- [ ] Logs are consistent.
- [ ] Providers read canonical logs.
- [ ] Bad habit slips and good habit completions are distinct.

### Phase 8 - Tracker Feature Set

#### Task 8.1 - Build Tracker Home and Detail Navigation

##### Why
Each tracker needs a user-visible path and real data.

##### What to tell Antigravity
MODIFY `lib/views/tabs/tracker_tab.dart`. CREATE tracker detail widgets under `lib/views/tabs/tracker/` if that folder does not exist. Tracker home must show active trackers from `/habits`, today's logs from `/habit_logs`, and detail navigation for smoking, screen time, junk food, procrastination, water, meditation, reading, exercise, money saving, and routine completion.

##### Dependencies
Phase 7.

##### How to verify
UI: every active tracker opens a detail screen. New user sees setup empty state. Firebase console reads come from `/habits` and `/habit_logs`.

##### Estimate
1 day

##### Done Criteria
- [ ] All tracker entry points exist.
- [ ] Detail screens use real data.
- [ ] Empty/error/loading states exist.

#### Task 8.2 - Complete Smoking and Addiction Tracker

##### Why
Smoking is a core bad-habit tracker with money saved and recovery loops.

##### What to tell Antigravity
MODIFY `lib/services/habit_service.dart`, `lib/views/tabs/tracker/smoking_tracker_detail.dart`, and related models. Store slips in `/habit_logs` and optional addiction-specific detail in `/addiction_logs`. Fields: addictionType, amount, trigger, mood, cost, location optional, note, ts. Emit `bad_habit_slip_logged` and `addiction_log_created`. Update money saved and streak context.

##### Dependencies
Task 8.1.

##### How to verify
UI: log a cigarette slip with trigger and cost. Firebase console: log appears and coach/streak context updates.

##### Estimate
1 day

##### Done Criteria
- [ ] Slip logging is fast.
- [ ] Trigger/mood/cost are stored.
- [ ] Recovery coach can react.

#### Task 8.3 - Complete Screen Time Tracker

##### Why
Android system data is a first-class production input.

##### What to tell Antigravity
MODIFY existing screen time bridge/importer files, `lib/views/tabs/tracker/screen_time_tracker_detail.dart`, and Cloud Functions if needed. Store daily screen time at `/users/{uid}/screen_time_logs/{date}` with totalMinutes, unlockCount, topApps, source, importedAt. Emit `screen_time_imported` and `screen_time_spike_detected` when threshold rules fire. Add permission/error states.

##### Dependencies
Task 8.1 and Phase 4.

##### How to verify
Android UI: permission request appears, import works or shows unsupported state. Firebase console: `/screen_time_logs/{date}` exists.

##### Estimate
1 day

##### Done Criteria
- [ ] Android permission flow is clear.
- [ ] Unsupported platforms are handled.
- [ ] Spike events are emitted.

#### Task 8.4 - Complete Junk Food and Mindful Eating Tracker

##### Why
The docs require safe handling for food behavior.

##### What to tell Antigravity
CREATE or MODIFY `lib/views/tabs/tracker/junk_food_tracker_detail.dart`, habit log models, and coach safety rules. Store logs in `/habit_logs` with foodType, quantity, trigger, hungerLevel, mood, note. Use neutral language and avoid shame. If sensitive eating-disorder flags are set in `/profile/main`, disable weight-loss framing and aggressive coaching. Emit `junk_food_logged`.

##### Dependencies
Tasks 3.1 and 8.1.

##### How to verify
UI: log junk food without judgmental wording. Firebase console: log includes safe fields. Coach does not shame or prescribe extreme restriction.

##### Estimate
4h

##### Done Criteria
- [ ] ED-sensitive behavior exists.
- [ ] Logs are stored.
- [ ] Coach uses safe language.

#### Task 8.5 - Complete Procrastination Tracker

##### Why
Procrastination connects tasks, routine, and coaching.

##### What to tell Antigravity
CREATE or MODIFY `lib/views/tabs/tracker/procrastination_tracker_detail.dart`, `lib/services/task_service.dart`, and rule engine. Detect procrastination from repeated task delays, skips, and abandons. Allow manual log with trigger, taskId, durationMinutes, note. Store at `/habit_logs` or `/addiction_logs` according to final model. Emit `procrastination_logged`.

##### Dependencies
Tasks 5.1 and 8.1.

##### How to verify
Skip or delay tasks. UI shows procrastination pattern. Firebase console: event and log exist.

##### Estimate
4h

##### Done Criteria
- [ ] Manual and event-derived cases work.
- [ ] Coach can suggest a small next action.
- [ ] Data is visible in tracker detail.

#### Task 8.6 - Complete Good Habit Trackers

##### Why
Water, meditation, reading, exercise, and money saving need complete user paths.

##### What to tell Antigravity
CREATE or MODIFY tracker detail files for water, meditation, reading, exercise, and money saving under `lib/views/tabs/tracker/`. Use `/habits` for configuration and `/habit_logs` for logs. Add fields specific to each tracker: water amount/unit; meditation duration; reading book/title/pages/minutes; exercise type/duration/intensity; money amount/category. Emit `water_logged`, `meditation_completed`, `reading_logged`, `exercise_logged`, and `money_saved_logged`.

##### Dependencies
Task 8.1.

##### How to verify
UI: each tracker can create at least one valid log. Firebase console: logs and events contain tracker-specific fields.

##### Estimate
1 day

##### Done Criteria
- [ ] Each tracker has a detail path.
- [ ] Each tracker writes real logs.
- [ ] Empty states and validation exist.

### Phase 9 - Streaks and Day Close

#### Task 9.1 - Implement Canonical Streak Rules

##### Why
Streaks are retention-critical and must match documented behavior.

##### What to tell Antigravity
MODIFY `lib/services/streak_service.dart`, `lib/models/streak_model.dart`, and Cloud Function day-close logic. Use `/users/{uid}/streaks/{habitId}`. Implement currentStreak, longestStreak, lastCompletedDate, status, graceUsed, pausedDates, milestones, and updatedAt. Emit `streak_extended`, `streak_broken`, `streak_milestone_reached`, `ghost_day_detected`, and `comeback_detected`.

##### Dependencies
Phases 4 and 7.

##### How to verify
Seed logs across multiple days. Run day close. Firebase console: streak values and milestone events are correct.

##### Estimate
1 day

##### Done Criteria
- [ ] Good and bad habit streak semantics are correct.
- [ ] Milestones are not duplicated.
- [ ] Grace/pause rules are tested.

#### Task 9.2 - Make Day Close Idempotent and Canonical

##### Why
Client and Cloud Functions currently overlap; production needs one truth.

##### What to tell Antigravity
MODIFY `lib/services/routine_service.dart`, `functions/jobs/dayClose.js`, `functions/index.js`, and `lib/core/providers.dart`. Choose Cloud Function as canonical production day close, with client fallback for offline/local catch-up. Write summaries to `/users/{uid}/dailySummaries/{yyyy-MM-dd}`. Include tasks, habit logs, streak changes, routine completion, identity progress, screen time, addiction logs, mood, and coach summary. Emit `day_closed` once.

##### Dependencies
Tasks 5.1, 7.2, 9.1.

##### How to verify
Run day close twice for same date. Firebase console: one summary and one `day_closed` event. UI: Home shows closed day summary.

##### Estimate
1 day

##### Done Criteria
- [ ] Day close is idempotent.
- [ ] Missed days are caught up.
- [ ] Client and server do not fight.

### Phase 10 - Home Dashboard

#### Task 10.1 - Build Mission Ring from Real Aggregates

##### Why
Home must reflect actual behavior, not presentation-only stats.

##### What to tell Antigravity
MODIFY `lib/views/tabs/home_tab.dart`, `lib/core/providers.dart`, and summary models. Read today's tasks, habit logs, routine progress, streaks, and goals. Compute mission ring from documented weights or from `/dailySummaries` when the day is closed. Show loading, empty, and error states.

##### Dependencies
Phase 9.

##### How to verify
Complete tasks and log habits. UI mission ring changes. Firebase console data explains every visible number.

##### Estimate
4h

##### Done Criteria
- [ ] No fake dashboard numbers.
- [ ] Home updates after logs.
- [ ] Day-closed state is shown.

#### Task 10.2 - Complete Home Entry Points

##### Why
Home is the daily command center.

##### What to tell Antigravity
MODIFY `lib/views/tabs/home_tab.dart` and navigation helpers. Home must provide visible paths to start next task, log a habit, open routine, open tracker detail, read latest coach message, view streaks, and close/review day. All paths must use existing services and Firestore paths.

##### Dependencies
Task 10.1.

##### How to verify
From Home only, complete a task, log a habit, open a tracker, and read a coach message. Firebase console: expected writes occur.

##### Estimate
4h

##### Done Criteria
- [ ] Main daily actions are reachable.
- [ ] Navigation returns cleanly.
- [ ] Error states do not trap the user.

### Phase 11 - Goals and Identity

#### Task 11.1 - Complete Goal and Identity Schema

##### Why
Identity is a core product pillar and drives coaching.

##### What to tell Antigravity
MODIFY `lib/models/goal_model.dart`, `lib/providers/goals_provider.dart`, `lib/views/tabs/goals_tab.dart`, and `lib/services/state_aggregator_service.dart`. Use `/users/{uid}/goals/{goalId}` for v1. Fields: title, identityStatement, why, category, linkedHabitIds, linkedTaskTags, milestones, progressScore, confidenceScore, status, createdAt, updatedAt. Emit `goal_created`, `goal_updated`, `goal_milestone_completed`, and `identity_progress_updated`.

##### Dependencies
Phases 4 and 7.

##### How to verify
Create a goal, link a habit, log the habit. Firebase console: goal progress updates and events appear.

##### Estimate
1 day

##### Done Criteria
- [ ] Goals are editable.
- [ ] Goals link to habits/tasks.
- [ ] Progress is derived from real behavior.

#### Task 11.2 - Build Goal Detail and Milestone UI

##### Why
The user must see why goals matter and what action advances them.

##### What to tell Antigravity
MODIFY `lib/views/tabs/goals_tab.dart` and create goal detail widgets if needed. Show identity statement, why, linked habits, linked tasks, milestones, progress, proof history, and next action. Use `/goals`, `/habit_logs`, `/tasks`, and `/events_recent`.

##### Dependencies
Task 11.1.

##### How to verify
UI: open a goal detail, complete linked habit/task, progress changes. Firebase console: progress is explainable.

##### Estimate
1 day

##### Done Criteria
- [ ] Every goal has a detail path.
- [ ] Progress is not manually faked.
- [ ] Empty states guide linking habits.

### Phase 12 - Notifications and Alarms

#### Task 12.1 - Complete Notification Preferences

##### Why
Notifications must be user-controlled.

##### What to tell Antigravity
MODIFY `lib/services/notification_service.dart`, `lib/views/tabs/profile_tab.dart`, onboarding notification page, and `/profile/main` writes. Store permission status, quiet hours, categories enabled, daily budget, alarm type, timezone, and updatedAt. Emit `notification_preferences_updated`.

##### Dependencies
Phase 3.

##### How to verify
UI: change notification settings and restart app. Firebase console: `/profile/main` updates. Notifications respect settings.

##### Estimate
4h

##### Done Criteria
- [ ] Settings are visible in Profile.
- [ ] Onboarding saves initial preferences.
- [ ] Quiet hours are enforced.

#### Task 12.2 - Persist, Re-register, and Track Notifications

##### Why
Scheduled reminders must survive app restarts.

##### What to tell Antigravity
MODIFY `lib/services/notification_service.dart`, `lib/main.dart`, and app lifecycle handlers. Store notifications at `/users/{uid}/scheduled_notifications/{notificationId}` with type, sourceId, scheduledFor, status, payload, createdAt, deliveredAt, openedAt, dismissedAt. On app start, re-register pending local notifications. Emit `notification_scheduled`, `notification_delivered`, `notification_opened`, `notification_dismissed`, and `notification_suppressed`.

##### Dependencies
Task 12.1.

##### How to verify
Schedule a task reminder, kill app, reopen. Notification remains scheduled. Firebase console: status changes after open/dismiss.

##### Estimate
1 day

##### Done Criteria
- [ ] Re-registration works.
- [ ] Tap opens correct screen.
- [ ] Suppression is logged.

#### Task 12.3 - Add FCM Device Registry and Server Push

##### Why
Cloud Functions need a supported way to notify users.

##### What to tell Antigravity
MODIFY `lib/services/notification_service.dart`, `functions/index.js`, and create or modify device-token helpers. Store tokens at `/users/{uid}/devices/{deviceId}` with fcmToken, platform, appVersion, timezone, lastSeenAt, notificationPermission. Cloud Functions should send pushes for eligible server events and update notification status.

##### Dependencies
Task 12.2.

##### How to verify
Firebase console: device token exists. Emulator or staging function sends a push. Logs show scheduled and delivered attempts.

##### Estimate
1 day

##### Done Criteria
- [ ] Tokens are stored and refreshed.
- [ ] Invalid tokens are cleaned.
- [ ] Server pushes respect preferences.

### Phase 13 - Coach Foundation

#### Task 13.1 - Make Coach Tab Use Canonical Messages

##### Why
Coach UI must show the same messages produced by rules and functions.

##### What to tell Antigravity
MODIFY `lib/views/tabs/coach_tab.dart`, `lib/services/coach_service.dart`, and `lib/core/providers.dart`. Use `/users/{uid}/coach_messages` as the canonical feed. Keep chat turns under `/users/{uid}/coach_chats/{threadId}/turns` if needed. User replies emit `coach_message_replied`; proactive messages emit `coach_message_sent`.

##### Dependencies
Phase 4.

##### How to verify
Create a proactive message from an event and send a chat reply. Firebase console: both canonical feed and chat thread are consistent.

##### Estimate
1 day

##### Done Criteria
- [ ] Coach feed is real.
- [ ] Messages paginate.
- [ ] No fake coach history appears.

#### Task 13.2 - Complete Rule Engine Coverage

##### Why
AI decisions must be rule-first and explainable.

##### What to tell Antigravity
MODIFY `lib/services/rule_engine_service.dart`, `lib/core/event_orchestrator.dart`, and create tests. Implement rules from AI Master Engine for slips, repeated misses, bad day, streaks, comeback, ghost day, day close, morning brief, screen time spikes, identity progress, and notification suppression. Add priority, cooldown, speak budget, coachEnabled gate, and reason codes.

##### Dependencies
Tasks 4.1, 9.2, 12.1.

##### How to verify
Seed event scenarios. Rule engine selects expected rule or suppresses with reason. Firebase console: `coach_speak_log` records decisions.

##### Estimate
1 day

##### Done Criteria
- [ ] Rules are deterministic.
- [ ] Suppression reasons are logged.
- [ ] Cooldowns and budgets work.

#### Task 13.3 - Build Context Snapshot and Output Validator

##### Why
LLM output must be safe, short, and grounded in real data.

##### What to tell Antigravity
MODIFY `lib/services/state_aggregator_service.dart`, `lib/services/gemini_service.dart`, `lib/services/coach_service.dart`, and Cloud Function `aiGenerate`. ContextSnapshot must include only derived data needed for the selected rule. Add output validator for length, repetition, unsafe advice, shame language, medical claims, and crisis terms. Store snapshots in `/users/{uid}/ai_context_snapshots/{snapshotId}` only when user-readable and deleteable.

##### Dependencies
Task 13.2.

##### How to verify
Run coach scenarios with sensitive inputs. Unsafe outputs are blocked or replaced with safe templates. Firebase console: snapshots contain no raw full database dumps.

##### Estimate
1 day

##### Done Criteria
- [ ] AI never receives raw DB history.
- [ ] Validator blocks unsafe output.
- [ ] User can inspect/delete memory later.

### Phase 14 - AI Backend, Safety, and Memory

#### Task 14.1 - Harden AI Cloud Function

##### Why
AI cost, latency, and safety cannot depend on the client.

##### What to tell Antigravity
MODIFY `functions/index.js`, `functions/package.json`, and AI helper modules. Keep Gemini API key server-side only. Add auth validation, App Check where supported, rate limits, per-user daily budget, timeout handling, fallback templates, model config, and structured response schema.

##### Dependencies
Phase 13.

##### How to verify
Call function unauthenticated and authenticated. Unauth fails. Over-budget calls are suppressed. Valid calls return structured output.

##### Estimate
1 day

##### Done Criteria
- [ ] API key is not in Flutter.
- [ ] Rate/cost controls exist.
- [ ] Fallback works.

#### Task 14.2 - Implement Crisis and Sensitive Safety SOP

##### Why
The AI Master Engine requires strict handling of crisis language.

##### What to tell Antigravity
MODIFY `lib/services/rule_engine_service.dart`, `lib/services/coach_service.dart`, `functions/index.js`, and create `/crisis_handoffs` support if needed. Detect crisis tiers, self-harm language, dangerous medical content, and eating-disorder risk. Show safe support copy and emergency guidance where appropriate. Emit `crisis_detected` and `crisis_handoff_created` without exposing sensitive details unnecessarily.

##### Dependencies
Task 13.3.

##### How to verify
Use emulator test phrases. UI shows safe response. Firebase console: crisis event exists with minimal safe payload.

##### Estimate
1 day

##### Done Criteria
- [ ] Crisis detection is tested.
- [ ] Unsafe coaching is blocked.
- [ ] Sensitive payloads are minimized.

#### Task 14.3 - Add AI Memory Controls

##### Why
Users must understand and control coach memory.

##### What to tell Antigravity
MODIFY `lib/services/state_aggregator_service.dart`, `lib/views/tabs/profile_tab.dart`, `lib/views/tabs/coach_tab.dart`, and scheduled functions. Store weekly user-readable memory at `/users/{uid}/ai_context_snapshots/{snapshotId}` with summary, sourceDateRange, createdAt, expiresAt, and userDeleted flag. Add Profile path to view/delete memory.

##### Dependencies
Task 13.3.

##### How to verify
Generate weekly memory. UI: user can view and delete. Firebase console: deleted memory is removed or marked deleted and not used.

##### Estimate
1 day

##### Done Criteria
- [ ] Memory is user-readable.
- [ ] User can delete memory.
- [ ] Deleted memory is not used.

### Phase 15 - Cloud Functions as Production Processors

#### Task 15.1 - Make Scheduled Day Close Authoritative

##### Why
Production summaries should not rely on the app being opened.

##### What to tell Antigravity
MODIFY `functions/jobs/dayClose.js`, `functions/index.js`, and shared event utilities. Process users by timezone after local day end. Read `/tasks`, `/habit_logs`, `/routine/current`, `/streaks`, `/goals`, `/screen_time_logs`, and `/addiction_logs`. Write `/dailySummaries/{date}` and related events idempotently.

##### Dependencies
Phase 9.

##### How to verify
Run function in emulator for a seeded user. Summary matches expected counts and does not duplicate on rerun.

##### Estimate
1 day

##### Done Criteria
- [ ] Function works without app open.
- [ ] Missed days catch up.
- [ ] Client fallback does not conflict.

#### Task 15.2 - Replace Static Scheduled Coach Jobs with Rule Pipeline

##### Why
Morning, midday, and inactivity messages must be context-aware.

##### What to tell Antigravity
MODIFY `functions/jobs/morningBrief.js`, `functions/jobs/middayPulse.js`, `functions/jobs/inactivityCheck.js`, and shared AI/rule helpers. Jobs should emit or process events, build ContextSnapshot, run rules, respect budget/quiet hours, and write `/coach_messages` only when allowed.

##### Dependencies
Phase 13.

##### How to verify
Run jobs with different user states. Firebase console: messages are relevant or suppressed with reason.

##### Estimate
1 day

##### Done Criteria
- [ ] No static generic production coach messages.
- [ ] Suppression is logged.
- [ ] Notifications are scheduled when eligible.

### Phase 16 - Analytics

#### Task 16.1 - Build Analytics Events and Daily Metrics

##### Why
Product metrics and user insights need stable event-derived data.

##### What to tell Antigravity
MODIFY event catalog, `functions/jobs/dayClose.js`, and summary models. Add metrics for activation, onboarding completion, daily active use, habit logs, task completion, routine completion, coach engagement, notification opens, retention, and churn risk. Store user-facing metrics in `/dailySummaries` and internal aggregates in analytics-safe destinations.

##### Dependencies
Phases 4 and 15.

##### How to verify
Run seeded flows. Metrics match raw events. User-facing summaries do not expose internal analytics-only fields.

##### Estimate
1 day

##### Done Criteria
- [ ] Metrics are derived from events.
- [ ] Analytics fields are documented.
- [ ] No PII leaks into broad analytics.

#### Task 16.2 - Add BigQuery Export and Dashboard Plan

##### Why
Production needs visibility into reliability and growth.

##### What to tell Antigravity
MODIFY Firebase project configuration and create documentation under `docs/analytics.md`. Enable or document Firestore/Analytics export to BigQuery. Define dashboards for activation, retention, habit logging, task completion, coach engagement, notification performance, function errors, and cost.

##### Dependencies
Task 16.1.

##### How to verify
In staging, events appear in BigQuery or the documented export path. Dashboard queries return expected counts.

##### Estimate
4h

##### Done Criteria
- [ ] Analytics export path is documented.
- [ ] Dashboard metrics are named.
- [ ] Privacy constraints are documented.

### Phase 17 - Profile, Settings, and Privacy

#### Task 17.1 - Complete Profile Real Data

##### Why
Profile should summarize the real user, not marketing placeholders.

##### What to tell Antigravity
MODIFY `lib/views/tabs/profile_tab.dart`, `lib/core/providers.dart`, and profile models. Show name, email, onboarding status, coach settings, accountability type, notification settings, About You summary, streak stats, goal stats, app version, export/delete, help, and sign out. Data must come from `/users/{uid}`, `/profile/main`, `/streaks`, `/goals`, and `/dailySummaries`.

##### Dependencies
Phases 2, 3, 9, 11, 12.

##### How to verify
UI: change settings and see Profile update. Firebase console: Profile values match Firestore.

##### Estimate
1 day

##### Done Criteria
- [ ] No fake profile stats.
- [ ] All settings are reachable.
- [ ] Sign out works safely.

#### Task 17.2 - Add About You and Coach Settings Editors

##### Why
Users must update onboarding-derived preferences later.

##### What to tell Antigravity
MODIFY `lib/views/tabs/profile_tab.dart` and create settings screens/widgets as needed. Allow editing biometrics, lifestyle, sensitive flags, coach style/name, accountability, notification budget, quiet hours, and timezone. Write to `/profile/main`. Emit `profile_preferences_updated`, `biometrics_updated`, and `coach_preferences_updated`.

##### Dependencies
Task 17.1.

##### How to verify
UI: edit each setting and restart app. Firebase console: `/profile/main` updates and events exist.

##### Estimate
1 day

##### Done Criteria
- [ ] User can change all important preferences.
- [ ] Sensitive fields are optional.
- [ ] Events are recorded.

#### Task 17.3 - Finalize Export and Delete

##### Why
Privacy/data ownership is a documented requirement.

##### What to tell Antigravity
MODIFY `lib/services/firestore_service.dart`, `lib/views/tabs/profile_tab.dart`, and supporting services. Export all final user-owned collections into structured JSON with metadata and generatedAt. Delete flow must require explicit confirmation, re-auth when needed, export suggestion, `account_deleted` event, Firestore deletion, and Firebase Auth deletion. Do not use destructive shortcuts.

##### Dependencies
Task 2.2 and final schema completion.

##### How to verify
UI: export downloads/shares valid JSON. Delete removes subtree only after confirmation. Logs show `account_deleted` before deletion or audit retention.

##### Estimate
1 day

##### Done Criteria
- [ ] Export is complete.
- [ ] Delete is complete.
- [ ] Same Gmail signup after deletion is verified.

### Phase 18 - Security, Privacy, and Compliance Hardening

#### Task 18.1 - Enforce Firestore Least Privilege

##### Why
Security rules must match the final schema.

##### What to tell Antigravity
MODIFY `firestore.rules` and emulator tests. Users can only access their own `/users/{uid}` subtree. Public config is read-only. Event append rules must prevent cross-user writes and disallow client mutation of protected server-only fields where practical.

##### Dependencies
Final schema phases.

##### How to verify
Rules tests cover allowed own writes, denied other-user reads, denied event tampering, and allowed profile updates.

##### Estimate
1 day

##### Done Criteria
- [ ] Rules tests pass.
- [ ] Server-only fields are protected where possible.
- [ ] No root user data collection is exposed.

#### Task 18.2 - Enforce AI Privacy Boundaries

##### Why
The AI docs prohibit raw database dumps to the LLM.

##### What to tell Antigravity
MODIFY `lib/services/state_aggregator_service.dart`, `lib/services/gemini_service.dart`, `functions/index.js`, and AI tests. Only pass derived ContextSnapshot fields. Strip PII, sensitive raw notes, raw event history, and full profile data. Add tests that fail if raw Firestore documents are passed to AI generation.

##### Dependencies
Phase 14.

##### How to verify
Inspect AI function payloads in emulator logs. No raw user subtree or sensitive notes are included.

##### Estimate
4h

##### Done Criteria
- [ ] AI context is minimal.
- [ ] Sensitive fields are filtered.
- [ ] Tests cover payload shape.

### Phase 19 - QA and End-to-End Tests

#### Task 19.1 - Add Unit Tests for Core Services

##### Why
Task, habit, event, streak, rule, and notification logic are high-risk.

##### What to tell Antigravity
CREATE tests under `test/services/` for `EventService`, `TaskService`, `HabitService`, `StreakService`, `RoutineService`, `NotificationService`, `RuleEngineService`, and `StateAggregatorService`. Use fake Firebase or emulator abstractions already compatible with the project.

##### Dependencies
Phases 4 through 14.

##### How to verify
Run `flutter test`. Tests cover happy path, invalid transitions, idempotency, and error states.

##### Estimate
1 day

##### Done Criteria
- [ ] Core service tests exist.
- [ ] Event idempotency is tested.
- [ ] Rule suppression is tested.

#### Task 19.2 - Add Widget Tests for Core Screens

##### Why
The user-visible flows must not regress.

##### What to tell Antigravity
CREATE tests under `test/views/` for signup, login, onboarding, home, routine, tracker, coach, goals, and profile. Mock providers or use emulator-backed providers. Verify loading, empty, error, and success states.

##### Dependencies
Phase 17.

##### How to verify
Run widget tests. Every core tab renders without fake production data.

##### Estimate
1 day

##### Done Criteria
- [ ] Core screens have widget tests.
- [ ] Empty states are tested.
- [ ] Navigation paths are tested.

#### Task 19.3 - Add Integration Test for First-Run to Day Close

##### Why
This is the critical product loop.

##### What to tell Antigravity
CREATE `integration_test/first_run_day_close_test.dart`. Test signup, onboarding completion, home load, routine task start/complete, habit log, tracker detail log, coach message generation or safe suppression, day close, profile export, and sign out. Use Firebase emulator.

##### Dependencies
All prior product phases.

##### How to verify
Run integration test against emulator. Firebase console/emulator data shows expected collections and events.

##### Estimate
1 day

##### Done Criteria
- [ ] First-run loop passes.
- [ ] Major user actions write expected collections.
- [ ] Day close writes summary.

### Phase 20 - Release Hardening

#### Task 20.1 - Production Configuration Checklist

##### Why
Release requires correct environment and observability.

##### What to tell Antigravity
MODIFY or CREATE docs under `docs/release_checklist.md`. Verify Firebase project ids, Android package, App Check production provider, Crashlytics, Performance, Remote Config defaults, notification channels, Firestore indexes, rules deployment, Functions secrets, and Play Console requirements.

##### Dependencies
All implementation phases.

##### How to verify
Run staging build. Confirm app connects to staging/prod intentionally and no emulator/demo config is shipped.

##### Estimate
4h

##### Done Criteria
- [ ] Release checklist exists.
- [ ] Secrets are server-side.
- [ ] Production build starts cleanly.

#### Task 20.2 - Production Smoke Test

##### Why
The app is only production-ready if the end-to-end loop works on a real device.

##### What to tell Antigravity
CREATE `docs/production_smoke_test.md`. Include exact manual steps: install app, sign up, complete onboarding, start task, complete task, log good habit, log bad slip, import screen time if Android, receive notification, read coach message, close day, export data, delete account, re-create account with same Gmail. Include Firebase console paths to verify at each step.

##### Dependencies
Task 20.1.

##### How to verify
Run the smoke test on a physical Android device and record pass/fail.

##### Estimate
4h

##### Done Criteria
- [ ] Smoke test doc exists.
- [ ] Every core collection is verified.
- [ ] Account deletion and same Gmail re-signup are verified.

## 8. Completeness Check

Before calling the app production-ready, verify every row below:

| Feature Area | UI Exists | Backend Exists | Firestore Exists | Verification Exists | User Can Access |
|---|---|---|---|---|---|
| Signup/Login | Yes | Partial | Yes | Needed | Yes |
| Onboarding | Partial | Partial | Partial | Needed | Yes |
| Home | Partial | Partial | Partial | Needed | Yes |
| Routine | Partial | Partial | Partial | Needed | Yes |
| Tasks | Partial | Partial | Yes | Needed | Yes |
| Habits | Partial | Partial | Yes | Needed | Yes |
| Trackers | Partial | Partial | Partial | Needed | Partial |
| Streaks | Partial | Partial | Yes | Needed | Partial |
| Goals | Partial | Partial | Partial | Needed | Yes |
| Events | No direct UI | Partial | Yes | Needed | Indirect |
| Coach | Partial | Partial | Partial | Needed | Yes |
| Notifications | Partial | Partial | Partial | Needed | Partial |
| Profile | Partial | Partial | Partial | Needed | Yes |
| Export/Delete | Partial | Partial | Partial | Needed | Yes |
| Analytics | No | Partial | Partial | Needed | No |
| Tests | No | No | No | Needed | No |

If any row remains Partial, Needed, or No, continue implementation and verification before release.

## 9. File Output

This content is saved as:

`todo_V1_(fixed)_All_Features.md`
