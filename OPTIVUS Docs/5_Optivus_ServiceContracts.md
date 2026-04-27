# Optivus — Service Contracts

**Document version:** 1.0
**Last updated:** April 2026
**Companion to:** *Optivus PRD*, *UserFlow*, *EventSystem*, *SystemDesign*
**Audience:** the engineer writing the code (you, in 2 weeks)
**Read this with:** your IDE open

---

## How to use this document

This doc is a **contract**. Every method signature, every event payload, every error code is the agreement between a service and the rest of the system. If you change a contract, you must update this doc *first*, then the code. If something in this doc is wrong, fix it before you write code that depends on it.

It is intentionally repetitive across services — that's the point. You should be able to look up any service in isolation without reading the whole doc.

### Conventions used throughout

- **`string`** — non-empty unless marked `?`
- **`string?`** — optional, may be null
- **`timestamp`** — Firestore server timestamp (`FieldValue.serverTimestamp()` on write, `Timestamp` on read)
- **`int`** — Dart `int`, 64-bit
- **`num`** — Dart `num` (`int` or `double`)
- **`Map<K,V>`** — Dart map; in Firestore stored as nested object
- **`List<T>`** — Dart list; in Firestore stored as array
- **`enum<X|Y|Z>`** — string, must be one of the listed values
- **`UID`** — Firebase Auth user ID, equivalent to `string`
- **`DateString`** — `"YYYY-MM-DD"` format, user-local-timezone

### The 6 services

1. EventService
2. TaskService
3. HabitService
4. StreakService
5. RoutineService
6. NotificationService

Plus 1 special:
- AuthService (thin wrapper around Firebase Auth — covered briefly at the end)

### Service Architecture Rules (mandatory)

Four rules govern how services interact. They are not suggestions. They are enforced by code review, and several are also enforced by Firestore security rules (§9). If a method violates any of them, that method is broken — fix it before merging.

These rules are reinforced in detail across §8 (event payloads), §9 (Firestore access), and §11 (error handling). This section is the single place they are stated together.

**Rule 1 — No service calls another service.**
A method on `TaskService` never imports or calls a method on `HabitService`, `StreakService`, etc. Services are isolated. The dependency graph is a star: every service depends only on `EventService` (and Firestore, and FirebaseAuth). It never depends on a peer service.

> Detailed enforcement: §9 "Service-layer enforcement rule" + Firestore access matrix.

**Rule 2 — All cross-service communication goes through EventService.**
When `TaskService.completeTask` finishes, it does not call `StreakService.extendStreak`. It emits `task_completed`. `StreakService` subscribes to `task_completed` and reacts. This is how the streak gets extended. The emitter does not know who is listening; the listener does not know who emitted.

This is what makes the system testable, replaceable, and replayable. If a service ever needs to "update something belonging to another service," it instead emits an event and lets that other service react.

> Detailed enforcement: §1.2 (`EventService.emit`) + §8 (event payload contracts).

**Rule 3 — Every state-mutating method emits at least one event.**
A method that writes to Firestore without emitting an event is forbidden. There are exactly two exceptions:
- Pure-read methods (queries, streams) — they emit nothing because they mutate nothing
- Internal write retries by the Firestore SDK itself — these are not "method calls" in the contract sense

Every method definition in this document declares its emissions in one of two places:
- A bolded **Emits** subsection (the preferred form), OR
- An explicit "Emit X" step inside the **Behavior** list

If neither is present on a state-mutating method, that's a documentation bug — fix this doc before writing the code. A method that mutates Firestore but appears to emit nothing means the event log is silently incomplete, which breaks every downstream listener.

> Detailed enforcement: every method spec in §1.2, §2.2, §3.2, §4.2, §5.2, §6.2.

**Rule 4 — No silent state changes.**
Every change to user-visible data (a habit log appears, a task completes, a streak resets, a routine completes) must produce a corresponding event in the log. The user's data must be reconstructible from the event stream alone.

There is one allowed exception: **intentional silent degradation when a permission or capability is missing.** Example: `NotificationService.scheduleForTask` silently no-ops if the user denied notification permission — that's a graceful failure of a capability, not a hidden state change. These exceptions are explicitly documented per method (search "silently" in this doc — there are 4 such cases).

What is forbidden:
- Mutating Firestore data without an event (would corrupt analytics, AI memory, replay)
- Updating a counter or aggregate without emitting a delta event
- Cleanup operations that delete data without an event recording the deletion
- Any code path where the user's data state changes but `events_recent` shows no record of why

> Detailed enforcement: §11.4 "What never throws" + §8 strict payload contracts.

### Why these four rules

Two reasons. First, they keep the architecture honest: as long as services only communicate via events, a service can be deleted, replaced, or rewritten without touching others. Second, they make the AI possible: the AI Coach reads the event stream to understand the user. If services bypass events to talk to each other directly, the AI sees an incomplete picture of the user's life — and the central promise of Optivus breaks.

These rules are why this document is called "Contracts" and not "Code Style Guide." They are the agreement that lets the system stay coherent across many services, many engineers, and many years.

---

## 1. EventService

The pub-sub bus. Every other service depends on this. It owns: writing events to Firestore atomically, broadcasting to local subscribers, and replay on app start.

### 1.1 Class shape

```
class EventService {
  EventService(this._firestore, this._auth, this._processedEventsCache);
  
  Future<void> emit({
    required String eventName,
    required Map<String, dynamic> payload,
    int payloadVersion = 1,
    EventSource source = EventSource.ui,
    WriteBatch? batch,
  });
  
  Stream<Event> on(String eventName);
  Stream<Event> onAny();
  Future<void> replayRecentEvents();
  
  void dispose();
}
```

### 1.2 Methods

#### `emit({eventName, payload, payloadVersion, source, batch})`

Writes an event to Firestore and broadcasts on the local stream.

**Input**
| Field | Type | Required | Notes |
|---|---|---|---|
| `eventName` | `string` | yes | Must be a registered name (see Section 8) |
| `payload` | `Map<String, dynamic>` | yes | Must match the registered schema for `eventName` |
| `payloadVersion` | `int` | no, default 1 | Bump when payload schema changes |
| `source` | `enum<ui|system|ai>` | no, default `ui` | Who originated the event |
| `batch` | `WriteBatch?` | no | If provided, the event write is added to this batch (caller commits). If null, EventService creates and commits its own batch. |

**Behavior**
1. Compute `eventId = sha256(uid + eventName + ts.toSeconds() + canonicalize(payload))`
2. Build event doc with envelope (see §1.4)
3. If `batch` provided: add `set` operation to it; **caller is responsible for commit**
4. If `batch` not provided: write atomically using `set(..., merge: false)` on `events_recent/{eventId}`
5. Once Firestore write resolves (or is queued offline), fire on local stream

**Output**
- `Future<void>` — completes when the write is queued (offline) or committed (online)

**Emits**
- The event itself (e.g., `task_completed`)

**Errors**
- `EventValidationError` — payload doesn't match registered schema
- `EventDuplicateError` — same `eventId` already exists; safe to ignore (idempotent)
- `NotAuthenticatedError` — no current Firebase user

**Notes**
- `eventId` is deterministic — re-emitting the exact same event in the same second is a no-op
- The local stream fires *only after* the Firestore write is at least queued; never before

#### `on(String eventName) → Stream<Event>`

Subscribe to a single event type.

**Input**
- `eventName` — must be a registered name

**Output**
- `Stream<Event>` — broadcasts every matching event for the lifetime of the service

**Errors**
- None at subscription time; errors during emission propagate via the stream

#### `onAny() → Stream<Event>`

Subscribe to all events. Used by SyncService and analytics.

#### `replayRecentEvents()`

Called once during app startup, after auth is restored.

**Behavior**
1. Read `users/{uid}/events_recent` ordered by `ts ASC`, limit 50
2. For each event, check `_processedEventsCache` (a local SharedPreferences-backed set of seen `eventId`s)
3. If not seen → fire on local stream, add to cache
4. If seen → skip

**Output**
- `Future<void>`

**Notes**
- Only fires events that are in `events_recent` but NOT in the local processed cache
- This is what reconciles state if the app crashed between Firestore write and listener execution

### 1.3 The `Event` model

```
class Event {
  final String eventId;
  final String eventName;
  final DateTime ts;                      // server time, as DateTime
  final DateTime? deviceLocalTs;          // for clock-drift detection
  final EventSource source;
  final String deviceId;
  final int payloadVersion;
  final Map<String, dynamic> payload;
  final int schemaVersion;
}

enum EventSource { ui, system, ai }
```

### 1.4 Firestore document shape

```
users/{uid}/events_recent/{eventId}:
{
  schemaVersion:   int        (always 1 for v1)
  eventId:         string     (same as doc ID)
  eventName:       string     ("task_completed", "good_habit_logged", ...)
  ts:              timestamp  (server timestamp)
  deviceLocalTs:   timestamp  (client clock at emit)
  source:          string     ("ui" | "system" | "ai")
  deviceId:        string     (uuid generated on first launch)
  payloadVersion:  int
  payload:         object     (event-specific, see §8)
}
```

### 1.5 Errors

| Error class | When | Recovery |
|---|---|---|
| `EventValidationError` | `payload` doesn't match `eventName` schema | Fix the caller; do not retry |
| `EventDuplicateError` | `eventId` already exists | Ignore — write was already idempotent |
| `NotAuthenticatedError` | No `auth.currentUser` | Redirect to login |
| `FirestoreUnavailable` | Network down AND offline cache disabled | SDK queues and retries; nothing for caller to do |

---

## 2. TaskService

Owns the task state machine: Scheduled → Started → Completed/Abandoned/Paused.

### 2.1 Class shape

```
class TaskService {
  TaskService(this._firestore, this._auth, this._eventService);
  
  Future<String> createTask(TaskInput input);
  Future<void> startTask(String taskId);
  Future<void> pauseTask(String taskId);
  Future<void> resumeTask(String taskId);
  Future<void> completeTask(String taskId);
  Future<void> abandonTask(String taskId, {String? reasonTag, AbandonReason reason = AbandonReason.userSkipped});
  Future<void> checkSubtask(String taskId, String subtaskId, {bool checked = true});
  Future<void> deleteTask(String taskId);
  
  Stream<List<Task>> tasksFor(DateTime date);
  Stream<Task?> watchTask(String taskId);
  Stream<Task?> activeTask();             // currently in `started` state
}
```

### 2.2 Methods

#### `createTask(TaskInput input) → Future<String>`

**Input** (`TaskInput`)
| Field | Type | Required | Notes |
|---|---|---|---|
| `type` | `enum<skin_care|eating|class|fixed|custom|habit_block>` | yes | |
| `parentRoutine` | `string?` | no | Type-equivalent value if part of a routine |
| `title` | `string` | yes | 1–80 chars |
| `emoji` | `string?` | no | Single emoji glyph |
| `color` | `string?` | no | Hex like `"#A8E6CF"` |
| `identityTags` | `List<string>` | no, default `[]` | Identity IDs |
| `alarmTier` | `enum<gentle|active|custom>` | no, default `gentle` | |
| `plannedStart` | `timestamp` | yes | Must be `>= now - 1h` |
| `plannedEnd` | `timestamp` | yes | Must be `> plannedStart`; max 8h duration |
| `subtasks` | `List<SubtaskInput>` | no, default `[]` | Each: `{title, checked: false}` |

**Output**
- `Future<String>` — the new `taskId`

**Behavior**
1. Generate `taskId = "{type}_{YYYYMMDD}_{slot}_{shortuuid}"`
2. Build task document with `state: "scheduled"`, all timestamps, schemaVersion: 1
3. WriteBatch:
   - Create `users/{uid}/tasks/{taskId}`
   - Emit event `task_scheduled` (added to same batch)
4. Commit

**Emits**
- `task_scheduled`

**Errors**
- `InvalidTimeRangeError` — plannedEnd <= plannedStart
- `TaskTooLongError` — duration > 8h
- `TaskInPastError` — plannedStart more than 1h ago

#### `startTask(String taskId)`

**Input**
- `taskId` — must exist and be in `scheduled` state

**Behavior**
1. Read task. Validate state == `scheduled`.
2. Validate no other task is currently `started` (or `paused`). If conflict → throw `MultipleActiveTasksError`.
3. Compute `actualStart = now`, `driftMin = (now - plannedStart).inMinutes`
4. WriteBatch:
   - Update task: `state = "started"`, `actualStart`, `updatedAt`
   - Emit `task_started` with payload (see §8)
5. Commit

**Emits**
- `task_started`

**Errors**
- `TaskNotFoundError`
- `InvalidStateTransitionError` — task not in `scheduled` (e.g., already started, completed, abandoned)
- `MultipleActiveTasksError` — another task is currently in started/paused state

**UI fast-path**
The local event bus fires `task_started` immediately on commit. UI subscribers (active task pinner, mission ring) react in the same frame.

#### `pauseTask(String taskId)`

**Behavior**
1. Validate state == `started`
2. Compute `elapsedSoFarMin = now - actualStart`
3. Update task: `state = "paused"`, `pausedAt = now`
4. Emit `task_paused`
5. Schedule a 20-min timer: if state still `paused` after 20min, call `abandonTask(taskId, reason: autoIdle)`

**Emits**
- `task_paused`

**Errors**
- `InvalidStateTransitionError` — task not in `started`

#### `resumeTask(String taskId)`

**Behavior**
1. Validate state == `paused`
2. Cancel the 20-min auto-abandon timer
3. Compute `pauseDuration = now - pausedAt`
4. Update: `state = "started"`, `pausedAt = null`, accumulate `totalPauseDurationMin`
5. Emit `task_resumed`

**Errors**
- `InvalidStateTransitionError`

#### `completeTask(String taskId)`

**Behavior**
1. Validate state in {`scheduled`, `started`, `paused`}
2. If state == `scheduled` (user marks complete without starting):
   - Confirm via UI dialog before reaching here (UI's responsibility)
   - Synthesize: `actualStart = actualEnd = now`, `actualDurationMin = 0`
   - Emit BOTH `task_started` (synthetic) AND `task_completed`, with `source: ui_quick_complete`
3. Otherwise:
   - `actualEnd = now`
   - `actualDurationMin = (actualEnd - actualStart).inMinutes - totalPauseDurationMin`
   - `driftPct = (actualDurationMin - plannedDurationMin) / plannedDurationMin`
4. Compute `subtasksCompleted = subtasks.where(checked).length`
5. WriteBatch:
   - Update task: `state = "completed"`, all duration fields, `updatedAt`
   - Append to `users/{uid}/taskOutcomes/{taskId}`
   - Emit `task_completed`
6. Commit

**Emits**
- `task_completed` (and possibly synthetic `task_started`)

**Errors**
- `TaskNotFoundError`
- `InvalidStateTransitionError`

#### `abandonTask(String taskId, {reasonTag, reason})`

**Input**
- `taskId`
- `reasonTag` — optional user-picked chip ("tired", "not feeling it", etc.)
- `reason` — `enum<userSkipped|autoIdle|autoNoStart>`

**Behavior**
1. Validate state in {`scheduled`, `started`, `paused`}
2. Update task: `state = "abandoned"`, `abandonedAt = now`, `reasonTag`, `reasonCategory: reason`
3. Emit `task_abandoned`

**Emits**
- `task_abandoned`

**Errors**
- `TaskNotFoundError`
- `InvalidStateTransitionError`

#### `checkSubtask(String taskId, String subtaskId, {checked: true})`

**Behavior**
1. Read task. Find subtask with id `subtaskId`. Validate exists.
2. Update `subtasks[i].checked = checked`
3. Emit `subtask_checked` with `{taskId, subtaskId, checked, ts}`
4. **Auto-complete trigger**: if all subtasks now checked AND `state == "started"` → call `completeTask(taskId)` (additional event will fire)

**Emits**
- `subtask_checked`
- (optional) `task_completed`

**Errors**
- `TaskNotFoundError`
- `SubtaskNotFoundError`

#### `deleteTask(String taskId)`

**Behavior**
1. Hard-delete the task document
2. Emit `task_deleted` (lightweight, no payload beyond taskId)

**Notes**
- Use only for accidental creates or for v1 testing. In production paths, prefer `abandonTask` so the audit trail is preserved.

### 2.3 Streams

| Stream | Returns | Notes |
|---|---|---|
| `tasksFor(DateTime date)` | `Stream<List<Task>>` | Tasks where `plannedStart` is in `[date 00:00, date+1 00:00)` user-local |
| `watchTask(String taskId)` | `Stream<Task?>` | Single task; null if deleted |
| `activeTask()` | `Stream<Task?>` | The single task currently in `started` state, or null |

All streams use Firestore `.snapshots()` and are auto-cleaned up by Riverpod.

### 2.4 Firestore document shape

```
users/{uid}/tasks/{taskId}:
{
  schemaVersion:        int       (1)
  taskId:               string    (same as doc ID)
  type:                 string    ("skin_care" | "eating" | "class" | "fixed" | "custom" | "habit_block")
  parentRoutine:        string?
  title:                string
  emoji:                string?
  color:                string?
  identityTags:         array<string>
  alarmTier:            string    ("gentle" | "active" | "custom")
  plannedStart:         timestamp
  plannedEnd:           timestamp
  state:                string    ("scheduled" | "started" | "paused" | "completed" | "abandoned")
  actualStart:          timestamp?
  actualEnd:            timestamp?
  pausedAt:             timestamp?
  abandonedAt:          timestamp?
  actualDurationMin:    int?
  totalPauseDurationMin: int?
  driftPct:             number?
  subtasks:             array<{
                          id: string,
                          title: string,
                          checked: bool
                        }>
  reasonTag:            string?
  reasonCategory:       string?   ("user_skipped" | "auto_idle" | "auto_no_start")
  createdAt:            timestamp
  updatedAt:            timestamp
}
```

### 2.5 Errors

| Error | When | Recovery |
|---|---|---|
| `TaskNotFoundError` | taskId doesn't exist | Refresh task list; UI shouldn't have shown the action |
| `InvalidStateTransitionError` | Wrong state for the operation | Re-read task state; UI may be stale |
| `MultipleActiveTasksError` | Tried to start a second task while one is active | Show toast; deep-link to active task |
| `InvalidTimeRangeError` | plannedEnd <= plannedStart | Validation; reject in UI |
| `TaskTooLongError` | Duration > 8h | Validation; reject in UI |
| `TaskInPastError` | plannedStart > 1h in the past | Validation; reject in UI |
| `SubtaskNotFoundError` | subtaskId doesn't exist on task | Refresh task |

---

## 3. HabitService

Owns habits and their logs. Handles both good and bad habits.

### 3.1 Class shape

```
class HabitService {
  HabitService(this._firestore, this._auth, this._eventService);
  
  Future<String> createHabit(HabitInput input);
  Future<void> updateHabit(String habitId, HabitUpdate update);
  Future<void> pauseHabit(String habitId);
  Future<void> resumeHabit(String habitId);
  Future<void> archiveHabit(String habitId);
  
  Future<String> logGood(String habitId, GoodLogInput input);
  Future<String> logSlip(String habitId, SlipLogInput input);
  Future<void> deleteLog(String habitId, String logId, DateString logDate);
  
  Stream<List<Habit>> habits({HabitState? filter});
  Stream<Habit?> watchHabit(String habitId);
  Stream<num> todayTotal(String habitId);
  Stream<List<HabitLog>> todayLogs(String habitId);
}
```

### 3.2 Methods

#### `createHabit(HabitInput input) → Future<String>`

**Input** (`HabitInput`)
| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | `string` | yes | 1–40 chars |
| `kind` | `enum<good|bad>` | yes | |
| `unit` | `string` | yes | "ml", "min", "pages", "count", etc. |
| `dailyGoal` | `num?` | yes if `kind == good` | |
| `goalType` | `enum<eliminate|reduce_to_target|awareness_only>` | yes if `kind == bad` | Default `awareness_only` for first 7 days |
| `target` | `num?` | yes if `goalType == reduce_to_target` | |
| `baselinePerDay` | `num?` | no | For bad habits, used in money-saved math |
| `costPerUnit` | `num?` | no | For bad habits, defaults by region |
| `currency` | `string?` | no, default user's locale | |
| `identityTags` | `List<string>` | no, default `[]` | |
| `emoji` | `string?` | no | |
| `color` | `string?` | no | |
| `trackerType` | `enum<water|meditation|reading|exercise|smoking|screen_time|junk_food|procrastination|money_saving|generic>` | yes | Drives type-specific UI/logic |

**Output**
- `Future<String>` — the new `habitId`

**Behavior**
1. Validate input combinations (good must have dailyGoal; bad with reduce_to_target must have target)
2. **Eating-disorder safety check**: if `trackerType == junk_food` AND user has `eating_disorder` flag → silently swap to `mindful_eating` tracker variant (different schema variant, no counts/goals)
3. Generate `habitId = "{trackerType}_{shortuuid}"`
4. WriteBatch:
   - Create habit doc, `state: "active"`, `createdAt: now`
   - Initialize `users/{uid}/streaks/{habitId}` with `currentCount: 0, state: "fresh"`
   - Emit `habit_created`
5. Commit

**Emits**
- `habit_created`

**Errors**
- `InvalidHabitInputError` — required fields missing or wrong combination
- `DuplicateHabitError` — habit with same `(name, kind)` already exists for this user

#### `logGood(String habitId, GoodLogInput input) → Future<String>`

**Input** (`GoodLogInput`)
| Field | Type | Required | Notes |
|---|---|---|---|
| `amount` | `num` | yes | > 0 |
| `unit` | `string?` | no | If null, uses habit's default unit |
| `source` | `enum<manual|notification|coach|auto>` | no, default `manual` | |
| `note` | `string?` | no | |

**Behavior**
1. Validate habit exists, is `kind: good`, state == `active`
2. Validate `amount > 0`
3. Generate `logId`
4. Compute `today = userLocalDate(now)` formatted as `DateString`
5. WriteBatch:
   - Create `users/{uid}/habits/{habitId}/logs/{today}/items/{logId}` with `{amount, unit, ts, source, note}`
   - Emit `good_habit_logged` with payload including `todayTotalAfter` and `goalHitToday` flags
6. Commit

**Output**
- `Future<String>` — the new `logId`

**Emits**
- `good_habit_logged`

**Errors**
- `HabitNotFoundError`
- `WrongHabitKindError` — tried to logGood on a bad habit
- `HabitNotActiveError` — habit is paused/archived
- `InvalidAmountError` — amount <= 0

#### `logSlip(String habitId, SlipLogInput input) → Future<String>`

**Input** (`SlipLogInput`)
| Field | Type | Required | Notes |
|---|---|---|---|
| `trigger` | `enum<stress|boredom|social|after_meal|craving|other>?` | no | User picker is optional |
| `note` | `string?` | no | |
| `photoUrl` | `string?` | no | For junk-food tracker only |
| `relatedTaskId` | `string?` | no | For procrastination auto-detect |
| `source` | `enum<manual|auto>` | no, default `manual` | |

**Behavior**
1. Validate habit exists, is `kind: bad`, state == `active`
2. Generate `logId`
3. Compute `today`, count today's slips after this one
4. WriteBatch:
   - Create slip log
   - Emit `bad_habit_slip_logged` with payload including `countTodayAfter`
5. **Frequency check (post-commit, async)**: if `count == 3` within last 30 min → emit `slip_streak_detected`

**Output**
- `Future<String>` — the new `logId`

**Emits**
- `bad_habit_slip_logged`
- (conditionally) `slip_streak_detected`

**Errors**
- `HabitNotFoundError`
- `WrongHabitKindError`
- `HabitNotActiveError`

#### `deleteLog(String habitId, String logId, DateString logDate)`

**Behavior**
1. Hard-delete the log document
2. Emit `habit_log_deleted` with `{habitId, logId, deletedAt}`

**Notes**
- Used for swipe-left undo on a log entry
- Does NOT affect streak (streaks finalize at day-close, not on log)

### 3.3 Firestore document shapes

```
users/{uid}/habits/{habitId}:
{
  schemaVersion:    int       (1)
  habitId:          string
  name:             string
  kind:             string    ("good" | "bad")
  unit:             string
  trackerType:      string    ("water" | "meditation" | ... | "generic")
  dailyGoal:        number?   (good)
  goalType:         string?   (bad: "eliminate" | "reduce_to_target" | "awareness_only")
  target:           number?   (bad)
  baselinePerDay:   number?
  costPerUnit:      number?
  currency:         string?
  identityTags:     array<string>
  emoji:            string?
  color:            string?
  state:            string    ("active" | "paused" | "archived")
  createdAt:        timestamp
  updatedAt:        timestamp
}

users/{uid}/habits/{habitId}/logs/{YYYY-MM-DD}/items/{logId}:
{
  schemaVersion:    int
  logId:            string
  amount:           number?   (good habits)
  unit:             string?
  trigger:          string?   (bad habits)
  note:             string?
  photoUrl:         string?
  relatedTaskId:    string?
  source:           string    ("manual" | "notification" | "coach" | "auto")
  ts:               timestamp
}
```

### 3.4 Errors

| Error | When |
|---|---|
| `HabitNotFoundError` | habitId doesn't exist |
| `WrongHabitKindError` | Called wrong method for habit kind |
| `HabitNotActiveError` | Habit is paused or archived |
| `InvalidAmountError` | amount <= 0 for good habit log |
| `InvalidHabitInputError` | Create input has wrong shape |
| `DuplicateHabitError` | Same habit name+kind already exists |

---

## 4. StreakService

Computes streaks. Most logic runs at day-close, not on individual events.

### 4.1 Class shape

```
class StreakService {
  StreakService(this._firestore, this._auth, this._eventService);
  
  Future<void> runDayCloseRollup(DateString date);
  Future<void> handleComeback(int gapDays);
  
  Stream<Streak> watchStreak(String habitId);
  Stream<Map<String, Streak>> allStreaks();
}
```

### 4.2 Methods

#### `runDayCloseRollup(DateString date)`

Called by the day-close trigger (see §6 RoutineService).

**Behavior**
1. Read all `users/{uid}/habits/` where `state == "active"`
2. For each habit, compute `hitToday`:
   - **Good habit**: sum today's logs >= dailyGoal
   - **Bad habit (eliminate)**: today's slip count == 0
   - **Bad habit (reduce_to_target)**: today's slip count <= target
   - **Bad habit (awareness_only)**: never breaks streak (always returns true)
3. Read current `users/{uid}/streaks/{habitId}`
4. Apply accountability rule:
   - **Forgiving**: if `hitToday == false` AND `currentCount >= 6` AND `weeklySkipsUsed[currentWeek] == 0` → grant grace, set `weeklySkipsUsed[currentWeek] = 1`, treat as hit
   - **Strict / Ruthless**: no grace
5. Apply update:
   - If hit: `currentCount += 1`, `lastHitDate = date`, update longestCount if needed
   - If not hit: `currentCount = 0`, `lastBreakDate = date`, `state = "broken"`
6. Check milestones `[3, 7, 14, 30, 60, 90, 180, 365]`:
   - If `currentCount` matches → emit `streak_milestone_reached`
7. WriteBatch:
   - Update streak doc
   - Emit `streak_extended` OR `streak_broken`

**Emits (per habit)**
- `streak_extended` OR `streak_broken`
- (conditionally) `streak_milestone_reached`

**Errors**
- `DayCloseAlreadyRanError` — `lastDayClosed >= date` (idempotent guard)

#### `handleComeback(int gapDays)`

Called by ComebackFlow when user returns after 3+ day absence.

**Behavior**
1. Read all paused streaks (`state == "paused"`)
2. For each:
   - If `gapDays <= 7`: restore `currentCount = prePauseCount`, `state = "active"`, emit `streak_resumed`
   - If `gapDays > 7`: `currentCount = 0`, `state = "broken"`, emit `streak_broken` with `reason: "ghost_period_exceeded"`

### 4.3 Firestore document shape

```
users/{uid}/streaks/{habitId}:
{
  schemaVersion:    int
  habitId:          string
  currentCount:     int
  longestCount:     int
  lastHitDate:      string?    ("YYYY-MM-DD")
  lastBreakDate:    string?
  state:            string    ("active" | "paused" | "broken" | "fresh")
  pausedAt:         timestamp?
  prePauseCount:    int?
  weeklySkipsUsed:  map<string, int>   ("YYYY-Wxx": count)
  updatedAt:        timestamp
}
```

### 4.4 Errors

| Error | When |
|---|---|
| `DayCloseAlreadyRanError` | Trying to roll up a date that's already been closed |
| `StreakNotFoundError` | Habit has no streak record (shouldn't happen — should be initialized on habit create) |

---

## 5. RoutineService

Computes routine completion %, runs day-close orchestration.

### 5.1 Class shape

```
class RoutineService {
  RoutineService(this._firestore, this._auth, this._eventService, this._streakService);
  
  Future<void> runDayCloseIfNeeded();
  Future<RoutineSummary> dailySummary(DateString date);
  
  Stream<double> routinePctToday(String routineType);
  Stream<RoutineSummary> watchDailySummary(DateString date);
}
```

### 5.2 Methods

#### `runDayCloseIfNeeded()`

Called on every app start. Idempotent — safe to call repeatedly.

**Behavior**
```
1. Read users/{uid}.lastDayClosed
2. today = userLocalDate(now)
3. WHILE lastDayClosed < (today - 1 day):
     missedDate = lastDayClosed + 1 day
     summary = computeDailySummary(missedDate)
     write users/{uid}/dailySummaries/{missedDate} (set, merge: false)
     await streakService.runDayCloseRollup(missedDate)
     update users/{uid}.lastDayClosed = missedDate
     emit "day_closed" with payload {date: missedDate, ...summary}
```

**Notes**
- The WHILE loop handles "user offline for N days" → rolls up each missed day in order
- All writes are inside a single transaction per missed day to maintain consistency
- This is the **idempotent day-close** that the SystemDesign §5.4 describes

**Output**
- `Future<void>`

**Emits**
- `day_closed` (one per missed day)

**Errors**
- `DayCloseInProgressError` — another day-close is currently running (lock via `users/{uid}.dayCloseLockedAt`)

#### `computeDailySummary(DateString date) → RoutineSummary`

Pure function, no side effects.

**Behavior**
1. Read all tasks where `plannedStart` is in `[date 00:00, date+1 00:00)` user-local
2. Group by `parentRoutine` (or "custom" if null)
3. For each routine:
   - For each task, compute contribution per the rules in EventSystem §9.1:
     - `completed`: 1.0
     - `started/paused`: `min(elapsed / planned_duration, 0.95)`
     - `abandoned`: 0.0
     - `skipped` with valid reason: excluded from denominator
   - `routinePct = sum(contributions) / count(non-excluded)`
4. Compute `overallPct = weighted_avg(routinePct values)`
5. Compute `missionPct` (see Mission ring formula in EventSystem §10.1)
6. Return `RoutineSummary`

### 5.3 Document shapes

```
users/{uid}/dailySummaries/{YYYY-MM-DD}:
{
  schemaVersion:     int
  date:              string
  perRoutinePct:     map<string, number>   ({"skin_care": 1.0, "eating": 0.75, ...})
  overallPct:        number
  missionPct:        number
  completedCount:    int
  abandonedCount:    int
  skippedCount:      int
  scheduledCount:    int                    (denominator)
  slipCounts:        map<string, int>       (habit_id → count)
  identityProgress:  map<string, number>    (identity_id → % at end of day)
  lockedAt:          timestamp
}
```

### 5.4 Streams

| Stream | Returns | Notes |
|---|---|---|
| `routinePctToday(String routineType)` | `Stream<double>` | Live; recomputes on every task event |
| `watchDailySummary(DateString date)` | `Stream<RoutineSummary>` | Subscribes to the dailySummaries doc |

### 5.5 Errors

| Error | When |
|---|---|
| `DayCloseInProgressError` | Lock held by another invocation |

---

## 6. NotificationService

Schedules and persists local notifications. Handles re-registration on app start.

### 6.1 Class shape

```
class NotificationService {
  NotificationService(this._firestore, this._auth, this._eventService, this._localNotif);
  
  Future<bool> requestPermissions();
  Future<void> scheduleForTask(Task task);
  Future<void> cancelForTask(String taskId);
  Future<void> reRegisterAllOnAppStart();
  Future<void> scheduleCustom(NotificationInput input);
  
  Stream<List<ScheduledNotification>> upcomingNotifications();
}
```

### 6.2 Methods

#### `requestPermissions() → Future<bool>`

Called once during onboarding. iOS shows the system prompt; Android 13+ requires runtime permission.

**Output**
- `Future<bool>` — true if granted

#### `scheduleForTask(Task task)`

**Behavior**
1. Skip if no permission
2. Compute fire times based on `alarmTier`:
   - `gentle`: pre-reminder at `plannedStart - 5min`
   - `active`: pre-reminder + active alert at `plannedStart + 5min` (only if not started by then — checked at fire time)
   - `custom`: full-screen alarm at `plannedStart` + the active alert
3. For each fire time:
   - Generate `notifId`
   - Write `users/{uid}/scheduledNotifications/{notifId}`:
     ```
     {fireAt, category, priority, deepLink, title, body, taskId, state: "scheduled"}
     ```
   - Schedule via `flutter_local_notifications` / OS APIs
   - Emit `notification_scheduled`

**Emits**
- `notification_scheduled` (one per fire time)

**Errors**
- `NoNotificationPermissionError` — silently skips, doesn't throw

#### `cancelForTask(String taskId)`

**Behavior**
1. Query `scheduledNotifications` where `taskId == taskId AND state == "scheduled"`
2. For each:
   - Cancel with OS
   - Update doc `state = "cancelled"`

#### `reRegisterAllOnAppStart()`

**Critical method.** Called every app start.

**Behavior**
```
1. Read all scheduledNotifications where state == "scheduled" AND fireAt > now
2. For each, re-register with the OS via flutter_local_notifications
3. (For docs where state == "scheduled" AND fireAt < now-1h):
     mark state = "missed", emit "notification_missed"
```

This is what guarantees notifications survive device reboots, app updates, and reinstalls.

### 6.3 Document shape

```
users/{uid}/scheduledNotifications/{notifId}:
{
  schemaVersion:    int
  notifId:          string
  taskId:           string?
  category:         string    ("pre_reminder" | "active_alert" | "custom_alarm" | "ai_nudge" | "celebration")
  priority:         string    ("P1" | "P2" | "P3" | "P4" | "P5" | "P6")
  fireAt:           timestamp
  title:            string
  body:             string
  deepLink:         string?
  state:            string    ("scheduled" | "sent" | "tapped" | "dismissed" | "cancelled" | "missed")
  scheduledAt:      timestamp
  sentAt:           timestamp?
  tappedAt:         timestamp?
}
```

### 6.4 Errors

| Error | When |
|---|---|
| `NoNotificationPermissionError` | Permission not granted (silently swallowed in scheduleForTask) |
| `NotificationNotFoundError` | notifId doesn't exist when cancelling |

---

## 7. AuthService (thin wrapper)

```
class AuthService {
  Stream<User?> authStateChanges();
  Future<User> signUpWithEmail(String email, String password, String name);
  Future<User> signInWithEmail(String email, String password);
  Future<User> signInWithGoogle();
  Future<User> signInWithApple();
  Future<void> signOut();
  Future<void> deleteAccount();
  
  String? get currentUserId;
}
```

**Errors**
- `EmailAlreadyInUseError`, `InvalidCredentialsError`, `NetworkError`, etc. — wrap `FirebaseAuthException` codes

**Emits**
- `user_signed_up` on successful new account
- `account_deleted` on delete confirm

---

## 8. Event payload contracts (strict)

The single source of truth for what every event's payload looks like. Consumers MUST validate against these shapes; producers MUST match them exactly.

### Strict payload rule (zero variation)

Each event below has **exactly** the payload shape shown. No producer is permitted to:
- Add an undocumented field ("we just need this one extra thing")
- Omit a required field ("we don't have it right now, we'll skip it this time")
- Rename a field ("cleaner name")
- Change a field's type or unit ("seconds → minutes")
- Embed nested objects with their own undocumented schemas

If a producer needs a field that isn't in the contract, the contract changes first (PR to this doc), then the code. **The doc moves first.** Producers are validated at write time by `EventService.emit` against the registered schema; mismatches throw `EventValidationError` and the event is rejected.

**Example of what this rule prevents.** v1 of the doc may say `task_completed` payload is `{taskId, plannedDurationMin, actualDurationMin, driftPct, ...}`. A drifting producer might emit `{task_id, duration_planned, duration_actual, drift}` because "those names are clearer." Any consumer reading the documented schema breaks. The streak service silently fails to extend, the AI's memory has gaps, the analytics dashboard shows wrong numbers. This rule is the seatbelt.

### Convention
All payloads include the fields shown. Optional fields are marked `?`. Adding fields requires bumping `payloadVersion`.

### `task_scheduled`
```
{
  taskId:           string
  type:             string
  parentRoutine:    string?
  plannedStart:     timestamp
  plannedEnd:       timestamp
  plannedDurationMin: int
  alarmTier:        string
  identityTags:     array<string>
}
```

### `task_started`
```
{
  taskId:           string
  plannedStart:     timestamp
  actualStart:      timestamp
  driftMin:         int
  startedVia:       string    ("ui" | "alarm_dismiss" | "ui_quick_complete")
}
```

### `task_paused`
```
{
  taskId:           string
  pausedAt:         timestamp
  elapsedSoFarMin:  int
}
```

### `task_resumed`
```
{
  taskId:           string
  resumedAt:        timestamp
  pauseDurationMin: int
}
```

### `subtask_checked`
```
{
  taskId:           string
  subtaskId:        string
  checked:          bool
  ts:               timestamp
}
```

### `task_completed`
```
{
  taskId:           string
  plannedDurationMin:    int
  actualDurationMin:     int
  driftPct:              number
  subtasksCompleted:     int
  subtasksTotal:         int
  totalPauseDurationMin: int
}
```

### `task_abandoned`
```
{
  taskId:           string
  abandonedAt:      timestamp
  reason:           string    ("user_skipped" | "auto_idle" | "auto_no_start")
  reasonTag:        string?
  startedAt:        timestamp?
  elapsedAtAbandonMin: int?
}
```

### `good_habit_logged`
```
{
  habitId:          string
  amount:           number
  unit:             string
  source:           string
  todayTotalAfter:  number
  goalHitToday:     bool
}
```

### `bad_habit_slip_logged`
```
{
  habitId:          string
  trigger:          string?
  note:             string?
  photoUrl:         string?
  relatedTaskId:    string?
  countTodayAfter:  int
  source:           string
}
```

### `slip_streak_detected`
```
{
  habitId:          string
  count:            int
  windowMin:        int
  firstSlipTs:      timestamp
  lastSlipTs:       timestamp
}
```

### `habit_log_deleted`
```
{
  habitId:          string
  logId:            string
  deletedAt:        timestamp
}
```

### `habit_created`
```
{
  habitId:          string
  kind:             string
  trackerType:      string
}
```

### `streak_extended`
```
{
  habitId:          string
  oldCount:         int
  newCount:         int
  isMilestone:      bool
}
```

### `streak_broken`
```
{
  habitId:          string
  oldCount:         int
  reason:           string    ("missed_target" | "slip" | "abandoned" | "ghost_period_exceeded")
}
```

### `streak_milestone_reached`
```
{
  habitId:          string
  milestone:        int       (3, 7, 14, 30, 60, 90, 180, 365)
  streakCount:      int
}
```

### `streak_paused` / `streak_resumed`
```
streak_paused:
{
  habitId:          string
  pausedAt:         timestamp
  prePauseCount:    int
}

streak_resumed:
{
  habitId:          string
  resumedAt:        timestamp
  restoredCount:    int
  gapDays:          int
}
```

### `routine_block_completed` (derived; emitted by listener, not directly)
```
{
  taskId:           string
  routineType:      string
  weekday:          int       (1-7)
  routinePctToday:  number
}
```

### `day_started`
```
{
  date:             string    ("YYYY-MM-DD")
  weekdayTemplateId: string
  plannedBlocksCount: int
}
```

### `day_closed`
```
{
  date:             string
  completionPct:    number
  missionPct:       number
  completedCount:   int
  abandonedCount:   int
  skippedCount:     int
  slipCounts:       map<string, int>
  focusMinutes:     int
}
```

### `notification_scheduled` / `notification_sent` / `notification_tapped` / `notification_dismissed` / `notification_suppressed`
```
notification_scheduled:
{
  notifId:          string
  fireAt:           timestamp
  category:         string
  priority:         string
  deepLink:         string?
}

notification_sent:
{
  notifId:          string
  category:         string
  priority:         string
  ts:               timestamp
  delivered:        bool
}

notification_tapped:
{
  notifId:          string
  tappedAt:         timestamp
  deepLink:         string?
}

notification_dismissed:
{
  notifId:          string
  dismissedVia:     string    ("swipe" | "clear_all" | "auto_expire")
}

notification_suppressed:
{
  wouldHaveBeenId:  string
  reason:           string    ("budget_full" | "dnd" | "cooldown" | "dedup" | "silence_window")
}
```

### `identity_progress_changed`
```
{
  identityId:       string
  oldPct:           number
  newPct:           number
  delta:            number
  contributorsChanged: array<string>
}
```

### `milestone_completed`
```
{
  identityId:       string
  milestoneId:      string
  completedAt:      timestamp
  autoOrManual:     string    ("auto" | "manual")
}
```

### `biometrics_updated`
```
{
  fieldsChanged:    array<string>
  old:              map<string, any>
  new:              map<string, any>
}
```

### `ghost_day_detected` / `comeback_initiated`
```
ghost_day_detected:
{
  lastSeenTs:       timestamp
  missedDays:       int
}

comeback_initiated:
{
  gapDays:          int
  lastSeenTs:       timestamp
}
```

### `user_signed_up`
```
{
  email:            string
  signupTs:         timestamp
  signupSource:     string    ("email" | "google" | "apple")
}
```

### `onboarding_completed`
```
{
  identityProfile:  map
  biometrics:       map
  scheduleId:       string
  coachConfig:      map
  accountability:   string
}
```

### `account_deleted`
```
{
  deletedAt:        timestamp
  scheduledPurgeAt: timestamp
}
```

---

## 9. Firestore access rules — code-level table

The matrix of who can read/write what. Every rule is enforced both in `firestore.rules` AND in the service layer (defense in depth).

| Path | Client read | Client write | Service responsible |
|---|---|---|---|
| `users/{uid}` | self only | self only (whole doc replaceable, but UI only edits `profile`, `biometrics`, `lifestyle`, `identities`, `healthFlags`) | UserService / OnboardingService |
| `users/{uid}/devices/{deviceId}` | self | self | AuthService (writes deviceId on first launch) |
| `users/{uid}/tasks/{taskId}` | self | self via TaskService only | TaskService |
| `users/{uid}/taskOutcomes/{taskId}` | self | append-only via TaskService | TaskService |
| `users/{uid}/habits/{habitId}` | self | self via HabitService only | HabitService |
| `users/{uid}/habits/{habitId}/logs/{date}/items/{logId}` | self | self via HabitService only | HabitService |
| `users/{uid}/streaks/{habitId}` | self | self via StreakService only | StreakService |
| `users/{uid}/identities/{identityId}` | self | self | IdentityService |
| `users/{uid}/events_recent/{eventId}` | self | **create only**, never update or delete | EventService |
| `users/{uid}/events_archive/**` | self read | server only (Cloud Function) | (server) |
| `users/{uid}/dailySummaries/{date}` | self | self via RoutineService only | RoutineService |
| `users/{uid}/scheduledNotifications/{notifId}` | self | self via NotificationService only | NotificationService |
| `users/{uid}/suggestions/{suggestionId}` | self read; can update `state` field only | server creates (Cloud Function); user updates state only | (server) + UI |
| `config/**` | any authenticated user | nobody (admin console only) | — |

### Service-layer enforcement rule

Every service method that writes to Firestore goes through this guard:

```
guard:
  - require auth.currentUser != null
  - require all writes are inside users/{auth.currentUser.uid}/...
  - require WriteBatch (no single writes outside batches except for event-only emissions)
  - require no Service A calling Service B's write methods
```

If a service ever needs to "update something belonging to another service," it instead emits an event and lets that other service react.

---

## 10. Riverpod provider contracts

The exact shape of every public provider. UI widgets subscribe to these — they should never instantiate services directly.

### 10.1 Core service providers

```
final eventServiceProvider          : Provider<EventService>
final taskServiceProvider           : Provider<TaskService>
final habitServiceProvider          : Provider<HabitService>
final streakServiceProvider         : Provider<StreakService>
final routineServiceProvider        : Provider<RoutineService>
final notificationServiceProvider   : Provider<NotificationService>
final authServiceProvider           : Provider<AuthService>
```

### 10.2 Auth & user providers

| Provider | Returns | Notes |
|---|---|---|
| `authStateProvider` | `StreamProvider<User?>` | Firebase Auth state |
| `currentUserProvider` | `Provider<User?>` | Synchronous accessor |
| `userProfileProvider` | `StreamProvider<UserProfile>` | Watches `users/{uid}` |

### 10.3 Task providers

| Provider | Type | Returns | Notes |
|---|---|---|---|
| `tasksForDateProvider(DateTime)` | `StreamProvider.family` | `List<Task>` | Today's or any date's tasks |
| `taskProvider(String)` | `StreamProvider.family` | `Task?` | Single task by ID |
| `activeTaskProvider` | `StreamProvider` | `Task?` | The pinned active task |
| `taskCountForRoutineProvider({routineType, date})` | `Provider.family` | `({completed, total})` | For routine cards |

### 10.4 Habit providers

| Provider | Type | Returns | Notes |
|---|---|---|---|
| `activeHabitsProvider` | `StreamProvider` | `List<Habit>` | All active habits |
| `goodHabitsProvider` | `StreamProvider` | `List<Habit>` | Filtered |
| `badHabitsProvider` | `StreamProvider` | `List<Habit>` | Filtered |
| `habitProvider(String)` | `StreamProvider.family` | `Habit?` | |
| `habitTodayTotalProvider(String)` | `StreamProvider.family` | `num` | Today's running total |
| `habitTodayLogsProvider(String)` | `StreamProvider.family` | `List<HabitLog>` | Today's log entries |
| `habitWeeklyTotalsProvider(String)` | `StreamProvider.family` | `Map<DateString, num>` | 7-day totals |

### 10.5 Streak providers

| Provider | Type | Returns | Notes |
|---|---|---|---|
| `streakProvider(String)` | `StreamProvider.family` | `Streak` | Per habit |
| `allStreaksProvider` | `StreamProvider` | `Map<String, Streak>` | Map by habitId |

### 10.6 Routine / mission providers

| Provider | Type | Returns | Notes |
|---|---|---|---|
| `routinePctTodayProvider(String)` | `StreamProvider.family` | `double` | Per routine type |
| `dailySummaryProvider(DateString)` | `StreamProvider.family` | `RoutineSummary` | |
| `missionRingProvider` | `StreamProvider` | `double` | Today's mission %, [0, 1] |

### 10.7 Notification provider

| Provider | Type | Returns |
|---|---|---|
| `upcomingNotificationsProvider` | `StreamProvider` | `List<ScheduledNotification>` |
| `notificationPermissionProvider` | `StateProvider<bool>` | granted state |

### 10.8 Provider rules

1. **No widget instantiates a service directly.** Always go through a provider.
2. **No provider does writes.** Providers are read-side only. Writes happen via service methods called from event handlers (button presses).
3. **All `family` providers must dispose unused instances.** Use `.autoDispose.family` for any provider keyed by user-ephemeral data (selected dates, etc.).

---

## 11. Error handling strategy

### 11.1 Error class hierarchy

```
OptivusError (abstract)
├── ValidationError
│   ├── InvalidHabitInputError
│   ├── InvalidAmountError
│   ├── InvalidTimeRangeError
│   ├── TaskTooLongError
│   └── TaskInPastError
├── NotFoundError
│   ├── TaskNotFoundError
│   ├── HabitNotFoundError
│   ├── SubtaskNotFoundError
│   ├── StreakNotFoundError
│   └── NotificationNotFoundError
├── StateError
│   ├── InvalidStateTransitionError
│   ├── MultipleActiveTasksError
│   ├── HabitNotActiveError
│   ├── WrongHabitKindError
│   ├── DayCloseAlreadyRanError
│   └── DayCloseInProgressError
├── AuthError
│   ├── NotAuthenticatedError
│   ├── EmailAlreadyInUseError
│   └── InvalidCredentialsError
├── ConflictError
│   ├── DuplicateHabitError
│   └── EventDuplicateError
├── PermissionError
│   └── NoNotificationPermissionError
└── InfraError
    ├── FirestoreUnavailable
    └── NetworkError
```

### 11.2 Where each error class is handled

| Error class | Recovery strategy |
|---|---|
| `ValidationError` | Reject in UI before service call. Service throws as defensive last resort. |
| `NotFoundError` | UI shouldn't have shown the action — refresh list and retry. |
| `StateError` | UI is stale — re-read state and either retry automatically or show "refresh and try again" |
| `AuthError` | Redirect to login. |
| `ConflictError` | Idempotent operations: ignore. Non-idempotent: show user-friendly message. |
| `PermissionError` | Silently degrade (skip notification scheduling). On critical features, prompt to enable in settings. |
| `InfraError` | Firestore SDK auto-retries; show toast on persistent failure. |

### 11.3 The error handling rule

**Every service method that writes to Firestore is wrapped in:**

```
try {
  // build payload, validate locally
  // run WriteBatch
  // commit
  return result
} on FirebaseException catch (e) {
  throw FirestoreUnavailable.fromFirebaseException(e)
} on OptivusError {
  rethrow                    // already typed, propagate
} catch (e, st) {
  Crashlytics.recordError(e, st)
  throw InfraError.unknown(e.toString())
}
```

UI catches `OptivusError` subclasses with specific messages; falls back to "Something went wrong" toast for unknown.

### 11.4 What never throws

Some methods are required to be exception-safe by the architecture:
- `EventService.replayRecentEvents()` — failures are logged, never thrown
- `NotificationService.reRegisterAllOnAppStart()` — same
- `RoutineService.runDayCloseIfNeeded()` — same; if it fails, next app open will retry

If any of these throws, app startup breaks. So they catch internally and log.

---

## 12. Quick-reference — building a new feature

When adding a new feature, walk this checklist:

1. **What events does it emit?** Add them to §8 with payload contract.
2. **What events does it listen to?** Make sure those exist; if not, add them.
3. **What service does it live in?** If none fits, create one (rare in MVP).
4. **What Firestore paths does it read/write?** Add to §9.
5. **What Riverpod providers does the UI need?** Add to §10.
6. **What can go wrong?** Add error types to §11.
7. **Update the User Flow doc** with the user-visible behavior.
8. **Then write code.**

If you can't fill out steps 1–7, you're not ready to write code yet. Spend 30 more minutes here, save 3 hours later.

---

## Closing

This document is the **before-code contract**. It looks like overhead. It is not. It is the difference between writing code once and writing it three times.

The other docs answer *why* and *what*. This one answers *exactly how the pieces talk to each other*. When you're three weeks into coding and you can't remember whether `task_completed`'s payload has `actualDurationMin` or `actualDuration`, you open this doc, you find the answer in 5 seconds, and you keep coding.

When something doesn't match this doc, fix this doc *first*. Then fix the code. Drift between doc and code is the leading cause of "we need to refactor everything" four months in.

Now you can start coding.
