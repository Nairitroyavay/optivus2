# Optivus Production Implementation Plan

## 1. Summary
Optivus is an AI-powered life operating system designed for young professionals and students to align daily habits with long-term identity goals. The application combines a daily routine planner, habit tracker, long-term goals system, and an AI coach into a single cohesive experience. 

The architecture relies heavily on an **Event-Driven System**. Every state change in the app emits an event (e.g., `task_completed`, `habit_logged`) to the `EventService`. Other services (`StreakService`, `TaskService`) listen to these events rather than communicating directly. This decoupled approach ensures data integrity, makes the system testable, and provides a rich event log that the AI Coach reads to understand the user's actual behavior over time.

For V1, the focus is strictly on stabilizing the foundational layers, implementing the core habit and task flows, and bringing the basic AI coach to life. Advanced features like Postgres migration, realtime push outside Firestore, and complex AI topic modes are deferred.

---

## 2. Codebase Analysis: Existing vs Missing

**What exists (Already implemented):**
- **Project Structure**: Flutter project configured with Firebase (`flutterfire`), `lib/core`, `lib/models`, `lib/services`, `lib/views`, `lib/widgets`.
- **Core Models**: `UserModel`, `HabitModel`, `TaskModel`, `GoalModel`, `EventModel`, `StreakModel`, `HabitLogModel`, `DaySummaryModel`.
- **Infrastructure Phase 0 & 1**: `AppErrors`, `UuidGenerator`, `EventNames` constants.
- **EventService**: Foundational Pub/Sub event bus reading/writing to `/users/{uid}/events_recent`.
- **Auth & Firebase**: `AuthService`, `AuthRepository`, `FirestoreService`.
- **Habit Logging UI**: `Habit` model, `habitsProvider`, `LogHabitSheet` bottom sheet UI.
- **Routine UI**: Setup screens (Skin care, classes, eating) and persistence in `RoutineNotifier`.
- **Gemini AI**: `GeminiService` migrated to a secure Cloud Function backend (`aiGenerate`).
- **UI Components**: `WavyLoadingIndicator`, `LiquidGlass` components, tab bar.

**What is missing:**
- **Service Layer Contracts**: `TaskService`, `HabitService` (backend logic), `StreakService`, `NotificationService`, `CoachService`.
- **Task Lifecycle Engine**: Logic to move tasks from Scheduled -> Started -> Completed -> Abandoned, and sync this with the UI.
- **Event Orchestration**: Subscribing peer services to the `EventService` streams to handle cross-service updates (e.g., updating streaks when a task completes).
- **Tracker Tab Dashboard**: A unified UI to display good/bad habits, progress rings, and streaks.
- **AI Coach Integration**: Wiring up the `CoachTab` UI to pass the user's context (events, routines) to the `GeminiService` and storing chat history in Firestore.
- **Day Close Logic**: Background or startup logic to finalize the day, roll up streaks, and generate daily summaries.
- **Notifications**: Local notifications for alarms and nudges.

---

## 3. Phase-wise TODO List

### Phase 1 — Fix & stabilize existing codebase

⸻

Task 1.1 — Integrate Habit Logging with EventService

Why:
We previously built the `LogHabitSheet` UI, but it currently lacks the Event-Driven architectural requirement. Logging a habit must emit an event so derived systems (like Streaks) can react later.

What to tell Antigravity:
```text
Refactor `lib/views/habits/log_habit_sheet.dart` and any relevant providers to use `EventService`. 
When the user logs a habit, you must call `EventService.emit()` with the event name `EventNames.goodHabitLogged` (or `badHabitSlipLogged`). 
MODIFY `lib/views/habits/log_habit_sheet.dart` to inject `EventService` via Riverpod.
Do not write directly to Firestore for the log; the `EventService` will handle the event creation. 
Ensure the payload includes `habitId`, `amount`, and `timestamp`.
```

How to verify:
* Open the app, tap the FAB, and log a habit.
* Check Firebase Console: `/users/{uid}/events_recent/{eventId}` should have a new document with the correct payload.
* Check VS Code debug logs for successful event emission.

Estimate: 1h

* [x] Done

⸻

Task 1.2 — Integrate Routine Setup with EventService

Why:
The routine setup screens (Skin care, Eating, Classes) save data but do not emit `task_scheduled` events as required by the System Contracts.

What to tell Antigravity:
```text
Refactor `lib/providers/routine_provider.dart` to inject `EventService`.
When saving a routine (e.g., `setSkinCarePlan`, `setClasses`), iterate over the created/updated blocks and emit a `EventNames.taskScheduled` event for each block.
MODIFY `lib/providers/routine_provider.dart`. 
Ensure the payload contains the `taskId`, `type`, `plannedStart`, and `plannedEnd`.
```

How to verify:
* Go to Profile -> Routine Setup -> Skin Care. Save a new skin care routine.
* Check Firebase Console: `/users/{uid}/events_recent/` should contain new `task_scheduled` events.

Estimate: 1h

* [ ] Done

⸻

### Phase 2 — Core features (habits, tasks)

⸻

Task 2.1 — Build TaskService

Why:
Tasks are the core operational units. We need a service to handle the state transitions (Scheduled -> Started -> Paused -> Completed) and write to the correct Firestore paths while emitting events.

What to tell Antigravity:
```text
Create `lib/services/task_service.dart`.
CREATE a `TaskService` class that implements `createTask`, `startTask`, `completeTask`, and `abandonTask`.
Use the `TaskModel` from `lib/models/task_model.dart`.
Write task documents to Firestore path: `/users/{uid}/tasks/{taskId}`.
In each state transition method, you MUST emit the corresponding event (e.g., `EventNames.taskStarted`, `EventNames.taskCompleted`) using `EventService`.
Integrate this service into `lib/core/providers.dart` as a Riverpod provider.
```

How to verify:
* Write a temporary test button on the Home screen to trigger `startTask`.
* Verify in Firebase Console that `/users/{uid}/tasks/{taskId}` updates its state field to `started`.
* Verify `/users/{uid}/events_recent/` contains a `task_started` event.

Estimate: 2h

* [x] Done

⸻

Task 2.2 — Implement Routine Timeline UI & Task Execution

Why:
Users need to see their day's tasks on a timeline and interact with them (start, complete).

What to tell Antigravity:
```text
MODIFY `lib/views/routine/routine_tab.dart` and `lib/views/routine/timeline_section.dart`.
Fetch today's tasks using `TaskService.tasksFor(DateTime.now())` (which should return a Stream).
Render the tasks on a vertical timeline based on their `plannedStart` and `plannedEnd`.
Add "Start" and "Complete" buttons to the UI blocks. When tapped, these buttons should call `startTask` and `completeTask` on the `TaskService`.
Handle the UI state change (e.g., show an active timer chip when state is `started`).
```

How to verify:
* Open Routine Tab. You should see tasks fetched from Firestore.
* Tap "Start" on a task block. The UI should instantly change to an active state.
* Tap "Complete". The task should mark as completed.

Estimate: 3h

* [x] Done

⸻

Task 2.3 — Build HabitService

Why:
We need a dedicated backend service to manage the CRUD operations of Habits and their historical logs, separating this logic from the UI.

What to tell Antigravity:
```text
Create `lib/services/habit_service.dart`.
CREATE `HabitService` with methods `createHabit`, `logGood`, and `logSlip`.
Write habit documents to `/users/{uid}/habits/{habitId}`.
Write logs to `/users/{uid}/habits/{habitId}/logs/{YYYY-MM-DD}/items/{logId}`.
Ensure `logGood` and `logSlip` emit `EventNames.goodHabitLogged` and `EventNames.badHabitSlipLogged` respectively.
Provide this service via Riverpod in `lib/core/providers.dart`.
```

How to verify:
* Use the app to create a new habit. Verify it appears in `/users/{uid}/habits/`.
* Log a slip. Verify the log is created in the subcollection.

Estimate: 2h

* [x] Done

⸻

Task 2.4 — Implement Tracker Tab UI Dashboard

Why:
The Tracker tab is where the user sees their habit progress, mission rings, and bad habit reductions.

What to tell Antigravity:
```text
MODIFY `lib/views/tabs/tracker_tab.dart`.
Build a dashboard UI that fetches habits via `HabitService.habits()`.
Display Good Habits as cards with progress bars (fetching daily totals from the logs subcollection).
Display Bad Habits in a separate carousel highlighting slip counts.
Use the LiquidGlass design system (vibrant colors, glassmorphism).
Add a "Log Slip" button for bad habits that calls `HabitService.logSlip`.
```

How to verify:
* Navigate to Tracker Tab.
* Ensure both Good and Bad habits are rendered correctly.
* Tap "Log Slip" and verify the UI updates and Firebase receives the write.

Estimate: 3h

* [x] Done

⸻

### Phase 3 — Event system

⸻

Task 3.1 — Create EventOrchestrator for Background Listening

Why:
We need a central place to listen to `EventService.onAny()` and trigger side-effects in other services without creating circular dependencies.

What to tell Antigravity:
```text
CREATE `lib/core/event_orchestrator.dart`.
Create an `EventOrchestrator` class that takes instances of `EventService`, `StreakService`, and `NotificationService`.
In its `init()` method, subscribe to `EventService.onAny()`.
Write a switch statement based on the `eventName`. 
For example, when `task_completed` is received, we will eventually call `StreakService`. (Leave comments for these calls for now).
Provide and initialize this class globally in `lib/main.dart` or via a Riverpod `Provider` initialized on startup.
```

How to verify:
* Add a print statement in the listener.
* Perform any action (log habit, complete task).
* Check the debug console to see the `EventOrchestrator` catching the event.

Estimate: 1h

* [ ] Done

⸻

### Phase 4 — Derived systems (streaks, summaries)

⸻

Task 4.1 — Build StreakService

Why:
Streaks are a core gamification loop. They need to calculate continuously based on completed tasks and habit logs.

What to tell Antigravity:
```text
CREATE `lib/services/streak_service.dart`.
Implement `runDayCloseRollup(String date)` which iterates over active habits, calculates if the goal was met based on logs, and updates `/users/{uid}/streaks/{habitId}`.
Fields should include `currentCount`, `longestCount`, and `state`.
MODIFY `lib/core/event_orchestrator.dart` to call `StreakService` methods if needed, or primarily rely on the Day Close trigger.
Provide via Riverpod.
```

How to verify:
* Manually trigger `runDayCloseRollup` via a temporary button.
* Check Firebase Console: `/users/{uid}/streaks/` should be created or updated with accurate counts.

Estimate: 3h

* [x] Done

⸻

Task 4.2 — Implement Day Close Rollup in RoutineService

Why:
The system needs to close the day out at midnight (or next app boot) to finalize streaks and generate a summary.

What to tell Antigravity:
```text
MODIFY `lib/services/routine_service.dart` (create it if it doesn't exist, moving logic from RoutineProvider).
Add `runDayCloseIfNeeded()`. 
Fetch the user's `lastDayClosed` from their profile. If it's less than yesterday, generate a `DaySummaryModel` and write to `/users/{uid}/dailySummaries/{date}`.
Inside this method, await `StreakService.runDayCloseRollup(date)`.
Emit `EventNames.dayClosed`.
Update `lastDayClosed` on the `UserModel`.
Call `runDayCloseIfNeeded()` during app startup in `lib/main.dart`.
```

How to verify:
* Set `lastDayClosed` to two days ago in Firebase.
* Restart the app.
* Verify the daily summary doc is created and streaks are calculated for the missing days.

Estimate: 2h

* [x] Done

⸻

### Phase 5 — Notifications

⸻

Task 5.1 — Build NotificationService

Why:
Users need reminders to execute their planned tasks.

What to tell Antigravity:
```text
CREATE `lib/services/notification_service.dart`.
Use the `flutter_local_notifications` package.
Implement `scheduleTaskAlarm(TaskModel task)`. It should schedule a notification 5 minutes before `plannedStart`.
MODIFY `lib/core/event_orchestrator.dart` to listen for `EventNames.taskScheduled` and call `NotificationService.scheduleTaskAlarm()`.
Request notification permissions on app startup.
```

How to verify:
* Create a task starting 10 minutes from now.
* Close the app.
* Wait 5 minutes. You should receive a push notification reminding you to start the task.

Estimate: 2h

* [ ] Done

⸻

### Phase 6 — AI Coach

⸻

Task 6.1 — Wire Coach Tab Chat UI

Why:
The core differentiator of Optivus is the AI Coach. We need the chat interface connected to the backend.

What to tell Antigravity:
```text
MODIFY `lib/views/tabs/coach_tab.dart`.
Implement a chat interface with iOS-style speech bubbles.
Use `GeminiService` (which uses Cloud Functions) to send user messages and retrieve responses.
Save chat history to Firestore: `/users/{uid}/coach_chats/{thread_id}/turns`.
Add a typing indicator and a text input field at the bottom.
```

How to verify:
* Open Coach Tab.
* Type "Hello".
* Wait for the AI bubble to stream in/appear.
* Check Firebase to ensure the chat history is saved.

Estimate: 3h

* [x] Done

⸻

Task 6.2 — Implement Coach Context Builder

Why:
The AI is useless if it doesn't know the user's data. We must pass the context (habits, tasks) in the system prompt.

What to tell Antigravity:
```text
CREATE `lib/services/coach_service.dart`.
Implement a method `generateSystemPrompt()` that fetches today's tasks from `TaskService`, active streaks from `StreakService`, and the user's identity goals from `UserModel`.
Inject this system prompt as context when calling `GeminiService`.
MODIFY `lib/views/tabs/coach_tab.dart` to use `CoachService` instead of directly calling `GeminiService`.
```

How to verify:
* Open Coach Tab.
* Ask the coach: "What tasks do I have scheduled for today?".
* The coach should accurately list your tasks because they were provided in the system prompt.

Estimate: 2h

* [x] Done

⸻

### Phase 7 — Advanced features (Deferred for V2)

⸻

Task 7.1 — Topic Modes & Advanced AI Rules (Deferred)
Task 7.2 — Phone Screen Time Integration (Deferred)
Task 7.3 — Postgres Migration Contingency (Deferred)

