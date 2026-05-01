// test/services/task_service_contract_test.dart
//
// Contract tests for TaskService.
// All groups are skipped (TODO) — implement with fake_cloud_firestore /
// firebase_auth_mocks once those dev-dependencies are added.
//
// Public surface under test:
//   TaskService.tasksFor(date)
//   TaskService.tasksForWindow(from, {days})
//   TaskService.createTask(task)
//   TaskService.syncRoutineTasks(tasks)
//   TaskService.startTask(taskId)
//   TaskService.pauseTask(taskId)
//   TaskService.resumeTask(taskId)
//   TaskService.completeTask(taskId)
//   TaskService.abandonTask(taskId, {reason, reasonTag})
//   TaskService.skipTask(taskId, {reason, reasonTag})
//   TaskService.toggleSubtask(taskId, subtaskId)
//
// State machine:
//   scheduled → started → paused → started → completed / abandoned
//   scheduled → abandoned  (via skipTask)

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── tasksFor ────────────────────────────────────────────────────────────────

  group('TaskService.tasksFor — happy path', () {
    test(
      'TODO: returns only tasks whose plannedStart falls within the given calendar day',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: stream emits an updated list when a new task is added to Firestore',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: returns an empty list when no tasks exist for the day',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── tasksForWindow ──────────────────────────────────────────────────────────

  group('TaskService.tasksForWindow — happy path', () {
    test(
      'TODO: returns tasks spanning a 14-day window starting at `from`',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: excludes tasks whose plannedStart falls before the window start',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── createTask ──────────────────────────────────────────────────────────────

  group('TaskService.createTask — happy path', () {
    test(
      'TODO: writes task doc to /users/{uid}/tasks/{taskId}',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: emits task_scheduled event inside the same WriteBatch',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: event payload contains taskId, type, plannedStart, plannedEnd, plannedDurationMin',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('TaskService.createTask — validation errors', () {
    test(
      'TODO: throws InvalidTimeRangeError when plannedEnd ≤ plannedStart',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: throws TaskTooLongError when plannedDurationMin > 480',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: throws NotAuthenticatedError when no user is signed in',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── syncRoutineTasks ────────────────────────────────────────────────────────

  group('TaskService.syncRoutineTasks — happy path', () {
    test(
      'TODO: writes task docs using SetOptions(merge: true) — preserves existing state',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: emits task_scheduled for tasks within the 2-day lookahead window',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: does not emit task_scheduled for tasks outside the lookahead window',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: processes tasks in batches of ≤ 450 when list exceeds chunk size',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: returns early without Firestore writes when tasks list is empty',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── startTask ───────────────────────────────────────────────────────────────

  group('TaskService.startTask — happy path', () {
    test(
      'TODO: transitions scheduled → started and writes actualStart',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: emits task_started event with correct payload',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('TaskService.startTask — state-machine errors', () {
    test(
      'TODO: throws MultipleActiveTasksError when another task is already started',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: throws InvalidStateTransitionError when task is not in scheduled state',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: throws TaskNotFoundError when taskId does not exist',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── pauseTask ───────────────────────────────────────────────────────────────

  group('TaskService.pauseTask — happy path', () {
    test(
      'TODO: transitions started → paused and writes pausedAt',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: emits task_paused event',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('TaskService.pauseTask — state-machine errors', () {
    test(
      'TODO: throws InvalidStateTransitionError when task is not started',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── resumeTask ──────────────────────────────────────────────────────────────

  group('TaskService.resumeTask — happy path', () {
    test(
      'TODO: transitions paused → started and accumulates totalPauseDurationMin',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: clears pausedAt field on resume',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: emits task_resumed event',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('TaskService.resumeTask — state-machine errors', () {
    test(
      'TODO: throws InvalidStateTransitionError when task is not paused',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── completeTask ─────────────────────────────────────────────────────────────

  group('TaskService.completeTask — happy path', () {
    test(
      'TODO: transitions started → completed and writes actualEnd, actualDurationMin, driftPct',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: transitions paused → completed capturing open pause duration',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: emits task_completed event with full payload',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: driftPct is (actualDurationMin − plannedDurationMin) / plannedDurationMin * 100',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('TaskService.completeTask — state-machine errors', () {
    test(
      'TODO: throws InvalidStateTransitionError when task is already completed',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: throws InvalidStateTransitionError when task is scheduled (never started)',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── abandonTask ──────────────────────────────────────────────────────────────

  group('TaskService.abandonTask — happy path', () {
    test(
      'TODO: transitions started → abandoned and writes abandonedAt, actualDurationMin, driftPct',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: records reasonCategory and reasonTag when provided',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: emits task_abandoned event with full payload',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('TaskService.abandonTask — state-machine errors', () {
    test(
      'TODO: throws InvalidStateTransitionError when task is already completed',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: throws InvalidStateTransitionError when task is already abandoned',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── skipTask ─────────────────────────────────────────────────────────────────

  group('TaskService.skipTask — happy path', () {
    test(
      'TODO: transitions scheduled → abandoned with actualDurationMin == 0',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: driftPct == -100 when plannedDurationMin > 0',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: emits task_skipped event',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('TaskService.skipTask — state-machine errors', () {
    test(
      'TODO: throws TaskSkippedFromInvalidStateError when task is not scheduled',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── toggleSubtask ────────────────────────────────────────────────────────────

  group('TaskService.toggleSubtask — happy path', () {
    test(
      'TODO: flips subtask.checked from false → true and updates Firestore',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: flips subtask.checked from true → false',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: emits subtask_checked when checked becomes true',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: emits subtask_unchecked when checked becomes false',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: payload includes allSubtasksChecked: true when all siblings are checked',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('TaskService.toggleSubtask — error cases', () {
    test(
      'TODO: throws SubtaskToggleNotAllowedError when task is not started or paused',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: throws SubtaskNotFoundError when subtaskId does not exist on the task',
      () {},
      skip: 'Not yet implemented',
    );
  });
}
