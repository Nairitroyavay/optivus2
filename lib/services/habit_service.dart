import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:optivus2/core/constants/event_names.dart';
import 'package:optivus2/core/errors/app_errors.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/models/habit_log_model.dart';
import 'package:optivus2/services/event_service.dart';
import 'package:optivus2/core/utils/uuid_generator.dart';

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

  /// Real-time stream of all active habits for the current user.
  Stream<List<HabitModel>> habits() {
    return _habitsRef
        .where('state', isEqualTo: HabitState.active.name)
        .snapshots()
        .map((snap) => snap.docs.map(HabitModel.fromFirestore).toList());
  }

  /// Returns the count of log items for [habitId] on [date].
  Future<int> dailyLogCount(String habitId, DateTime date) async {
    final dateString =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final snap = await _habitsRef
        .doc(habitId)
        .collection('logs')
        .doc(dateString)
        .collection('items')
        .count()
        .get();
    return snap.count ?? 0;
  }

  /// Returns the sum of quantities for a good habit on [date].
  Future<num> dailyTotal(String habitId, DateTime date) async {
    final dateString =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final snap = await _habitsRef
        .doc(habitId)
        .collection('logs')
        .doc(dateString)
        .collection('items')
        .get();
    num total = 0;
    for (final doc in snap.docs) {
      total += (doc.data()['quantity'] as num?) ?? 1;
    }
    return total;
  }

  Future<void> createHabit(HabitModel habit) async {
    final docRef = _habitsRef.doc(habit.id);
    final batch = _firestore.batch();
    
    batch.set(docRef, habit.toFirestore());

    await _eventService.emit(
      eventName: EventNames.habitCreated,
      payload: {
        'habitId': habit.id,
        'kind': habit.kind.name,
      },
      batch: batch,
    );

    await batch.commit();
  }

  Future<void> logGood(String habitId, {num? amount, String? note, DateTime? occurredAt}) async {
    final now = DateTime.now();
    final occurred = occurredAt ?? now;
    final logId = generateId();
    
    final log = HabitLog(
      logId: logId,
      habitId: habitId,
      occurredAt: occurred,
      loggedAt: now,
      quantity: amount,
      note: note,
    );

    final dateString = "${occurred.year}-${occurred.month.toString().padLeft(2, '0')}-${occurred.day.toString().padLeft(2, '0')}";
    final docRef = _habitsRef.doc(habitId).collection('logs').doc(dateString).collection('items').doc(logId);
    
    final batch = _firestore.batch();
    batch.set(docRef, log.toFirestore());

    await _eventService.emit(
      eventName: EventNames.goodHabitLogged,
      payload: {
        'habitId': habitId,
        'amount': amount,
        'timestamp': occurred.toIso8601String(),
      },
      batch: batch,
    );

    await batch.commit();
  }

  Future<void> logSlip(String habitId, {String? trigger, String? note, DateTime? occurredAt}) async {
    final now = DateTime.now();
    final occurred = occurredAt ?? now;
    final logId = generateId();
    
    final log = HabitLog(
      logId: logId,
      habitId: habitId,
      occurredAt: occurred,
      loggedAt: now,
      trigger: trigger,
      note: note,
    );

    final dateString = "${occurred.year}-${occurred.month.toString().padLeft(2, '0')}-${occurred.day.toString().padLeft(2, '0')}";
    final docRef = _habitsRef.doc(habitId).collection('logs').doc(dateString).collection('items').doc(logId);
    
    final batch = _firestore.batch();
    batch.set(docRef, log.toFirestore());

    await _eventService.emit(
      eventName: EventNames.badHabitSlipLogged,
      payload: {
        'habitId': habitId,
        'trigger': trigger,
        'timestamp': occurred.toIso8601String(),
      },
      batch: batch,
    );

    await batch.commit();
  }
}
