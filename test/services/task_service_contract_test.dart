// test/services/task_service_contract_test.dart
//
// Contract tests for TaskService.
//
// State machine under test:
//   scheduled → started → paused/resumed → completed
//   scheduled → skipped
//   started/paused → abandoned
//   completed, skipped, abandoned are terminal.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:optivus2/core/constants/event_names.dart';
import 'package:optivus2/core/errors/app_errors.dart';
import 'package:optivus2/models/task_model.dart';
import 'package:optivus2/services/event_service.dart';
import 'package:optivus2/services/task_service.dart';

const _kUid = 'test_uid_123';

TaskModel _scheduledTask({
  String id = 'task_1',
  TaskType type = TaskType.fixed,
  DateTime? plannedStart,
  DateTime? plannedEnd,
  List<Subtask> subtasks = const [],
}) {
  final now = DateTime(2026, 5, 2, 10, 0);
  final start = plannedStart ?? now;
  final end = plannedEnd ?? now.add(const Duration(minutes: 30));
  return TaskModel(
    id: id,
    type: type,
    title: 'Test task',
    plannedStart: start,
    plannedEnd: end,
    subtasks: subtasks,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late EventService eventService;
  late TaskService service;

  CollectionReference<Map<String, dynamic>> tasksColl() =>
      firestore.collection('users').doc(_kUid).collection('tasks');
  CollectionReference<Map<String, dynamic>> outcomesColl() =>
      firestore.collection('users').doc(_kUid).collection('task_outcomes');
  CollectionReference<Map<String, dynamic>> eventsColl() =>
      firestore.collection('users').doc(_kUid).collection('events');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(mockUser: MockUser(uid: _kUid), signedIn: true);
    eventService = EventService(firestore: firestore, auth: auth);
    service = TaskService(
      eventService: eventService,
      firestore: firestore,
      auth: auth,
    );
  });

  tearDown(() => eventService.dispose());

  // ── createTask ──────────────────────────────────────────────────────────────

  group('TaskService.createTask', () {
    test('writes doc to /users/{uid}/tasks/{taskId}', () async {
      await service.createTask(_scheduledTask());

      final doc = await tasksColl().doc('task_1').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['taskId'], 'task_1');
      expect(doc.data()!['state'], 'scheduled');
    });

    test('emits exactly one task_scheduled event in the same batch', () async {
      await service.createTask(_scheduledTask());

      final events = await eventsColl().get();
      final scheduledEvents =
          events.docs.where((d) => d.data()['eventName'] == EventNames.taskScheduled);
      expect(scheduledEvents.length, 1);
      final payload = scheduledEvents.first.data()['payload'] as Map;
      expect(payload['taskId'], 'task_1');
      expect(payload['type'], 'fixed');
      expect(payload['plannedDurationMin'], 30);
    });

    test('throws InvalidTimeRangeError when plannedEnd ≤ plannedStart', () async {
      final t = DateTime(2026, 5, 2, 10);
      final task = _scheduledTask(plannedStart: t, plannedEnd: t);
      await expectLater(
        service.createTask(task),
        throwsA(isA<InvalidTimeRangeError>()),
      );
    });

    test('throws TaskTooLongError when plannedDurationMin > 480', () async {
      final start = DateTime(2026, 5, 2, 8);
      final end = start.add(const Duration(hours: 9));
      await expectLater(
        service.createTask(
            _scheduledTask(plannedStart: start, plannedEnd: end)),
        throwsA(isA<TaskTooLongError>()),
      );
    });

    test('throws NotAuthenticatedError when no user is signed in', () async {
      final unauth = MockFirebaseAuth(signedIn: false);
      final unauthService = TaskService(
        eventService: eventService,
        firestore: firestore,
        auth: unauth,
      );
      await expectLater(
        unauthService.createTask(_scheduledTask()),
        throwsA(isA<NotAuthenticatedError>()),
      );
    });
  });

  // ── watchTask / watchTasksForDay / watchTasksForWindow / watchActiveTask ────

  group('TaskService.watchTask', () {
    test('emits null when the doc does not exist', () async {
      expect(await service.watchTask('missing').first, isNull);
    });

    test('emits the task once it is written', () async {
      await service.createTask(_scheduledTask());
      final emitted = await service.watchTask('task_1').first;
      expect(emitted, isNotNull);
      expect(emitted!.id, 'task_1');
    });
  });

  group('TaskService.watchTasksForDay', () {
    test('returns only tasks whose plannedStart is on the given calendar day',
        () async {
      final day = DateTime(2026, 5, 2, 10);
      final other = DateTime(2026, 5, 3, 10);

      await service.createTask(_scheduledTask(id: 'today', plannedStart: day));
      await service.createTask(_scheduledTask(
          id: 'tomorrow',
          plannedStart: other,
          plannedEnd: other.add(const Duration(minutes: 30))));

      final tasks = await service.watchTasksForDay(day).first;
      expect(tasks.map((t) => t.id), contains('today'));
      expect(tasks.map((t) => t.id), isNot(contains('tomorrow')));
    });
  });

  group('TaskService.watchTasksForWindow', () {
    test('returns tasks across a [days]-day window starting at `from`',
        () async {
      final day = DateTime(2026, 5, 2, 10);
      await service.createTask(_scheduledTask(id: 'd0', plannedStart: day));
      await service.createTask(_scheduledTask(
        id: 'd5',
        plannedStart: day.add(const Duration(days: 5)),
        plannedEnd: day.add(const Duration(days: 5, minutes: 30)),
      ));
      await service.createTask(_scheduledTask(
        id: 'd14',
        plannedStart: day.add(const Duration(days: 14)),
        plannedEnd: day.add(const Duration(days: 14, minutes: 30)),
      ));

      final tasks = await service.watchTasksForWindow(day, days: 14).first;
      expect(tasks.map((t) => t.id).toList(), ['d0', 'd5']);
    });
  });

  group('TaskService.watchActiveTask', () {
    test('emits the started task; null when none is active', () async {
      await service.createTask(_scheduledTask(id: 'task_1'));

      // No started task initially.
      expect(await service.watchActiveTask().first, isNull);

      await service.startTask('task_1');
      final active = await service.watchActiveTask().first;
      expect(active, isNotNull);
      expect(active!.id, 'task_1');
      expect(active.state, TaskState.started);
    });
  });

  // ── State machine: start / pause / resume ──────────────────────────────────

  group('TaskService.startTask', () {
    test('transitions scheduled → started and writes actualStart', () async {
      await service.createTask(_scheduledTask());
      await service.startTask('task_1');

      final doc = await tasksColl().doc('task_1').get();
      expect(doc.data()!['state'], 'started');
      expect(doc.data()!['actualStart'], isA<Timestamp>());
    });

    test('emits task_started', () async {
      await service.createTask(_scheduledTask());
      await service.startTask('task_1');

      final events = await eventsColl()
          .where('eventName', isEqualTo: EventNames.taskStarted)
          .get();
      expect(events.docs.length, 1);
    });

    test('throws MultipleActiveTasksError when another task is started',
        () async {
      await service.createTask(_scheduledTask(id: 'a'));
      await service.createTask(_scheduledTask(id: 'b'));
      await service.startTask('a');

      await expectLater(
        service.startTask('b'),
        throwsA(isA<MultipleActiveTasksError>()),
      );
    });

    test('throws InvalidStateTransitionError when not in scheduled state',
        () async {
      await service.createTask(_scheduledTask());
      await service.startTask('task_1');

      await expectLater(
        service.startTask('task_1'),
        throwsA(isA<InvalidStateTransitionError>()),
      );
    });

    test('throws TaskNotFoundError when the taskId does not exist', () async {
      await expectLater(
        service.startTask('missing'),
        throwsA(isA<TaskNotFoundError>()),
      );
    });
  });

  group('TaskService.pauseTask / resumeTask', () {
    test('started → paused writes pausedAt and emits task_paused', () async {
      await service.createTask(_scheduledTask());
      await service.startTask('task_1');
      await service.pauseTask('task_1');

      final doc = await tasksColl().doc('task_1').get();
      expect(doc.data()!['state'], 'paused');
      expect(doc.data()!['pausedAt'], isA<Timestamp>());

      final events = await eventsColl()
          .where('eventName', isEqualTo: EventNames.taskPaused)
          .get();
      expect(events.docs.length, 1);
    });

    test('paused → started clears pausedAt and emits task_resumed', () async {
      await service.createTask(_scheduledTask());
      await service.startTask('task_1');
      await service.pauseTask('task_1');
      await service.resumeTask('task_1');

      final doc = await tasksColl().doc('task_1').get();
      expect(doc.data()!['state'], 'started');
      expect(doc.data()!.containsKey('pausedAt'), isFalse);

      final events = await eventsColl()
          .where('eventName', isEqualTo: EventNames.taskResumed)
          .get();
      expect(events.docs.length, 1);
    });

    test('pause throws when state is not started', () async {
      await service.createTask(_scheduledTask());
      await expectLater(
        service.pauseTask('task_1'),
        throwsA(isA<InvalidStateTransitionError>()),
      );
    });

    test('resume throws when state is not paused', () async {
      await service.createTask(_scheduledTask());
      await service.startTask('task_1');
      await expectLater(
        service.resumeTask('task_1'),
        throwsA(isA<InvalidStateTransitionError>()),
      );
    });
  });

  // ── completeTask ────────────────────────────────────────────────────────────

  group('TaskService.completeTask', () {
    test('started → completed writes actualEnd, duration, drift', () async {
      await service.createTask(_scheduledTask());
      await service.startTask('task_1');
      await service.completeTask('task_1');

      final doc = await tasksColl().doc('task_1').get();
      expect(doc.data()!['state'], 'completed');
      expect(doc.data()!['actualEnd'], isA<Timestamp>());
      expect(doc.data()!['actualDurationMin'], isA<int>());
      expect(doc.data()!['driftPct'], isA<num>());
    });

    test('writes a /task_outcomes/{taskId} document with outcome=completed',
        () async {
      await service.createTask(_scheduledTask());
      await service.startTask('task_1');
      await service.completeTask('task_1');

      final outcome = await outcomesColl().doc('task_1').get();
      expect(outcome.exists, isTrue);
      expect(outcome.data()!['outcome'], 'completed');
      expect(outcome.data()!['plannedDurationMin'], 30);
      expect(outcome.data()!['weekday'], isA<String>());
      expect(outcome.data()!['timeOfDayBucket'], isA<String>());
    });

    test('emits task_completed', () async {
      await service.createTask(_scheduledTask());
      await service.startTask('task_1');
      await service.completeTask('task_1');

      final events = await eventsColl()
          .where('eventName', isEqualTo: EventNames.taskCompleted)
          .get();
      expect(events.docs.length, 1);
    });

    test('throws when called from scheduled (never started)', () async {
      await service.createTask(_scheduledTask());
      await expectLater(
        service.completeTask('task_1'),
        throwsA(isA<InvalidStateTransitionError>()),
      );
    });

    test('throws when called on an already-completed task', () async {
      await service.createTask(_scheduledTask());
      await service.startTask('task_1');
      await service.completeTask('task_1');

      await expectLater(
        service.completeTask('task_1'),
        throwsA(isA<InvalidStateTransitionError>()),
      );
    });
  });

  // ── abandonTask ─────────────────────────────────────────────────────────────

  group('TaskService.abandonTask', () {
    test('started → abandoned writes abandonedAt and reasonCategory', () async {
      await service.createTask(_scheduledTask());
      await service.startTask('task_1');
      await service.abandonTask(
        'task_1',
        reason: AbandonReason.autoIdle,
        reasonTag: 'phone_distraction',
      );

      final doc = await tasksColl().doc('task_1').get();
      expect(doc.data()!['state'], 'abandoned');
      expect(doc.data()!['abandonedAt'], isA<Timestamp>());
      expect(doc.data()!['reasonCategory'], 'auto_idle');
      expect(doc.data()!['reasonTag'], 'phone_distraction');
    });

    test('writes a /task_outcomes/{taskId} document with outcome=abandoned',
        () async {
      await service.createTask(_scheduledTask());
      await service.startTask('task_1');
      await service.abandonTask('task_1', reason: AbandonReason.userSkipped);

      final outcome = await outcomesColl().doc('task_1').get();
      expect(outcome.exists, isTrue);
      expect(outcome.data()!['outcome'], 'abandoned');
    });

    test('emits task_abandoned', () async {
      await service.createTask(_scheduledTask());
      await service.startTask('task_1');
      await service.abandonTask('task_1');

      final events = await eventsColl()
          .where('eventName', isEqualTo: EventNames.taskAbandoned)
          .get();
      expect(events.docs.length, 1);
    });

    test('throws when called from scheduled state (must use skipTask)',
        () async {
      await service.createTask(_scheduledTask());
      await expectLater(
        service.abandonTask('task_1'),
        throwsA(isA<InvalidStateTransitionError>()),
      );
    });

    test('throws when called on a completed task', () async {
      await service.createTask(_scheduledTask());
      await service.startTask('task_1');
      await service.completeTask('task_1');

      await expectLater(
        service.abandonTask('task_1'),
        throwsA(isA<InvalidStateTransitionError>()),
      );
    });
  });

  // ── skipTask ────────────────────────────────────────────────────────────────

  group('TaskService.skipTask', () {
    test('scheduled → skipped (terminal); actualDurationMin=0, driftPct=-100',
        () async {
      await service.createTask(_scheduledTask());
      await service.skipTask('task_1');

      final doc = await tasksColl().doc('task_1').get();
      expect(doc.data()!['state'], 'skipped');
      expect(doc.data()!['skippedAt'], isA<Timestamp>());
      expect(doc.data()!['actualDurationMin'], 0);
      expect(doc.data()!['driftPct'], -100.0);
    });

    test('writes a /task_outcomes/{taskId} document with outcome=skipped',
        () async {
      await service.createTask(_scheduledTask());
      await service.skipTask('task_1');

      final outcome = await outcomesColl().doc('task_1').get();
      expect(outcome.exists, isTrue);
      expect(outcome.data()!['outcome'], 'skipped');
    });

    test('emits task_skipped', () async {
      await service.createTask(_scheduledTask());
      await service.skipTask('task_1');

      final events = await eventsColl()
          .where('eventName', isEqualTo: EventNames.taskSkipped)
          .get();
      expect(events.docs.length, 1);
    });

    test('throws TaskSkippedFromInvalidStateError when not scheduled',
        () async {
      await service.createTask(_scheduledTask());
      await service.startTask('task_1');

      await expectLater(
        service.skipTask('task_1'),
        throwsA(isA<TaskSkippedFromInvalidStateError>()),
      );
    });
  });

  // ── deleteTask ──────────────────────────────────────────────────────────────

  group('TaskService.deleteTask', () {
    test('removes the task doc and emits task_deleted', () async {
      await service.createTask(_scheduledTask());
      await service.deleteTask('task_1');

      final doc = await tasksColl().doc('task_1').get();
      expect(doc.exists, isFalse);

      final events = await eventsColl()
          .where('eventName', isEqualTo: EventNames.taskDeleted)
          .get();
      expect(events.docs.length, 1);
      expect(events.docs.first.data()['payload']['taskId'], 'task_1');
    });

    test('throws TaskNotFoundError on a missing task', () async {
      await expectLater(
        service.deleteTask('missing'),
        throwsA(isA<TaskNotFoundError>()),
      );
    });
  });

  // ── checkSubtask / uncheckSubtask ───────────────────────────────────────────

  group('TaskService.checkSubtask', () {
    test('flips a subtask to checked and emits subtask_checked', () async {
      await service.createTask(_scheduledTask(
        subtasks: const [Subtask(id: 'a', title: 'A')],
      ));
      await service.startTask('task_1');
      await service.checkSubtask('task_1', 'a');

      final doc = await tasksColl().doc('task_1').get();
      final stored = (doc.data()!['subtasks'] as List).first as Map;
      expect(stored['checked'], isTrue);

      final events = await eventsColl()
          .where('eventName', isEqualTo: EventNames.subtaskChecked)
          .get();
      expect(events.docs.length, 1);
      expect(events.docs.first.data()['payload']['allSubtasksChecked'], isTrue);
    });

    test('is idempotent — second check is a no-op (no event emitted)',
        () async {
      await service.createTask(_scheduledTask(
        subtasks: const [Subtask(id: 'a', title: 'A', checked: true)],
      ));
      await service.startTask('task_1');
      await service.checkSubtask('task_1', 'a');

      final events = await eventsColl()
          .where('eventName', isEqualTo: EventNames.subtaskChecked)
          .get();
      expect(events.docs.length, 0);
    });

    test('throws SubtaskToggleNotAllowedError when task is not started/paused',
        () async {
      await service.createTask(_scheduledTask(
        subtasks: const [Subtask(id: 'a', title: 'A')],
      ));
      await expectLater(
        service.checkSubtask('task_1', 'a'),
        throwsA(isA<SubtaskToggleNotAllowedError>()),
      );
    });

    test('throws SubtaskNotFoundError for an unknown subtaskId', () async {
      await service.createTask(_scheduledTask(
        subtasks: const [Subtask(id: 'a', title: 'A')],
      ));
      await service.startTask('task_1');
      await expectLater(
        service.checkSubtask('task_1', 'missing'),
        throwsA(isA<SubtaskNotFoundError>()),
      );
    });
  });

  group('TaskService.uncheckSubtask', () {
    test('flips a subtask to unchecked and emits subtask_unchecked', () async {
      await service.createTask(_scheduledTask(
        subtasks: const [Subtask(id: 'a', title: 'A', checked: true)],
      ));
      await service.startTask('task_1');
      await service.uncheckSubtask('task_1', 'a');

      final events = await eventsColl()
          .where('eventName', isEqualTo: EventNames.subtaskUnchecked)
          .get();
      expect(events.docs.length, 1);
    });
  });

  // ── syncRoutineTasks ────────────────────────────────────────────────────────

  group('TaskService.syncRoutineTasks', () {
    test('returns early when given an empty list (no Firestore writes)',
        () async {
      await service.syncRoutineTasks(const []);
      final docs = await tasksColl().get();
      expect(docs.docs, isEmpty);
    });

    test('merges and never clobbers an in-progress task state', () async {
      await service.createTask(_scheduledTask());
      await service.startTask('task_1');

      // Simulate routine sync with the same id but updated title.
      final updated = TaskModel(
        id: 'task_1',
        type: TaskType.fixed,
        title: 'Updated title',
        plannedStart: DateTime(2026, 5, 2, 10),
        plannedEnd: DateTime(2026, 5, 2, 10, 30),
        createdAt: DateTime(2026, 5, 2),
        updatedAt: DateTime(2026, 5, 2),
      );
      await service.syncRoutineTasks([updated]);

      final doc = await tasksColl().doc('task_1').get();
      // State must be preserved.
      expect(doc.data()!['state'], 'started');
      // But the title is updated.
      expect(doc.data()!['title'], 'Updated title');
    });
  });
}
