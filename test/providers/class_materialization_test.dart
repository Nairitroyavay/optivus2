// test/providers/class_materialization_test.dart
//
// Integration tests for manual class routine materialization.
// Uses FakeFirebaseFirestore — no real Firebase project required.
//
// Verifies:
//   1. Room and Professor fields are translated into subtasks.
//   2. Weekly repeat rules limit materialization to matching days.
//   3. AI/Worker endpoints and image import flags are not required for manual saving.
//   4. `routine_template_created` and `task_scheduled` events are fired correctly.

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

  static const _uid = 'class_test_user';

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

  Future<List<Map<String, dynamic>>> eventsWhere(String eventName) async {
    final snap = await _events
        .where('eventName', isEqualTo: eventName)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  void dispose() => notifier.dispose();
}

// ── Template factory ──────────────────────────────────────────────────────────

Map<String, dynamic> _classTemplate({
  required String id,
  required String title,
  required String repeatRule,
  String room = '',
  String professor = '',
  String startTime = '09:00',
  String endTime = '10:00',
}) {
  return {
    'templateId': id,
    'title': title,
    'routineType': 'classes',
    'startTime': startTime,
    'endTime': endTime,
    'repeatRule': repeatRule,
    'room': room,
    'professor': professor,
    'isActive': true,
  };
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Manual Class Setup — Materialization & Fields', () {
    test('Weekdays materialization respects weekly:N rules', () async {
      final h = await _Harness.create();
      
      // Save Mon, Wed, Fri classes
      await h.notifier.setRoutineTemplates(
        'classes',
        [
          _classTemplate(id: 'class_1', title: 'Math 101', repeatRule: 'weekly:1'), // Mon
          _classTemplate(id: 'class_3', title: 'Math 101', repeatRule: 'weekly:3'), // Wed
          _classTemplate(id: 'class_5', title: 'Math 101', repeatRule: 'weekly:5'), // Fri
        ],
        materializeDays: 0,
      );

      // 2025-06-09 is Monday (1)
      final monday = DateTime(2025, 6, 9);
      final tuesday = DateTime(2025, 6, 10);
      final wednesday = DateTime(2025, 6, 11);
      
      await h.notifier.materializeForDate(monday);
      await h.notifier.materializeForDate(tuesday);
      await h.notifier.materializeForDate(wednesday);

      final monTasks = await h.tasksForDate(monday);
      expect(monTasks, hasLength(1));
      expect(monTasks.first['title'], 'Math 101');

      final tueTasks = await h.tasksForDate(tuesday);
      expect(tueTasks, isEmpty, reason: 'No class scheduled on Tuesday');

      final wedTasks = await h.tasksForDate(wednesday);
      expect(wedTasks, hasLength(1));
      expect(wedTasks.first['title'], 'Math 101');

      h.dispose();
    });

    test('Room and Professor fields become subtasks', () async {
      final h = await _Harness.create();
      
      await h.notifier.setRoutineTemplates(
        'classes',
        [
          _classTemplate(
            id: 'cs101',
            title: 'Computer Science 101',
            repeatRule: 'weekly:1',
            room: 'Lab 42',
            professor: 'Dr. Smith',
          ),
        ],
        materializeDays: 0,
      );

      final monday = DateTime(2025, 6, 9);
      await h.notifier.materializeForDate(monday);

      final tasks = await h.tasksForDate(monday);
      expect(tasks, hasLength(1));

      final subtasks = tasks.first['subtasks'] as List;
      
      final roomSubtask = subtasks.firstWhere(
        (s) => (s as Map)['id'] == 'room',
        orElse: () => null,
      );
      expect(roomSubtask, isNotNull, reason: 'Expected a room subtask');
      expect((roomSubtask as Map)['title'], 'Lab 42');

      final professorSubtask = subtasks.firstWhere(
        (s) => (s as Map)['id'] == 'professor',
        orElse: () => null,
      );
      expect(professorSubtask, isNotNull, reason: 'Expected a professor subtask');
      expect((professorSubtask as Map)['title'], 'Dr. Smith');

      h.dispose();
    });
  });

  group('Manual Class Setup — Events', () {
    test('Emits routine_template_created and task_scheduled', () async {
      final h = await _Harness.create();
      
      await h.notifier.setRoutineTemplates(
        'classes',
        [
          _classTemplate(id: 'cs101', title: 'Computer Science', repeatRule: 'weekly:1'),
        ],
        materializeDays: 0,
      );

      final templateEvents = await h.eventsWhere('routine_template_created');
      expect(templateEvents, hasLength(1));
      expect((templateEvents.first['payload'] as Map)['templateId'], 'cs101');

      final monday = DateTime(2025, 6, 9);
      await h.notifier.materializeForDate(monday);

      final taskEvents = await h.eventsWhere('task_scheduled');
      expect(taskEvents, isNotEmpty);
      expect((taskEvents.first['payload'] as Map)['taskId'], contains('cs101'));

      h.dispose();
    });
  });

  group('Manual Class Setup — Feature Flag Independence', () {
    test('Manual classes save without worker endpoints', () async {
      // Harness uses a RoutineRepository WITHOUT providing an apiService or featureFlags,
      // simulating manual setup perfectly.
      final h = await _Harness.create();
      
      await h.notifier.setRoutineTemplates(
        'classes',
        [
          _classTemplate(id: 'physics', title: 'Physics', repeatRule: 'weekly:1'),
        ],
        materializeDays: 0,
      );
      
      final monday = DateTime(2025, 6, 9);
      await h.notifier.materializeForDate(monday);

      final tasks = await h.tasksForDate(monday);
      expect(tasks, hasLength(1));
      expect(tasks.first['title'], 'Physics');

      h.dispose();
    });
  });
}
