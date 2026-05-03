// lib/services/habit_service.dart
//
// Habit CRUD and logging per ServiceContracts §3.
//
// Firestore paths:
//   Habit document : users/{uid}/habits/{habitId}
//   Canonical log  : users/{uid}/habit_logs/{logId}
//   Legacy copy    : users/{uid}/habits/{habitId}/logs/{YYYY-MM-DD}/items/{logId}
//
// Canonical reads use /habit_logs. The nested copy is dual-written only so
// older clients and one-time migrations can continue to find historical logs.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:optivus2/core/constants/event_names.dart';
import 'package:optivus2/core/errors/app_errors.dart';
import 'package:optivus2/core/utils/uuid_generator.dart';
import 'package:optivus2/models/habit_log_model.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/services/event_service.dart';

class HabitService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final EventService _eventService;

  HabitService({
    required EventService eventService,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _eventService = eventService,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw const NotAuthenticatedError();
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _habitsRef =>
      _firestore.collection('users').doc(_uid).collection('habits');

  CollectionReference<Map<String, dynamic>> get _habitLogsRef =>
      _firestore.collection('users').doc(_uid).collection('habit_logs');

  CollectionReference<Map<String, dynamic>> _itemsRef(
    String habitId,
    DateTime date,
  ) =>
      _habitsRef
          .doc(habitId)
          .collection('logs')
          .doc(_dateString(date))
          .collection('items');

  String _dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  (DateTime, DateTime) _dayBounds(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    return (start, start.add(const Duration(days: 1)));
  }

  // ── Reads ─────────────────────────────────────────────────────────────────

  /// Real-time stream of habits. Defaults to active habits only.
  Stream<List<HabitModel>> watchHabits({HabitState? filter}) {
    Query<Map<String, dynamic>> query = _habitsRef;
    if (filter != null) {
      query = query.where('state', isEqualTo: filter.name);
    }

    return query
        .snapshots()
        .map((snap) => snap.docs.map(HabitModel.fromFirestore).toList());
  }

  /// Backwards-compatible alias used by existing providers.
  Stream<List<HabitModel>> habits({HabitState? filter}) =>
      watchHabits(filter: filter ?? HabitState.active);

  /// Fetches a single habit. Returns null if it does not exist.
  Future<HabitModel?> getHabit(String habitId) async {
    final snap = await _habitsRef.doc(habitId).get();
    if (!snap.exists || snap.data() == null) return null;
    return HabitModel.fromFirestore(snap);
  }

  /// Real-time stream of canonical log docs for a calendar date.
  Stream<List<HabitLog>> watchHabitLogsForDate(
    DateTime date, {
    String? habitId,
  }) {
    final (startOfDay, endOfDay) = _dayBounds(date);
    Query<Map<String, dynamic>> query = _habitLogsRef
        .where('occurredAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('occurredAt', isLessThan: Timestamp.fromDate(endOfDay));

    if (habitId != null) {
      query = query.where('habitId', isEqualTo: habitId);
    }

    return query
        .orderBy('occurredAt')
        .snapshots()
        .map((snap) => snap.docs.map(HabitLog.fromFirestore).toList());
  }

  /// Returns the count of canonical log items for [habitId] on [date].
  Future<int> dailyLogCount(String habitId, DateTime date) async {
    final (startOfDay, endOfDay) = _dayBounds(date);
    final snap = await _habitLogsRef
        .where('habitId', isEqualTo: habitId)
        .where('occurredAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('occurredAt', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    num total = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      total += (data['quantity'] as num?) ?? 1;
    }
    return total.round();
  }

  /// Returns the summed quantity for [habitId] on [date].
  Future<num> dailyTotal(String habitId, DateTime date) async {
    final (startOfDay, endOfDay) = _dayBounds(date);
    final snap = await _habitLogsRef
        .where('habitId', isEqualTo: habitId)
        .where('occurredAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('occurredAt', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    num total = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['logType'] == 'slip') continue;
      total += (data['quantity'] as num?) ?? (data['amount'] as num?) ?? 1;
    }
    return total;
  }

  // ── Habit lifecycle ───────────────────────────────────────────────────────

  Future<String> createHabit(HabitModel habit) async {
    _validateHabit(habit);

    final docRef = _habitsRef.doc(habit.id);
    final batch = _firestore.batch();
    final toCreate = habit.copyWith(state: HabitState.active);

    batch.set(docRef, {
      ...toCreate.toFirestore(),
      'state': HabitState.active.name,
      'schemaVersion': 1,
    });

    await _eventService.emit(
      eventName: EventNames.habitCreated,
      source: 'app',
      payload: _habitPayload(toCreate),
      batch: batch,
    );

    await batch.commit();
    return habit.id;
  }

  Future<void> updateHabit(HabitModel habit) async {
    final existing = await _requireHabit(habit.id);
    _validateHabit(habit);

    final updated = habit.copyWith(
      state: habit.state,
      pausedAt: habit.pausedAt,
      archivedAt: habit.archivedAt,
    );
    final docRef = _habitsRef.doc(habit.id);
    final batch = _firestore.batch();

    batch.update(docRef, {
      ...updated.toFirestore(),
      'createdAt': Timestamp.fromDate(existing.createdAt),
      'schemaVersion': 1,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _eventService.emit(
      eventName: EventNames.habitUpdated,
      source: 'app',
      payload: _habitPayload(updated),
      batch: batch,
    );

    await batch.commit();
  }

  Future<void> pauseHabit(String habitId) async {
    final habit = await _requireHabit(habitId);
    if (habit.state == HabitState.archived) {
      throw InvalidHabitInputError('Archived habits cannot be paused.');
    }
    if (habit.state == HabitState.paused) return;

    final now = DateTime.now();
    final batch = _firestore.batch();
    final docRef = _habitsRef.doc(habitId);

    batch.update(docRef, {
      'state': HabitState.paused.name,
      'pausedAt': Timestamp.fromDate(now),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': 1,
    });

    await _eventService.emit(
      eventName: EventNames.habitPaused,
      source: 'app',
      payload: _habitPayload(
        habit.copyWith(state: HabitState.paused, pausedAt: now),
      ),
      batch: batch,
    );

    await batch.commit();
  }

  Future<void> resumeHabit(String habitId) async {
    final habit = await _requireHabit(habitId);
    if (habit.state == HabitState.archived) {
      throw InvalidHabitInputError('Archived habits cannot be resumed.');
    }
    if (habit.state == HabitState.active) return;

    final batch = _firestore.batch();
    final docRef = _habitsRef.doc(habitId);

    batch.update(docRef, {
      'state': HabitState.active.name,
      'pausedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': 1,
    });

    await _eventService.emit(
      eventName: EventNames.habitResumed,
      source: 'app',
      payload: _habitPayload(
        habit.copyWith(state: HabitState.active, clearPausedAt: true),
      ),
      batch: batch,
    );

    await batch.commit();
  }

  Future<void> archiveHabit(String habitId) async {
    final habit = await _requireHabit(habitId);
    if (habit.state == HabitState.archived) return;

    final now = DateTime.now();
    final batch = _firestore.batch();
    final docRef = _habitsRef.doc(habitId);

    batch.update(docRef, {
      'state': HabitState.archived.name,
      'archivedAt': Timestamp.fromDate(now),
      'pausedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': 1,
    });

    await _eventService.emit(
      eventName: EventNames.habitArchived,
      source: 'app',
      payload: _habitPayload(
        habit.copyWith(
          state: HabitState.archived,
          archivedAt: now,
          clearPausedAt: true,
        ),
      ),
      batch: batch,
    );

    await batch.commit();
  }

  /// Hard-deletes only the habit doc. Canonical logs are preserved for audit.
  Future<void> deleteHabit(
    String habitId, {
    bool confirmDestructive = false,
  }) async {
    if (!confirmDestructive) {
      throw InvalidHabitInputError(
        'Deleting a habit is destructive and requires confirmation.',
      );
    }

    final habit = await _requireHabit(habitId);
    final batch = _firestore.batch();
    batch.delete(_habitsRef.doc(habitId));

    await _eventService.emit(
      eventName: EventNames.habitDeleted,
      source: 'app',
      payload: _habitPayload(habit),
      batch: batch,
    );

    await batch.commit();
  }

  // ── Logging ────────────────────────────────────────────────────────────────

  Future<String> logGood(
    String habitId, {
    num? amount,
    String? unit,
    String? note,
    String? source,
    DateTime? occurredAt,
  }) async {
    final habit = await _requireHabit(habitId);
    _requireKind(habit, HabitKind.good);
    _requireActive(habit);

    final quantity = amount ?? 1;
    if (quantity <= 0) throw const InvalidAmountError();

    final now = DateTime.now();
    final occurred = occurredAt ?? now;
    final logId = generateId();
    final totalAfter = await dailyTotal(habitId, occurred) + quantity;

    final log = HabitLog(
      logId: logId,
      habitId: habitId,
      habitKind: habit.kind.name,
      logType: 'good',
      occurredAt: occurred,
      loggedAt: now,
      quantity: quantity,
      unit: unit ?? habit.unit,
      note: note,
      source: source ?? 'manual',
      schemaVersion: 1,
    );

    final batch = _firestore.batch();
    batch.set(_habitLogsRef.doc(logId), log.toFirestore());
    batch.set(_itemsRef(habitId, occurred).doc(logId), log.toFirestore());

    await _eventService.emit(
      eventName: EventNames.goodHabitLogged,
      source: source ?? 'manual',
      payload: {
        'habitId': habitId,
        'habitName': habit.name,
        'logId': logId,
        'amount': quantity,
        'unit': unit ?? habit.unit,
        'ts': occurred.toIso8601String(),
        'occurredAt': occurred.toIso8601String(),
        'loggedAt': now.toIso8601String(),
        'todayTotalAfter': totalAfter,
        'goalHitToday':
            habit.dailyGoal == null ? null : totalAfter >= habit.dailyGoal!,
        if (note != null) 'note': note,
        'source': source ?? 'manual',
      },
      batch: batch,
    );

    await batch.commit();
    return logId;
  }

  Future<String> logSlip(
    String habitId, {
    String? trigger,
    num? count,
    String? note,
    String? source,
    DateTime? occurredAt,
  }) async {
    final habit = await _requireHabit(habitId);
    _requireKind(habit, HabitKind.bad);
    _requireActive(habit);

    final now = DateTime.now();
    final occurred = occurredAt ?? now;
    final logId = generateId();
    final quantity = count ?? 1;
    if (quantity <= 0) throw const InvalidAmountError();
    final countTodayAfter = await _slipCount(habitId, occurred) + quantity;

    final log = HabitLog(
      logId: logId,
      habitId: habitId,
      habitKind: habit.kind.name,
      logType: 'slip',
      occurredAt: occurred,
      loggedAt: now,
      quantity: quantity,
      trigger: trigger,
      note: note,
      source: source ?? 'manual',
      schemaVersion: 1,
    );

    final batch = _firestore.batch();
    batch.set(_habitLogsRef.doc(logId), log.toFirestore());
    batch.set(_itemsRef(habitId, occurred).doc(logId), log.toFirestore());

    await _eventService.emit(
      eventName: EventNames.badHabitSlipLogged,
      source: source ?? 'manual',
      payload: {
        'habitId': habitId,
        'habitName': habit.name,
        'logId': logId,
        'count': quantity,
        'ts': occurred.toIso8601String(),
        'occurredAt': occurred.toIso8601String(),
        'loggedAt': now.toIso8601String(),
        'countTodayAfter': countTodayAfter,
        if (trigger != null) 'trigger': trigger,
        if (trigger != null) 'triggerTag': trigger,
        if (note != null) 'note': note,
        'source': source ?? 'manual',
      },
      batch: batch,
    );

    await batch.commit();
    return logId;
  }

  Future<void> deleteLog(
    String habitId,
    String logId, {
    bool confirmDestructive = false,
  }) async {
    if (!confirmDestructive) {
      throw InvalidHabitInputError(
        'Deleting a habit log is destructive and requires confirmation.',
      );
    }

    await _requireHabit(habitId);
    final canonicalRef = _habitLogsRef.doc(logId);
    final snap = await canonicalRef.get();
    if (!snap.exists || snap.data() == null) {
      throw InvalidHabitInputError('Habit log $logId does not exist.');
    }

    final log = HabitLog.fromFirestore(snap);
    if (log.habitId != habitId) {
      throw InvalidHabitInputError(
        'Habit log $logId does not belong to habit $habitId.',
      );
    }

    final batch = _firestore.batch();
    batch.delete(canonicalRef);
    batch.delete(_itemsRef(habitId, log.occurredAt).doc(logId));

    await _eventService.emit(
      eventName: EventNames.habitLogDeleted,
      source: 'app',
      payload: {
        'habitId': habitId,
        'logId': logId,
        'logType': log.logType,
        'occurredAt': log.occurredAt.toIso8601String(),
      },
      batch: batch,
    );

    await batch.commit();
  }

  // ── Guards ────────────────────────────────────────────────────────────────

  Future<HabitModel> _requireHabit(String habitId) async {
    final habit = await getHabit(habitId);
    if (habit == null) throw HabitNotFoundError(habitId);
    return habit;
  }

  void _requireKind(HabitModel habit, HabitKind expected) {
    if (habit.kind != expected) {
      throw WrongHabitKindError(
        expected: expected.name,
        actual: habit.kind.name,
      );
    }
  }

  void _requireActive(HabitModel habit) {
    if (habit.state != HabitState.active) {
      throw HabitNotActiveError(habit.id);
    }
  }

  void _validateHabit(HabitModel habit) {
    if (habit.name.trim().isEmpty) {
      throw InvalidHabitInputError('Habit name must not be blank.');
    }

    if (habit.kind == HabitKind.good) {
      if (habit.dailyGoal == null || habit.dailyGoal! <= 0) {
        throw InvalidHabitInputError(
          'Good habits require a dailyGoal greater than 0.',
        );
      }
      return;
    }

    final goalType = habit.goalType ?? BadHabitGoalType.awarenessOnly;
    if (goalType == BadHabitGoalType.reduceToTarget &&
        (habit.target == null || habit.target! < 0)) {
      throw InvalidHabitInputError(
        'Bad habits with reduce_to_target require a non-negative target.',
      );
    }
    if (habit.target != null && habit.target! < 0) {
      throw InvalidHabitInputError('Habit target must not be negative.');
    }
    if (habit.baselinePerDay != null && habit.baselinePerDay! < 0) {
      throw InvalidHabitInputError('Habit baseline must not be negative.');
    }
    if (habit.costPerUnit != null && habit.costPerUnit! < 0) {
      throw InvalidHabitInputError('Habit cost must not be negative.');
    }
  }

  Future<int> _slipCount(String habitId, DateTime date) async {
    final (startOfDay, endOfDay) = _dayBounds(date);
    final snap = await _habitLogsRef
        .where('habitId', isEqualTo: habitId)
        .where('logType', isEqualTo: 'slip')
        .where('occurredAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('occurredAt', isLessThan: Timestamp.fromDate(endOfDay))
        .get();
    num total = 0;
    for (final doc in snap.docs) {
      total += (doc.data()['quantity'] as num?) ?? 1;
    }
    return total.round();
  }

  Map<String, dynamic> _habitPayload(HabitModel habit) {
    return {
      'habitId': habit.id,
      'habitName': habit.name,
      'kind': habit.kind.name,
      'state': habit.state.name,
      'unit': habit.unit,
      'trackerType': habit.trackerType,
      if (habit.dailyGoal != null) 'dailyGoal': habit.dailyGoal,
      if (habit.goalType != null) 'goalType': habit.goalType!.toJson(),
      if (habit.target != null) 'target': habit.target,
      'scheduleDays': habit.scheduleDays,
      'remindersEnabled': habit.remindersEnabled,
      if (habit.reminderTime != null) 'reminderTime': habit.reminderTime,
      if (habit.accountability != null) 'accountability': habit.accountability,
      if (habit.pausedAt != null) 'pausedAt': habit.pausedAt!.toIso8601String(),
      if (habit.archivedAt != null)
        'archivedAt': habit.archivedAt!.toIso8601String(),
    };
  }
}
