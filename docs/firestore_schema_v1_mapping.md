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
| `/users/{uid}/ai_context_snapshots/{snapshotId}` | Aggregated AI context snapshots |
| `/users/{uid}/dailySummaries/{date}` | Daily rollups keyed by `YYYY-MM-DD` |
| `/users/{uid}/weeklySummaries/{weekKey}` | Weekly rollups keyed by `YYYY-Www` |
| `/users/{uid}/devices/{deviceId}` | Device and push-token registry |
| `/users/{uid}/data_exports/{exportId}` | User data export requests |
| `/users/{uid}/deletion_requests/{requestId}` | Account deletion requests |
| `/users/{uid}/usage/{monthKey}` | Monthly usage counters keyed by `YYYY-MM` |

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

## Rules Summary

Rules live in `firestore.rules`.

| Scope | Client access |
| --- | --- |
| `/users/{uid}` | Owner read/create/update/delete; root update cannot alter `uid`, `createdAt`, or `schemaVersion` |
| `/users/{uid}/{collection}/{doc...}` | Owner read/write for user-owned app data when an optional `uid` field matches `{uid}` |
| `/users/{uid}/events/{eventId}` | Owner read/create only; envelope is required; `eventId` and `uid` must match |
| `/users/{uid}/events_recent/{eventId}` | Same as `events` |
| `/users/{uid}/data_exports/{exportId}` | Owner read/create only |
| `/users/{uid}/deletion_requests/{requestId}` | Owner read/create only |
| `/app_config/{doc}` | Authenticated read only |
| `/crisis_handoffs/{doc}` | Client access denied |

Admin SDK bypasses rules for trusted backend maintenance.

## Indexes

Indexes live in `firestore.indexes.json`.

Required v1 composite indexes:

| Collection group | Fields |
| --- | --- |
| `tasks` | `scheduledDate ASC`, `plannedStart ASC`, `status ASC`, `sourceRoutineType ASC` |
| `tasks` | `scheduledDate ASC`, `status ASC`, `sourceRoutineType ASC`, `plannedStart ASC` |
| `tasks` | `scheduledDate ASC`, `plannedStart ASC` |
| `tasks` | `status ASC`, `plannedStart ASC` |
| `tasks` | `status ASC`, `plannedEnd ASC` |
| `events_recent` | `eventName ASC`, `timestamp DESC` |
| `events_recent` | `timestamp DESC` |
| `suggestions` | `status ASC`, `createdAt DESC` |
| `scheduled_notifications` | `status ASC`, `fireAt ASC` |

Additional compatibility indexes are currently retained for event history, habit logs, streaks, coach messages, and legacy `scheduledFor` notification queries.
