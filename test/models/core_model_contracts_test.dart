import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus2/models/account_lifecycle_request_model.dart';
import 'package:optivus2/models/routine_import_preview_model.dart';
import 'package:optivus2/models/routine_template_model.dart';
import 'package:optivus2/models/suggestion_model.dart';
import 'package:optivus2/models/usage_model.dart';

void main() {
  group('SuggestionModel', () {
    test('handles legacy ids, missing lists/maps, timestamps, and extras', () {
      final createdAt = DateTime.utc(2026, 5, 9, 10);
      final model = SuggestionModel.fromMap({
        'id': 'legacy_suggestion',
        'title': 'Try one anchor',
        'message': 'Fallback body',
        'status': 'generated',
        'createdAt': Timestamp.fromDate(createdAt),
        'legacyScore': 0.8,
      });

      expect(model.suggestionId, 'legacy_suggestion');
      expect(model.body, 'Fallback body');
      expect(model.suggestionIds, isEmpty);
      expect(model.metadata, isEmpty);
      expect(model.createdAt?.toUtc(), createdAt);
      expect(model.extra['legacyScore'], 0.8);

      final map = model.toMap();
      expect(map['suggestionId'], 'legacy_suggestion');
      expect(map['id'], 'legacy_suggestion');
      expect(map['message'], 'Fallback body');
      expect(map['suggestionIds'], isEmpty);
      expect(map['metadata'], isEmpty);
      expect(map['legacyScore'], 0.8);
    });
  });

  group('RoutineTemplateModel', () {
    test(
        'normalizes legacy template fields and preserves routine-specific data',
        () {
      final updatedAt = DateTime.utc(2026, 5, 9, 11);
      final model = RoutineTemplateModel.fromMap({
        'id': 'legacy_template',
        'name': 'Vitamin D',
        'routineType': 'supplements',
        'time': '8:15 AM',
        'weekdayRule': 'daily',
        'steps': null,
        'warnings': 'Check label',
        'confidence': '0.66',
        'updatedAt': updatedAt.toIso8601String(),
        'dosage': '1000 IU',
        '_suggestionId': 'suggestion_1',
      });

      expect(model.templateId, 'legacy_template');
      expect(model.title, 'Vitamin D');
      expect(model.startTime, '08:15');
      expect(model.steps, isEmpty);
      expect(model.warnings, ['Check label']);
      expect(model.confidence, closeTo(0.66, 0.001));
      expect(model.updatedAt, updatedAt);

      final map = model.toMap();
      expect(map['id'], 'legacy_template');
      expect(map['name'], 'Vitamin D');
      expect(map['dosage'], '1000 IU');
      expect(map['_suggestionId'], 'suggestion_1');
      expect(map['weekdayRule'], 'daily');
      expect(map['time'], '8:15 AM');
      expect(map['steps'], isEmpty);
      expect(map['warnings'], ['Check label']);
    });
  });

  group('RoutineImportPreviewModel', () {
    test('parses alternate Worker response keys and attaches suggestion ids',
        () {
      final preview = RoutineImportPreviewModel.fromMap(
        {
          'items': [
            {
              'templateId': 'skin_1',
              'title': 'Cleanse',
              'time': '7:30 PM',
              'productType': 'cleanser',
              'imageMetadata': {
                'objectKey': 'users/uid/uploads/skin/cleanser.jpg',
                'provider': 'cloudflare_r2',
              },
            },
          ],
          'suggestionIds': ['suggestion_1'],
          'metadata': {'workerVersion': 'v1'},
          'requestId': 'preview_1',
        },
        routineType: 'skin_care',
        mode: 'skin_care_text',
      );

      expect(preview.templates, hasLength(1));
      expect(preview.templates.single.routineType, 'skin_care');
      expect(preview.templates.single.startTime, '19:30');
      expect(preview.metadata, {'workerVersion': 'v1'});
      expect(preview.extra['requestId'], 'preview_1');
      final templateMap = preview.templateMaps.single;
      expect(templateMap['_suggestionId'], 'suggestion_1');
      expect(templateMap['productType'], 'cleanser');
      expect(templateMap['imageMetadata'], {
        'objectKey': 'users/uid/uploads/skin/cleanser.jpg',
        'provider': 'cloudflare_r2',
      });
      expect(templateMap['steps'], isEmpty);
      expect(templateMap['warnings'], isEmpty);
      expect(templateMap['metadata'], isEmpty);
    });

    test('parses templates and blocks response variants', () {
      final templatesPreview = RoutineImportPreviewModel.fromMap(
        {
          'templates': [
            {'templateId': 'class_1', 'title': 'Biology'}
          ],
        },
        routineType: 'classes',
      );
      final blocksPreview = RoutineImportPreviewModel.fromMap(
        {
          'blocks': [
            {'templateId': 'meal_1', 'title': 'Lunch'}
          ],
        },
        routineType: 'eating',
      );

      expect(templatesPreview.templateMaps.single['routineType'], 'classes');
      expect(blocksPreview.templateMaps.single['routineType'], 'eating');
    });
  });

  group('UsageModel', () {
    test('defaults missing maps and parses numeric counters safely', () {
      final model = UsageModel.fromMap({
        'monthKey': '2026-05',
        'aiRequests': '3',
        'routineImportPreviews': 2.4,
        'createdAt': '2026-05-01T00:00:00.000Z',
        'legacyLimit': 10,
      });

      expect(model.monthKey, '2026-05');
      expect(model.aiRequests, 3);
      expect(model.routineImportPreviews, 2);
      expect(model.counters, isEmpty);
      expect(model.limits, isEmpty);
      expect(model.extra['legacyLimit'], 10);
      expect(model.toMap()['counters'], isEmpty);
      expect(model.toMap()['limits'], isEmpty);
    });
  });

  group('AccountLifecycleRequestModel', () {
    test('keeps broad deletion map for full read round-trip', () {
      final model = AccountLifecycleRequestModel.fromMap(
        {
          'id': 'delete_1',
          'uid': 'uid_1',
          'status': 'pending',
          'createdAt': Timestamp.fromDate(DateTime.utc(2026, 5, 9)),
          'reason': 'done',
          'backendNote': 'preserved',
        },
        type: AccountLifecycleRequestType.deletion,
      );

      final map = model.toMap();
      expect(model.requestId, 'delete_1');
      expect(model.status, 'pending');
      expect(map['requestId'], 'delete_1');
      expect(map['reason'], 'done');
      expect(map, isNot(contains('metadata')));
      expect(map['backendNote'], 'preserved');
    });

    test('safe deletion client create map matches Firestore rules', () {
      final requestedAt = Timestamp.fromDate(DateTime.utc(2026, 5, 9));
      final model = AccountLifecycleRequestModel(
        requestId: 'delete_1',
        uid: 'uid_1',
        type: AccountLifecycleRequestType.deletion,
        status: 'completed',
        reason: 'done',
        updatedAt: DateTime.utc(2026, 5, 10),
        completedAt: DateTime.utc(2026, 5, 11),
        metadata: const {'resultObject': 'must-not-leak'},
        extra: const {'backendNote': 'must-not-leak'},
      );

      expect(model.toMap()['status'], 'completed');
      expect(model.toMap(), contains('updatedAt'));
      expect(model.toMap(), contains('metadata'));

      final createMap =
          model.toClientCreateMap(requestedAtOverride: requestedAt);
      expect(createMap, {
        'requestId': 'delete_1',
        'uid': 'uid_1',
        'requestedAt': requestedAt,
        'status': 'requested',
        'reason': 'done',
        'schemaVersion': 1,
      });
    });

    test('safe export client create map matches Firestore rules', () {
      final requestedAt = Timestamp.fromDate(DateTime.utc(2026, 5, 9));
      final model = AccountLifecycleRequestModel(
        requestId: 'export_1',
        uid: 'uid_1',
        type: AccountLifecycleRequestType.dataExport,
        status: 'pending',
        requestedAt: DateTime.utc(2026, 5, 9),
        updatedAt: DateTime.utc(2026, 5, 10),
        format: 'json',
        metadata: const {'signedUrl': 'must-not-leak'},
      );

      final map = model.toMap();
      expect(map['exportId'], 'export_1');
      expect(map, isNot(contains('requestId')));
      expect(map['status'], 'pending');
      expect(map['schemaVersion'], 1);
      expect(map, contains('updatedAt'));
      expect(map, contains('metadata'));

      final createMap =
          model.toClientCreateMap(requestedAtOverride: requestedAt);
      expect(createMap, {
        'exportId': 'export_1',
        'uid': 'uid_1',
        'requestedAt': requestedAt,
        'status': 'pending',
        'format': 'json',
        'schemaVersion': 1,
      });
    });
  });
}
