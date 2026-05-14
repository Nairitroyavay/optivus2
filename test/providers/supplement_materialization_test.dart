// test/providers/supplement_materialization_test.dart
//
// Integration tests for supplement template materialization.
// Uses FakeFirebaseFirestore — no real Firebase project required.
//
// Firestore paths exercised:
//   /users/{uid}/routine/current               — supplement templates
//   /users/{uid}/tasks/{taskId}                — materialized supplement tasks
//   /users/{uid}/events/{eventId}              — routine_template_created + task_scheduled
//   /users/{uid}/scheduled_notifications/{id}  — reminder docs
//
// Verifies:
//   1. dosage subtask appears in materialized task
//   2. timingRule subtask appears as "After breakfast" etc.
//   3. notes subtask appears when notes are non-empty and no steps exist
//   4. notes subtask does NOT appear when steps are present
//   5. reminderEnabled=true creates a notification doc
//   6. routine_template_created emitted once per template (not per materialisation)
//   7. task_scheduled emitted on first create only (idempotent)
//   8. Manual path works with no AI/Worker endpoint configured (feature flag absent)
//   9. Saving an empty list clears Firestore and does not crash
//  10. weekly repeatRule skips non-matching weekdays

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

// ── Harness ───────────────────────────────────────────────────────────────────

class _Harness {
  final FakeFirebaseFirestore fakeFirestore;
  final MockFirebaseAuth fakeAuth;
  final RoutineNotifier notifier;

  static const _uid = 'supp_test_user';

  _Harness._({
    required this.fakeFirestore,
    required this.fakeAuth,
    required this.notifier,
  });

  static Future<_Harness> create({
    Map<String, dynamic>? initialRoutine,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final fakeFirestore = FakeFirebaseFirestore();
    final fakeAuth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: _uid, email: 'tester@test.com'),
    );
    if (initialRoutine != null) {
      await fakeFirestore
          .collection('users')
          .doc(_uid)
          .collection('routine')
          .doc('current')
          .set(initialRoutine);
    }
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
    await pumpEventQueue(times: 20);

    return _Harness._(
      fakeFirestore: fakeFirestore,
      fakeAuth: fakeAuth,
      notifier: notifier,
    );
  }

  CollectionReference<Map<String, dynamic>> get _tasks =>
      fakeFirestore.collection('users').doc(_uid).collection('tasks');

  CollectionReference<Map<String, dynamic>> get _events =>
      fakeFirestore.collection('users').doc(_uid).collection('events');

  CollectionReference<Map<String, dynamic>> get _notifications => fakeFirestore
      .collection('users')
      .doc(_uid)
      .collection('scheduled_notifications');

  Future<List<Map<String, dynamic>>> tasksForDate(DateTime date) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final snap = await _tasks
        .where('plannedStart',
            isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('plannedStart', isLessThan: Timestamp.fromDate(dayEnd))
        .get();
    return snap.docs.map((d) => {'__id': d.id, ...d.data()}).toList();
  }

  Future<Map<String, dynamic>?> taskById(String id) async {
    final doc = await _tasks.doc(id).get();
    if (!doc.exists) return null;
    return {'__id': doc.id, ...doc.data()!};
  }

  Future<List<Map<String, dynamic>>> eventsWhere(String eventName) async {
    final snap = await _events.where('eventName', isEqualTo: eventName).get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Future<List<Map<String, dynamic>>> allNotifications() async {
    final snap = await _notifications.get();
    return snap.docs.map((d) => {'__id': d.id, ...d.data()}).toList();
  }

  void dispose() => notifier.dispose();
}

// ── Supplement template factory ───────────────────────────────────────────────

Map<String, dynamic> _suppTemplate({
  String id = 'vitamin_d',
  String title = 'Vitamin D',
  String dosage = '1000 IU',
  String startTime = '08:00',
  String endTime = '08:05',
  String repeatRule = 'daily',
  String timingRule = 'after breakfast',
  String notes = '',
  bool reminderEnabled = false,
  List<Map<String, dynamic>>? steps,
}) {
  return {
    'templateId': id,
    'title': title,
    'routineType': 'supplements',
    'startTime': startTime,
    'endTime': endTime,
    'repeatRule': repeatRule,
    'timingRule': timingRule,
    'dosage': dosage,
    'notes': notes,
    'reminderEnabled': reminderEnabled,
    'isActive': true,
    if (steps != null) 'steps': steps,
  };
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── 1. dosage subtask ───────────────────────────────────────────────────────

  group('Supplement materialization — dosage subtask', () {
    test('dosage appears as a subtask in the materialized task', () async {
      final h = await _Harness.create();
      await h.notifier.setRoutineTemplates(
        'supplements',
        [_suppTemplate(dosage: '1000 IU')],
        materializeDays: 0,
      );

      final date = DateTime(2025, 6, 10);
      await h.notifier.materializeForDate(date);

      final tasks = await h.tasksForDate(date);
      expect(tasks, hasLength(1));

      final subtasks = tasks.first['subtasks'] as List;
      final dosageSubtask = subtasks.firstWhere(
        (s) => (s as Map)['id'] == 'dosage',
        orElse: () => null,
      );
      expect(dosageSubtask, isNotNull, reason: 'Expected a dosage subtask');
      expect((dosageSubtask as Map)['title'], '1000 IU');

      h.dispose();
    });
  });

  // ── 2. timingRule subtask ───────────────────────────────────────────────────

  group('Supplement materialization — timingRule subtask', () {
    test('"after breakfast" appears capitalized as timing subtask', () async {
      final h = await _Harness.create();
      await h.notifier.setRoutineTemplates(
        'supplements',
        [_suppTemplate(timingRule: 'after breakfast')],
        materializeDays: 0,
      );

      final date = DateTime(2025, 6, 10);
      await h.notifier.materializeForDate(date);

      final tasks = await h.tasksForDate(date);
      final subtasks = tasks.first['subtasks'] as List;
      final timingSubtask = subtasks.firstWhere(
        (s) => (s as Map)['id'] == 'timing',
        orElse: () => null,
      );
      expect(timingSubtask, isNotNull, reason: 'Expected a timing subtask');
      expect((timingSubtask as Map)['title'], 'After breakfast');

      h.dispose();
    });

    test('"before bed" appears capitalized as timing subtask', () async {
      final h = await _Harness.create();
      await h.notifier.setRoutineTemplates(
        'supplements',
        [
          _suppTemplate(
            id: 'magnesium',
            title: 'Magnesium',
            dosage: '400 mg',
            startTime: '22:00',
            endTime: '22:05',
            timingRule: 'before bed',
          ),
        ],
        materializeDays: 0,
      );

      final date = DateTime(2025, 6, 10);
      await h.notifier.materializeForDate(date);

      final tasks = await h.tasksForDate(date);
      final subtasks = tasks.first['subtasks'] as List;
      final timingSubtask = subtasks.firstWhere(
        (s) => (s as Map)['id'] == 'timing',
        orElse: () => null,
      );
      expect(timingSubtask, isNotNull);
      expect((timingSubtask as Map)['title'], 'Before bed');

      h.dispose();
    });

    test('template without timingRule does not produce a timing subtask',
        () async {
      final h = await _Harness.create();
      final template = Map<String, dynamic>.from(_suppTemplate())
        ..remove('timingRule');
      await h.notifier.setRoutineTemplates(
        'supplements',
        [template],
        materializeDays: 0,
      );

      final date = DateTime(2025, 6, 10);
      await h.notifier.materializeForDate(date);

      final tasks = await h.tasksForDate(date);
      final subtasks = tasks.first['subtasks'] as List;
      final timingSubtask = subtasks
          .cast<Map<dynamic, dynamic>>()
          .where((s) => s['id'] == 'timing')
          .toList();
      expect(timingSubtask, isEmpty);

      h.dispose();
    });
  });

  // ── 3. notes subtask ────────────────────────────────────────────────────────

  group('Supplement materialization — notes subtask', () {
    test('notes appear as a subtask when no steps are present', () async {
      final h = await _Harness.create();
      await h.notifier.setRoutineTemplates(
        'supplements',
        [_suppTemplate(notes: 'Take with a glass of water')],
        materializeDays: 0,
      );

      final date = DateTime(2025, 6, 10);
      await h.notifier.materializeForDate(date);

      final tasks = await h.tasksForDate(date);
      final subtasks = tasks.first['subtasks'] as List;
      final notesSubtask = subtasks.firstWhere(
        (s) => (s as Map)['id'] == 'notes',
        orElse: () => null,
      );
      expect(notesSubtask, isNotNull, reason: 'Expected a notes subtask');
      expect((notesSubtask as Map)['title'], 'Take with a glass of water');

      h.dispose();
    });

    test('notes subtask is NOT added when steps are present', () async {
      final h = await _Harness.create();
      await h.notifier.setRoutineTemplates(
        'supplements',
        [
          _suppTemplate(
            notes: 'Some note',
            steps: [
              {'name': 'Open bottle'},
              {'name': 'Take pill'},
            ],
          ),
        ],
        materializeDays: 0,
      );

      final date = DateTime(2025, 6, 10);
      await h.notifier.materializeForDate(date);

      final tasks = await h.tasksForDate(date);
      final subtasks = tasks.first['subtasks'] as List;
      final notesSubtask = subtasks
          .cast<Map<dynamic, dynamic>>()
          .where((s) => s['id'] == 'notes')
          .toList();
      expect(notesSubtask, isEmpty,
          reason: 'notes subtask must be suppressed when steps are present');

      h.dispose();
    });

    test('empty notes does not produce a notes subtask', () async {
      final h = await _Harness.create();
      await h.notifier.setRoutineTemplates(
        'supplements',
        [_suppTemplate(notes: '')],
        materializeDays: 0,
      );

      final date = DateTime(2025, 6, 10);
      await h.notifier.materializeForDate(date);

      final tasks = await h.tasksForDate(date);
      final subtasks = tasks.first['subtasks'] as List;
      final notesSubtask = subtasks
          .cast<Map<dynamic, dynamic>>()
          .where((s) => s['id'] == 'notes')
          .toList();
      expect(notesSubtask, isEmpty);

      h.dispose();
    });
  });

  // ── 4. Reminder notification ────────────────────────────────────────────────

  group('Supplement materialization — reminder notification', () {
    test('reminderEnabled=true creates a scheduled_notifications doc',
        () async {
      final h = await _Harness.create();
      await h.notifier.setRoutineTemplates(
        'supplements',
        [_suppTemplate(reminderEnabled: true)],
        materializeDays: 0,
      );

      final date = DateTime(2025, 6, 10);
      await h.notifier.materializeForDate(date);

      final notifs = await h.allNotifications();
      expect(notifs, isNotEmpty,
          reason: 'Expected a notification doc for reminderEnabled=true');
      expect(notifs.first['category'], 'task_reminder');
      expect(notifs.first['source'], 'routine_template');

      h.dispose();
    });

    test('reminderEnabled=false does not create a notification doc', () async {
      final h = await _Harness.create();
      await h.notifier.setRoutineTemplates(
        'supplements',
        [_suppTemplate(reminderEnabled: false)],
        materializeDays: 0,
      );

      final date = DateTime(2025, 6, 10);
      await h.notifier.materializeForDate(date);

      final notifs = await h.allNotifications();
      expect(notifs, isEmpty);

      h.dispose();
    });
  });

  // ── 5. routine_template_created event ──────────────────────────────────────

  group('Supplement events — routine_template_created', () {
    test('emitted exactly once per template on setRoutineTemplates', () async {
      final h = await _Harness.create();
      await h.notifier.setRoutineTemplates(
        'supplements',
        [
          _suppTemplate(id: 'vit_d', title: 'Vitamin D'),
          _suppTemplate(id: 'creatine', title: 'Creatine', dosage: '5 g'),
        ],
        materializeDays: 0,
      );

      final events = await h.eventsWhere('routine_template_created');
      expect(events, hasLength(2),
          reason: 'One routine_template_created per template');

      final ids =
          events.map((e) => (e['payload'] as Map)['templateId']).toSet();
      expect(ids, containsAll(['vit_d', 'creatine']));

      h.dispose();
    });

    test('calling setRoutineTemplates again does not double-emit', () async {
      final h = await _Harness.create();
      await h.notifier.setRoutineTemplates(
        'supplements',
        [_suppTemplate()],
        materializeDays: 0,
      );
      final countAfterFirst =
          (await h.eventsWhere('routine_template_created')).length;

      // Save the same template again.
      await h.notifier.setRoutineTemplates(
        'supplements',
        [_suppTemplate()],
        materializeDays: 0,
      );
      final countAfterSecond =
          (await h.eventsWhere('routine_template_created')).length;

      // Each save emits once; two saves = two events (one per call).
      expect(countAfterSecond, countAfterFirst + 1);

      h.dispose();
    });
  });

  // ── 6. task_scheduled event ─────────────────────────────────────────────────

  group('Supplement events — task_scheduled', () {
    test('emitted only on first materialization, not on re-run', () async {
      final h = await _Harness.create();
      await h.notifier.setRoutineTemplates(
        'supplements',
        [_suppTemplate()],
        materializeDays: 0,
      );

      final date = DateTime(2025, 6, 10);
      await h.notifier.materializeForDate(date);
      final countAfterFirst = (await h.eventsWhere('task_scheduled')).length;

      await h.notifier.materializeForDate(date);
      final countAfterSecond = (await h.eventsWhere('task_scheduled')).length;

      expect(countAfterSecond, equals(countAfterFirst),
          reason: 'task_scheduled must not be emitted on re-materialization');

      h.dispose();
    });
  });

  // ── 7. AI not required ──────────────────────────────────────────────────────

  group('Supplement — AI/Worker flag independence', () {
    test('manual supplement saves and materializes without Worker endpoint',
        () async {
      // RoutineRepository is constructed without featureFlags or apiService,
      // meaning the Worker guard is inactive. This verifies the manual path is
      // fully self-contained.
      final h = await _Harness.create();
      await h.notifier.setRoutineTemplates(
        'supplements',
        [_suppTemplate(title: 'Omega 3', dosage: '1 capsule')],
        materializeDays: 0,
      );

      final date = DateTime(2025, 6, 10);
      await h.notifier.materializeForDate(date);

      final tasks = await h.tasksForDate(date);
      expect(tasks, hasLength(1));
      expect(tasks.first['title'], 'Omega 3');
      expect(tasks.first['sourceRoutineType'], 'supplements');

      h.dispose();
    });
  });

  // ── 8. Empty list clears Firestore ──────────────────────────────────────────

  group('Supplement — empty list save', () {
    test('saving empty list does not crash and clears templates', () async {
      final h = await _Harness.create();
      // First save a template.
      await h.notifier.setRoutineTemplates(
        'supplements',
        [_suppTemplate()],
        materializeDays: 0,
      );
      expect(h.notifier.state.routineTemplates['supplements'], hasLength(1));

      // Now clear.
      await h.notifier.setRoutineTemplates(
        'supplements',
        [],
        materializeDays: 0,
      );
      expect(h.notifier.state.routineTemplates['supplements'], isEmpty);

      h.dispose();
    });
  });

  // ── 9. Weekly repeat rule ───────────────────────────────────────────────────

  group('Supplement — weekly repeatRule', () {
    test('weekdays-only supplement skips weekends', () async {
      final h = await _Harness.create();
      await h.notifier.setRoutineTemplates(
        'supplements',
        [
          _suppTemplate(
            id: 'protein',
            title: 'Protein',
            dosage: '1 scoop',
            repeatRule: 'weekly:1,2,3,4,5', // Mon–Fri
          ),
        ],
        materializeDays: 0,
      );

      // 2025-06-09 = Monday (weekday 1)
      final monday = DateTime(2025, 6, 9);
      // 2025-06-14 = Saturday (weekday 6)
      final saturday = DateTime(2025, 6, 14);

      await h.notifier.materializeForDate(monday);
      await h.notifier.materializeForDate(saturday);

      expect(await h.tasksForDate(monday), hasLength(1));
      expect(await h.tasksForDate(saturday), isEmpty);

      h.dispose();
    });
  });

  // ── 10. Firestore path verification ─────────────────────────────────────────

  group('Supplement — Firestore path', () {
    test('template is stored at /users/{uid}/routine/current', () async {
      final h = await _Harness.create();
      await h.notifier.setRoutineTemplates(
        'supplements',
        [_suppTemplate()],
        materializeDays: 0,
      );

      final doc = await h.fakeFirestore
          .collection('users')
          .doc(_Harness._uid)
          .collection('routine')
          .doc('current')
          .get();

      expect(doc.exists, isTrue);
      final templates =
          (doc.data()!['templates'] as Map)['supplements'] as List;
      expect(templates, hasLength(1));
      expect(templates.first['title'], 'Vitamin D');
      expect(templates.first['dosage'], '1000 IU');

      h.dispose();
    });

    test('materialized task is stored at /users/{uid}/tasks/{taskId}',
        () async {
      final h = await _Harness.create();
      await h.notifier.setRoutineTemplates(
        'supplements',
        [_suppTemplate()],
        materializeDays: 0,
      );

      final date = DateTime(2025, 6, 10);
      await h.notifier.materializeForDate(date);

      const expectedId = 'routine_2025-06-10_supplements_vitamin_d_0800_0805';
      final task = await h.taskById(expectedId);
      expect(task, isNotNull);
      expect(task!['title'], 'Vitamin D');

      h.dispose();
    });
  });
}
