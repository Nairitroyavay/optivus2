import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../services/firestore_service.dart';
import '../providers/routine_provider.dart'; // RoutineState lives here

const String _routineImportEndpoint =
    String.fromEnvironment('ROUTINE_IMPORT_ENDPOINT');
const String _localRunDartDefines = 'Required local run flags:\n'
    '--dart-define=COACH_REPLY_ENDPOINT=https://...\n'
    '--dart-define=AI_GENERATE_ENDPOINT=https://...\n'
    '--dart-define=ROUTINE_IMPORT_ENDPOINT=https://...';

/// Persists and loads the full RoutineState to/from Firestore, and provides
/// the low-level read/merge helpers used by the routine task materialiser.
///
/// Routine state lives at: `/users/{uid}/routine/current`
/// Routine-derived tasks live at: `/users/{uid}/tasks/{taskId}`
class RoutineRepository {
  final FirestoreService _service;

  RoutineRepository(this._service);

  /// Save the entire routine state as a single Firestore document.
  Future<void> saveRoutine(RoutineState state) async {
    final existing = await _service.getRoutine() ?? <String, dynamic>{};
    final existingImports = existing['imports'] is Map
        ? Map<String, dynamic>.from(existing['imports'] as Map)
        : <String, dynamic>{};
    await _service.saveRoutine({
      ...state.toMap(),
      if (existingImports.isNotEmpty) 'imports': existingImports,
    });
  }

  /// Save only the fixed schedule template config at
  /// /users/{uid}/routine/current.templates.fixed_schedule.
  Future<void> saveFixedScheduleTemplates(
    List<FixedScheduleTemplate> templates,
  ) async {
    final existing = await _service.getRoutine() ?? <String, dynamic>{};
    final existingTemplates = existing['templates'] is Map
        ? Map<String, dynamic>.from(existing['templates'] as Map)
        : <String, dynamic>{};

    await _service.saveRoutine({
      ...existing,
      'templates': {
        ...existingTemplates,
        'fixed_schedule':
            templates.map((template) => template.toMap()).toList(),
      },
      'fixedScheduleSetUp': templates.isNotEmpty,
    });
  }

  Future<void> saveRoutineTemplates(
    String routineType,
    List<Map<String, dynamic>> templates, {
    Map<String, dynamic>? importMetadata,
  }) async {
    final existing = await _service.getRoutine() ?? <String, dynamic>{};
    final existingTemplates = existing['templates'] is Map
        ? Map<String, dynamic>.from(existing['templates'] as Map)
        : <String, dynamic>{};
    final existingImports = existing['imports'] is Map
        ? Map<String, dynamic>.from(existing['imports'] as Map)
        : <String, dynamic>{};

    await _service.saveRoutine({
      ...existing,
      'templates': {
        ...existingTemplates,
        routineType: templates,
      },
      if (importMetadata != null)
        'imports': {
          ...existingImports,
          routineType: importMetadata,
        },
      '${_setupFlagFor(routineType)}SetUp': templates.isNotEmpty,
    });
  }

  /// Ask the routine import Worker endpoint to parse text/image input into
  /// routine templates without committing them. The setup screens present the
  /// returned items for review before calling [saveRoutineTemplates].
  Future<List<Map<String, dynamic>>> previewRoutineImport({
    required String routineType,
    required String mode,
    String? sourceText,
    Map<String, dynamic>? imageMetadata,
  }) async {
    if (_routineImportEndpoint.isEmpty) {
      throw Exception(
        'ROUTINE_IMPORT_ENDPOINT is not configured. $_localRunDartDefines',
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Cannot call routine import endpoint without auth token');
    }

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Cannot call routine import endpoint without auth token');
    }

    final response = await http.post(
      Uri.parse(_routineImportEndpoint),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'userId': user.uid,
        'routineType': routineType,
        'mode': mode,
        'commit': false,
        if (sourceText != null && sourceText.trim().isNotEmpty)
          'sourceText': sourceText.trim(),
        if (imageMetadata != null) 'imageMetadata': imageMetadata,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Routine import endpoint failed: '
        '${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('Routine import endpoint returned invalid JSON');
    }

    final data = Map<String, dynamic>.from(decoded);
    final raw = data['templates'] ?? data['items'] ?? data['blocks'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> saveScheduledNotification(
    String notificationId,
    Map<String, dynamic> data,
  ) {
    return _service.saveScheduledNotification(notificationId, data);
  }

  /// Load the routine state. Returns null if no data exists yet.
  Future<RoutineState?> loadRoutine() async {
    final data = await _service.getRoutine();
    if (data == null) return null;
    return RoutineState.fromMap(data);
  }

  // ── Routine-task materialisation helpers ───────────────────────────────────

  /// Reads existing task docs whose `plannedStart` falls on [date]'s calendar
  /// day. Returns a map of `taskId -> state` (state defaulting to `'scheduled'`
  /// when missing). Used by the materialiser to decide whether a candidate
  /// should be created, merged, or skipped (terminal state).
  Future<Map<String, String>> existingRoutineTaskStatesForDate(
      DateTime date) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final snap = await _service.userDoc
        .collection('tasks')
        .where('plannedStart',
            isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('plannedStart', isLessThan: Timestamp.fromDate(dayEnd))
        .get();
    return {
      for (final d in snap.docs) d.id: _taskState(d.data()),
    };
  }

  /// Reads the lifecycle state for one task ID. This keeps materialisation
  /// idempotent even if a previous task's planned time changed and no longer
  /// falls into the date-range query used as the fast path above.
  Future<String?> taskState(String taskId) async {
    final doc = await _service.userDoc.collection('tasks').doc(taskId).get();
    if (!doc.exists) return null;
    return _taskState(doc.data() ?? const <String, dynamic>{});
  }

  /// Merges [fields] into an existing task doc without touching state/actuals
  /// — used to (re)apply routine-template config and materialisation metadata
  /// onto a task that already exists. Always stamps `updatedAt`.
  Future<void> mergeTaskFields(
    String taskId,
    Map<String, dynamic> fields,
  ) {
    return _service.userDoc.collection('tasks').doc(taskId).set(
      {...fields, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  String _taskState(Map<String, dynamic> data) =>
      (data['state'] as String?) ?? (data['status'] as String?) ?? 'scheduled';

  String _setupFlagFor(String routineType) {
    switch (routineType) {
      case 'fixed_schedule':
        return 'fixedSchedule';
      case 'skin_care':
        return 'skinCare';
      case 'classes':
        return 'classes';
      case 'eating':
        return 'eating';
      case 'supplements':
        return 'supplements';
      default:
        return '${routineType.replaceAll('_', '')}Templates';
    }
  }
}
