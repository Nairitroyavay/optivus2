import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus2/services/firestore_service.dart';

void main() {
  group('Firestore schema contract', () {
    test('rules keep Spark-only wording and append-only event writes', () {
      final rules = File('firestore.rules').readAsStringSync();

      expect(rules, isNot(contains('Cloud ' 'Functions')));
      expect(rules, contains('function isKnownUserCollection'));
      expect(rules, contains('function hasNoForbiddenBlobFields'));
      expect(rules, contains('match /{collectionId}/{docId}'));
      expect(rules, isNot(contains('match /{collectionId}/{document=**}')));
      expect(rules, contains('match /events/{eventId}'));
      expect(rules, contains('match /events_recent/{eventId}'));
      expect(rules, contains('match /habits/{habitId}/logs/{logDate}'));
      expect(rules, contains('match /coach_chats/{chatId}/turns/{turnId}'));
      expect(
        RegExp(r'match /events/\{eventId\}[\s\S]*?allow update, delete: if false;')
            .hasMatch(rules),
        isTrue,
      );
      expect(
        RegExp(
          r'match /events_recent/\{eventId\}[\s\S]*?allow update, delete: if false;',
        ).hasMatch(rules),
        isTrue,
      );
    });

    test('export and deletion request rules are create/read safe', () {
      final rules = File('firestore.rules').readAsStringSync();

      expect(rules, contains('function exportRequestIsValid'));
      expect(rules, contains('function deletionRequestIsValid'));
      expect(rules,
          contains("request.resource.data.status in ['requested', 'pending']"));
      expect(
        RegExp(
          r'match /data_exports/\{exportId\}[\s\S]*?allow read: if isOwner\(userId\);[\s\S]*?allow create:[\s\S]*?exportRequestIsValid[\s\S]*?allow update, delete: if false;',
        ).hasMatch(rules),
        isTrue,
      );
      expect(
        RegExp(
          r'match /deletion_requests/\{requestId\}[\s\S]*?allow read: if isOwner\(userId\);[\s\S]*?allow create:[\s\S]*?deletionRequestIsValid[\s\S]*?allow update, delete: if false;',
        ).hasMatch(rules),
        isTrue,
      );
    });

    test('schema docs include every FirestoreService user-owned collection',
        () {
      final schema =
          File('docs/firestore_schema_v1_mapping.md').readAsStringSync();
      final rules = File('firestore.rules').readAsStringSync();

      for (final collectionId in FirestoreService.userOwnedCollectionIds) {
        expect(
          schema,
          contains('/users/{uid}/$collectionId'),
          reason: 'Schema docs must mention $collectionId.',
        );
        expect(
          rules,
          contains("'$collectionId'"),
          reason: 'Rules whitelist must mention $collectionId.',
        );
      }

      expect(schema, contains('objectKey'));
      expect(schema, isNot(contains('Firebase ' 'Storage')));
      expect(schema,
          contains('Rules do not recursively inspect every nested map'));
      expect(schema, contains('Orphaned legacy nested item docs'));
      expect(schema, contains('Client-side cleanup is best-effort only'));
      expect(schema, contains('legacy event documents require a backfill'));
    });

    test('client cleanup skips append-only and request collections', () async {
      final db = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'uid_1'),
      );
      final service = FirestoreService(db: db, auth: auth);
      final userRef = db.collection('users').doc('uid_1');

      await userRef.set({'uid': 'uid_1'});
      await userRef.collection(FirestoreService.kEvents).doc('event_1').set({
        'uid': 'uid_1',
        'eventId': 'event_1',
      });
      await userRef
          .collection(FirestoreService.kEventsRecent)
          .doc('event_1')
          .set({'uid': 'uid_1'});
      await userRef
          .collection(FirestoreService.kDeletionRequests)
          .doc('delete_1')
          .set({'uid': 'uid_1'});
      await userRef
          .collection(FirestoreService.kDataExports)
          .doc('export_1')
          .set({'uid': 'uid_1'});
      await userRef
          .collection(FirestoreService.kGoals)
          .doc('goal_1')
          .set({'uid': 'uid_1'});

      await service.deleteUserOwnedData();

      expect(
        (await userRef.collection(FirestoreService.kGoals).doc('goal_1').get())
            .exists,
        isFalse,
      );
      expect(
        (await userRef
                .collection(FirestoreService.kEvents)
                .doc('event_1')
                .get())
            .exists,
        isTrue,
      );
      expect(
        (await userRef
                .collection(FirestoreService.kEventsRecent)
                .doc('event_1')
                .get())
            .exists,
        isTrue,
      );
      expect(
        (await userRef
                .collection(FirestoreService.kDeletionRequests)
                .doc('delete_1')
                .get())
            .exists,
        isTrue,
      );
      expect(
        (await userRef
                .collection(FirestoreService.kDataExports)
                .doc('export_1')
                .get())
            .exists,
        isTrue,
      );
    });

    test('deletion request helper creates a safe request document', () async {
      final db = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'uid_1'),
      );
      final service = FirestoreService(db: db, auth: auth);

      final requestId = await service.requestAccountDeletion(reason: '  done ');
      final doc = await db
          .collection('users')
          .doc('uid_1')
          .collection(FirestoreService.kDeletionRequests)
          .doc(requestId)
          .get();

      expect(doc.exists, isTrue);
      expect(doc.data()?['requestId'], requestId);
      expect(doc.data()?['uid'], 'uid_1');
      expect(doc.data()?['status'], 'requested');
      expect(doc.data()?['reason'], 'done');
      expect(doc.data()?['schemaVersion'], 1);
    });

    test('exports and deletes legacy nested habit log item copies', () async {
      final db = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'uid_1'),
      );
      final service = FirestoreService(db: db, auth: auth);
      final userRef = db.collection('users').doc('uid_1');
      final occurredAt = Timestamp.fromDate(DateTime(2026, 5, 9, 10));

      await userRef.collection(FirestoreService.kHabits).doc('habit_1').set({
        'uid': 'uid_1',
        'name': 'Hydrate',
      });
      await userRef.collection(FirestoreService.kHabitLogs).doc('log_1').set({
        'uid': 'uid_1',
        'habitId': 'habit_1',
        'occurredAt': occurredAt,
      });
      await userRef
          .collection(FirestoreService.kHabits)
          .doc('habit_1')
          .collection(FirestoreService.kHabitLegacyLogs)
          .doc('2026-05-09')
          .collection(FirestoreService.kHabitLegacyItems)
          .doc('log_1')
          .set({
        'uid': 'uid_1',
        'habitId': 'habit_1',
        'occurredAt': occurredAt,
      });

      final exported =
          jsonDecode(await service.exportUserData()) as Map<String, dynamic>;
      final habits = (exported['collections']
          as Map<String, dynamic>)[FirestoreService.kHabits] as List;
      final habit = habits.single as Map<String, dynamic>;
      final logs = (habit['subcollections']
          as Map<String, dynamic>)[FirestoreService.kHabitLegacyLogs] as List;
      final logDate = logs.single as Map<String, dynamic>;
      final items = (logDate['subcollections']
          as Map<String, dynamic>)[FirestoreService.kHabitLegacyItems] as List;
      expect(items.single, containsPair('id', 'log_1'));

      await service.deleteUserOwnedData();

      final legacyItem = await userRef
          .collection(FirestoreService.kHabits)
          .doc('habit_1')
          .collection(FirestoreService.kHabitLegacyLogs)
          .doc('2026-05-09')
          .collection(FirestoreService.kHabitLegacyItems)
          .doc('log_1')
          .get();
      expect(legacyItem.exists, isFalse);
    });

    test('indexes cover current compound query shapes', () {
      final indexes = _indexes();

      expect(
        _hasIndex(indexes, 'scheduled_notifications', const [
          'routineTemplateId:ASCENDING',
          'scheduledDate:ASCENDING',
          'scheduledTime:ASCENDING',
          'category:ASCENDING',
          'status:ASCENDING',
        ]),
        isTrue,
      );
      expect(
        _hasIndex(indexes, 'scheduled_notifications', const [
          'taskId:ASCENDING',
          'status:ASCENDING',
        ]),
        isTrue,
      );
      expect(
        _hasIndex(indexes, 'suggestions', const [
          'status:ASCENDING',
          'targetSurface:ASCENDING',
        ]),
        isTrue,
      );
      expect(
        _hasIndex(indexes, 'fitnessActivities', const [
          'status:ASCENDING',
          'completedAt:ASCENDING',
        ]),
        isTrue,
      );
      expect(
        _hasIndex(indexes, 'habit_logs', const [
          'habitId:ASCENDING',
          'logType:ASCENDING',
          'occurredAt:ASCENDING',
        ]),
        isTrue,
      );
    });
  });
}

List<Map<String, dynamic>> _indexes() {
  final raw = jsonDecode(File('firestore.indexes.json').readAsStringSync())
      as Map<String, dynamic>;
  return (raw['indexes'] as List)
      .cast<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

bool _hasIndex(
  List<Map<String, dynamic>> indexes,
  String collectionGroup,
  List<String> expectedFields,
) {
  return indexes.any((index) {
    if (index['collectionGroup'] != collectionGroup) return false;
    final fields = (index['fields'] as List)
        .cast<Map>()
        .map((field) => '${field['fieldPath']}:${field['order']}')
        .toList();
    return _listEquals(fields, expectedFields);
  });
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
