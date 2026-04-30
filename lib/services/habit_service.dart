// lib/services/habit_service.dart
//
// Full CRUD for habits. Per ServiceContracts §3.
//
// Firestore paths:
//   Habit document  : users/{uid}/habits/{habitId}
//   Log entry       : users/{uid}/habits/{habitId}/logs/{YYYY-MM-DD}/items/{logId}
//
// Rules:
//   • All writes use WriteBatch and carry schemaVersion: 1.
//   • logGood / logSlip validate habit existence, kind, and active state before writing.
//   • deleteHabit is a soft-delete (state → archived) to preserve log sub-collections.

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

  // ── Private helpers ────────────────────────────────────────────────────────

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw const NotAuthenticatedError();
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _habitsRef =>
      _firestore.collection('users').doc(_uid).collection('habits');

  CollectionReference<Map<String, dynamic>> get _habitLogsRef =>
      _firestore.collection('users').doc(_uid).collection('habit_logs');

  /// Returns a zero-padded `YYYY-MM-DD` string for [date].
  String _dateString(DateTime date) =>
      '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Returns the `items` sub-collection ref for a given [habitId] and [date].
  CollectionReference<Map<String, dynamic>> _itemsRef(
    String habitId,
    DateTime date,
  ) =>
      _habitsRef
          .doc(habitId)
          .collection('logs')
          .doc(_dateString(date))
          .collection('items');

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Real-time stream of all active habits for the current user.
  Stream<List<HabitModel>> habits() {
    return _habitsRef
        .where('state', isEqualTo: HabitState.active.name)
        .snapshots()
        .map((snap) => snap.docs.map(HabitModel.fromFirestore).toList());
  }

  /// Fetches a single habit. Returns `null` if it does not exist.
  Future<HabitModel?> getHabit(String habitId) async {
    final snap = await _habitsRef.doc(habitId).get();
    if (!snap.exists || snap.data() == null) return null;
    return HabitModel.fromFirestore(snap);
  }

  /// Returns the count of log items for [habitId] on [date].
  Future<int> dailyLogCount(String habitId, DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snap = await _habitLogsRef
        .where('habitId', isEqualTo: habitId)
        .where('occurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('occurredAt', isLessThan: Timestamp.fromDate(endOfDay))
        .count()
        .get();

    return snap.count ?? 0;
  }

  /// Returns the sum of quantities for a good habit on [date].
  Future<num> dailyTotal(String habitId, DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snap = await _habitLogsRef
        .where('habitId', isEqualTo: habitId)
        .where('occurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('occurredAt', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    num total = 0;
    for (final doc in snap.docs) {
      total += (doc.data()['quantity'] as num?) ?? 1;
    }
    return total;
  }

  // ── Create ────────────────────────────────────────────────────────────────

  /// Creates a new habit document at `users/{uid}/habits/{habitId}`.
  ///
  /// Throws [InvalidHabitInputError] if [habit.name] is blank.
  /// Uses [WriteBatch] for the write; stamps `schemaVersion: 1`.
  Future<void> createHabit(HabitModel habit) async {
    if (habit.name.trim().isEmpty) {
      throw InvalidHabitInputError('Habit name must not be blank.');
    }

    final docRef = _habitsRef.doc(habit.id);
    final batch = _firestore.batch();

    batch.set(docRef, {
      ...habit.toFirestore(),
      'schemaVersion': 1,
    });

    await batch.commit();
    // Phase 4: emit EventNames.habitCreated
  }

  // ── Update ────────────────────────────────────────────────────────────────

  /// Updates an existing habit document.
  ///
  /// Throws [HabitNotFoundError] if the habit does not exist.
  /// Uses [WriteBatch]; stamps `schemaVersion: 1` and refreshes `updatedAt`.
  Future<void> updateHabit(HabitModel habit) async {
    final existing = await getHabit(habit.id);
    if (existing == null) throw HabitNotFoundError(habit.id);

    final docRef = _habitsRef.doc(habit.id);
    final batch = _firestore.batch();

    batch.update(docRef, {
      ...habit.toFirestore(),
      'schemaVersion': 1,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    // Phase 4: emit EventNames.habitUpdated
  }

  // ── Delete (soft) ─────────────────────────────────────────────────────────

  /// Soft-deletes a habit by transitioning its state to [HabitState.archived].
  ///
  /// Hard deletion is intentionally avoided — deleting the parent document
  /// would orphan the log sub-collections and erase streak history.
  ///
  /// Throws [HabitNotFoundError] if the habit does not exist.
  Future<void> deleteHabit(String habitId) async {
    final existing = await getHabit(habitId);
    if (existing == null) throw HabitNotFoundError(habitId);

    final docRef = _habitsRef.doc(habitId);
    final batch = _firestore.batch();

    batch.update(docRef, {
      'state': HabitState.archived.name,
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': 1,
    });

    await batch.commit();
    // Phase 4: emit habit_archived event (not yet in EventNames — add in Phase 4)
  }

  // ── Logging ───────────────────────────────────────────────────────────────

  /// Logs a good-habit occurrence.
  ///
  /// Path: `users/{uid}/habits/{habitId}/logs/{YYYY-MM-DD}/items/{logId}`
  ///
  /// Throws:
  ///   - [HabitNotFoundError]  — habit does not exist.
  ///   - [WrongHabitKindError] — habit is not [HabitKind.good].
  ///   - [HabitNotActiveError] — habit is paused or archived.
  ///   - [InvalidAmountError]  — [amount] is provided but ≤ 0.
  ///
  /// Uses [WriteBatch]; stamps `schemaVersion: 1` and `logType: 'good'`.
  Future<void> logGood(
    String habitId, {
    num? amount,
    String? note,
    String? source,
    DateTime? occurredAt,
  }) async {
    final habit = await _requireHabit(habitId);
    _requireKind(habit, HabitKind.good);
    _requireActive(habit);
    if (amount != null && amount <= 0) throw const InvalidAmountError();

    final now = DateTime.now();
    final occurred = occurredAt ?? now;
    final logId = generateId();

    final log = HabitLog(
      logId: logId,
      habitId: habitId,
      habitKind: habit.kind.name,
      logType: 'good',
      occurredAt: occurred,
      loggedAt: now,
      quantity: amount,
      unit: habit.unit,
      note: note,
      source: source ?? 'manual',
      schemaVersion: 1,
    );

    final nestedDocRef = _itemsRef(habitId, occurred).doc(logId);
    final canonicalDocRef = _habitLogsRef.doc(logId);
    final batch = _firestore.batch();

    batch.set(nestedDocRef, log.toFirestore());
    batch.set(canonicalDocRef, log.toFirestore());

    await _eventService.emit(
      eventName: EventNames.goodHabitLogged,
      payload: {
        'habitId': habitId,
        'logId': logId,
        'occurredAt': occurred.toIso8601String(),
        'loggedAt': now.toIso8601String(),
        if (amount != null) 'amount': amount,
        if (note != null) 'note': note,
        'source': source ?? 'manual',
      },
      batch: batch,
    );

    await batch.commit();
  }

  /// Logs a bad-habit slip.
  ///
  /// Path: `users/{uid}/habits/{habitId}/logs/{YYYY-MM-DD}/items/{logId}`
  ///
  /// Throws:
  ///   - [HabitNotFoundError]  — habit does not exist.
  ///   - [WrongHabitKindError] — habit is not [HabitKind.bad].
  ///   - [HabitNotActiveError] — habit is paused or archived.
  ///
  /// Uses [WriteBatch]; stamps `schemaVersion: 1` and `logType: 'slip'`.
  Future<void> logSlip(
    String habitId, {
    String? trigger,
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

    final log = HabitLog(
      logId: logId,
      habitId: habitId,
      habitKind: habit.kind.name,
      logType: 'slip',
      occurredAt: occurred,
      loggedAt: now,
      trigger: trigger,
      note: note,
      source: source ?? 'manual',
      schemaVersion: 1,
    );

    final nestedDocRef = _itemsRef(habitId, occurred).doc(logId);
    final canonicalDocRef = _habitLogsRef.doc(logId);
    final batch = _firestore.batch();

    batch.set(nestedDocRef, log.toFirestore());
    batch.set(canonicalDocRef, log.toFirestore());

    await _eventService.emit(
      eventName: EventNames.badHabitSlipLogged,
      payload: {
        'habitId': habitId,
        'logId': logId,
        'occurredAt': occurred.toIso8601String(),
        'loggedAt': now.toIso8601String(),
        if (trigger != null) 'trigger': trigger,
        if (note != null) 'note': note,
        'source': source ?? 'manual',
      },
      batch: batch,
    );

    await batch.commit();
  }

  // ── Guard helpers (private) ───────────────────────────────────────────────

  /// Fetches a habit and throws [HabitNotFoundError] if missing.
  Future<HabitModel> _requireHabit(String habitId) async {
    final habit = await getHabit(habitId);
    if (habit == null) throw HabitNotFoundError(habitId);
    return habit;
  }

  /// Throws [WrongHabitKindError] if [habit.kind] ≠ [expected].
  void _requireKind(HabitModel habit, HabitKind expected) {
    if (habit.kind != expected) {
      throw WrongHabitKindError(
        expected: expected.name,
        actual: habit.kind.name,
      );
    }
  }

  /// Throws [HabitNotActiveError] if [habit.state] ≠ [HabitState.active].
  void _requireActive(HabitModel habit) {
    if (habit.state != HabitState.active) {
      throw HabitNotActiveError(habit.id);
    }
  }
}
