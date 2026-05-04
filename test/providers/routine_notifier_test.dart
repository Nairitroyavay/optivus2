// test/providers/routine_notifier_test.dart
//
// Unit tests for RoutineNotifier.materializeForDate and materializeForWindow.
//
// All I/O is done through FakeFirebaseFirestore + MockFirebaseAuth so no real
// Firebase project is required.  SharedPreferences is stubbed via
// SharedPreferences.setMockInitialValues({}).
//
// Firestore paths exercised:
//   /users/{uid}/tasks/{taskId}          — routine task documents
//   /users/{uid}/events/{eventId}        — task_scheduled events
//
// See also: lib/providers/routine_provider.dart for the production logic.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:optivus2/providers/routine_provider.dart';
import 'package:optivus2/repositories/routine_repository.dart';
import 'package:optivus2/services/event_service.dart';
import 'package:optivus2/services/firestore_service.dart';
import 'package:optivus2/services/task_service.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

FixedScheduleTemplate _tpl({
  String id = 'tpl1',
  String title = 'Work',
  String start = '09:00',
  String end = '10:00',
  String repeat = 'daily',
}) {
  final now = DateTime.now().toIso8601String();
  return FixedScheduleTemplate(
    templateId: id,
    title: title,
    startTime: start,
    endTime: end,
    repeatRule: repeat,
    createdAt: now,
    updatedAt: now,
  );
}

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

// ── Test harness ─────────────────────────────────────────────────────────────

class _Harness {
  final FakeFirebaseFirestore fakeFirestore;
  final MockFirebaseAuth fakeAuth;
  final RoutineNotifier notifier;

  static const _uid = 'test_user';

  _Harness._({
    required this.fakeFirestore,
    required this.fakeAuth,
    required this.notifier,
  });

  static Future<_Harness> create() async {
    SharedPreferences.setMockInitialValues({});

    final fakeFirestore = FakeFirebaseFirestore();
    final fakeAuth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: _uid, email: 'tester@test.com'),
    );

    final eventService = EventService(
      firestore: fakeFirestore,
      auth: fakeAuth,
    );
    final taskService = TaskService(
      eventService: eventService,
      firestore: fakeFirestore,
      auth: fakeAuth,
    );
    final firestoreService = FirestoreService(
      db: fakeFirestore,
      auth: fakeAuth,
    );
    final repo = RoutineRepository(firestoreService);
    final notifier = RoutineNotifier(repo, taskService, eventService);

    // Drain the microtask queue so _loadRoutine() completes before any test
    // method calls setFixedScheduleTemplates (which would otherwise be overwritten
    // by the async state reset in _loadRoutine).
    await pumpEventQueue(times: 20);

    return _Harness._(
      fakeFirestore: fakeFirestore,
      fakeAuth: fakeAuth,
      notifier: notifier,
    );
  }

  // ── Firestore read helpers ────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _tasks =>
      fakeFirestore.collection('users').doc(_uid).collection('tasks');

  CollectionReference<Map<String, dynamic>> get _events =>
      fakeFirestore.collection('users').doc(_uid).collection('events');

  /// Tasks whose plannedStart falls within [date]'s calendar day (local time).
  Future<List<Map<String, dynamic>>> tasksForDate(DateTime date) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final snap = await _tasks
        .where(
          'plannedStart',
          isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart),
        )
        .where('plannedStart', isLessThan: Timestamp.fromDate(dayEnd))
        .get();
    return snap.docs.map((d) => {'__id': d.id, ...d.data()}).toList();
  }

  Future<Map<String, dynamic>?> taskById(String id) async {
    final doc = await _tasks.doc(id).get();
    if (!doc.exists) return null;
    return {'__id': doc.id, ...doc.data()!};
  }

  Future<int> eventCount() async => (await _events.get()).docs.length;

  void dispose() => notifier.dispose();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── 1. Idempotency ──────────────────────────────────────────────────────────

  group('materializeForDate — idempotency', () {
    test('same template + same date materialises exactly one task', () async {
      final h = await _Harness.create();
      h.notifier.setFixedScheduleTemplates([_tpl()]);

      final date = DateTime(2025, 6, 10);
      await h.notifier.materializeForDate(date);
      await h.notifier.materializeForDate(date);

      expect(await h.tasksForDate(date), hasLength(1));
      h.dispose();
    });

    test('task_scheduled event is emitted only once across two calls', () async {
      final h = await _Harness.create();
      h.notifier.setFixedScheduleTemplates([_tpl()]);

      final date = DateTime(2025, 6, 10);
      await h.notifier.materializeForDate(date);
      final countAfterFirst = await h.eventCount();

      await h.notifier.materializeForDate(date);
      expect(await h.eventCount(), equals(countAfterFirst));
      h.dispose();
    });
  });

  // ── 2. Manual edit preservation ─────────────────────────────────────────────

  group('materializeForDate — manual edit preservation', () {
    test('re-materialising does not overwrite manually reordered subtasks',
        () async {
      final h = await _Harness.create();
      h.notifier.setFixedScheduleTemplates([_tpl()]);

      final date = DateTime(2025, 6, 10);
      await h.notifier.materializeForDate(date);

      final tasks = await h.tasksForDate(date);
      expect(tasks, hasLength(1));
      final taskId = tasks.first['__id'] as String;

      // User manually sets a custom subtask list.
      final manualSubtasks = [
        {'id': 'custom', 'title': 'My custom step', 'checked': false},
      ];
      await h._tasks.doc(taskId).update({'subtasks': manualSubtasks});

      // Template changes and re-materialises — must NOT overwrite user edit.
      h.notifier
          .setFixedScheduleTemplates([_tpl(title: 'Work (updated title)')]);
      await h.notifier.materializeForDate(date);

      final after = (await h.taskById(taskId))!;
      final subtasks = after['subtasks'] as List;
      expect(subtasks, hasLength(1));
      expect(subtasks[0]['title'], equals('My custom step'));
      h.dispose();
    });

    test('re-materialising does not overwrite manually adjusted planned time',
        () async {
      final h = await _Harness.create();
      h.notifier.setFixedScheduleTemplates([_tpl(start: '09:00', end: '10:00')]);

      final date = DateTime(2025, 6, 10);
      await h.notifier.materializeForDate(date);

      final tasks = await h.tasksForDate(date);
      final taskId = tasks.first['__id'] as String;

      // User reschedules to 11:00.
      final movedStart = Timestamp.fromDate(DateTime(2025, 6, 10, 11, 0));
      await h._tasks.doc(taskId).update({'plannedStart': movedStart});

      // Re-materialise — template still says 09:00, user edit must survive.
      await h.notifier.materializeForDate(date);

      final after = (await h.taskById(taskId))!;
      final storedStart = (after['plannedStart'] as Timestamp).toDate();
      expect(storedStart.hour, equals(11),
          reason: 'plannedStart should stay at the user-edited 11:00');
      h.dispose();
    });
  });

  // ── 3. Terminal-state (history) preservation ─────────────────────────────────

  group('materializeForDate — terminal state preservation', () {
    for (final terminal in ['completed', 'skipped', 'abandoned']) {
      test('task in "$terminal" state is not touched when template changes',
          () async {
        final h = await _Harness.create();
        h.notifier.setFixedScheduleTemplates([_tpl(title: 'Original title')]);

        final date = DateTime(2025, 1, 15);
        await h.notifier.materializeForDate(date);

        final tasks = await h.tasksForDate(date);
        expect(tasks, hasLength(1));
        final taskId = tasks.first['__id'] as String;

        // Mark the task as terminal.
        await h._tasks.doc(taskId).update({'state': terminal});

        // Change template and re-materialise.
        h.notifier
            .setFixedScheduleTemplates([_tpl(title: 'Changed title')]);
        await h.notifier.materializeForDate(date);

        final after = (await h.taskById(taskId))!;
        // Title must be the original — terminal tasks are never modified.
        expect(after['title'], equals('Original title'));
        h.dispose();
      });
    }
  });

  // ── 4. DST boundary — no duplicates, no gaps ─────────────────────────────────
  //
  // Real DST offsets are system-timezone-dependent and cannot be simulated in
  // a Dart unit test.  These tests verify the structural invariant that
  // materializeForDate produces exactly one task per (template, calendar date)
  // regardless of the date chosen, and that a contiguous window has no gaps.

  group('materializeForWindow — DST boundary', () {
    test(
        'date that crosses a potential DST boundary (2025-03-09) produces '
        'exactly one task', () async {
      final h = await _Harness.create();
      h.notifier.setFixedScheduleTemplates([_tpl()]);

      final dstDate = DateTime(2025, 3, 9);
      await h.notifier.materializeForDate(dstDate);

      expect(await h.tasksForDate(dstDate), hasLength(1));
      h.dispose();
    });

    test(
        '14-day window spanning a potential DST boundary contains '
        'exactly one task per day — no gaps, no duplicates', () async {
      final h = await _Harness.create();
      h.notifier.setFixedScheduleTemplates([_tpl()]);

      // Window starts a few days before the US spring-forward date.
      final from = DateTime(2025, 3, 7);
      await h.notifier.materializeForWindow(from, days: 14);

      for (int i = 0; i < 14; i++) {
        final raw = from.add(Duration(days: i));
        // Normalise to midnight so the range query is unambiguous regardless
        // of any wall-clock drift caused by DST on the test machine.
        final day = DateTime(raw.year, raw.month, raw.day);
        final tasks = await h.tasksForDate(day);
        expect(
          tasks,
          hasLength(1),
          reason: 'Expected exactly 1 task for ${_dateKey(day)} '
              '(i=$i), got ${tasks.length}',
        );
      }
      h.dispose();
    });
  });

  // ── 5. Timezone change mapping ────────────────────────────────────────────────
  //
  // Verifies that materializeForDate produces a deterministic, unique task ID
  // keyed on the wall-clock calendar date.  When the local timezone changes
  // (e.g. Asia/Kolkata → UTC), the calendar date used for the ID derives from
  // the DateTime passed in, so tasks materialised for the same wall-clock date
  // map to the same bucket.

  group('materializeForDate — timezone mapping', () {
    test('task ID is deterministic and keyed on the calendar date', () async {
      final h = await _Harness.create();
      h.notifier.setFixedScheduleTemplates([_tpl(id: 'gym')]);

      final date = DateTime(2025, 8, 15);
      await h.notifier.materializeForDate(date);

      // The ID format: routine_YYYY-MM-DD_fixed_schedule_<templateId>
      const expectedId = 'routine_2025-08-15_fixed_schedule_gym';
      final task = await h.taskById(expectedId);
      expect(task, isNotNull,
          reason: 'Task should exist under the deterministic ID $expectedId');
      h.dispose();
    });

    test('consecutive calendar dates produce non-overlapping task IDs',
        () async {
      final h = await _Harness.create();
      h.notifier.setFixedScheduleTemplates([_tpl(id: 'gym')]);

      await h.notifier.materializeForDate(DateTime(2025, 8, 15));
      await h.notifier.materializeForDate(DateTime(2025, 8, 16));

      const id1 = 'routine_2025-08-15_fixed_schedule_gym';
      const id2 = 'routine_2025-08-16_fixed_schedule_gym';

      expect(await h.taskById(id1), isNotNull);
      expect(await h.taskById(id2), isNotNull);
      expect(id1, isNot(equals(id2)));
      h.dispose();
    });
  });

  // ── 6. 14-day rolling window boundary ────────────────────────────────────────

  group('materializeForWindow — 14-day rolling window', () {
    test('generates tasks for all 14 days (none skipped)', () async {
      final h = await _Harness.create();
      h.notifier.setFixedScheduleTemplates([_tpl()]);

      final from = DateTime(2025, 6, 1);
      await h.notifier.materializeForWindow(from, days: 14);

      for (int i = 0; i < 14; i++) {
        final day = DateTime(2025, 6, 1 + i);
        final tasks = await h.tasksForDate(day);
        expect(
          tasks,
          hasLength(1),
          reason: 'Day ${i + 1} (${_dateKey(day)}) should have 1 task',
        );
      }
      h.dispose();
    });

    test('does not generate tasks beyond the 14-day boundary', () async {
      final h = await _Harness.create();
      h.notifier.setFixedScheduleTemplates([_tpl()]);

      final from = DateTime(2025, 6, 1);
      await h.notifier.materializeForWindow(from, days: 14);

      // Day 15 (index 14) must be empty.
      final day15 = DateTime(2025, 6, 15);
      expect(await h.tasksForDate(day15), isEmpty,
          reason: 'No task should exist for day 15 (${_dateKey(day15)})');
      h.dispose();
    });
  });
}
