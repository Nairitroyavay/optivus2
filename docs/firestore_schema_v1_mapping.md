# Firestore Schema v1 Mapping

Last updated: May 2026

All user-owned application data is scoped under `/users/{uid}`. Clients must never read or write another user's subtree.

## Per-User Paths

| Path | Purpose |
| --- | --- |
| `/users/{uid}` | Root user record and onboarding flags |
| `/users/{uid}/profile/main` | User profile, biometrics, lifestyle, notification budget |
| `/users/{uid}/onboarding/state` | Draft/completed onboarding state |
| `/users/{uid}/routine/current` | Current routine template config |
| `/users/{uid}/tasks/{taskId}` | Materialized scheduled task docs |
| `/users/{uid}/task_outcomes/{taskId}` | Completed/abandoned task outcome summaries |
| `/users/{uid}/habits/{habitId}` | Habit definitions |
| `/users/{uid}/habits/{habitId}/logs/{date}/items/{itemId}` | Legacy habit log item copy, derived from canonical `habit_logs` |
| `/users/{uid}/habit_logs/{logId}` | Canonical habit log entries |
| `/users/{uid}/streaks/{streakId}` | Habit streak state |
| `/users/{uid}/goals/{goalId}` | Goal definitions |
| `/users/{uid}/identity_profile/main` | Computed identity profile |
| `/users/{uid}/events/{eventId}` | Immutable event audit log |
| `/users/{uid}/events_recent/{eventId}` | Immutable recent event cache |
| `/users/{uid}/scheduled_notifications/{notificationId}` | Scheduled notification intents |
| `/users/{uid}/notificationLog/{logId}` | Notification delivery/tap/suppression audit |
| `/users/{uid}/suggestions/{suggestionId}` | Deterministic or AI-generated suggestions |
| `/users/{uid}/coach_messages/{messageId}` | Coach conversation messages |
| `/users/{uid}/coach_speak_log/{logId}` | Coach/rule decision audit |
| `/users/{uid}/coach_chats/{chatId}/turns/{turnId}` | Legacy fallback coach turns |
| `/users/{uid}/ai_context_snapshots/{snapshotId}` | Aggregated AI context snapshots |
| `/users/{uid}/dailySummaries/{date}` | Daily rollups keyed by `YYYY-MM-DD` |
| `/users/{uid}/weeklySummaries/{weekKey}` | Weekly rollups keyed by `YYYY-Www` |
| `/users/{uid}/devices/{deviceId}` | Device and push-token registry |
| `/users/{uid}/data_exports/{exportId}` | User data export requests |
| `/users/{uid}/deletion_requests/{requestId}` | Account deletion requests |
| `/users/{uid}/usage/{monthKey}` | Monthly usage counters keyed by `YYYY-MM` |
| `/users/{uid}/screenTimeRaw/{logId}` | Raw daily screen-time imports |
| `/users/{uid}/money_saved/{date}` | Money-saved daily aggregates and manual deposits |
| `/users/{uid}/money_savings_goals/{goalId}` | Money-saved tracker goals |
| `/users/{uid}/fitnessActivities/{activityId}` | Fitness activity state and summary metrics |
| `/users/{uid}/fitnessActivities/{activityId}/routePoints/{pointId}` | Route polyline points; numeric GPS metadata only |
| `/users/{uid}/fitnessActivities/{activityId}/splits/{splitId}` | Activity split/lap summaries |
| `/users/{uid}/fitnessActivities/{activityId}/heartRateSamples/{sampleId}` | Optional heart-rate samples |
| `/users/{uid}/fitnessStats/{periodKey}` | Daily/weekly/monthly fitness aggregates |
| `/users/{uid}/fitnessGoals/{goalId}` | Fitness goals |

## Routine Current

Path: `/users/{uid}/routine/current`

`routine/current` stores template configuration. The canonical v1 shape is:

```js
{
  schemaVersion: 1,
  updatedAt: Timestamp,
  fixedScheduleSetUp: true,
  skinCareSetUp: false,
  eatingSetUp: false,
  classesSetUp: false,
  supplementsSetUp: false,
  customTemplatesSetUp: false,

  templates: {
    fixed_schedule: [
      {
        templateId: "starter_morning_focus",
        title: "Morning Focus",
        routineType: "fixed_schedule",
        startTime: "09:00",
        endTime: "09:30",
        repeatRule: "daily",
        category: "Focus",
        notes: "",
        isActive: true,
        createdAt: "2026-05-02T...",
        updatedAt: "2026-05-02T..."
      }
    ],

    skin_care: [
      {
        templateId: "...",
        title: "Morning Skin Care",
        routineType: "skin_care",
        startTime: "07:30",
        endTime: "07:45",
        repeatRule: "daily",
        steps: [{ name: "Cleanser", tag: "cleanse" }],
        isActive: true,
        createdAt: Timestamp,
        updatedAt: Timestamp
      }
    ],

    supplements: [
      {
        templateId: "...",
        title: "Vitamin D",
        routineType: "supplements",
        startTime: "08:30",
        endTime: "08:35",
        repeatRule: "daily",
        dosage: "1000 IU",
        withMeal: true,
        isActive: true,
        createdAt: Timestamp,
        updatedAt: Timestamp
      }
    ],

    classes: [
      {
        templateId: "...",
        title: "Biology",
        routineType: "classes",
        startTime: "10:00",
        endTime: "11:00",
        repeatRule: "weekly:1,3,5",
        room: "A-201",
        professor: "Dr. Smith",
        colorHex: "#3B82F6",
        isActive: true,
        createdAt: Timestamp,
        updatedAt: Timestamp
      }
    ],

    eating: [
      {
        templateId: "...",
        title: "Lunch",
        routineType: "eating",
        startTime: "13:00",
        endTime: "13:30",
        repeatRule: "daily",
        mealType: "lunch",
        isActive: true,
        createdAt: Timestamp,
        updatedAt: Timestamp
      }
    ],

    custom: [
      {
        templateId: "...",
        title: "Project Review",
        routineType: "custom",
        startTime: "16:00",
        endTime: "16:45",
        repeatRule: "once",
        targetDate: "2026-05-02",
        isOneOff: true,
        isActive: true,
        createdAt: Timestamp,
        updatedAt: Timestamp
      }
    ]
  }
}
```

The current Dart model already serializes fixed schedule templates to `templates.fixed_schedule`. Older routine screens may adapt through legacy `FixedBlock` APIs, but persisted v1 data should use `templates`.

## Materialized Tasks

Path: `/users/{uid}/tasks/{taskId}`

Every task created from a routine template must include these materialization fields in addition to its normal task state fields:

| Field | Type | Notes |
| --- | --- | --- |
| `sourceRoutineType` | string | `fixed_schedule`, `skin_care`, `supplements`, `classes`, `eating`, or `custom` |
| `routineTemplateId` | string | Template ID from `/routine/current.templates.{type}` |
| `scheduledDate` | string | Local calendar date, `YYYY-MM-DD` |
| `plannedStart` | Timestamp | Planned start |
| `plannedEnd` | Timestamp | Planned end |
| `repeatRule` | string | `daily`, `weekly:1,3,5`, `once`, or future RRULE-compatible value |
| `materializedFromTemplateAt` | Timestamp | When the task document was generated from the template |

The current runtime task model stores lifecycle as `state`; the v1 query/index field is `status`. New materialization helpers should write both during migration.

## Events

Paths:

| Path | Notes |
| --- | --- |
| `/users/{uid}/events/{eventId}` | Full immutable event log |
| `/users/{uid}/events_recent/{eventId}` | Same envelope, trimmed/replayed for recent context |

Event envelope:

```js
{
  eventId: string,
  eventName: string,
  uid: string,
  timestamp: Timestamp,
  source: string,
  schemaVersion: 1,
  payloadVersion: 1,
  payload: {},
  deviceId: string,
  appVersion: string
}
```

Events are create-only from clients. Both event collections receive the same envelope in one transaction or batch.

`timestamp` is the canonical event time field. New queries and indexes use `timestamp`. Any `ts`-only legacy event documents require a backfill before they appear in new aggregator queries.

## R2 Metadata

Image/file bytes are not stored in Firestore. Upload flows use Cloudflare R2 through Worker-issued signed URLs and persist only small metadata maps, for example:

```js
{
  imageMetadata: {
    objectKey: "users/{uid}/uploads/classes/1710000000000.jpg",
    path: "users/{uid}/uploads/classes/1710000000000.jpg",
    sizeBytes: 245000,
    mimeType: "image/jpeg",
    provider: "cloudflare_r2"
  }
}
```

Do not store base64, raw bytes, audio blobs, image blobs, or data URLs in Firestore. `firestore.rules` deny common top-level blob/base64 field names for client writes, and deny the same first-level keys inside event payloads. Rules do not recursively inspect every nested map, so model/service code must keep nested metadata maps to object keys and small descriptors only.

## Account Export and Deletion Requests

Paths:

| Path | Client access | Required create fields |
| --- | --- | --- |
| `/users/{uid}/data_exports/{exportId}` | Owner read/create only; no update/delete | `uid`, `requestedAt`, `status`, `schemaVersion` |
| `/users/{uid}/deletion_requests/{requestId}` | Owner read/create only; no update/delete | `uid`, `requestedAt`, `status`, `schemaVersion` |

Allowed client-created statuses are `requested` and `pending`. Clients cannot write export result objects, deletion completion markers, or large file/blob fields to these request documents.

Client-side cleanup is best-effort only. The app may delete rules-allowed user data collections, including known nested fitness, coach, and legacy habit log copies, but it must skip append-only/request collections: `events`, `events_recent`, `data_exports`, and `deletion_requests`. Full account deletion is a later account lifecycle task started by creating a `deletion_requests` document.

Legacy habit log item copies are exported and deleted through their canonical `/users/{uid}/habit_logs/{logId}` rows, using `habitId` and `occurredAt` to locate `/users/{uid}/habits/{habitId}/logs/{date}/items/{logId}`. Orphaned legacy nested item docs with no canonical `habit_logs` row are not discoverable by the client SDK and require the later account lifecycle worker/backfill.

## Rules Summary

Rules live in `firestore.rules`.

| Scope | Client access |
| --- | --- |
| `/users/{uid}` | Owner read/create/update/delete; root update cannot alter `uid`, `createdAt`, or `schemaVersion` |
| `/users/{uid}/{knownCollection}/{doc}` | Owner read/write for whitelisted top-level user-owned app data when an optional `uid` field matches `{uid}` |
| `/users/{uid}/events/{eventId}` | Owner read/create only; envelope is required; `eventId` and `uid` must match |
| `/users/{uid}/events_recent/{eventId}` | Same as `events` |
| `/users/{uid}/data_exports/{exportId}` | Owner read/create only; constrained request schema |
| `/users/{uid}/deletion_requests/{requestId}` | Owner read/create only; constrained request schema |
| `/users/{uid}/fitnessActivities/{activityId}/routePoints/{pointId}` | Owner read/create/update/delete; no blob/base64 fields |
| `/users/{uid}/fitnessActivities/{activityId}/splits/{splitId}` | Owner read/create/update/delete; no blob/base64 fields |
| `/users/{uid}/fitnessActivities/{activityId}/heartRateSamples/{sampleId}` | Owner read/create/update/delete; no blob/base64 fields |
| `/users/{uid}/habits/{habitId}/logs/{date}/items/{itemId}` | Owner read/create/update/delete; no blob/base64 fields |
| `/users/{uid}/coach_chats/{chatId}/turns/{turnId}` | Owner read/create/update/delete; no blob/base64 fields |
| `/app_config/{doc}` | Authenticated read only |
| `/crisis_handoffs/{doc}` | Client access denied |

Admin SDK bypasses rules for trusted backend maintenance.

## Indexes

Indexes live in `firestore.indexes.json`.

### tasks

| Fields | Query |
| --- | --- |
| `scheduledDate ASC`, `plannedStart ASC`, `status ASC`, `sourceRoutineType ASC` | Day-view: fetch tasks for a date ordered by start time, filtered by status and routine type |
| `scheduledDate ASC`, `status ASC`, `sourceRoutineType ASC`, `plannedStart ASC` | Day-view variant: filter by status + routine type first, then order by start time |
| `scheduledDate ASC`, `plannedStart ASC` | Day-view: all tasks for a date ordered by start time |
| `status ASC`, `plannedStart ASC` | Upcoming open tasks ordered by planned start (v1 `status` field) |
| `status ASC`, `plannedEnd ASC` | Overdue detection: open tasks ordered by planned end |
| `state ASC`, `plannedStart ASC` | Upcoming open tasks ordered by planned start (runtime `state` field, written alongside `status` during migration) |
| `parentRoutine ASC`, `plannedStart DESC` | Fetch all tasks spawned from a given routine template, most recent first |

### events / events_recent

| Collection group | Fields | Query |
| --- | --- | --- |
| `events_recent` | `eventName ASC`, `timestamp DESC` | Fetch recent events of a specific type, newest first |
| `events_recent` | `timestamp DESC` | Fetch all recent events newest first (single-field, kept explicit for deploy consistency) |
| `events` | `eventName ASC`, `timestamp DESC` | Same query on the full audit log |

### suggestions

| Fields | Query |
| --- | --- |
| `status ASC`, `createdAt DESC` | Fetch pending/accepted suggestions ordered newest first |
| `status ASC`, `targetSurface ASC` | Fetch pending suggestions for a specific UI surface |

### coach_messages

| Fields | Query |
| --- | --- |
| `sessionId ASC`, `createdAt ASC` | Load all messages in a coach session in chronological order |
| `createdAt DESC` | Global feed of coach messages newest first |

### scheduled_notifications

| Fields | Query |
| --- | --- |
| `status ASC`, `scheduledFor ASC` | Legacy: fetch pending notifications by legacy `scheduledFor` field |
| `status ASC`, `fireAt ASC` | Fetch pending notifications by `fireAt` (v1 field, used by notification dispatcher) |
| `state ASC`, `fireAt ASC` | Fetch pending notifications by `state` (runtime field written alongside `status` during migration) |
| `taskId ASC`, `status ASC` | Cancel pending notifications associated with a task |
| `routineTemplateId ASC`, `scheduledDate ASC`, `scheduledTime ASC`, `category ASC`, `status ASC` | Detect duplicate pending routine notifications |

### notificationLog

| Fields | Query |
| --- | --- |
| `timestamp DESC` | Notification center feed newest first |

### dailySummaries

| Fields | Query |
| --- | --- |
| `date DESC` | Fetch recent daily summaries newest first |

### weeklySummaries

| Fields | Query |
| --- | --- |
| `weekKey DESC` | Fetch the N most recent weekly summaries (e.g., for coach context window) |

### habits / habit_logs / streaks / coach_speak_log

| Collection group | Fields | Query |
| --- | --- | --- |
| `habits` | `type ASC`, `createdAt ASC` | Fetch habits by type in creation order |
| `habits` | `trackerType ASC`, `state ASC` | Fetch active tracker-specific habits |
| `habit_logs` | `habitId ASC`, `occurredAt ASC` | Habit history oldest-first for streak calculation |
| `habit_logs` | `habitId ASC`, `occurredAt DESC` | Habit history newest-first for display |
| `habit_logs` | `occurredAt DESC` | Global log feed newest first |
| `habit_logs` | `logType ASC`, `occurredAt ASC` | Fetch slip logs for a day |
| `habit_logs` | `habitId ASC`, `logType ASC`, `occurredAt ASC` | Fetch typed logs for one habit in a day |
| `streaks` | `habitId ASC`, `lastHitDate DESC` | Current streak state per habit |
| `streaks` | `state ASC`, `pauseReason ASC` | Fetch paused ghost streaks for cleanup |
| `coach_speak_log` | `decision ASC`, `createdAt DESC` | Filter coach decisions by outcome, newest first |

### fitnessActivities

| Fields | Query |
| --- | --- |
| `status ASC`, `completedAt ASC` | Recompute daily fitness stats from completed activities |
