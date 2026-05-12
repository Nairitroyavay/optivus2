// test/providers/eating_materialization_test.dart
//
// Integration tests for eating template materialization and safety gates.
// Uses FakeFirebaseFirestore — no real Firebase project required.
//
// Firestore paths exercised:
//   /users/{uid}/routine/current                — eating templates
//   /users/{uid}/tasks/{taskId}                 — materialized eating tasks
//   /users/{uid}/events/{eventId}               — routine_template_created + task_scheduled
//
// Verifies:
//   1. Normal user: manual meal saves and materializes as eating task on correct weekday
//   2. Sensitive user: templates gain sensitiveMode:true in Firestore
//   3. Empty list: clears eating templates without crash
//   4. mess_menu_weekday repeat rule: skips non-matching weekdays
//   5. routine_template_created emitted once per template on save
//   6. task_scheduled emitted only on first materialization (idempotent)
//   7. No Worker endpoint required — manual path is fully self-contained

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

  static const _uid = 'eating_test_user';

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
    final snap =
        await _events.where('eventName', isEqualTo: eventName).get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Future<Map<String, dynamic>?> routineDoc() async {
    final doc = await fakeFirestore
        .collection('users')
        .doc(_uid)
        .collection('routine')
        .doc('current')
        .get();
    if (!doc.exists) return null;
    return doc.data();
  }

  void dispose() => notifier.dispose();
}

// ── Template factory ──────────────────────────────────────────────────────────

Map<String, dynamic> _eatingTemplate({
  String id = 'eating_1_breakfast',
  String title = 'Breakfast',
  String startTime = '08:00',
  String endTime = '09:00',
  String repeatRule = 'mess_menu_weekday:1', // Monday
  String notes = 'Idli, Sambar',
  String emoji = '🥣',
  bool reminderEnabled = false,
  bool sensitiveMode = false,
}) {
  return {
    'templateId': id,
    'title': title,
    'routineType': 'eating',
    'startTime': startTime,
    'endTime': endTime,
    'repeatRule': repeatRule,
    'mealType': title,
    'notes': notes,
    'emoji': emoji,
    'reminderEnabled': reminderEnabled,
    'isActive': true,
    if (sensitiveMode) 'sensitiveMode': true,
  };
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── 1. Normal user — manual meal saves and materializes ────────────────────

  group('Eating materialization — normal user', () {
    test('manual meal saves to Firestore and materializes as eating task',
        () async {
      final h = await _Harness.create();
      await h.notifier.setRoutineTemplates(
        'eating',
        [_eatingTemplate()],
        materializeDays: 0,
      );

      // 2025-06-02 = Monday (weekday 1)
      final monday = DateTime(2025, 6, 2);
      await h.notifier.materializeForDate(monday);

      final tasks = await h.tasksForDate(monday);
      expect(tasks, hasLength(1));
      expect(tasks.first['title'], 'Breakfast');
      expect(tasks.first['sourceRoutineType'], 'eating');

      final routine = await h.routineDoc();
      expect(routine, isNotNull);
      final templates =
          (routine!['templates'] as Map)['eating'] as List;
      expect(templates, hasLength(1));
      expect(templates.first['title'], 'Breakfast');

      h.dispose();
    });
  });

  // ── 2. Sensitive user — sensitiveMode:true in Firestore ────────────────────

  group('Eating safety gate — sensitive user', () {
    test('template saved with sensitiveMode:true is persisted to Firestore',
        () async {
      final h = await _Harness.create();
      // Simulate the screen passing sensitiveMode:true in the template.
      await h.notifier.setRoutineTemplates(
        'eating',
        [_eatingTemplate(sensitiveMode: true)],
        materializeDays: 0,
      );

      final routine = await h.routineDoc();
      final templates =
          (routine!['templates'] as Map)['eating'] as List;
      expect(templates.first['sensitiveMode'], isTrue,
          reason: 'sensitiveMode flag must be persisted for downstream guards');

      h.dispose();
    });

    test('normal user template does NOT have sensitiveMode field', () async {
      final h = await _Harness.create();
      await h.notifier.setRoutineTemplates(
        'eating',
        [_eatingTemplate(sensitiveMode: false)],
        materializeDays: 0,
      );

      final routine = await h.routineDoc();
      final templates =
          (routine!['templates'] as Map)['eating'] as List;
      expect(templates.first.containsKey('sensitiveMode'), isFalse,
          reason: 'Normal users must not have sensitiveMode field');

      h.dispose();
    });
  });

  // ── 3. Empty list — clears templates without crash ─────────────────────────

  group('Eating — empty list save', () {
    test('saving empty list clears eating templates', () async {
      final h = await _Harness.create();
      await h.notifier.setRoutineTemplates(
        'eating',
        [_eatingTemplate()],
        materializeDays: 0,
      );
      expect(h.notifier.state.routineTemplates['eating'], hasLength(1));

      await h.notifier.setRoutineTemplates(
        'eating',
        [],
        materializeDays: 0,
      );
      expect(h.notifier.state.routineTemplates['eating'], isEmpty);

      h.dispose();
    });
  });

  // ── 4. mess_menu_weekday repeat rule — skips non-matching weekdays ─────────

  group('Eating — mess_menu_weekday repeat rule', () {
    test('Monday meal does not materialize on Tuesday', () async {
      final h = await _Harness.create();
      await h.notifier.setRoutineTemplates(
        'eating',
        [_eatingTemplate(repeatRule: 'mess_menu_weekday:1')], // Monday only
        materializeDays: 0,
      );

      // 2025-06-02 = Monday, 2025-06-03 = Tuesday
      final monday = DateTime(2025, 6, 2);
      final tuesday = DateTime(2025, 6, 3);
      await h.notifier.materializeForDate(monday);
      await h.notifier.materializeForDate(tuesday);

      expect(await h.tasksForDate(monday), hasLength(1));
      expect(await h.tasksForDate(tuesday), isEmpty,
          reason: 'Monday meal must not appear on Tuesday');

      h.dispose();
    });

    test('Wednesday meal only materializes on Wednesday', () async {
      final h = await _Harness.create();
      await h.notifier.setRoutineTemplates(
        'eating',
        [
          _eatingTemplate(
            id: 'eating_3_lunch',
            title: 'Lunch',
            repeatRule: 'mess_menu_weekday:3', // Wednesday
          )
        ],
        materializeDays: 0,
      );

      // 2025-06-04 = Wednesday, 2025-06-05 = Thursday
      final wednesday = DateTime(2025, 6, 4);
      final thursday = DateTime(2025, 6, 5);
      await h.notifier.materializeForDate(wednesday);
      await h.notifier.materializeForDate(thursday);

      expect(await h.tasksForDate(wednesday), hasLength(1));
      expect(await h.tasksForDate(thursday), isEmpty);

      h.dispose();
    });
  });

  // ── 5. routine_template_created event ──────────────────────────────────────

  group('Eating events — routine_template_created', () {
    test('emitted once per template on setRoutineTemplates', () async {
      final h = await _Harness.create();
      await h.notifier.setRoutineTemplates(
        'eating',
        [
          _eatingTemplate(id: 'eating_1_breakfast', title: 'Breakfast'),
          _eatingTemplate(
              id: 'eating_1_lunch',
              title: 'Lunch',
              repeatRule: 'mess_menu_weekday:1'),
        ],
        materializeDays: 0,
      );

      final events = await h.eventsWhere('routine_template_created');
      expect(events, hasLength(2),
          reason: 'One routine_template_created per template');

      final ids = events
          .map((e) => (e['payload'] as Map)['templateId'])
          .toSet();
      expect(ids, containsAll(['eating_1_breakfast', 'eating_1_lunch']));

      h.dispose();
    });
  });

  // ── 6. task_scheduled — idempotent ─────────────────────────────────────────

  group('Eating events — task_scheduled idempotency', () {
    test('task_scheduled emitted only on first materialization', () async {
      final h = await _Harness.create();
      await h.notifier.setRoutineTemplates(
        'eating',
        [_eatingTemplate()],
        materializeDays: 0,
      );

      final monday = DateTime(2025, 6, 2);
      await h.notifier.materializeForDate(monday);
      final countAfterFirst =
          (await h.eventsWhere('task_scheduled')).length;

      // Re-materialize same day — must not emit again.
      await h.notifier.materializeForDate(monday);
      final countAfterSecond =
          (await h.eventsWhere('task_scheduled')).length;

      expect(countAfterSecond, equals(countAfterFirst),
          reason:
              'task_scheduled must not be re-emitted on re-materialization');

      h.dispose();
    });
  });

  // ── 7. No Worker required — manual path is self-contained ──────────────────

  group('Eating — AI/Worker flag independence', () {
    test('manual eating saves and materializes without Worker endpoint',
        () async {
      // RoutineRepository has no featureFlags/apiService injected,
      // so the Worker guard is inactive. This proves the manual path
      // is fully self-contained.
      final h = await _Harness.create();
      await h.notifier.setRoutineTemplates(
        'eating',
        [
          _eatingTemplate(
            id: 'eating_1_dinner',
            title: 'Dinner',
            notes: 'Dal, Rice, Sabzi',
            startTime: '20:00',
            endTime: '21:00',
          )
        ],
        materializeDays: 0,
      );

      final monday = DateTime(2025, 6, 2);
      await h.notifier.materializeForDate(monday);

      final tasks = await h.tasksForDate(monday);
      expect(tasks, hasLength(1));
      expect(tasks.first['title'], 'Dinner');
      expect(tasks.first['sourceRoutineType'], 'eating');

      h.dispose();
    });
  });
}
