import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task_model.dart';
import '../models/goal_model.dart';

class FirestoreService {
  // ── Singleton document IDs ─────────────────────────────────────────────────
  static const String kProfileDoc = 'main';
  static const String kOnboardingDoc = 'state';
  static const String kRoutineDoc = 'current';
  static const String kIdentityProfileDoc = 'main';

  // ── Canonical per-user collection IDs ──────────────────────────────────────
  static const String kProfile = 'profile';
  static const String kOnboarding = 'onboarding';
  static const String kRoutine = 'routine';
  static const String kTasks = 'tasks';
  static const String kTaskOutcomes = 'task_outcomes';
  static const String kHabits = 'habits';
  static const String kHabitLogs = 'habit_logs';
  static const String kStreaks = 'streaks';
  static const String kGoals = 'goals';
  static const String kIdentityProfile = 'identity_profile';
  static const String kEvents = 'events';
  static const String kEventsRecent = 'events_recent';
  static const String kScheduledNotifications = 'scheduled_notifications';
  static const String kNotificationLog = 'notificationLog';
  static const String kSuggestions = 'suggestions';
  static const String kCoachMessages = 'coach_messages';
  static const String kCoachSpeakLog = 'coach_speak_log';
  static const String kCoachChats = 'coach_chats';
  static const String kAiContextSnapshots = 'ai_context_snapshots';
  static const String kDailySummaries = 'dailySummaries';
  static const String kWeeklySummaries = 'weeklySummaries';
  static const String kDevices = 'devices';
  static const String kDataExports = 'data_exports';
  static const String kDeletionRequests = 'deletion_requests';
  static const String kUsage = 'usage';
  static const String kScreenTimeRaw = 'screenTimeRaw';
  static const String kMoneySaved = 'money_saved';
  static const String kMoneySavingsGoals = 'money_savings_goals';

  // ── Fitness engine ─────────────────────────────────────────────────────────
  static const String kFitnessActivities = 'fitnessActivities';
  static const String kFitnessStats = 'fitnessStats';
  static const String kFitnessGoals = 'fitnessGoals';
  static const String kFitnessRoutePoints = 'routePoints';
  static const String kFitnessSplits = 'splits';
  static const String kFitnessHeartRateSamples = 'heartRateSamples';
  static const String kHabitLegacyLogs = 'logs';
  static const String kHabitLegacyItems = 'items';
  static const String kCoachChatTurns = 'turns';

  // ── All user-owned top-level collection IDs ────────────────────────────────
  // Keep in sync with the documented schema paths and with Firestore Rules.
  static const List<String> userOwnedCollectionIds = [
    kProfile,
    kOnboarding,
    kRoutine,
    kTasks,
    kTaskOutcomes,
    kHabits,
    kHabitLogs,
    kStreaks,
    kGoals,
    kIdentityProfile,
    kEvents,
    kEventsRecent,
    kScheduledNotifications,
    kNotificationLog,
    kSuggestions,
    kCoachMessages,
    kCoachSpeakLog,
    kCoachChats,
    kAiContextSnapshots,
    kDailySummaries,
    kWeeklySummaries,
    kDevices,
    kDataExports,
    kDeletionRequests,
    kUsage,
    kScreenTimeRaw,
    kMoneySaved,
    kMoneySavingsGoals,
    kFitnessActivities,
    kFitnessStats,
    kFitnessGoals,
  ];

  static const List<String> clientRestrictedCollectionIds = [
    kEvents,
    kEventsRecent,
    kDataExports,
    kDeletionRequests,
  ];

  static const int _deleteBatchSize = 400;
  static const int _nestedParentDeleteBatchSize = 200;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  FirestoreService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Current authenticated user's UID. Throws if not signed in.
  String get uid => _auth.currentUser!.uid;

  /// Root document: /users/{uid}
  DocumentReference<Map<String, dynamic>> get userDoc =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> userCollection(
    String collectionId,
  ) =>
      userDoc.collection(collectionId);

  DocumentReference<Map<String, dynamic>> userSubdocument(
    String collectionId,
    String docId,
  ) =>
      userCollection(collectionId).doc(docId);

  // ── Generic subcollection helpers ─────────────────────────────────────────

  Future<void> saveUserSubdocument(
    String collectionPath,
    String docId,
    Map<String, dynamic> data, {
    bool merge = true,
  }) =>
      userSubdocument(collectionPath, docId)
          .set(data, merge ? SetOptions(merge: true) : null);

  Future<Map<String, dynamic>?> getUserSubdocument(
    String collectionPath,
    String docId,
  ) async {
    final doc = await userSubdocument(collectionPath, docId).get();
    return doc.exists ? doc.data() : null;
  }

  // ── User root document ─────────────────────────────────────────────────────

  Future<void> saveUserProfile(Map<String, dynamic> data,
          {bool merge = false}) =>
      userDoc.set(data, merge ? SetOptions(merge: true) : null);

  Future<Map<String, dynamic>?> getUserProfile() async {
    final doc = await userDoc.get();
    return doc.exists ? doc.data() : null;
  }

  // ── /users/{uid}/profile/main ─────────────────────────────────────────────

  Future<void> saveProfile(Map<String, dynamic> data) =>
      saveUserSubdocument(kProfile, kProfileDoc, data);

  Future<Map<String, dynamic>?> getProfile() =>
      getUserSubdocument(kProfile, kProfileDoc);

  // ── /users/{uid}/onboarding/state ────────────────────────────────────────

  Future<void> saveOnboardingState(Map<String, dynamic> data) =>
      saveUserSubdocument(kOnboarding, kOnboardingDoc, data);

  Future<Map<String, dynamic>?> getOnboardingState() =>
      getUserSubdocument(kOnboarding, kOnboardingDoc);

  // ── /users/{uid}/identity_profile/main ───────────────────────────────────

  Future<void> saveIdentityProfile(Map<String, dynamic> data) =>
      saveUserSubdocument(kIdentityProfile, kIdentityProfileDoc, data);

  Future<Map<String, dynamic>?> getIdentityProfile() =>
      getUserSubdocument(kIdentityProfile, kIdentityProfileDoc);

  // ── /users/{uid}/tasks/{taskId} ───────────────────────────────────────────

  Future<void> saveTask(TaskModel task) =>
      userSubdocument(kTasks, task.id).set(task.toMap());

  Future<void> saveMaterializedTask(
    TaskModel task, {
    required String sourceRoutineType,
    required String routineTemplateId,
    required String scheduledDate,
    required String repeatRule,
    DateTime? materializedFromTemplateAt,
    bool merge = true,
  }) {
    final materializedAt = materializedFromTemplateAt ?? DateTime.now();
    return userSubdocument(kTasks, task.id).set({
      ...task.toMap(),
      'status': task.state.toJson(),
      'sourceRoutineType': sourceRoutineType,
      'routineTemplateId': routineTemplateId,
      'scheduledDate': scheduledDate,
      'repeatRule': repeatRule,
      'materializedFromTemplateAt': Timestamp.fromDate(materializedAt),
    }, merge ? SetOptions(merge: true) : null);
  }

  Future<List<TaskModel>> getTasks() async {
    final snap = await userCollection(kTasks).get();
    return snap.docs.map((d) => TaskModel.fromMap(d.data())).toList();
  }

  Future<List<TaskModel>> getTasksForDate(
    String scheduledDate, {
    String? status,
    String? sourceRoutineType,
  }) async {
    Query<Map<String, dynamic>> query =
        userCollection(kTasks).where('scheduledDate', isEqualTo: scheduledDate);
    if (status != null) query = query.where('status', isEqualTo: status);
    if (sourceRoutineType != null) {
      query = query.where('sourceRoutineType', isEqualTo: sourceRoutineType);
    }
    final snap = await query.orderBy('plannedStart').get();
    return snap.docs.map((d) => TaskModel.fromMap(d.data())).toList();
  }

  Future<void> deleteTask(String taskId) =>
      userSubdocument(kTasks, taskId).delete();

  Future<void> saveTaskOutcome(String taskId, Map<String, dynamic> data) =>
      saveUserSubdocument(kTaskOutcomes, taskId, data);

  // ── /users/{uid}/goals/{goalId} ───────────────────────────────────────────

  Future<void> saveGoal(GoalModel goal) =>
      userSubdocument(kGoals, goal.goalId).set(goal.toMap());

  Future<List<GoalModel>> getGoals() async {
    final snap = await userCollection(kGoals).get();
    return snap.docs
        .map((d) => GoalModel.fromMap(d.data(), fallbackId: d.id))
        .toList();
  }

  Future<void> deleteGoal(String goalId) =>
      userSubdocument(kGoals, goalId).delete();

  // ── /users/{uid}/routine/current ─────────────────────────────────────────

  Future<void> saveRoutine(Map<String, dynamic> routineMap) =>
      userSubdocument(kRoutine, kRoutineDoc).set(routineMap);

  Future<Map<String, dynamic>?> getRoutine() async {
    final doc = await userSubdocument(kRoutine, kRoutineDoc).get();
    return doc.exists ? doc.data() : null;
  }

  Future<void> saveScheduledNotification(
    String notificationId,
    Map<String, dynamic> data,
  ) =>
      saveUserSubdocument(kScheduledNotifications, notificationId, data);

  Future<void> saveSuggestion(String suggestionId, Map<String, dynamic> data) =>
      saveUserSubdocument(kSuggestions, suggestionId, data);

  Future<void> saveAiContextSnapshot(
    String snapshotId,
    Map<String, dynamic> data,
  ) =>
      saveUserSubdocument(kAiContextSnapshots, snapshotId, data);

  // ── /users/{uid}/coach_messages/{messageId} ───────────────────────────────

  Future<void> saveCoachMessage(String messageId, Map<String, dynamic> data) =>
      userSubdocument(kCoachMessages, messageId).set(data);

  Future<List<Map<String, dynamic>>> getCoachMessages({
    String? sessionId,
    int limit = 50,
  }) async {
    Query<Map<String, dynamic>> q = userCollection(kCoachMessages);
    if (sessionId != null) {
      q = q.where('sessionId', isEqualTo: sessionId);
    }
    q = q.orderBy('createdAt').limitToLast(limit);
    final snap = await q.get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Future<void> saveCoachChatTurn(
    String threadId,
    String turnId,
    Map<String, dynamic> turnData,
  ) {
    final data = {
      ...turnData,
      'id': turnId,
      'threadId': threadId,
      'sessionId': threadId,
      'source': turnData['isUser'] == true ? 'user' : 'coach',
      'createdAt': turnData['timestamp'] ?? FieldValue.serverTimestamp(),
    };
    return saveCoachMessage(turnId, data);
  }

  Future<List<Map<String, dynamic>>> getCoachChatTurns(String threadId) async {
    final canonical = await getCoachMessages(sessionId: threadId, limit: 100);
    if (canonical.isNotEmpty) return canonical;

    // Legacy read-only fallback for pre-v1 chat history.
    final snap = await userDoc
        .collection('coach_chats')
        .doc(threadId)
        .collection('turns')
        .orderBy('timestamp')
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  // ── Account Export & Deletion ─────────────────────────────────────────────

  List<String> get clientDeletableCollectionIds => userOwnedCollectionIds
      .where((collectionId) =>
          !clientRestrictedCollectionIds.contains(collectionId))
      .toList(growable: false);

  Future<String> requestAccountDeletion({String? reason}) async {
    final currentUid = uid;
    final requestId = 'delete_${DateTime.now().toUtc().microsecondsSinceEpoch}';
    await userSubdocument(kDeletionRequests, requestId).set({
      'requestId': requestId,
      'uid': currentUid,
      'requestedAt': FieldValue.serverTimestamp(),
      'status': 'requested',
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      'schemaVersion': 1,
    });
    return requestId;
  }

  Future<String> exportUserData() async {
    final currentUid = uid;
    final exportData = <String, dynamic>{
      'uid': currentUid,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'root': <String, dynamic>{},
      'collections': <String, dynamic>{},
    };

    final profileDoc = await userDoc.get();
    exportData['root'] = {
      'path': profileDoc.reference.path,
      'exists': profileDoc.exists,
      if (profileDoc.exists) 'data': _toJsonValue(profileDoc.data()),
    };

    for (final collectionId in userOwnedCollectionIds) {
      exportData['collections'][collectionId] =
          await _exportCollectionDocuments(
        collectionId,
        userDoc.collection(collectionId),
      );
    }

    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  /// Best-effort client cleanup for data that rules allow clients to delete.
  ///
  /// This is not full account deletion. Append-only audit/request collections
  /// are intentionally skipped because Firestore Rules deny client deletion.
  /// Full account deletion is handled by a later account lifecycle flow that
  /// starts with [requestAccountDeletion].
  Future<void> deleteUserOwnedData() async {
    for (final collectionId in clientDeletableCollectionIds) {
      await _deleteCollectionDocuments(
        collectionId,
        userDoc.collection(collectionId),
      );
    }
  }

  @Deprecated(
    'Use requestAccountDeletion for account deletion, or '
    'deleteUserOwnedData for best-effort client cleanup. This helper is not '
    'full account deletion.',
  )
  Future<void> deleteAllUserData() => deleteUserOwnedData();

  Future<List<Map<String, dynamic>>> _exportCollectionDocuments(
    String collectionId,
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    final snap = await collection.orderBy(FieldPath.documentId).get();
    final docs = <Map<String, dynamic>>[];

    for (final doc in snap.docs) {
      final nested = await _exportKnownNestedSubcollections(
        collectionId,
        doc.reference,
      );
      docs.add({
        'id': doc.id,
        'path': doc.reference.path,
        'data': _toJsonValue(doc.data()),
        if (nested.isNotEmpty) 'subcollections': nested,
      });
    }

    return docs;
  }

  Future<Map<String, dynamic>> _exportKnownNestedSubcollections(
    String collectionId,
    DocumentReference<Map<String, dynamic>> parent,
  ) async {
    final nested = <String, dynamic>{};

    if (collectionId == kFitnessActivities) {
      for (final subcollectionId in [
        kFitnessRoutePoints,
        kFitnessSplits,
        kFitnessHeartRateSamples,
      ]) {
        nested[subcollectionId] = await _exportSubcollectionDocuments(
          parent.collection(subcollectionId),
        );
      }
    } else if (collectionId == kCoachChats) {
      nested[kCoachChatTurns] = await _exportSubcollectionDocuments(
        parent.collection(kCoachChatTurns),
      );
    } else if (collectionId == kHabits) {
      nested[kHabitLegacyLogs] = await _exportHabitLegacyLogs(parent);
    }

    nested.removeWhere((_, value) => value is List && value.isEmpty);
    return nested;
  }

  Future<List<Map<String, dynamic>>> _exportHabitLegacyLogs(
    DocumentReference<Map<String, dynamic>> habitRef,
  ) async {
    final canonicalLogs = await userCollection(kHabitLogs)
        .where('habitId', isEqualTo: habitRef.id)
        .get();
    final byDate = <String, List<Map<String, dynamic>>>{};

    for (final logDoc in canonicalLogs.docs) {
      final dateKey = _dateKeyFromValue(logDoc.data()['occurredAt']);
      if (dateKey == null) continue;

      final itemRef = habitRef
          .collection(kHabitLegacyLogs)
          .doc(dateKey)
          .collection(kHabitLegacyItems)
          .doc(logDoc.id);
      final itemDoc = await itemRef.get();
      if (!itemDoc.exists) continue;

      byDate.putIfAbsent(dateKey, () => <Map<String, dynamic>>[]).add({
        'id': itemDoc.id,
        'path': itemDoc.reference.path,
        'data': _toJsonValue(itemDoc.data()),
      });
    }

    final entries = byDate.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries
        .map(
          (entry) => {
            'id': entry.key,
            'path': habitRef.collection(kHabitLegacyLogs).doc(entry.key).path,
            'subcollections': {
              kHabitLegacyItems: entry.value,
            },
          },
        )
        .toList();
  }

  Future<void> _deleteHabitLegacyLogs(
    DocumentReference<Map<String, dynamic>> habitRef,
  ) async {
    final canonicalLogs = await userCollection(kHabitLogs)
        .where('habitId', isEqualTo: habitRef.id)
        .get();

    for (var start = 0;
        start < canonicalLogs.docs.length;
        start += _nestedParentDeleteBatchSize) {
      final batch = _db.batch();
      final dateDocsDeletedInBatch = <String>{};
      for (final logDoc in canonicalLogs.docs
          .skip(start)
          .take(_nestedParentDeleteBatchSize)) {
        final dateKey = _dateKeyFromValue(logDoc.data()['occurredAt']);
        if (dateKey == null) continue;
        final logDateRef = habitRef.collection(kHabitLegacyLogs).doc(dateKey);
        batch.delete(
          logDateRef.collection(kHabitLegacyItems).doc(logDoc.id),
        );
        if (dateDocsDeletedInBatch.add(dateKey)) {
          batch.delete(logDateRef);
        }
      }
      await batch.commit();
    }
  }

  String? _dateKeyFromValue(Object? value) {
    DateTime? date;
    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else if (value is String) {
      date = DateTime.tryParse(value);
    }
    if (date == null) return null;
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<List<Map<String, dynamic>>> _exportSubcollectionDocuments(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    final snap = await collection.orderBy(FieldPath.documentId).get();
    return snap.docs
        .map(
          (doc) => {
            'id': doc.id,
            'path': doc.reference.path,
            'data': _toJsonValue(doc.data()),
          },
        )
        .toList();
  }

  Future<void> _deleteCollectionDocuments(
    String collectionId,
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final snap = await collection.limit(_deleteBatchSize).get();
      if (snap.docs.isEmpty) return;

      final batch = _db.batch();
      for (final doc in snap.docs) {
        await _deleteKnownNestedSubcollections(collectionId, doc.reference);
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (snap.docs.length < _deleteBatchSize) return;
    }
  }

  Future<void> _deleteKnownNestedSubcollections(
    String collectionId,
    DocumentReference<Map<String, dynamic>> parent,
  ) async {
    if (collectionId == kFitnessActivities) {
      for (final subcollectionId in [
        kFitnessRoutePoints,
        kFitnessSplits,
        kFitnessHeartRateSamples,
      ]) {
        await _deleteNestedSubcollection(parent.collection(subcollectionId));
      }
    } else if (collectionId == kCoachChats) {
      await _deleteNestedSubcollection(parent.collection(kCoachChatTurns));
    } else if (collectionId == kHabits) {
      await _deleteHabitLegacyLogs(parent);
    }
  }

  Future<void> _deleteNestedSubcollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final snap = await collection.limit(_deleteBatchSize).get();
      if (snap.docs.isEmpty) return;

      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (snap.docs.length < _deleteBatchSize) return;
    }
  }

  Object? _toJsonValue(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is GeoPoint) {
      return {'latitude': value.latitude, 'longitude': value.longitude};
    }
    if (value is DocumentReference) return value.path;
    if (value is Iterable) return value.map(_toJsonValue).toList();
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _toJsonValue(entry.value),
      };
    }
    return value.toString();
  }
}
