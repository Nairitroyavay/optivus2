# Optivus V2 Final Play Store TODO

Audit date: 2026-05-08

This is the single master roadmap for Optivus V2 MVP completion and Play Store internal testing readiness. Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the permanent project rules for every task.

This file is the only active implementation TODO. V1, older TODOs, audits, and product docs have been consumed as historical checklist input and must not be used as implementation references after this file. If a requirement matters for V2, it is copied directly into a task below.

Non-negotiable architecture result: Optivus remains Firebase Spark-only. Do not add Firebase Functions, Firebase Storage, Firebase Hosting/App Hosting, Google Maps API, Google Cloud billing services, Google Cloud Vision, Cloud Run, Cloud Build, Artifact Registry, or Google Cloud Secrets Manager. Use Cloudflare Workers for backend/AI, Cloudflare R2 for files/images, Cloudflare Pages for legal/support pages, Mapbox for maps, and Flutter assets for meditation audio.

# Phase 1 — Final MVP Completion + Play Store Readiness

### Task 1.1 — Spark-only guardrail scan and legacy service labeling

#### Status

- [x] Completed

#### Priority

P0 — Blocks all work

#### Depends on

None

#### Blocks

Most downstream implementation tasks

#### Why

Every implementation task must start from a repo state that cannot accidentally revive Blaze-only Firebase or Google Cloud billing paths.

#### Current code evidence

- `docs/OPTIVUS_STRICT_TASK_RULES.md` defines the permanent Spark-only rules.
- `firebase.json` deploys Firestore rules/indexes only.
- `storage.rules` exists but is intentionally inactive and not referenced by `firebase.json`.
- `functions/index.js`, `functions/jobs/*`, and `functions/ai/coachReply.js` still contain Firebase Functions source.
- `GEMINI.md`, `docs/implementation_inventory.md`, and superseded planning files contain legacy Cloud Functions and Firebase Storage wording.

#### Gap

There is no reliable pre-work/pre-release guardrail scan that distinguishes inactive legacy reference code from forbidden active dependencies, and comments still mention Cloud Functions in active files.

#### Spec source

Inferred from Spark-only architecture requirement; `docs/OPTIVUS_STRICT_TASK_RULES.md`; audit finding.

#### Build order prerequisite

None

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Create a Spark-only guardrail scan/checklist that future agents can run before implementation and release. Label `functions/` as inactive legacy reference or queue removal; do not port it back to Firebase Functions.
Files to inspect first: docs/OPTIVUS_STRICT_TASK_RULES.md, firebase.json, pubspec.yaml, firestore.rules, storage.rules, .gitignore, GEMINI.md, docs/, functions/, workers/.
Files allowed to modify: todo/docs/scripts only; no Flutter feature code.
Firestore paths: None.
R2 paths: None.
Cloudflare Worker endpoints: None.
Feature flags: None.
Requirements: scan for active forbidden packages, deploy configs, manifest keys, billing services, Firebase Storage wording, Google Maps wording, and Cloud Functions wording; allow clearly inactive legacy references only if labeled.
Events: None.
Verification: run the guardrail scan; confirm no active forbidden dependency or deploy target exists.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `docs/spark_cloudflare_architecture.md`
- `docs/implementation_inventory.md`
- `GEMINI.md`
- optional local guardrail script or checklist under `docs/`
- `docs/spark_only_guardrail_scan.md`
- `scripts/spark_guardrail_scan.py`

#### Firestore paths

None

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

None

#### Dependencies

Read-only repo audit and documentation updates.

#### How to verify

- Automated: run the new scan/checklist and confirm forbidden active references fail the check.
- Manual: inspect `firebase.json`, `pubspec.yaml`, Android manifest, Workers, and legacy `functions/` labels.

#### Estimate

0.5 day

#### Done Criteria

- [x] Active forbidden services are scanned.
- [x] Legacy `functions/` status is unambiguous.
- [x] Firebase Storage and Google Maps wording is not implementation guidance.
- [x] No app feature code is edited.

### Task 1.2 — Establish build, test, and QA baseline

#### Status

- [x] Completed

#### Priority

P0 — Blocks all work

#### Depends on

1.1

#### Blocks

Tasks 1.3-1.51

#### Why

Future implementation tasks need a known analyzer/test/build baseline so regressions are visible and not hidden behind existing failures.

#### Current code evidence

- `analysis_options.yaml` exists.
- `test/services/*_contract_test.dart` and `test/providers/routine_notifier_test.dart` exist.
- `workers/routine-import-worker/test/routineImport.contract.test.js` exists.
- `android/app/build.gradle.kts` still uses debug signing and `com.example.optivus`.
- `lib/views/tabs/profile_tab.dart` has a known analyzer/compile blocker reported as a duplicate `emptyLabel` parameter.

#### Gap

The TODO did not define a single release QA command matrix with current pass/fail status, skipped tests, Worker test commands, release build command, device checks, Spark-only scan, and current analyzer/compile blockers that must be cleared before feature work.

Resolved 2026-05-09: `docs/build_test_qa_baseline.md` now records the baseline command matrix, dart-define dimensions, skipped tests, Worker test status, Android release build result, and real-device smoke checklist.

#### Spec source

Inferred from Play Store readiness requirement; audit finding.

#### Build order prerequisite

1.1

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Create the baseline build/test/QA matrix for the current repo, and fix any current analyzer/compile blocker before feature work. Specifically verify and resolve the `lib/views/tabs/profile_tab.dart` duplicate `emptyLabel` parameter blocker before starting downstream feature tasks.
Files to inspect first: pubspec.yaml, analysis_options.yaml, test/, workers/*/package.json, android/app/build.gradle.kts, docs/.
Files allowed to modify: docs and TODO/checklist files for the baseline; minimal code/config edits only if required to clear a current analyzer/compile blocker before feature work.
Firestore paths: None.
R2 paths: None.
Cloudflare Worker endpoints: None.
Feature flags: all existing dart-define flags must be listed as test dimensions.
Requirements: document commands for flutter analyze, flutter test, Worker tests, Spark-only scan, Android release build, and real-device smoke tests; record current known blockers/skipped tests; analyzer/compile blockers must be fixed before feature implementation tasks begin.
Events: None.
Verification: run only safe local commands; do not deploy Firebase or Cloudflare.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `docs/`
- `todo_V2_Final_PlayStore_Single_Phase.md` if baseline findings change task ordering
- `android/settings.gradle.kts` for Android Gradle Plugin baseline compatibility
- `android/gradle/wrapper/gradle-wrapper.properties` for Gradle wrapper baseline compatibility

#### Firestore paths

None

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

None

#### Dependencies

Flutter SDK, Node/npm for Worker tests, Android Gradle toolchain.

#### How to verify

- Automated: run documented safe baseline commands where possible.
- Manual: record commands that cannot be run locally and why.

#### Estimate

0.5 day

#### Done Criteria

- [x] Baseline analyzer/test/build status is documented.
- [x] Current analyzer/compile blockers are fixed before feature work, including verification that `profile_tab.dart` no longer has a duplicate `emptyLabel` parameter.
- [x] Skipped or missing tests are listed.
- [x] Worker test commands are documented.
- [x] No deploy command is run.

### Task 1.3 — Centralize shared config, feature flags, and kill switches

#### Status

- [x] Completed

#### Priority

P1 — Blocks many features

#### Depends on

1.2

#### Blocks

Most downstream implementation tasks that use feature flags, kill switches, Worker endpoints, R2, Mapbox, notifications, AI, or release QA

#### Why

Backend, R2, Mapbox, AI, and risky trackers must fail closed with manual fallbacks so release can disable features without app updates.

#### Current code evidence

- `lib/core/config/feature_flags.dart` defines dart-define flags for R2/image/AI coach.
- `lib/services/remote_config_service.dart` defines Remote Config keys but defaults AI flags to enabled.
- `lib/services/gemini_service.dart`, `lib/repositories/routine_repository.dart`, and `lib/services/r2_upload_service.dart` read endpoints directly from dart defines.
- `lib/main.dart` initializes Remote Config.

#### Gap

Resolved 2026-05-09: shared client config now centralizes dart-define
endpoints, compile-time feature flags, Remote Config kill switches, R2
endpoints, and Mapbox token state. Risky AI/R2/image features default off and
require both Remote Config and endpoint/compile gates before use.

#### Spec source

Spark-only architecture requirement; actual code file audit.

#### Build order prerequisite

1.1, 1.2

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Centralize app config and release-safe kill switches for Cloudflare endpoints, R2 uploads, Mapbox, AI, notifications, FCM/App Check optional features, and tracker imports.
Files to inspect first: lib/core/config/feature_flags.dart, lib/services/remote_config_service.dart, lib/main.dart, lib/core/providers.dart, lib/services/gemini_service.dart, lib/repositories/routine_repository.dart, lib/services/r2_upload_service.dart.
Files allowed to modify: config/providers/services related to feature flags; focused tests.
Firestore paths: None.
R2 paths: None.
Cloudflare Worker endpoints: ROUTINE_IMPORT_ENDPOINT, COACH_REPLY_ENDPOINT, AI_GENERATE_ENDPOINT, R2_SIGNED_UPLOAD_ENDPOINT, R2_DELETE_UPLOAD_ENDPOINT.
Feature flags: all existing flags plus any Remote Config kill switches needed; unsafe flags default off for release.
Requirements: no secrets in Flutter; missing endpoints show fallback/Coming Soon; manual/text flows keep working.
Events: optional notification_suppressed or suggestion_dismissed only if already supported.
Verification: flutter analyze, focused config tests, manual launch with flags off.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/core/config/feature_flags.dart`
- `lib/services/remote_config_service.dart`
- `lib/core/providers.dart`
- targeted service tests

#### Firestore paths

None

#### R2 paths

None

#### Cloudflare Worker endpoints

- `ROUTINE_IMPORT_ENDPOINT`
- `COACH_REPLY_ENDPOINT`
- `AI_GENERATE_ENDPOINT`
- `R2_SIGNED_UPLOAD_ENDPOINT`
- `R2_DELETE_UPLOAD_ENDPOINT`

#### Events

None

#### Dependencies

Firebase Remote Config SDK, dart-define values, existing provider graph.

#### How to verify

- Automated: focused unit tests for defaults and kill-switch precedence.
- Manual: run app with all AI/R2/Mapbox flags absent and confirm fallbacks.

#### Estimate

1 day

#### Done Criteria

- [x] All risky features have explicit off states.
- [x] Release defaults do not require paid Google services.
- [x] Missing Cloudflare endpoints do not crash manual flows.
- [x] Flags are documented in QA matrix.

### Task 1.4 — Create a Cloudflare API service contract in Flutter

#### Status

- [x] Completed

#### Priority

P1 — Blocks many features

#### Depends on

1.3

#### Blocks

Worker-backed import, upload, AI coach, R2, and Worker test tasks

#### Why

Cloudflare calls are duplicated across AI, routine import, and R2 services. A common client contract reduces auth/header/error handling bugs.

#### Current code evidence

- `lib/services/gemini_service.dart` implements private authenticated POST logic.
- `lib/repositories/routine_repository.dart` posts to `ROUTINE_IMPORT_ENDPOINT`.
- `lib/services/r2_upload_service.dart` posts to R2 signed upload/delete endpoints.

#### Gap

Resolved 2026-05-09: `CloudflareApiService` now centralizes Firebase ID
token acquisition, JSON headers, endpoint validation, timeouts, typed errors,
and HTTP status mapping for Worker calls.

#### Spec source

Required Worker Pattern in `docs/OPTIVUS_STRICT_TASK_RULES.md`; audit finding.

#### Build order prerequisite

1.3

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Add a small shared Cloudflare API client/service and migrate only duplicated request/auth/error handling, preserving existing feature behavior.
Files to inspect first: lib/services/gemini_service.dart, lib/repositories/routine_repository.dart, lib/services/r2_upload_service.dart, lib/core/providers.dart, test/services/*.
Files allowed to modify: new Cloudflare API service, existing services that call Workers, focused tests.
Firestore paths: None.
R2 paths: None.
Cloudflare Worker endpoints: ROUTINE_IMPORT_ENDPOINT, COACH_REPLY_ENDPOINT, AI_GENERATE_ENDPOINT, R2_SIGNED_UPLOAD_ENDPOINT, R2_DELETE_UPLOAD_ENDPOINT.
Feature flags: use Task 1.3 config path.
Requirements: Firebase ID token in Authorization header; no API keys in Flutter; typed network/auth/config errors; no server writes unless already designed.
Events: None.
Verification: flutter analyze and focused service tests with mocked HTTP/auth.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/services/cloudflare_api_service.dart`
- `lib/services/gemini_service.dart`
- `lib/repositories/routine_repository.dart`
- `lib/services/r2_upload_service.dart`
- focused tests

#### Firestore paths

None

#### R2 paths

None

#### Cloudflare Worker endpoints

- `ROUTINE_IMPORT_ENDPOINT`
- `COACH_REPLY_ENDPOINT`
- `AI_GENERATE_ENDPOINT`
- `R2_SIGNED_UPLOAD_ENDPOINT`
- `R2_DELETE_UPLOAD_ENDPOINT`

#### Events

None

#### Dependencies

Firebase Auth ID token and `http` package.

#### How to verify

- Automated: mocked HTTP success, 401, 429, 500, missing endpoint, unauthenticated user.
- Manual: confirm disabled endpoints show existing fallbacks.

#### Estimate

1 day

#### Done Criteria

- [x] Worker calls share auth/header/error behavior.
- [x] Existing contracts are preserved.
- [x] No secrets are introduced.
- [x] Focused tests cover failure paths.

### Task 1.5 — Make event names, payloads, and rule-engine inputs consistent

#### Status

- [ ] Not started

#### Priority

P1 — Blocks many features

#### Depends on

1.2

#### Blocks

Tasks 1.6, 1.7, 1.25, 1.33, 1.34, and release observability tasks that rely on canonical event names

#### Why

The coach, notifications, identity scoring, day lifecycle, and analytics depend on reliable events.

#### Current code evidence

- `lib/core/constants/event_names.dart` defines canonical events.
- `lib/services/event_payload_validator.dart` validates many events.
- `lib/services/event_service.dart` writes `events` and `events_recent`.
- `lib/core/event_orchestrator.dart` handles many events but has TODOs.
- `lib/services/rule_engine_service.dart` references `routine_window_missed`, which is not in `EventNames`.

#### Gap

Event names, validator requirements, payload field names, rule-engine rule inputs, and emitted event payloads are not fully aligned.

#### Spec source

Codebase audit; historical event-system requirements already merged into this task; Play Store readiness.

#### Build order prerequisite

1.2

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Align event constants, payload validator rules, emitters, and rule-engine input event names.
Files to inspect first: lib/core/constants/event_names.dart, lib/services/event_payload_validator.dart, lib/services/event_service.dart, lib/core/event_orchestrator.dart, lib/services/rule_engine_service.dart, test/services/event_service_contract_test.dart, test/services/rule_engine_service_contract_test.dart.
Files allowed to modify: event constants, validator, event emitters/listeners, focused tests.
Firestore paths: /users/{uid}/events/{eventId}, /users/{uid}/events_recent/{eventId}, /users/{uid}/coach_speak_log/{logId}.
R2 paths: None.
Cloudflare Worker endpoints: None.
Feature flags: None.
Requirements: no unknown production events; stable snake_case names; validator covers all emitted events; rule-engine event names exist; no duplicate side effects on replay.
Events: all canonical events touched by this task.
Verification: event and rule engine tests; manual event emission trace.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/core/constants/event_names.dart`
- `lib/services/event_payload_validator.dart`
- `lib/core/event_orchestrator.dart`
- `lib/services/rule_engine_service.dart`
- event/rule tests

#### Firestore paths

- `/users/{uid}/events/{eventId}`
- `/users/{uid}/events_recent/{eventId}`
- `/users/{uid}/coach_speak_log/{logId}`

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

All emitted events; especially `routine_window_missed`, `screen_time_synced`, `coach_replied`, `suggestion_generated`, `notification_missed`, `comeback_*`, and fitness events.

#### Dependencies

Firestore schema and event tests.

#### How to verify

- Automated: event service, payload validator, rule engine tests.
- Manual: trigger task, habit, screen-time, day-close, and coach flows and inspect event payloads.

#### Estimate

1 day

#### Done Criteria

- [ ] No emitted event is missing from validator.
- [ ] Rule engine references only canonical events.
- [ ] Payload names are consistent.
- [ ] Tests cover unknown and malformed events.

### Task 1.6 — Harden Firestore schema, rules, indexes, and data ownership

#### Status

- [ ] Not started

#### Priority

P1 — Blocks many features

#### Depends on

1.2, 1.5

#### Blocks

Most data-model, routine, auth, tracker, privacy/account lifecycle, and release QA tasks

#### Why

Firestore is the Spark-only source of truth. Rules and indexes must match actual paths before release.

#### Current code evidence

- `firestore.rules` has broad owner access for many user subcollections.
- `firestore.rules` comments say `events_recent` trimming is done by Cloud Functions.
- `docs/firestore_schema_v1_mapping.md` lists canonical paths and indexes.
- `lib/services/firestore_service.dart` defines `userOwnedCollectionIds`.
- `firestore.indexes.json` exists.

#### Gap

Rules, comments, indexes, path docs, and service constants are not fully reconciled with current features, nested fitness route data, deletion/export requests, suggestions, usage, and notification logs.

#### Spec source

Actual code file; Firestore schema docs; audit finding.

#### Build order prerequisite

1.2, 1.5

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Reconcile Firestore paths, rules, indexes, and schema docs for the MVP.
Files to inspect first: firestore.rules, firestore.indexes.json, docs/firestore_schema_v1_mapping.md, lib/services/firestore_service.dart, lib/services/*, lib/repositories/*, test/services/*.
Files allowed to modify: firestore.rules, firestore.indexes.json, schema docs, focused rules/schema tests if present.
Firestore paths: all /users/{uid} subcollections, /app_config/{doc}, /crisis_handoffs/{doc}.
R2 paths: None.
Cloudflare Worker endpoints: None.
Feature flags: None.
Requirements: no Cloud Functions comments in active rules; owner-only access; events append-only; data_exports/deletion_requests create-only; indexes cover documented queries; no large images/base64 in Firestore.
Events: all canonical event envelope writes.
Verification: rules/index review, flutter tests that depend on paths, safe local rules checks if available.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `firestore.rules`
- `firestore.indexes.json`
- `docs/firestore_schema_v1_mapping.md`
- focused tests

#### Firestore paths

- `/users/{uid}`
- `/users/{uid}/{collection}/{doc}`
- `/users/{uid}/events/{eventId}`
- `/users/{uid}/events_recent/{eventId}`
- `/users/{uid}/data_exports/{exportId}`
- `/users/{uid}/deletion_requests/{requestId}`
- `/users/{uid}/fitnessActivities/{activityId}/routePoints/{pointId}`
- `/app_config/{doc}`
- `/crisis_handoffs/{doc}`

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

All event envelope documents.

#### Dependencies

Firestore rules/index deploy is allowed only as `firebase deploy --only firestore:rules,firestore:indexes`, but do not deploy in this task unless separately requested.

#### How to verify

- Automated: rules/schema tests if available; `flutter test` for affected services.
- Manual: review each service query against indexes and rules.

#### Estimate

1 day

#### Done Criteria

- [ ] Active Firestore comments are Spark-only.
- [ ] Schema docs match service constants.
- [ ] Indexes match current queries.
- [ ] Export/delete request paths are explicit and safe.

### Task 1.7 — Fill core model contract gaps

#### Status

- [ ] Not started

#### Priority

P1 — Blocks many features

#### Depends on

1.6

#### Blocks

Routine import, suggestion, account lifecycle, and release QA tasks that need typed model contracts

#### Why

Several screens use raw maps because models are missing. Typed models are needed before suggestion, routine import, AI, and release QA work scales.

#### Current code evidence

- `lib/core/providers.dart` returns raw maps from `trackerSuggestionsProvider`.
- `docs/implementation_inventory.md` lists missing `SuggestionModel`, routine import result model, and full routine template model.
- `lib/views/routine/widgets/routine_review_screen.dart` normalizes raw template maps.
- `lib/repositories/routine_repository.dart` returns `List<Map<String, dynamic>>` for imports.

#### Gap

Suggestion, routine import preview, routine template, AI usage, and some account lifecycle shapes are map-based and not validated consistently.

#### Spec source

Audit finding; `docs/implementation_inventory.md`; `docs/firestore_schema_v1_mapping.md`.

#### Build order prerequisite

1.6

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Add minimal typed model contracts for suggestions, routine import previews, routine templates, usage records, and account export/delete request status where they are currently raw maps.
Files to inspect first: lib/models/, lib/core/providers.dart, lib/repositories/routine_repository.dart, lib/views/routine/widgets/routine_review_screen.dart, docs/firestore_schema_v1_mapping.md.
Files allowed to modify: model files, serializers, focused tests, narrow call sites that consume the new models.
Firestore paths: /users/{uid}/suggestions/{suggestionId}, /users/{uid}/routine/current, /users/{uid}/usage/{monthKey}, /users/{uid}/data_exports/{exportId}, /users/{uid}/deletion_requests/{requestId}.
R2 paths: None.
Cloudflare Worker endpoints: ROUTINE_IMPORT_ENDPOINT if model contract is parsed.
Feature flags: None.
Requirements: extend existing patterns; no broad rewrites; preserve backward compatibility with old map fields.
Events: suggestion_generated, suggestion_accepted, suggestion_dismissed if model is touched.
Verification: serialization tests and existing Flutter tests.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/models/suggestion_model.dart`
- `lib/models/routine_template_model.dart`
- `lib/models/routine_import_preview_model.dart`
- existing consumers and focused tests

#### Firestore paths

- `/users/{uid}/suggestions/{suggestionId}`
- `/users/{uid}/routine/current`
- `/users/{uid}/usage/{monthKey}`
- `/users/{uid}/data_exports/{exportId}`
- `/users/{uid}/deletion_requests/{requestId}`

#### R2 paths

None

#### Cloudflare Worker endpoints

- `ROUTINE_IMPORT_ENDPOINT`

#### Events

- `suggestion_generated`
- `suggestion_accepted`
- `suggestion_dismissed`

#### Dependencies

Event and Firestore schema alignment.

#### How to verify

- Automated: model from/to Firestore/map tests.
- Manual: inspect saved routine templates and suggestions in Firestore.

#### Estimate

1 day

#### Done Criteria

- [ ] Raw map contracts are reduced at critical boundaries.
- [ ] Backward compatibility is preserved.
- [ ] Serialization tests cover missing/legacy fields.

### Task 1.8 — Reconcile routine template schema and materialization

#### Status

- [ ] Not started

#### Priority

P1 — Blocks many features

#### Depends on

1.7

#### Blocks

None

#### Why

Routine templates drive timeline tasks, reminders, day summaries, and manual/AI setup flows.

#### Current code evidence

- `lib/providers/routine_provider.dart` contains large routine state and materialization logic.
- `lib/repositories/routine_repository.dart` writes `/users/{uid}/routine/current`.
- `lib/services/routine_service.dart` materializes `templates` on day start.
- `lib/services/task_service.dart` syncs routine tasks and emits `task_scheduled`.
- `docs/firestore_schema_v1_mapping.md` documents template fields.

#### Gap

Template schema, legacy fixed block fields, `status` vs `state`, repeat handling, one-off custom tasks, and materialization idempotency are spread across provider, repository, and service code.

#### Spec source

Actual code; schema docs; audit finding.

#### Build order prerequisite

1.6, 1.7

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Reconcile routine template schema and idempotent materialization for fixed, skin, supplements, classes, eating, and custom templates.
Files to inspect first: lib/providers/routine_provider.dart, lib/repositories/routine_repository.dart, lib/services/routine_service.dart, lib/services/task_service.dart, lib/models/task_model.dart, docs/firestore_schema_v1_mapping.md.
Files allowed to modify: routine provider/repository/service/model adapters and focused tests only.
Firestore paths: /users/{uid}/routine/current, /users/{uid}/tasks/{taskId}, /users/{uid}/task_outcomes/{taskId}, /users/{uid}/events/{eventId}.
R2 paths: None.
Cloudflare Worker endpoints: None.
Feature flags: None.
Requirements: templates write canonical fields; materialization is idempotent; terminal task state is never overwritten; both state/status compatibility is handled during migration.
Events: task_scheduled, routine_template_created, routine_template_updated, routine_template_deleted if supported.
Verification: routine provider/service tests and manual today/tomorrow timeline check.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/providers/routine_provider.dart`
- `lib/repositories/routine_repository.dart`
- `lib/services/routine_service.dart`
- `lib/services/task_service.dart`
- routine tests

#### Firestore paths

- `/users/{uid}/routine/current`
- `/users/{uid}/tasks/{taskId}`
- `/users/{uid}/task_outcomes/{taskId}`
- `/users/{uid}/events/{eventId}`

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

- `task_scheduled`
- `routine_template_created`
- `routine_template_updated`
- `routine_template_deleted`

#### Dependencies

Core model contracts, event validator, Firestore indexes.

#### How to verify

- Automated: routine materialization tests for daily, weekly, once, terminal state, and duplicate prevention.
- Manual: create templates, open multiple selected dates, and verify tasks appear once.

#### Estimate

2 days

#### Done Criteria

- [ ] Template schema is canonical.
- [ ] Materialization is idempotent.
- [ ] Repeat rules work for daily, weekly, and once.
- [ ] Task lifecycle state is preserved.

### Task 1.9 — Fix add task, repeat rules, and selected date behavior

#### Status

- [ ] Not started

#### Priority

P2 — Required for MVP

#### Depends on

1.8

#### Blocks

None

#### Why

Users must be able to add a task for the date they are viewing without it leaking into today or duplicating across the routine timeline.

#### Current code evidence

- `lib/core/providers.dart` defines `selectedRoutineDateProvider`.
- `lib/views/routine/add_task_sheet.dart` is large and owns custom task input.
- `lib/views/routine/routine_tab.dart` shows timeline days and opens add/AI flows.
- `lib/services/task_service.dart` creates Firestore tasks.

#### Gap

Selected date, one-off vs repeat, reminders, validation, and task creation need focused verification after routine materialization is reconciled.

#### Spec source

Actual code; audit category requirement.

#### Build order prerequisite

1.8

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Make the Add Task flow reliably create one-off or repeating tasks/templates for the selected routine date.
Files to inspect first: lib/views/routine/add_task_sheet.dart, lib/views/routine/routine_tab.dart, lib/core/providers.dart, lib/services/task_service.dart, lib/providers/routine_provider.dart.
Files allowed to modify: add task sheet, routine tab selected-date plumbing, task/routine service adapters, focused tests.
Firestore paths: /users/{uid}/tasks/{taskId}, /users/{uid}/routine/current.templates.custom, /users/{uid}/scheduled_notifications/{notificationId}.
R2 paths: None.
Cloudflare Worker endpoints: None.
Feature flags: None.
Requirements: selected date is honored; repeat rules are explicit; invalid time ranges are blocked; no duplicate materialized tasks; reminders are optional and safe.
Events: task_scheduled, notification_scheduled if reminder is enabled.
Verification: add task today/tomorrow/next week; repeat daily/weekly; delete/edit if supported.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/views/routine/add_task_sheet.dart`
- `lib/views/routine/routine_tab.dart`
- `lib/providers/routine_provider.dart`
- `lib/services/task_service.dart`
- focused tests

#### Firestore paths

- `/users/{uid}/tasks/{taskId}`
- `/users/{uid}/routine/current`
- `/users/{uid}/scheduled_notifications/{notificationId}`

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

- `task_scheduled`
- `notification_scheduled`

#### Dependencies

Routine materialization and notification service contracts.

#### How to verify

- Automated: selected-date task creation tests.
- Manual: add tasks for today, tomorrow, and a weekly repeat; inspect Firestore and timeline.

#### Estimate

1 day

#### Done Criteria

- [ ] Selected date is honored.
- [ ] Repeat rules are explicit.
- [ ] Invalid tasks cannot be saved.
- [ ] No duplicate tasks are generated.

### Task 1.10 — Finalize routine timeline status controls and day lifecycle

#### Status

- [ ] Not started

#### Priority

P2 — Required for MVP

#### Depends on

1.9

#### Blocks

None

#### Why

The routine timeline is the core daily workflow. Task status changes must update events, summaries, notifications, and selected-date UI correctly.

#### Current code evidence

- `lib/views/routine/timeline_section.dart` renders timeline tasks.
- `lib/views/routine/timeline_zoom_views.dart` supports zoom views.
- `lib/services/task_service.dart` owns start/pause/resume/complete/skip/abandon.
- `lib/services/routine_service.dart` owns day start/close.
- `lib/core/event_orchestrator.dart` reacts to task events and day events.

#### Gap

Timeline controls, day-close overdue handling, routine block completion, task outcomes, and selected-date rendering need end-to-end verification after schema cleanup.

#### Spec source

Actual code; service contracts; audit finding.

#### Build order prerequisite

1.8, 1.9

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Finalize task lifecycle controls in the routine timeline and day start/day close behavior.
Files to inspect first: lib/views/routine/timeline_section.dart, lib/views/routine/routine_tab.dart, lib/services/task_service.dart, lib/services/routine_service.dart, lib/core/event_orchestrator.dart, test/services/task_service_contract_test.dart, test/services/routine_service_contract_test.dart.
Files allowed to modify: timeline UI, task/routine service, orchestrator, focused tests.
Firestore paths: /users/{uid}/tasks/{taskId}, /users/{uid}/task_outcomes/{taskId}, /users/{uid}/dailySummaries/{date}, /users/{uid}/events/{eventId}.
R2 paths: None.
Cloudflare Worker endpoints: None.
Feature flags: None.
Requirements: valid state transitions only; terminal tasks not overwritten; selected date renders actual Firestore tasks; day close is idempotent.
Events: task_started, task_paused, task_resumed, task_completed, task_abandoned, task_skipped, routine_block_completed, day_started, day_closed, routine_day_summarized.
Verification: task service tests and manual full-day lifecycle script.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/views/routine/timeline_section.dart`
- `lib/views/routine/routine_tab.dart`
- `lib/services/task_service.dart`
- `lib/services/routine_service.dart`
- `lib/core/event_orchestrator.dart`
- focused tests

#### Firestore paths

- `/users/{uid}/tasks/{taskId}`
- `/users/{uid}/task_outcomes/{taskId}`
- `/users/{uid}/dailySummaries/{date}`
- `/users/{uid}/events/{eventId}`

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

- `task_started`
- `task_paused`
- `task_resumed`
- `task_completed`
- `task_abandoned`
- `task_skipped`
- `routine_block_completed`
- `day_started`
- `day_closed`
- `routine_day_summarized`

#### Dependencies

Routine schema, task model, event validator, notification service.

#### How to verify

- Automated: task lifecycle and routine day-close tests.
- Manual: create/start/pause/resume/complete/skip/abandon tasks and inspect events/outcomes.

#### Estimate

2 days

#### Done Criteria

- [ ] Timeline controls map to valid service transitions.
- [ ] Day close is idempotent.
- [ ] Events and outcomes match task state.
- [ ] Selected-date timeline stays consistent.

### Task 1.11 — Harden existing Worker preview contracts

#### Status

- [ ] Not started

#### Priority

P1 — Blocks many features

#### Depends on

1.4, 1.6

#### Blocks

None

#### Why

AI/backend calls must be safe Cloudflare Worker calls with Firebase ID token verification and no direct Flutter secrets.

#### Current code evidence

- `workers/routine-import-worker/src/index.js` implements preview-only routine import and rejects Firebase Storage/GCS image URLs.
- `workers/routine-import-worker/test/routineImport.contract.test.js` exists.
- `workers/coach-reply-worker/src/index.js` and `workers/ai-gateway-worker/src/index.js` exist.
- `workers/*/wrangler.toml` exists.

#### Gap

Worker contracts, auth requirements, error codes, rate-limit behavior, safety branches, and test coverage are inconsistent across Workers.

#### Spec source

Required Worker Pattern; actual Worker code; audit finding.

#### Build order prerequisite

1.4, 1.6

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Harden existing Cloudflare Worker preview contracts for routine import, coach reply, and AI gateway.
Files to inspect first: workers/routine-import-worker/src/index.js, workers/routine-import-worker/test/routineImport.contract.test.js, workers/coach-reply-worker/src/index.js, workers/ai-gateway-worker/src/index.js, workers/*/package.json.
Files allowed to modify: Worker source/tests/docs only; no Flutter feature code unless contract docs require client constants later.
Firestore paths: None unless Worker explicitly documents preview-only no writes.
R2 paths: only read/metadata references for image import; no direct secrets in Flutter.
Cloudflare Worker endpoints: routine import, coach reply, AI generate/gateway.
Feature flags: match Flutter kill switches from Task 1.3.
Requirements: Firebase ID token required; no server secrets in repo; preview-only behavior documented; consistent JSON error shape; rate-limit and safety tests.
Events: None from Worker unless explicitly designed; Flutter saves reviewed results/events.
Verification: npm test for each Worker package that has tests; add missing contract tests.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `workers/routine-import-worker/src/index.js`
- `workers/routine-import-worker/test/routineImport.contract.test.js`
- `workers/coach-reply-worker/src/index.js`
- `workers/ai-gateway-worker/src/index.js`
- Worker package tests/docs

#### Firestore paths

None

#### R2 paths

- `users/{uid}/uploads/{routineType}/{fileName}`

#### Cloudflare Worker endpoints

- Routine import endpoint
- Coach reply endpoint
- AI generate/gateway endpoint

#### Events

None

#### Dependencies

Cloudflare Workers runtime, Firebase ID token verification approach, AI provider secrets configured outside Flutter.

#### How to verify

- Automated: Worker contract tests for auth, bad input, safe fallback, rate limits, response schema.
- Manual: local Worker preview requests with missing/invalid token are rejected.

#### Estimate

1 day

#### Done Criteria

- [ ] Existing Workers require auth.
- [ ] Response/error schemas are documented.
- [ ] Tests cover no-token and malformed payloads.
- [ ] No Worker writes to Firebase unless explicitly approved.

### Task 1.12 — Build R2 signed upload Worker and cleanup policy

#### Status

- [ ] Not started

#### Priority

P1 — Blocks many features

#### Depends on

1.4, 1.11

#### Blocks

None

#### Why

Profile photos and image routine import cannot ship until uploads use Cloudflare R2 with signed URLs and cleanup, not Firebase Storage.

#### Current code evidence

- `lib/services/r2_upload_service.dart` expects `R2_SIGNED_UPLOAD_ENDPOINT` and `R2_DELETE_UPLOAD_ENDPOINT`.
- `lib/services/image_upload_service.dart` compresses images to JPEG under 1 MB.
- No R2 upload Worker was found under `workers/`.

#### Gap

The backend endpoints for signed upload/delete do not exist, so all image upload features must remain disabled.

#### Spec source

Required R2 Pattern; actual code file; audit finding.

#### Build order prerequisite

1.4, 1.11

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Implement a Cloudflare Worker for authenticated R2 signed upload/delete URLs and cleanup policy.
Files to inspect first: lib/services/r2_upload_service.dart, lib/services/image_upload_service.dart, workers/*, docs/OPTIVUS_STRICT_TASK_RULES.md.
Files allowed to modify: new Worker directory/files, Worker tests, docs; no Flutter feature UI except contract constants if needed.
Firestore paths: None.
R2 paths: users/{uid}/uploads/{routineType}/{timestamp}.jpg, users/{uid}/profile/{timestamp}.jpg.
Cloudflare Worker endpoints: R2_SIGNED_UPLOAD_ENDPOINT, R2_DELETE_UPLOAD_ENDPOINT.
Feature flags: ENABLE_R2_UPLOADS remains default false until verified.
Requirements: verify Firebase token; objectKey must start with signed-in uid; content type image/jpeg; size <= 1 MB; short upload expiry; no R2 secrets in Flutter; cleanup/lifecycle documented.
Events: None.
Verification: Worker contract tests; manual test against dev R2 bucket if credentials are available.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `workers/r2-upload-worker/package.json`
- `workers/r2-upload-worker/src/index.js`
- `workers/r2-upload-worker/test/*.test.js`
- `workers/r2-upload-worker/wrangler.toml`
- docs for cleanup policy

#### Firestore paths

None

#### R2 paths

- `users/{uid}/uploads/{routineType}/{timestamp}.jpg`
- `users/{uid}/profile/{timestamp}.jpg`

#### Cloudflare Worker endpoints

- `R2_SIGNED_UPLOAD_ENDPOINT`
- `R2_DELETE_UPLOAD_ENDPOINT`

#### Events

None

#### Dependencies

Cloudflare R2 binding and Worker secrets outside repo.

#### How to verify

- Automated: Worker tests for auth, object key traversal, wrong uid, content type, size, delete.
- Manual: upload/delete a JPEG in a dev R2 bucket before enabling flags.

#### Estimate

1 day

#### Done Criteria

- [ ] Signed upload endpoint exists.
- [ ] Delete endpoint or cleanup policy exists.
- [ ] UID/object key validation is enforced.
- [ ] Feature flag remains off until verified.

### Task 1.13 — Wire Flutter R2 uploads and disabled fallbacks

#### Status

- [ ] Not started

#### Priority

P2 — Required for MVP

#### Depends on

1.12

#### Blocks

None

#### Why

Flutter upload flows must store only R2 object metadata and gracefully show Coming Soon if R2 is disabled or unavailable.

#### Current code evidence

- `lib/services/r2_upload_service.dart` returns `objectKey`, `path`, size, MIME, and optional URL.
- `lib/services/image_upload_service.dart` gates uploads with `FeatureFlags.enableR2Uploads`.
- `lib/views/routine/widgets/photo_picker_button.dart` shows Coming Soon when disabled.
- `lib/views/tabs/profile_tab.dart` needs profile image/avatar handling.

#### Gap

Upload metadata, cleanup-on-replace, profile image path, and image import flows are not fully verified against a real R2 Worker contract.

#### Spec source

Required R2 Pattern; actual code file; audit finding.

#### Build order prerequisite

1.12

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Wire Flutter R2 uploads to the signed upload Worker and keep all disabled states safe.
Files to inspect first: lib/services/r2_upload_service.dart, lib/services/image_upload_service.dart, lib/views/routine/widgets/photo_picker_button.dart, lib/views/tabs/profile_tab.dart, lib/core/config/feature_flags.dart.
Files allowed to modify: upload services, profile/routine image call sites, focused tests.
Firestore paths: /users/{uid}/profile/main, /users/{uid}/routine/current.imports.
R2 paths: users/{uid}/uploads/{routineType}/{timestamp}.jpg, users/{uid}/profile/{timestamp}.jpg.
Cloudflare Worker endpoints: R2_SIGNED_UPLOAD_ENDPOINT, R2_DELETE_UPLOAD_ENDPOINT.
Feature flags: ENABLE_R2_UPLOADS, ENABLE_PROFILE_IMAGE_UPLOAD, ENABLE_IMAGE_ROUTINE_IMPORT, per-routine image flags.
Requirements: no Firebase Storage; no base64 in Firestore; store objectKey/metadata only; cleanup replaced drafts best-effort; Coming Soon with flags off.
Events: None unless existing profile/routine events are already defined.
Verification: service tests and manual flags-off/flags-on upload check.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/services/r2_upload_service.dart`
- `lib/services/image_upload_service.dart`
- `lib/views/routine/widgets/photo_picker_button.dart`
- `lib/views/tabs/profile_tab.dart`
- focused tests

#### Firestore paths

- `/users/{uid}/profile/main`
- `/users/{uid}/routine/current`

#### R2 paths

- `users/{uid}/uploads/{routineType}/{timestamp}.jpg`
- `users/{uid}/profile/{timestamp}.jpg`

#### Cloudflare Worker endpoints

- `R2_SIGNED_UPLOAD_ENDPOINT`
- `R2_DELETE_UPLOAD_ENDPOINT`

#### Events

None

#### Dependencies

R2 signed upload Worker and feature flags.

#### How to verify

- Automated: mocked upload service tests for disabled, success, delete cleanup.
- Manual: flags off show Coming Soon; flags on upload a JPEG through dev Worker.

#### Estimate

1 day

#### Done Criteria

- [ ] Flutter stores only R2 metadata.
- [ ] Disabled flows do not block manual/text setup.
- [ ] Profile image upload is gated.
- [ ] No Firebase Storage package or path is used.

### Task 1.14 — Finalize Mapbox infrastructure and no-token fallback

#### Status

- [ ] Not started

#### Priority

P2 — Required for MVP

#### Depends on

1.3

#### Blocks

None

#### Why

Running/fitness must work without Google Maps and without crashing when the Mapbox token is absent.

#### Current code evidence

- `pubspec.yaml` uses `flutter_map` and `latlong2`; no `google_maps_flutter`.
- `lib/core/config/map_config.dart` reads `MAPBOX_ACCESS_TOKEN`.
- `lib/views/fitness/activity_route_review_screen.dart` has Mapbox fallback UI.
- `lib/services/location_tracking_service.dart` and fitness controllers collect route data.

#### Gap

Mapbox token handling, route review, live route fallback, package/user-agent identity, and Android permission behavior need release verification.

#### Spec source

Required Mapbox Pattern; actual code file; audit finding.

#### Build order prerequisite

1.3

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Finalize Mapbox config and no-token fallback for live/saved fitness routes.
Files to inspect first: lib/core/config/map_config.dart, lib/views/fitness/activity_route_review_screen.dart, lib/views/fitness/live_activity_tracking_screen.dart, lib/controllers/fitness_map_controller.dart, lib/services/location_tracking_service.dart, android/app/src/main/AndroidManifest.xml.
Files allowed to modify: map config, route UI, fitness map controller, docs/tests.
Firestore paths: /users/{uid}/fitnessActivities/{activityId}, /users/{uid}/fitnessActivities/{activityId}/routePoints/{pointId}.
R2 paths: None.
Cloudflare Worker endpoints: None.
Feature flags: MAPBOX_ACCESS_TOKEN via dart-define/env only; no real token committed.
Requirements: no Google Maps; metrics continue without map tiles; missing token shows fallback; permissions are user-controlled.
Events: routeTrackingStarted, routeTrackingStopped, routeSaved, routeReviewOpened.
Verification: manual run with and without token; real-device GPS permission test.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/core/config/map_config.dart`
- `lib/views/fitness/activity_route_review_screen.dart`
- `lib/views/fitness/live_activity_tracking_screen.dart`
- `lib/controllers/fitness_map_controller.dart`
- docs/tests

#### Firestore paths

- `/users/{uid}/fitnessActivities/{activityId}`
- `/users/{uid}/fitnessActivities/{activityId}/routePoints/{pointId}`

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

- `routeTrackingStarted`
- `routeTrackingStopped`
- `routeSaved`
- `routeReviewOpened`

#### Dependencies

Mapbox token supplied outside source, Android location permission.

#### How to verify

- Automated: config/controller tests where possible.
- Manual: route review with no token, invalid token, and valid dev token; metrics still work.

#### Estimate

1 day

#### Done Criteria

- [ ] No Google Maps dependency exists.
- [ ] Missing Mapbox token does not break fitness metrics.
- [ ] Route fallback UI is clear.
- [ ] Real token is not committed.

### Task 1.15 — Harden auth, onboarding completion, and profile bootstrap

#### Status

- [ ] Not started

#### Priority

P2 — Required for MVP

#### Depends on

1.6, 1.8

#### Blocks

None

#### Why

Play Store testing needs a reliable first-run path from signup through onboarding to home with expected Firestore documents.

#### Current code evidence

- `lib/services/auth_service.dart`, `lib/repositories/auth_repository.dart`, and `lib/repositories/user_repository.dart` handle auth/user data.
- `lib/core/providers/bootstrap_provider.dart` routes based on auth and onboarding.
- `lib/views/screens/onboarding_screen.dart` and `lib/views/onboarding/onboarding_page_0.dart` through page 10 exist.
- `lib/providers/onboarding_provider.dart` completes onboarding and materializes initial data.

#### Gap

First-run edge cases, existing-user schema migration, onboarding completion documents/events, and post-completion routing need end-to-end tests.

#### Spec source

Actual code; audit category requirement.

#### Build order prerequisite

1.6, 1.8

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Harden signup/login/bootstrap/onboarding completion and first-run Firestore documents.
Files to inspect first: lib/services/auth_service.dart, lib/repositories/user_repository.dart, lib/core/providers/bootstrap_provider.dart, lib/core/router/app_router.dart, lib/providers/onboarding_provider.dart, lib/views/screens/onboarding_screen.dart.
Files allowed to modify: auth/onboarding/router/bootstrap code and focused tests.
Firestore paths: /users/{uid}, /users/{uid}/profile/main, /users/{uid}/onboarding/state, /users/{uid}/routine/current, /users/{uid}/goals/{goalId}, /users/{uid}/identity_profile/main.
R2 paths: None.
Cloudflare Worker endpoints: None.
Feature flags: AI/R2 flags must not be required for onboarding.
Requirements: manual onboarding works offline as much as Firestore allows; completion is idempotent; events emit once; ready users route to home.
Events: user_signed_up, onboarding_completed, task_scheduled, identityCreated if supported.
Verification: auth/onboarding tests and manual new-user smoke test.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/services/auth_service.dart`
- `lib/repositories/user_repository.dart`
- `lib/core/providers/bootstrap_provider.dart`
- `lib/core/router/app_router.dart`
- `lib/providers/onboarding_provider.dart`
- focused tests

#### Firestore paths

- `/users/{uid}`
- `/users/{uid}/profile/main`
- `/users/{uid}/onboarding/state`
- `/users/{uid}/routine/current`
- `/users/{uid}/goals/{goalId}`
- `/users/{uid}/identity_profile/main`

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

- `user_signed_up`
- `onboarding_completed`
- `task_scheduled`
- `identity_created`

#### Dependencies

Firebase Auth, Firestore schema, routine materialization.

#### How to verify

- Automated: provider/repository tests for onboarding completion.
- Manual: signup, complete onboarding, kill/reopen app, verify home route and documents.

#### Estimate

2 days

#### Done Criteria

- [ ] First-run flow is deterministic.
- [ ] Onboarding completion is idempotent.
- [ ] Required documents exist.
- [ ] Ready state routes to `/home`.

### Task 1.16 — Finish home, navigation shell, and settings entry points

#### Status

- [ ] Not started

#### Priority

P2 — Required for MVP

#### Depends on

1.15

#### Blocks

None

#### Why

Internal testers need obvious navigation to routine, trackers, coach, profile, notification settings, support/legal/account actions, and feature fallbacks.

#### Current code evidence

- `lib/views/screens/home_screen.dart` defines the tab shell.
- `lib/views/tabs/home_tab.dart`, `routine_settings_screen.dart`, `tracker_tab.dart`, `coach_tab.dart`, `goals_tab.dart`, and `profile_tab.dart` exist.
- `lib/core/router/app_router.dart` has many app routes but not legal/support pages.

#### Gap

Navigation coverage, empty states, settings entry points, Coming Soon disabled states, route availability, and profile settings dead taps need a release pass.

#### Spec source

Actual code; Play Store readiness requirement.

#### Build order prerequisite

1.15

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Finish home/navigation shell and settings entry points for MVP testing, including profile settings dead-tap cleanup.
Files to inspect first: lib/views/screens/home_screen.dart, lib/views/tabs/home_tab.dart, lib/views/tabs/profile_tab.dart, lib/views/tabs/routine_settings_screen.dart, lib/views/tabs/tracker_tab.dart, lib/core/router/app_router.dart.
Files allowed to modify: navigation/router/tab UI/settings entry points and focused widget tests.
Firestore paths: /users/{uid}/profile/main, /users/{uid}/routine/current, /users/{uid}/dailySummaries/{date}, /users/{uid}/scheduled_notifications/{notificationId}.
R2 paths: None unless profile image metadata is displayed.
Cloudflare Worker endpoints: None.
Feature flags: all disabled AI/R2 features must show fallback/Coming Soon.
Requirements: no dead taps; no missing routes; legal/support/delete/export entry points visible by final release tasks. Profile rows must be audited one by one: Subscription row, Security row, Haptic feedback toggle, Correct spelling toggle, Report bug, Help center, Terms of use, and Privacy policy. Each row must either work, link to the Cloudflare Pages legal/support destination, persist its setting, or be removed/deferred with clear MVP copy. No dead taps in profile for internal testing.
Events: notification_tapped only if notification center route is touched.
Verification: manual tab navigation smoke test.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/views/screens/home_screen.dart`
- `lib/views/tabs/home_tab.dart`
- `lib/views/tabs/profile_tab.dart`
- `lib/views/tabs/routine_settings_screen.dart`
- `lib/core/router/app_router.dart`
- focused widget tests

#### Firestore paths

- `/users/{uid}/profile/main`
- `/users/{uid}/routine/current`
- `/users/{uid}/dailySummaries/{date}`
- `/users/{uid}/scheduled_notifications/{notificationId}`

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

None

#### Dependencies

Auth/onboarding ready state.

#### How to verify

- Automated: widget tests for core routes if feasible.
- Manual: tap all primary tabs/settings cards on a fresh user and existing user.

#### Estimate

1 day

#### Done Criteria

- [ ] No main navigation dead ends.
- [ ] Profile has no dead taps for Subscription, Security, haptics, spelling, report bug, help, terms, or privacy.
- [ ] Empty states are useful.
- [ ] Disabled features have safe fallback UI.
- [ ] Profile/settings routes needed for release are reachable.

### Task 1.17 — Unify fixed schedule setup across onboarding and settings

#### Status

- [ ] Not started

#### Priority

P2 — Required for MVP

#### Depends on

1.8, 1.15

#### Blocks

None

#### Why

Onboarding and Settings fixed schedule editors currently diverge, risking data loss and inconsistent repeat/reminder behavior.

#### Current code evidence

- `docs/fixed_schedule_audit.md` documents differences between onboarding and settings.
- `lib/views/onboarding/onboarding_page_9.dart` owns onboarding schedule UI.
- `lib/views/routine/fixed_schedule_setup_screen.dart` owns settings schedule UI.
- `lib/views/routine/widgets/fixed_schedule_editor.dart` exists.
- `lib/providers/routine_provider.dart` defines fixed schedule templates.

#### Gap

Validation, category, repeat rules, reminders, overlap handling, createdAt preservation, and save paths differ between the two fixed schedule flows.

#### Spec source

`docs/fixed_schedule_audit.md`; actual code.

#### Build order prerequisite

1.8, 1.15

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Unify fixed schedule validation and template fields between onboarding and settings without a broad redesign.
Files to inspect first: docs/fixed_schedule_audit.md, lib/views/onboarding/onboarding_page_9.dart, lib/views/routine/fixed_schedule_setup_screen.dart, lib/views/routine/widgets/fixed_schedule_editor.dart, lib/providers/routine_provider.dart.
Files allowed to modify: fixed schedule editor/widget, onboarding page 9, settings screen, provider adapters, focused tests.
Firestore paths: /users/{uid}/onboarding/state, /users/{uid}/routine/current.templates.fixed_schedule, /users/{uid}/tasks/{taskId}.
R2 paths: None.
Cloudflare Worker endpoints: None.
Feature flags: None.
Requirements: one canonical template shape; no silent blank titles; overlap handling documented; settings edits preserve important metadata.
Events: routine_template_created, routine_template_updated, routine_template_deleted, task_scheduled.
Verification: onboarding schedule -> complete -> settings edit -> timeline materialization.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/views/onboarding/onboarding_page_9.dart`
- `lib/views/routine/fixed_schedule_setup_screen.dart`
- `lib/views/routine/widgets/fixed_schedule_editor.dart`
- `lib/providers/routine_provider.dart`
- focused tests

#### Firestore paths

- `/users/{uid}/onboarding/state`
- `/users/{uid}/routine/current`
- `/users/{uid}/tasks/{taskId}`

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

- `routine_template_created`
- `routine_template_updated`
- `routine_template_deleted`
- `task_scheduled`

#### Dependencies

Routine schema/materialization and onboarding completion.

#### How to verify

- Automated: fixed schedule serialization/validation tests.
- Manual: create 6+ onboarding blocks, complete onboarding, edit in settings, verify timeline.

#### Estimate

2 days

#### Done Criteria

- [ ] Onboarding/settings use compatible fields.
- [ ] Validation is consistent.
- [ ] Existing templates are not corrupted.
- [ ] Timeline reflects saved changes.

### Task 1.18 — Productionize manual skin routine setup

#### Status

- [ ] Not started

#### Priority

P2 — Required for MVP

#### Depends on

1.8

#### Blocks

None

#### Why

Manual skin care must work even when AI and R2 are disabled.

#### Current code evidence

- `lib/views/routine/skin_care_setup_screen.dart` exists and is large.
- `lib/views/routine/widgets/routine_review_screen.dart` can review templates.
- `lib/repositories/routine_repository.dart` saves templates.
- `lib/providers/routine_provider.dart` materializes routine tasks.

#### Gap

Manual validation, template fields, repeat/timing rules, subtasks, safe sample data handling, and timeline verification need a focused production pass.

#### Spec source

Actual code; audit category requirement.

#### Build order prerequisite

1.8

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Productionize manual skin care routine setup with AI/R2 disabled.
Files to inspect first: lib/views/routine/skin_care_setup_screen.dart, lib/views/routine/widgets/routine_review_screen.dart, lib/repositories/routine_repository.dart, lib/providers/routine_provider.dart, lib/services/task_service.dart.
Files allowed to modify: skin setup screen, shared review/template adapters, focused tests.
Firestore paths: /users/{uid}/routine/current.templates.skin_care, /users/{uid}/tasks/{taskId}.
R2 paths: None for manual mode.
Cloudflare Worker endpoints: None for manual mode.
Feature flags: AI/R2 flags must not be required.
Requirements: validated product/step/time input; no accidental sample data saves; review/save creates canonical templates; timeline tasks include subtasks.
Events: routine_template_created, task_scheduled.
Verification: manual skin setup with all AI/R2 flags off.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/views/routine/skin_care_setup_screen.dart`
- `lib/views/routine/widgets/routine_review_screen.dart`
- `lib/providers/routine_provider.dart`
- focused tests

#### Firestore paths

- `/users/{uid}/routine/current`
- `/users/{uid}/tasks/{taskId}`

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

- `routine_template_created`
- `task_scheduled`

#### Dependencies

Routine template schema and materialization.

#### How to verify

- Automated: template serialization tests.
- Manual: create morning/night skin routine with flags off and verify timeline subtasks.

#### Estimate

1 day

#### Done Criteria

- [ ] Manual skin setup saves canonical templates.
- [ ] AI/R2 disabled path works.
- [ ] No sample data is saved accidentally.
- [ ] Timeline tasks materialize correctly.

### Task 1.19 — Productionize manual supplement routine setup

#### Status

- [ ] Not started

#### Priority

P2 — Required for MVP

#### Depends on

1.8

#### Blocks

None

#### Why

Supplement schedules are part of the routine MVP and must be usable without AI.

#### Current code evidence

- `lib/views/routine/supplement_setup_screen.dart` exists.
- `lib/providers/routine_provider.dart` supports routine state.
- `lib/repositories/routine_repository.dart` saves templates.

#### Gap

Supplement fields such as dosage, with-meal behavior, warnings, reminders, repeat rules, and timeline materialization need focused validation.

#### Spec source

Actual code; audit category requirement.

#### Build order prerequisite

1.8

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Productionize manual supplement routine setup.
Files to inspect first: lib/views/routine/supplement_setup_screen.dart, lib/repositories/routine_repository.dart, lib/providers/routine_provider.dart, lib/services/task_service.dart.
Files allowed to modify: supplement setup screen, template adapters, focused tests.
Firestore paths: /users/{uid}/routine/current.templates.supplements, /users/{uid}/tasks/{taskId}.
R2 paths: None.
Cloudflare Worker endpoints: None.
Feature flags: AI flags must not be required.
Requirements: validate name/dosage/time; with-meal and notes fields persist if present; timeline task title/subtasks are useful; no medical claims or unsafe copy.
Events: routine_template_created, task_scheduled.
Verification: manual supplement setup with AI off.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/views/routine/supplement_setup_screen.dart`
- `lib/providers/routine_provider.dart`
- focused tests

#### Firestore paths

- `/users/{uid}/routine/current`
- `/users/{uid}/tasks/{taskId}`

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

- `routine_template_created`
- `task_scheduled`

#### Dependencies

Routine template schema and materialization.

#### How to verify

- Automated: supplement template parsing tests.
- Manual: add/edit/delete supplements and verify timeline tasks.

#### Estimate

1 day

#### Done Criteria

- [ ] Supplement templates save canonical fields.
- [ ] Validation blocks unusable entries.
- [ ] Timeline tasks materialize.
- [ ] AI is not required.

### Task 1.20 — Productionize manual class routine setup

#### Status

- [ ] Not started

#### Priority

P2 — Required for MVP

#### Depends on

1.8

#### Blocks

None

#### Why

Class timetable setup must work manually while timetable image import remains gated.

#### Current code evidence

- `lib/views/routine/class_setup_screen.dart` exists.
- `lib/views/routine/widgets/photo_picker_button.dart` gates image uploads.
- `lib/repositories/routine_repository.dart` saves templates.

#### Gap

Manual class repeat rules, weekday behavior, time validation, room/professor fields, and selected-day timeline output need final production verification.

#### Spec source

Actual code; audit category requirement.

#### Build order prerequisite

1.8

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Productionize manual class timetable setup.
Files to inspect first: lib/views/routine/class_setup_screen.dart, lib/repositories/routine_repository.dart, lib/providers/routine_provider.dart, lib/views/routine/widgets/photo_picker_button.dart.
Files allowed to modify: class setup screen, routine template adapters, focused tests.
Firestore paths: /users/{uid}/routine/current.templates.classes, /users/{uid}/tasks/{taskId}.
R2 paths: None for manual mode.
Cloudflare Worker endpoints: None for manual mode.
Feature flags: ENABLE_CLASS_TIMETABLE_IMAGE_IMPORT must not be required for manual mode.
Requirements: validated weekday/time/class fields; weekly repeat rules materialize only on matching days; image path disabled safely.
Events: routine_template_created, task_scheduled.
Verification: add Monday/Wednesday/Friday class and inspect timeline dates.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/views/routine/class_setup_screen.dart`
- `lib/providers/routine_provider.dart`
- focused tests

#### Firestore paths

- `/users/{uid}/routine/current`
- `/users/{uid}/tasks/{taskId}`

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

- `routine_template_created`
- `task_scheduled`

#### Dependencies

Routine repeat rule handling.

#### How to verify

- Automated: weekly repeat tests.
- Manual: add class schedule, inspect matching and non-matching dates.

#### Estimate

1 day

#### Done Criteria

- [ ] Weekly class rules work.
- [ ] Manual mode works with image flags off.
- [ ] Timetable fields persist.
- [ ] Timeline dates are correct.

### Task 1.21 — Productionize eating setup and adaptive eating safety

#### Status

- [ ] Not started

#### Priority

P2 — Required for MVP

#### Depends on

1.8, 1.15

#### Blocks

None

#### Why

Eating setup is sensitive. The MVP must avoid unsafe calorie/weight-loss behavior for users with eating-disorder context while keeping manual meal planning useful.

#### Current code evidence

- `lib/views/routine/eating_setup_screen.dart` exists.
- `lib/providers/onboarding_provider.dart` stores sensitive context.
- `docs/phase_1_5_audit.md` notes eating-disorder flag consumption is missing downstream.
- `lib/views/habits/variants/mindful_eating_tracker_view.dart` exists.

#### Gap

Manual meal setup, hostel/mess fallback, adaptive eating logic, and sensitive-context safety are not fully defined or enforced.

#### Spec source

Actual code; old audit; Play Store health/safety readiness requirement.

#### Build order prerequisite

1.8, 1.15

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Productionize manual eating setup and add safety gates for adaptive/nutritional logic.
Files to inspect first: lib/views/routine/eating_setup_screen.dart, lib/providers/onboarding_provider.dart, lib/repositories/user_repository.dart, lib/providers/routine_provider.dart, lib/views/habits/variants/mindful_eating_tracker_view.dart.
Files allowed to modify: eating setup, sensitive-context read path, routine template adapters, focused tests.
Firestore paths: /users/{uid}/profile/main, /users/{uid}/onboarding/state, /users/{uid}/routine/current.templates.eating, /users/{uid}/tasks/{taskId}.
R2 paths: None for manual mode.
Cloudflare Worker endpoints: None for manual mode.
Feature flags: image import and AI flags off by default; adaptive eating can be disabled.
Requirements: no calorie prescription for sensitive users; manual meals save; adaptive eating is Coming Soon or clearly safe if incomplete; hostel/mess text fallback works.
Events: routine_template_created, task_scheduled.
Verification: manual setup for normal and sensitive-context profiles.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/views/routine/eating_setup_screen.dart`
- `lib/providers/onboarding_provider.dart`
- `lib/repositories/user_repository.dart`
- `lib/providers/routine_provider.dart`
- focused tests

#### Firestore paths

- `/users/{uid}/profile/main`
- `/users/{uid}/onboarding/state`
- `/users/{uid}/routine/current`
- `/users/{uid}/tasks/{taskId}`

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

- `routine_template_created`
- `task_scheduled`

#### Dependencies

Onboarding sensitive context and routine template schema.

#### How to verify

- Automated: safety gate tests for sensitive context.
- Manual: create meal plan with AI/R2 off and verify timeline tasks.

#### Estimate

1 day

#### Done Criteria

- [ ] Manual eating setup works.
- [ ] Sensitive-context safety is enforced.
- [ ] Adaptive eating is safe or gated.
- [ ] Image/AI disabled fallback works.

### Task 1.22 — Finalize AI routine import text mode and review-before-save

#### Status

- [ ] Not started

#### Priority

P2 — Required for MVP

#### Depends on

1.4, 1.7, 1.8, 1.11

#### Blocks

None

#### Why

Text routine import can add major value without image upload risk, but it must be preview-only and user-reviewed before Firestore writes.

#### Current code evidence

- `lib/repositories/routine_repository.dart` calls `ROUTINE_IMPORT_ENDPOINT` with `commit: false`.
- `workers/routine-import-worker/src/index.js` returns preview templates.
- `lib/views/routine/widgets/routine_review_screen.dart` supports review/edit/accept.
- Skin, supplement, class, and eating setup screens contain AI/text paths.

#### Gap

Text mode contract, typed parsing, review metadata, suggestion events, disabled endpoint fallback, and per-routine save behavior are not fully consistent.

#### Spec source

Required Worker Pattern; actual code; audit finding.

#### Build order prerequisite

1.4, 1.7, 1.8, 1.11

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Finalize text-based AI routine import for skin, supplements, classes, and eating with review-before-save.
Files to inspect first: lib/repositories/routine_repository.dart, lib/views/routine/widgets/routine_review_screen.dart, lib/views/routine/skin_care_setup_screen.dart, lib/views/routine/supplement_setup_screen.dart, lib/views/routine/class_setup_screen.dart, lib/views/routine/eating_setup_screen.dart, workers/routine-import-worker/src/index.js.
Files allowed to modify: routine import client/model, setup screens, review screen, Worker contract tests, focused Flutter tests.
Firestore paths: /users/{uid}/routine/current, /users/{uid}/suggestions/{suggestionId}, /users/{uid}/events/{eventId}.
R2 paths: None for text mode.
Cloudflare Worker endpoints: ROUTINE_IMPORT_ENDPOINT.
Feature flags: AI routine import kill switch must default safe/off if endpoint missing.
Requirements: Worker preview only; Flutter saves reviewed templates; manual fallback remains; no API keys in Flutter.
Events: suggestion_generated, suggestion_accepted, suggestion_dismissed, routine_template_created.
Verification: mock Worker text responses and manual endpoint-missing fallback.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/repositories/routine_repository.dart`
- `lib/views/routine/widgets/routine_review_screen.dart`
- routine setup screens
- Worker tests
- Flutter tests

#### Firestore paths

- `/users/{uid}/routine/current`
- `/users/{uid}/suggestions/{suggestionId}`
- `/users/{uid}/events/{eventId}`

#### R2 paths

None

#### Cloudflare Worker endpoints

- `ROUTINE_IMPORT_ENDPOINT`

#### Events

- `suggestion_generated`
- `suggestion_accepted`
- `suggestion_dismissed`
- `routine_template_created`

#### Dependencies

Cloudflare API client, routine template models, Worker preview contract.

#### How to verify

- Automated: mocked text import tests and Worker contract tests.
- Manual: enter text for each routine type; review/edit/accept; inspect saved templates.

#### Estimate

2 days

#### Done Criteria

- [ ] Text import never writes directly from Worker.
- [ ] Review-before-save is enforced.
- [ ] Endpoint-missing fallback is safe.
- [ ] Events and suggestions are consistent.

### Task 1.23 — Gate AI routine image import through R2

#### Status

- [ ] Not started

#### Priority

P3 — Important polish

#### Depends on

1.12, 1.13, 1.22

#### Blocks

None

#### Why

Image import is useful but should not block MVP if R2 or OCR is not ready. Manual/text alternatives must remain usable.

#### Current code evidence

- `lib/views/routine/widgets/photo_picker_button.dart` handles pick/upload/clear.
- `lib/services/image_upload_service.dart` compresses JPEGs.
- `workers/routine-import-worker/src/index.js` supports image metadata and rejects Firebase Storage/GCS URLs.
- Skin, class, and eating setup screens include image/photo UI.

#### Gap

Image mode depends on R2 Worker readiness and must be gated per routine type with Coming Soon fallback and cleanup.

#### Spec source

Required R2 Pattern; actual code; audit finding.

#### Build order prerequisite

1.12, 1.13, 1.22

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Gate skin product, class timetable, and eating mess-menu image import behind R2 and image-import flags.
Files to inspect first: lib/views/routine/widgets/photo_picker_button.dart, lib/services/image_upload_service.dart, lib/repositories/routine_repository.dart, lib/views/routine/skin_care_setup_screen.dart, lib/views/routine/class_setup_screen.dart, lib/views/routine/eating_setup_screen.dart, workers/routine-import-worker/src/index.js.
Files allowed to modify: image UI call sites, upload/import client, Worker tests, focused tests.
Firestore paths: /users/{uid}/routine/current.imports, /users/{uid}/suggestions/{suggestionId}.
R2 paths: users/{uid}/uploads/skin_care/{timestamp}.jpg, users/{uid}/uploads/classes/{timestamp}.jpg, users/{uid}/uploads/eating/{timestamp}.jpg.
Cloudflare Worker endpoints: R2_SIGNED_UPLOAD_ENDPOINT, R2_DELETE_UPLOAD_ENDPOINT, ROUTINE_IMPORT_ENDPOINT.
Feature flags: ENABLE_R2_UPLOADS, ENABLE_IMAGE_ROUTINE_IMPORT, ENABLE_SKIN_PRODUCT_IMAGE_IMPORT, ENABLE_CLASS_TIMETABLE_IMAGE_IMPORT, ENABLE_HOSTEL_MESS_IMAGE_IMPORT.
Requirements: flags off show Coming Soon; no Firebase Storage; no base64 Firestore; manual/text fallback preserved; cleanup abandoned uploads where possible.
Events: suggestion_generated, suggestion_accepted, suggestion_dismissed.
Verification: flags-off manual QA; flags-on dev R2 + mock import.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/views/routine/widgets/photo_picker_button.dart`
- `lib/services/image_upload_service.dart`
- `lib/repositories/routine_repository.dart`
- `lib/views/routine/skin_care_setup_screen.dart`
- `lib/views/routine/class_setup_screen.dart`
- `lib/views/routine/eating_setup_screen.dart`
- tests

#### Firestore paths

- `/users/{uid}/routine/current`
- `/users/{uid}/suggestions/{suggestionId}`

#### R2 paths

- `users/{uid}/uploads/skin_care/{timestamp}.jpg`
- `users/{uid}/uploads/classes/{timestamp}.jpg`
- `users/{uid}/uploads/eating/{timestamp}.jpg`

#### Cloudflare Worker endpoints

- `R2_SIGNED_UPLOAD_ENDPOINT`
- `R2_DELETE_UPLOAD_ENDPOINT`
- `ROUTINE_IMPORT_ENDPOINT`

#### Events

- `suggestion_generated`
- `suggestion_accepted`
- `suggestion_dismissed`

#### Dependencies

R2 upload Worker, Flutter upload integration, text import review flow.

#### How to verify

- Automated: flags and mocked image import tests.
- Manual: flags off fallback; flags on upload/import/review/accept with dev endpoints.

#### Estimate

2 days

#### Done Criteria

- [ ] Image import is disabled safely by default.
- [ ] R2 metadata is the only stored file reference.
- [ ] Manual/text alternatives work.
- [ ] No Firebase Storage or Google Vision is added.

### Task 1.24 — Make habit system consistency production-ready

#### Status

- [ ] Not started

#### Priority

P2 — Required for MVP

#### Depends on

1.6, 1.7

#### Blocks

None

#### Why

All tracker variants depend on consistent habit definitions, log paths, undo/delete behavior, and streak inputs.

#### Current code evidence

- `lib/models/habit_model.dart` and `lib/models/habit_log_model.dart` exist.
- `lib/services/habit_service.dart` writes canonical `/habit_logs` and legacy nested copies.
- `lib/views/habits/habit_editor_screen.dart`, `habit_detail_screen.dart`, and `log_habit_sheet.dart` exist.
- `lib/services/streak_service.dart` computes streaks.

#### Gap

Habit editor lifecycle, bad/good habit validation, log undo/delete, nested legacy path handling, and streak consistency need a focused release pass.

#### Spec source

Actual code; audit category requirement.

#### Build order prerequisite

1.6, 1.7

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Productionize habit CRUD, log/undo/delete, and streak input consistency.
Files to inspect first: lib/models/habit_model.dart, lib/models/habit_log_model.dart, lib/services/habit_service.dart, lib/services/streak_service.dart, lib/views/habits/habit_editor_screen.dart, lib/views/habits/habit_detail_screen.dart, lib/views/habits/log_habit_sheet.dart.
Files allowed to modify: habit models/service/UI and focused tests.
Firestore paths: /users/{uid}/habits/{habitId}, /users/{uid}/habit_logs/{logId}, /users/{uid}/habits/{habitId}/logs/{date}/items/{logId}, /users/{uid}/streaks/{streakId}.
R2 paths: None.
Cloudflare Worker endpoints: None.
Feature flags: None unless tracker variants are gated.
Requirements: create/edit/pause/resume/archive/delete work; log delete emits event; canonical logs drive reads; legacy nested writes are documented.
Events: habit_created, habit_updated, habit_paused, habit_resumed, habit_archived, habit_deleted, good_habit_logged, bad_habit_slip_logged, habit_log_deleted.
Verification: habit service tests and manual editor/detail/log flow.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/services/habit_service.dart`
- `lib/views/habits/habit_editor_screen.dart`
- `lib/views/habits/habit_detail_screen.dart`
- `lib/views/habits/log_habit_sheet.dart`
- focused tests

#### Firestore paths

- `/users/{uid}/habits/{habitId}`
- `/users/{uid}/habit_logs/{logId}`
- `/users/{uid}/habits/{habitId}/logs/{date}/items/{logId}`
- `/users/{uid}/streaks/{streakId}`

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

- `habit_created`
- `habit_updated`
- `habit_paused`
- `habit_resumed`
- `habit_archived`
- `habit_deleted`
- `good_habit_logged`
- `bad_habit_slip_logged`
- `habit_log_deleted`

#### Dependencies

Event validator and Firestore schema.

#### How to verify

- Automated: habit service lifecycle tests.
- Manual: create, edit, log, undo/delete log, pause, resume, archive.

#### Estimate

2 days

#### Done Criteria

- [ ] Habit lifecycle is complete.
- [ ] Logs are canonical and delete-safe.
- [ ] Events validate.
- [ ] Streak inputs are stable.

### Task 1.25 — Harden notifications, reminders, settings, and alarm policy

#### Status

- [ ] Not started

#### Priority

P2 — Required for MVP

#### Depends on

1.3, 1.5, 1.10, 1.24

#### Blocks

None

#### Why

Notifications involve Play Store permission review, exact alarm policy, user budgets, quiet hours, and task/habit reminders.

#### Current code evidence

- `lib/services/notification_service.dart` is large and schedules task/habit alarms.
- `lib/views/settings/notification_settings_screen.dart` exists.
- `lib/views/alarms/alarm_editor_screen.dart`, `alarm_ringing_screen.dart`, and `snooze_reason_sheet.dart` exist.
- `android/app/src/main/AndroidManifest.xml` declares notification, exact alarm, full-screen intent, boot, vibration permissions.

#### Gap

Runtime permission flow, exact alarm/full-screen policy justification, quiet hours, category caps, boot re-registration, task end reminders, and user settings need release verification.

#### Spec source

Actual code; Play Store permissions requirement.

#### Build order prerequisite

1.3, 1.5, 1.10, 1.24

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Harden local notifications, reminders, settings, and alarm policy readiness.
Files to inspect first: lib/services/notification_service.dart, lib/views/settings/notification_settings_screen.dart, lib/views/alarms/, lib/core/event_orchestrator.dart, android/app/src/main/AndroidManifest.xml.
Files allowed to modify: notification service/settings/alarm screens, manifest comments if needed, focused tests/docs.
Firestore paths: /users/{uid}/scheduled_notifications/{notificationId}, /users/{uid}/notificationLog/{logId}, /users/{uid}/profile/main.
R2 paths: None.
Cloudflare Worker endpoints: None for MVP local notifications.
Feature flags: notification kill switches/Remote Config budget defaults.
Requirements: POST_NOTIFICATIONS permission UX; exact alarm/full-screen policy justified or removed; quiet hours/caps work; re-register on app start; no FCM dependency unless safe.
Events: notification_scheduled, notification_sent, notification_tapped, notification_dismissed, notification_suppressed, notification_missed.
Verification: local notification scheduling/tap/dismiss/manual QA.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/services/notification_service.dart`
- `lib/views/settings/notification_settings_screen.dart`
- `lib/views/alarms/*`
- `android/app/src/main/AndroidManifest.xml`
- tests/docs

#### Firestore paths

- `/users/{uid}/scheduled_notifications/{notificationId}`
- `/users/{uid}/notificationLog/{logId}`
- `/users/{uid}/profile/main`

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

- `notification_scheduled`
- `notification_sent`
- `notification_tapped`
- `notification_dismissed`
- `notification_suppressed`
- `notification_missed`

#### Dependencies

Android notification permissions, Remote Config defaults, task/habit events.

#### How to verify

- Automated: notification service contract tests.
- Manual: grant/deny notification permission, schedule task reminder, reboot/reopen, tap/dismiss.

#### Estimate

2 days

#### Done Criteria

- [ ] Permission UX is clear.
- [ ] Alarms/reminders schedule and cancel correctly.
- [ ] Quiet hours and budgets work.
- [ ] Play Store permission justification is ready.

### Task 1.26 — Complete smoking tracker MVP

#### Status

- [ ] Not started

#### Priority

P2 — Required for MVP

#### Depends on

1.24, 1.25

#### Blocks

None

#### Why

Smoking is a core bad-habit tracker and is tied to slip events, recovery alarms, and coach interventions.

#### Current code evidence

- `lib/views/habits/variants/smoking_tracker_view.dart` has rich UI.
- `lib/services/habit_service.dart` logs slips.
- `lib/services/notification_service.dart` schedules slip recovery.
- `lib/services/rule_engine_service.dart` has smoking and multiple-slip rules.

#### Gap

Baseline handling, relapse math, money saved, trigger tags, recovery alarm scheduling, and coach event payload alignment need final verification.

#### Spec source

Codebase audit; historical tracker requirements already merged into this task; Play Store readiness.

#### Build order prerequisite

1.24, 1.25

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Complete the smoking tracker MVP without adding backend billing dependencies.
Files to inspect first: lib/views/habits/variants/smoking_tracker_view.dart, lib/services/habit_service.dart, lib/services/notification_service.dart, lib/services/rule_engine_service.dart, lib/models/habit_model.dart, lib/models/habit_log_model.dart.
Files allowed to modify: smoking tracker, habit/notification/rule payload adapters, focused tests.
Firestore paths: /users/{uid}/habits/{habitId}, /users/{uid}/habit_logs/{logId}, /users/{uid}/streaks/{habitId}, /users/{uid}/scheduled_notifications/{notificationId}.
R2 paths: None.
Cloudflare Worker endpoints: None.
Feature flags: None.
Requirements: slip count and triggers save; recovery alarms work locally; money-saved and milestones are accurate; coach rules receive valid payloads; no medical claims beyond generic wellness copy.
Events: bad_habit_slip_logged, slip_streak_detected, notification_scheduled, notification_suppressed.
Verification: manual smoke with baseline, multiple slips, alarm schedule.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/views/habits/variants/smoking_tracker_view.dart`
- `lib/services/habit_service.dart`
- `lib/services/notification_service.dart`
- `lib/services/rule_engine_service.dart`
- focused tests

#### Firestore paths

- `/users/{uid}/habits/{habitId}`
- `/users/{uid}/habit_logs/{logId}`
- `/users/{uid}/streaks/{habitId}`
- `/users/{uid}/scheduled_notifications/{notificationId}`

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

- `bad_habit_slip_logged`
- `slip_streak_detected`
- `notification_scheduled`
- `notification_suppressed`

#### Dependencies

Habit system and notification service. Coach/rule-engine behavior is verified again in Task 1.34.

#### How to verify

- Automated: smoking-specific habit payload tests if feasible.
- Manual: log slips, view triggers/chart, schedule recovery alarm, inspect events.

#### Estimate

1 day

#### Done Criteria

- [ ] Smoking slip logging works.
- [ ] Recovery alarm path works or is safely disabled.
- [ ] Coach/rule payloads validate.
- [ ] UI calculations are correct enough for MVP.

### Task 1.27 — Complete screen time tracker and Android usage access flow

#### Status

- [ ] Not started

#### Priority

P2 — Required for MVP

#### Depends on

1.24

#### Blocks

None

#### Why

Screen time uses a sensitive Android special permission and must clearly explain access, fallback, and Data Safety implications.

#### Current code evidence

- `android/app/src/main/kotlin/com/example/optivus/ScreenTimePlugin.kt` bridges UsageStatsManager.
- `android/app/src/main/kotlin/com/example/optivus/MainActivity.kt` registers the screen-time MethodChannel.
- `lib/services/screen_time_bridge.dart` and `screen_time_importer.dart` exist.
- `lib/views/habits/variants/screen_time_tracker_view.dart` exists.
- `android/app/src/main/AndroidManifest.xml` declares `PACKAGE_USAGE_STATS`.

#### Gap

Permission UX, path naming, caps/slips, app lock placeholder behavior, Data Safety wording, tracker display, and native package rename coverage need release validation.

#### Spec source

Actual code; Play Store permission audit requirement.

#### Build order prerequisite

1.24

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Complete screen time tracker MVP and Android usage access flow.
Files to inspect first: android/app/src/main/kotlin/com/example/optivus/MainActivity.kt, android/app/src/main/kotlin/com/example/optivus/ScreenTimePlugin.kt, android/app/src/main/AndroidManifest.xml, lib/services/screen_time_bridge.dart, lib/services/screen_time_importer.dart, lib/views/habits/variants/screen_time_tracker_view.dart, lib/models/screen_time_log_model.dart.
Files allowed to modify: screen-time bridge/importer/UI, permission copy, focused tests.
Firestore paths: /users/{uid}/screenTimeRaw/{logId} or canonical chosen path, /users/{uid}/habit_logs/{logId}, /users/{uid}/events/{eventId}.
R2 paths: None.
Cloudflare Worker endpoints: None.
Feature flags: optional screen-time tracker flag if needed.
Requirements: permission denied state is usable; usage access settings opens; no actual app blocking claims if lockApp is placeholder; Data Safety notes are captured. If Task 1.41 changes the Android package identity, screen-time coverage must include `android/app/src/main/kotlin/com/example/optivus/MainActivity.kt`, `android/app/src/main/kotlin/com/example/optivus/ScreenTimePlugin.kt`, `lib/services/screen_time_bridge.dart`, and the MethodChannel name `com.example.optivus/screen_time` so native and Dart names remain aligned with the final package policy.
Events: screen_time_synced, bad_habit_slip_logged.
Verification: real Android device permission grant/deny/sync.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/services/screen_time_bridge.dart`
- `lib/services/screen_time_importer.dart`
- `lib/views/habits/variants/screen_time_tracker_view.dart`
- `android/app/src/main/kotlin/com/example/optivus/MainActivity.kt`
- `android/app/src/main/kotlin/com/example/optivus/ScreenTimePlugin.kt`
- docs/tests

#### Firestore paths

- `/users/{uid}/screenTimeRaw/{logId}`
- `/users/{uid}/habit_logs/{logId}`
- `/users/{uid}/events/{eventId}`

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

- `screen_time_synced`
- `bad_habit_slip_logged`

#### Dependencies

Android UsageStatsManager permission and habit system.

#### How to verify

- Automated: importer tests with mocked bridge.
- Manual: real Android grant/deny/sync and tracker display.

#### Estimate

1 day

#### Done Criteria

- [ ] Permission UX is clear.
- [ ] Sync writes canonical logs.
- [ ] Placeholder lock behavior is not misrepresented.
- [ ] Screen-time native package and MethodChannel names are aligned with final package rename decisions.
- [ ] Data Safety notes are ready.

### Task 1.28 — Complete meditation tracker, timer, and local audio QA

#### Status

- [ ] Not started

#### Priority

P2 — Required for MVP

#### Depends on

1.24

#### Blocks

None

#### Why

Meditation must use bundled Flutter audio assets, not Firebase Storage, and the timer/log flow must be stable offline.

#### Current code evidence

- `assets/audio/*` contains bundled MP3 files.
- `lib/services/meditation_audio_service.dart` uses local audio.
- `lib/config/meditation_library.dart` exists.
- `lib/views/habits/variants/meditation_tracker_view.dart` and `meditation_timer_screen.dart` exist.
- `docs/MEDITATION_AUDIO_LICENSES.md` still contains legacy Firebase Storage path wording.

#### Gap

Audio asset licensing docs, offline playback, timer completion logs, background/interruption handling, and stale Storage wording need final QA.

#### Spec source

Spark-only architecture requirement; actual code; audit finding.

#### Build order prerequisite

1.24

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Complete meditation tracker/timer and local audio QA.
Files to inspect first: lib/services/meditation_audio_service.dart, lib/config/meditation_library.dart, lib/views/habits/variants/meditation_tracker_view.dart, lib/views/habits/variants/meditation_timer_screen.dart, pubspec.yaml, docs/MEDITATION_AUDIO_LICENSES.md.
Files allowed to modify: meditation service/UI/config/docs, focused tests.
Firestore paths: /users/{uid}/habit_logs/{logId}, /users/{uid}/habits/{habitId}, /users/{uid}/events/{eventId}.
R2 paths: None.
Cloudflare Worker endpoints: None.
Feature flags: None.
Requirements: local assets only; no Firebase Storage; timer completion logs habit; audio session handles pause/stop; docs align with bundled assets.
Events: good_habit_logged.
Verification: offline playback and timer completion on device.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/services/meditation_audio_service.dart`
- `lib/config/meditation_library.dart`
- `lib/views/habits/variants/meditation_tracker_view.dart`
- `lib/views/habits/variants/meditation_timer_screen.dart`
- `docs/MEDITATION_AUDIO_LICENSES.md`

#### Firestore paths

- `/users/{uid}/habit_logs/{logId}`
- `/users/{uid}/habits/{habitId}`
- `/users/{uid}/events/{eventId}`

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

- `good_habit_logged`

#### Dependencies

`just_audio`, `audio_session`, bundled assets.

#### How to verify

- Automated: meditation library/service tests if feasible.
- Manual: airplane-mode playback, timer completion, log creation, stop/restart.

#### Estimate

1 day

#### Done Criteria

- [ ] Meditation works offline.
- [ ] Timer completion logs correctly.
- [ ] Audio docs have no Firebase Storage implementation guidance.
- [ ] Audio assets are declared in `pubspec.yaml`.

### Task 1.29 — Complete running and fitness tracker MVP

#### Status

- [ ] Not started

#### Priority

P2 — Required for MVP

#### Depends on

1.14, 1.24

#### Blocks

None

#### Why

Running/fitness involves high-risk permissions, route persistence, stats, Mapbox fallback, and routine task linking.

#### Current code evidence

- `lib/controllers/active_activity_controller.dart` controls activities.
- `lib/repositories/fitness_activity_repository.dart` persists activities and route data.
- `lib/services/fitness_stats_service.dart`, `fitness_route_service.dart`, `location_tracking_service.dart`, and `fitness_event_service.dart` exist.
- `lib/services/fitness_health_connector_service.dart` is a stub.
- `lib/views/fitness/*` screens exist.

#### Gap

Foreground location behavior, route persistence, stats rollups, Health Connect / HealthKit stub decision, AI fitness feedback gating, and Play Store permission justification need release hardening.

#### Spec source

Actual code; Play Store permissions requirement.

#### Build order prerequisite

1.14, 1.24

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Complete running/fitness MVP with Mapbox fallback and safe permission handling.
Files to inspect first: lib/controllers/active_activity_controller.dart, lib/repositories/fitness_activity_repository.dart, lib/services/location_tracking_service.dart, lib/services/fitness_route_service.dart, lib/services/fitness_stats_service.dart, lib/services/fitness_health_connector_service.dart, lib/views/fitness/, android/app/src/main/AndroidManifest.xml.
Files allowed to modify: fitness controller/services/views, manifest permission copy if needed, focused tests.
Firestore paths: /users/{uid}/fitnessActivities/{activityId}, /routePoints, /splits, /heartRateSamples, /fitnessStats/{periodKey}, /fitnessGoals/{goalId}, /tasks/{taskId}.
R2 paths: None.
Cloudflare Worker endpoints: AI_GENERATE_ENDPOINT only if fitness AI feedback is enabled and gated.
Feature flags: AI feedback disabled by default unless Worker is verified.
Requirements: route/stats work without Mapbox token; permission denied state is usable; routine task linking works. `lib/services/fitness_health_connector_service.dart` is a stub, so the Health Connect / HealthKit toggle must not appear as a real connected integration unless it is implemented safely. Either implement the integration safely, disable it, or show Coming Soon. Reflect the chosen decision in Android/iOS permissions and Play Store Data Safety/privacy policy notes.
Events: fitnessActivityStarted, fitnessActivityCompleted, routeSaved, routineFitnessStarted, routineFitnessCompleted, fitnessAiFeedbackRequested, fitnessAiFeedbackGenerated.
Verification: real-device walk/run smoke test and no-token map test.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/controllers/active_activity_controller.dart`
- `lib/repositories/fitness_activity_repository.dart`
- `lib/services/location_tracking_service.dart`
- `lib/services/fitness_stats_service.dart`
- `lib/views/fitness/*`
- focused tests

#### Firestore paths

- `/users/{uid}/fitnessActivities/{activityId}`
- `/users/{uid}/fitnessActivities/{activityId}/routePoints/{pointId}`
- `/users/{uid}/fitnessActivities/{activityId}/splits/{splitId}`
- `/users/{uid}/fitnessActivities/{activityId}/heartRateSamples/{sampleId}`
- `/users/{uid}/fitnessStats/{periodKey}`
- `/users/{uid}/fitnessGoals/{goalId}`
- `/users/{uid}/tasks/{taskId}`

#### R2 paths

None

#### Cloudflare Worker endpoints

- `AI_GENERATE_ENDPOINT` if enabled

#### Events

- `fitnessActivityStarted`
- `fitnessActivityCompleted`
- `routeSaved`
- `routineFitnessStarted`
- `routineFitnessCompleted`
- `fitnessAiFeedbackRequested`
- `fitnessAiFeedbackGenerated`

#### Dependencies

Geolocator, Mapbox token optional, Android location permissions.

#### How to verify

- Automated: fitness metrics/route/stats tests.
- Manual: start, pause, resume, finish an outdoor activity; inspect Firestore route/stats.

#### Estimate

2 days

#### Done Criteria

- [ ] Fitness activity lifecycle works.
- [ ] Route data persists.
- [ ] Stats update.
- [ ] No-token map fallback works.
- [ ] Health Connect / HealthKit stub decision is implemented, disabled, or clearly shown as Coming Soon.
- [ ] Permissions and Data Safety reflect the Health Connect / HealthKit decision.

### Task 1.30 — Complete simple tracker variants

#### Status

- [ ] Not started

#### Priority

P2 — Required for MVP

#### Depends on

1.24

#### Blocks

None

#### Why

Hydration, money saving, reading, and exercise habit variants need usable MVP logging and display consistency.

#### Current code evidence

- `lib/views/habits/variants/hydration_tracker_view.dart`
- `lib/views/habits/variants/money_saving_tracker_view.dart`
- `lib/views/habits/variants/reading_tracker_view.dart`
- `lib/views/habits/variants/exercise_tracker_view.dart`
- `lib/services/google_books_service.dart` calls Google Books API without an API key.

#### Gap

Variant-specific fields, log amounts, external book lookup fallback, empty states, and habit detail integration need release verification.

#### Spec source

Actual code; audit category requirement.

#### Build order prerequisite

1.24

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Complete hydration, money-saving, reading, and exercise tracker MVP variants.
Files to inspect first: lib/views/habits/variants/hydration_tracker_view.dart, money_saving_tracker_view.dart, reading_tracker_view.dart, exercise_tracker_view.dart, tracker_variant_base.dart, lib/services/google_books_service.dart, lib/services/habit_service.dart.
Files allowed to modify: these tracker views, habit service/model adapters, focused tests.
Firestore paths: /users/{uid}/habits/{habitId}, /users/{uid}/habit_logs/{logId}, /users/{uid}/streaks/{habitId}.
R2 paths: None.
Cloudflare Worker endpoints: None.
Feature flags: optional external lookup flag for reading if needed.
Requirements: variant-specific logging works; Google Books lookup is optional/fallback and must not require Google Cloud billing or secrets; shared UI states are consistent.
Events: good_habit_logged, bad_habit_slip_logged where relevant.
Verification: manually open/log each variant.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/views/habits/variants/hydration_tracker_view.dart`
- `lib/views/habits/variants/money_saving_tracker_view.dart`
- `lib/views/habits/variants/reading_tracker_view.dart`
- `lib/views/habits/variants/exercise_tracker_view.dart`
- `lib/services/google_books_service.dart`
- focused tests

#### Firestore paths

- `/users/{uid}/habits/{habitId}`
- `/users/{uid}/habit_logs/{logId}`
- `/users/{uid}/streaks/{habitId}`

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

- `good_habit_logged`
- `bad_habit_slip_logged`

#### Dependencies

Habit system; optional public Google Books lookup without keys.

#### How to verify

- Automated: variant logging tests if feasible.
- Manual: create/open/log each variant and inspect Firestore.

#### Estimate

2 days

#### Done Criteria

- [ ] Each variant can log the expected metric.
- [ ] Empty/error states are usable.
- [ ] External lookup is optional and safe.
- [ ] Shared tracker UX is consistent.

### Task 1.31 — Complete sensitive and derived tracker variants

#### Status

- [ ] Not started

#### Priority

P2 — Required for MVP

#### Depends on

1.21, 1.24, 1.10

#### Blocks

None

#### Why

Mindful eating, procrastination, routine completion, and mood/energy/stress check-ins need careful safety and derived-data handling.

#### Current code evidence

- `lib/views/habits/variants/mindful_eating_tracker_view.dart`
- `lib/views/habits/variants/procrastination_tracker_view.dart`
- `lib/views/habits/variants/routine_completion_tracker_view.dart`
- `lib/services/routine_service.dart` writes `dailySummaries`.
- Mood/energy/stress tracker is not clearly implemented.

#### Gap

Sensitive copy, automatic procrastination slip detection, routine completion derived display, and mood/energy/stress MVP decision are incomplete.

#### Spec source

Actual code; old feature matrix; audit category requirement.

#### Build order prerequisite

1.21, 1.24, 1.10

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Complete mindful eating, procrastination, routine completion, and mood/energy/stress check-in tracker decisions for MVP.
Files to inspect first: lib/views/habits/variants/mindful_eating_tracker_view.dart, procrastination_tracker_view.dart, routine_completion_tracker_view.dart, tracker_variant_base.dart, lib/services/routine_service.dart, lib/core/event_orchestrator.dart, lib/services/habit_service.dart.
Files allowed to modify: these tracker views, habit/routine/orchestrator adapters, focused tests.
Firestore paths: /users/{uid}/habit_logs/{logId}, /users/{uid}/dailySummaries/{date}, /users/{uid}/tasks/{taskId}, /users/{uid}/events/{eventId}.
R2 paths: None.
Cloudflare Worker endpoints: None.
Feature flags: use a tracker feature flag if mood/energy/stress is deferred.
Requirements: mindful eating is non-punitive; procrastination auto-detection is transparent; routine completion reads daily summaries; missing mood/energy/stress is either implemented minimally or explicitly gated.
Events: good_habit_logged, bad_habit_slip_logged, slip_log_dismissed, routine_day_summarized.
Verification: manual logs and day summary display check.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/views/habits/variants/mindful_eating_tracker_view.dart`
- `lib/views/habits/variants/procrastination_tracker_view.dart`
- `lib/views/habits/variants/routine_completion_tracker_view.dart`
- `lib/services/routine_service.dart`
- `lib/core/event_orchestrator.dart`
- focused tests

#### Firestore paths

- `/users/{uid}/habit_logs/{logId}`
- `/users/{uid}/dailySummaries/{date}`
- `/users/{uid}/tasks/{taskId}`
- `/users/{uid}/events/{eventId}`

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

- `good_habit_logged`
- `bad_habit_slip_logged`
- `slip_log_dismissed`
- `routine_day_summarized`

#### Dependencies

Habit system, eating safety, routine day summaries.

#### How to verify

- Automated: focused tracker/derived-summary tests.
- Manual: exercise each variant and inspect logs/summaries.

#### Estimate

2 days

#### Done Criteria

- [ ] Sensitive tracker copy is safe.
- [ ] Derived routine completion uses summaries.
- [ ] Procrastination detection is transparent.
- [ ] Mood/energy/stress is implemented or gated.

### Task 1.32 — Complete goals, identity, milestones, and score explanation

#### Status

- [ ] Not started

#### Priority

P2 — Required for MVP

#### Depends on

1.10, 1.24

#### Blocks

None

#### Why

Goals and identity scoring are core product concepts and must be understandable, editable, and verifiable.

#### Current code evidence

- `lib/models/goal_model.dart` and `identity_profile_model.dart` exist.
- `lib/repositories/goal_repository.dart` exists.
- `lib/providers/goal_provider.dart` and `identity_provider.dart` stream data.
- `lib/views/goals/*` files exist.
- `lib/services/state_aggregator_service.dart` updates identity profile.

#### Gap

Create/edit/archive, milestones, score explanation, identity-habit links, and event consistency are not release-complete.

#### Spec source

Actual code; old feature matrix; audit category requirement.

#### Build order prerequisite

1.10, 1.24

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Complete goals, identity, milestones, and identity score explanation.
Files to inspect first: lib/models/goal_model.dart, lib/models/identity_profile_model.dart, lib/repositories/goal_repository.dart, lib/providers/goal_provider.dart, lib/providers/identity_provider.dart, lib/views/goals/, lib/services/state_aggregator_service.dart.
Files allowed to modify: goal/identity models, repository/provider, goals UI, focused tests.
Firestore paths: /users/{uid}/goals/{goalId}, /users/{uid}/identity_profile/main, /users/{uid}/habit_logs/{logId}, /users/{uid}/dailySummaries/{date}.
R2 paths: None.
Cloudflare Worker endpoints: None.
Feature flags: AI explanations disabled unless Worker path exists.
Requirements: create/edit/archive goals; milestones complete; score contributors are transparent; identity progress event validates.
Events: identity_created, identity_updated, identity_archived, identity_habit_linked, identity_progress_changed, milestone_completed.
Verification: manual goal lifecycle and score update after task/habit completion.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/models/goal_model.dart`
- `lib/repositories/goal_repository.dart`
- `lib/providers/goal_provider.dart`
- `lib/providers/identity_provider.dart`
- `lib/views/goals/*`
- `lib/services/state_aggregator_service.dart`
- tests

#### Firestore paths

- `/users/{uid}/goals/{goalId}`
- `/users/{uid}/identity_profile/main`
- `/users/{uid}/habit_logs/{logId}`
- `/users/{uid}/dailySummaries/{date}`

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

- `identity_created`
- `identity_updated`
- `identity_archived`
- `identity_habit_linked`
- `identity_progress_changed`
- `milestone_completed`

#### Dependencies

Routine/habit events and state aggregator.

#### How to verify

- Automated: goal repository/state aggregator tests.
- Manual: create goal, link habit, complete milestone, inspect score explanation.

#### Estimate

2 days

#### Done Criteria

- [ ] Goal lifecycle works.
- [ ] Milestones work.
- [ ] Identity score has visible explanation.
- [ ] Events validate.

### Task 1.33 — Complete interactive AI coach Worker integration and UI states

#### Status

- [ ] Not started

#### Priority

P2 — Required for MVP

#### Depends on

1.3, 1.4, 1.5, 1.11, 1.32

#### Blocks

None

#### Why

Coach chat must be useful, safe, and fail gracefully when Workers or AI are disabled.

#### Current code evidence

- `lib/views/tabs/coach_tab.dart` exists.
- `lib/services/coach_service.dart` saves user and assistant messages.
- `lib/services/gemini_service.dart` calls `COACH_REPLY_ENDPOINT`.
- `workers/coach-reply-worker/src/index.js` exists.

#### Gap

Interactive coach loading/error/disabled states, safety branches, duplicated chat write paths, Remote Config kill switches, and event consistency need finalization.

#### Spec source

Required Worker Pattern; actual code; audit category.

#### Build order prerequisite

1.3, 1.4, 1.5, 1.11, 1.32

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Complete interactive AI coach integration and UI states using Cloudflare Workers only.
Files to inspect first: lib/views/tabs/coach_tab.dart, lib/services/coach_service.dart, lib/services/gemini_service.dart, workers/coach-reply-worker/src/index.js, lib/services/remote_config_service.dart.
Files allowed to modify: coach UI/service/client, Worker tests, focused Flutter tests.
Firestore paths: /users/{uid}/coach_messages/{messageId}, /users/{uid}/coach_speak_log/{logId}, /users/{uid}/events/{eventId}.
R2 paths: None.
Cloudflare Worker endpoints: COACH_REPLY_ENDPOINT.
Feature flags: ENABLE_AI_COACH_WORKER, Remote Config AI/coach kill switches.
Requirements: no API keys in Flutter; disabled state works; safety branch displays safe copy; events validate; old `coach_chats` fallback does not create duplicate active writes unless intentional.
Events: coach_message_sent, coach_replied, coach_re_enabled.
Verification: mocked Worker chat tests and manual disabled/enabled smoke.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/views/tabs/coach_tab.dart`
- `lib/services/coach_service.dart`
- `lib/services/gemini_service.dart`
- Worker tests
- focused Flutter tests

#### Firestore paths

- `/users/{uid}/coach_messages/{messageId}`
- `/users/{uid}/coach_speak_log/{logId}`
- `/users/{uid}/events/{eventId}`

#### R2 paths

None

#### Cloudflare Worker endpoints

- `COACH_REPLY_ENDPOINT`

#### Events

- `coach_message_sent`
- `coach_replied`
- `coach_re_enabled`

#### Dependencies

Cloudflare API service, Worker contracts, Remote Config kill switches.

#### How to verify

- Automated: coach service/UI tests with mocked Worker.
- Manual: send coach message with Worker disabled, endpoint missing, and dev endpoint.

#### Estimate

2 days

#### Done Criteria

- [ ] Coach works through Worker only.
- [ ] Disabled/error states are usable.
- [ ] Safety branches render safely.
- [ ] No Flutter AI secrets exist.

### Task 1.34 — Align proactive rule engine, budgets, and AI coach triggers

#### Status

- [ ] Not started

#### Priority

P2 — Required for MVP

#### Depends on

1.4, 1.5, 1.25, 1.32, 1.33

#### Blocks

None

#### Why

Proactive coaching should be helpful without notification spam, invalid event triggers, or unexpected AI cost.

#### Current code evidence

- `lib/core/event_orchestrator.dart` evaluates rules for every event.
- `lib/services/rule_engine_service.dart` defines rule conditions.
- `lib/services/coach_service.dart` saves proactive messages and speak logs.
- `lib/services/notification_service.dart` has budget reservation logic.
- `lib/services/state_aggregator_service.dart` builds context snapshots.

#### Gap

Rule triggers, cooldowns, budget decisions, AI generation failures, context payloads, and safety branches need consistency and tests.

#### Spec source

Actual code; AI master engine docs; audit finding.

#### Build order prerequisite

1.4, 1.5, 1.25, 1.32, 1.33

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Align proactive coach rule engine, notification budgets, cooldowns, and AI fallback messages.
Files to inspect first: lib/core/event_orchestrator.dart, lib/services/rule_engine_service.dart, lib/services/coach_service.dart, lib/services/state_aggregator_service.dart, lib/services/notification_service.dart, test/services/rule_engine_service_contract_test.dart, test/services/coach_service_contract_test.dart.
Files allowed to modify: orchestrator, rule engine, coach/notification adapters, focused tests.
Firestore paths: /users/{uid}/coach_messages/{messageId}, /users/{uid}/coach_speak_log/{logId}, /users/{uid}/notificationLog/{logId}, /users/{uid}/events/{eventId}.
R2 paths: None.
Cloudflare Worker endpoints: AI_GENERATE_ENDPOINT.
Feature flags: AI coach/proactive kill switches and notification budget config.
Requirements: no invalid event names; fallback message used when AI fails; budget/cooldown logs are consistent; no duplicate replay side effects.
Events: coach_replied, notification_suppressed, suggestion_generated if used.
Verification: rule engine/orchestrator focused tests and manual slip/missed-task trigger.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/core/event_orchestrator.dart`
- `lib/services/rule_engine_service.dart`
- `lib/services/coach_service.dart`
- `lib/services/notification_service.dart`
- `lib/services/state_aggregator_service.dart`
- tests

#### Firestore paths

- `/users/{uid}/coach_messages/{messageId}`
- `/users/{uid}/coach_speak_log/{logId}`
- `/users/{uid}/notificationLog/{logId}`
- `/users/{uid}/events/{eventId}`

#### R2 paths

None

#### Cloudflare Worker endpoints

- `AI_GENERATE_ENDPOINT`

#### Events

- `coach_replied`
- `notification_suppressed`
- `suggestion_generated`

#### Dependencies

Coach Worker integration, event validator, and notification budget integration from Task 1.25.

#### How to verify

- Automated: rule/cooldown/budget tests.
- Manual: trigger smoking slip, missed task, streak milestone, and AI failure fallback.

#### Estimate

2 days

#### Done Criteria

- [ ] Proactive rules reference valid events.
- [ ] Cooldown and budget are enforced.
- [ ] AI failure falls back safely.
- [ ] Replay does not duplicate messages.

### Task 1.35 — Complete ghost absence and comeback system

#### Status

- [ ] Not started

#### Priority

P2 — Required for MVP

#### Depends on

1.10, 1.24, 1.33

#### Blocks

None

#### Why

Returning users need a supportive recovery flow that preserves streak fairness and does not rely on Firebase Functions.

#### Current code evidence

- `lib/services/routine_service.dart` detects comeback after gaps and writes pending suggestions.
- `lib/views/comeback/comeback_modal.dart` exists.
- `lib/services/streak_service.dart` can pause/resume streaks.
- `functions/jobs/inactivityCheck.js` is legacy inactive reference.

#### Gap

Modal trigger, streak pause/resume, suggestion choices, event payloads, and any background/cron expectations need Spark-only behavior and tests.

#### Spec source

Actual code; legacy functions reference; audit category.

#### Build order prerequisite

1.10, 1.24, 1.33

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Complete client-side ghost absence/comeback MVP without Firebase Functions.
Files to inspect first: lib/services/routine_service.dart, lib/views/comeback/comeback_modal.dart, lib/services/streak_service.dart, lib/views/tabs/home_tab.dart, lib/core/event_orchestrator.dart, functions/jobs/inactivityCheck.js as legacy reference only.
Files allowed to modify: routine service, comeback modal trigger/UI, streak service adapters, tests/docs.
Firestore paths: /users/{uid}, /users/{uid}/profile/main, /users/{uid}/streaks/{streakId}, /users/{uid}/suggestions/{suggestionId}, /users/{uid}/events/{eventId}.
R2 paths: None.
Cloudflare Worker endpoints: None for MVP unless a future Cloudflare Cron task is explicitly scoped.
Feature flags: optional comeback feature flag if risk remains.
Requirements: no Firebase Functions; absence flow runs on app open; user can choose/dismiss comeback path; streaks resume safely; suggestions are reviewed.
Events: ghost_day_detected, comeback_initiated, comeback_path_chosen, suggestion_generated.
Verification: seed old lastSeen and reopen app.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/services/routine_service.dart`
- `lib/views/comeback/comeback_modal.dart`
- `lib/services/streak_service.dart`
- `lib/views/tabs/home_tab.dart`
- tests/docs

#### Firestore paths

- `/users/{uid}`
- `/users/{uid}/profile/main`
- `/users/{uid}/streaks/{streakId}`
- `/users/{uid}/suggestions/{suggestionId}`
- `/users/{uid}/events/{eventId}`

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

- `ghost_day_detected`
- `comeback_initiated`
- `comeback_path_chosen`
- `suggestion_generated`

#### Dependencies

Routine day lifecycle, streak service, suggestion model, event validator.

#### How to verify

- Automated: routine comeback service tests.
- Manual: seed `lastSeen` 3+ and 7+ days ago, launch app, choose a path, inspect streaks/events.

#### Estimate

2 days

#### Done Criteria

- [ ] Comeback modal triggers reliably.
- [ ] Streaks are paused/resumed safely.
- [ ] Events validate.
- [ ] No Firebase Functions dependency exists.

### Task 1.36 — Implement suggestion and weekly insight lifecycle

#### Status

- [ ] Not started

#### Priority

P3 — Important polish

#### Depends on

1.3, 1.10

#### Blocks

None

#### Why

Suggestions and weekly insights connect AI/rules to user action. Without accept/reject lifecycle, generated advice is not auditable.

#### Current code evidence

- `lib/core/providers.dart` has `trackerSuggestionsProvider` using raw maps.
- `lib/views/routine/ai_routine_panel.dart` defines local `AiSuggestion`.
- `lib/services/routine_service.dart` writes comeback suggestions.
- `EventNames` contains suggestion and `weeklyInsightReady` events.
- `docs/firestore_schema_v1_mapping.md` lists `/suggestions` and `/weeklySummaries`.

#### Gap

There is no cohesive `SuggestionService`, status model, accept/dismiss side effects, weekly insight source, or UI surface contract.

#### Spec source

Actual code; old feature matrix; audit category.

#### Build order prerequisite

1.3, 1.10

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Implement the suggestion accept/dismiss lifecycle and weekly insight MVP surface or gate.
Files to inspect first: lib/core/providers.dart, lib/views/routine/ai_routine_panel.dart, lib/services/routine_service.dart, lib/core/constants/event_names.dart, docs/firestore_schema_v1_mapping.md.
Files allowed to modify: suggestion model/service/provider, small UI integrations, focused tests.
Firestore paths: /users/{uid}/suggestions/{suggestionId}, /users/{uid}/weeklySummaries/{weekKey}, /users/{uid}/events/{eventId}.
R2 paths: None.
Cloudflare Worker endpoints: AI_GENERATE_ENDPOINT only if insight generation is enabled and Worker-verified.
Feature flags: weekly insights can be gated if incomplete.
Requirements: pending/accepted/dismissed statuses; side effects are explicit; weekly insights are either produced safely or Coming Soon.
Events: suggestion_generated, suggestion_accepted, suggestion_dismissed, weekly_insight_ready.
Verification: accept/dismiss suggestion and inspect state/events.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/models/suggestion_model.dart`
- `lib/services/suggestion_service.dart`
- `lib/core/providers.dart`
- `lib/views/routine/ai_routine_panel.dart`
- focused tests

#### Firestore paths

- `/users/{uid}/suggestions/{suggestionId}`
- `/users/{uid}/weeklySummaries/{weekKey}`
- `/users/{uid}/events/{eventId}`

#### R2 paths

None

#### Cloudflare Worker endpoints

- `AI_GENERATE_ENDPOINT` if enabled

#### Events

- `suggestion_generated`
- `suggestion_accepted`
- `suggestion_dismissed`
- `weekly_insight_ready`

#### Dependencies

Suggestion model, event validator, routine/coach rules.

#### How to verify

- Automated: suggestion service tests.
- Manual: generate, accept, dismiss, and inspect Firestore/events.

#### Estimate

1 day

#### Done Criteria

- [ ] Suggestion statuses are consistent.
- [ ] Accept/dismiss side effects are clear.
- [ ] Weekly insight is implemented or gated.
- [ ] Events validate.

### Task 1.37 — Complete notification center and alarm callbacks

#### Status

- [ ] Not started

#### Priority

P3 — Important polish

#### Depends on

1.36

#### Blocks

None

#### Why

Users need a visible history of reminders/notifications and reliable callbacks for alarm actions.

#### Current code evidence

- `lib/views/notifications/notification_center_screen.dart` exists.
- `lib/core/router/app_router.dart` routes `/notifications`.
- `lib/services/notification_service.dart` writes notification-related docs.
- `lib/views/alarms/alarm_ringing_screen.dart` and `snooze_reason_sheet.dart` exist.

#### Gap

Notification center read model, tap/dismiss/missed states, alarm action deep links, and stale notification cleanup need final integration.

#### Spec source

Actual code; audit category requirement.

#### Build order prerequisite

1.36

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Complete notification center and alarm callback flows.
Files to inspect first: lib/views/notifications/notification_center_screen.dart, lib/services/notification_service.dart, lib/views/alarms/alarm_ringing_screen.dart, lib/views/alarms/snooze_reason_sheet.dart, lib/core/router/app_router.dart.
Files allowed to modify: notification center, alarm callbacks/screens, notification service, focused tests.
Firestore paths: /users/{uid}/notificationLog/{logId}, /users/{uid}/scheduled_notifications/{notificationId}, /users/{uid}/tasks/{taskId}.
R2 paths: None.
Cloudflare Worker endpoints: None.
Feature flags: notifications kill switch.
Requirements: list sent/tapped/dismissed/suppressed/missed; alarm actions update task or snooze safely; stale pending notifications are visible or cleaned.
Events: notification_tapped, notification_dismissed, notification_missed, task_started, task_skipped.
Verification: manual alarm action and notification center history check.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/views/notifications/notification_center_screen.dart`
- `lib/services/notification_service.dart`
- `lib/views/alarms/*`
- focused tests

#### Firestore paths

- `/users/{uid}/notificationLog/{logId}`
- `/users/{uid}/scheduled_notifications/{notificationId}`
- `/users/{uid}/tasks/{taskId}`

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

- `notification_tapped`
- `notification_dismissed`
- `notification_missed`
- `task_started`
- `task_skipped`

#### Dependencies

Notification service hardening.

#### How to verify

- Automated: notification center parser tests if feasible.
- Manual: send/tap/dismiss an alarm notification and inspect history.

#### Estimate

1 day

#### Done Criteria

- [ ] Notification center reflects notification state.
- [ ] Alarm actions perform expected task operations.
- [ ] Missed/stale notifications are handled.

### Task 1.38 — Create legal, support, terms, privacy, and delete-account pages

#### Status

- [ ] Not started

#### Priority

P1 — Blocks many features

#### Depends on

1.1

#### Blocks

None

#### Why

Play Store requires privacy policy, account deletion instructions, support contact, and clear terms before internal testing.

#### Current code evidence

- No Cloudflare Pages app or static legal pages were found.
- `profile_tab.dart` has account actions but public URLs are not established.
- Strict rules require Cloudflare Pages, not Firebase Hosting/App Hosting.

#### Gap

Privacy policy URL, terms URL, support page, delete account instructions page, and report bug/feedback page are missing.

#### Spec source

Play Store readiness requirement; Spark-only architecture requirement.

#### Build order prerequisite

1.1

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Create Cloudflare Pages-ready legal/support/delete-account static pages and link plan.
Files to inspect first: docs/OPTIVUS_STRICT_TASK_RULES.md, docs/spark_cloudflare_architecture.md, lib/views/tabs/profile_tab.dart, README.md.
Files allowed to modify: docs/static page source under a Cloudflare Pages folder, profile link constants if needed, no Firebase Hosting config.
Firestore paths: None.
R2 paths: None.
Cloudflare Worker endpoints: None.
Feature flags: None.
Requirements: privacy policy, terms, support/contact, delete account instructions, report bug/feedback page; no Firebase Hosting/App Hosting; URLs documented for Play Store.
Events: None.
Verification: local static page preview or file review; link checklist.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `pages/` or `docs/legal/`
- `README.md`
- `docs/spark_cloudflare_architecture.md`
- optional profile link constants

#### Firestore paths

None

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

None

#### Dependencies

Cloudflare Pages account/deployment outside Firebase.

#### How to verify

- Automated: link/static file checks if available.
- Manual: open each page locally and confirm Play Store-required content.

#### Estimate

1 day

#### Done Criteria

- [ ] Privacy policy page exists.
- [ ] Terms page exists.
- [ ] Support/report bug page exists.
- [ ] Delete account instructions page exists.
- [ ] No Firebase Hosting/App Hosting is added.

### Task 1.39 — Add in-app account deletion request flow

#### Status

- [ ] Not started

#### Priority

P1 — Blocks many features

#### Depends on

1.6, 1.16, 1.38

#### Blocks

None

#### Why

Play Store requires users to be able to request account/data deletion from inside the app or clearly reach deletion instructions.

#### Current code evidence

- `lib/views/tabs/profile_tab.dart` has profile/account actions.
- `lib/services/firestore_service.dart` has `deleteUserOwnedData()` and `deleteAllUserData()`.
- `firestore.rules` has `/deletion_requests/{requestId}` create-only.
- `docs/firestore_schema_v1_mapping.md` lists deletion requests.

#### Gap

The current direct client deletion path may be risky, lacks request/status lifecycle, legal copy, cancellation/re-auth UX, notification cancellation, and worker/manual fulfillment plan.

#### Spec source

Play Store readiness requirement; actual code.

#### Build order prerequisite

1.6, 1.16, 1.38

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Add an in-app account deletion request flow compatible with Spark-only architecture.
Files to inspect first: lib/views/tabs/profile_tab.dart, lib/services/firestore_service.dart, lib/services/auth_service.dart, firestore.rules, docs/firestore_schema_v1_mapping.md.
Files allowed to modify: profile/account UI, Firestore service/request model, docs/tests.
Firestore paths: /users/{uid}/deletion_requests/{requestId}, /users/{uid}/events/{eventId}, /users/{uid}/scheduled_notifications/{notificationId}.
R2 paths: users/{uid}/profile/* and users/{uid}/uploads/* may need deletion lifecycle documentation.
Cloudflare Worker endpoints: optional Cloudflare deletion Worker only if scoped; no Firebase Functions.
Feature flags: deletion worker flag if backend is not ready.
Requirements: user can request deletion; status visible; legal page linked; direct destructive delete is guarded by re-auth/confirmation; no Firebase Functions.
Events: account_deleted only when deletion is actually completed; optional deletion_requested if added and validated.
Verification: emulator/manual request creation and rules check.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/views/tabs/profile_tab.dart`
- `lib/services/firestore_service.dart`
- `lib/services/auth_service.dart`
- deletion request model/test/docs

#### Firestore paths

- `/users/{uid}/deletion_requests/{requestId}`
- `/users/{uid}/events/{eventId}`
- `/users/{uid}/scheduled_notifications/{notificationId}`

#### R2 paths

- `users/{uid}/profile/*`
- `users/{uid}/uploads/*`

#### Cloudflare Worker endpoints

None unless a Cloudflare deletion Worker is explicitly added later.

#### Events

- `account_deleted`

#### Dependencies

Legal delete instructions page and Firestore rules.

#### How to verify

- Automated: request model/service tests.
- Manual: create request, verify Firestore rules block updates/deletes, confirm legal page link.

#### Estimate

1 day

#### Done Criteria

- [ ] In-app deletion request exists.
- [ ] Status and instructions are visible.
- [ ] Destructive delete is guarded.
- [ ] No Firebase Functions are used.

### Task 1.40 — Complete data export and deletion lifecycle

#### Status

- [ ] Not started

#### Priority

P1 — Blocks many features

#### Depends on

1.39

#### Blocks

None

#### Why

Users need access to their data and a documented deletion lifecycle that includes Firestore data, scheduled notifications, and R2 objects.

#### Current code evidence

- `lib/services/firestore_service.dart` has `exportUserData()` and `deleteUserOwnedData()`.
- `FirestoreService.userOwnedCollectionIds` lists user collections.
- `firestore.rules` has `/data_exports/{exportId}` and `/deletion_requests/{requestId}` create-only.
- R2 upload paths are planned but not part of current client deletion.

#### Gap

Export request/status, export file delivery approach, nested subcollection deletion coverage, R2 object cleanup, cancellation window, and tests are incomplete.

#### Spec source

Play Store readiness requirement; actual code; R2 architecture.

#### Build order prerequisite

1.39

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Complete Spark-only data export and deletion lifecycle.
Files to inspect first: lib/services/firestore_service.dart, lib/views/tabs/profile_tab.dart, firestore.rules, docs/firestore_schema_v1_mapping.md, lib/services/r2_upload_service.dart.
Files allowed to modify: export/delete request models/service/UI, docs/tests; Cloudflare Worker only if explicitly scoped.
Firestore paths: /users/{uid}/data_exports/{exportId}, /users/{uid}/deletion_requests/{requestId}, all user-owned subcollections.
R2 paths: users/{uid}/profile/*, users/{uid}/uploads/*.
Cloudflare Worker endpoints: optional export/delete Worker endpoints; no Firebase Functions.
Feature flags: export/delete Worker flags if backend is not ready.
Requirements: export can be generated or request queued; deletion lifecycle covers Firestore and R2 cleanup plan; nested subcollections are not missed; manual fulfillment fallback documented.
Events: account_deleted only on completion; export request event only if added and validated.
Verification: service tests with fake Firestore where possible and manual export output review.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/services/firestore_service.dart`
- `lib/views/tabs/profile_tab.dart`
- export/delete models/tests/docs
- optional Cloudflare Worker docs

#### Firestore paths

- `/users/{uid}/data_exports/{exportId}`
- `/users/{uid}/deletion_requests/{requestId}`
- all `/users/{uid}` subcollections in `FirestoreService.userOwnedCollectionIds`

#### R2 paths

- `users/{uid}/profile/*`
- `users/{uid}/uploads/*`

#### Cloudflare Worker endpoints

None unless a Cloudflare export/delete Worker is explicitly scoped.

#### Events

- `account_deleted`

#### Dependencies

Deletion request flow, Firestore schema, R2 cleanup policy.

#### How to verify

- Automated: export JSON includes expected collections; delete helper covers nested paths if implemented.
- Manual: request export/delete and inspect status/copy.

#### Estimate

2 days

#### Done Criteria

- [ ] Export flow/request exists.
- [ ] Deletion lifecycle covers Firestore and R2 plan.
- [ ] Manual fallback is documented.
- [ ] Play Store deletion requirement is satisfied.

### Task 1.41 — Finalize Android package identity, signing, versioning, icon, splash, and app name

#### Status

- [ ] Not started

#### Priority

P0 — Blocks all work

#### Depends on

1.1, 1.2, 1.3
#### Blocks

None

#### Why

The app cannot be uploaded to Play Store with `com.example.*`, debug signing, placeholder app name, or unfinished branding assets.

#### Current code evidence

- `android/app/build.gradle.kts` uses `namespace = "com.example.optivus"` and `applicationId = "com.example.optivus"`.
- `android/app/src/main/kotlin/com/example/optivus/MainActivity.kt` and `android/app/src/main/kotlin/com/example/optivus/ScreenTimePlugin.kt` still use the example package path/name.
- `lib/services/screen_time_bridge.dart` still uses MethodChannel `com.example.optivus/screen_time`.
- `android/app/google-services.json` is registered for Android package `com.example.optivus`.
- Release build signs with debug keys.
- `android/app/src/main/AndroidManifest.xml` label is `optivus2`.
- Launcher icons exist in `android/app/src/main/res/mipmap-*`.
- `pubspec.yaml` version is `1.0.0+1`.

#### Gap

Package name, native Kotlin package paths/classes, MethodChannel naming, Firebase Android app registration/config alignment, release signing, versioning, app name, launcher icon, splash, Crashlytics mapping upload setting, and release build verification are not ready.

#### Spec source

Play Store release rules; actual Android config.

#### Build order prerequisite

1.1, 1.2, 1.3
#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Finalize Android release identity, signing, versioning, app name, icon, and splash readiness.
Files to inspect first: android/app/build.gradle.kts, android/app/src/main/AndroidManifest.xml, android/app/src/main/kotlin/com/example/optivus/MainActivity.kt, android/app/src/main/kotlin/com/example/optivus/ScreenTimePlugin.kt, lib/services/screen_time_bridge.dart, android/app/google-services.json, pubspec.yaml, android/app/src/main/res/, assets/images/logo.png.
Files allowed to modify: Android app config/resources, pubspec version, docs; no feature code.
Firestore paths: None.
R2 paths: None.
Cloudflare Worker endpoints: None.
Feature flags: Mapbox/package references must align with final applicationId.
Requirements: package not com.example; signing uses release keystore config without committing secrets; app label final; icon/splash final; Firebase app config updated for final package. Package rename coverage must include `android/app/src/main/kotlin/com/example/optivus/MainActivity.kt`, `android/app/src/main/kotlin/com/example/optivus/ScreenTimePlugin.kt`, `lib/services/screen_time_bridge.dart`, MethodChannel name `com.example.optivus/screen_time`, `android/app/google-services.json`, and Firebase Android app registration for the final package ID.
Events: None.
Verification: flutter analyze, flutter build appbundle --release after signing prerequisites are available.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `android/app/build.gradle.kts`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/example/optivus/MainActivity.kt`
- `android/app/src/main/kotlin/com/example/optivus/ScreenTimePlugin.kt`
- `lib/services/screen_time_bridge.dart`
- `android/app/google-services.json`
- `pubspec.yaml`
- Android resources
- release docs

#### Firestore paths

None

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

None

#### Dependencies

Final Play package name, Firebase Android app registration, release keystore.

#### How to verify

- Automated: `flutter analyze`; `flutter build appbundle --release`.
- Manual: install release build, verify app name/icon/splash and package name.

#### Estimate

1 day

#### Done Criteria

- [ ] Package name is final.
- [ ] Native Kotlin package paths/classes, screen-time MethodChannel, `google-services.json`, and Firebase Android app registration match the final package ID.
- [ ] Release signing is configured without committed secrets.
- [ ] App name/icon/splash are final.
- [ ] Release app bundle builds.

### Task 1.42 — Add release observability with Analytics, Crashlytics, and Remote Config

#### Status

- [ ] Not started

#### Priority

P2 — Required for MVP

#### Depends on

1.3, 1.5, 1.41
#### Blocks

None

#### Why

Internal testing needs crash visibility, feature flag visibility, and privacy-safe analytics for core funnels.

#### Current code evidence

- `lib/main.dart` initializes Crashlytics pipe through `GlobalErrorHandler`.
- `lib/services/global_error_handler.dart` exists.
- `lib/services/remote_config_service.dart` exists.
- `test/services/analytics_service_contract_test.dart` exists, but no clear `AnalyticsService` file was found.
- `pubspec.yaml` did not show `firebase_analytics`.

#### Gap

Analytics dependency/service status, event naming, consent/privacy copy, Crashlytics mapping upload setting, and Remote Config release defaults need a focused release pass.

#### Spec source

Play Store readiness requirement; actual code audit.

#### Build order prerequisite

1.3, 1.5, 1.41
#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Add or verify release observability through allowed Firebase services only.
Files to inspect first: pubspec.yaml, lib/main.dart, lib/services/global_error_handler.dart, lib/services/remote_config_service.dart, test/services/analytics_service_contract_test.dart, android/app/build.gradle.kts.
Files allowed to modify: observability services/config/tests/docs only.
Firestore paths: None unless logging opt-in settings under /users/{uid}/profile/main.
R2 paths: None.
Cloudflare Worker endpoints: None.
Feature flags: Remote Config release defaults and kill switches.
Requirements: Firebase Analytics only if safe and added intentionally; Crashlytics enabled for release; no PII in analytics; Remote Config defaults documented.
Events: analytics event names are separate from Firestore events unless mapped explicitly.
Verification: flutter analyze/test and manual debug logs.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `pubspec.yaml` only if adding `firebase_analytics` intentionally
- `lib/services/analytics_service.dart`
- `lib/services/global_error_handler.dart`
- `lib/services/remote_config_service.dart`
- tests/docs

#### Firestore paths

None

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

Analytics events as a separate client analytics layer; no Firestore event changes unless explicitly required.

#### Dependencies

Allowed Firebase Analytics, Crashlytics, Remote Config.

#### How to verify

- Automated: analytics/remote config contract tests.
- Manual: trigger test error in debug-safe mode and inspect logs/config values.

#### Estimate

1 day

#### Done Criteria

- [ ] Observability services are intentional and documented.
- [ ] No PII analytics payloads.
- [ ] Crashlytics release behavior is configured.
- [ ] Remote Config defaults are release-safe.

### Task 1.43 — Review App Check, FCM, and Performance Monitoring readiness

#### Status

- [ ] Not started

#### Priority

P3 — Important polish

#### Depends on

1.3, 1.25, 1.41
#### Blocks

None

#### Why

Allowed Firebase services should be used only if safe and configured without introducing billing or Play Store risk.

#### Current code evidence

- `lib/main.dart` activates Firebase App Check with Play Integrity in release and debug provider otherwise.
- `pubspec.yaml` includes `firebase_app_check` but not clearly FCM or Performance Monitoring packages.
- Notification service uses local notifications; FCM is not clearly wired.

#### Gap

App Check provider behavior, debug token process, FCM decision, Performance Monitoring decision, and release documentation are incomplete.

#### Spec source

Allowed Firebase services list; Play Store readiness requirement.

#### Build order prerequisite

1.3, 1.25, 1.41
#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Review App Check, FCM, and Performance Monitoring readiness and either configure safely or explicitly defer.
Files to inspect first: lib/main.dart, pubspec.yaml, android/app/google-services.json, android/app/build.gradle.kts, docs/spark_cloudflare_architecture.md, notification service files.
Files allowed to modify: app startup config, docs, optional Firebase package config only if allowed and safe.
Firestore paths: /users/{uid}/devices/{deviceId} if FCM is enabled.
R2 paths: None.
Cloudflare Worker endpoints: None.
Feature flags: FCM/performance/App Check operational flags if used.
Requirements: no billing requirement; local notifications remain enough for MVP if FCM deferred; App Check debug/release process documented.
Events: notification_scheduled/sent only if FCM touches notification path.
Verification: debug and release startup checks where possible.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `lib/main.dart`
- `pubspec.yaml` only if adding an allowed Firebase package intentionally
- `docs/spark_cloudflare_architecture.md`
- notification/device token docs/tests

#### Firestore paths

- `/users/{uid}/devices/{deviceId}` if FCM is enabled

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

- `notification_scheduled`
- `notification_sent`

#### Dependencies

Firebase App Check, optional FCM, optional Performance Monitoring.

#### How to verify

- Automated: startup tests where feasible.
- Manual: debug provider startup and release Play Integrity configuration checklist.

#### Estimate

0.5 day

#### Done Criteria

- [ ] App Check release/debug behavior is documented.
- [ ] FCM is safely configured or deferred.
- [ ] Performance Monitoring is safely configured or deferred.
- [ ] No billing-only Firebase service is added.

### Task 1.44 — Complete permissions audit and Play Store Data Safety checklist

#### Status

- [ ] Not started

#### Priority

P1 — Blocks many features

#### Depends on

1.23, 1.25, 1.27, 1.29, 1.38, 1.40, 1.42, 1.43
#### Blocks

None

#### Why

Play Store review can fail if permissions or Data Safety answers do not match runtime behavior.

#### Current code evidence

- `android/app/src/main/AndroidManifest.xml` declares notifications, boot, vibration, exact alarm, full-screen intent, location, foreground service location, and package usage stats.
- Screen time and fitness features process sensitive device data.
- Network-backed features include Firebase/Firestore, Cloudflare Workers, Cloudflare R2 signed upload URLs, Mapbox tiles, Google Books API, ipapi.co, and Open-Meteo.
- Privacy/export/delete tasks are required.

#### Gap

Permission justifications, release Android INTERNET permission, feature-by-feature data collection, third-party network/API sharing, retention, deletion, safety answers, and fallback behavior are not documented in final form.

#### Spec source

Play Store readiness requirement.

#### Build order prerequisite

1.23, 1.25, 1.27, 1.29, 1.38, 1.40, 1.42, 1.43
#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Complete Android permissions audit, third-party network/API privacy audit, and Play Store Data Safety checklist.
Files to inspect first: android/app/src/main/AndroidManifest.xml, pubspec.yaml, lib/services/screen_time_importer.dart, lib/services/location_tracking_service.dart, lib/services/notification_service.dart, lib/services/firestore_service.dart, lib/services/r2_upload_service.dart, lib/services/google_books_service.dart, lib/services/fitness_route_service.dart, hydration/weather/IP lookup code paths, Worker clients, legal/privacy docs.
Files allowed to modify: docs/checklists/manifest only if removing unjustified permissions; no feature code unless permission removal requires it.
Firestore paths: all user-owned data categories documented.
R2 paths: users/{uid}/profile/*, users/{uid}/uploads/* if uploads are enabled.
Cloudflare Worker endpoints: all AI/R2 endpoints listed for data processing.
Feature flags: disabled features must be reflected in Data Safety if not shipped.
Requirements: justify each permission; remove unused permissions; complete Data Safety answers; align privacy policy. Verify `android/app/src/main/AndroidManifest.xml` includes `android.permission.INTERNET` if network features are shipped. Network features include Firebase, Firestore, Cloudflare Workers, R2 signed upload, Mapbox tiles, Google Books, ipapi.co, and Open-Meteo. Audit third-party network/API usage for Cloudflare Workers, Cloudflare R2 signed upload URLs, Mapbox, Google Books API, ipapi.co, Open-Meteo, and Firebase; document what data is sent, why it is sent, retention if known, and Data Safety/privacy policy impact. Hydration weather/IP lookup must be opt-in, disabled, or clearly disclosed.
Events: None.
Verification: manifest review and real-device permission prompts.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `docs/play_store_data_safety.md`
- `docs/permissions_audit.md`
- `android/app/src/main/AndroidManifest.xml` if removing permissions
- privacy/legal docs

#### Firestore paths

All user-owned data paths documented.

#### R2 paths

- `users/{uid}/profile/*`
- `users/{uid}/uploads/*`

#### Cloudflare Worker endpoints

- `ROUTINE_IMPORT_ENDPOINT`
- `COACH_REPLY_ENDPOINT`
- `AI_GENERATE_ENDPOINT`
- `R2_SIGNED_UPLOAD_ENDPOINT`
- `R2_DELETE_UPLOAD_ENDPOINT`

#### Events

None

#### Dependencies

Final feature set, legal pages, export/delete lifecycle.

#### How to verify

- Automated: manifest permission diff review.
- Manual: complete Play Console checklist using documented answers.

#### Estimate

1 day

#### Done Criteria

- [ ] Every permission is justified or removed.
- [ ] Release INTERNET permission is present when shipped network features require it.
- [ ] Third-party network/API privacy audit covers Cloudflare Workers, R2 signed uploads, Mapbox, Google Books API, ipapi.co, Open-Meteo, and Firebase.
- [ ] Hydration weather/IP lookup is opt-in, disabled, or clearly disclosed.
- [ ] Data Safety answers are documented.
- [ ] Privacy policy matches implementation.
- [ ] Disabled features are not claimed as active.

### Task 1.45 — Run dependency, license, secret, and security audit

#### Status

- [ ] Not started

#### Priority

P1 — Blocks many features

#### Depends on

1.1, 1.41, 1.44
#### Blocks

None

#### Why

Release must not ship debug secrets, committed service secrets, incompatible licenses, stale generated dependencies, or billing-only packages.

#### Current code evidence

- `android/app/google-services.json` is committed.
- `workers/coach-reply-worker/.dev.vars.example` and `.dev.vars` exist; `.gitignore` has Cloudflare secrets comments.
- `functions/node_modules/` and `workers/*/node_modules/` are present in the working tree.
- `docs/MEDITATION_AUDIO_LICENSES.md` exists.
- `pubspec.lock`, Worker `package-lock.json`, and Android Gradle files exist.

#### Gap

No final dependency/license/secret audit report exists, and generated dependency folders may confuse scans.

#### Spec source

Play Store readiness requirement; security audit requirement.

#### Build order prerequisite

1.1, 1.41, 1.44
#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Run dependency, license, secret, and security audit for release.
Files to inspect first: pubspec.yaml, pubspec.lock, android/app/google-services.json, .gitignore, workers/*/.dev.vars*, workers/*/package.json, functions/, docs/MEDITATION_AUDIO_LICENSES.md.
Files allowed to modify: docs, .gitignore, secret examples, dependency config if safe; no feature code.
Firestore paths: None.
R2 paths: None.
Cloudflare Worker endpoints: all endpoint names checked for no secrets.
Feature flags: dart-define examples only; no real secrets.
Requirements: no API keys beyond expected Firebase client config; no R2/AI/service account secrets; licenses documented; forbidden packages absent; node_modules policy documented.
Events: None.
Verification: secret scan commands and manual review.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `.gitignore`
- `docs/security_audit.md`
- `docs/MEDITATION_AUDIO_LICENSES.md`
- Worker `.dev.vars.example`
- dependency docs

#### Firestore paths

None

#### R2 paths

None

#### Cloudflare Worker endpoints

All configured endpoint names, no real secrets.

#### Events

None

#### Dependencies

Final package identity and feature set.

#### How to verify

- Automated: secret/dependency scan commands where available.
- Manual: inspect committed config, licenses, and generated dependency folders.

#### Estimate

1 day

#### Done Criteria

- [ ] No server/API/R2 secrets are committed.
- [ ] Forbidden packages are absent.
- [ ] Licenses are documented.
- [ ] Generated dependency folder policy is clear.

### Task 1.46 — Expand Flutter automated tests for release-critical flows

#### Status

- [ ] Not started

#### Priority

P2 — Required for MVP

#### Depends on

1.10, 1.24, 1.25, 1.31, 1.40
#### Blocks

None

#### Why

Release-critical service contracts need tests that agents can run after each feature change.

#### Current code evidence

- `test/services/*_contract_test.dart` files exist.
- `test/providers/routine_notifier_test.dart` exists.
- Some old docs mention skipped or missing tests.

#### Gap

Coverage is not sufficient for onboarding, routine materialization, selected date, habit variants, notification budget, export/delete, and permissions-sensitive services.

#### Spec source

Play Store readiness requirement; audit category.

#### Build order prerequisite

1.10, 1.24, 1.25, 1.31, 1.40
#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Add/repair Flutter tests for release-critical contracts.
Files to inspect first: test/, lib/services/, lib/providers/, lib/repositories/, lib/models/.
Files allowed to modify: tests and small testability seams only; avoid feature rewrites.
Firestore paths: all paths touched by tested services.
R2 paths: mocked only.
Cloudflare Worker endpoints: mocked only.
Feature flags: test enabled/disabled defaults.
Requirements: tests for routine materialization, task lifecycle, event validator, habit logs, streaks, notifications, coach fallback, export/delete, config flags.
Events: all events covered by tests.
Verification: flutter test.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `test/services/*`
- `test/providers/*`
- small test helpers

#### Firestore paths

All tested user-owned paths.

#### R2 paths

Mocked only.

#### Cloudflare Worker endpoints

Mocked only.

#### Events

All tested canonical events.

#### Dependencies

`flutter_test`, `fake_cloud_firestore`, Firebase auth mocks.

#### How to verify

- Automated: `flutter test`.
- Manual: review remaining skipped tests and explain any that are intentionally deferred.

#### Estimate

2 days

#### Done Criteria

- [ ] Release-critical services have tests.
- [ ] No unexplained skipped tests remain.
- [ ] `flutter test` result is documented.

### Task 1.47 — Expand Worker tests and local verification scripts

#### Status

- [ ] Not started

#### Priority

P2 — Required for MVP

#### Depends on

1.11, 1.12

#### Blocks

None

#### Why

Cloudflare Workers replace Firebase Functions, so Worker contract tests are release-critical.

#### Current code evidence

- `workers/routine-import-worker/test/routineImport.contract.test.js` exists.
- `workers/coach-reply-worker/package.json` and `workers/ai-gateway-worker/package.json` exist.
- R2 upload Worker does not exist until Task 1.12.
- `functions/test/*` is legacy Firebase Functions test code and should not be release target.

#### Gap

There is no uniform Worker test command matrix or full coverage for auth, safety, rate limits, R2, and malformed payloads.

#### Spec source

Required Worker Pattern; audit category.

#### Build order prerequisite

1.11, 1.12

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Expand Worker tests and local verification scripts for all active Cloudflare Workers.
Files to inspect first: workers/*/package.json, workers/*/src/index.js, workers/*/test/*, docs/spark_cloudflare_architecture.md, functions/test/ as legacy reference only.
Files allowed to modify: Worker tests/scripts/docs; no Flutter feature code.
Firestore paths: None unless a Worker explicitly writes after a separate task.
R2 paths: users/{uid}/uploads/* for R2 Worker tests.
Cloudflare Worker endpoints: routine import, coach reply, AI gateway, R2 signed upload/delete.
Feature flags: endpoint/feature flag docs.
Requirements: npm test works per Worker; tests cover no auth, bad auth, schema errors, rate limits, unsafe URLs, no Firebase Storage/GCS, and R2 path validation.
Events: None.
Verification: run Worker tests locally.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `workers/*/test/*.test.js`
- `workers/*/package.json`
- Worker test docs/scripts

#### Firestore paths

None

#### R2 paths

- `users/{uid}/uploads/*`

#### Cloudflare Worker endpoints

- Routine import
- Coach reply
- AI gateway
- R2 signed upload/delete

#### Events

None

#### Dependencies

Node/npm, Miniflare or Worker-compatible test runner.

#### How to verify

- Automated: run each Worker package test command.
- Manual: inspect docs for deprecated `functions/test` references.

#### Estimate

1 day

#### Done Criteria

- [ ] Active Workers have documented test commands.
- [ ] Auth and malformed input tests exist.
- [ ] R2 tests cover object key safety.
- [ ] Legacy Firebase Functions tests are not release blockers.

### Task 1.48 — Create manual QA scripts and real-device smoke checklist

#### Status

- [ ] Not started

#### Priority

P1 — Blocks many features

#### Depends on

1.2, 1.3, 1.33, 1.40, 1.41, 1.44, 1.46, 1.47
#### Blocks

None

#### Why

Some release risks require real-device verification: permissions, notifications, location, usage access, audio, release install, and Play Store internal test behavior.

#### Current code evidence

- Multiple permission-heavy features exist in Android manifest.
- `docs/feature_matrix.md` has per-feature verification notes.
- No final manual QA script file was found.

#### Gap

No final real-device test script exists for auth, onboarding, routine, trackers, notifications, fitness, maps, privacy, delete/export, offline audio, disabled flags, and release install.

#### Spec source

Play Store readiness requirement; audit category.

#### Build order prerequisite

1.2, 1.3, 1.33, 1.40, 1.41, 1.44, 1.46, 1.47
#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Create final manual QA scripts and real-device smoke checklist.
Files to inspect first: docs/feature_matrix.md, docs/implementation_inventory.md, android/app/src/main/AndroidManifest.xml, todo_V2_Final_PlayStore_Single_Phase.md.
Files allowed to modify: docs/manual QA files and TODO status only.
Firestore paths: all major user-owned paths listed in schema docs.
R2 paths: profile/uploads paths if upload flags enabled.
Cloudflare Worker endpoints: all Worker endpoints if enabled.
Feature flags: test flags off and enabled dev endpoints.
Requirements: cover fresh install, signup, onboarding, routine, habits, trackers, coach, notifications, location, screen time, audio, export/delete, legal links, offline/poor network, release build install.
Events: checklist should inspect key events.
Verification: dry-run checklist against emulator/device if available.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `docs/manual_qa_play_store.md`
- `docs/release_checklist.md`
- `docs/feature_matrix.md`

#### Firestore paths

All major user-owned paths documented.

#### R2 paths

- `users/{uid}/profile/*`
- `users/{uid}/uploads/*`

#### Cloudflare Worker endpoints

All active Worker endpoints.

#### Events

Key auth, onboarding, task, habit, notification, coach, fitness, export/delete events.

#### Dependencies

Feature tasks, automated tests, permissions audit.

#### How to verify

- Automated: none required beyond link/checklist consistency.
- Manual: run the script on at least one Android device before internal testing.

#### Estimate

1 day

#### Done Criteria

- [ ] Manual QA script exists.
- [ ] Real-device permission checks are included.
- [ ] Disabled-feature checks are included.
- [ ] Firestore/Worker/R2 inspection steps are included.

### Task 1.49 — Prepare Play Store listing assets and internal test metadata

#### Status

- [ ] Not started

#### Priority

P1 — Blocks many features

#### Depends on

1.38, 1.41, 1.44, 1.48
#### Blocks

1.50, 1.51

#### Why

Even a technically working APK/AAB cannot enter Play Store internal testing without listing metadata, screenshots, content rating, app access, and policy answers.

#### Current code evidence

- App name/package/signing are not final until Task 1.41.
- Legal/support pages are not ready until Task 1.38.
- Data Safety is not ready until Task 1.44.

#### Gap

Store listing copy, screenshots, app category, content rating, app access instructions, tester notes, privacy URL, support email/URL, and release notes are missing.

#### Spec source

Play Store readiness requirement.

#### Build order prerequisite

1.38, 1.41, 1.44, 1.48
#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Prepare Play Store listing assets and internal testing metadata.
Files to inspect first: docs/release_checklist.md, docs/play_store_data_safety.md, legal page docs, assets/images/, android resources, app screenshots if present.
Files allowed to modify: docs/store listing assets metadata; no feature code.
Firestore paths: None.
R2 paths: None.
Cloudflare Worker endpoints: None.
Feature flags: document which features are enabled for internal testing.
Requirements: short/full description, screenshots checklist, feature disclaimers, privacy/support/delete URLs, app access instructions, content rating inputs, internal release notes.
Events: None.
Verification: compare docs to Play Console required fields.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `docs/play_store_listing.md`
- `docs/release_checklist.md`
- screenshot asset folder if created

#### Firestore paths

None

#### R2 paths

None

#### Cloudflare Worker endpoints

None

#### Events

None

#### Dependencies

Final branding, legal pages, Data Safety, QA checklist.

#### How to verify

- Automated: none.
- Manual: Play Console metadata dry-run checklist.

#### Estimate

1 day

#### Done Criteria

- [ ] Listing copy exists.
- [ ] Screenshot plan/assets exist.
- [ ] Privacy/support/delete URLs are ready.
- [ ] Internal testing metadata is complete.

### Task 1.50 — Lock final V2 scope, deferrals, and removed MVP features

#### Status

- [ ] Not started

#### Priority

P1 — Blocks final release planning

#### Depends on

1.1, 1.49

#### Blocks

1.51

#### Why

The V2 roadmap must be self-contained before final QA. Every historical feature/gap needs an explicit V2 decision so agents never have to open superseded roadmap files to know whether a feature is in MVP, deferred, removed, or rewritten for Spark-only architecture.

#### Current code evidence

- This file is the active master roadmap and contains 51 one-phase tasks.
- `docs/OPTIVUS_STRICT_TASK_RULES.md` defines the allowed Spark-only architecture.
- The codebase contains partial implementations for auth/onboarding, routines, trackers, coach, notifications, goals, privacy/account lifecycle, Workers, R2 upload client, Mapbox-style Flutter map usage, tests, and Android release config.
- Superseded historical planning inputs have already been consumed into the coverage table below.

#### Gap

V2 needs a final self-contained scope table for covered, deferred, removed, and Spark-only rewritten items. Without it, future agents could accidentally reopen old roadmap files, reintroduce forbidden services, or implement a non-MVP feature as if it blocked Play Store internal testing.

#### Final historical coverage and scope decisions

Do not open superseded files for implementation. The needed decisions are copied here.

| Historical item or gap | Final V2 decision | V2 handling |
| --- | --- | --- |
| Auth lifecycle, root user schema, onboarding completion, About You onboarding, and page 10 plan-ready | Already covered in V2 | Tasks 1.15 and 1.32 |
| About You biometrics, lifestyle, sensitive context, eating-disorder safety input, and onboarding draft persistence | Already covered in V2 | Tasks 1.15, 1.21, 1.31, 1.32, and 1.44 |
| Event spine, event payload validator, Firestore schema/rules/indexes, model contract gaps | Already covered in V2 | Tasks 1.5, 1.6, and 1.7 |
| Missing event contracts including `bad_day_detected`, `slip_log_dismissed`, `screen_time_synced`, `weekly_insight_ready`, `account_deleted`, and `comeback_path_chosen` | Already covered in V2 | Tasks 1.5, 1.27, 1.35, 1.36, and 1.40 |
| Task service, routine materialization, selected day behavior, day lifecycle, fixed schedule source of truth | Already covered in V2 | Tasks 1.8, 1.9, 1.10, and 1.17 |
| Routine tab Add button and selected-day one-off tasks | Already covered in V2 | Task 1.9 |
| Routine tab AI button, suggestion round-trip, save-as-template behavior, and review-before-save | Already covered in V2 | Tasks 1.22, 1.33, 1.34, and 1.36 |
| Manual skin, supplement, class, and eating setup polish | Already covered in V2 | Tasks 1.18, 1.19, 1.20, and 1.21 |
| Routine import, routine AI text modes, and image import review-before-save | Already covered in V2 with Spark-only rewrite | Tasks 1.11, 1.12, 1.13, 1.22, and 1.23; old Storage wording becomes Cloudflare R2 signed upload metadata |
| Skin routine text AI/photo AI, supplement text AI, class timetable photo OCR, eating mess photo, and AI-generated eating plan | Already covered in V2 with Spark-only rewrite | Text modes use `ROUTINE_IMPORT_ENDPOINT` in Task 1.22; image modes use R2 signed upload plus `ROUTINE_IMPORT_ENDPOINT` in Task 1.23; manual fallback stays in Tasks 1.18-1.21 |
| Cloud Vision/OCR-style image extraction | Spark-only rewrite or defer | Use Gemini/OpenAI/other AI provider through Cloudflare Worker after R2 upload metadata; no Cloud Vision. If Worker is not verified, image modes stay disabled with Coming Soon copy under Task 1.23 |
| Habit lifecycle, tracker home, smoking, screen time, hydration, meditation, money saving, reading, procrastination, mindful eating, routine-completion, and fitness variants | Already covered in V2 | Tasks 1.24 through 1.31 |
| Junk food to mindful eating safety swap for users with sensitive eating context | Already covered in V2 | Tasks 1.21, 1.31, and 1.44 |
| Reading tracker Google Books lookup | Already covered in V2 | Task 1.30 and Task 1.44 require Google Books privacy audit and fallback |
| Hydration weather/IP lookup | Already covered in V2 | Task 1.30 and Task 1.44 require opt-in, disabled, or clearly disclosed behavior |
| Running/exercise maps and route review | Already covered in V2 with Spark-only rewrite | Task 1.14 and Task 1.29 use Mapbox/fallback, not Google Maps |
| Streak rules, per-habit accountability behavior, ghost absence, comeback, and tone lock | Already covered in V2 | Tasks 1.24, 1.34, and 1.35 |
| Forgiving weekly skip, strict/ruthless reset behavior, per-habit accountability override, and 8+ day ghost reset/pause decision | Already covered in V2 | Tasks 1.24, 1.34, 1.35, and 1.46 |
| Goal and identity profile schema/UI/score explanation | Already covered in V2 | Task 1.32 |
| Milestones, identity detail, why-this-score explanation, pause/archive identity | Already covered in V2 | Task 1.32 |
| Local notifications, notification center, notification settings, alarms, and snooze reasons | Already covered in V2 | Tasks 1.25 and 1.37 |
| Interactive coach, remaining AI callables, rule engine, speak budget, safety routing, watched conditions, derived context fields, and cooldown/budget behavior | Already covered in V2 with Spark-only rewrite | Tasks 1.3, 1.4, 1.11, 1.33, 1.34, and 1.36; old Firebase Function wording becomes Cloudflare Worker endpoints |
| Crisis handoff and emergency/safety response | Already covered for MVP safety routing; human ops alert deferred | Task 1.34 covers safety routing and safe response behavior; crisis alert Worker is deferred below unless staffed/required |
| Daily summary surface and weekly insights | Covered/defer split | MVP summary/insight lifecycle is Task 1.36; standalone Cloudflare Cron weekly summary Worker is deferred unless explicitly enabled and tested |
| Profile hub, legal/support/privacy, account deletion, data export/delete lifecycle | Already covered in V2 | Tasks 1.16, 1.38, 1.39, and 1.40 |
| Profile/accountability/coach settings rows and no-dead-tap requirement | Already covered in V2 | Task 1.16 requires each row to work, persist, link to Cloudflare Pages, or show clear MVP deferred copy |
| Remote Config kill switches, Crashlytics/Analytics/Performance/App Check, permissions/Data Safety, dependency/security audit, tests, manual QA, Play Store listing, and final gate | Already covered in V2 | Tasks 1.2, 1.3, and 1.41 through 1.51 |
| `journal_entries` day-close reflections | Deferred after Play Store internal testing | Keep out of MVP; no journal UI/model/path is required for internal testing |
| Separate `addiction_logs` collection | Removed from MVP as a separate collection | Smoking and addiction-like logs use the V2 habit log model in Task 1.26/1.31 for MVP |
| `coach_review` ambiguous-crisis human-review collection | Deferred after Play Store internal testing unless an ops workflow is staffed | Safety copy/routing remains covered by Task 1.34 |
| Server notification dispatcher for offline/cross-device delivery | Defer after Play Store internal testing | MVP relies on local notifications through Tasks 1.25 and 1.37 unless Cloudflare Cron dispatch is explicitly scoped |
| Cleanup/archive/backfill jobs and event maintenance | Defer after Play Store internal testing except release-critical cleanup | R2 cleanup and export/delete cleanup remain covered by Tasks 1.12, 1.13, and 1.40 |
| Cost monitor Worker | Defer after Play Store internal testing | If later needed, it must be a Cloudflare Cron Worker and must not introduce Google Cloud billing |
| Crisis alert Worker | Defer after Play Store internal testing unless required by safety policy | If later needed, it must be a Cloudflare Worker/Cron poller, not Firebase Functions |
| Subscription / AI usage caps UI | Defer or remove from MVP unless monetization/AI caps are enabled for internal testing | Profile dead taps are covered by Task 1.16; Worker-side rate/budget controls are covered by Tasks 1.3 and 1.34 |
| About You editor after onboarding | Defer after Play Store internal testing unless required to remove a profile dead tap | Task 1.16 must show working/deferred MVP copy if no editor ships |
| Coach/accountability settings and per-user `coachEnabled` switch | Defer full settings after Play Store internal testing unless required for internal testing | Basic coach state/fallback is covered by Tasks 1.16, 1.33, and 1.34; no dead taps allowed |
| Migration/seed checklist and generated dependency folder policy | Already covered in V2 | Tasks 1.2, 1.45, 1.48, and 1.51 |
| Firebase Storage, Cloud Functions/Firebase Functions, Google Maps, Firebase Hosting/App Hosting, Google Cloud billing, Cloud Vision, Cloud Run, Cloud Build, Secret Manager | Conflicts with Spark-only architecture | Forbidden; rewrite as Cloudflare R2, Cloudflare Workers/Cron, Mapbox, and Cloudflare Pages, or mark removed |

#### Spec source

Codebase audit; historical checklist already merged into this task; Play Store readiness; Spark-only architecture requirement.

#### Build order prerequisite

1.1, 1.49

#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit app feature code.

Task: Lock final V2 internal-testing scope using the self-contained coverage table in this task. Do not implement deferred or removed features.
Files to inspect first: todo_V2_Final_PlayStore_Single_Phase.md, docs/OPTIVUS_STRICT_TASK_RULES.md, docs/spark_cloudflare_architecture.md.
Files allowed to modify: todo_V2_Final_PlayStore_Single_Phase.md and release checklist docs only; no Flutter, Android, Worker, Firebase, or Cloudflare feature implementation.
Firestore paths: documentation only; deferred paths include /users/{uid}/journal_entries/{entryId}, /users/{uid}/coach_review/{reviewId}, /users/{uid}/usage/{monthKey}, and no separate /users/{uid}/addiction_logs path for MVP.
R2 paths: documentation only; all MVP image paths must use users/{uid}/uploads/* or users/{uid}/profile/* via Cloudflare R2 signed upload.
Cloudflare Worker endpoints: documentation only; deferred endpoints include notification dispatcher, weekly summary, cost monitor, and crisis alert Workers unless separately scoped.
Feature flags: final internal-testing matrix must identify disabled/deferred flags and visible fallback copy.
Requirements: preserve the final coverage table; make sure each deferred/removed item has user-visible behavior if it appears in UI; no dead taps; no implementation reference to superseded roadmaps; no Firebase Functions, Firebase Storage, Google Maps, Firebase Hosting/App Hosting, Cloud Vision, Cloud Run, Cloud Build, Secret Manager, or Google Cloud billing.
Events: documentation only; deferred event names must not be required by MVP flows unless another task implements and validates them.
Verification: confirm the scope table is self-contained and every deferred/removed/rewritten item is represented in final QA and Play Store copy where user-visible.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `todo_V2_Final_PlayStore_Single_Phase.md`
- `todo_V2_Final_PlayStore_Single_Phase.md`
- `docs/release_checklist.md` if created by Task 1.48 or Task 1.51

#### Firestore paths

Documentation only. Deferred or removed paths include `/users/{uid}/journal_entries/{entryId}`, `/users/{uid}/coach_review/{reviewId}`, `/users/{uid}/usage/{monthKey}`, and no MVP `/users/{uid}/addiction_logs/{logId}` collection.

#### R2 paths

Documentation only. MVP image paths remain `users/{uid}/uploads/*` and `users/{uid}/profile/*` through Cloudflare R2 signed upload.

#### Cloudflare Worker endpoints

Documentation only. Deferred Worker endpoints include notification dispatcher, weekly summary, cost monitor, and crisis alert unless a later post-internal-testing roadmap promotes them.

#### Events

Documentation only; no event is added or changed by this task.

#### Dependencies

Final internal-testing feature scope and Spark-only architecture rules.

#### How to verify

- Automated: none required.
- Manual: confirm the coverage table is self-contained and no future implementation prompt sends agents to superseded roadmap files.

#### Estimate

0.5 day

#### Done Criteria

- [ ] Covered items name current V2 task numbers.
- [ ] Deferred items have explicit post-internal-testing status and safe MVP behavior.
- [ ] Removed MVP items are explicitly marked removed and do not block Play Store internal testing.
- [ ] Spark-only rewrites are explicit: R2 for files/images, Workers/Cron for backend/AI, Cloudflare Pages for legal/support, Mapbox for maps.
- [ ] Superseded roadmap files are not required to implement V2.
- [ ] No feature implementation is done in this scope-lock task.

### Task 1.51 — Final release candidate gate and documentation cleanup

#### Status

- [ ] Not started

#### Priority

P0 — Blocks all work

#### Depends on

1.1, 1.2, 1.3, 1.33, 1.40, 1.41, 1.44, 1.46, 1.47, 1.48, 1.49, 1.50
#### Blocks

None

#### Why

The final gate prevents shipping with stale docs, forbidden services, skipped tests, debug signing, missing legal URLs, or unverified real-device behavior.

#### Current code evidence

- `todo_V2_Final_PlayStore_Single_Phase.md` is the master roadmap.
- Task 1.50 contains the final self-contained coverage and scope decision table.
- Superseded roadmap files are no longer implementation references.
- Build/test/release tasks above establish prerequisites.

#### Gap

No final go/no-go process exists that ties Spark-only guardrails, tests, release build, legal, Data Safety, Play Store metadata, real-device QA, and documentation cleanup together.

#### Spec source

Play Store readiness requirement; audit finding.

#### Build order prerequisite

All P0/P1/P2 MVP tasks complete or explicitly deferred with safe gates. Must include 1.2, 1.3, 1.33, 1.40, 1.41, 1.44, 1.48, 1.49, and 1.50.
#### What to tell Codex / Gemini / Antigravity

```text
Use `docs/OPTIVUS_STRICT_TASK_RULES.md` as the project rules.

Work in planning mode first. Do not edit code until you inspect the files and give a plan.

Task: Run the final release candidate gate for Play Store internal testing and clean stale docs.
Files to inspect first: todo_V2_Final_PlayStore_Single_Phase.md, docs/OPTIVUS_STRICT_TASK_RULES.md, docs/release_checklist.md, docs/manual_qa_play_store.md, docs/play_store_data_safety.md.
Files allowed to modify: docs/TODO/checklists only unless a blocker is explicitly approved as a separate implementation task.
Firestore paths: all release-critical paths in schema docs.
R2 paths: all enabled R2 paths.
Cloudflare Worker endpoints: all enabled Worker endpoints.
Feature flags: final internal testing flag matrix.
Requirements: Spark-only scan pass; flutter analyze/test pass; Worker tests pass; release AAB build pass; legal/Data Safety/listing complete; real-device QA pass; no Phase 2/Phase 3 roadmap remains in this file; do not send agents back to superseded roadmap files for implementation requirements.
Events: key event flows verified through QA.
Verification: execute final checklist and record PASS/FAIL.
Final response format: files inspected, files changed, summary, Firestore paths affected, Cloudflare Worker endpoints affected, R2 paths affected, events added/changed, feature flags added/changed, analyzer/test results, manual verification steps, remaining risks.
```

#### Files likely to modify

- `docs/release_checklist.md`
- `docs/manual_qa_play_store.md`
- `GEMINI.md`

#### Firestore paths

All release-critical user-owned paths.

#### R2 paths

All enabled R2 paths.

#### Cloudflare Worker endpoints

All enabled Worker endpoints.

#### Events

All key auth, onboarding, task, habit, notification, coach, fitness, export/delete events.

#### Dependencies

All MVP completion and Play Store setup tasks.

#### How to verify

- Automated: Spark-only scan, `flutter analyze`, `flutter test`, Worker tests, release AAB build.
- Manual: real-device QA script and Play Console metadata checklist.

#### Estimate

1 day

#### Done Criteria

- [ ] Spark-only scan passes.
- [ ] Flutter analyzer/tests pass or justified known failures are resolved.
- [ ] Worker tests pass.
- [ ] Release build passes.
- [ ] Legal/Data Safety/listing are complete.
- [ ] Real-device QA passes.
- [ ] Documentation no longer points agents to forbidden services.

# Final Self-Review Result

- V1 feature coverage: PASS
- Codebase gap coverage: PASS
- Task size check: PASS
- Dependency/order check: PASS
- Spark-only compliance: PASS
- Format check: PASS
- Play Store readiness coverage: PASS
- Remaining known risks:
  - This roadmap is complete as a planning artifact, but the app remains not Play Store-ready until the P0/P1/P2 tasks are implemented and verified.
  - R2 upload Worker does not currently exist and image upload/import must stay disabled until Tasks 1.12 and 1.13 pass.
  - Android package name and release signing are still placeholders until Task 1.41.
  - `functions/` contains inactive legacy Firebase Functions source and must remain clearly labeled or removed; it must not be deployed.
  - Deferred-after-internal-testing items are intentionally out of MVP: journal entries, separate addiction logs, coach review queue, server notification dispatcher, cleanup/backfill jobs, Cloudflare Cron weekly summary, cost monitor Worker, crisis alert Worker, full subscription/usage-cap UI, About You editor, full coach/accountability settings, and per-user coachEnabled settings.
  - Real-device verification is still required for notifications, exact alarms, screen time usage access, foreground location, audio playback, and release install.
