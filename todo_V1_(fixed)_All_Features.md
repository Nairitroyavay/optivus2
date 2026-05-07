# Optivus V1 (Fixed) — All Features Master TODO

> **Source of truth.** This file is the full, beginner-friendly implementation roadmap for Optivus.
> Every task is copy-paste ready for Gemini CLI / Antigravity, references `.gemini/GEMINI.md`,
> and starts in planning mode. The 7 OPTIVUS Docs are the product source of truth — User Flow first.
> Do **not** treat Optivus as a fresh project: extend existing code, preserve completed work,
> only refactor where a task explicitly says the contract is broken.

---

## 1. Short Summary (read this first)

1. Optivus already has a working Flutter shell, six tabs, onboarding pages 0–10, routine setup screens (fixed/skin/eating/class/supplement), Routine timeline with Add + AI buttons, Tracker with 10 variant scaffolds, habit/streak/comeback flows, EventService with idempotency, Firestore rules, and Cloud Functions stubs.
2. Pre-phase through Phase 5 of the previous TODO are marked **Done** (Apr 30 → May 03 commits). Most are real, but several leave un-checked Done Criteria, weak verification, or only scaffold-level UI.
3. The biggest correctness gap is **goal/identity glue**: GoalRepository emits `identity_*` events for goal docs (not identity profile) and the StateAggregator does not yet ingest goals into the AI context — special task §G1 below repairs this.
4. The biggest UX gap is the **routine setup AI/photo modes**: skin care text/photo AI, supplement text AI, class timetable photo, eating mess photo and AI-generated routine all need UI review-before-save plus a Cloud Function backend (`routineImport`) that does not exist yet.
5. The biggest backend gap is **Cloud Functions**: only 4 stub jobs exist (`morningBrief`, `middayPulse`, `dayClose`, `inactivityCheck`). Notification dispatcher, AI planner, AI rule engine, safety routing, routine import, export/delete, cleanup, backfill, and weekly summary are all missing.
6. Tracker variants for smoking, screen time, mindful eating, procrastination, hydration, meditation, money saving, reading, exercise, and routine completion exist as **41-line stubs** that all extend a base — they need real per-variant fields, log paths, AI insights, and verification.
7. Notifications: NotificationService exists but lifecycle (sent/tapped/dismissed/suppressed/missed), notification center UI, settings, custom alarm UX, and FCM dispatcher are all missing.
8. AI Coach: chat UI exists, but real Gemini calls must move to Cloud Functions, rule engine + speak budget + safety routing are not implemented end-to-end, and the AI is not yet event-driven from `ai_context_snapshots`.
9. Subscription, privacy export/delete, remote config kill switches, analytics summaries, weekly insights, and production QA tests are all not yet implemented.
10. Fixed schedule **already supports unlimited templates** at `/users/{uid}/routine/current.templates.fixed_schedule` and materialises daily — but the onboarding UI and Settings UI are **separate components**; this TODO requires shared widgets and explicit verification that data flows onboarding → Settings → Routine timeline.
11. Routine tab already has a clear **Add button** (`add_task_sheet.dart`) and an **AI button** (`ai_routine_panel.dart`) — but AI suggestions are local; backend AI generation, save-as-template option, and `suggestion_*` events round-trip need polish.
12. Skin/Eating/Class setup screens already render manual flows; **AI text mode and photo upload mode need to be wired** through `routineImport` Cloud Function with review-before-save.
13. Eating routine **AI-generated mode + mess menu photo upload** are not yet implemented.
14. Class routine **timetable image OCR upload** is not yet implemented.
15. Smoking, running, meditation, sleep, water, screen time, junk food, procrastination, money-saving, reading, exercise, and routine-completion **trackers must each have real per-variant detail screens, log flows, AI insights, and verification** — generic habit tracking is not enough.
16. The event spine is solid (validator + idempotency + transaction) but missing: `bad_day_detected`, `slip_log_dismissed`, `screen_time_synced` payload contracts, `weekly_insight_ready`, `account_deleted` final emission, and `comeback_path_chosen`.
17. Firestore rules already enforce per-user ownership and append-only events; new collections (`coach_messages`, `coach_speak_log`, `suggestions`, `ai_context_snapshots`, `weeklySummaries`, `usage`, `devices`) need rules carve-outs and indexes when introduced.
18. Cloud Functions must be the **only** place AI keys live. Flutter never holds Gemini keys. `routineImport`, `aiPlanner`, `notificationDispatcher`, `safetyRouter`, `exportUserData`, `deleteUserData`, `eventMaintenance`, `schemaBackfill`, `weeklySummary` are all required.
19. Production readiness: emulator tests, rules tests, function tests, integration smoke, migration checklist, seed data, kill switches, monitoring dashboards, crashlytics enrichment, and final completeness audit gate the launch.
20. **A feature is complete only when** UI, state/provider, Firestore path, backend (if needed), event, AI rule (if applicable), notification (if applicable), verification, and a user-visible entry point all exist and are exercised end-to-end.

---

## 2. Existing TODO File Audit

### 2.1 Strong Parts

- Section 6 phase-wise structure (Pre-Phase → Phase 11) is sensible and dependency-ordered.
- Pre-Phase 0 / Phase 0 inventory + matrix tasks are real and were genuinely executed (`docs/implementation_inventory.md`, `docs/feature_matrix.md`).
- Tasks 1.1–1.4 (auth, About You, fixed schedule unlimited, page 10 plan ready) are concrete with file lists, schemas, validation, and verification steps.
- Tasks 2.1 and 2.2 lock Firestore paths, event envelope, indexes, and rules — these are now the canonical contracts.
- Task 3.2 correctly captures idempotent materialisation and the deterministic task-id pattern.
- Task 5.1 streak rules, 5.3 comeback flow, and 4.x habit lifecycle are well-specified.

### 2.2 Weak Parts

- **Verification depth is uneven.** Many tasks list "UI" / "Firebase console" / "Events" as bullet headers without naming the exact assertions or click paths.
- **Done Criteria don't always match Status.** Tasks 1.1–5.3 are marked "Completed on YYYY-MM-DD" but the unchecked Done Criteria (e.g. Task 6.1 has all `[ ]`) live next to a Status of "Completed" / no status — needs alignment.
- **Tasks 6.x to 11.x lack Status fields.** They drift between "no status" and "Done Criteria empty" — these need explicit `Not started` markers.
- **Gemini CLI prompts are missing.** No task in the existing file has the `Use \`.gemini/GEMINI.md\` as the project rules.` planning-mode preamble. The user's spec demands this in every task.
- **No "Files allowed to modify" hard list.** Tasks list MODIFY paths but do not declare scope as a hard constraint, so the agent can drift outside.
- **No "Final response format" block.** Tasks do not require Antigravity to summarise files inspected, files changed, events emitted/skipped, analyzer result, remaining risks.

### 2.3 Duplicate / Redundant Tasks

- **0.1 inventory + 11.3 final completeness audit** overlap; 11.3 must reuse 0.1's matrix, not produce a parallel doc.
- **3.4 routine setup screens** and **8.4 AI routine import endpoints** both list the same setup screens — split needed: 3.4 owns the UI surface and the manual mode; 8.4 owns the backend + AI text/photo modes.
- **5.3 comeback** mentions suggestion creation, but 8.3 owns the SuggestionService; cross-reference instead of re-defining.
- **7.1 + 7.2 + 7.3** share notification settings logic; consolidate the Firestore field shape in one place.
- **Task 1.2 About You** duplicates fields with Task 6.1 identity profile — needs a clean boundary (Task 1.2 owns biometrics/lifestyle, 6.1 owns identity profile main doc).

### 2.4 Vague Tasks

- "Routine tab still reads tasks" (Task 3.1) — no exact assertion.
- "Coach exists, but it must become backend-controlled" (codebase analysis) — no migration steps.
- "Disabled states are graceful" (10.4) — no UX reference.
- "Empty/loading states for new users" (3.5) — no per-screen list.
- "Cloud Functions exist but need event-triggered jobs" — no per-event mapping.

### 2.5 Missing Verification

- Task 1.1: no rules-test for unauthenticated access denial.
- Task 1.4: no negative test for partial onboarding state.
- Task 3.2: verification mentions "no duplicates" but no exact deterministic-id assertion.
- Task 4.4: "Variant screens exist" — does not verify per-variant log writes hit the correct Firestore path.
- Task 5.3: no offline-replay verification for ghost detection.
- Task 6.1: no aggregator no-goal-user crash test.
- Task 6.3: no end-to-end "complete linked habit → identity score moves" assertion.
- Task 7.1: no notification re-registration after `flutter pub upgrade` or app upgrade test.
- Task 8.1: no rule-engine speak-budget exhaustion test.
- Task 8.4: no malformed-AI-JSON rejection test.
- Task 9.2: no soft-delete recovery window assertion.

### 2.6 Wrong Dependency Order

- Task 1.4 (page 10 plan) depends on Task 2.1 (event spine) for `task_scheduled` / `notification_scheduled` — original order ran 1.4 before 2.1. Repair: split 1.4 into "page 10 UI" and "first-day materialisation events" so the UI ships in Phase 1 and events lock in Phase 2.
- Task 4.4 tracker variants depend on Task 5.1 streak data, but 4.4 sits in Phase 4 while 5.1 sits in Phase 5 — repair by moving 4.4 to Phase 5 (after streaks) or scoping 4.4 to non-streak surfaces.
- Task 6.1 identity glue depends on Task 3.5 day-close + Task 4.1 habits + Task 5.1 streaks — fine, but its un-checked Done Criteria show it never closed, so Phase 6 needs to start by completing 6.1.
- Task 7.x notifications need Task 8.1 rule engine for AI nudges — currently 7.1 ships before 8.1 with no kill switch.

### 2.7 Tasks Too Large

- Task 3.4 ("complete routine setup screens AND new supplement setup") = 5 screens + new supplement screen + AI hooks. Split into 5 sub-tasks.
- Task 4.4 ("build tracker-specific variants") = 10 variant screens. Split into a base task + per-variant tasks.
- Task 8.4 ("AI routine import and generation endpoints") = 7 modes. Split per mode.
- Task 8.5 ("strategic AI scheduled jobs") = 5 jobs + rule engine + safety. Split per job.
- Task 11.1 ("full test suite") = unit + widget + integration + rules + function tests. Split per surface.

### 2.8 Executed Phase Gap Analysis (Pre-Phase → Phase 5)

#### Pre-Phase 0 — Scope Lock
- **Supposed:** Add unlimited fixed schedule, daily repeat, Add button, AI button, skin/supplement/class/eating modes to scope.
- **Actual:** Scope captured in old TODO; verified against codebase.
- **Gap:** None on scope; verification text does not name shared widget for onboarding/Settings fixed schedule (Problem 9). New tasks below add this explicitly.

#### Phase 0 — Audit Guardrails
- **Supposed:** Build inventory + matrix + test skeletons.
- **Actual:** `docs/implementation_inventory.md` and `docs/feature_matrix.md` exist; ~190 skipped Dart contract tests + 3 JS contract tests.
- **Gap:** Matrix likely missing rows for smoking/running/meditation/supplement/eating-AI/class-photo specifically (must be re-audited in 0.3 below). Function `npm test` not wired (documented but blocking 11.1).

#### Phase 1 — Auth, User Schema, Onboarding
- **Supposed:** auth lifecycle, About You sub-pages, unlimited fixed schedule, page 10 plan-ready.
- **Actual:** Auth screens, signup, onboarding pages 0–10, fixed schedule template list, page 10 exists.
- **Gap:**
  - About You sensitive-context page 5c needs verification that the eating-disorder flag actually gates calorie tracking app-wide (Tracker variant must read this flag).
  - Page 10 `suggestion_generated` for first deterministic plan suggestions: no proof these events emit; verify in Phase 2 cleanup.
  - Onboarding fixed schedule must use the exact same widget/component the Settings fixed schedule uses (Problem 9). Currently `onboarding_page_9.dart` and `fixed_schedule_setup_screen.dart` are separate files.
  - Onboarding writes to `/users/{uid}/routine/current.templates.fixed_schedule` and Settings writes to the same path — verify via emulator that one entry, not two, is created when user does both.

#### Phase 2 — Event Spine + Firestore Contracts
- **Supposed:** Production-grade EventService + schema/rules/indexes alignment.
- **Actual:** EventService has validator, deterministic IDs, transaction-based idempotency, replay; rules enforce ownership + append-only events.
- **Gap:**
  - `event_payload_validator.dart` covers core events but `screen_time_synced`, `routine_template_*`, `slip_log_dismissed`, `bad_day_detected`, `weekly_insight_ready`, `comeback_path_chosen`, `account_deleted` payloads need explicit schema entries.
  - `firestore.indexes.json` covers basics; no compound index yet for `suggestions(status, createdAt DESC)`, `coach_messages(threadId, ts)`, `scheduled_notifications(state, fireAt)`, `events_recent(eventName, timestamp DESC)`.
  - Schema mapping doc `docs/firestore_schema_v1_mapping.md` exists but does not document `coach_speak_log`, `ai_context_snapshots`, `weeklySummaries`, `usage`, `devices`, `data_exports`, `deletion_requests` shapes.

#### Phase 3 — Task, Routine, Day Lifecycle
- **Supposed:** TaskService contract, routine materialisation, Add+AI buttons, setup screens, day start/close.
- **Actual:** Task state machine in `task_service.dart`; `RoutineNotifier.materializeForDate` is idempotent and deterministic; `add_task_sheet.dart` + `ai_routine_panel.dart` exist; setup screens for fixed/skin/eating/class/supplement exist; `routine_service.dart` runs day close with summaries.
- **Gap:**
  - Setup screens render but **AI text mode + photo upload mode** for skin/eating/class are stubbed UIs only — `routineImport` callable is wired in `RoutineRepository.previewRoutineImport` but the Cloud Function does not exist.
  - Eating "Generate with AI" mode (text goal → routine) not implemented.
  - Class "timetable image upload" not implemented (no image picker, no OCR call).
  - Supplement "text AI" mode not implemented.
  - Routine settings sheet does not surface every setup screen consistently (must be checked).
  - Day close emits `routine_day_summarized` but mission-ring formula in `home_tab.dart` may not weight identity-aligned tasks per Event System §10.1; verify.

#### Phase 4 — Habit & Tracker
- **Supposed:** HabitService lifecycle, quick-log, habit editor/detail, 10 tracker variants.
- **Actual:** Habit lifecycle service, log_habit_sheet, habit_editor_screen, habit_detail_screen, 10 variant files all extending `tracker_variant_base.dart`.
- **Gap:**
  - The 10 variant files are **40-line stubs** — each needs the per-variant fields, log paths, AI insight cards, and safety branching (eating-disorder flag for junk-food → mindful-eating swap; phone-usage import for screen time; auto-detect for procrastination).
  - Smoking variant needs trigger picker, money-saved math, days-clean, and health milestones — none implemented.
  - Screen time needs Android `UsageStatsManager` bridge — `screen_time_bridge.dart` exists but is unverified end-to-end.
  - No money-saving aggregation reading from smoking/junk-food/alcohol slips.
  - Tracker home does not yet show the AI insight card surface from User Flow §8.1.

#### Phase 5 — Streaks, Accountability, Retention
- **Supposed:** Production streak rules, detail/heatmap UI, ghost-day + comeback.
- **Actual:** `streak_service.dart` (24KB), `streak_detail_screen.dart`, `streak_heatmap.dart`, `comeback_modal.dart`, `inactivityCheck.js`.
- **Gap:**
  - Forgiving accountability "1 free skip per 7-day window" and weekly-skip ledger (`weeklySkipsUsed`) needs explicit verification on streak_model.dart.
  - Per-habit accountability override (Profile → Accountability → "Override per-habit") not yet wired.
  - Ghost-day detection is in `inactivityCheck.js` but it must also pause streaks server-side and emit `streak_paused` per habit; verify.
  - Comeback modal exists but `comeback_path_chosen` event is not in `event_names.dart` — must be added.
  - 8-day-or-longer absence path (reset, not resume) not yet tested.

### 2.9 Things That Should NOT Be Touched

- `firestore.rules` envelope/append-only structure (Phase 2.2 contract).
- `event_names.dart` constants that are already used by services (don't rename — only add new names).
- `EventService` deterministic-ID + transaction logic.
- Working onboarding pages 0–9 except where this TODO explicitly extracts a shared fixed-schedule widget.
- `RoutineNotifier.materializeForDate` deterministic id pattern.
- `routine/current.templates.fixed_schedule` Firestore path.
- The 6-tab navigation shell.
- The Riverpod provider tree in `lib/core/providers.dart`.

---

## 3. Codebase Analysis

### 3.1 Already Implemented (do not redesign)

- **App shell / nav:** `lib/main.dart`, `lib/core/router/app_router.dart`, `lib/core/providers.dart`, `lib/core/providers/bootstrap_provider.dart`, `lib/views/screens/home_screen.dart`, six tabs in `lib/views/tabs/*.dart`.
- **Auth:** `lib/services/auth_service.dart`, `lib/repositories/auth_repository.dart`, signup/login/welcome screens, `user_model.dart` rich profile.
- **Onboarding:** Pages 0–10 in `lib/views/onboarding/*.dart`, `onboarding_provider.dart`, `user_repository.dart`.
- **Routine:** `routine_provider.dart` (50KB — RoutineState, FixedScheduleTemplate, materializer), `routine_repository.dart`, all 5 setup screens, timeline, Add+AI panels.
- **Tasks:** `task_model.dart`, `task_service.dart` with state machine; outcomes path used.
- **Habits:** `habit_model.dart`, `habit_log_model.dart`, `habit_service.dart`, editor + detail screens, 10 variant stubs.
- **Streaks:** `streak_model.dart`, `streak_service.dart`, detail screen, heatmap.
- **Routine lifecycle:** `routine_service.dart`, `day_summary_model.dart`.
- **Events:** `event_model.dart`, `event_service.dart`, `event_payload_validator.dart`, `event_names.dart`.
- **Notifications:** `notification_service.dart` (20KB), `scheduled_notification_model.dart`.
- **AI scaffolding:** `gemini_service.dart`, `coach_service.dart`, `rule_engine_service.dart`, `state_aggregator_service.dart`, `context_snapshot.dart`, `coach_rule.dart`.
- **Goals/Identity:** `goal_model.dart`, `identity_profile_model.dart`, `goal_repository.dart`, `goal_provider.dart`, `identity_provider.dart`.
- **Comeback:** `comeback_modal.dart`.
- **Cloud Functions:** `functions/index.js`, `functions/jobs/{morningBrief,middayPulse,dayClose,inactivityCheck,utils}.js`.
- **Rules + Indexes:** `firestore.rules`, `firestore.indexes.json`.
- **Remote config:** `remote_config_service.dart`.
- **Screen time:** `screen_time_bridge.dart`, `screen_time_importer.dart`, `screen_time_log_model.dart`.

### 3.2 Partially Implemented (extend, don't rewrite)

- **GoalRepository:** Saves goals + emits `identity_*` events. Bug: `identity_progress_changed` is emitted from goal updates instead of identity profile recomputation; aggregator does not recompute identity profile from goals. Special task §G1 fixes this without breaking existing data.
- **StateAggregator:** Builds context snapshot but only `buildSnapshot` and `updateIdentityProfile` exist; needs goal/habit/task ingestion + safety flags + speak-budget input.
- **Routine setup screens:** Manual modes work; AI text/photo modes call `previewRoutineImport` but the backend isn't deployed.
- **Tracker variants:** 10 files extend a shared base; per-variant fields and writes missing.
- **NotificationService:** Local scheduling exists; lifecycle records (`recordSent/Tapped/Dismissed/Suppressed/Missed`) and re-registration on app start need contract tests.
- **Cloud Functions:** Stubs only; no AI calls, no notification dispatcher, no export/delete.
- **Coach tab:** Chat UI renders but is not yet event-driven from `coach_messages` and the Gemini call still happens client-side.
- **Page 10:** `onboarding_page_10.dart` exists but its emission of `task_scheduled` / `notification_scheduled` for the first plan should be re-verified.

### 3.3 Not Implemented

- Routine import Cloud Function (`functions/ai/routineImport.js`).
- AI planner Cloud Function (`functions/jobs/aiPlanner.js`).
- Rule engine Cloud Function (`functions/jobs/ruleEngine.js`).
- Safety routing (`functions/jobs/safety.js`).
- Server notification dispatcher (`functions/jobs/notificationDispatcher.js`).
- Weekly summary job (`functions/jobs/weeklySummary.js`).
- Export user data job + lifecycle UI.
- Delete user data job + recovery window.
- Event maintenance / archival job.
- Schema backfill job.
- Subscription / usage limits.
- Notification center screen.
- Notification settings screen.
- Custom alarm editor + ringing screen + snooze-reason sheet.
- Goal editor / detail / milestone editor screens.
- Identity hero on Profile / Home.
- Smoking trigger picker + money-saved card + health milestones.
- Reading book shelf + Google Books lookup.
- Meditation timer overlay.
- Money-saving aggregator + sources breakdown.
- Mindful-eating swap UI.
- Procrastination auto-detect listener.
- Phone behavior unlock-without-action heuristic.
- Profile settings screens (coach / accountability / about-you / privacy / subscription).
- AI suggestion accept/dismiss → template OR selected-day task path.
- AI rule engine speak budget enforcement end-to-end.
- AI safety routing for self-harm / medical / legal / financial.
- Crisis handoff flow.
- Daily summary / weekly summary surfaces in Home + Profile.
- App Check + Crashlytics rich logging.

### 3.4 Broken / Risky

- `goal_repository.dart` emits `identity_*` events for goal docs — semantically wrong; AI rules listening for identity events will mis-fire. Repair is non-destructive (rename or split events; preserve back-compat for analytics).
- `state_aggregator_service.dart` `buildSnapshot` does not gracefully no-op on users with no goals/no habits — verify (the SPECIAL REQUIRED TASK §G1 makes this safe).
- ~~AI key risk: `gemini_service.dart` may be reading a key from Flutter~~ **Verified safe 2026-05-03**: `gemini_service.dart` only calls `httpsCallable('aiGenerate')`; `functions/index.js` holds `geminiApiKey` via `secrets: [...]`. No client-side key. (Task 11.1 reclassified to Done.)
- `screen_time_bridge.dart` Android-only (`UsageStatsManager`). No iOS target — no guard needed.

### 3.5 Needs Refactor (touch only via the listed task)

- `event_payload_validator.dart`: extend with new events listed in §6 Phase 2.
- `notification_service.dart`: split into scheduling + lifecycle + dispatcher-bridge.
- `coach_service.dart`: route Gemini calls through Cloud Functions.
- `rule_engine_service.dart`: connect to context snapshot + speak budget + Firestore-backed coach_speak_log.
- `state_aggregator_service.dart`: ingest goals, habits, slips, recent events; expose safe defaults.
- Routine setup screens: extract shared review-before-save widget.

### 3.6 Do Not Touch

- Flutter framework / Firebase / Cloud Functions choice.
- Existing onboarding pages 0–9 layout (only extract widgets where Problem 9 demands).
- The 6-tab nav.
- `event_names.dart` existing constants.
- `firestore.rules` event-immutability contract.
- `routine/current.templates.fixed_schedule` Firestore path.
- Streak detail / heatmap visual design.
- Comeback modal copy.

---

## 4. Document Coverage Analysis (per-feature)

Format: **Feature** → Doc source · Expected behaviour · UI · State · Firestore · Backend · Events · AI · Notif · Codebase status · TODO coverage

> Status legend: ✓ implemented · ◐ partial · ✗ missing · 🔒 do-not-touch

| # | Feature | Source | UI | State | Firestore | Backend | Events | AI | Notif | Status | TODO §/Task |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Sign-up + sign-out | PRD §4.8 / UF §1 | ✓ | ✓ | `/users/{uid}` | Firebase Auth | `user_signed_up`, `account_deleted` | – | – | ✓ | P1.T1.1 (existing) |
| 2 | Onboarding 0–4 (focus / habits / goals) | UF §1 | ✓ | ✓ | `/onboarding/state` | – | – | – | – | ✓ | P1.T1.x |
| 3 | About You (5a/5b/5c) | PRD §4.9 / UF §1 step 8 | ✓ | ✓ | `/profile/main`, `/onboarding/state.aboutYou` | – | `biometrics_updated` (post-onb) | filter at runtime (eating-disorder gate) | – | ◐ | P4.T4.1, P14.T14.4 |
| 4 | Coach style + name | UF §1 step 9–10 | ✓ | ✓ | `/profile/main.coach*` | – | `coach_settings_changed` | – | – | ✓ | P14.T14.1 |
| 5 | Accountability | UF §1 step 11 | ✓ | ✓ | `/profile/main.accountability` | – | `accountability_changed` | – | – | ✓ | P14.T14.2 |
| 6 | Fixed schedule onboarding (unlimited) | Problem 1+2 / UF §1 step 12 | ✓ | ✓ | `/routine/current.templates.fixed_schedule` | – | template events | – | scheduled per task | ✓ | P4.T4.2 (wraps Problem 9) |
| 7 | Settings → Fixed schedule | Problem 9 / UF §3.4 | ✓ | ✓ | same as above | – | template events | – | – | ◐ | P4.T4.3 (shared widget) |
| 8 | Daily fixed-schedule repeat | Problem 2 / UF §3 | ✓ via materializer | ✓ | `/tasks/{taskId}` | – | `task_scheduled` | – | reminders | ✓ | P5.T5.1 (idempotency proof) |
| 9 | Routine tab Add button | Problem 3 / UF §3 | ✓ | ✓ | `/tasks` or `/routine/current.templates.custom` | – | task + template events | – | reminders | ✓ | P5.T5.2 (review) |
| 10 | Routine tab AI button | Problem 4 / UF §5.3 | ✓ skeleton | ◐ | `/suggestions/{id}` | callable `routineSuggest` | `suggestion_*` | yes | – | ◐ | P11.T11.3 |
| 11 | Skin care manual | Problem 5 / UF §3.1 | ✓ | ✓ | `/routine/current.templates.skin_care` | – | template events | – | – | ✓ | P6.T6.1 |
| 12 | Skin care text AI | Problem 5 | ✗ wired | – | same | callable `routineImport` mode `skin_care_text` | `suggestion_generated/accepted` | yes | – | ◐ | P12.T12.2 |
| 13 | Skin care photo AI | Problem 5 | ✗ wired | – | same | callable `routineImport` mode `skin_care_photo` + Storage | `suggestion_*` | yes | – | ◐ | P12.T12.3 |
| 14 | Supplement manual | Problem 6 / PRD §4.1 | ✓ | ✓ | `/routine/current.templates.supplements` | – | template events | – | – | ✓ | P6.T6.2 |
| 15 | Supplement text AI | Problem 6 | ✗ | – | same | callable `routineImport` mode `supplement_text` | `suggestion_*` | yes | – | ✗ | P12.T12.4 |
| 16 | Class manual | Problem 7 / UF §3.3 | ✓ | ✓ | `/routine/current.templates.classes` | – | template events | – | – | ✓ | P6.T6.3 |
| 17 | Class timetable photo | Problem 7 | ✗ | – | same | callable `routineImport` mode `class_timetable_photo` + Storage | `suggestion_*` | yes (OCR) | – | ✗ | P12.T12.5 |
| 18 | Eating manual | Problem 8 / UF §3.2 | ✓ | ✓ | `/routine/current.templates.eating` | – | template events | – | – | ✓ | P6.T6.4 |
| 19 | Eating mess menu photo | Problem 8 | ✗ | – | same | callable `routineImport` mode `eating_mess_photo` | `suggestion_*` | yes | – | ✗ | P12.T12.6 |
| 20 | Eating AI-generated routine | Problem 8 | ✗ | – | same | callable `routineImport` mode `eating_goal_text` | `suggestion_*` | yes | – | ✗ | P12.T12.7 |
| 21 | Task lifecycle (start/pause/resume/complete/skip/abandon) | UF §6 / EventSys §5 | ✓ | ✓ | `/tasks` + `/task_outcomes` | – | task events | learning loop | active alerts | ✓ | P5.T5.4 |
| 22 | Subtasks | EventSys §5.4 | ✓ | ✓ | task subtasks | – | `subtask_checked/unchecked` | – | – | ✓ | P5.T5.4 |
| 23 | Habit good log | UF §4.1 | ✓ | ✓ | `/habit_logs/{logId}` | – | `good_habit_logged` | – | – | ✓ | P7.T7.1 |
| 24 | Habit slip log | UF §4.2 | ✓ | ✓ | `/habit_logs/{logId}` | – | `bad_habit_slip_logged`, `slip_streak_detected` | yes | P4 | ✓ | P7.T7.1 |
| 25 | Habit pause/resume/archive | UF §8.6 | ✓ | ✓ | `/habits` | – | habit events | – | – | ✓ | P7.T7.2 |
| 26 | Smoking tracker | UF §8.4.1 / Problem 10 | ◐ stub | ✗ fields | `/habits/{cigarettes}` + logs | – | slip events | recovery alarm rule | P3 | ◐ | P7.T7.4 |
| 27 | Screen time tracker | UF §8.4.2 | ◐ stub + bridge | ◐ | `/habits/{screen_time}/logs` + `/screenTimeRaw` | importer | `screen_time_synced`, slip events | unlock-without-action | – | ◐ | P7.T7.5 |
| 28 | Junk food / Mindful eating | UF §8.4.3 | ◐ stub | ✗ | `/habits/{junk_food}` | – | slip events | safety swap on eating-disorder | – | ◐ | P7.T7.6 |
| 29 | Procrastination | UF §8.4.4 | ◐ stub | ✗ | `/habits/{procrastination}/logs` | listener | `bad_habit_slip_logged` (auto), `slip_log_dismissed` | auto-detect | – | ◐ | P7.T7.7 |
| 30 | Hydration | UF §8.4.5 | ◐ stub | ✗ | `/habit_logs` | – | `good_habit_logged` | smart reminder | reminders | ◐ | P7.T7.8 |
| 31 | Meditation | UF §8.4.6 / Problem 10 | ◐ stub | ✗ | `/habit_logs` | – | `good_habit_logged` | mood lift | – | ◐ | P7.T7.9 |
| 32 | Money saving | UF §8.4.7 | ◐ stub | ✗ | `/money_saved` aggregate | – | derived only | relapse pause | – | ◐ | P7.T7.10 |
| 33 | Reading | UF §8.4.8 | ◐ stub | ✗ | `/books`, `/habit_logs` | Google Books call | `good_habit_logged` | yes | – | ◐ | P7.T7.11 |
| 34 | Exercise / running | UF §8.4.9 / Problem 10 | ◐ stub | ✗ | `/habit_logs` (workout type) | health-kit opt-in | `good_habit_logged`, `running_completed/missed` (alias of `good_habit_logged`) | yes | reminders | ◐ | P7.T7.12 |
| 35 | Routine completion meta-tracker | UF §8.4.10 | ◐ stub | ✗ | `/dailySummaries`, `/weeklySummaries` | day-close + weekly job | `routine_day_summarized`, `weekly_insight_ready` | yes | – | ◐ | P7.T7.13 |
| 36 | Goals home / identity grid | UF §9 | ✗ | ✗ | `/goals`, `/identity_profile/main` | – | identity events | – | – | ✗ | P9.T9.2 |
| 37 | Identity detail / Why-this-score | UF §9.2/9.3 | ✗ | ✗ | same | – | identity events | yes (transparency layer) | – | ✗ | P9.T9.3 |
| 38 | Add identity | UF §9.4 | ✗ | ✗ | same | – | `identity_created` | – | – | ✗ | P9.T9.2 |
| 39 | Milestone marking | UF §9.6 | ◐ model only | ✗ UI | same | – | `milestone_completed` | – | P6 | ◐ | P9.T9.4 |
| 40 | Pause / archive identity | UF §9.5 | ✗ | ✗ | same | – | `identity_paused/archived` | – | – | ✗ | P9.T9.5 |
| 41 | Identity statement editor | UF §10.2 | ✗ | ✗ | `/profile/main.identityStatement` | – | `identity_statement_updated` | – | – | ✗ | P14.T14.1 |
| 42 | Coach chat | UF §5 / PRD §6 | ✓ shell | ◐ | `/coach_messages` | callable `coachReply` | `coach_message_sent/replied` | yes | – | ◐ | P11.T11.1 |
| 43 | Coach topic modes | UF §5.4 | ◐ | ◐ | same | same | – | system-prompt swap | – | ◐ | P11.T11.2 |
| 44 | Routine AI suggestions | UF §5.3 / Problem 4 | ✓ panel | ◐ | `/suggestions` | `routineSuggest` | `suggestion_*` | yes | – | ◐ | P11.T11.3 |
| 45 | AI rule engine + speak budget | EventSys §12 / AIM doc | ◐ scaffold | ◐ | `/coach_speak_log`, `/ai_context_snapshots` | `ruleEngine` | suppression events | yes | yes | ✗ | P11.T11.4 |
| 46 | AI safety routing | UF §5.5 / PRD §6 | ✗ | ✗ | `/crisis_handoffs` | `safety` | – | yes | – | ✗ | P11.T11.5 |
| 47 | AI scheduled jobs (morning/midday/dayclose/inactivity) | EventSys §13 | ◐ stubs | – | `/ai_context_snapshots`, `/suggestions` | jobs | `suggestion_generated`, `day_started/closed`, `ghost_day_detected` | yes | yes | ◐ | P11.T11.6 |
| 48 | Day start / day close | UF §6/7 | ◐ | ✓ | `/dailySummaries/{date}` | dayClose.js | `day_started/closed`, `routine_day_summarized` | yes | EoD push | ◐ | P5.T5.5 |
| 49 | Mission ring | EventSys §10 | ◐ | ◐ | derived | – | – | – | – | ◐ | P5.T5.6 |
| 50 | Streaks | EventSys §8 | ✓ | ✓ | `/streaks` | – | `streak_*` | – | P6 milestones | ✓ | P8.T8.1 |
| 51 | Streak detail + heatmap | UF §4.3 | ✓ | ✓ | `/streaks` | – | – | – | – | ✓ | (no rework) |
| 52 | Ghost day detection + comeback | UF §14 | ◐ | ◐ | `/streaks`, `/suggestions` | inactivityCheck.js | `ghost_day_detected`, `comeback_initiated`, `comeback_path_chosen` | force-supportive | retention pushes | ◐ | P8.T8.2 |
| 53 | Notification 6-tier scheduler | UF §11 / EventSys §13 | ◐ | ◐ | `/scheduled_notifications`, `/notificationLog` | dispatcher | full lifecycle | yes | yes | ◐ | P10.T10.1 |
| 54 | Notification center | UF §10.5 | ✗ | ✗ | `/notificationLog` | – | `notification_tapped/dismissed` | – | – | ✗ | P10.T10.2 |
| 55 | Notification settings | UF §10.5 | ✗ | ✗ | `/profile/main.notificationSettings` | – | `notification_settings_changed` | – | – | ✗ | P10.T10.3 |
| 56 | Custom alarm editor + ringing | UF §6 / PRD §4.5 | ✗ | ✗ | `/scheduled_notifications` (P1) | AlarmManager | – | yes (voice) | P1 | ✗ | P10.T10.4 |
| 57 | Money saved (passive + active) | EventSys §14 | ◐ | ✗ | derived | dayClose.js | – | relapse pause | – | ◐ | P7.T7.10 |
| 58 | Daily / weekly summaries | UF §7.2 / PRD §4.6 | ✗ | ✗ | `/dailySummaries`, `/weeklySummaries` | dayClose + weekly job | `routine_day_summarized`, `weekly_insight_ready` | EoD coach copy | EoD push | ◐ | P15.T15.1 |
| 59 | Strengths / Areas to improve | UF §10 | ✗ | ✗ | `/profile/main.strengths/areas` (cached) | weekly job | – | yes | – | ✗ | P15.T15.2 |
| 60 | Privacy / export / delete | UF §10.7 | ✗ | ✗ | `/data_exports`, `/deletion_requests` | export/delete jobs | `account_deleted` | – | – | ✗ | P14.T14.5 |
| 61 | Subscription + AI usage caps | UF §10.8 / PRD §10 | ✗ | ✗ | `/profile/main.subscription`, `/usage/{monthKey}` | usage gate in callables | – | – | – | ✗ | P14.T14.6 |
| 62 | Remote-config kill switches | sysdesign §2 | ◐ | ◐ | Remote Config | – | – | – | – | ◐ | P16.T16.1 |
| 63 | Crash + perf monitoring | sysdesign §2 | ◐ | ◐ | Crashlytics | – | – | – | – | ◐ | P16.T16.2 |
| 64 | Firestore rules + indexes audit | sysdesign §4 | ✓ | – | rules + indexes | – | – | – | – | ✓ | P17.T17.1 |
| 65 | App Check | sysdesign §2 | ✗ | – | – | – | – | – | – | ✗ | P17.T17.2 |
| 66 | Migration / seed data | TODO 11.2 | ✗ | – | – | – | – | – | – | ✗ | P18.T18.2 |
| 67 | Production QA suite | TODO 11.1 | ◐ skips | – | tests/* | functions/test/* | – | – | – | ◐ | P18.T18.1 |

(Any row not marked ✓ shows up as a task in §6.)

---

## 5. User Flow Breakdown

> For every step: **user action · UI screen · provider/state · Firestore read/write · repository/service · backend · event · AI · notification · verification.**

### 5.1 Onboarding Flow

| Step | User action | UI | Provider | Firestore | Service / Backend | Event | AI | Notif | Verification |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Open app | `WelcomeScreen` | `bootstrapProvider` | read auth | – | – | – | – | manual: cold start lands welcome |
| 2 | Sign up | `SignupScreen` | `authRepository` | `users/{uid}` | AuthService | `user_signed_up` | – | – | events_recent has 1 |
| 3 | Pick focus areas | `onboarding_page_1` | `onboardingProvider` | `onboarding/state.focusAreas` | UserRepo | – | – | – | restart preserves |
| 4 | Bad habits | page 2 | same | `onboarding/state.badHabits` | – | – | – | – | – |
| 5 | Good habits | page 3 | same | `onboarding/state.goodHabits` | – | – | – | – | – |
| 6 | Identity goals | page 4 | same | `onboarding/state.goals` | – | – | – | – | – |
| 7 | About You | page 5 | same + `userRepository` | `profile/main.{biometrics,lifestyle,sensitiveContext}` | – | – | computes BMI/water | – | sensitive-context skip works |
| 8 | Coach style/name | pages 6/7 | same | `profile/main.coach*` | – | – | – | – | – |
| 9 | Accountability | page 8 | same | `profile/main.accountabilityMode` | – | – | – | – | – |
| 10 | **Fixed schedule (unlimited)** | page 9 / shared `FixedScheduleEditor` | `routineProvider` | `routine/current.templates.fixed_schedule` | RoutineRepo `saveFixedScheduleTemplates` | template events | – | – | add 6+ rows; persists |
| 11 | Plan ready | page 10 | both providers | tasks/notifs/snapshots | RoutineNotifier `materializeForWindow` | `onboarding_completed`, `task_scheduled`, `notification_scheduled`, `suggestion_generated` | first deterministic plan | armed | docs created; events present |
| 12 | Enter app | `home` | bootstrap | `users.hasCompletedOnboarding=true` | – | `day_started` | – | – | lands Home |

### 5.2 First Day Experience

| Step | Action | UI | Service | Firestore | Event | Verify |
|---|---|---|---|---|---|---|
| 1 | Open Home | `HomeTab` | StateAggregator | `ai_context_snapshots/{id}` | `day_started` | snapshot has goals+habits |
| 2 | Open Routine | `RoutineTab` | RoutineNotifier | `tasks` | `task_scheduled` (new only) | no dup tasks |
| 3 | Start task | timeline row | TaskService | `tasks` | `task_started` | one active task |
| 4 | Subtask check | timeline | TaskService | `tasks.subtasks` | `subtask_checked` | parent recomputes |
| 5 | Complete task | timeline | TaskService | `tasks` + `task_outcomes` | `task_completed`, maybe `routine_block_completed` | mission ring updates |
| 6 | Log habit | Home pill | HabitService | `habit_logs` | `good_habit_logged` | daily total updates |
| 7 | AI suggestions | AI panel | SuggestionService | `suggestions` | `suggestion_generated` | shimmer → cards |
| 8 | Accept suggestion | AI panel | SuggestionService → RoutineRepo | `routine/current` or `tasks` | `suggestion_accepted`, `task_scheduled` | item materialises |
| 9 | Notification tap | OS | NotificationService | `notificationLog` | `notification_tapped` | deep-link works |

### 5.3 Daily Usage Loop

| Loop | Action | UI | Service | Firestore | Event |
|---|---|---|---|---|---|
| Morning | Open app | Home | DailyPlanner (AI Cloud Function) | `tasks/*`, `dailySummaries` | `day_started` |
| During day | Execute tasks | Routine | TaskService | `tasks` | task events |
| Habit moment | Log good/slip | Home/Tracker | HabitService | `habit_logs` | habit events |
| AI moment | Accept/dismiss | Routine/Coach/Home | SuggestionService | `suggestions` | suggestion events |
| Notification | Tap/dismiss | OS | NotificationService | `notificationLog` | notification events |
| Evening | Review | Home/Coach | RoutineService.dayClose | `dailySummaries/{date}` | `day_closed`, `routine_day_summarized` |
| Long term | Identity push | Goals/Profile | StateAggregator.updateIdentityProfile | `identity_profile/main`, `goals` | `identity_progress_changed` |

### 5.4 Routine Tab Flow (Add + AI buttons)

- **Add button →** `add_task_sheet` opens with date/time/title/type/repeat → save → `tasks` (one-off) **or** `routine/current.templates.custom` (repeating). Events: `task_scheduled` + `notification_scheduled` if reminder enabled.
- **AI button →** `ai_routine_panel` opens; calls `routineSuggest` callable; renders cards; accept emits `suggestion_accepted` + creates task or template.
- **Day selector →** changes `RoutineNotifier.selectedDate`; materialiser fills missing tasks for that day.
- **Setup empty states →** "Set up Skin Care" / "Set up Eating" / "Set up Class" / "Set up Supplements" buttons route to dedicated setup screens.

### 5.5 Fixed Schedule Flow (onboarding ↔ Settings ↔ Routine)

1. Onboarding page 9 hosts the **shared** `FixedScheduleEditor` widget; saves to `routine/current.templates.fixed_schedule`.
2. Settings → Fixed Schedule opens the same widget reading the same path.
3. Save in either place invokes `RoutineRepository.saveFixedScheduleTemplates` (idempotent merge).
4. After save, `RoutineNotifier.materializeFutureFromTomorrow` runs; today's already-completed tasks are not overwritten.
5. **Verification:** `firestore.indexOf('templates.fixed_schedule')` document is single; emulator test asserts onboarding edit and Settings edit converge to one doc.

### 5.6 AI Routine Suggestion Flow

1. User taps AI button in Routine tab → loading shimmer.
2. Flutter calls `routineSuggest(userId, selectedDate, context)` → Cloud Function builds context snapshot → calls Gemini → returns suggestion JSON validated against schema.
3. Suggestions written to `/users/{uid}/suggestions` with `status='pending'`, expires in 24h.
4. UI lists cards: Accept → create task or template; Edit → opens editor pre-filled; Dismiss → status `dismissed` + decay similar.
5. Events: `suggestion_generated` (server), `suggestion_accepted` / `suggestion_dismissed` (client).

### 5.7 Goal + Identity Flow

1. Goals tab shows identity statement + identity grid + milestones strip + AI insight.
2. Tap identity card → identity detail screen (Why-this-score + contributors + milestones + recent wins/slips + Talk-to-coach).
3. Add identity → identity picker (8 defaults + custom) → contributors auto-suggested.
4. Connect habit/routine → `goals/{goalId}.connectedHabitIds` and `connectedRoutineTypes`.
5. Milestones: manual mark → `milestone_completed` → P6 push.
6. Pause/Archive → `identity_paused/archived` events.
7. **Special task §G1 wires:** GoalRepository correctly emits `identity_progress_changed` only on real progress delta; StateAggregator ingests goals+habits+tasks safely.

### 5.8 Habit + Task Flow

- Habit lifecycle: create → update → pause → resume → archive → delete; logs at `/habit_logs` (canonical, flat).
- Task lifecycle: scheduled → started → paused/resumed → completed/skipped/abandoned → outcome record.
- One active task at a time (relaxed for calendar-conflict ribbon).
- Plan-vs-actual capture into `task_outcomes` for AI duration learning.

### 5.9 Skin Care Routine Flow (3 modes)

- **Manual:** Add blocks per weekday, edit subtasks (Cleanse / Vitamin C / SPF), save → `routine/current.templates.skin_care`.
- **Text AI:** User types products → callable `routineImport` mode `skin_care_text` → returns structured items → review screen → accept → templates.
- **Photo AI:** User uploads photo of products → upload to Storage → callable `routineImport` mode `skin_care_photo` (image_metadata) → returns items → review → accept.

### 5.10 Supplement Routine Flow (2 modes)

- **Manual:** name, time, dosage, repeat → templates.
- **Text AI:** user typed supplement list → callable `routineImport` mode `supplement_text` → returns timing rules → review → accept.

### 5.11 Class Routine Flow (2 modes)

- **Manual:** subject, room, professor, weekday, start/end → templates.
- **Photo OCR:** user uploads timetable photo → Storage → callable `routineImport` mode `class_timetable_photo` → returns weekday-keyed schedule → review → accept.

### 5.12 Eating Routine Flow (3 modes)

- **Manual:** meal name, food, time → templates.
- **Mess menu photo:** user uploads hostel mess photo → Storage → callable `routineImport` mode `eating_mess_photo` → returns weekday × meal grid → review → accept.
- **AI goal text:** user types food goal ("hostel mass-gain extras") → callable `routineImport` mode `eating_goal_text` → returns full weekly routine → review → accept.

### 5.13 Photo Upload AI Flow (shared)

- Image picker → resize/compress → upload to Storage `users/{uid}/uploads/{type}/{ts}.jpg` → metadata to callable → AI returns structured items → review-before-save → templates → events.
- Failure: corrupt image / OCR fail → show "Couldn't read this — try again or type it in" → emit nothing.

### 5.14 Ghost Absence / Comeback Flow

- Background `inactivityCheck` Cloud Function runs daily.
- Day 1/3/7/14/30 thresholds → push messages; streak pause at day 3; comeback modal on next open.
- Comeback modal: Easy / Half / Full → `comeback_path_chosen` → 48h forced-supportive coach tone.
- Streaks resume if gap ≤ 7d, reset if ≥ 8d.

### 5.15 Protected Streak Pause / Resume Flow

- Pause: `streak_paused` per habit when `engagementState=ghost`.
- Resume: `streak_resumed` on `comeback_initiated` (gap ≤ 7d).
- Reset: `streak_broken` on gap ≥ 8d.
- UI: streak detail shows "Paused" chip with `pre_pause_count`.

### 5.16 AI Coach Interaction Flow

- Coach tab → input bar → user message → callable `coachReply(userId, threadId, text, mode)` → Cloud Function builds snapshot → calls Gemini with system prompt → streams reply → write `coach_messages` and `coach_speak_log`.
- Topic modes: long-press avatar → swap mode → preserve thread.
- Safety: regex/keyword match in client AND server → if match, route to safety function → show crisis card, never LLM-generate.

---

## 6. Dependency Map (strict build order)

1. **Auth + `/users/{uid}` schema** → onboarding completion writes (Phase 1 done).
2. **Models + Event payload validators** → before any service emits new events (Phase 2).
3. **Firestore rules + indexes for new collections** → before code that reads/writes them (Phases 2 + 17).
4. **TaskService state machine** → before timeline UI controls (Phase 3 done).
5. **Routine templates (`routine/current.templates.*`)** → before daily materialisation (Phase 5 done).
6. **Daily materialisation** → before reminders & day-close (Phase 5 done).
7. **Habit logs** → before streaks, tracker analytics, money-saved (Phase 7).
8. **Day-start / Day-close** → before mission ring, identity scoring, AI day planning (Phases 5 + 11).
9. **Goal/Identity schema + StateAggregator goals ingestion (§G1)** → before identity mission ring + AI context (Phase 9).
10. **Storage upload + image picker** → before any photo AI mode (Phase 12).
11. **Cloud Function `routineImport`** → before skin/supplement/class/eating AI modes' UI calls (Phase 12).
12. **Notification lifecycle service** → before custom alarms, caps, dedupe, AI nudges (Phase 10).
13. **Context snapshots + speak budget** → before rule engine + LLM (Phase 11).
14. **Suggestion storage** → before Routine AI accept/dismiss round-trip (Phase 11).
15. **Subscription / usage caps in Cloud Functions** → before AI shipping to all users (Phase 14).
16. **Privacy export/delete jobs** → before deletion lifecycle UI (Phase 14).
17. **Analytics summaries** → after events and day-close are stable (Phase 15).
18. **Remote config kill switches** → before final QA (Phase 16).
19. **App Check + rules tests** → before production release (Phase 17).
20. **Production QA + migration + seed** → release gate (Phase 18).

---

## 7. Phase-wise Master TODO List

> Every task uses the strict format. Status defaults to `Not started` unless the existing TODO recorded completion — in which case status carries over and the task body marks any outstanding gaps as a sub-task.


## Phase 0 — Audit Refresh & Guardrails

### Task 0.1 — Refresh implementation inventory & feature matrix

#### Status

- [ ] Not started
- [ ] In progress
- [x] Done (carried from previous TODO Pre-Phase 0 / Phase 0 — May 1 2026)
- [x] Needs review — verified May 4 2026: all new rows present

#### Why

The previous inventory was correct on 2026-05-01 but does not yet have explicit rows for every tracker variant the User Flow §8.4 mentions, the new `routineImport` AI modes, and the `coach_speak_log`/`ai_context_snapshots`/`weeklySummaries`/`usage`/`devices`/`data_exports`/`deletion_requests` Firestore paths. The matrix is the single source future tasks read.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Refresh `docs/implementation_inventory.md` and `docs/feature_matrix.md` so every feature in the 7 OPTIVUS Docs has a row.

## Files allowed to modify

Only modify these files:

- `docs/implementation_inventory.md`
- `docs/feature_matrix.md`

If another file is required, explain why before changing it.

## Firestore paths

(Read-only audit — no Firestore writes.)

## Requirements

- Read every file under `lib/` plus `functions/index.js` and `functions/jobs/*.js`.
- Re-list current files and sizes; flag any file > 1 KB as needing per-task verification.
- Add matrix rows for: smoking, screen time, mindful eating (eating-disorder swap), procrastination, hydration, meditation, money saving, reading, exercise/running, routine completion meta-tracker, supplement text-AI, skin care text-AI, skin care photo-AI, class timetable photo OCR, eating mess photo, eating goal-text AI, AI rule engine, AI safety routing, weekly summary, daily summary, notification center, notification settings, custom alarm editor + ringing, subscription, usage caps, privacy export, deletion lifecycle, App Check.
- Each row must have columns: Feature · UI path · Flutter file · Provider/state · Service/repository · Firestore path · Event · Cloud Function/backend · Notification need · AI need · Status (implemented | partial | missing) · Verification.
- Do not change app runtime code.

## Events

(No event emission.)

## Dependencies

Check whether these are implemented:

- N/A (audit task)

If dependencies are missing:
- explain what is missing
- implement only safe independent parts
- do not fake dependency behavior

## Verification

After implementation, run:

`flutter analyze`

Also verify:

- both files open without errors
- every row has all 12 columns
- the new rows above are present
- `git diff` shows only docs

## Final response format

Return:

1. Files inspected
2. Files changed
3. Summary of changes
4. Firestore paths affected
5. Events implemented or skipped
6. Analyzer result
7. Remaining risks or missing dependencies
```

#### Dependencies

- None.

#### How to verify

- UI: N/A (docs-only).
- Firebase console: N/A.
- Logs: N/A.
- Navigation: N/A.
- Edge cases: matrix has new rows; old rows preserved.

#### Estimate

2h

#### Done Criteria

- [x] Inventory + matrix exist (carried over).
- [x] All new rows added (smoking, running, meditation, supplements AI, eating mess photo, etc.).
- [x] Status column accurate against current code.

---

### Task 0.2 — Add contract test skeletons for new services

#### Status

- [ ] Not started
- [ ] In progress
- [x] Done (May 4 2026)

#### Why

Phase 11+ adds SuggestionService, RoutineImportService, CoachService (server-mode), RuleEngineService, SafetyRouter, NotificationDispatcher. Each needs a skipped/TODO Dart or JS test file so the test runner has a place to land assertions later, without blocking implementation.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Create skipped/TODO test files for: SuggestionService, RoutineImportService, CoachService backend mode, RuleEngineService, SafetyRouter, NotificationDispatcher, AnalyticsService, ExportService, DeleteService.

## Files allowed to modify

Only modify these files:

- `test/services/suggestion_service_contract_test.dart`
- `test/services/routine_import_service_contract_test.dart`
- `test/services/coach_service_contract_test.dart`
- `test/services/rule_engine_service_contract_test.dart`
- `test/services/safety_router_contract_test.dart`
- `test/services/analytics_service_contract_test.dart`
- `functions/test/routineImport.contract.test.js`
- `functions/test/notificationDispatcher.contract.test.js`
- `functions/test/safety.contract.test.js`
- `functions/test/exportUserData.contract.test.js`
- `functions/test/deleteUserData.contract.test.js`
- `functions/test/aiPlanner.contract.test.js`
- `functions/test/ruleEngine.contract.test.js`
- `functions/test/weeklySummary.contract.test.js`

If another file is required, explain why before changing it.

## Firestore paths

(No Firestore writes — tests use mocks.)

## Requirements

- Use `test_skipped` or `skip:` markers — tests must not fail due to absent implementation.
- Each test file must include a top-level comment describing the contract being tested.
- Add npm script `npm test` in `functions/package.json` if not present (uses Mocha or Jest — pick whichever already exists or default to Mocha + sinon).
- Do not modify production services.

## Events

N/A

## Dependencies

- Task 0.1.

## Verification

After implementation, run:

`flutter test`
`cd functions && npm test`

Both must succeed (with skipped tests).

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 0.1.

#### How to verify

- `flutter test` shows new skipped groups, no failures.
- `cd functions && npm test` runs cleanly.
- New test files exist in repo.

#### Estimate

1h

#### Done Criteria

- [x] All 14 test files exist.
- [x] Test runners pass with skips.
- [x] `functions/package.json` has `test` script.

---

### Task 0.3 — Re-verify executed Phase 1–5 done criteria

#### Status

- [x] Done (May 4 2026)

#### Why

Several previously-completed tasks have unchecked Done Criteria or weak verification (see §2.5 / §2.8). This task does **not** change code — it produces a verification report at `docs/phase_1_5_audit.md` listing per-task what was actually verified, what is still open, and what tests are missing.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Produce `docs/phase_1_5_audit.md` listing for every task 1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 3.1, 3.2, 3.3, 3.4, 3.5, 4.1, 4.2, 4.3, 4.4, 5.1, 5.2, 5.3:

- Files inspected
- What was actually completed (cite file:line)
- What is still missing
- What test exists / what test is needed
- Risk if shipped as-is

## Files allowed to modify

Only modify these files:

- `docs/phase_1_5_audit.md`

## Firestore paths

(Read-only.)

## Requirements

- Cite file:line when claiming a feature is implemented.
- Do not edit any Dart or JS file.
- Treat skipped test as "test missing".

## Verification

Open the doc; confirm every task above has its own subsection.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 0.1.

#### How to verify

- Doc exists; opens without errors.
- Every Phase 1–5 task has a section.
- Sections cite specific files.

#### Estimate

3h

#### Done Criteria

- [x] Audit doc exists.
- [x] All Phase 1–5 tasks audited.
- [x] Risks named explicitly.

---

## Phase 1 — Auth, User Schema, Onboarding (carry-over)

### Task 1.1 — Auth lifecycle + root user schema

#### Status

- [x] Done (May 1 2026 — see existing TODO).
- [ ] Needs review (rules-test for unauth denial — see Task 0.3).

#### Why

Already implemented; this entry exists so the new TODO carries the historical proof and Done Criteria.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Re-verify Task 1.1 only. Do not implement. Read the listed files and Firestore paths, confirm each requirement still holds against the current code, and report any gaps without modifying production code.

## Files allowed to modify

Only modify these files:

- `docs/phase_1_5_audit.md` (append a fresh section for Task 1.1)

If another file is required, explain why before changing it.

## Files to inspect (read-only)

- `lib/services/auth_service.dart`
- `lib/repositories/auth_repository.dart`
- `lib/models/user_model.dart`
- `lib/views/screens/signup_screen.dart`
- `lib/views/screens/login_screen.dart`
- `lib/core/constants/event_names.dart`

## Firestore paths

- `/users/{uid}`
- `/users/{uid}/events_recent/{eventId}`

## Requirements (verify each)

- confirm `/users/{uid}` has uid, email, displayName, createdAt, updatedAt, schemaVersion, timezone, hasCompletedOnboarding, onboardingStep, lastDayClosed, coachName, coachStyle, accountabilityMode, notificationSettings
- confirm exactly one `user_signed_up` per account
- confirm rules-test for unauthenticated denial exists (or report gap)

## Events

Use these event names only if the existing event system supports them:

- `user_signed_up`

If no event system exists, report clearly instead of inventing one.

## Dependencies

Check whether these are implemented:

- Task 0.3

If dependencies are missing:
- explain what is missing
- implement only safe independent parts
- do not fake dependency behavior

## Verification

After implementation, run:

`flutter analyze`

Also verify:

- every Requirement above can be cited to file:line
- if a Requirement fails, document the gap and the follow-up Task that owns the fix
- no production Dart or JS file is modified
- the audit doc gains a new section, not a rewrite

## Final response format

Return:

1. Files inspected
2. Files changed
3. Summary of changes
4. Firestore paths affected
5. Events implemented or skipped
6. Analyzer result
7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 0.3

#### How to verify

- UI: re-walk the user paths declared in the source TODO entry; flag deviations.
- Firebase console: spot-check one document per Firestore path above.
- Logs: confirm the events listed (or document why they are absent).
- Edge cases: any item flagged as "Needs review" must be reproduced or explicitly closed.

#### Estimate

1h (audit only)

#### Done Criteria

- [x] Signup works.
- [x] Login works.
- [x] Root user schema is complete.
- [x] `user_signed_up` is emitted once.

---

### Task 1.2 — About You onboarding (3 sub-pages)

#### Status

- [x] Done (May 1 2026).
- [ ] Needs review: verify eating-disorder flag actually gates calorie tracking app-wide (consumed by Tracker variants — see Task 7.6).

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Re-verify Task 1.2 only. Do not implement. Read the listed files and Firestore paths, confirm each requirement still holds against the current code, and report any gaps without modifying production code.

## Files allowed to modify

Only modify these files:

- `docs/phase_1_5_audit.md` (append a fresh section for Task 1.2)

If another file is required, explain why before changing it.

## Files to inspect (read-only)

- `lib/views/onboarding/onboarding_page_5.dart`
- `lib/providers/onboarding_provider.dart`
- `lib/repositories/user_repository.dart`
- `lib/models/user_model.dart`
- `lib/models/identity_profile_model.dart`

## Firestore paths

- `/users/{uid}/onboarding/state.aboutYou`
- `/users/{uid}/profile/main.biometrics`
- `/users/{uid}/profile/main.lifestyle`
- `/users/{uid}/profile/main.sensitiveContext`

## Requirements (verify each)

- confirm three sub-pages exist (Body basics, Lifestyle rhythm, Sensitive context)
- confirm sensitive-context skip works (fields nullable)
- confirm eating-disorder flag is consumed downstream by Tracker (Task 7.6)
- no `biometrics_updated` emitted during onboarding draft

## Events

Use these event names only if the existing event system supports them:

- (read-only re-verification — emit nothing.)

If no event system exists, report clearly instead of inventing one.

## Dependencies

Check whether these are implemented:

- Task 7.6

If dependencies are missing:
- explain what is missing
- implement only safe independent parts
- do not fake dependency behavior

## Verification

After implementation, run:

`flutter analyze`

Also verify:

- every Requirement above can be cited to file:line
- if a Requirement fails, document the gap and the follow-up Task that owns the fix
- no production Dart or JS file is modified
- the audit doc gains a new section, not a rewrite

## Final response format

Return:

1. Files inspected
2. Files changed
3. Summary of changes
4. Firestore paths affected
5. Events implemented or skipped
6. Analyzer result
7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 7.6

#### How to verify

- UI: re-walk the user paths declared in the source TODO entry; flag deviations.
- Firebase console: spot-check one document per Firestore path above.
- Logs: confirm the events listed (or document why they are absent).
- Edge cases: any item flagged as "Needs review" must be reproduced or explicitly closed.

#### Estimate

1h (audit only)

#### Done Criteria

- [x] Page 5 has three sub-pages.
- [x] Data persists.
- [x] Validation works.
- [x] Firestore paths match.

---

### Task 1.3 — Onboarding fixed schedule unlimited templates

#### Status

- [x] Done (May 1 2026).
- [ ] Needs review (Task 4.2 below extracts a shared widget — Problem 9).

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Re-verify Task 1.3 only. Do not implement. Read the listed files and Firestore paths, confirm each requirement still holds against the current code, and report any gaps without modifying production code.

## Files allowed to modify

Only modify these files:

- `docs/phase_1_5_audit.md` (append a fresh section for Task 1.3)

If another file is required, explain why before changing it.

## Files to inspect (read-only)

- `lib/views/onboarding/onboarding_page_9.dart`
- `lib/providers/onboarding_provider.dart`
- `lib/providers/routine_provider.dart`
- `lib/repositories/routine_repository.dart`

## Firestore paths

- `/users/{uid}/onboarding/state.fixedSchedule`
- `/users/{uid}/routine/current.templates.fixed_schedule`

## Requirements (verify each)

- confirm no 3-item cap remains
- confirm 6+ blocks persist as templates
- confirm onboarding does not create one-time tasks (templates only)
- flag if shared widget extraction (Task 4.2) is still pending

## Events

Use these event names only if the existing event system supports them:

- `routine_template_created`
- `routine_template_updated`
- `routine_template_deleted`

If no event system exists, report clearly instead of inventing one.

## Dependencies

Check whether these are implemented:

- Task 4.2

If dependencies are missing:
- explain what is missing
- implement only safe independent parts
- do not fake dependency behavior

## Verification

After implementation, run:

`flutter analyze`

Also verify:

- every Requirement above can be cited to file:line
- if a Requirement fails, document the gap and the follow-up Task that owns the fix
- no production Dart or JS file is modified
- the audit doc gains a new section, not a rewrite

## Final response format

Return:

1. Files inspected
2. Files changed
3. Summary of changes
4. Firestore paths affected
5. Events implemented or skipped
6. Analyzer result
7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 4.2

#### How to verify

- UI: re-walk the user paths declared in the source TODO entry; flag deviations.
- Firebase console: spot-check one document per Firestore path above.
- Logs: confirm the events listed (or document why they are absent).
- Edge cases: any item flagged as "Needs review" must be reproduced or explicitly closed.

#### Estimate

1h (audit only)

#### Done Criteria

- [x] User can add more than 3 blocks.
- [x] Blocks persist as templates.
- [x] Validation exists.
- [x] No one-time-only fixed schedule behavior remains.

---

### Task 1.4 — Onboarding page 10 plan-ready

#### Status

- [x] Done (May 1 2026).
- [ ] Needs review: confirm `task_scheduled` and `notification_scheduled` events emit during first-day materialisation.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Re-verify Task 1.4 only. Do not implement. Read the listed files and Firestore paths, confirm each requirement still holds against the current code, and report any gaps without modifying production code.

## Files allowed to modify

Only modify these files:

- `docs/phase_1_5_audit.md` (append a fresh section for Task 1.4)

If another file is required, explain why before changing it.

## Files to inspect (read-only)

- `lib/views/onboarding/onboarding_page_10.dart`
- `lib/views/screens/onboarding_screen.dart`
- `lib/providers/onboarding_provider.dart`
- `lib/repositories/user_repository.dart`
- `lib/providers/routine_provider.dart`

## Firestore paths

- `/users/{uid}.hasCompletedOnboarding`
- `/users/{uid}/profile/main`
- `/users/{uid}/routine/current`
- `/users/{uid}/tasks/{taskId}`
- `/users/{uid}/habits/{habitId}`
- `/users/{uid}/goals/{goalId}`
- `/users/{uid}/scheduled_notifications/{notificationId}`
- `/users/{uid}/ai_context_snapshots/{snapshotId}`

## Requirements (verify each)

- confirm onboarding completion writes all required docs
- confirm `task_scheduled`, `notification_scheduled`, `suggestion_generated` emit during first-day materialisation
- confirm Routine tab shows fixed schedule today after Page 10
- report if any event is missing instead of generating it

## Events

Use these event names only if the existing event system supports them:

- `onboarding_completed`
- `task_scheduled`
- `notification_scheduled`
- `suggestion_generated`

If no event system exists, report clearly instead of inventing one.

## Dependencies

Check whether these are implemented:

- Task 2.1

If dependencies are missing:
- explain what is missing
- implement only safe independent parts
- do not fake dependency behavior

## Verification

After implementation, run:

`flutter analyze`

Also verify:

- every Requirement above can be cited to file:line
- if a Requirement fails, document the gap and the follow-up Task that owns the fix
- no production Dart or JS file is modified
- the audit doc gains a new section, not a rewrite

## Final response format

Return:

1. Files inspected
2. Files changed
3. Summary of changes
4. Firestore paths affected
5. Events implemented or skipped
6. Analyzer result
7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 2.1

#### How to verify

- UI: re-walk the user paths declared in the source TODO entry; flag deviations.
- Firebase console: spot-check one document per Firestore path above.
- Logs: confirm the events listed (or document why they are absent).
- Edge cases: any item flagged as "Needs review" must be reproduced or explicitly closed.

#### Estimate

1h (audit only)

#### Done Criteria

- [x] Page 10 exists.
- [x] Start Today completes onboarding.
- [x] Fixed schedule appears in Routine today.
- [x] Required docs/events exist.

---

## Phase 2 — Event Spine & Firestore Contracts (carry-over + gap-fill)

### Task 2.1 — EventService production-grade

#### Status

- [x] Done (May 2 2026).

---

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Re-verify Task 2.1 only. Do not implement. Read the listed files and Firestore paths, confirm each requirement still holds against the current code, and report any gaps without modifying production code.

## Files allowed to modify

Only modify these files:

- `docs/phase_1_5_audit.md` (append a fresh section for Task 2.1)

If another file is required, explain why before changing it.

## Files to inspect (read-only)

- `lib/services/event_service.dart`
- `lib/services/event_payload_validator.dart`
- `lib/models/event_model.dart`
- `lib/core/constants/event_names.dart`
- `lib/core/utils/uuid_generator.dart`
- `test/services/event_service_contract_test.dart`

## Firestore paths

- `/users/{uid}/events/{eventId}`
- `/users/{uid}/events_recent/{eventId}`

## Requirements (verify each)

- confirm event envelope has eventId, eventName, uid, timestamp, source, schemaVersion, payloadVersion, payload, deviceId, appVersion
- confirm duplicate eventId is a no-op (transaction check)
- confirm both events and events_recent receive identical envelope in one transaction
- list any unvalidated event names (will be patched in Task 2.3)

## Events

Use these event names only if the existing event system supports them:

- (read-only re-verification — emit nothing.)

If no event system exists, report clearly instead of inventing one.

## Dependencies

Check whether these are implemented:

- Task 2.3

If dependencies are missing:
- explain what is missing
- implement only safe independent parts
- do not fake dependency behavior

## Verification

After implementation, run:

`flutter analyze`

Also verify:

- every Requirement above can be cited to file:line
- if a Requirement fails, document the gap and the follow-up Task that owns the fix
- no production Dart or JS file is modified
- the audit doc gains a new section, not a rewrite

## Final response format

Return:

1. Files inspected
2. Files changed
3. Summary of changes
4. Firestore paths affected
5. Events implemented or skipped
6. Analyzer result
7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 2.3

#### How to verify

- UI: re-walk the user paths declared in the source TODO entry; flag deviations.
- Firebase console: spot-check one document per Firestore path above.
- Logs: confirm the events listed (or document why they are absent).
- Edge cases: any item flagged as "Needs review" must be reproduced or explicitly closed.

#### Estimate

1h (audit only)


### Task 2.2 — Firestore schema, rules, indexes alignment

#### Status

- [x] Done (May 2 2026).

---

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Re-verify Task 2.2 only. Do not implement. Read the listed files and Firestore paths, confirm each requirement still holds against the current code, and report any gaps without modifying production code.

## Files allowed to modify

Only modify these files:

- `docs/phase_1_5_audit.md` (append a fresh section for Task 2.2)

If another file is required, explain why before changing it.

## Files to inspect (read-only)

- `firestore.rules`
- `firestore.indexes.json`
- `lib/services/firestore_service.dart`
- `docs/firestore_schema_v1_mapping.md`

## Firestore paths

- `/users/{uid}/...`
- `all per-user subcollections in §3.5 of TODO`

## Requirements (verify each)

- confirm rules deny cross-user reads/writes
- confirm append-only enforcement on /events and /events_recent
- confirm indexes cover queries used by app today
- list any new collection (suggestions, coach_messages, etc.) that lacks rules — Task 17.1 will fix

## Events

Use these event names only if the existing event system supports them:

- (read-only re-verification — emit nothing.)

If no event system exists, report clearly instead of inventing one.

## Dependencies

Check whether these are implemented:

- Task 2.4
- Task 17.1

If dependencies are missing:
- explain what is missing
- implement only safe independent parts
- do not fake dependency behavior

## Verification

After implementation, run:

`flutter analyze`

Also verify:

- every Requirement above can be cited to file:line
- if a Requirement fails, document the gap and the follow-up Task that owns the fix
- no production Dart or JS file is modified
- the audit doc gains a new section, not a rewrite

## Final response format

Return:

1. Files inspected
2. Files changed
3. Summary of changes
4. Firestore paths affected
5. Events implemented or skipped
6. Analyzer result
7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 2.4
- Task 17.1

#### How to verify

- UI: re-walk the user paths declared in the source TODO entry; flag deviations.
- Firebase console: spot-check one document per Firestore path above.
- Logs: confirm the events listed (or document why they are absent).
- Edge cases: any item flagged as "Needs review" must be reproduced or explicitly closed.

#### Estimate

1h (audit only)


### Task 2.3 — Extend event payload validator with new events (NEW)

#### Status

- [x] Done (May 4 2026).
- **Re-open required before Task 12.7:** Three new events must be added to `event_names.dart` and `event_payload_validator.dart`:
  - `nutritional_target_computed` — payload: `{uid, tdeeKcal, source:'mifflin_st_jeor'}`
  - `ai_meal_suggestion_created` — payload: `{uid, date, slot, mealName, calories, repeatRule}`
  - `ai_meal_preference_updated` — payload: `{uid, flavorTags: [...]}`

#### Why

The validator covers core events. Verified present: `routine_template_created/updated/deleted` (lines 112–114, rule `_routineTemplateRule`). Genuinely missing payload schemas: `screen_time_synced`, `slip_log_dismissed`, `bad_day_detected`, `weekly_insight_ready`, `comeback_path_chosen`, `account_deleted`, `notification_missed`, `coach_re_enabled`. Without explicit schemas these events ship un-validated and break listeners.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Extend `lib/services/event_payload_validator.dart` with payload schemas for these events (do NOT touch the existing `_routineTemplateRule` — already covers `routine_template_created/updated/deleted`): `screen_time_synced`, `slip_log_dismissed`, `bad_day_detected`, `weekly_insight_ready`, `comeback_path_chosen`, `account_deleted`, `notification_missed`, `coach_re_enabled`.

## Files allowed to modify

Only modify these files:

- `lib/services/event_payload_validator.dart`
- `lib/core/constants/event_names.dart`
- `test/services/event_service_contract_test.dart`

If another file is required, explain why before changing it.

## Firestore paths

- `/users/{uid}/events/{eventId}`
- `/users/{uid}/events_recent/{eventId}`

## Requirements

- Add constants for new event names if missing (snake_case, past tense).
- Validators return clear error messages when fields are missing or wrong type.
- Default `priority='medium'` accepted.
- Reject unknown fields only in debug builds (warn) — in release just log.
- Preserve existing validators byte-for-byte.

## Events

- `screen_time_synced`
- `routine_template_created`
- `routine_template_updated`
- `routine_template_deleted`
- `slip_log_dismissed`
- `bad_day_detected`
- `weekly_insight_ready`
- `comeback_path_chosen`
- `account_deleted`
- `notification_missed`

## Dependencies

- Task 2.1.

## Verification

Run `flutter test test/services/event_service_contract_test.dart`. Verify each new event has a passing valid-case + a failing invalid-case test.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 2.1.

#### How to verify

- Tests pass.
- Logs: invalid payload rejected at debug.
- Edge cases: payload with extra fields accepted in release.

#### Estimate

2h

#### Done Criteria

- [x] All 10 new events have validators.
- [x] Test cases cover valid + invalid.
- [x] No existing validator broken.

---

### Task 2.4 — Extend Firestore indexes for new collections (NEW)

#### Status

- [x] Done (May 4 2026).
- **Re-open required before Task 12.7:** Add indexes for two new AI eating collections:
  - `routine/ai_suggestions`: composite `date ASC, slot ASC` (used by timeline to load AI blocks for a date).
  - `routine/nutritional_targets`: no composite index needed (single doc per user).
  - `routine/preferences`: no composite index needed (single doc per user).

#### Why

Phases 10–15 add new collections (`suggestions`, `coach_messages`, `coach_speak_log`, `scheduled_notifications`, `notificationLog`, `weeklySummaries`, `usage`). Without composite indexes declared up front, queries fail in production.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Add composite indexes to `firestore.indexes.json` for upcoming queries.

## Files allowed to modify

Only modify these files:

- `firestore.indexes.json`
- `docs/firestore_schema_v1_mapping.md`

## Firestore paths

(Indexes only.)

## Requirements

- Add composite indexes for:
  - `suggestions`: `status ASC, createdAt DESC`
  - `coach_messages`: `threadId ASC, ts DESC`
  - `scheduled_notifications`: `state ASC, fireAt ASC`
  - `events_recent`: `eventName ASC, timestamp DESC`
  - `notificationLog`: `notifId ASC, ts DESC`
  - `weeklySummaries`: `weekKey DESC`
  - `tasks` (verify exists): `state ASC, plannedStart ASC` and `parentRoutine ASC, plannedStart DESC`
- Document each index in `docs/firestore_schema_v1_mapping.md` with the query that uses it.

## Verification

Deploy rules + indexes to emulator: `firebase deploy --only firestore:indexes` (dry-run). No errors. Inspect doc.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 2.2.

#### How to verify

- Emulator deploy succeeds.
- Doc explains each index's query.

#### Estimate

1h

#### Done Criteria

- [x] All listed indexes declared.
- [x] Doc updated.

---

## Phase 3 — Task, Routine, Day Lifecycle (carry-over)

### Task 3.1 — TaskService contract

#### Status

- [x] Done (May 2 2026).

---

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Re-verify Task 3.1 only. Do not implement. Read the listed files and Firestore paths, confirm each requirement still holds against the current code, and report any gaps without modifying production code.

## Files allowed to modify

Only modify these files:

- `docs/phase_1_5_audit.md` (append a fresh section for Task 3.1)

If another file is required, explain why before changing it.

## Files to inspect (read-only)

- `lib/services/task_service.dart`
- `lib/models/task_model.dart`
- `lib/core/constants/event_names.dart`
- `test/services/task_service_contract_test.dart`

## Firestore paths

- `/users/{uid}/tasks/{taskId}`
- `/users/{uid}/task_outcomes/{taskId}`

## Requirements (verify each)

- confirm full state machine: scheduled → started → paused/resumed → completed/skipped/abandoned
- confirm only one active task at a time (or relaxed only on conflict)
- confirm subtask check auto-completes parent
- confirm task and subtask events emit per state change

## Events

Use these event names only if the existing event system supports them:

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

If no event system exists, report clearly instead of inventing one.

## Dependencies

Check whether these are implemented:

- (no follow-ups required by this re-verify.)

If dependencies are missing:
- explain what is missing
- implement only safe independent parts
- do not fake dependency behavior

## Verification

After implementation, run:

`flutter analyze`

Also verify:

- every Requirement above can be cited to file:line
- if a Requirement fails, document the gap and the follow-up Task that owns the fix
- no production Dart or JS file is modified
- the audit doc gains a new section, not a rewrite

## Final response format

Return:

1. Files inspected
2. Files changed
3. Summary of changes
4. Firestore paths affected
5. Events implemented or skipped
6. Analyzer result
7. Remaining risks or missing dependencies
```

#### Dependencies

- None (re-verify only)

#### How to verify

- UI: re-walk the user paths declared in the source TODO entry; flag deviations.
- Firebase console: spot-check one document per Firestore path above.
- Logs: confirm the events listed (or document why they are absent).
- Edge cases: any item flagged as "Needs review" must be reproduced or explicitly closed.

#### Estimate

1h (audit only)


### Task 3.2 — Daily materialisation from reusable templates

#### Status

- [x] Done (May 2 2026).

---

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Re-verify Task 3.2 only. Do not implement. Read the listed files and Firestore paths, confirm each requirement still holds against the current code, and report any gaps without modifying production code.

## Files allowed to modify

Only modify these files:

- `docs/phase_1_5_audit.md` (append a fresh section for Task 3.2)

If another file is required, explain why before changing it.

## Files to inspect (read-only)

- `lib/providers/routine_provider.dart`
- `lib/repositories/routine_repository.dart`
- `lib/services/task_service.dart`

## Firestore paths

- `/users/{uid}/routine/current`
- `/users/{uid}/tasks/{taskId}`

## Requirements (verify each)

- confirm idempotent: re-running materialise does not create duplicates
- confirm completed/skipped/abandoned past tasks are preserved
- confirm deterministic task id pattern uses scheduledDate + routineType + templateId
- flag if Task 5.1 idempotency tests are still pending

## Events

Use these event names only if the existing event system supports them:

- `task_scheduled`

If no event system exists, report clearly instead of inventing one.

## Dependencies

Check whether these are implemented:

- Task 5.1

If dependencies are missing:
- explain what is missing
- implement only safe independent parts
- do not fake dependency behavior

## Verification

After implementation, run:

`flutter analyze`

Also verify:

- every Requirement above can be cited to file:line
- if a Requirement fails, document the gap and the follow-up Task that owns the fix
- no production Dart or JS file is modified
- the audit doc gains a new section, not a rewrite

## Final response format

Return:

1. Files inspected
2. Files changed
3. Summary of changes
4. Firestore paths affected
5. Events implemented or skipped
6. Analyzer result
7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 5.1

#### How to verify

- UI: re-walk the user paths declared in the source TODO entry; flag deviations.
- Firebase console: spot-check one document per Firestore path above.
- Logs: confirm the events listed (or document why they are absent).
- Edge cases: any item flagged as "Needs review" must be reproduced or explicitly closed.

#### Estimate

1h (audit only)


### Task 3.3 — Routine tab Add + AI buttons + selected day

#### Status

- [x] Done (May 2 2026).

---

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Re-verify Task 3.3 only. Do not implement. Read the listed files and Firestore paths, confirm each requirement still holds against the current code, and report any gaps without modifying production code.

## Files allowed to modify

Only modify these files:

- `docs/phase_1_5_audit.md` (append a fresh section for Task 3.3)

If another file is required, explain why before changing it.

## Files to inspect (read-only)

- `lib/views/routine/routine_tab.dart`
- `lib/views/routine/add_task_sheet.dart`
- `lib/views/routine/ai_routine_panel.dart`
- `lib/views/routine/timeline_section.dart`
- `lib/views/routine/timeline_zoom_views.dart`

## Firestore paths

- `/users/{uid}/tasks/{taskId}`
- `/users/{uid}/routine/current.templates.custom`
- `/users/{uid}/suggestions/{suggestionId}`

## Requirements (verify each)

- confirm Add button visible and opens sheet for selected date
- confirm AI button opens panel
- confirm task rows expose Start/Pause/Resume/Complete/Skip/Abandon as status allows
- flag if Routine Add polish (Task 5.2) or AI round-trip (Task 11.3) are still pending

## Events

Use these event names only if the existing event system supports them:

- `task_scheduled`
- `task_started`
- `task_completed`
- `task_abandoned`
- `suggestion_generated`
- `suggestion_accepted`
- `suggestion_dismissed`

If no event system exists, report clearly instead of inventing one.

## Dependencies

Check whether these are implemented:

- Task 5.2
- Task 11.3

If dependencies are missing:
- explain what is missing
- implement only safe independent parts
- do not fake dependency behavior

## Verification

After implementation, run:

`flutter analyze`

Also verify:

- every Requirement above can be cited to file:line
- if a Requirement fails, document the gap and the follow-up Task that owns the fix
- no production Dart or JS file is modified
- the audit doc gains a new section, not a rewrite

## Final response format

Return:

1. Files inspected
2. Files changed
3. Summary of changes
4. Firestore paths affected
5. Events implemented or skipped
6. Analyzer result
7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 5.2
- Task 11.3

#### How to verify

- UI: re-walk the user paths declared in the source TODO entry; flag deviations.
- Firebase console: spot-check one document per Firestore path above.
- Logs: confirm the events listed (or document why they are absent).
- Edge cases: any item flagged as "Needs review" must be reproduced or explicitly closed.

#### Estimate

1h (audit only)


### Task 3.4 — Routine setup screens & supplement screen (manual modes)

#### Status

- [x] Done (May 2 2026) — manual modes only.
- [ ] Needs review: AI text/photo modes deferred to Phase 12.

---

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Re-verify Task 3.4 only. Do not implement. Read the listed files and Firestore paths, confirm each requirement still holds against the current code, and report any gaps without modifying production code.

## Files allowed to modify

Only modify these files:

- `docs/phase_1_5_audit.md` (append a fresh section for Task 3.4)

If another file is required, explain why before changing it.

## Files to inspect (read-only)

- `lib/views/routine/fixed_schedule_setup_screen.dart`
- `lib/views/routine/skin_care_setup_screen.dart`
- `lib/views/routine/eating_setup_screen.dart`
- `lib/views/routine/class_setup_screen.dart`
- `lib/views/routine/supplement_setup_screen.dart`
- `lib/views/routine/routine_settings_sheet.dart`
- `lib/views/tabs/routine_settings_screen.dart`
- `lib/providers/routine_provider.dart`
- `lib/repositories/routine_repository.dart`

## Firestore paths

- `/users/{uid}/routine/current.templates.{routineType}`

## Requirements (verify each)

- confirm 5 setup screens render and save manual templates
- confirm AI text/photo modes are scaffolded (UI tabs exist) but defer real wiring to Phase 12 tasks
- confirm review-before-save widget is reusable (Task 12.2 will harden it)
- list any setup screen missing from Routine settings hub (Task 6.5)

## Events

Use these event names only if the existing event system supports them:

- `routine_template_created`
- `routine_template_updated`
- `routine_template_deleted`

If no event system exists, report clearly instead of inventing one.

## Dependencies

Check whether these are implemented:

- Task 6.5
- Task 12.2
- Task 12.3
- Task 12.4
- Task 12.5
- Task 12.6
- Task 12.7

If dependencies are missing:
- explain what is missing
- implement only safe independent parts
- do not fake dependency behavior

## Verification

After implementation, run:

`flutter analyze`

Also verify:

- every Requirement above can be cited to file:line
- if a Requirement fails, document the gap and the follow-up Task that owns the fix
- no production Dart or JS file is modified
- the audit doc gains a new section, not a rewrite

## Final response format

Return:

1. Files inspected
2. Files changed
3. Summary of changes
4. Firestore paths affected
5. Events implemented or skipped
6. Analyzer result
7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 6.5
- Task 12.2
- Task 12.3
- Task 12.4
- Task 12.5
- Task 12.6
- Task 12.7

#### How to verify

- UI: re-walk the user paths declared in the source TODO entry; flag deviations.
- Firebase console: spot-check one document per Firestore path above.
- Logs: confirm the events listed (or document why they are absent).
- Edge cases: any item flagged as "Needs review" must be reproduced or explicitly closed.

#### Estimate

1h (audit only)


### Task 3.5 — Day start, day close, mission ring

#### Status

- [x] Done (May 2 2026).
- [ ] Needs review: mission-ring identity-aligned weighting (Event System §10.1) — see Task 5.6.

---

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Re-verify Task 3.5 only. Do not implement. Read the listed files and Firestore paths, confirm each requirement still holds against the current code, and report any gaps without modifying production code.

## Files allowed to modify

Only modify these files:

- `docs/phase_1_5_audit.md` (append a fresh section for Task 3.5)

If another file is required, explain why before changing it.

## Files to inspect (read-only)

- `lib/services/routine_service.dart`
- `lib/models/day_summary_model.dart`
- `lib/views/tabs/home_tab.dart`
- `lib/core/providers.dart`
- `functions/jobs/dayClose.js`

## Firestore paths

- `/users/{uid}/dailySummaries/{date}`
- `/users/{uid}/tasks/{taskId}`
- `/users/{uid}/habit_logs/{logId}`
- `/users/{uid}/streaks/{streakId}`
- `/users/{uid}/identity_profile/main`

## Requirements (verify each)

- confirm day_started emits once per local date (idempotent)
- confirm day_close handles missed days in order
- confirm summary contains task completion, routine completion, focus minutes, habit completion, slips, streak inputs, identity inputs, mission score
- flag if mission-ring identity-aligned weighting (Task 5.3) is still pending

## Events

Use these event names only if the existing event system supports them:

- `day_started`
- `day_closed`
- `routine_block_completed`
- `routine_day_summarized`

If no event system exists, report clearly instead of inventing one.

## Dependencies

Check whether these are implemented:

- Task 5.3

If dependencies are missing:
- explain what is missing
- implement only safe independent parts
- do not fake dependency behavior

## Verification

After implementation, run:

`flutter analyze`

Also verify:

- every Requirement above can be cited to file:line
- if a Requirement fails, document the gap and the follow-up Task that owns the fix
- no production Dart or JS file is modified
- the audit doc gains a new section, not a rewrite

## Final response format

Return:

1. Files inspected
2. Files changed
3. Summary of changes
4. Firestore paths affected
5. Events implemented or skipped
6. Analyzer result
7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 5.3

#### How to verify

- UI: re-walk the user paths declared in the source TODO entry; flag deviations.
- Firebase console: spot-check one document per Firestore path above.
- Logs: confirm the events listed (or document why they are absent).
- Edge cases: any item flagged as "Needs review" must be reproduced or explicitly closed.

#### Estimate

1h (audit only)


## Phase 4 — Onboarding ↔ Settings Fixed Schedule Source-of-Truth

### Task 4.1 — Audit & document fixed-schedule data flow (NEW — Problem 9)

#### Status

- [ ] Not started

#### Why

Onboarding page 9 and the Settings fixed-schedule screen are separate files (`onboarding_page_9.dart` vs `fixed_schedule_setup_screen.dart`) but they save to the same Firestore path. Before extracting a shared widget we must prove there is no duplicate doc and define the contract.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Audit `onboarding_page_9.dart` and `fixed_schedule_setup_screen.dart`. Produce `docs/fixed_schedule_audit.md` documenting:
- The exact widget tree differences (lists, validation, sort order).
- The save path each screen uses.
- Any duplicate writes.
- The fields written in each path.
- A ranked list of differences, smallest first.

## Files allowed to modify

Only modify these files:

- `docs/fixed_schedule_audit.md`

## Firestore paths

- Read `/users/{uid}/onboarding/state.fixedSchedule`
- Read `/users/{uid}/routine/current.templates.fixed_schedule`

## Requirements

- Cite file:line for every claim.
- Do not edit any Dart file.

## Verification

Open the doc; confirm both screens are documented.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- None.

#### How to verify

- Doc exists; lists differences.

#### Estimate

2h

#### Done Criteria

- [ ] Audit doc created.
- [ ] Differences ranked.
- [ ] Save paths confirmed identical.

---

### Task 4.2 — Extract shared FixedScheduleEditor widget (NEW — Problem 9)

#### Status

- [ ] Not started

#### Why

Both onboarding page 9 and Settings → Fixed Schedule should share one widget so behaviour, validation, and Firestore writes are identical. Edits in either place must update the same canonical doc.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Extract a shared `FixedScheduleEditor` widget that both onboarding page 9 and the Settings fixed-schedule screen use. Both must write to `/users/{uid}/routine/current.templates.fixed_schedule` via `RoutineRepository.saveFixedScheduleTemplates`.

## Files allowed to modify

Only modify these files:

- `lib/views/routine/widgets/fixed_schedule_editor.dart` (new)
- `lib/views/onboarding/onboarding_page_9.dart`
- `lib/views/routine/fixed_schedule_setup_screen.dart`
- `lib/views/tabs/routine_settings_screen.dart` (link to setup screen if missing)

If another file is required, explain why before changing it.

## Firestore paths

- `/users/{uid}/routine/current.templates.fixed_schedule`
- `/users/{uid}/onboarding/state.fixedSchedule` (draft only — must be cleared on onboarding completion)

## Requirements

- The widget exposes: list of `FixedScheduleTemplate`, add/edit/remove/reorder callbacks, validation rules, Save callback returning a Future.
- Onboarding uses the widget in draft mode (state held in `onboarding_provider.dart`); Settings uses it in immediate-save mode.
- Validation prevents empty title, invalid times. Allows unlimited blocks.
- Both screens look the same (same colors, paddings, typography). Diff allowed only for header / nav / "Save & Continue" vs "Done".
- Preserve existing onboarding flow; do not change page numbering.

## Events

- `routine_template_created`
- `routine_template_updated`
- `routine_template_deleted`

## Dependencies

- Task 4.1.

## Verification

After implementation, run:

`flutter analyze`

Also verify:

- UI: open onboarding fresh user → add 6+ items → finish onboarding → Settings → Fixed Schedule → confirm same 6+ items.
- Edit one item from Settings → reopen Routine tab tomorrow → confirm change.
- Firebase console: only one `routine/current` doc; no duplicate `templates.fixed_schedule` array.
- No duplicate template events for unchanged items.
- Old users with existing fixed_schedule data still load.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 4.1.

#### How to verify

- UI: onboarding 6+ items → Settings shows them → edit → Routine timeline updates.
- Firebase console: single doc; no dup arrays.
- Logs: template events emitted only for actual changes.
- Navigation: returning to onboarding mid-flow still preserves draft.
- Edge cases: existing user re-launches onboarding (shouldn't usually but if forced) does not wipe templates.

#### Estimate

1 day

#### Done Criteria

- [ ] Shared widget exists.
- [ ] Onboarding + Settings both use it.
- [ ] Single Firestore doc.
- [ ] Existing data preserved.
- [ ] Verification matrix from Problem 9 passes.

---

### Task 4.3 — Wire Settings → Fixed Schedule entry-point (NEW)

#### Status

- [ ] Not started

#### Why

Profile tab and Routine settings screen must both expose a clear path to "Fixed Schedule" that opens the shared editor. This unblocks Problem 9's verification list.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Add Settings → Fixed Schedule entry from Profile tab and Routine settings sheet. Both routes open `fixed_schedule_setup_screen.dart` which now uses the shared `FixedScheduleEditor`.

## Files allowed to modify

Only modify these files:

- `lib/views/tabs/profile_tab.dart`
- `lib/views/routine/routine_settings_sheet.dart`
- `lib/views/tabs/routine_settings_screen.dart`
- `lib/core/router/app_router.dart`

## Firestore paths

- read `/users/{uid}/routine/current.templates.fixed_schedule`

## Requirements

- Profile → Routine settings → Fixed Schedule
- Routine settings sheet → "Fixed schedule" row with chevron
- Both navigate to the same setup screen.
- Re-entry preserves edits (no double-saving).

## Events

- (none for this entry — the editor task emits.)

## Dependencies

- Task 4.2.

## Verification

UI: navigate Profile → Routine settings → Fixed Schedule. Confirm same screen appears as in onboarding.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 4.2.

#### How to verify

- UI: 2-tap path from Profile.
- Edge cases: missing routine doc gracefully shows empty editor.

#### Estimate

2h

#### Done Criteria

- [ ] Profile route exists.
- [ ] Routine settings sheet route exists.
- [ ] Both reach same screen.

---

## Phase 5 — Routine Timeline & Daily Repeat Engine (gap-fill on done work)

### Task 5.1 — Idempotency & timezone proof for fixed-schedule daily repeat (NEW — Problem 2)

#### Status

- [ ] Not started

#### Why

Materialisation is implemented (Task 3.2). This task **proves** correctness: deterministic IDs, no duplicates across DST transitions, edits to template do not retro-overwrite completed tasks, multiple devices flushing offline writes don't double-create.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Add tests + small hardening for `RoutineNotifier.materializeForDate` and `materializeForWindow`.

## Files allowed to modify

Only modify these files:

- `test/services/routine_service_contract_test.dart`
- `test/providers/routine_notifier_test.dart` (new)
- `lib/providers/routine_provider.dart` (only if a defect is found; extend, do not rewrite)

## Firestore paths

- `/users/{uid}/routine/current`
- `/users/{uid}/tasks/{taskId}`

## Requirements

- Test: same template + same date materialises once.
- Test: re-running materialise after a manual edit to a future-day task does not overwrite the manual edit (subtask order, time).
- Test: completed/skipped/abandoned task on past date is preserved when template changes.
- Test: DST transition does not duplicate or skip a date.
- Test: timezone change (Asia/Kolkata → UTC) maps correctly.
- Test: 14-day rolling window does not generate beyond it.
- If a defect is found, fix only the smallest scope. Document any change.

## Events

- `task_scheduled` only for new instances.

## Dependencies

- Task 3.2.

## Verification

`flutter test test/providers/routine_notifier_test.dart` — all pass.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 3.2.

#### How to verify

- Tests pass.
- Manual: edit a template at 23:55 local → materialise at 00:05 → no duplicate.
- Manual: travel between timezones in emulator (set device tz) → tasks correct.

#### Estimate

4h

#### Done Criteria

- [ ] Tests cover idempotency, DST, tz change, history preservation.
- [ ] No duplicates in any test.

---

### Task 5.2 — Routine Add button polish (NEW — Problem 3)

#### Status

- [ ] Not started

#### Why

`add_task_sheet.dart` exists; this task refines: clear validation copy, repeat-rule presets (daily / weekdays / weekends / weekly), reminder toggle wired to NotificationService, support for any-selected-day, and full empty/loading/error states.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Polish the Routine tab Add button flow.

## Files allowed to modify

Only modify these files:

- `lib/views/routine/add_task_sheet.dart`
- `lib/views/routine/routine_tab.dart`
- `lib/providers/routine_provider.dart` (only for new fields if needed)
- `lib/repositories/routine_repository.dart`

## Firestore paths

- One-off: `/users/{uid}/tasks/{taskId}` with `scheduledDate`
- Repeating: `/users/{uid}/routine/current.templates.custom`
- Reminders: `/users/{uid}/scheduled_notifications/{id}`

## Requirements

- Sheet shows: Title, Date (defaults selected day), Start, End or Duration, Routine type (custom/skin_care/etc.), Notes, Reminder toggle, Repeat rule (none/daily/weekdays/weekends/weekly).
- Validation: blank title, end < start, duration > 24h.
- Loading state during save; error toast on failure.
- Empty state on Routine tab when no tasks for selected day: "Nothing planned" + Add button.
- Reminder toggle creates a `scheduled_notifications` doc with category `task_reminder` priority P3.

## Events

- `task_scheduled`
- `routine_template_created` if Repeat selected
- `notification_scheduled` if Reminder enabled

## Dependencies

- Task 3.3.

## Verification

UI: add task to tomorrow → appears tomorrow only. Add repeating "daily" task → appears every day. Toggle reminder → `scheduled_notifications` doc exists. Validation: blank title disables Save.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 3.3.

#### How to verify

- UI: 4 click paths above.
- Firebase console: doc shape correct.
- Logs: events emitted.

#### Estimate

4h

#### Done Criteria

- [ ] Validation works.
- [ ] Repeat rule presets work.
- [ ] Reminder toggle creates notification doc.
- [ ] Empty state visible.

---

### Task 5.3 — Mission ring identity-aligned weighting

#### Status

- [ ] Not started

#### Why

Per Event System §10.1, Mission ring counts identity-aligned tasks at full weight and others at half weight. Verify and fix `home_tab.dart` mission-ring computation.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Verify `home_tab.dart` mission ring uses the EventSystem §10.1 formula. If not, fix.

## Files allowed to modify

Only modify these files:

- `lib/views/tabs/home_tab.dart`
- `lib/services/routine_service.dart`
- `lib/models/day_summary_model.dart`

## Firestore paths

- `/users/{uid}/dailySummaries/{date}`
- `/users/{uid}/tasks` (read for identity tags)

## Requirements

- mission_pct = (identity_aligned_completed_value + non_aligned_completed_value × 0.5) / max_possible_value_today
- Identity-aligned = task.identityTags overlaps user's active goals' identityTag.
- 100% with 0 identity-aligned should surface as a Tracker insight (Phase 15).

## Events

- (read-only on home; writes happen in dayClose.)

## Dependencies

- Task 3.5.

## Verification

Test: 7 random tasks complete + 0 identity-aligned → ring < 70%. 3 identity-aligned + 0 random → ring 100%.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 3.5.

#### How to verify

- Unit test on the formula.
- UI: ring math matches predicted percentage.

#### Estimate

3h

#### Done Criteria

- [ ] Formula matches doc.
- [ ] Unit test passes.

---

## Phase 6 — Routine Setup Categories (manual surface polish)

### Task 6.1 — Skin care manual setup polish

#### Status

- [x] Done (manual mode — May 2 2026).
- [ ] Needs review: ensure Settings entry-point exists (Phase 4.3 covers).

---

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Re-verify Task 6.1 only. Do not implement. Read the listed files and Firestore paths, confirm each requirement still holds against the current code, and report any gaps without modifying production code.

## Files allowed to modify

Only modify these files:

- `docs/phase_1_5_audit.md` (append a fresh section for Task 6.1)

If another file is required, explain why before changing it.

## Files to inspect (read-only)

- `lib/views/routine/skin_care_setup_screen.dart`

## Firestore paths

- `/users/{uid}/routine/current.templates.skin_care`

## Requirements (verify each)

- confirm manual mode saves templates with title, time, weekday, steps, notes
- flag if Settings entry-point (Task 4.3) or AI text/photo modes (Tasks 12.2/12.3) are still pending

## Events

Use these event names only if the existing event system supports them:

- `routine_template_created`

If no event system exists, report clearly instead of inventing one.

## Dependencies

Check whether these are implemented:

- Task 4.3
- Task 12.2
- Task 12.3

If dependencies are missing:
- explain what is missing
- implement only safe independent parts
- do not fake dependency behavior

## Verification

After implementation, run:

`flutter analyze`

Also verify:

- every Requirement above can be cited to file:line
- if a Requirement fails, document the gap and the follow-up Task that owns the fix
- no production Dart or JS file is modified
- the audit doc gains a new section, not a rewrite

## Final response format

Return:

1. Files inspected
2. Files changed
3. Summary of changes
4. Firestore paths affected
5. Events implemented or skipped
6. Analyzer result
7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 4.3
- Task 12.2
- Task 12.3

#### How to verify

- UI: re-walk the user paths declared in the source TODO entry; flag deviations.
- Firebase console: spot-check one document per Firestore path above.
- Logs: confirm the events listed (or document why they are absent).
- Edge cases: any item flagged as "Needs review" must be reproduced or explicitly closed.

#### Estimate

1h (audit only)


### Task 6.2 — Supplement manual setup polish

#### Status

- [x] Done (manual mode — May 2 2026).

---

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Re-verify Task 6.2 only. Do not implement. Read the listed files and Firestore paths, confirm each requirement still holds against the current code, and report any gaps without modifying production code.

## Files allowed to modify

Only modify these files:

- `docs/phase_1_5_audit.md` (append a fresh section for Task 6.2)

If another file is required, explain why before changing it.

## Files to inspect (read-only)

- `lib/views/routine/supplement_setup_screen.dart`

## Firestore paths

- `/users/{uid}/routine/current.templates.supplements`

## Requirements (verify each)

- confirm manual mode saves name, dosage, time, repeat
- flag if Text AI mode (Task 12.4) is still pending

## Events

Use these event names only if the existing event system supports them:

- `routine_template_created`

If no event system exists, report clearly instead of inventing one.

## Dependencies

Check whether these are implemented:

- Task 12.4

If dependencies are missing:
- explain what is missing
- implement only safe independent parts
- do not fake dependency behavior

## Verification

After implementation, run:

`flutter analyze`

Also verify:

- every Requirement above can be cited to file:line
- if a Requirement fails, document the gap and the follow-up Task that owns the fix
- no production Dart or JS file is modified
- the audit doc gains a new section, not a rewrite

## Final response format

Return:

1. Files inspected
2. Files changed
3. Summary of changes
4. Firestore paths affected
5. Events implemented or skipped
6. Analyzer result
7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 12.4

#### How to verify

- UI: re-walk the user paths declared in the source TODO entry; flag deviations.
- Firebase console: spot-check one document per Firestore path above.
- Logs: confirm the events listed (or document why they are absent).
- Edge cases: any item flagged as "Needs review" must be reproduced or explicitly closed.

#### Estimate

1h (audit only)


### Task 6.3 — Class manual setup polish

#### Status

- [x] Done (manual mode — May 2 2026).

---

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Re-verify Task 6.3 only. Do not implement. Read the listed files and Firestore paths, confirm each requirement still holds against the current code, and report any gaps without modifying production code.

## Files allowed to modify

Only modify these files:

- `docs/phase_1_5_audit.md` (append a fresh section for Task 6.3)

If another file is required, explain why before changing it.

## Files to inspect (read-only)

- `lib/views/routine/class_setup_screen.dart`

## Firestore paths

- `/users/{uid}/routine/current.templates.classes`

## Requirements (verify each)

- confirm manual mode saves subject, room, professor, weekday, start/end
- flag if Photo OCR mode (Task 12.5) is still pending

## Events

Use these event names only if the existing event system supports them:

- `routine_template_created`

If no event system exists, report clearly instead of inventing one.

## Dependencies

Check whether these are implemented:

- Task 12.5

If dependencies are missing:
- explain what is missing
- implement only safe independent parts
- do not fake dependency behavior

## Verification

After implementation, run:

`flutter analyze`

Also verify:

- every Requirement above can be cited to file:line
- if a Requirement fails, document the gap and the follow-up Task that owns the fix
- no production Dart or JS file is modified
- the audit doc gains a new section, not a rewrite

## Final response format

Return:

1. Files inspected
2. Files changed
3. Summary of changes
4. Firestore paths affected
5. Events implemented or skipped
6. Analyzer result
7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 12.5

#### How to verify

- UI: re-walk the user paths declared in the source TODO entry; flag deviations.
- Firebase console: spot-check one document per Firestore path above.
- Logs: confirm the events listed (or document why they are absent).
- Edge cases: any item flagged as "Needs review" must be reproduced or explicitly closed.

#### Estimate

1h (audit only)


### Task 6.4 — Eating manual setup polish

#### Status

- [x] Done (manual mode — May 2 2026).
- G1 fixed (May 5 2026): template `title` field now always stores `mealName` (was ambiguous — sometimes stored `foodName`). Fix in `eating_setup_screen.dart`.
- G2 fixed (May 5 2026): timeline meal block now shows user's meal name as title and `tlMealLabel()` (Breakfast/Lunch/etc.) as subtitle. Fix in `routine_tab.dart`.

---

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Re-verify Task 6.4 only. Do not implement. Read the listed files and Firestore paths, confirm each requirement still holds against the current code, and report any gaps without modifying production code.

## Files allowed to modify

Only modify these files:

- `docs/phase_1_5_audit.md` (append a fresh section for Task 6.4)

If another file is required, explain why before changing it.

## Files to inspect (read-only)

- `lib/views/routine/eating_setup_screen.dart`

## Firestore paths

- `/users/{uid}/routine/current.templates.eating`

## Requirements (verify each)

- confirm manual mode saves meal name, food, time, repeat
- flag if Mess Photo (Task 12.6) or AI Goal (Task 12.7) modes are still pending

## Events

Use these event names only if the existing event system supports them:

- `routine_template_created`

If no event system exists, report clearly instead of inventing one.

## Dependencies

Check whether these are implemented:

- Task 12.6
- Task 12.7

If dependencies are missing:
- explain what is missing
- implement only safe independent parts
- do not fake dependency behavior

## Verification

After implementation, run:

`flutter analyze`

Also verify:

- every Requirement above can be cited to file:line
- if a Requirement fails, document the gap and the follow-up Task that owns the fix
- no production Dart or JS file is modified
- the audit doc gains a new section, not a rewrite

## Final response format

Return:

1. Files inspected
2. Files changed
3. Summary of changes
4. Firestore paths affected
5. Events implemented or skipped
6. Analyzer result
7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 12.6
- Task 12.7

#### How to verify

- UI: re-walk the user paths declared in the source TODO entry; flag deviations.
- Firebase console: spot-check one document per Firestore path above.
- Logs: confirm the events listed (or document why they are absent).
- Edge cases: any item flagged as "Needs review" must be reproduced or explicitly closed.

#### Estimate

1h (audit only)


### Task 6.5 — Routine settings hub polish (NEW)

#### Status

- [ ] Not started
- Filter pill label fix resolved (May 5 2026): `GlassFilterDropdown` now shows active filter name (e.g., "Eating", "All") instead of hardcoded "Filter". Fix in `glass_filter_dropdown.dart` — `LiquidGlassPill` label is now dynamic from `filterMetaData[widget.selected]!.label`.

#### Why

`routine_settings_screen.dart` and `routine_settings_sheet.dart` should expose every routine type with a uniform row: icon, title, subtitle (count or "Not set up yet"), chevron. Empty states guide the user to setup.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Polish the routine settings hub so every routine type — fixed schedule, skin care, supplement, classes, eating — is reachable in 2 taps from Profile and from Routine tab gear.

## Files allowed to modify

Only modify these files:

- `lib/views/routine/routine_settings_sheet.dart`
- `lib/views/tabs/routine_settings_screen.dart`
- `lib/views/tabs/profile_tab.dart`
- `lib/core/router/app_router.dart`

## Requirements

- Each routine type row shows: icon, name, count of templates or "Not set up yet", chevron.
- Tap routes to the corresponding setup screen.
- Each setup screen, when reached from Settings, lacks "Skip" / "Continue" CTAs (those are onboarding-only).

## Verification

UI: Profile → Routine settings → tap each row → corresponding setup screen.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 6.1–6.4.

#### How to verify

- UI: all 5 rows reachable; counts visible.

#### Estimate

3h

#### Done Criteria

- [ ] All 5 routine types listed.
- [ ] Counts shown.
- [ ] Routes work from Profile and from Routine tab.

---

## Phase 7 — Habit, Tracker Variants, Tracker Home

### Task 7.1 — Habit lifecycle service (carry-over)

#### Status

- [x] Done (May 3 2026).

---

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Re-verify Task 7.1 only. Do not implement. Read the listed files and Firestore paths, confirm each requirement still holds against the current code, and report any gaps without modifying production code.

## Files allowed to modify

Only modify these files:

- `docs/phase_1_5_audit.md` (append a fresh section for Task 7.1)

If another file is required, explain why before changing it.

## Files to inspect (read-only)

- `lib/services/habit_service.dart`
- `lib/models/habit_model.dart`
- `lib/models/habit_log_model.dart`
- `test/services/habit_service_contract_test.dart`

## Firestore paths

- `/users/{uid}/habits/{habitId}`
- `/users/{uid}/habit_logs/{logId}`

## Requirements (verify each)

- confirm createHabit, updateHabit, pauseHabit, resumeHabit, archiveHabit, deleteHabit, logGood, logSlip, deleteLog all exist
- confirm canonical log path is /habit_logs/{logId} (flat)
- confirm validation rejects blank name, invalid target, negative log
- confirm lifecycle events emit per action

## Events

Use these event names only if the existing event system supports them:

- `habit_created`
- `habit_updated`
- `habit_paused`
- `habit_resumed`
- `habit_archived`
- `habit_deleted`
- `good_habit_logged`
- `bad_habit_slip_logged`
- `habit_log_deleted`
- `slip_streak_detected`

If no event system exists, report clearly instead of inventing one.

## Dependencies

Check whether these are implemented:

- (no follow-ups required by this re-verify.)

If dependencies are missing:
- explain what is missing
- implement only safe independent parts
- do not fake dependency behavior

## Verification

After implementation, run:

`flutter analyze`

Also verify:

- every Requirement above can be cited to file:line
- if a Requirement fails, document the gap and the follow-up Task that owns the fix
- no production Dart or JS file is modified
- the audit doc gains a new section, not a rewrite

## Final response format

Return:

1. Files inspected
2. Files changed
3. Summary of changes
4. Firestore paths affected
5. Events implemented or skipped
6. Analyzer result
7. Remaining risks or missing dependencies
```

#### Dependencies

- None (re-verify only)

#### How to verify

- UI: re-walk the user paths declared in the source TODO entry; flag deviations.
- Firebase console: spot-check one document per Firestore path above.
- Logs: confirm the events listed (or document why they are absent).
- Edge cases: any item flagged as "Needs review" must be reproduced or explicitly closed.

#### Estimate

1h (audit only)


### Task 7.2 — Habit editor / detail / quick-log (carry-over)

#### Status

- [x] Done (May 3 2026).

---

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Re-verify Task 7.2 only. Do not implement. Read the listed files and Firestore paths, confirm each requirement still holds against the current code, and report any gaps without modifying production code.

## Files allowed to modify

Only modify these files:

- `docs/phase_1_5_audit.md` (append a fresh section for Task 7.2)

If another file is required, explain why before changing it.

## Files to inspect (read-only)

- `lib/views/tabs/home_tab.dart`
- `lib/views/tabs/tracker_tab.dart`
- `lib/views/habits/log_habit_sheet.dart`
- `lib/views/habits/habit_editor_screen.dart`
- `lib/views/habits/habit_detail_screen.dart`

## Firestore paths

- `/users/{uid}/habit_logs/{logId}`
- `/users/{uid}/habits/{habitId}`

## Requirements (verify each)

- confirm Home pills, log sheets, editor, detail all render
- confirm undo latest works
- flag if 10 tracker variants (Tasks 7.4-7.13) need real per-variant work

## Events

Use these event names only if the existing event system supports them:

- `good_habit_logged`
- `bad_habit_slip_logged`
- `habit_log_deleted`
- `habit_created`
- `habit_updated`
- `habit_paused`
- `habit_resumed`
- `habit_archived`

If no event system exists, report clearly instead of inventing one.

## Dependencies

Check whether these are implemented:

- Task 7.3
- Task 7.4
- Task 7.5
- Task 7.6
- Task 7.7
- Task 7.8
- Task 7.9
- Task 7.10
- Task 7.11
- Task 7.12
- Task 7.13

If dependencies are missing:
- explain what is missing
- implement only safe independent parts
- do not fake dependency behavior

## Verification

After implementation, run:

`flutter analyze`

Also verify:

- every Requirement above can be cited to file:line
- if a Requirement fails, document the gap and the follow-up Task that owns the fix
- no production Dart or JS file is modified
- the audit doc gains a new section, not a rewrite

## Final response format

Return:

1. Files inspected
2. Files changed
3. Summary of changes
4. Firestore paths affected
5. Events implemented or skipped
6. Analyzer result
7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 7.3
- Task 7.4
- Task 7.5
- Task 7.6
- Task 7.7
- Task 7.8
- Task 7.9
- Task 7.10
- Task 7.11
- Task 7.12
- Task 7.13

#### How to verify

- UI: re-walk the user paths declared in the source TODO entry; flag deviations.
- Firebase console: spot-check one document per Firestore path above.
- Logs: confirm the events listed (or document why they are absent).
- Edge cases: any item flagged as "Needs review" must be reproduced or explicitly closed.

#### Estimate

1h (audit only)


### Task 7.3 — Tracker home with AI insight surface (NEW)

#### Status

- [ ] Not started

#### Why

Tracker home (`tracker_tab.dart`) lists cards but does not yet show the User Flow §8.1 layout: mission ring (compact), good-habit carousel, bad-habit carousel, phone-behavior card, weekly trend strip, AI insight card.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Refactor `tracker_tab.dart` to match User Flow §8.1 with: header (Today/Week/Month + filter), compact mission ring, good-habit carousel, bad-habit carousel, phone-behavior card (Android only), weekly trend strip, AI insight card.

## Files allowed to modify

Only modify these files:

- `lib/views/tabs/tracker_tab.dart`
- `lib/widgets/` (new shared widgets if needed; declare them in plan)

## Firestore paths

- read `/users/{uid}/habits`, `/habit_logs`, `/streaks`, `/dailySummaries`, `/suggestions` (filter by `targetSurface='tracker'`)

## Requirements

- Today/Week/Month toggle re-binds card numbers.
- Filter chip: All / Good / Bad / Phone (horizontally scrollable).
- AI insight card only renders when a `pending` `suggestions` doc with `targetSurface='tracker'` exists.
- Loading: shimmer placeholders.
- Offline: cached data + "Synced X min ago" footer.
- Empty: glass card prompting habit picker.

## Events

- `suggestion_dismissed` (when user dismisses insight card)

## Dependencies

- Tasks 7.1, 7.2.

## Verification

UI: open Tracker → see all sections. Toggle Today/Week/Month. Filter pills.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 7.1, 7.2.

#### How to verify

- UI: every section renders.
- Empty/loading/offline states.
- Insight card disappears after dismiss.

#### Estimate

1 day

#### Done Criteria

- [ ] Layout matches doc.
- [ ] AI insight card wires to suggestions.
- [ ] Loading + offline states.

---

### Task 7.4 — Smoking tracker variant (NEW — Problem 10)

#### Status

- [ ] Not started

#### Why

Smoking is a flagship recovery use case (Nairit persona). Stub at `lib/views/habits/variants/smoking_tracker_view.dart` (~40 lines) must become the real screen: trigger picker, money-saved card, days-clean counter, health-milestone unlocks, recovery alarms, Talk-to-coach CTA.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Build the full smoking tracker detail screen per User Flow §8.4.1.

## Files allowed to modify

Only modify these files:

- `lib/views/habits/variants/smoking_tracker_view.dart`
- `lib/views/habits/variants/tracker_variant_base.dart` (extend only — no breaking change)
- `lib/services/habit_service.dart` (only if a slip-with-trigger method is missing)
- `lib/models/habit_log_model.dart` (only if a `triggerTag` field is missing)

## Firestore paths

- `/users/{uid}/habits/{cigarettes}` (or wherever the smoking habit lives)
- `/users/{uid}/habit_logs/{logId}`
- `/users/{uid}/streaks/{habitId}`
- `/users/{uid}/scheduled_notifications/{id}` for recovery alarms

## Requirements

- Hero: today's count + baseline + money saved + days clean.
- Log slip button (gentle gray, never red).
- Trigger picker (optional skip): Stress · Boredom · Social · After meal · Craving · Other.
- Today's log with trigger tags.
- 7×24 trigger heatmap.
- Weekly chart bars going down.
- Health milestones (20m, 12h, 24h, 72h, 1w, 2w, 1m, 1y) auto-unlocked by days clean.
- Recovery-alarms section: schedule pre-emptive nudges 5 min before high-risk slot.
- Talk-to-coach button.
- During relapse week (today > baseline): hide money-saved.

## Events

- `bad_habit_slip_logged` (with trigger_tag).
- `slip_streak_detected` (3+ in 30 min).
- `notification_scheduled` for recovery alarms.

## AI

- Recovery-alarm rule reads trigger heatmap; this UI consumes the rule's output, not generates it.

## Dependencies

- Tasks 7.1, 7.2, 8.1 (streaks).

## Verification

UI: log slip → count increments, money pauses; pick stress trigger → heatmap updates. Health milestone unlocks at 1 day clean.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 7.1, 7.2, 8.1.

#### How to verify

- UI: full detail screen.
- Firebase console: `habit_logs` with `triggerTag`.
- Logs: events emitted; recovery alarms scheduled.

#### Estimate

1 day

#### Done Criteria

- [ ] Trigger picker works.
- [ ] Money-saved math correct.
- [ ] Heatmap renders.
- [ ] Health milestones unlock by days clean.
- [ ] Recovery alarms schedule.

---

### Task 7.5 — Screen time / doom-scrolling tracker variant (NEW)

#### Status

- [ ] Not started

#### Why

Stub exists. Real version needs: Android UsageStats import, top-apps breakdown, hourly distribution, per-app cap, cap-violation flow, unlock-without-action heuristic.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Build the screen-time tracker per User Flow §8.4.2.

## Files allowed to modify

Only modify these files:

- `lib/views/habits/variants/screen_time_tracker_view.dart`
- `lib/services/screen_time_bridge.dart`
- `lib/services/screen_time_importer.dart`
- `lib/models/screen_time_log_model.dart`

## Firestore paths

- `/users/{uid}/screenTimeRaw/{date}` (raw snapshot)
- `/users/{uid}/habit_logs/{logId}` (slips when caps crossed)

## Requirements

- Android only: UsageStatsManager auto-pull every 30 min foreground + once at day-close.
- Hero: today's screen time + comparison bar.
- Top 5 apps with time + per-app unlock count.
- Total unlocks today.
- Hourly distribution chart.
- "Apps marked as drains" with editable per-app caps.
- Cap-violation flow: first crossing → push + Lock 1 hr / Dismiss; second crossing → Coach conversation prompt.
- Unlock-without-action heuristic flag (>80/day).
- Optivus does NOT hard-block apps.

## Events

- `screen_time_synced` (background import).
- `bad_habit_slip_logged` (one per app per day max).

## AI

- Pattern correlation logic lives in rule engine; this view shows what the rule produces.

## Dependencies

- Tasks 7.1, 7.2.

## Verification

Android emulator with permission: snap of usage data → hero updates.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 7.1, 7.2.

#### How to verify

- UI: full layout.
- Android: import works end-to-end.
- Cap crossing fires once per day.

#### Estimate

1 day

#### Done Criteria

- [ ] Android import (UsageStatsManager) working end-to-end.
- [ ] Cap crossing flow.
- [ ] Unlock heuristic.

---

### Task 7.6 — Junk food / Mindful eating swap (NEW — eating-disorder safety)

#### Status

- [ ] Not started

#### Why

User Flow §8.4.3: if `eatingDisorderHistory=true` from About You, the junk-food tracker is silently replaced with Mindful Eating (no counts, no goals, no streaks). Currently the swap does not exist.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Implement the Junk Food → Mindful Eating swap based on `profile/main.sensitiveContext.eatingDisorderHistory`.

## Files allowed to modify

Only modify these files:

- `lib/views/habits/variants/mindful_eating_tracker_view.dart`
- `lib/views/tabs/tracker_tab.dart` (route swap)
- `lib/providers/onboarding_provider.dart` (read flag if needed)

## Firestore paths

- read `/users/{uid}/profile/main.sensitiveContext.eatingDisorderHistory`
- write `/users/{uid}/habit_logs/{logId}` (mindful eating: just `mealMood` slider + note)

## Requirements

- If flag true: route junk-food taps to Mindful Eating view (slider 1–10 "rushed/stressed → nourishing/calm" + optional note).
- Mindful Eating: no counts, no goals, no streaks, no money-saved.
- Toggling flag OFF requires friction confirmation (per UF §10.6).
- Junk Food default view (when flag false): emoji quick-add chips, trigger picker, photo log, cost tracker.
- Photos local only + Firestore-private; never shared.

## Events

- `good_habit_logged` (mindful eating mood snap).
- `bad_habit_slip_logged` (junk food slip).

## Dependencies

- Tasks 7.1, 7.2, 1.2.

## Verification

Toggle flag → tap junk food → swap UI. Confirm no calorie display anywhere.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 7.1, 7.2, 1.2.

#### How to verify

- UI: swap works on flag.
- No calorie field anywhere when flag set.
- Friction modal on toggle off.

#### Estimate

4h

#### Done Criteria

- [ ] Swap logic.
- [ ] Mindful Eating view.
- [ ] Junk Food view.
- [ ] Friction confirmation.

---

### Task 7.7 — Procrastination tracker + auto-detect listener (NEW)

#### Status

- [ ] Not started

#### Why

User Flow §8.4.4: manual log + auto-detect from `task_started` drift > 30m and `task_abandoned` reason `auto_no_start`.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Build the procrastination tracker + the auto-detect listener.

## Files allowed to modify

Only modify these files:

- `lib/views/habits/variants/procrastination_tracker_view.dart`
- `lib/services/habit_service.dart` (only to add procrastination auto-detect)
- `lib/core/event_orchestrator.dart` (only to register listener)

## Firestore paths

- `/users/{uid}/habit_logs/{logId}` (procrastination habit)

## Requirements

- Manual log path: pick task / "what did you do instead" / how long avoided.
- Auto-detect path: subscribe to `task_started` (drift > 30m) and `task_abandoned` (reason `auto_no_start`); emit `bad_habit_slip_logged` with `trigger_tag='late_start'` or `'no_show'` and `related_task_id`.
- Auto-logs are dismissable; dismissal emits `slip_log_dismissed`.
- Hero: today's lost minutes.
- Mixed log (manual + auto, chronological).
- Task-type heatmap, time-of-day heatmap, identity-damage view.
- Anti-shame header copy: "Procrastination is information, not failure."

## Events

- `bad_habit_slip_logged` (auto + manual).
- `slip_log_dismissed`.

## Dependencies

- Tasks 7.1, 7.2, 2.3 (validator includes `slip_log_dismissed`).

## Verification

Auto-log: task scheduled 9am, started 9:35am → procrastination log appears. User dismisses → log goes; dismissal event recorded.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 7.1, 7.2, 2.3.

#### How to verify

- Auto-detect works for both paths.
- Dismissal emits event.
- Heatmaps render.

#### Estimate

1 day

#### Done Criteria

- [ ] Manual + auto paths.
- [ ] Heatmaps.
- [ ] Anti-shame copy.

---

### Task 7.8 — Hydration tracker (NEW)

#### Status

- [ ] Not started

#### Why

Stub exists; needs container presets, hourly distribution, weight-based auto-target, smart reminders, heat-day boost.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Build hydration tracker per UF §8.4.5.

## Files allowed to modify

Only modify these files:

- `lib/views/habits/variants/hydration_tracker_view.dart`

## Firestore paths

- `/users/{uid}/habit_logs/{logId}` (good habit logs).
- read `/users/{uid}/profile/main.biometrics.weightKg` for auto-target.

## Requirements

- Auto-target: `weight_kg × 35 ml`, editable.
- Quick-log: +250 ml · +500 ml · +1 L · Custom · saved containers ("My 750ml bottle").
- Hourly distribution chart.
- Smart reminders: front-load detection.
- Heat boost: weather hook (location permission); +500 ml on >35°C.

## Events

- `good_habit_logged` with `unit='ml'`.

## Dependencies

- Tasks 7.1, 7.2.

## Verification

Log 500 ml → ring fills. Save container preset → tap to log instantly.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 7.1, 7.2.

#### How to verify

- Auto-target reflects weight.
- Custom container saved + tappable.

#### Estimate

4h

#### Done Criteria

- [ ] Quick-log row.
- [ ] Custom containers.
- [ ] Hourly chart.

---

### Task 7.9 — Meditation tracker + timer (NEW — Problem 10)

#### Status

- [ ] Not started

#### Why

Stub exists; UF §8.4.6: built-in timer overlay, optional pre/post mood check-in, lifetime totals, type breakdown.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Build meditation tracker + full-screen timer.

## Files allowed to modify

Only modify these files:

- `lib/views/habits/variants/meditation_tracker_view.dart`
- `lib/views/habits/variants/meditation_timer_screen.dart` (new)

## Firestore paths

- `/users/{uid}/habit_logs/{logId}` with `durationSec`, `type`, `moodBefore`, `moodAfter`.

## Requirements

- Animated breathing orb.
- Bell at start/end + optional 1/5/10-min bells.
- Background sound options.
- Pause/resume + Mark complete + auto-complete.
- Optional pre/post mood sliders → AI computes "meditation lift".
- Hero: today's minutes + streak.
- Lifetime total + milestone badges (10h, 50h, 100h, 365h).
- Type breakdown chart.
- No goal pressure on length.

## Events

- `good_habit_logged` (meditation completion event).

## Dependencies

- Tasks 7.1, 7.2.

## Verification

Open timer → 90s → mark complete → log appears. Mood lift computed.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 7.1, 7.2.

#### How to verify

- Timer overlay works.
- Pre/post mood sliders save deltas.
- Lifetime totals roll up.

#### Estimate

1 day

#### Done Criteria

- [ ] Timer.
- [ ] Mood lift.
- [ ] Lifetime total.

---

### Task 7.10 — Money saving aggregator (NEW)

#### Status

- [ ] Not started

#### Why

UF §8.4.7: passive (auto from quit habits) + active (manual deposits). Money tracker view + sources breakdown + savings goals + reflective card. Relapse-pause hides counter.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Build money-saving tracker aggregator.

## Files allowed to modify

Only modify these files:

- `lib/views/habits/variants/money_saving_tracker_view.dart`
- `lib/services/habit_service.dart` (add aggregator helper if missing)

## Firestore paths

- `/users/{uid}/habits` (read: cost_per_unit, baseline_per_day)
- `/users/{uid}/habit_logs` (read: slips)
- `/users/{uid}/money_saved/{date}` (write: daily aggregate)
- `/users/{uid}/money_savings_goals/{goalId}` (active deposits + goals)

## Requirements

- Passive math: `daily_passive_saved(habit) = max(0, baseline - count_today) × cost_per_unit`.
- Active mode: + Log savings deposit (amount + reason).
- Sources breakdown: pie of cigarettes / junk / alcohol / manual.
- Savings goal ring with name/amount/emoji.
- Reflective card (weekly): "What your discipline bought you".
- Relapse pause: if today > baseline → hide counter for the day.

## Events

- (none new — derived from existing slip + good_habit events.)

## Dependencies

- Tasks 7.1, 7.2.

## Verification

Smoke: log slip → savings drops; if exceeds baseline → counter hides; deposit → goal ring fills.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 7.1, 7.2, 7.4.

#### How to verify

- Pie + ring + relapse-pause behaviour.

#### Estimate

4h

#### Done Criteria

- [ ] Passive math.
- [ ] Active mode.
- [ ] Goal ring.
- [ ] Relapse pause.

---

### Task 7.11 — Reading tracker (NEW)

#### Status

- [ ] Not started

#### Why

UF §8.4.8: 3 log modes (time / pages / books), Currently-reading shelf, Google Books lookup, session log.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Build reading tracker per UF §8.4.8.

## Files allowed to modify

Only modify these files:

- `lib/views/habits/variants/reading_tracker_view.dart`
- `lib/services/google_books_service.dart` (new)

## Firestore paths

- `/users/{uid}/books/{bookId}`
- `/users/{uid}/habit_logs/{logId}` (reading sessions)

## Requirements

- Log mode selector: time / pages / books.
- Add book: title + author → Google Books API → cover/pages/genre/blurb.
- Currently-reading shelf with progress bar.
- Session log: date / duration / pages / note.
- Yearly goal ring.
- Streak: any reading on a day counts.

## Events

- `good_habit_logged` (reading session).

## Dependencies

- Tasks 7.1, 7.2.

## Verification

Add a real book → cover fetched. Log session → shelf updates.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 7.1, 7.2.

#### How to verify

- Lookup works.
- Session log persists.

#### Estimate

1 day

#### Done Criteria

- [ ] All 3 log modes.
- [ ] Book shelf.
- [ ] Yearly goal.

---

### Task 7.12.1 — Optivus Fitness Foundation inside Track tab (NEW — Problem 10)

#### Status

- [ ] Not started

#### Why

The old exercise tracker task is too narrow. Optivus needs its own Fitness Engine inside the existing Track tab, not a Strava dependency and not a separate bottom-nav tab.

This foundation task creates the domain model, Firestore contract, repository/provider layer, and first Track-tab fitness UI surfaces while preserving the current habit tracker behavior.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules. If that file is absent, use root `GEMINI.md`.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Build Phase 1 of the Optivus-native Fitness Engine inside the existing Track tab.

Do not depend on Strava or any external fitness app for the core experience.

## Must inspect before editing

- Existing Flutter project structure
- Existing routing/navigation
- Existing Riverpod providers
- Existing models/repositories/services
- Existing Firebase paths
- Existing event system
- Existing AI coach system
- Existing Track tab, Routine tab, Home dashboard, Settings, and Analytics screens

## Scope

- Add a Fitness section/entry point inside `TrackerTab`.
- Add Fitness dashboard UI inside Fitness Tracking section.
- Add Activity Selection UI.
- Add Activity Pre-Start UI.
- Create/extend models only if similar models do not already exist.
- Create Firestore schema constants if the project has a schema/constants pattern.
- Create repository and Riverpod providers using existing project conventions.
- Preserve existing habit tracker cards, logs, streaks, and Track tab behavior.

## UI screens

- `FitnessDashboardScreen`
- `ActivitySelectionScreen`
- `ActivityPreStartScreen`
- Permission state UI for pre-start flows

## Models

- `FitnessActivityModel`
- `RoutePointModel`
- `ActivitySplitModel`
- `HeartRateSampleModel`
- `FitnessStatsModel`
- `FitnessGoalModel`
- `LiveActivityMetricsModel`
- `FitnessPermissionStateModel`
- `FitnessActivityType`
- `FitnessActivityStatus`

Models must include safe `fromMap`, `toMap`, `copyWith`, null-safe Timestamp conversion, defaults, and backward compatibility for old/missing fields.

## Providers / repository

- `fitnessActivityRepositoryProvider`
- `activityHistoryProvider`
- `activityDetailProvider`
- `fitnessStatsProvider`
- `fitnessGoalsProvider`
- `fitnessPermissionProvider`
- `FitnessActivityRepository`

Repository methods required in this foundation:

- `createActivity`
- `updateActivity`
- `watchActivity`
- `watchActivityHistory`
- `deleteActivity`

## Firestore paths

- `/users/{uid}/fitnessActivities/{activityId}`
- `/users/{uid}/fitnessActivities/{activityId}/routePoints/{pointId}`
- `/users/{uid}/fitnessActivities/{activityId}/splits/{splitId}`
- `/users/{uid}/fitnessActivities/{activityId}/heartRateSamples/{sampleId}`
- `/users/{uid}/fitnessStats/daily_{dateKey}`
- `/users/{uid}/fitnessStats/weekly_{weekKey}`
- `/users/{uid}/fitnessStats/monthly_{monthKey}`
- `/users/{uid}/fitnessGoals/{goalId}`

## Requirements

- Track tab shows Fitness card/section with Start Activity.
- Quick start buttons: Run, Walk, Cycle, Hike, Gym, Swim.
- Activity selection supports running, walking, cycling, hiking, swimming, gym/workout, custom.
- Pre-start screen shows selected type, Start, Back, Settings, permissions, GPS status where applicable, goal/target inputs, and notes.
- GPS activities are running, walking, cycling, hiking, and open-water swimming when available.
- Pool swimming and gym/workout do not require a map.
- UI must use the existing Liquid UI / Optivus design language.
- All async screens must handle loading, error, empty, permission denied, and offline states.

## Events

Add event names to the central constants/validator only when implementation needs them:

- `fitness_activity_started`
- `fitness_activity_cancelled`
- `fitness_activity_discarded`

## Dependencies

- Existing Track tab and routing.
- Existing Auth, Firestore, Riverpod, event, and AI coach services.

## Verification

- `flutter pub get`
- `flutter analyze`
- `flutter test` if relevant tests exist
- Manual: Open Track tab, see Fitness section, tap Start Activity, choose activity, land on pre-start.
```

#### Dependencies

- Tasks 7.1, 7.2.

#### How to verify

- Track tab still loads existing habit tracker content.
- Fitness entry appears inside Track tab.
- Activity selection and pre-start flows work without duplicate models/providers.

#### Estimate

2 days

#### Done Criteria

- [ ] Fitness entry exists inside Track tab.
- [ ] Dashboard, selection, and pre-start screens exist.
- [ ] Foundation models/repository/providers exist or existing equivalents are extended.
- [ ] Firestore schema plan is reflected in code constants/models.
- [ ] Existing Track habit behavior is preserved.

---

### Task 7.12.2 — Live Activity Tracking, GPS, Map, and Controls

#### Status

- [ ] Not started

#### Why

Optivus must own the live tracking experience for running, walking, cycling, hiking, and optional open-water swimming. Users must see live distance, pace/speed, time, calories, GPS status, current location, and a route line while tracking.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules. If that file is absent, use root `GEMINI.md`.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Build live activity tracking, GPS, map, metrics, and controls for the Optivus Fitness Engine inside Track tab.

## Scope

- Add location permission handling.
- Add foreground GPS tracking.
- Add background-safe active activity state if supported by platform setup.
- Add live timer, moving time, paused time.
- Add live distance, speed, pace, calories.
- Add Start / Pause / Resume / Finish / Cancel controls.
- Add live route point capture and route filtering.
- Add live map with current location marker and route polyline.
- Add map controls: recenter, follow mode, zoom, map type toggle, lock controls, collapse metrics.

## Services/controllers

- `LocationTrackingService`
- `FitnessMapController`
- `FitnessMetricsCalculator`
- `FitnessRouteService` basics for filtering/bounds
- `activeActivityControllerProvider`
- `liveActivityMetricsProvider`
- `locationTrackingServiceProvider`
- `fitnessMapControllerProvider`

## UI screens/sheets

- `LiveActivityTrackingScreen`
- `ActivityPauseBottomSheet`
- `FinishActivityConfirmationSheet`
- Permission-required state UI

## Firestore writes

- Create active activity at `/users/{uid}/fitnessActivities/{activityId}`.
- Save route points under `/routePoints/{pointId}`.
- Do not store unlimited GPS points inside the activity document.
- Route points must be ordered by `sequence`.
- Use batching where safe.
- Mark `syncStatus` as `synced`, `pending`, or `failed`.

## GPS filtering

Ignore points when:

- accuracy is too poor
- jump is unrealistic
- timestamp is invalid
- user is paused
- movement is too tiny to be useful

## Events

- `fitness_activity_started`
- `fitness_activity_paused`
- `fitness_activity_resumed`
- `fitness_activity_cancelled`
- `fitness_activity_discarded`
- `route_tracking_started`
- `route_tracking_stopped`

## Privacy rules

- Never track silently.
- Only track after user taps Start.
- Stop immediately after Finish or Cancel.
- Show visible tracking-active UI.
- Handle permission denied, permanently denied, GPS disabled, weak GPS, no internet, app background, phone lock where supported.

## Verification

- `flutter pub get`
- `flutter analyze`
- `flutter test` if relevant tests exist
- Manual: Start Running, see timer, distance, pace, map, marker, live polyline, pause, resume, finish confirmation, cancel/discard.
```

#### Dependencies

- Task 7.12.1.
- Map/location packages chosen after inspecting existing platform setup.

#### How to verify

- GPS activity starts only after user action.
- Live route line updates.
- Pause stops moving time and distance accumulation.
- Finish/cancel stops tracking.

#### Estimate

3 days

#### Done Criteria

- [ ] Live tracking works for running/walking/cycling/hiking.
- [ ] Map controls work during tracking.
- [ ] Route points are saved to subcollection.
- [ ] Bad GPS points are filtered.
- [ ] Permission and GPS edge states are handled.

---

### Task 7.12.3 — Activity Completion, Summary, History, Route Review, Swim, and Gym

#### Status

- [ ] Not started

#### Why

Users must be able to finish an activity, review the saved route and stats, reopen old activities, and use non-GPS flows for pool swimming and gym/workout.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules. If that file is absent, use root `GEMINI.md`.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Build the saved activity experience for the Optivus Fitness Engine.

## Scope

- Finish and save activity.
- Calculate final stats.
- Generate splits where applicable.
- Save notes/manual fields.
- Show post-activity summary.
- Show saved route review from Firestore route points.
- Show activity history and detail.
- Support pool swimming without GPS by default.
- Support open-water swimming with optional route data.
- Support gym/workout without map.

## UI screens

- `ActivitySummaryScreen`
- `ActivityRouteReviewScreen`
- `ActivityHistoryScreen`
- `ActivityDetailScreen`

## Swimming

- Pool swimming: timer, pool length, laps, manual distance, calories, heart rate optional, notes.
- Open-water swimming: GPS optional; allow manual distance when no route is available.
- Do not assume GPS works underwater.

## Gym / workout

- Timer, pause/resume/finish.
- Workout category.
- Optional exercises, sets, reps, weight later.
- Calories estimate.
- Heart rate optional.
- Notes and AI feedback slot.

## Route review

- Use saved `/routePoints`.
- Show full polyline, start marker, finish marker, split markers.
- Allow zoom, pan, recenter full route, map type toggle.
- Must not require an active tracking session.
- Old activities must reopen safely.

## Repository methods

- `completeActivity`
- `cancelActivity`
- `saveRoutePoint`
- `saveRoutePointsBatch`
- `watchRoutePoints`
- `saveSplits`
- `saveHeartRateSamples`

## Events

- `fitness_activity_completed`
- `running_activity_completed`
- `walking_activity_completed`
- `cycling_activity_completed`
- `hiking_activity_completed`
- `swimming_activity_completed`
- `gym_activity_completed`
- `route_saved`
- `route_review_opened`

## Verification

- `flutter analyze`
- `flutter test` if relevant tests exist
- Manual: Finish activity, see summary, open route review, open history, reopen old activity, view route from saved points.
```

#### Dependencies

- Tasks 7.12.1 and 7.12.2.

#### How to verify

- Finished GPS activity has route review.
- Pool swim can finish without route.
- Gym workout can finish without map.
- History and detail screens reopen saved activities.

#### Estimate

3 days

#### Done Criteria

- [ ] Summary screen supports GPS and non-GPS activities.
- [ ] History and detail screens exist.
- [ ] Saved route review uses Firestore route points.
- [ ] Swimming and gym flows are supported.
- [ ] Splits and notes are persisted where applicable.

---

### Task 7.12.4 — Stats, Goals, Routine, Events, AI, Backend, Rules, and Polish

#### Status

- [ ] Not started

#### Why

The Fitness Engine is not production-ready until it updates stats/goals/streaks/daily summaries, integrates Routine and AI Coach, emits validated events, has backend automation, has security rules, and handles offline/error cases.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules. If that file is absent, use root `GEMINI.md`.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Complete production integrations for the Optivus Fitness Engine.

## Scope

- Daily, weekly, monthly fitness stats.
- Fitness goals.
- Routine tab integration.
- Home dashboard fitness card integration if it fits existing architecture.
- AI Coach post-activity feedback.
- Streak and daily summary integration.
- Event system integration.
- Analytics surfaces.
- Firestore security rules.
- Cloud Functions automation.
- Offline queue/sync state.
- Error, empty, loading, permission, and map failure states.
- Tests and analyzer/build verification.

## UI screens

- `FitnessStatsScreen`
- `FitnessGoalsScreen`
- `FitnessSettingsScreen`

## Services

- `FitnessStatsService`
- `FitnessEventService`
- `FitnessAICoachService`
- `FitnessHealthConnectorService`
- `FitnessRouteService`

## Routine integration

- Add running, walking, cycling, hiking, swimming, and gym routine support.
- Routine item can start a Fitness activity.
- On finish, link `fitnessActivityId` back to the routine task/item.
- Mark routine item complete.
- Emit routine and fitness events.
- Update daily summary and streaks.

## AI Coach

After completion, request personalized feedback using:

- activity type
- distance
- duration
- pace/speed
- calories
- heart rate if available
- goals
- routine completion
- missed days
- streak state
- previous activities

Do not use user fitness data to train external models. Use it only for that user's coaching experience.

## Cloud Functions

- `onFitnessActivityCompleted`
- `onFitnessGoalUpdated`
- `scheduledFitnessWeeklySummary`
- `cleanupOrCompressRoutePoints` optional

Functions must be idempotent and avoid duplicate stats/events.

## Security rules

Add owner-only rules for:

- `/users/{uid}/fitnessActivities/{activityId}`
- `/users/{uid}/fitnessActivities/{activityId}/routePoints/{pointId}`
- `/users/{uid}/fitnessActivities/{activityId}/splits/{splitId}`
- `/users/{uid}/fitnessActivities/{activityId}/heartRateSamples/{sampleId}`
- `/users/{uid}/fitnessStats/{statId}`
- `/users/{uid}/fitnessGoals/{goalId}`

Protect aggregate stats if backend-managed.

## Events

- `fitness_goal_created`
- `fitness_goal_progress_updated`
- `fitness_goal_completed`
- `weekly_distance_goal_completed`
- `fitness_streak_updated`
- `fitness_ai_feedback_requested`
- `fitness_ai_feedback_generated`
- `routine_fitness_started`
- `routine_fitness_completed`

## Verification

- `flutter pub get`
- `flutter analyze`
- `flutter test` if tests exist
- Android debug build
- iOS build if available
- `npm test` in `functions/`
- Firebase emulator rules/function verification where possible
- Manual edge cases: denied permission, GPS off, no internet, pause/resume, cancel, duplicate finish, very short activity, no heart rate.
```

#### Dependencies

- Tasks 7.12.1, 7.12.2, and 7.12.3.

#### How to verify

- Stats update after completed activity.
- Goals progress updates.
- Routine-started fitness activity completes the routine item.
- AI feedback is requested/generated.
- Security rules cover all new paths.
- Offline and error states are visible.

#### Estimate

4 days

#### Done Criteria

- [ ] Stats/goals services and UI exist.
- [ ] Routine, streak, daily summary, analytics, event, and AI integrations exist.
- [ ] Cloud Functions are idempotent.
- [ ] Firestore rules secure all fitness paths.
- [ ] Offline/error/empty states are handled.

---

### Task 7.12 — Final build and confirmation: full Optivus Fitness Engine

#### Status

- [ ] Not started

#### Why

This is the final parent acceptance task for the complete Optivus Fitness Engine. Tasks 7.12.1, 7.12.2, 7.12.3, and 7.12.4 together cover the full requested scope: Track-tab fitness entry, activity selection, live GPS tracking, live map controls, saved route review, activity history/detail, swimming, gym/workout, stats, goals, routine, streaks, daily summary, events, AI Coach, backend automation, security rules, offline support, and verification.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules. If that file is absent, use root `GEMINI.md`.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Build and verify the full Optivus-native Fitness Engine by completing Tasks 7.12.1, 7.12.2, 7.12.3, and 7.12.4.

This parent task is complete only when the user can:

1. Open Optivus.
2. Go to the existing Track tab.
3. Tap Start Activity.
4. Select Running, Walking, Cycling, Hiking, Swimming, Gym/Workout, or Custom.
5. Start an activity.
6. See live map and route for GPS activities.
7. See timer, distance, pace/speed, calories, GPS status, and optional heart rate.
8. Pause, resume, finish, cancel, recenter, zoom, change map type, and control follow mode.
9. Save the activity.
10. See summary and route review.
11. Reopen old activities from history.
12. Use gym and pool swimming without GPS.
13. See stats/goals update.
14. Complete routine-linked fitness activities.
15. Receive AI Coach feedback.

## Confirmation

Confirm explicitly in the final response that Tasks 7.12.1-7.12.4 cover the full Optivus Fitness Engine requirement and that Task 7.12 is the final build/acceptance task.

## Final verification

- `flutter pub get`
- `flutter analyze`
- `flutter test` if tests exist
- Android debug build
- iOS build if available
- `npm test` in `functions/`
- Firebase emulator verification for functions/rules where possible
- Manual UI flow verification from Track tab through completed route review
- Firestore document verification for activities, route points, splits, daily stats, and weekly stats
- Event verification for fitness start, complete, route saved, streak updated, and AI feedback requested
```

#### Dependencies

- Task 7.12.1.
- Task 7.12.2.
- Task 7.12.3.
- Task 7.12.4.

#### How to verify

- Full user flow works from Track tab.
- GPS and non-GPS activities work.
- Saved route map reopens from history.
- Firestore data, events, stats, goals, routine, streak, and AI integrations work.
- Verification commands pass or remaining issues are explicitly documented.

#### Estimate

1 day final acceptance after 7.12.1-7.12.4 are implemented.

#### Done Criteria

- [ ] Tasks 7.12.1-7.12.4 are complete.
- [ ] Full Optivus Fitness Engine is implemented inside the existing Track tab.
- [ ] No Strava dependency is required for the core experience.
- [ ] Running, walking, cycling, hiking, swimming, gym/workout, and custom activities are supported.
- [ ] Live route map and saved route review work for GPS activities.
- [ ] Map controls work live and after activity.
- [ ] Stats, goals, routine, streak, daily summary, events, AI, backend, rules, and offline/error states are covered.
- [ ] Final verification results are reported.

---

### Task 7.13 — Routine completion meta-tracker (NEW)

#### Status

- [ ] Not started

#### Why

UF §8.4.10: tracker of the routine itself. Hero metric, block-by-block view, per-routine breakdown, drift heatmap, weekday patterns. Reads dailySummaries — no new logs.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Build routine completion meta-tracker.

## Files allowed to modify

Only modify these files:

- `lib/views/habits/variants/routine_completion_tracker_view.dart`

## Firestore paths

- read `/users/{uid}/dailySummaries/{date}`
- read `/users/{uid}/tasks` (today's blocks)

## Requirements

- Hero: today's completion %.
- Block-by-block scroll with status badges.
- Per-routine-type table (skin care, classes, eating, fixed schedule, custom).
- Drift heatmap (hour × weekday).
- Weekly view: 7-day rings.
- Weekday patterns text: "Mondays you average X%."

## Events

- (read-only.)

## Dependencies

- Tasks 3.5, 7.1.

## Verification

UI shows correct numbers. Heatmap reflects logs.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 3.5, 7.1.

#### How to verify

- Numbers match logs.

#### Estimate

4h

#### Done Criteria

- [ ] Hero.
- [ ] Per-routine breakdown.
- [ ] Heatmap.

---


## Phase 8 — Streaks, Accountability, Ghost / Comeback (gap-fill)

### Task 8.1 — Production streak rules (carry-over)

#### Status

- [x] Done (May 3 2026).
- [ ] Needs review: per-habit accountability override + 8+ day reset assertion (Task 8.3).

---

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Re-verify Task 8.1 only. Do not implement. Read the listed files and Firestore paths, confirm each requirement still holds against the current code, and report any gaps without modifying production code.

## Files allowed to modify

Only modify these files:

- `docs/phase_1_5_audit.md` (append a fresh section for Task 8.1)

If another file is required, explain why before changing it.

## Files to inspect (read-only)

- `lib/services/streak_service.dart`
- `lib/models/streak_model.dart`
- `test/services/streak_service_contract_test.dart`

## Firestore paths

- `/users/{uid}/streaks/{streakId}`
- `/users/{uid}/habit_logs/{logId}`
- `/users/{uid}/dailySummaries/{date}`

## Requirements (verify each)

- confirm good habit streaks, bad habit clean streaks, routine completion streaks all compute
- confirm milestones 3, 7, 14, 30, 60, 90, 180, 365
- confirm Forgiving / Strict / Ruthless modes
- flag if per-habit override + 8+ day reset (Task 8.3) is still pending

## Events

Use these event names only if the existing event system supports them:

- `streak_extended`
- `streak_broken`
- `streak_milestone_reached`
- `streak_paused`
- `streak_resumed`

If no event system exists, report clearly instead of inventing one.

## Dependencies

Check whether these are implemented:

- Task 8.3

If dependencies are missing:
- explain what is missing
- implement only safe independent parts
- do not fake dependency behavior

## Verification

After implementation, run:

`flutter analyze`

Also verify:

- every Requirement above can be cited to file:line
- if a Requirement fails, document the gap and the follow-up Task that owns the fix
- no production Dart or JS file is modified
- the audit doc gains a new section, not a rewrite

## Final response format

Return:

1. Files inspected
2. Files changed
3. Summary of changes
4. Firestore paths affected
5. Events implemented or skipped
6. Analyzer result
7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 8.3

#### How to verify

- UI: re-walk the user paths declared in the source TODO entry; flag deviations.
- Firebase console: spot-check one document per Firestore path above.
- Logs: confirm the events listed (or document why they are absent).
- Edge cases: any item flagged as "Needs review" must be reproduced or explicitly closed.

#### Estimate

1h (audit only)


### Task 8.2 — Streak detail + heatmap (carry-over)

#### Status

- [x] Done (May 3 2026).

---

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Re-verify Task 8.2 only. Do not implement. Read the listed files and Firestore paths, confirm each requirement still holds against the current code, and report any gaps without modifying production code.

## Files allowed to modify

Only modify these files:

- `docs/phase_1_5_audit.md` (append a fresh section for Task 8.2)

If another file is required, explain why before changing it.

## Files to inspect (read-only)

- `lib/views/streaks/streak_detail_screen.dart`
- `lib/views/streaks/streak_heatmap.dart`
- `lib/views/tabs/home_tab.dart`
- `lib/views/tabs/tracker_tab.dart`

## Firestore paths

- `/users/{uid}/streaks/{streakId}`
- `/users/{uid}/habit_logs/{logId}`
- `/users/{uid}/dailySummaries/{date}`

## Requirements (verify each)

- confirm Home streak card opens detail
- confirm Tracker habit detail links to streak detail
- confirm heatmap data matches logs

## Events

Use these event names only if the existing event system supports them:

- (read-only re-verification — emit nothing.)

If no event system exists, report clearly instead of inventing one.

## Dependencies

Check whether these are implemented:

- (no follow-ups required by this re-verify.)

If dependencies are missing:
- explain what is missing
- implement only safe independent parts
- do not fake dependency behavior

## Verification

After implementation, run:

`flutter analyze`

Also verify:

- every Requirement above can be cited to file:line
- if a Requirement fails, document the gap and the follow-up Task that owns the fix
- no production Dart or JS file is modified
- the audit doc gains a new section, not a rewrite

## Final response format

Return:

1. Files inspected
2. Files changed
3. Summary of changes
4. Firestore paths affected
5. Events implemented or skipped
6. Analyzer result
7. Remaining risks or missing dependencies
```

#### Dependencies

- None (re-verify only)

#### How to verify

- UI: re-walk the user paths declared in the source TODO entry; flag deviations.
- Firebase console: spot-check one document per Firestore path above.
- Logs: confirm the events listed (or document why they are absent).
- Edge cases: any item flagged as "Needs review" must be reproduced or explicitly closed.

#### Estimate

1h (audit only)


### Task 8.3 — Streak hardening: per-habit accountability + 8+ day reset (NEW)

#### Status

- [ ] Not started

#### Why

User Flow §8.3 + Event System §8.5: accountability mode can be set per-habit; ghost gap ≥ 8 days resets streak instead of resuming. The current service does not yet expose a per-habit override or test the reset path.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Add per-habit accountability override + 8+ day ghost reset path to StreakService.

## Files allowed to modify

Only modify these files:

- `lib/services/streak_service.dart`
- `lib/models/streak_model.dart`
- `lib/models/habit_model.dart` (only to add `accountabilityOverride` field if missing)
- `test/services/streak_service_contract_test.dart`

## Firestore paths

- `/users/{uid}/streaks/{habitId}`
- `/users/{uid}/habits/{habitId}.accountabilityOverride`

## Requirements

- Habit can declare its own accountability mode; if null → fall back to user-global mode.
- On `comeback_initiated`: if gap ≥ 8 days → `streak_broken` per habit; if 3 ≤ gap ≤ 7 days → `streak_resumed` restoring `pre_pause_count`.
- Forgiving mode `weeklySkipsUsed` ledger correct after pause/resume cycle.
- All tests cover Forgiving / Strict / Ruthless × resume / reset.

## Events

- `streak_paused` (already implemented).
- `streak_resumed` (verify on gap 3–7).
- `streak_broken` (verify on gap ≥ 8).

## Dependencies

- Task 5.3 (existing comeback flow).

## Verification

Test seeds: gap 4d → resumed; gap 8d → broken. Override flag lets one habit be Forgiving while user is Strict.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 5.3 (comeback).

#### How to verify

- Tests pass for all 3 accountability modes.
- Per-habit override works in UI (Profile → Accountability → "Override per-habit").

#### Estimate

4h

#### Done Criteria

- [ ] Override field works.
- [ ] 8+ day reset.
- [ ] All accountability modes tested.

---

### Task 8.4 — Comeback path event + tone-lock (NEW)

#### Status

- [ ] Not started

#### Why

Comeback modal exists but `comeback_path_chosen` event is missing from `event_names.dart`. Also, the 48-hour forced-Supportive coach tone is not enforced.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Add `comeback_path_chosen` event + 48h forced-supportive tone lock.

## Files allowed to modify

Only modify these files:

- `lib/core/constants/event_names.dart`
- `lib/services/event_payload_validator.dart`
- `lib/views/comeback/comeback_modal.dart`
- `lib/services/coach_service.dart` (read tone lock)
- `lib/services/state_aggregator_service.dart` (expose flag)

## Firestore paths

- `/users/{uid}/profile/main.toneLockUntil` (timestamp; 48h after `comeback_initiated`).

## Requirements

- Add `comebackPathChosen = 'comeback_path_chosen'` constant.
- Validator: payload `{path: 'easy'|'half'|'full', gapDays}`.
- On comeback modal pick → set `toneLockUntil = now + 48h`.
- Coach decision uses the tone lock to override style.

## Events

- `comeback_path_chosen`.

## Dependencies

- Task 2.3.

## Verification

Pick "Easy day" → 48h timestamp written; coach service reads lock.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 2.3.

#### How to verify

- Event in `events_recent`.
- Coach service reads tone lock.

#### Estimate

3h

#### Done Criteria

- [ ] Event constant + validator.
- [ ] Tone lock honoured.

---

## Phase 9 — Goals & Identity Profile (CRITICAL — fixes broken contract)

### Task 9.G1 — SPECIAL: Goal + Identity Profile schema support (REQUIRED)

#### Status

- [ ] Not started

#### Why

GoalRepository currently emits `identity_*` events for goal documents — semantically wrong because the identity profile is a separate doc at `/users/{uid}/identity_profile/main`. The StateAggregator must also gracefully ingest goals/habits/tasks for users who have none. This is the critical foundation for AI context (Phase 11).

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Implement Goal + Identity Profile schema support safely.

## Files allowed to modify

Only modify these files:

- `lib/models/goal_model.dart`
- `lib/models/identity_profile_model.dart`
- `lib/repositories/goal_repository.dart`
- `lib/providers/goal_provider.dart`
- `lib/providers/identity_provider.dart`
- `lib/services/state_aggregator_service.dart`

If another file is required, explain why before changing it.

## Firestore paths

Use these paths exactly:

- `/users/{uid}/goals/{goalId}`
- `/users/{uid}/identity_profile/main`
- `/users/{uid}/habits/{habitId}`
- `/users/{uid}/tasks/{taskId}`

## Goal fields

`GoalModel` must support:

- `goalId`
- `title`
- `identityTag`
- `why`
- `status`
- `weight`
- `progress`
- `targetDate`
- `milestones`
- `connectedHabitIds`
- `connectedRoutineTypes`
- `createdAt`
- `updatedAt`
- `archivedAt`

Requirements:

- Preserve existing fields and behavior.
- Add safe `fromMap`, `toMap`, and `copyWith`.
- Handle old Firestore docs with missing fields.
- Handle Firestore `Timestamp` and Dart `DateTime` safely.
- `progress` defaults to `0`.
- `weight` defaults to `1`.
- list fields default to empty lists.
- `targetDate` can be nullable.
- `archivedAt` can be nullable.

## Identity Profile

Update `identity_profile_model.dart` only if needed for goal/identity support.

Requirements:

- Preserve existing fields.
- Add missing fields safely.
- Support old Firestore docs.
- Update `fromMap`, `toMap`, and `copyWith` consistently.

## Repository behavior

Update `goal_repository.dart`.

Requirements:

- Use `/users/{uid}/goals/{goalId}`.
- Do not hardcode user IDs.
- Follow existing FirebaseAuth/Firestore pattern.
- Create goal should set `createdAt` and `updatedAt`.
- Update goal should set `updatedAt`.
- Archive goal should set:
  - `status = archived`
  - `archivedAt`
  - `updatedAt`
- Progress update should compare old progress and new progress.
- Emit `identity_progress_changed` ONLY when progress actually changes (real delta).
- Emit `milestone_completed` only when a milestone changes from incomplete to complete.
- Use existing event system if available.
- Do not invent a duplicate event system.
- Keep existing `identity_created/updated/paused/archived/habit_linked` event mapping intact for back-compat — but document in code that these refer to the goal-as-identity, not the identity profile doc.

## Providers

Update:

- `goal_provider.dart`
- `identity_provider.dart`

Requirements:

- Follow existing Riverpod style.
- Do not create duplicate providers.
- Preserve existing public APIs where possible.
- Add create/update/archive/progress methods only if consistent with existing pattern.
- Handle loading, error, and empty states.

## State Aggregator

Update `state_aggregator_service.dart`.

Requirements:

- Must handle users with no goals.
- Must not crash if any of these are missing:
  - identity profile
  - goals collection
  - habits collection
  - tasks collection
- Keep existing aggregator output backward compatible.
- Add goal/identity data only if safe and needed.

## Events

Support these event names only if existing event system supports them:

- `identity_created`
- `identity_updated`
- `identity_paused`
- `identity_archived`
- `identity_habit_linked`
- `identity_progress_changed`
- `milestone_completed`

Event payload should follow the existing event format. If no event system exists, report that clearly instead of inventing one.

## Dependencies

Check whether these are implemented:

- Task 3.5 (day-close)
- Task 4.1 (auth/onb base)
- Task 5.1 (streaks)
- Task 7.1 (habits)
- Task 8.1 (streaks)

If dependencies are missing:
- explain what is missing
- implement only safe independent parts
- do not fake dependency behavior

## Verification

After implementation, run:

`flutter analyze`

Also verify:

- goal documents match schema
- identity profile document matches schema
- aggregator handles no-goal users
- `identity_progress_changed` emits only when progress changes (no false-positive emissions when only `updatedAt` is touched)
- `milestone_completed` emits only on incomplete→complete transition
- old users/docs do not crash

## Final response format

Return:

1. Files inspected
2. Files changed
3. Summary of changes
4. Firestore paths affected
5. Events implemented or skipped
6. Analyzer result
7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 3.5, 4.1, 5.1, 7.1, 8.1.

#### How to verify

- UI: existing Goals tab (even shell) loads without error for a user with no goals.
- Firebase console: goal docs have full schema after create.
- Logs: `identity_progress_changed` emitted only on real delta.
- Edge cases: aggregator handles missing collections.

#### Estimate

1 day

#### Done Criteria

- [ ] GoalModel covers all 13 fields with safe defaults.
- [ ] Repository emits events on real change only.
- [ ] Aggregator no-crash on no-goal users.
- [ ] All listed deps verified.

---

### Task 9.2 — Goals home tab + identity grid

#### Status

- [ ] Not started

#### Why

UF §9.1: identity statement card, today's identity push, identity grid, milestones strip, AI insight card. Currently `goals_tab.dart` is a thin shell.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Build the Goals home tab per UF §9.1.

## Files allowed to modify

Only modify these files:

- `lib/views/tabs/goals_tab.dart`
- `lib/views/goals/identity_card.dart` (new)
- `lib/views/goals/today_identity_push_card.dart` (new)
- `lib/views/goals/milestones_strip.dart` (new)
- `lib/core/router/app_router.dart`

## Firestore paths

- read `/users/{uid}/goals`
- read `/users/{uid}/identity_profile/main`
- read `/users/{uid}/profile/main.identityStatement`
- read `/users/{uid}/suggestions` (filter `targetSurface='goals'`)

## Requirements

- Identity Statement card (top, glass plaque).
- Today's identity push card.
- Identity grid (2-col).
- Milestones strip.
- AI insight card (only if pending suggestion).
- Long-press identity → quick menu.

## Events

- (no writes — read-only home.)

## Dependencies

- Task 9.G1.

## Verification

UI: open Goals tab → all sections render. Empty user → empty state with "+ Add identity".

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 9.G1.

#### How to verify

- UI sections render.
- Empty state works.

#### Estimate

1 day

#### Done Criteria

- [ ] All sections per UF §9.1.
- [ ] Empty state.
- [ ] Long-press menu.

---

### Task 9.3 — Identity detail screen (Why-this-score)

#### Status

- [ ] Not started

#### Why

UF §9.2/9.3: hero progress arc, daily contributions, transparency layer, milestones, recent wins/slips.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Build identity detail screen per UF §9.2/9.3.

## Files allowed to modify

Only modify these files:

- `lib/views/goals/identity_detail_screen.dart` (new)
- `lib/views/goals/why_this_score_card.dart` (new)
- `lib/core/router/app_router.dart`

## Firestore paths

- `/users/{uid}/goals/{goalId}`
- `/users/{uid}/habits/{habitId}` (for contributors)
- `/users/{uid}/dailySummaries/{date}` (for wins/slips)

## Requirements

- 240px progress arc.
- "What feeds this identity" list with weights.
- Why-this-score expandable card (recomputed on every open).
- Milestones with checkboxes.
- Recent wins/slips 7-day timeline.
- Talk-to-coach button.
- Settings row: Connect habits / Adjust weights / Pause / Archive.

## Events

- `identity_progress_changed` (when weights edited if affects score).
- `milestone_completed` (manual mark).
- `identity_paused/archived`.

## Dependencies

- Task 9.G1, Task 7.1.

## Verification

Tap identity card → detail. Mark milestone → event emitted. Adjust weight → score updates.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 9.G1, 7.1.

#### How to verify

- All sections visible.
- Why-this-score recomputes per open.
- Weights editable.

#### Estimate

1 day

#### Done Criteria

- [ ] Hero arc.
- [ ] Why-this-score.
- [ ] Milestones.
- [ ] Settings row.

---

### Task 9.4 — Add identity / milestone editor (NEW)

#### Status

- [ ] Not started

#### Why

UF §9.4 / §9.6: identity picker (8 defaults + custom), quick-config screen, milestone editor sheet.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Build identity add + milestone editor flows.

## Files allowed to modify

Only modify these files:

- `lib/views/goals/identity_picker_sheet.dart` (new)
- `lib/views/goals/identity_editor_screen.dart` (new)
- `lib/views/goals/milestone_editor_sheet.dart` (new)

## Firestore paths

- `/users/{uid}/goals/{goalId}` (create / update + milestones)

## Requirements

- Picker: 8 defaults + Custom.
- Editor: name, emoji + color, one-sentence definition, suggested contributors, target end-date or Ongoing, initial milestone.
- Milestone editor: title, manual/auto, due date, completed.

## Events

- `identity_created`
- `identity_updated`
- `milestone_completed`

## Dependencies

- Task 9.G1.

## Verification

Add Custom identity → editor saves it. Add a milestone → list updates.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 9.G1.

#### How to verify

- Add identity flow.
- Milestone CRUD.

#### Estimate

4h

#### Done Criteria

- [ ] Picker.
- [ ] Editor.
- [ ] Milestone sheet.

---

### Task 9.5 — Pause / archive identity

#### Status

- [ ] Not started

#### Why

UF §9.5. Pause stops scoring/AI references; archive removes from active list. Both reversible.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Add pause/archive flows + Profile → Archived identities list.

## Files allowed to modify

Only modify these files:

- `lib/views/goals/identity_detail_screen.dart` (extend)
- `lib/views/settings/archived_identities_screen.dart` (new)
- `lib/repositories/goal_repository.dart` (already has pauseGoal/archiveGoal — verify wiring)

## Firestore paths

- `/users/{uid}/goals/{goalId}.status`

## Requirements

- Pause durations: 7 / 30 / 90 days / Until I unpause.
- Archive sends a final summary card (AI-generated copy stored in `goals/{goalId}.archiveSummary`).
- Archived list lives in Profile → Archived identities; reactivate restores.

## Events

- `identity_paused`
- `identity_archived`

## Dependencies

- Task 9.G1.

## Verification

Pause → identity disappears from grid; reactivate → returns. Archive → moves to archived list.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 9.G1.

#### How to verify

- Pause + reactivate.
- Archive + restore.

#### Estimate

3h

#### Done Criteria

- [ ] Pause durations.
- [ ] Archive flow.
- [ ] Reactivate path.

---

## Phase 10 — Notifications, Notification Center, Custom Alarms

### Task 10.1 — Notification lifecycle service hardening

#### Status

- [ ] Not started

#### Why

`notification_service.dart` schedules but lifecycle (recordSent/Tapped/Dismissed/Suppressed/Missed) and re-registration on app start need contract tests + dedupe.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Harden NotificationService lifecycle.

## Files allowed to modify

Only modify these files:

- `lib/services/notification_service.dart`
- `lib/models/scheduled_notification_model.dart`
- `lib/core/event_orchestrator.dart`
- `lib/main.dart` (re-register on app start)
- `test/services/notification_service_contract_test.dart`

## Firestore paths

- `/users/{uid}/scheduled_notifications/{id}`
- `/users/{uid}/notificationLog/{id}`
- `/users/{uid}/events_recent`

## Requirements

- Methods: requestPermissions, scheduleForTask, scheduleForRoutineTemplate, scheduleCustom, cancel, reRegisterAllOnAppStart, recordSent, recordTapped, recordDismissed, recordSuppressed, recordMissed.
- Dedupe by `(routineTemplateId, scheduledDate, scheduledTime, category)`.
- Re-register all pending on cold start.
- Lifecycle records persisted to `notificationLog`.
- Quiet hours + caps applied before fire.

## Events

- `notification_scheduled`
- `notification_sent`
- `notification_tapped`
- `notification_dismissed`
- `notification_suppressed`
- `notification_missed`

## Dependencies

- Tasks 2.1, 2.2, 3.2.

## Verification

Tests cover lifecycle. App restart re-registers.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 2.1, 2.2, 3.2.

#### How to verify

- Tests pass.
- Real device: schedule + restart + tap.

#### Estimate

1 day

#### Done Criteria

- [ ] All 11 methods.
- [ ] Re-register on start.
- [ ] Dedupe works.

---

### Task 10.2 — Notification center screen

#### Status

- [ ] Not started

#### Why

UF §10.5 / Home bell entry. Lists all notifications (sent/tapped/dismissed) with deep links.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Build notification center.

## Files allowed to modify

Only modify these files:

- `lib/views/notifications/notification_center_screen.dart` (new)
- `lib/views/tabs/home_tab.dart` (bell icon → route)
- `lib/core/router/app_router.dart`

## Firestore paths

- read `/users/{uid}/notificationLog`
- read `/users/{uid}/scheduled_notifications`

## Requirements

- Sections: Today / This week / Earlier.
- Each row: time, title, snippet, status badge, deep link.
- Mark all read.
- Filter: All / Unread / Coach / Tasks / Streaks.
- Empty state.

## Events

- `notification_tapped` (when row tapped to deep-link).

## Dependencies

- Task 10.1.

## Verification

Bell tap → screen → deep link works.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 10.1.

#### How to verify

- UI works; deep links fire.

#### Estimate

1 day

#### Done Criteria

- [ ] Center screen.
- [ ] Filters.
- [ ] Deep links.

---

### Task 10.3 — Notification settings screen

#### Status

- [ ] Not started

#### Why

UF §10.5 user controls.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Build notification settings.

## Files allowed to modify

Only modify these files:

- `lib/views/settings/notification_settings_screen.dart` (new)
- `lib/views/tabs/profile_tab.dart`
- `lib/core/router/app_router.dart`
- `lib/services/notification_service.dart` (read settings)

## Firestore paths

- `/users/{uid}/profile/main.notificationSettings`

## Requirements

- Daily budget slider 3–15.
- Per-category caps.
- Quiet days (today + scheduled).
- Blackout windows.
- Custom alarms list (with toggles).
- Sound picker.
- Vibration pattern.
- Test notification button.

## Events

- `notification_settings_changed`

## Dependencies

- Task 10.1.

## Verification

Toggle category off → no notifications of that type fire.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 10.1.

#### How to verify

- Settings persist.
- Test notification fires.

#### Estimate

1 day

#### Done Criteria

- [ ] Budget + caps.
- [ ] Quiet hours.
- [ ] Test notification.

---

### Task 10.4 — Custom alarm editor + ringing screen + snooze reason

#### Status

- [ ] Not started

#### Why

PRD §4.5 / UF §6: P1 alarms with custom sound, voice, vibration; ringing screen; snooze with reason.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Build custom alarm UX.

## Files allowed to modify

Only modify these files:

- `lib/views/alarms/alarm_editor_screen.dart` (new)
- `lib/views/alarms/alarm_ringing_screen.dart` (new)
- `lib/views/alarms/snooze_reason_sheet.dart` (new)
- `lib/views/routine/add_task_sheet.dart` (alarm opt-in toggle)
- `lib/views/routine/timeline_section.dart` (alarm chip on rows)
- `lib/services/notification_service.dart` (P1 path)

## Firestore paths

- `/users/{uid}/scheduled_notifications/{id}` (priority P1)
- `/users/{uid}/notificationLog/{id}` (snooze reason)

## Requirements

- Editor: sound picker, voice toggle, vibration pattern, snooze allowed durations.
- Ringing: full-screen, Start / Snooze (reason) / Skip (reason).
- Snooze sheet: tired / not feeling it / busy / other.
- Coach voice clip play on ring (use locally-cached samples).
- Skip + reason feeds AI context.

## Events

- `notification_sent` (on ring).
- `notification_tapped` / `notification_dismissed` (Start/Skip).
- `task_started` if Start tapped.

## Dependencies

- Tasks 10.1, 10.3.

## Verification

Schedule alarm 2 minutes ahead → simulate fire → ringing screen appears.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 10.1, 10.3.

#### How to verify

- Editor + ringing + snooze flow.

#### Estimate

1 day

#### Done Criteria

- [ ] Editor.
- [ ] Ringing.
- [ ] Snooze reason saved.

---

## Phase 11 — AI Coach, Rule Engine, Suggestions, Safety

### Task 11.1 — Move Gemini calls to Cloud Function

#### Status

- [x] Done (verified 2026-05-03 — `lib/services/gemini_service.dart` already calls `FirebaseFunctions.instance.httpsCallable('aiGenerate')`; `functions/index.js` exports `aiGenerate` with `secrets: [geminiApiKey]`; no Gemini key shipped in Flutter).
- [ ] Needs review: client-side safety pre-filter (Task 11.5) and per-user usage cap (Task 14.5) still pending.

#### Why

Flutter must never hold the Gemini API key (sysdesign §2.1). Move all Gemini calls behind a callable Cloud Function.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Migrate Gemini calls from Flutter to a callable Cloud Function `coachReply`.

## Files allowed to modify

Only modify these files:

- `lib/services/gemini_service.dart` (replace direct API call with HttpsCallable)
- `lib/services/coach_service.dart`
- `functions/index.js`
- `functions/ai/coachReply.js` (new)
- `functions/test/coachReply.contract.test.js`

## Firestore paths

- `/users/{uid}/coach_messages/{id}`
- `/users/{uid}/coach_speak_log/{id}`
- `/users/{uid}/ai_context_snapshots/{id}`

## Requirements

- Function inputs: `{userId, threadId, text, mode}`. Auth via Firebase Auth callable.
- Function reads context snapshot, calls Gemini with system prompt, validates JSON, returns text + suggested actions.
- Function writes to `coach_messages` (server-trusted source).
- No API key in Flutter.
- Crisis keywords routed before LLM (Phase 11.5).

## Events

- `coach_message_sent` (client-side on send).
- `coach_replied` (server-side on reply).

## Dependencies

- Task 9.G1 (snapshot has goals).

## Verification

Crashlytics: no Gemini key in client crash. Function tests cover happy path + safety rejection.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 9.G1.

#### How to verify

- Search Flutter source for Gemini key — must be absent.
- Function emulator returns reply.

#### Estimate

1 day

#### Done Criteria

- [ ] No keys in Flutter.
- [ ] Function returns reply.
- [ ] Tests cover schema validation.

---

### Task 11.2 — Coach chat UI + topic modes

#### Status

- [ ] Not started (verified 2026-05-03: `coach_service.dart` already writes to `/users/{uid}/coach_messages/{messageId}` at line 196 and `/users/{uid}/coach_speak_log/{logId}` at line 220 — wiring is real, but topic-mode picker, streaming UI, retry, and crisis-card branches still need to be built).

#### Why

UF §5.1–5.4: chat UI works but topic modes (Recovery / Study / Calm) and full lifecycle of `coach_messages` need polish.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Polish Coach tab + topic modes.

## Files allowed to modify

Only modify these files:

- `lib/views/tabs/coach_tab.dart`
- `lib/services/coach_service.dart`

## Firestore paths

- `/users/{uid}/coach_messages/{id}`

## Requirements

- Chat history paginated.
- Long-press avatar → topic mode picker (Recovery / Study / Calm / Ask Anything).
- Mode swap preserves history.
- Streaming reply shows typing indicator.
- Error retry.
- Safety response state shows crisis card.

## Events

- `coach_message_sent`
- `coach_replied`

## Dependencies

- Task 11.1.

## Verification

Send + reply per mode; mode swap mid-thread; offline send queues.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 11.1.

#### How to verify

- 4 modes work.
- Streaming + retry visible.

#### Estimate

1 day

#### Done Criteria

- [ ] 4 modes.
- [ ] Pagination.
- [ ] Streaming.

---

### Task 11.3 — SuggestionService + Routine AI panel round-trip

#### Status

- [ ] Not started

#### Why

`ai_routine_panel.dart` exists but suggestions are local. Wire to `/users/{uid}/suggestions` Firestore + accept-and-create-template flow.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Build SuggestionService + wire Routine AI panel.

## Files allowed to modify

Only modify these files:

- `lib/models/suggestion_model.dart` (new)
- `lib/services/suggestion_service.dart` (new)
- `lib/views/routine/ai_routine_panel.dart`
- `lib/views/suggestions/suggestion_detail_sheet.dart` (new)
- `lib/core/providers.dart`

## Firestore paths

- `/users/{uid}/suggestions/{id}`

## Suggestion fields

- suggestionId, type, title, body, reason, targetPath, status, priority, targetDate, createdAt, expiresAt, acceptedAt, dismissedAt, sourceRuleId, targetSurface

## Requirements

- Service: stream pending suggestions; accept→ create task or template + status='accepted'; dismiss→ status='dismissed'+ decay similar.
- Panel reads stream; Accept opens detail sheet; Dismiss is one tap.
- Free-text "Ask AI..." bar calls `routineSuggest` callable (Cloud Function — Phase 13).

## Events

- `suggestion_accepted`
- `suggestion_dismissed`

## Dependencies

- Tasks 5.2, 11.1.

## Verification

Seed 3 suggestions → accept one → task or template created. Dismiss one → status updates.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 5.2, 11.1.

#### How to verify

- Stream wires; accept creates task/template.
- Dismiss decays similar.

#### Estimate

1 day

#### Done Criteria

- [ ] Service.
- [ ] Panel uses Firestore.
- [ ] Detail sheet.

---

### Task 11.4 — Rule engine speak budget + suppression

#### Status

- [ ] Not started

#### Why

EventSystem §12 / AI Master Engine: speak budget, cooldowns, silence windows, tone budget. The current `rule_engine_service.dart` exists but doesn't enforce all rules.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Implement speak budget + suppression in the rule engine.

## Files allowed to modify

Only modify these files:

- `lib/services/rule_engine_service.dart`
- `lib/models/coach_rule.dart`
- `lib/models/ai_rule_log_model.dart` (new)
- `test/services/rule_engine_service_contract_test.dart`

## Firestore paths

- `/users/{uid}/coach_speak_log/{id}`
- `/users/{uid}/ai_context_snapshots/{id}`

## Requirements

- Implement rules from EventSystem §12.5: don't break flow / don't pile on after slip / don't interrupt active work / don't shout into the void / don't doom-loop / quiet day.
- Tone budget: max 2 Tough-Love per day; auto-soften after 3 bad days; never within 2h of slip.
- Speak budget default 5 proactive interventions/day.
- Log every rule decision (spoke / suppressed + reason).

## Events

- `notification_suppressed` (when rule blocks).

## Dependencies

- Task 11.1, 9.G1.

## Verification

Tests for each suppression rule. Log shows reason for every silence.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 11.1, 9.G1.

#### How to verify

- Tests for each rule.
- speak_log captures reasons.

#### Estimate

1 day

#### Done Criteria

- [ ] All §12.5 rules.
- [ ] Tone budget.
- [ ] Speak log.

---

### Task 11.5 — Safety routing for crisis / medical / legal / financial

#### Status

- [ ] Not started

#### Why

PRD §6 + UF §5.5: crisis routing, never LLM-generate when keyword detected; medical/legal/financial → professional handoff.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Implement safety router (client guard + Cloud Function).

## Files allowed to modify

Only modify these files:

- `lib/services/coach_service.dart` (client pre-filter)
- `lib/views/tabs/coach_tab.dart` (crisis card)
- `functions/jobs/safety.js` (new)
- `functions/index.js`

## Firestore paths

- `/crisis_handoffs/{id}` (admin SDK only — already in rules).

## Requirements

- Client: regex/keyword pre-filter on user text.
- If crisis keyword → show pre-LLM crisis card with regional helpline numbers.
- Function: secondary check on server before Gemini call; if matched, return safe template, never call Gemini.
- Medical/legal/financial: server-side decline message with "talk to a [doctor/lawyer/advisor]".
- All safety triggers logged to `crisis_handoffs` (admin SDK).

## Events

- (none new — uses suppression events.)

## Dependencies

- Task 11.1, 11.4.

## Verification

Type "I want to hurt myself" → crisis card, no LLM call (function logs).

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 11.1, 11.4.

#### How to verify

- Crisis input → safe path.
- Function logs intercept.

#### Estimate

1 day

#### Done Criteria

- [ ] Client pre-filter.
- [ ] Server backstop.
- [ ] Crisis card.

---

### Task 11.6 — AI scheduled jobs (morning/midday/dayClose/inactivity)

#### Status

- [ ] Not started

#### Why

EventSystem §13 / TODO 8.5 split: each job needs full implementation reading context snapshot, applying rules, writing suggestions/scheduled notifications.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Flesh out scheduled AI jobs (morning, midday, dayClose, inactivity, AI planner, rule engine).

## Files allowed to modify

Only modify these files:

- `functions/jobs/morningBrief.js`
- `functions/jobs/middayPulse.js`
- `functions/jobs/dayClose.js`
- `functions/jobs/inactivityCheck.js`
- `functions/jobs/aiPlanner.js` (new)
- `functions/jobs/ruleEngine.js` (new)
- `functions/jobs/utils.js`
- `functions/index.js`

## Firestore paths

- `/users/{uid}/ai_context_snapshots/{id}`
- `/users/{uid}/coach_messages/{id}`
- `/users/{uid}/coach_speak_log/{id}`
- `/users/{uid}/suggestions/{id}`
- `/users/{uid}/scheduled_notifications/{id}`
- `/users/{uid}/events_recent`

## Requirements

- Morning: build snapshot, plan day, generate up to 5 suggestions, schedule pre-emptive notifications.
- Midday: drift check; lighten plan if needed.
- DayClose: write daily summary; emit `routine_day_summarized` if missing.
- Inactivity: detect 1/3/7/14/30-day absences; emit `ghost_day_detected`.
- AI Planner: orchestrator the morning job calls.
- Rule Engine: server replica of §11.4 rules.
- Skip safely for users without data.
- Never store provider key in Flutter.

## Events

- `suggestion_generated`
- `notification_scheduled`
- `notification_suppressed`
- `coach_replied`
- `ghost_day_detected`
- `day_closed`
- `routine_day_summarized`

## Dependencies

- Tasks 11.1, 11.4, 11.5.

## Verification

Emulator: seed user data → run jobs → confirm outputs.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 11.1, 11.4, 11.5.

#### How to verify

- Emulator runs all jobs without crash on no-data users.

#### Estimate

2 days

#### Done Criteria

- [ ] All 6 jobs.
- [ ] Emulator green.

---


## Phase 12 — Image Upload + Photo AI + Routine Import

### Task 12.1 — Storage setup + image picker + upload helper

#### Status

- [ ] Not started

#### Why

All photo AI modes (skin care products, class timetable, mess menu) need a shared upload helper before any AI call.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Add Cloud Storage setup, image picker, compression, and upload helper.

## Files allowed to modify

Only modify these files:

- `lib/services/image_upload_service.dart` (new)
- `lib/views/routine/widgets/photo_picker_button.dart` (new)
- `pubspec.yaml` (add `image_picker`, `image`, `firebase_storage` if missing)
- `firebase.json` (add Storage config if missing)
- `storage.rules` (new — owner-only writes)

## Firestore paths

- N/A (Storage paths only).

## Storage paths

- `users/{uid}/uploads/{routineType}/{ts}.jpg`

## Requirements

- Pick from camera or gallery.
- Compress to <1 MB.
- Upload returns metadata `{path, sizeBytes, mimeType, downloadUrl}`.
- Delete on cancel.
- Permissions: only owner.

## Events

- (none — uploads are not events.)

## Dependencies

- Task 2.2 (Firestore base).

## Verification

Pick photo → upload → URL returned → file visible in Storage emulator.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 2.2.

#### How to verify

- Pick → upload → URL.
- Rules deny non-owner.

#### Estimate

4h

#### Done Criteria

- [ ] Picker.
- [ ] Compression.
- [ ] Owner-only rules.

---

### Task 12.2 — Skin care text AI mode (NEW — Problem 5)

#### Status

- [ ] Not started

#### Why

Problem 5: User types products → AI creates routine.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Wire skin care setup screen text-AI mode + Cloud Function.

## Files allowed to modify

Only modify these files:

- `lib/views/routine/skin_care_setup_screen.dart`
- `lib/views/routine/widgets/routine_review_screen.dart` (new shared)
- `functions/ai/routineImport.js` (new)
- `functions/index.js`
- `lib/repositories/routine_repository.dart` (already has previewRoutineImport — verify)

## Firestore paths

- `/users/{uid}/routine/current.templates.skin_care`
- `/users/{uid}/routine/current.imports.skin_care` (source text)
- `/users/{uid}/suggestions/{id}` (review draft)

## Requirements

- Setup screen has 3 mode tabs: Manual / Text AI / Photo AI.
- Text AI: textarea → "Generate" button → callable `routineImport({routineType:'skin_care', mode:'skin_care_text', sourceText, commit:false})`.
- Function returns `{templates: [...]}`; client renders review screen with edit/remove/add/regenerate; on Accept-all, calls `saveRoutineTemplates`.
- Output schema: title, time, timing rule, weekday rule, steps, notes, confidence, warnings.

## Events

- `suggestion_generated` (server).
- `suggestion_accepted` (client).
- `routine_template_created`.

## Dependencies

- Tasks 6.1, 12.1, 11.1.

## Verification

Type "Vitamin C, retinol, SPF, moisturiser" → AI proposes morning + night blocks → review → accept → templates appear in routine.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 6.1, 12.1, 11.1.

#### How to verify

- Generate → review → accept.
- Templates persist; routine timeline updates.

#### Estimate

1 day

#### Done Criteria

- [ ] Text mode wired.
- [ ] Review screen.
- [ ] Templates saved.

---

### Task 12.3 — Skin care photo AI mode (NEW — Problem 5)

#### Status

- [ ] Not started

#### Why

Problem 5: User uploads photo of products → AI creates routine.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Add photo AI mode to skin care setup.

## Files allowed to modify

Only modify these files:

- `lib/views/routine/skin_care_setup_screen.dart`
- `functions/ai/routineImport.js`
- `functions/index.js`

## Firestore paths

- `/users/{uid}/routine/current.templates.skin_care`
- `/users/{uid}/routine/current.imports.skin_care.photoPath`

## Storage paths

- `users/{uid}/uploads/skin_care/{ts}.jpg`

## Requirements

- Photo mode: pick photo → upload via Task 12.1 helper → callable `routineImport({mode:'skin_care_photo', imageMetadata})`.
- Function uses Gemini Pro Vision to extract product names + suggested timings.
- Review screen identical to Task 12.2.
- Bad image → friendly error, save nothing.

## Events

- `suggestion_generated`, `suggestion_accepted`, `routine_template_created`.

## Dependencies

- Tasks 12.1, 12.2.

## Verification

Sample image → generates templates. Corrupted image → friendly error.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 12.1, 12.2.

#### How to verify

- Real photo → templates.

#### Estimate

1 day

#### Done Criteria

- [ ] Photo upload works.
- [ ] Vision call returns templates.
- [ ] Errors are friendly.

---

### Task 12.4 — Supplement text AI mode (NEW — Problem 6)

#### Status

- [ ] Not started

#### Why

Problem 6: User writes supplement list → AI creates schedule.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Add supplement text AI mode.

## Files allowed to modify

Only modify these files:

- `lib/views/routine/supplement_setup_screen.dart`
- `functions/ai/routineImport.js`

## Firestore paths

- `/users/{uid}/routine/current.templates.supplements`

## Requirements

- Modes tab: Manual / Text AI.
- Text AI input → callable `routineImport({mode:'supplement_text', sourceText})`.
- Output: name, dosage, time, timing rule (after breakfast / after workout / after lunch / before bed), notes, warnings.
- Review screen reuses shared widget from 12.2.

## Events

- `suggestion_generated`, `suggestion_accepted`, `routine_template_created`.

## Dependencies

- Tasks 6.2, 12.1, 12.2, 11.1.

## Verification

"creatine, whey, vitamin D, omega 3" → 4 templates with sensible times.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 6.2, 12.1, 12.2, 11.1.

#### How to verify

- Text → 4 valid templates.

#### Estimate

4h

#### Done Criteria

- [ ] Text mode wired.
- [ ] Templates saved.

---

### Task 12.5 — Class timetable photo OCR mode (NEW — Problem 7)

#### Status

- [ ] Not started

#### Why

Problem 7: User uploads timetable photo → AI extracts classes per weekday.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Add photo OCR mode to class setup.

## Files allowed to modify

Only modify these files:

- `lib/views/routine/class_setup_screen.dart`
- `functions/ai/routineImport.js`

## Firestore paths

- `/users/{uid}/routine/current.templates.classes`

## Storage paths

- `users/{uid}/uploads/classes/{ts}.jpg`

## Requirements

- Modes tab: Manual / Photo OCR.
- Pick image → upload → callable `routineImport({mode:'class_timetable_photo', imageMetadata})`.
- Output: `{weekday, subject, room, professor, start, end}` array.
- Review screen lets user adjust each class.
- Recurring weekly schedule applied via templates.

## Events

- `suggestion_generated`, `suggestion_accepted`, `routine_template_created`.

## Dependencies

- Tasks 6.3, 12.1, 12.2, 11.1.

## Verification

Real timetable photo → weekly grid populated.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 6.3, 12.1, 12.2, 11.1.

#### How to verify

- Photo → schedule.

#### Estimate

1 day

#### Done Criteria

- [ ] OCR mode.
- [ ] Weekly grid.

---

### Task 12.6 — Eating mess menu photo mode (NEW — Problem 8)

#### Status

- [ ] Not started

#### Why

Problem 8: Hostel users upload a weekly mess sheet photo → Claude Vision OCR extracts per-weekday meal times + items → populates eating templates automatically.

**Note:** This task shares the `routineImport` Cloud Function with Tasks 12.2 (skin care photo), 12.3 (skin care text), 12.4 (class timetable photo), and 12.5 (skin care text). Build the CF once and route by `mode`. AI Goal text mode for eating is covered by the fully-redesigned **Task 12.7**.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Add eating mess-menu photo mode.

## Files allowed to modify

Only modify these files:

- `lib/views/routine/eating_setup_screen.dart`
- `functions/ai/routineImport.js`

## Firestore paths

- `/users/{uid}/routine/current.templates.eating`

## Storage paths

- `users/{uid}/uploads/eating/{ts}.jpg`

## Requirements

- Mess Photo button (already stubbed in `_showImportOptions`): pick → compress → upload Storage → callable `routineImport({mode:'eating_mess_photo', storagePath})`.
- CF uses Claude Vision to OCR the sheet and returns weekly grid `{weekday, mealTime, mealName, items[]}`.
- Review screen lets user adjust each meal before saving.
- Saved templates use `repeatRule: 'mess_menu_weekday:N'` (N=1–7, 1=Mon).
- AI Goal text mode (Task 12.7) is a separate button — do NOT add it here.

## Events

- `suggestion_generated`, `suggestion_accepted`, `routine_template_created`.

## Dependencies

- Tasks 6.4, 12.1, 11.1.
  - Note: 12.2 (skin care photo AI) is NOT a dependency — the `routineImport` CF is shared infrastructure but this task's mode is independent.

## Verification

Mess sheet image → weekly grid populated → templates saved with `mess_menu_weekday` repeat rule.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 6.4, 12.1, 11.1.

#### How to verify

- Image → grid.
- Templates stored with `mess_menu_weekday:N` repeatRule.

#### Estimate

1 day

#### Done Criteria

- [ ] Mess Photo mode functional end-to-end.
- [ ] Grid review screen.
- [ ] Templates persisted with correct repeatRule.

---

### Task 12.7 — AI Adaptive Eating — nutritional gap-fill, missed meal recovery, preference steering (NEW — Problem 8 extension)

#### Status

- [ ] Not started

#### Why

After the user marks meals done, Claude checks whether their nutritional targets (TDEE) were met. If short, Claude adds one or more "gap-fill" food blocks for the rest of the day. If a meal was skipped, Claude schedules a recovery snack. Gap-fill blocks repeat on the same weekday the following weeks (e.g., Monday gap-fill appears every Monday). The user can steer suggestions toward sweet / spicy / light etc. by sending a preference message; Claude adjusts on next suggestion cycle. AI blocks are non-deletable by the user (they can request flavour changes instead).

**Spec source:** `docs/phase_1_5_audit.md` → "Feature Spec: Task 12.6 + Task 12.7 — AI Adaptive Eating".

**Build order prerequisite:** Task 2.3 must be re-opened to add the new events below before this task ships. Task 2.4 must be re-opened to add the new Firestore indexes.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Build AI Adaptive Eating: nutritional gap-fill after meal completion, missed-meal recovery, and preference steering.

## Files allowed to modify

Only modify these files:

- `lib/providers/routine_provider.dart`
- `lib/views/routine/routine_tab.dart`
- `lib/views/routine/eating_setup_screen.dart`
- `lib/models/task_model.dart`          ← add `deletable: bool` field (default true)
- `functions/ai/adaptiveEating.js`      ← new callable Cloud Function
- `functions/index.js`
- `lib/core/constants/event_names.dart`
- `lib/services/event_payload_validator.dart`

## Firestore paths

- `/users/{uid}/routine/current.templates.eating`           ← existing meal templates
- `/users/{uid}/routine/ai_suggestions/{date}_{slot}`       ← AI-generated gap-fill blocks
  Fields: `mealName`, `emoji`, `time`, `calories`, `repeatRule` (`weekly:N`), `deletable: false`, `source: 'ai'`, `createdAt`
- `/users/{uid}/routine/nutritional_targets`                ← computed TDEE + macro targets
  Fields: `tdeeKcal`, `proteinG`, `carbG`, `fatG`, `lastComputedAt`
- `/users/{uid}/routine/preferences`                        ← user flavour steering
  Fields: `flavorTags: ['sweet'|'spicy'|'light'|...]`, `updatedAt`
- `/users/{uid}/profile/main`                               ← read-only: height, weight, age, sex, activityLevel, eatingDisorderFlag

## Storage paths

None for this task.

## Requirements

### A — TDEE computation
- On first run (or when biometrics change), callable `adaptiveEating({action:'compute_targets'})` computes TDEE using Mifflin-St Jeor formula:
  - Men:   BMR = 10·weight(kg) + 6.25·height(cm) − 5·age + 5
  - Women: BMR = 10·weight(kg) + 6.25·height(cm) − 5·age − 161
  - TDEE = BMR × activityMultiplier (sedentary 1.2, light 1.375, moderate 1.55, active 1.725, very active 1.9)
- Store result in `/users/{uid}/routine/nutritional_targets`.
- If `eatingDisorderFlag == true`: skip calorie talk; use only meal-structure suggestions.
- Emit `nutritional_target_computed` event.

### B — Gap-fill flow (triggered after meal marked done)
- Triggered: user marks a meal task done in routine_tab → provider calls `adaptiveEating({action:'check_gap', date, completedMealTime})`.
- CF sums calories of all meals marked done that day vs. `tdeeKcal`.
- If gap > 200 kcal and there are ≥ 2 hours left in the day:
  - Generate 1–2 food blocks to close the gap (respect `preferences.flavorTags`).
  - Store each block in `/users/{uid}/routine/ai_suggestions/{date}_{slot}` with `deletable: false`.
  - Create a recurring template with `repeatRule: 'weekly:N'` (N = weekday of `date`) so the same suggestion appears every week on that weekday.
  - Emit `ai_meal_suggestion_created` event per block.
- If gap ≤ 200 kcal: no action.

### C — Missed meal recovery
- Triggered: routine_tab checks at end-of-day (or on next open after midnight) if any meal template for that date was never marked done.
- Calls `adaptiveEating({action:'missed_meal_recovery', date, missedSlot})`.
- CF generates a recovery snack for the following morning.
- Stored in `ai_suggestions/{tomorrow}_{slot}`.
- Non-recurring (one-off `repeatRule: 'once'`).
- Emit `ai_meal_suggestion_created`.

### D — Preference steering
- In eating_setup_screen.dart: add a "Steer AI suggestions" chip bar (sweet / spicy / light / high-protein / vegan).
- Tapping a chip saves to `/users/{uid}/routine/preferences.flavorTags` (toggle on/off).
- CF reads this on every gap-fill cycle.
- Emit `ai_meal_preference_updated` event.

### E — Non-deletable display
- `TaskModel` gains `deletable: bool` (default `true`).
- AI suggestion blocks in routine_tab render with a lock icon instead of a delete affordance.
- User can long-press to open a "Request change" bottom sheet: free-text preference → saved to `preferences` → triggers new gap-fill cycle.

### F — TaskModel.deletable field
- Add `deletable` to `TaskModel.fromMap()` / `toMap()` (default `true` when absent in Firestore).
- `TaskService.deleteTask()` must check `deletable == false` and throw `PermissionDenied` error.

## Events

- `nutritional_target_computed` — payload: `{uid, tdeeKcal, source:'mifflin_st_jeor'}`
- `ai_meal_suggestion_created` — payload: `{uid, date, slot, mealName, calories, repeatRule}`
- `ai_meal_preference_updated` — payload: `{uid, flavorTags: [...]}`

These three events must be registered in `event_names.dart` and validated in `event_payload_validator.dart` before this task is considered done. (Task 2.3 re-open required.)

## Dependencies

- Task 6.4 (eating manual mode — templates exist).
- Task 12.1 (routineImport CF skeleton — shared infra).
- Task 12.6 (mess menu OCR — user's weekly meals populated before gap-fill makes sense).
- Task 11.1 (About You biometrics — needed for TDEE).
- Task 1.2 (profile/main — eatingDisorderFlag).
- Task 3.1 (TaskModel base — adding `deletable` field here).
- Task 2.3 re-open (new event validators).
- Task 2.4 re-open (new Firestore indexes for `ai_suggestions` and `nutritional_targets`).

## Verification

1. Mark all meals done for today with 600 kcal gap → CF creates gap-fill block in Firestore + appears in timeline with lock icon.
2. Skip breakfast → next morning recovery snack appears.
3. Toggle "spicy" chip → regenerate gap-fill → suggestion uses spicy tags.
4. Attempt to delete AI block → blocked with PermissionDenied.
5. Long-press AI block → "Request change" sheet → preference saved → cycle re-runs.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 6.4, 12.1, 12.6, 11.1, 1.2, 3.1.
- Task 2.3 must be re-opened to add: `nutritional_target_computed`, `ai_meal_suggestion_created`, `ai_meal_preference_updated`.
- Task 2.4 must be re-opened to add indexes for `ai_suggestions` (date+slot) and `nutritional_targets`.

#### How to verify

- Gap-fill block appears in timeline after calories fall short.
- Missed meal → next-day recovery snack present.
- Preference chips steer suggestions.
- AI blocks non-deletable; "Request change" flow works.

#### Estimate

3–4 days

#### Done Criteria

- [ ] TDEE computed and stored (Mifflin-St Jeor; eating-disorder flag respected).
- [ ] Gap-fill CF creates recurring weekly AI blocks when daily shortfall > 200 kcal.
- [ ] Missed meal recovery creates one-off next-morning block.
- [ ] Preference chip bar saves `flavorTags`; CF respects them.
- [ ] AI blocks render with lock icon; delete blocked; "Request change" sheet works.
- [ ] `TaskModel.deletable` field added; `TaskService.deleteTask()` enforces it.
- [ ] Three new events registered, validated, and emitted.

---

## Phase 13 — Cloud Functions Hardening

### Task 13.1 — Server notification dispatcher

#### Status

- [ ] Not started

#### Why

For users offline at fire-time + cross-device delivery + caps enforced server-side.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Build the server notification dispatcher Cloud Function.

## Files allowed to modify

Only modify these files:

- `functions/jobs/notificationDispatcher.js` (new)
- `functions/index.js`
- `functions/test/notificationDispatcher.contract.test.js`

## Firestore paths

- `/users/{uid}/scheduled_notifications`
- `/users/{uid}/notificationLog`
- `/users/{uid}/profile/main.notificationSettings`
- `/users/{uid}/devices/{deviceId}`

## Requirements

- Query due notifications (state='scheduled', fireAt <= now).
- Apply caps + quiet hours + dedupe.
- FCM send if token exists; mark `pending_local` if not.
- Emit lifecycle events.
- Skip safely when settings disable a category.

## Events

- `notification_sent`
- `notification_suppressed`

## Dependencies

- Tasks 10.1, 10.3.

## Verification

Emulator: seed due notification → run dispatcher → status updates.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 10.1, 10.3.

#### How to verify

- Emulator green.

#### Estimate

1 day

#### Done Criteria

- [ ] Dispatcher.
- [ ] Caps enforced.
- [ ] Lifecycle logs.

---

### Task 13.2 — Cleanup, archive, backfill jobs

#### Status

- [ ] Not started

#### Why

Production needs event trimming, schema migration, safe backfills.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Build maintenance + backfill jobs.

## Files allowed to modify

Only modify these files:

- `functions/jobs/eventMaintenance.js` (new)
- `functions/jobs/schemaBackfill.js` (new)
- `functions/index.js`

## Firestore paths

- `/users/{uid}/events_recent` (trim)
- `/users/{uid}/events` (preserve)
- `/users/{uid}/events_archive/{YYYYMM}/items/{eventId}` (move)

## Requirements

- Trim `events_recent` to last 7d or 100.
- Backfill missing `schemaVersion`, `uid`.
- Dry-run mode before write mode.
- Logs counts + samples.

## Events

- (none new.)

## Dependencies

- Tasks 2.1, 2.2.

## Verification

Emulator: seed old data → dry-run logs → write mode updates.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 2.1, 2.2.

#### How to verify

- Dry-run safe.
- Write mode correct.

#### Estimate

1 day

#### Done Criteria

- [ ] Maintenance.
- [ ] Backfill.
- [ ] Dry-run.

---

### Task 13.3 — Routine import callable Cloud Function (consolidates 12.x)

#### Status

- [ ] Not started

#### Why

Task 12.2–12.7 each call `routineImport`. This task ensures the function exists once with all 7 modes.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Implement `routineImport` callable handling 7 modes.

## Files allowed to modify

Only modify these files:

- `functions/ai/routineImport.js`
- `functions/index.js`
- `functions/test/routineImport.contract.test.js`

## Firestore paths

- writes only via Flutter; this function returns JSON to client.
- writes `/users/{uid}/usage/{monthKey}` to track AI calls.

## Requirements

- Modes: skin_care_text, skin_care_photo, supplement_text, class_timetable_photo, eating_mess_photo, eating_goal_text, routine_goal_suggestions.
- Validate output against per-mode JSON schema.
- Reject malformed AI output (return safe error).
- Enforce per-user usage cap (Phase 14.6).
- Read About You for safety flags.
- Log call to `usage/{monthKey}.aiCalls`.

## Events

- `suggestion_generated` (write to `/suggestions`).

## Dependencies

- Task 11.1, 12.1.

## Verification

Tests for each mode; malformed output rejected.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 11.1, 12.1.

#### How to verify

- All 7 modes tested.

#### Estimate

2 days

#### Done Criteria

- [ ] All modes.
- [ ] Schema validation.
- [ ] Usage logged.

---

## Phase 14 — Profile, Settings, Privacy, Subscription

### Task 14.1 — Profile hub + identity hero + strengths card

#### Status

- [ ] Not started

#### Why

UF §10 — Profile is mirror + admin hub.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Polish Profile tab per UF §10.1.

## Files allowed to modify

Only modify these files:

- `lib/views/tabs/profile_tab.dart`
- `lib/views/profile/identity_hero_card.dart` (new)
- `lib/views/profile/strengths_areas_card.dart` (new)
- `lib/core/router/app_router.dart`

## Firestore paths

- `/users/{uid}/profile/main`
- `/users/{uid}/identity_profile/main`
- `/users/{uid}/weeklySummaries/{weekKey}` (read strengths)

## Requirements

- Identity hero: avatar + name + identity statement + stat row.
- Strengths/Areas to Improve card (read-only — generated weekly).
- Settings list with chevron rows: Routine, Coach, Accountability, Notifications, About You, Privacy, Subscription, Help, Sign out.

## Events

- `identity_statement_updated`

## Dependencies

- Tasks 9.G1, 15.2.

## Verification

UI: all sections.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 9.G1, 15.2.

#### How to verify

- UI: hero + cards + list.

#### Estimate

1 day

#### Done Criteria

- [ ] Hero.
- [ ] Strengths card.
- [ ] Settings list.

---

### Task 14.2 — Coach + Accountability settings

#### Status

- [ ] Not started

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Build Coach settings + Accountability settings screens.

## Files allowed to modify

Only modify these files:

- `lib/views/settings/coach_settings_screen.dart` (new)
- `lib/views/settings/accountability_settings_screen.dart` (new)

## Firestore paths

- `/users/{uid}/profile/main.coach*`
- `/users/{uid}/profile/main.accountabilityMode`
- `/users/{uid}/habits/{habitId}.accountabilityOverride` (per-habit override list)

## Requirements

- Coach: name, style, tone budget slider, voice toggle, voice preview, topic modes, reset memory (warning modal).
- Accountability: 3 cards + per-habit override list.

## Events

- `coach_settings_changed`
- `accountability_changed`

## Dependencies

- Tasks 14.1, 8.3.

## Verification

Edits persist; override list works.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 14.1, 8.3.

#### How to verify

- Settings persist.

#### Estimate

1 day

#### Done Criteria

- [ ] Coach screen.
- [ ] Accountability screen.

---

### Task 14.3 — About You editor (post-onboarding)

#### Status

- [ ] Not started

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Build About You editor (3 sub-pages, post-onboarding).

## Files allowed to modify

Only modify these files:

- `lib/views/settings/about_you_settings_screen.dart` (new)

## Firestore paths

- `/users/{uid}/profile/main.{biometrics,lifestyle,sensitiveContext}`

## Requirements

- Mirror onboarding page 5 sub-pages.
- Show delta on weight (+0.8 kg ↗).
- Eating-disorder toggle confirmation friction (both directions).

## Events

- `biometrics_updated`
- `health_flags_changed`

## Dependencies

- Tasks 1.2, 14.1.

## Verification

Edit weight → delta visible. Toggle ED → friction modal.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 1.2, 14.1.

#### How to verify

- Edits persist; friction modal works.

#### Estimate

4h

#### Done Criteria

- [ ] 3 sub-pages.
- [ ] Delta display.
- [ ] Friction.

---

### Task 14.4 — Privacy & data (export + delete)

#### Status

- [ ] Not started

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Build privacy + export + delete lifecycle.

## Files allowed to modify

Only modify these files:

- `lib/views/settings/privacy_data_screen.dart` (new)
- `functions/jobs/exportUserData.js` (new)
- `functions/jobs/deleteUserData.js` (new)
- `functions/index.js`
- `firestore.rules` (already carves out)

## Firestore paths

- `/users/{uid}/data_exports/{exportId}`
- `/users/{uid}/deletion_requests/{requestId}`

## Requirements

- Plain-English data summary.
- Export: queued/processing/ready/failed; emailed link.
- Delete: 7-day soft-delete window; cancel allowed.
- Granular delete: chat history / events / biometrics.

## Events

- `account_deleted` (after purge).

## Dependencies

- Task 2.2.

## Verification

Emulator: request → status flow → cancel works.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 2.2.

#### How to verify

- Export status updates.
- Delete recovery window works.

#### Estimate

1 day

#### Done Criteria

- [ ] Privacy screen.
- [ ] Export job.
- [ ] Delete job.

---

### Task 14.5 — Subscription + AI usage caps

#### Status

- [ ] Not started

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Add subscription screen + server-side usage caps.

## Files allowed to modify

Only modify these files:

- `lib/views/settings/subscription_screen.dart` (new)
- `lib/services/coach_service.dart`
- `lib/services/notification_service.dart`
- `functions/ai/routineImport.js` (cap check)
- `functions/ai/coachReply.js` (cap check)

## Firestore paths

- `/users/{uid}/profile/main.subscription`
- `/users/{uid}/usage/{monthKey}`

## Requirements

- Show plan + limits.
- Server enforces caps (10 coach msgs/day free; AI imports/month).
- Disabled upgrade CTA if Stripe/Play not integrated yet.

## Events

- (none.)

## Dependencies

- Tasks 13.3, 11.1, 10.3.

## Verification

Hit cap → friendly server error returned to UI.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 13.3, 11.1, 10.3.

#### How to verify

- Cap blocks server-side.

#### Estimate

1 day

#### Done Criteria

- [ ] Subscription screen.
- [ ] Usage doc.
- [ ] Cap blocks.

---

## Phase 15 — Analytics, Daily / Weekly Summaries

### Task 15.1 — Daily summary surface

#### Status

- [ ] Not started

#### Why

Day close already writes summaries; UI surfaces them on Home + Profile.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Surface daily summary in Home + Profile.

## Files allowed to modify

Only modify these files:

- `lib/views/tabs/home_tab.dart`
- `lib/views/tabs/profile_tab.dart`
- `lib/services/analytics_service.dart` (new)

## Firestore paths

- `/users/{uid}/dailySummaries/{date}`

## Requirements

- Home: end-of-day card (after sleep block) shows yesterday's summary.
- Profile: This week section.
- Tap → expanded detail.

## Events

- (read-only.)

## Dependencies

- Task 3.5.

## Verification

UI: summary card visible after day close.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 3.5.

#### How to verify

- Card appears.

#### Estimate

4h

#### Done Criteria

- [ ] Home card.
- [ ] Profile section.

---

### Task 15.2 — Weekly summary job + Strengths/Areas card

#### Status

- [ ] Not started

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Build weekly summary Cloud Function + Strengths/Areas card.

## Files allowed to modify

Only modify these files:

- `functions/jobs/weeklySummary.js` (new)
- `functions/index.js`
- `lib/views/profile/strengths_areas_card.dart` (consume)

## Firestore paths

- `/users/{uid}/weeklySummaries/{weekKey}`

## Requirements

- Job runs Sunday 23:59 user-local.
- Reads `dailySummaries` for the week.
- Writes weekly metrics + AI-generated strengths/areas.
- Emits `weekly_insight_ready`.

## Events

- `weekly_insight_ready`

## Dependencies

- Tasks 3.5, 11.6.

## Verification

Emulator: seed week of data → run job → weeklySummary doc.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 3.5, 11.6.

#### How to verify

- Doc written; card displays.

#### Estimate

1 day

#### Done Criteria

- [ ] Job.
- [ ] Card.
- [ ] Event.

---

## Phase 16 — Remote Config, Monitoring, Crash + Performance

### Task 16.1 — Remote-config kill switches

#### Status

- [ ] Not started

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Wire remote-config kill switches.

## Files allowed to modify

Only modify these files:

- `lib/services/remote_config_service.dart`
- `lib/main.dart`
- `lib/services/global_error_handler.dart`
- `functions/index.js`

## Config keys

- ai_enabled
- routine_ai_import_enabled
- image_upload_ai_enabled
- proactive_coach_enabled
- notifications_enabled
- custom_alarms_enabled
- screen_time_enabled
- subscription_limits_enabled

## Requirements

- UI: graceful disabled state per feature.
- Functions: skip work if flag off; log skip reason.

## Events

- (none.)

## Dependencies

- Tasks 10.3, 13.3, 13.1.

## Verification

Flip flag → UI shows disabled; function skips.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 10.3, 13.3, 13.1.

#### How to verify

- Flag flip works.

#### Estimate

4h

#### Done Criteria

- [ ] All 8 keys.
- [ ] UI graceful.
- [ ] Server respects.

---

### Task 16.2 — Crashlytics + performance enrichment

#### Status

- [ ] Not started

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Enrich Crashlytics with user state + performance traces on hot paths.

## Files allowed to modify

Only modify these files:

- `lib/services/global_error_handler.dart`
- `lib/main.dart`
- `lib/services/notification_service.dart`
- `lib/services/task_service.dart`
- `lib/services/habit_service.dart`

## Requirements

- Set custom keys on Crashlytics: `engagementState`, `accountabilityMode`, `lastDayClosed`, `subscriptionTier`, `featureFlags` snapshot.
- Performance traces: app start, day close, materialise, coach reply.
- Do NOT log PII (email, name, biometrics).

## Events

- (none.)

## Dependencies

- Tasks 1.1, 3.5.

## Verification

Force crash → Firebase shows enriched keys.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 1.1, 3.5.

#### How to verify

- Forced crash visible with keys.

#### Estimate

3h

#### Done Criteria

- [ ] Custom keys.
- [ ] Traces.
- [ ] No PII.

---

## Phase 17 — Security Rules, App Check, Backend Hardening

### Task 17.1 — Rules + indexes audit for new collections

#### Status

- [ ] Not started

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Add rules + indexes for new collections.

## Files allowed to modify

Only modify these files:

- `firestore.rules`
- `firestore.indexes.json`
- `storage.rules`
- `test/rules/security_rules_test.dart` (new — uses `firebase_rules_test_helper` or emulator)

## Firestore paths affected

- `/users/{uid}/coach_messages`
- `/users/{uid}/coach_speak_log`
- `/users/{uid}/suggestions`
- `/users/{uid}/ai_context_snapshots`
- `/users/{uid}/weeklySummaries`
- `/users/{uid}/usage`
- `/users/{uid}/devices`
- `/users/{uid}/data_exports`
- `/users/{uid}/deletion_requests`
- `/users/{uid}/uploads/...` (Storage)

## Requirements

- Rules: owner-only read/write where appropriate.
- `coach_messages`: client write user message; server (admin SDK) writes coach reply.
- `ai_context_snapshots`: server-only writes; client read-only.
- `usage`: server-only writes.
- Indexes: as listed in Task 2.4.
- Storage rules: owner-only writes; max 5 MB.

## Events

- (none.)

## Dependencies

- Task 2.2 (existing rules).

## Verification

Rules tests cover unauthenticated denial, cross-user denial, server-only-write enforcement.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 2.2.

#### How to verify

- Rules tests green.

#### Estimate

1 day

#### Done Criteria

- [ ] Rules tested.
- [ ] Indexes deployed.

---

### Task 17.2 — Firebase App Check

#### Status

- [ ] Not started

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Enable Firebase App Check (Play Integrity on Android, App Attest on iOS).

## Files allowed to modify

Only modify these files:

- `lib/main.dart`
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Runner.entitlements`
- `functions/index.js` (enforceAppCheck on callable functions)

## Requirements

- Token attached to all Firestore + Functions calls.
- Functions reject without valid token.
- Debug token allowed in dev only.

## Events

- (none.)

## Dependencies

- Task 2.2.

## Verification

Stripped APK without token → Firestore denial.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 2.2.

#### How to verify

- App Check console shows tokens.

#### Estimate

3h

#### Done Criteria

- [ ] Tokens enforce.
- [ ] Debug bypass works.

---

## Phase 18 — Production QA & Release

### Task 18.1 — Full test suite

#### Status

- [ ] Not started

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Convert all skipped contract tests to real tests covering implemented behaviour.

## Files allowed to modify

Only modify files under:

- `test/services/*`
- `test/widgets/*`
- `integration_test/*`
- `functions/test/*`
- `test/rules/*`

## Coverage required

- auth + onboarding
- unlimited fixed schedule (Problem 1)
- daily fixed schedule repeat (Problem 2)
- selected-day Add button (Problem 3)
- routine setup AI/upload review flow (Problems 5–8)
- onboarding ↔ Settings shared widget (Problem 9)
- task state machine
- habit logs
- streak rules (forgiving / strict / ruthless × pause/resume/reset)
- notification lifecycle + dispatcher
- suggestions accept/dismiss
- AI import schema
- privacy export/delete
- App Check
- security rules
- crash + perf

## Requirements

- Unit, widget, integration, function, rules layers.
- No `skip:` markers when feature is implemented.
- CI ready scripts in `package.json` and `pubspec.yaml`.

## Events

- (tests only — no production emission.)

## Dependencies

- All implementation phases.

## Verification

`flutter test`, `flutter test integration_test`, `cd functions && npm test`, `firebase emulators:exec --only firestore "npm test"`.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- All implementation phases.

#### How to verify

- All test runners green.

#### Estimate

3 days

#### Done Criteria

- [ ] Unit tests pass.
- [ ] Widget tests pass.
- [ ] Integration smoke pass.
- [ ] Function tests pass.
- [ ] Rules tests pass.

---

### Task 18.2 — Migration / seed checklist

#### Status

- [ ] Not started

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Document migration + seed for existing users.

## Files allowed to modify

Only modify these files:

- `docs/migration_checklist.md`
- `docs/seed_data_checklist.md`
- `functions/jobs/seedDevData.js` (new — emulator only)

## Requirements

- Old onboarding shape → new templates.
- Old tasks preserved.
- Notification re-registration.
- Emulator scenarios: new user / existing onboarding / completed user / habit-history user / ghost user / AI-disabled user / eating-disorder user.

## Events

- (none — migration only.)

## Dependencies

- Task 13.2.

## Verification

Run migration in emulator → no crash; seed produces every scenario user.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 13.2.

#### How to verify

- All scenarios open without crash.

#### Estimate

1 day

#### Done Criteria

- [ ] Migration doc.
- [ ] Seed doc.
- [ ] Emulator seed job.

---

### Task 18.3 — Final completeness audit + release gate

#### Status

- [ ] Not started

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Update `docs/feature_matrix.md` for production release.

## Files allowed to modify

Only modify these files:

- `docs/feature_matrix.md`
- `docs/release_checklist.md` (new)

## Requirements

- Every feature row must have UI + state + Firestore + backend + event + AI + notification + verification + user-visible path filled.
- Any `partial` row must list a blocking issue.
- Release checklist gates: APK signing, App Check on, kill switches default-on for AI, Crashlytics keys redacted, privacy policy URL set, store listing copy ready.
- Cover the urgent fixes:
  - unlimited fixed schedule (Problem 1)
  - daily fixed schedule repeat (Problem 2)
  - Routine Add button (Problem 3)
  - Routine AI button (Problem 4)
  - skin care manual/text/photo AI (Problem 5)
  - supplement manual/text AI (Problem 6)
  - class manual/upload (Problem 7)
  - eating manual/mess photo/AI (Problem 8)
  - onboarding ↔ Settings shared widget (Problem 9)
  - all tracking features (Problem 10)
  - full app coverage (Problem 11)

## Events

- (audit only.)

## Dependencies

- All phases.

## Verification

Open matrix; no `missing` rows; release checklist all green.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- All phases.

#### How to verify

- Matrix complete.
- Release checklist all green.

#### Estimate

1 day

#### Done Criteria

- [ ] Matrix all green.
- [ ] Release checklist exists.
- [ ] No release blockers.

---


## 8. Completeness Matrix

> Columns: UI · State/provider · Firestore · Backend · Event · AI · Verification · User-visible path
> Cells use ✓ (covered by a task in this file), ◐ (partially covered, follow-up task listed), or ✗ (gap — must be added before release).

| # | Feature | UI | State | Firestore | Backend | Event | AI | Verif | UI path |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Onboarding | ✓ | ✓ | ✓ | – | ✓ | – | ✓ | Welcome → Onboarding 0–10 |
| 2 | Home screen | ✓ | ✓ | ✓ | day-close | ✓ | day-start | ✓ | Tab 0 |
| 3 | Settings (Profile hub) | ✓ T14.1 | ✓ | ✓ | – | ✓ | – | ✓ | Tab 5 |
| 4 | Profile (identity hero) | ✓ T14.1 | ✓ | ✓ | weeklySummary | ✓ | weekly | ✓ | Tab 5 → header |
| 5 | Fixed schedule onboarding UI | ✓ T4.2 | ✓ | ✓ | – | ✓ | – | ✓ | Onboarding p9 |
| 6 | Fixed schedule settings UI | ✓ T4.3 | ✓ | ✓ | – | ✓ | – | ✓ | Profile → Routine settings → Fixed Schedule |
| 7 | Shared fixed schedule component | ✓ T4.2 | ✓ | ✓ | – | ✓ | – | ✓ | Both above use it |
| 8 | Daily repeating routine timeline | ✓ T5.1 | ✓ | ✓ | – | ✓ | – | ✓ | Tab 1 timeline |
| 9 | Routine Add button | ✓ T5.2 | ✓ | ✓ | – | ✓ | – | ✓ | Tab 1 + |
| 10 | Routine AI suggest button | ✓ T11.3 | ✓ | ✓ | T13.3 routineSuggest | ✓ | yes | ✓ | Tab 1 AI |
| 11 | Habit system | ✓ | ✓ | ✓ | – | ✓ | – | ✓ | Tracker tab |
| 12 | Task system | ✓ | ✓ | ✓ | – | ✓ | learning | ✓ | Routine tab |
| 13 | Goal system | ✓ T9.G1, T9.2–T9.5 | ✓ | ✓ | – | ✓ | yes (Why score) | ✓ | Tab 4 |
| 14 | Identity profile | ✓ T9.G1, T14.1 | ✓ | ✓ | aggregator | ✓ | yes | ✓ | Tab 4 + Tab 5 hero |
| 15 | Smoking tracking | ✓ T7.4 | ✓ | ✓ | recovery alarm | ✓ | yes | ✓ | Tracker → Cigarettes |
| 16 | Smoking reduction goals | ✓ T7.4 + T9.4 | ✓ | ✓ | – | ✓ | yes | ✓ | Goals + Tracker |
| 17 | Running tracking | ✓ T7.12 | ✓ | ✓ | health pull | ✓ | yes | ✓ | Tracker → Exercise |
| 18 | Workout/gym tracking | ✓ T7.12 | ✓ | ✓ | health pull | ✓ | yes | ✓ | Tracker → Exercise |
| 19 | Meditation tracking | ✓ T7.9 | ✓ | ✓ | – | ✓ | mood lift | ✓ | Tracker → Meditation |
| 20 | Reading tracking | ✓ T7.11 | ✓ | ✓ | Google Books | ✓ | yes | ✓ | Tracker → Reading |
| 21 | Coding/study tracking | ✓ via Habit + procrastination T7.7 | ✓ | ✓ | – | ✓ | yes | ✓ | Tracker → custom + procrastination |
| 22 | Sleep tracking | ✓ via routine sleep block + dailySummary | ✓ | ✓ | dayClose | ✓ | yes | ✓ | Routine + Tracker |
| 23 | Water tracking | ✓ T7.8 | ✓ | ✓ | – | ✓ | smart reminder | ✓ | Tracker → Hydration |
| 24 | Screen time / app usage | ✓ T7.5 | ✓ | ✓ | importer | ✓ | yes | ✓ | Tracker → Screen Time |
| 25 | Skin care routine | ✓ T6.1 + T12.2 + T12.3 | ✓ | ✓ | routineImport | ✓ | yes | ✓ | Routine settings → Skin Care |
| 26 | Supplement routine | ✓ T6.2 + T12.4 | ✓ | ✓ | routineImport | ✓ | yes | ✓ | Routine settings → Supplements |
| 27 | Class routine | ✓ T6.3 + T12.5 | ✓ | ✓ | routineImport | ✓ | yes | ✓ | Routine settings → Classes |
| 28 | Eating routine | ✓ T6.4 + T12.6 + T12.7 | ✓ | ✓ | routineImport | ✓ | yes | ✓ | Routine settings → Eating |
| 29 | Photo upload AI (shared) | ✓ T12.1 | ✓ | – (Storage) | upload | – | – | ✓ | All photo modes |
| 30 | Hostel mess sheet AI | ✓ T12.6 | ✓ | ✓ | routineImport | ✓ | yes | ✓ | Eating setup → Mess Photo |
| 31 | Timetable image AI | ✓ T12.5 | ✓ | ✓ | routineImport | ✓ | yes | ✓ | Class setup → Photo |
| 32 | Skincare product photo AI | ✓ T12.3 | ✓ | ✓ | routineImport | ✓ | yes | ✓ | Skin Care setup → Photo |
| 33 | AI routine generation | ✓ T11.3 + T12.x + T13.3 | ✓ | ✓ | routineImport, routineSuggest | ✓ | yes | ✓ | Routine AI panel + setup screens |
| 34 | AI rule engine | ✓ T11.4 | ✓ | ✓ | ruleEngine.js | ✓ | yes | ✓ | (server) |
| 35 | AI coach messages | ✓ T11.1, T11.2 | ✓ | ✓ | coachReply.js | ✓ | yes | ✓ | Coach tab |
| 36 | Event system | ✓ T2.1, T2.3 | ✓ | ✓ | – | ✓ | – | ✓ | (system-wide) |
| 37 | Streaks | ✓ T8.1, T8.3 | ✓ | ✓ | – | ✓ | – | ✓ | Home + Tracker |
| 38 | Ghost absence | ✓ T8.4 | ✓ | ✓ | inactivityCheck | ✓ | – | ✓ | (background) |
| 39 | Comeback modal | ✓ existing + T8.4 | ✓ | ✓ | inactivityCheck | ✓ | force-supportive | ✓ | Home (post-gap) |
| 40 | Protected streak pause/resume | ✓ T8.3 | ✓ | ✓ | inactivityCheck | ✓ | – | ✓ | Streak detail chip |
| 41 | Notifications | ✓ T10.1 + T13.1 | ✓ | ✓ | dispatcher | ✓ | rule engine | ✓ | All deep links |
| 42 | Notification center | ✓ T10.2 | ✓ | ✓ | – | ✓ | – | ✓ | Home bell |
| 43 | Notification settings | ✓ T10.3 | ✓ | ✓ | – | ✓ | – | ✓ | Profile → Notifications |
| 44 | Custom alarms | ✓ T10.4 | ✓ | ✓ | AlarmManager | ✓ | voice | ✓ | Routine row + Profile |
| 45 | Daily summaries | ✓ T15.1 | ✓ | ✓ | dayClose | ✓ | EoD | ✓ | Home + Profile |
| 46 | Weekly summaries / strengths | ✓ T15.2 + T14.1 | ✓ | ✓ | weeklySummary | ✓ | yes | ✓ | Profile |
| 47 | Money saving | ✓ T7.10 | ✓ | ✓ | dayClose | – | relapse pause | ✓ | Tracker |
| 48 | Junk food → Mindful eating swap | ✓ T7.6 | ✓ | ✓ | – | ✓ | safety | ✓ | Tracker (flag-driven) |
| 49 | Procrastination auto-detect | ✓ T7.7 | ✓ | ✓ | – | ✓ | yes | ✓ | Tracker |
| 50 | Routine completion meta-tracker | ✓ T7.13 | ✓ | ✓ | dayClose | – | yes | ✓ | Tracker |
| 51 | Privacy export/delete | ✓ T14.4 | ✓ | ✓ | export/delete jobs | ✓ | – | ✓ | Profile → Privacy |
| 52 | Subscription + AI usage caps | ✓ T14.5 | ✓ | ✓ | server caps | – | – | ✓ | Profile → Subscription |
| 53 | Firestore security rules | ✓ T17.1 | – | ✓ | – | – | – | ✓ | (system) |
| 54 | App Check | ✓ T17.2 | – | ✓ | – | – | – | ✓ | (system) |
| 55 | Cloud Functions | ✓ T11.6 + T13.x | – | ✓ | – | ✓ | yes | ✓ | (background) |
| 56 | Crash + perf monitoring | ✓ T16.2 | – | – | Crashlytics | – | – | ✓ | (system) |
| 57 | Remote config kill switches | ✓ T16.1 | ✓ | – | – | – | – | ✓ | (system) |
| 58 | Production QA | ✓ T18.1 | – | – | – | – | – | ✓ | (CI) |
| 59 | Migration / seed | ✓ T18.2 | – | – | seedDevData | – | – | ✓ | (emulator) |
| 60 | Final completeness audit | ✓ T18.3 | – | – | – | – | – | ✓ | (release gate) |

> If any cell is `✗` after this matrix is updated by Task 18.3, the build is **not ready**. Add follow-up tasks in this same file.

---


---

## 10. Spec vs Code Reconciliation (re-verification round 2)

> Findings from a line-by-line read of all 7 OPTIVUS Docs and a code spot-check on 2026-05-03.
> Earlier rounds claimed gaps that did not exist; some genuine gaps were missed. This section is the corrected ledger.

### 10.1 Claims I corrected

| Earlier claim | Reality (file:line) | Status |
|---|---|---|
| `routine_template_*` validators missing | `event_payload_validator.dart:112-114` already maps all three to `_routineTemplateRule` | Validator OK — Task 2.3 trimmed |
| `gemini_service.dart` may hold the API key | `gemini_service.dart` only calls `httpsCallable('aiGenerate')`; `functions/index.js` line 60 declares `secrets: [geminiApiKey]` | **No client-side key — Task 11.1 marked Done** |
| Routine setup AI mode UI is "stubbed" | `skin_care_setup_screen.dart:940`, `eating_setup_screen.dart:849`, `class_setup_screen.dart:864`, `supplement_setup_screen.dart:114` all wire `RoutineRepository.previewRoutineImport` and have `_mode = 'Manual'` segmented controls | **UI wired; only the server-side `routineImport` callable is missing** — Task 13.3 unchanged |
| `coach_messages` / `coach_speak_log` writes not yet wired | `coach_service.dart:196,220,268` already writes both | Task 11.2 reclassified — UI/topic-mode work remains, schema is correct |
| `screen_time_logs` collection unscoped | Already exists at `/users/{uid}/screen_time_logs/{logId}` — see `screen_time_log_model.dart` and `screen_time_importer.dart:130` | Task 7.5 path corrected below |
| habit logs path mismatch | Code uses canonical flat `/users/{uid}/habit_logs/{logId}` AND legacy nested `/users/{uid}/habits/{habitId}/logs/{date}/items/{logId}` (dual-write per `habit_service.dart:7-10`) | TODO uses flat path ✓; spec (Service Contracts §3.3) is wrong vs code — code wins for v1 |
| Cloud Functions deployed list missing | `functions/index.js:60,146-149` exports `aiGenerate`, `scheduledDayClose`, `scheduledInactivityCheck`, `scheduledMorningBrief`, `scheduledMiddayPulse` | Tasks 11.6, 13.1, 13.3, 14.4, 15.2 unchanged — they add the **missing** ones |

### 10.2 Genuine gaps I missed (added below as new tasks)

| Gap | Source doc | New task |
|---|---|---|
| Per-user `coachEnabled` master kill switch with crisis-only carve-out | AI Master Engine §5.0 | **Task 14.7** below |
| Watched-conditions on-device 60-second tick timer for in-app pattern detection | AI Master Engine §1.3 | **Task 11.7** below |
| Derived fields (`bad_day_signal_count`, `routine_miss_count_7d`, `consecutive_recovery_days`) computed in `context_builder.dart` | AI Master Engine §4.4 | **Task 11.8** below |
| `cf_costMonitor` daily cost cap + `ai:global_kill_switch` + `ai:monthly_spend_usd` | AI Master Engine §1.4 | **Task 13.4** below |
| `cf_crisisAlert` Slack/email alert to ops on Tier 2/3 crisis (uid only, no PII) | AI Master Engine §1.4 | **Task 13.5** below |
| Cross-device cooldowns + per-user daily token budget — Redis (or Firestore-backed surrogate at `/users/{uid}/coach_budget/...`) | AI Master Engine §1.4, §5.4 | **Task 11.9** below |
| `addiction_logs` collection (typed: cigarettes, alcohol, weed, vape) per `addictionType` index | Database Schema §1A.1, §1A.2 | **Task 7.14** below |
| `journal_entries` collection (day-close reflections, mood notes) | Database Schema §1A.1 | **Task 7.15** below |
| `coach_review` collection for ambiguous crisis-marker review | AI Master Engine §6.2 | **Task 11.10** below |
| Speak budget tied to accountability mode: Forgiving=4, Strict=7, Ruthless=10 (currently TODO Task 11.4 says "default 5") | AI Master Engine §5.4 | **Task 11.4 amended** below |
| Per-message rate limit: 15 min minimum between any two coach messages (except crisis P1) | AI Master Engine §5.5 | **Task 11.4 amended** |
| Mandatory rule fields `prompt_template` / `example_outputs` / `fallback_message` per Rule schema | AI Master Engine §2 | **Task 11.4 amended** |
| Hardcoded `STRESS_MARKERS`, `CRISIS_MARKERS_HIGH`, `CRISIS_MARKERS_AMBIGUOUS` in Dart only | AI Master Engine §6.1, §6.2 | **Task 11.5 amended** |

### 10.3 Doc-vs-code event-name conflicts (do NOT silently rename — document the alias)

| Doc-spec event | Existing code uses | Disposition |
|---|---|---|
| `screen_time_exceeded` (AI Master Engine rules) | `bad_habit_slip_logged` with habit `screen_time_*` | Code wins; AI rule conditions read habit ID, not event name |
| `routine_window_missed` (AI Master Engine rules) | `task_abandoned` with `reason='auto_no_start'` (parent routine task) | Code wins; rules pattern-match on payload, not event name |
| `chat_user_message` (AI Master Engine D-series rules) | `coach_message_sent` (already exists in event_names.dart) | Code wins — same semantic |
| `morning_brief` / `midday_pulse_low_completion` events | None — emitted by Cloud Function but not yet in `event_names.dart` | **Add** in Task 11.6 amendment |
| `user_inactive_24h` / `user_inactive_48h` (AI Master Engine §3 F1/F2) | `ghost_day_detected` (one event with `missedDays` payload field) | Code wins — derive 24/48h triage from `missedDays` |

### 10.4 Documentation responsibility

When this list shrinks to zero, the §11.3 release-blocker bar in Task 18.3 is met. Until then, every entry above is a known divergence and must be cited in any PR that touches the affected service.

---

## Phase 7 amendment — addiction & journal collections

### Task 7.14 — `addiction_logs` typed collection (NEW — Database Schema §1A.1)

#### Status

- [ ] Not started

#### Why

Database Schema §1A.1 explicitly lists `addiction_logs` as a separate collection from generic `habit_logs`. It carries a typed `addictionType` field (cigarettes, alcohol, weed, vape, …) plus per-type metadata. The smoking tracker (Task 7.4) currently writes to `habit_logs` only — that is fine for v1 generic counters but breaks the per-addiction analytics surface and the `addictionType ASC, ts DESC` index queries the doc declares.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Decide and document whether v1 ships `addiction_logs` as its own collection OR keeps everything in `habit_logs` with a `kind='addiction'` filter. Either decision is fine — but it must be made explicit and indexed accordingly.

## Files allowed to modify

Only modify these files:

- `docs/firestore_schema_v1_mapping.md` (decision record)
- `firestore.indexes.json` (only if the decision is "separate collection")
- `lib/models/habit_log_model.dart` (add `addictionType` and per-type metadata fields ONLY if the decision is "stay in habit_logs")
- `test/services/habit_service_contract_test.dart` (assert chosen behaviour)

## Firestore paths

- `/users/{uid}/habit_logs/{logId}` (current canonical)
- `/users/{uid}/addiction_logs/{logId}` (Database Schema spec — only if adopted)

## Requirements

- Decision recorded in `docs/firestore_schema_v1_mapping.md` with rationale.
- If "stay in habit_logs": add `addictionType`, `triggerTag`, `costPerUnit` fields to the existing model with safe defaults; do NOT introduce a new collection.
- If "separate collection": add the index `addictionType ASC, ts DESC` to `firestore.indexes.json` and update Task 7.4 to write to both for back-compat during a 60-day rollout.
- Either way: update Service Contracts §3.3 deviation note in `docs/firestore_schema_v1_mapping.md`.

## Events

- `bad_habit_slip_logged` (existing) — payload may add `addictionType` field with payloadVersion bumped to 2.

## Dependencies

- Task 7.4 (Smoking tracker — depends on this decision before its real Firestore writes).

## Verification

After implementation, run:

`flutter analyze`

Also verify:

- One source of truth for cigarette logs (no dual writes unless explicitly chosen for migration window).
- Index deployed if separate collection.
- Smoking tracker reads still work after the change.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 7.4

#### How to verify

- Decision doc exists.
- Index (if applicable) deployed.
- Analyzer green.

#### Estimate

3h (decision + small edits)

#### Done Criteria

- [ ] Decision recorded with rationale.
- [ ] Code matches the decision.
- [ ] Smoking tracker (Task 7.4) updated.

---

### Task 7.15 — `journal_entries` collection + day-close reflection (NEW — Database Schema §1A.1)

#### Status

- [ ] Not started

#### Why

Database Schema §1A.1 lists `journal_entries` for day-close reflections, mood notes, and free-text capture. UF §6.10 (wind-down notification asks "Want to journal?") and §7.2 (EoD coach summary) both reference journal entries. Currently the codebase has no journal model, no screen, no Firestore writes.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Add a minimal journaling surface: model + service + screen + day-close hook.

## Files allowed to modify

Only modify these files:

- `lib/models/journal_entry_model.dart` (new)
- `lib/services/journal_service.dart` (new)
- `lib/views/journal/journal_entry_sheet.dart` (new)
- `lib/views/tabs/home_tab.dart` (EoD card "Reflect on today" → opens sheet)
- `lib/views/comeback/comeback_modal.dart` (optional one-line note on comeback)
- `firestore.indexes.json` (add `journal_entries: createdAt DESC`)
- `firestore.rules` (rules already cover via per-user wildcard)

## Firestore paths

- `/users/{uid}/journal_entries/{entryId}`

## Requirements

- Fields: `entryId, text, mood (1-10 optional), tags[], context (free|day_close|comeback|coach_prompt), createdAt, updatedAt`.
- Sheet supports add/edit; no delete from UI (preserve history; archive only).
- EoD: when `day_closed` event fires, optionally show a one-tap entry sheet.
- Comeback: optional one-line note "What's been on your mind?" — saved as a journal entry with `context='comeback'`.
- No AI generation in v1 — pure user text capture.

## Events

- `journal_entry_added` (NEW — needs validator entry per Task 2.3)
- `journal_entry_updated` (NEW)

## Dependencies

- Task 2.3 (validator for new events).

## Verification

After implementation, run:

`flutter analyze`

Also verify:

- UI: open sheet → write 1 line → save → entry visible.
- Firebase console: doc shape matches schema.
- No dependence on AI service.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 2.3

#### How to verify

- Sheet opens, saves, persists.
- Doc shape correct.

#### Estimate

4h

#### Done Criteria

- [ ] Model + service + sheet.
- [ ] Day-close hook.
- [ ] Index declared.

---

## Phase 11 amendments — coach engine corrections

### Task 11.4 (amended) — accountability-tiered speak budget + 15-min rate limit + rule schema enforcement

> This block extends Task 11.4 above. **Do not duplicate** the original task; instead, the original task's "## Requirements" must include these additional bullets:

- Speak budget by accountability mode: **Forgiving = 4, Strict = 7, Ruthless = 10** (per AI Master Engine §5.4). User-overridable as Light/Standard/Heavy.
- Per-message rate limit: **at most 1 coach message every 15 minutes** (P1 crisis exempt) per AI Master Engine §5.5.
- Rule schema validator: every rule object must declare `id, description, event, conditions, priority (1-4), cooldown_seconds, cooldown_topic, ai_intent, tone, prompt_template, example_outputs (>=2), fallback_message, suggested_actions, followup_policy`. A rule missing any field is rejected at app start.
- Cooldown topics list: per-habit (90 min), per-routine (4h), `streak_milestone` (6h), `bad_day` (6h), `inactivity` (12h), `crisis` (24h), `recovery_ack` (24h), generic (24h).

### Task 11.5 (amended) — hardcode stress / crisis markers in Dart only

> This block extends Task 11.5 above. The original task's "## Files allowed to modify" must add:

- `lib/services/coach_safety_lists.dart` (new — top-level constants for `STRESS_MARKERS`, `CRISIS_MARKERS_HIGH`, `CRISIS_MARKERS_AMBIGUOUS`).

> The original task's "## Requirements" must add:

- `STRESS_MARKERS` / `CRISIS_MARKERS_HIGH` / `CRISIS_MARKERS_AMBIGUOUS` are top-level Dart constants (per AI Master Engine §6) — **never** stored in Firestore, never remotely editable.
- Ambiguous crisis match alone fires Rule D1 (stress) AND writes to `/users/{uid}/coach_review/{reviewId}` for human pattern review.
- Ambiguous match + secondary signal (depression keywords / `user_state==relapsing 7d+` / 22:00–04:00 local) escalates to E1.

---

### Task 11.7 — Watched-conditions on-device 60s tick timer (NEW — AI Master Engine §1.3)

#### Status

- [ ] Not started

#### Why

The engine has three event sources: reactive (Firestore stream, <30s), watched (local 60s tick, in-app), scheduled (Cloud Function). Watched-conditions are the path for "Mission ring 0% with 90 min left in day" — needs the user's local clock + battery state, can't be done server-side.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Add a 60-second on-device tick timer that re-evaluates watched conditions while the app is foreground.

## Files allowed to modify

Only modify these files:

- `lib/services/watched_conditions_service.dart` (new)
- `lib/services/rule_engine_service.dart` (register watched-eval entry point)
- `lib/main.dart` (start/stop timer with app lifecycle)

## Firestore paths

- read `/users/{uid}/profile/main.coachEnabled` (Task 14.7) — skip tick if false
- read live state (cached from Riverpod providers); no extra reads per tick

## Requirements

- Timer ticks every 60 seconds while app foreground; no work in background.
- Each tick: read cached `ContextSnapshot`, evaluate watched-only rules, fire if eligible.
- Battery-aware: skip tick when battery < 20% AND not charging.
- Pause when `coachEnabled=false`.
- Respect existing speak budget + cooldowns.

## Events

- (no new events — fires the same `coach_*` and `suggestion_*` events the rule engine fires)

## Dependencies

- Task 11.4 (rule engine), Task 14.7 (coachEnabled flag).

## Verification

After implementation, run `flutter analyze`. Also verify: timer starts on foreground, stops on background, skips when coach disabled, doesn't spam Firestore.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 11.4, Task 14.7

#### How to verify

- Foreground tick logs every 60s.
- Background pauses.
- Coach disabled pauses.
- No bursty Firestore reads.

#### Estimate

4h

#### Done Criteria

- [ ] Timer service.
- [ ] Lifecycle hooks.
- [ ] Battery guard.

---

### Task 11.8 — Derived fields in context builder (NEW — AI Master Engine §4.4)

#### Status

- [ ] Not started

#### Why

Multi-event rules (`bad_day_pattern`, `recovery_acknowledgment`, `stuck_routine`) read `derived.bad_day_signal_count`, `derived.routine_miss_count_7d`, `derived.consecutive_recovery_days`. These are computed in `context_builder.dart` from raw events — not stored. Without them, multi-event rules cannot fire.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Add derived-field pure functions to the context builder.

## Files allowed to modify

Only modify these files:

- `lib/services/state_aggregator_service.dart`
- `lib/models/context_snapshot.dart`
- `test/services/context_snapshot_test.dart` (new)

## Firestore paths

- read `/users/{uid}/events_recent` (last 7 days; client-side computation)

## Requirements

- `derived.bad_day_signal_count(events, today)` — count of negative signals: routine completion <40%, slip 2+, screen time >200% cap, mission <25% by midday, stress markers, 3+ task abandonments, sleep <5h.
- `derived.routine_miss_count_7d(events, routineType)` — count of `task_abandoned` for routineType in last 7d.
- `derived.consecutive_recovery_days(events, today)` — count of trailing days meeting recovery threshold.
- All pure functions — unit-testable with synthetic event sequences.
- Add to `ContextSnapshot` as a `derived: Map<String, dynamic>` map.

## Events

- (read-only)

## Dependencies

- Task 9.G1 (state aggregator hardening), Task 11.4.

## Verification

`flutter test test/services/context_snapshot_test.dart` — synthetic event sequences produce correct derived counts.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 9.G1, Task 11.4

#### How to verify

- Unit tests for each derived field.

#### Estimate

4h

#### Done Criteria

- [ ] All 3 derived functions.
- [ ] ContextSnapshot exposes `derived` map.
- [ ] Tests cover each.

---

### Task 11.9 — Cross-device cooldown ledger (NEW — AI Master Engine §1.4)

#### Status

- [ ] Not started

#### Why

Per AI Master Engine, cooldowns and per-user daily token budgets need to be enforced across devices for the same user. Recommended store: Redis. Acceptable v1 surrogate: Firestore at `/users/{uid}/coach_budget/{date}` with read/write throttled and counter-incremented via transaction.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Implement a cross-device cooldown + token-budget ledger for the coach engine. v1 uses Firestore (Redis is a Phase 19 upgrade only when daily reads cross ~100M).

## Files allowed to modify

Only modify these files:

- `functions/jobs/coachBudget.js` (new — cap enforcement helper)
- `lib/services/coach_service.dart` (read budget before client-side decision)
- `firestore.rules` (carve out `coach_budget` server-only writes)

## Firestore paths

- `/users/{uid}/coach_budget/{date}` document with fields: `tokensUsedToday, messagesSentToday, lastSpokeAt, cooldownUntil: { topic: timestamp }`.

## Requirements

- Read budget in `cf_aiGenerate` before LLM call; reject if exhausted.
- Update budget atomically in a transaction after each successful generation.
- Cooldown topics keyed map; per-topic timestamp; engine reads server-side or via client snapshot (cached for 60s to avoid hot reads).
- Documented Redis migration path in `docs/scaling_plan.md` for when Firestore reads cross threshold.

## Events

- `notification_suppressed` (with `reason='budget_full'` or `reason='cooldown'`).

## Dependencies

- Task 11.1, Task 11.4.

## Verification

Hit budget cap → next generation rejected with friendly server error.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 11.1, 11.4

#### How to verify

- Cap enforcement.
- Migration path documented.

#### Estimate

1 day

#### Done Criteria

- [ ] Firestore ledger.
- [ ] Server enforcement.
- [ ] Migration plan doc.

---

### Task 11.10 — `coach_review` collection for ambiguous-crisis review (NEW — AI Master Engine §6.2)

#### Status

- [ ] Not started

#### Why

Ambiguous crisis markers ("disappear", "no future", etc.) fire Rule D1 (stress) but also write to `coach_review` for human pattern review. Without this, false negatives become invisible.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Add the `coach_review` collection writes when an ambiguous crisis marker is matched alone.

## Files allowed to modify

Only modify these files:

- `lib/services/coach_service.dart`
- `lib/services/coach_safety_lists.dart` (created in Task 11.5)
- `firestore.rules` (server-only read; client-only write of own uid)

## Firestore paths

- `/users/{uid}/coach_review/{reviewId}` with fields: `reviewId, matchedTokens[], context (last 3 user messages), userState, ts`.

## Requirements

- Ambiguous-only match → write a review row + fire D1 (already in Task 11.4).
- Ambiguous + secondary signal → escalate to E1 (Task 11.5) and DO write a review row too.
- No PII beyond what the user typed; review row is per-user-private.

## Events

- (none new — review collection is data only.)

## Dependencies

- Tasks 11.4, 11.5.

## Verification

Type ambiguous phrase → no E1 card → review row written.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 11.4, 11.5

#### How to verify

- Review row appears for ambiguous matches.

#### Estimate

3h

#### Done Criteria

- [ ] Collection writes.
- [ ] Rules carve-out.

---

## Phase 13 amendments — cost monitor + crisis alert

### Task 13.4 — `cf_costMonitor` daily Cloud Function (NEW)

#### Status

- [ ] Not started

#### Why

AI Master Engine §1.4 requires a daily aggregator that sums coach LLM spend across all users and toggles `ai:global_kill_switch` if a monthly cap is breached. Without this, a single bug or abusive user can run the bill to thousands of dollars overnight.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Build the cost-monitor scheduled Cloud Function.

## Files allowed to modify

Only modify these files:

- `functions/jobs/costMonitor.js` (new)
- `functions/index.js`
- `functions/test/costMonitor.contract.test.js` (new)

## Firestore paths

- read `/users/{uid}/coach_speak_log` aggregate counts
- write `/app_config/global_kill_switch` (read-only for clients)
- write `/app_config/monthly_spend_usd`

## Requirements

- Pub/Sub schedule: daily 02:00 UTC.
- Aggregates `tokensUsed` across all `coach_speak_log` entries for the current month.
- Computes USD using configured per-1k-tokens rate from `/app_config/llm_pricing`.
- Toggles `global_kill_switch=true` if monthly cap breached.
- Sends Slack alert (via webhook stored in functions config) if 80% / 100% of cap.

## Events

- (none new — switches a config flag.)

## Dependencies

- Task 11.1.

## Verification

Emulator: seed speak logs above cap → run job → kill switch flipped.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Task 11.1

#### How to verify

- Cap breach → switch flips.

#### Estimate

4h

#### Done Criteria

- [ ] Job scheduled.
- [ ] Cap enforced.
- [ ] Slack alert.

---

### Task 13.5 — `cf_crisisAlert` Slack/email alert on Tier 2/3 crisis (NEW)

#### Status

- [ ] Not started

#### Why

AI Master Engine §1.4: when a Tier 2/3 crisis fires, an off-app alert must reach ops within minutes. Cannot rely on the client to deliver; must be server-driven on a Firestore trigger.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Build the crisis-alert Firestore trigger.

## Files allowed to modify

Only modify these files:

- `functions/jobs/crisisAlert.js` (new)
- `functions/index.js`

## Firestore paths

- trigger on writes to `/users/{uid}/coach_speak_log/{logId}` where `crisisTier in ['T2', 'T3']`
- read `/crisis_handoffs/{handoffId}` (admin-only, already in rules)

## Requirements

- Send Slack webhook + email with: `uid`, tier, ts, ruleId. NO PII (no email, no name, no message text).
- Idempotent on `logId` (don't re-alert on retry).
- Document the Slack channel and on-call rotation in `docs/oncall.md`.

## Events

- (none new.)

## Dependencies

- Tasks 11.1, 11.5.

## Verification

Emulator: seed Tier 3 row → alert posted.

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 11.1, 11.5

#### How to verify

- Trigger fires; Slack receives.

#### Estimate

3h

#### Done Criteria

- [ ] Trigger.
- [ ] Slack alert.
- [ ] No PII.

---

## Phase 14 amendment — coachEnabled per-user kill switch

### Task 14.7 — Per-user `coachEnabled` master kill switch (NEW — AI Master Engine §5.0)

#### Status

- [ ] Not started

#### Why

AI Master Engine §5.0 explicitly elevates `coachEnabled` to a top-level user setting: when off, the coach is **silent** (Gate 0 in `evaluate()`), with one carve-out — Crisis E1/E2/E3 still fire. Currently `coachEnabled` exists only as a **global** Remote Config flag in `remote_config_service.dart` line 5; there is no per-user override at `profile/main.coachEnabled`.

#### What to tell Gemini CLI / Antigravity

```text
Use `.gemini/GEMINI.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

## Task

Add the per-user `coachEnabled` flag and Gate 0 enforcement.

## Files allowed to modify

Only modify these files:

- `lib/models/user_model.dart` (add `coachEnabled: bool, default true`)
- `lib/services/coach_service.dart` (Gate 0 — return immediately if false)
- `lib/services/rule_engine_service.dart` (Gate 0)
- `lib/services/watched_conditions_service.dart` (Gate 0)
- `lib/views/settings/coach_settings_screen.dart` (toggle + 1-tap re-enable)
- `lib/views/tabs/coach_tab.dart` ("Coach is paused" placeholder + composer disabled)
- `functions/jobs/morningBrief.js`, `middayPulse.js`, `dayClose.js`, `inactivityCheck.js` (skip user if false)
- `lib/services/notification_service.dart` (cancel coach-source notifications on flip-off)
- `lib/core/constants/event_names.dart` (add `coachReEnabled = 'coach_re_enabled'`)
- `lib/services/event_payload_validator.dart`

## Firestore paths

- `/users/{uid}/profile/main.coachEnabled`

## Requirements

- Default true on new accounts.
- When false: no rule eval, no LLM call, no coach push, no proactive coach bubble; log no "drop" event (silent).
- Crisis E1/E2/E3 carve-out: still fires regardless. Static, non-LLM message.
- Toggle from Coach settings (Task 14.2) emits `coach_settings_changed`.
- Re-enable: starts fresh (no backlog replay); emit `coach_re_enabled` event.
- Optional: morning-brief welcome-back message gated by separate "no welcome back" toggle.

## Events

- `coach_settings_changed` (existing)
- `coach_re_enabled` (NEW — needs validator entry)

## Dependencies

- Task 11.4, Task 11.5, Task 14.2.

## Verification

After implementation, run:

`flutter analyze`

Also verify:

- Toggle OFF → speak no proactive messages for 24h.
- Toggle OFF → user types crisis phrase → E1 still fires.
- Toggle ON → fresh start, no backlog replay.
- Cloud Functions skip user when false (logs reason).

## Final response format

Return: 1. Files inspected 2. Files changed 3. Summary of changes 4. Firestore paths affected 5. Events implemented or skipped 6. Analyzer result 7. Remaining risks or missing dependencies
```

#### Dependencies

- Tasks 11.4, 11.5, 14.2

#### How to verify

- Toggle off → silence (proven).
- Crisis still fires.
- Functions skip user.

#### Estimate

1 day

#### Done Criteria

- [ ] Per-user flag.
- [ ] Gate 0 in client + functions.
- [ ] Crisis carve-out.
- [ ] Re-enable fresh.

---

## 9. File Output

This file IS the deliverable: `todo_V1_(fixed)_All_Features.md`.

It contains:

1. Short summary
2. Existing TODO file audit
3. Codebase analysis
4. Document coverage analysis
5. User flow breakdown
6. Dependency map
7. Phase-wise master TODO list (Phases 0–18, ~60 tasks)
8. Completeness matrix
9. This output marker

Every task includes:
- the planning-mode preamble for Gemini CLI / Antigravity
- exact files allowed to modify
- exact Firestore paths
- exact event names
- explicit dependencies
- a verification checklist
- a final response format requirement
- estimate
- per-task done criteria

Use this file as the single source of truth from now on. When a task closes, set its Status to `Done (YYYY-MM-DD)` and tick the Done Criteria — do not delete the entry.
