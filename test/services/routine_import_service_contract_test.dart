// test/services/routine_import_service_contract_test.dart
//
// Contract tests for RoutineImportService.
// All groups are skipped (TODO) — RoutineImportService does not yet exist as a
// production file; these tests define the intended public contract so that the
// service can be implemented against them.
//
// Intended public surface (to be implemented):
//   RoutineImportService.previewFromText(uid, sourceText, category) → List<RoutineBlock>
//   RoutineImportService.previewFromImage(uid, imageBytes, category) → List<RoutineBlock>
//   RoutineImportService.acceptImport(uid, blocks, metadata) → RoutineImportResult
//   RoutineImportService.importFromText(uid, sourceText, category) → RoutineImportResult
//   RoutineImportService.importFromImage(uid, imageBytes, category) → RoutineImportResult
//
// Backend dependency (planned):
//   functions/ai/routineImport.js callable
//
// Firestore paths (planned):
//   /users/{uid}/routine/current
//   /users/{uid}/tasks/{taskId}
//   /users/{uid}/suggestions/{suggestionId}

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── previewFromText ──────────────────────────────────────────────────────────

  group('RoutineImportService.previewFromText — happy path', () {
    test(
      'TODO: calls routineImport backend callable with mode=text and sourceText',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: returns a non-empty list of RoutineBlock objects',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: each returned block has a non-empty title and valid startTime',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: category param scopes the blocks (e.g. supplements, skinCare, eating)',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('RoutineImportService.previewFromText — error cases', () {
    test(
      'TODO: throws NotAuthenticatedError when no user is signed in',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: throws ValidationError when sourceText is empty',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: returns empty list and does not throw when backend returns no blocks',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: does not write to Firestore during preview — preview is side-effect-free',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── previewFromImage ─────────────────────────────────────────────────────────

  group('RoutineImportService.previewFromImage — happy path', () {
    test(
      'TODO: calls routineImport backend callable with mode=image and imageMetadata',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: returns extracted blocks from OCR pipeline',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: each block title is non-empty after OCR extraction',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('RoutineImportService.previewFromImage — error cases', () {
    test(
      'TODO: throws ValidationError when imageBytes is empty',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: throws UnsupportedOperationError when OCR backend is unavailable',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── acceptImport ─────────────────────────────────────────────────────────────

  group('RoutineImportService.acceptImport — happy path', () {
    test(
      'TODO: writes accepted blocks to /users/{uid}/routine/current',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: materialises task docs for the next 14 days in /users/{uid}/tasks',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: emits routine_template_imported event with blocksImported count',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: returns RoutineImportResult with success=true and tasksCreated count',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: routine/current doc contains schemaVersion: 1 and updatedAt timestamp',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('RoutineImportService.acceptImport — error cases', () {
    test(
      'TODO: throws ValidationError when blocks list is null',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: returns RoutineImportResult with success=false and errors list when write fails',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── idempotency ──────────────────────────────────────────────────────────────

  group('RoutineImportService.acceptImport — idempotency', () {
    test(
      'TODO: importing the same template twice does not duplicate task docs',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: second import overwrites routine/current but preserves in-progress task states',
      () {},
      skip: 'Not yet implemented',
    );
  });
}
