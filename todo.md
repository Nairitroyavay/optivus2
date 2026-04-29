# Optivus Production Roadmap (66/100 → 100/100)

## 1. Summary of Current System
Optivus currently has a clean Flutter architecture with Riverpod and GoRouter, plus basic Firebase Auth and UI screens. However, it lacks a deterministic initialization flow, causing critical race conditions where routing occurs before Firestore data is loaded (skipping onboarding). Core services (habits, tasks) are skeletal, and the foundational Event System and AI Master Engine described in the design documents are not yet implemented.

## 2. Key Problems Blocking 100/100
1. **Critical Race Condition:** Router evaluates state before Firebase/Firestore is ready.
2. **No Bootstrap Layer:** The app lacks a single source of truth for initialization.
3. **Missing Event Bus:** Services don't emit standardized events, breaking the decoupled architecture.
4. **Incomplete Service Contracts:** Task, Habit, and Streak services lack production CRUD and event emissions.
5. **No Context Aggregation:** The AI cannot see user state because `UserStateAggregator` doesn't exist.
6. **No AI Decision Loop:** The rule engine to convert events into proactive coach actions is missing.
7. **No Production Hardening:** Missing global error handling, offline persistence configuration, and schema validation.

## 3. Strategy to Reach 100/100
We will execute a strict, phased approach. We cannot build the AI Engine before the Event System, and we cannot build the Event System before the app routes deterministically. 
1. **Phases 1 & 2** stabilize the core app flow and error handling.
2. **Phase 3** implements the business logic (CRUD for habits/tasks).
3. **Phase 4** wires the nervous system (Event Orchestrator).
4. **Phases 5 & 6** build the brain (State Aggregator + AI Rule Engine).
5. **Phase 7** hardens for scale.

## 4. Full TODO Roadmap

---

### Phase 1 — Critical Fixes

### Task 1.1 — App Bootstrap Layer

**Why:**
The app currently races between Firebase Auth and GoRouter. We need a single source of truth for app initialization that guarantees Firestore data is loaded before routing decisions are made.

**What to tell Antigravity:**
CREATE an `AppBootstrapNotifier` (StateNotifier) that manages app initialization. It must listen to `FirebaseAuth.instance.authStateChanges()`. If user is null, emit `unauthenticated`. If user exists, await a fetch of `users/{uid}`. If `hasCompletedOnboarding` is false or the doc doesn't exist, emit `needsOnboarding`. If true, emit `ready`. DO NOT route directly from here. Expose this state via a Riverpod provider. Enable Firestore offline persistence in `main.dart`.

**Files to modify:**
- `lib/core/providers/bootstrap_provider.dart`
- `lib/main.dart`

**How to verify:**
- Run the app. Logs should show state transitioning: `initializing` -> `unauthenticated` / `needsOnboarding` / `ready`.

**Estimate:** 2 hours

- [x] Done

---

### Task 1.2 — Deterministic Router Rewrite

**Why:**
GoRouter currently relies on async Firestore calls or incomplete auth state, causing the critical onboarding skip bug.

**What to tell Antigravity:**
MODIFY `app_router.dart` to depend strictly on the `AppBootstrapNotifier` state. Remove all direct Firestore or Auth calls from the router's `redirect` logic. The `redirect` should be a pure switch statement: `initializing` -> `/loading`, `unauthenticated` -> `/login`, `needsOnboarding` -> `/onboarding`, `ready` -> `/home`. Ensure the router refreshes when the bootstrap state changes.

**Files to modify:**
- `lib/core/router/app_router.dart`

**How to verify:**
- Create a new account. The app MUST land on the first onboarding screen. Restart the app; it must stay on onboarding until completed.

**Estimate:** 2 hours

- [x] Done

---

### Task 1.3 — Auth & Firestore Sync Fix

**Why:**
During signup, the user document must be explicitly created with `hasCompletedOnboarding: false` to ensure schema consistency.

**What to tell Antigravity:**
MODIFY the `AuthService` signup method. After `createUserWithEmailAndPassword`, immediately perform a `set()` operation to `users/{uid}` with a default `UserModel` where `hasCompletedOnboarding` is explicitly `false` and `schemaVersion` is 1. Ensure `UserModel.fromFirestore` correctly parses this or defaults to `false`.

**Files to modify:**
- `lib/services/auth_service.dart`
- `lib/models/user_model.dart`

**How to verify:**
- Sign up with a new email. Check Firebase Console: the `users/{uid}` document must exist immediately with `hasCompletedOnboarding: false`.

**Estimate:** 1 hour

- [X] Done

---

### Phase 2 — Core Stability

### Task 2.1 — Global Error Handler

**Why:**
Failures currently crash the app silently. Production apps need a safety net to catch UI and async errors.

**What to tell Antigravity:**
CREATE a `GlobalErrorHandler` service. Hook into `FlutterError.onError` for Flutter framework errors and `PlatformDispatcher.instance.onError` for asynchronous Dart errors. For now, log them using `debugPrint` with a clear formatting (e.g., `🔴 [Error]`), and prepare the structure to pipe them to Firebase Crashlytics. Initialize this at the top of `main()` before `runApp`.

**Files to modify:**
- `lib/core/services/error_handler_service.dart`
- `lib/main.dart`

**How to verify:**
- Throw an intentional exception inside a button click. The app should not crash to desktop; the error should be printed via the custom logger.

**Estimate:** 1 hour

- [ ] Done

---

### Phase 3 — Core Features (V1)

### Task 3.1 — Habit Service CRUD

**Why:**
Habit tracking is foundational, but the service layer is incomplete. 

**What to tell Antigravity:**
MODIFY `HabitService` to implement full CRUD for habits. Use `WriteBatch` for logging. Create `createHabit` (writes to `users/{uid}/habits/{habitId}`). Create `logGood` and `logSlip` methods. These must write to the time-bucketed `users/{uid}/habits/{habitId}/logs/{YYYY-MM-DD}/items/{logId}` path. Do NOT emit events yet (that happens in Phase 4). Add a `schemaVersion: 1` to all writes.

**Files to modify:**
- `lib/services/habit_service.dart`
- `lib/models/habit_model.dart`

**How to verify:**
- Tap a habit in the UI. Verify the log document appears in the correct time-bucketed subcollection in the Firebase Console.

**Estimate:** 3 hours

- [ ] Done

---

### Task 3.2 — Task Service Transitions

**Why:**
Tasks have a specific state machine (scheduled -> started -> completed/abandoned) that must be enforced.

**What to tell Antigravity:**
MODIFY `TaskService` to handle state transitions. Implement `createTask`, `startTask`, `pauseTask`, `resumeTask`, `completeTask`, and `abandonTask`. Ensure `startTask` sets `actualStart`, and `completeTask` calculates `actualDurationMin`. Write to `users/{uid}/tasks/{taskId}`. Throw custom exceptions (e.g., `InvalidStateTransitionError`) if the state machine is violated.

**Files to modify:**
- `lib/services/task_service.dart`
- `lib/models/task_model.dart`

**How to verify:**
- Create a task, start it, then complete it. Check Firestore to ensure timestamps and duration are populated correctly.

**Estimate:** 3 hours

- [ ] Done

---

### Phase 4 — Event System (FOUNDATION)

### Task 4.1 — Event Model & Event Service

**Why:**
Cross-service communication must happen via idempotent events, not direct calls. This is the core architectural invariant.

**What to tell Antigravity:**
CREATE `EventModel` with fields: `eventId` (String), `eventName` (String), `ts` (DateTime), `deviceLocalTs` (DateTime), `source` (String), and `payload` (Map). CREATE `EventService`. Implement the `emit` method. It must generate a deterministic `eventId` (UUIDv7 or SHA256 of payload+time). It must write the event to BOTH `users/{uid}/events/{eventId}` and `users/{uid}/events_recent/{eventId}` using a `WriteBatch`. It must then broadcast the event to a local `StreamController.broadcast()`.

**Files to modify:**
- `lib/models/event_model.dart`
- `lib/services/event_service.dart`

**How to verify:**
- Call `EventService.emit` manually. Check Firestore that both `events` and `events_recent` collections receive the exact same document.

**Estimate:** 3 hours

- [ ] Done

---

### Task 4.2 — Hook Events into Services

**Why:**
Services must broadcast their actions so the rest of the system (streaks, AI) can react.

**What to tell Antigravity:**
MODIFY `HabitService`, `TaskService`, and `OnboardingScreen`. Inject `EventService`. At the end of `logGood`, emit `good_habit_logged`. In `logSlip`, emit `bad_habit_slip_logged`. In `completeTask`, emit `task_completed`. In `abandonTask`, emit `task_abandoned`. In onboarding completion, emit `onboarding_completed`. ALL emissions must happen in the same `WriteBatch` as the primary data mutation if possible, or immediately after.

**Files to modify:**
- `lib/services/habit_service.dart`
- `lib/services/task_service.dart`
- `lib/views/onboarding/onboarding_screen.dart`

**How to verify:**
- Complete a task in the UI. Check `events_recent` in Firestore to confirm `task_completed` appears with the correct payload.

**Estimate:** 2 hours

- [ ] Done

---

### Phase 5 — State Engine

### Task 5.1 — User State Aggregator

**Why:**
The AI Coach needs to know the user's current status (how many tasks done today, active streaks, slips) to provide context-aware advice.

**What to tell Antigravity:**
CREATE `ContextSnapshot` model containing `tasksCompletedToday`, `goodHabitsLoggedToday`, `badHabitSlipsToday`, `longestActiveStreak`, and `userState`. CREATE `StateAggregatorService`. Implement `buildSnapshot(String uid)`. It should query `events_recent` for today's date to count completions/slips, and query `streaks` to find the longest active streak. Return a compiled `ContextSnapshot`.

**Files to modify:**
- `lib/models/context_snapshot.dart`
- `lib/services/state_aggregator_service.dart`

**How to verify:**
- Trigger `buildSnapshot` and print the output. Perform an action in the app, trigger it again, and verify the counts increase.

**Estimate:** 3 hours

- [ ] Done

---

### Phase 6 — AI Engine (BASIC)

### Task 6.1 — AI Rule Engine Service

**Why:**
The system needs to decide *when* to proactively coach the user based on events and their current state.

**What to tell Antigravity:**
CREATE `RuleEngineService`. Define a hardcoded list of `Rule` objects based on the AI Master Engine doc (e.g., `rule_smoking_pattern_4_cigs`, `rule_missed_gym_one_off`). Implement `evaluate(ContextSnapshot snapshot, EventModel recentEvent)`. It should filter rules where `rule.event == recentEvent.eventName`, check all `conditions` against the snapshot, and return the eligible rule with the highest priority. Ignore cooldown logic for this V1 iteration.

**Files to modify:**
- `lib/models/coach_rule.dart`
- `lib/services/rule_engine_service.dart`

**How to verify:**
- Pass a mock `bad_habit_slip_logged` event (count = 4) and a mock snapshot to `evaluate`. Verify it returns the `rule_smoking_pattern_4_cigs` rule.

**Estimate:** 4 hours

- [ ] Done

---

### Task 6.2 — Proactive Coach Wiring

**Why:**
The Coach needs to automatically send a message when a rule fires, rather than just waiting for the user to chat.

**What to tell Antigravity:**
MODIFY `EventOrchestrator`. It should listen to `EventService.onAny()`. When an event arrives, call `StateAggregatorService.buildSnapshot`. Pass the snapshot and event to `RuleEngineService.evaluate`. If a rule is returned, pass the rule's `prompt_template` to `GeminiService.generateOnce()`. Save the resulting message to `users/{uid}/coach_messages/{messageId}` with `role: "coach"` so the UI automatically displays it.

**Files to modify:**
- `lib/core/event_orchestrator.dart`
- `lib/services/coach_service.dart`

**How to verify:**
- Log 4 bad habit slips. Switch to the Coach Tab. A new proactive message from the coach should appear automatically.

**Estimate:** 3 hours

- [ ] Done

---

### Phase 7 — Production Readiness

### Task 7.1 — Model Null-Safety & Schema Versioning

**Why:**
Firestore documents might be missing fields, especially during early development. The app must not crash on malformed data.

**What to tell Antigravity:**
MODIFY all models in `lib/models/`. Audit every `fromFirestore` or `fromJson` factory. Ensure strict null-safety with fallbacks (e.g., `json['name'] as String? ?? ''`). Ensure every `toMap` includes `schemaVersion: 1`.

**Files to modify:**
- `lib/models/user_model.dart`
- `lib/models/habit_model.dart`
- `lib/models/task_model.dart`
- `lib/models/event_model.dart`

**How to verify:**
- Manually edit a Firestore document and delete a non-critical field. Reload the app. It must not crash.

**Estimate:** 2 hours

- [ ] Done

---

### Task 7.2 — Event Replay on Startup

**Why:**
If the app crashes before the UI can react to a Firestore write, the state becomes inconsistent.

**What to tell Antigravity:**
MODIFY `EventService`. Add a `replayRecentEvents()` method. On app startup (when Bootstrap transitions to `ready`), fetch the last 50 events from `events_recent`. Check against a local cache (e.g., `SharedPreferences`) of processed `eventId`s. If an event hasn't been processed, fire it on the local stream so the `EventOrchestrator` can catch up.

**Files to modify:**
- `lib/services/event_service.dart`
- `lib/core/providers/bootstrap_provider.dart`

**How to verify:**
- Log an event, but immediately kill the app before the `EventOrchestrator` can process it (mock this). Restart the app. The orchestrator should process the missed event.

**Estimate:** 3 hours

- [ ] Done
