// test/services/suggestion_service_contract_test.dart
//
// Contract tests for SuggestionService.
// All groups are skipped (TODO) — SuggestionService does not yet exist as a
// production file; these tests define the intended public contract so that the
// service can be implemented against them.
//
// Intended public surface (to be implemented):
//   SuggestionService.fetchSuggestions({uid, context})
//   SuggestionService.dismissSuggestion(uid, suggestionId)
//   SuggestionService.acceptSuggestion(uid, suggestionId)
//   SuggestionService.watchPendingSuggestions(uid)
//
// Firestore path (planned):
//   /users/{uid}/suggestions/{suggestionId}

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── fetchSuggestions ─────────────────────────────────────────────────────────

  group('SuggestionService.fetchSuggestions — happy path', () {
    test(
      'TODO: calls backend AI endpoint with uid and context snapshot',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: writes returned suggestions to /users/{uid}/suggestions/{id}',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: each suggestion doc has status == pending and schemaVersion: 1',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: returns list of SuggestionModel instances',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: emits suggestions_fetched event after writing docs',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('SuggestionService.fetchSuggestions — error cases', () {
    test(
      'TODO: throws NotAuthenticatedError when no user is signed in',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: returns empty list when backend returns no suggestions',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: does not throw when backend call fails — returns empty list',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── dismissSuggestion ────────────────────────────────────────────────────────

  group('SuggestionService.dismissSuggestion — happy path', () {
    test(
      'TODO: updates suggestion doc status to dismissed',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: stamps dismissedAt with a server timestamp',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: emits suggestion_dismissed event',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('SuggestionService.dismissSuggestion — error cases', () {
    test(
      'TODO: throws SuggestionNotFoundError when suggestionId does not exist',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── acceptSuggestion ─────────────────────────────────────────────────────────

  group('SuggestionService.acceptSuggestion — happy path', () {
    test(
      'TODO: updates suggestion doc status to accepted',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: stamps acceptedAt with a server timestamp',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: emits suggestion_accepted event',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('SuggestionService.acceptSuggestion — error cases', () {
    test(
      'TODO: throws SuggestionNotFoundError when suggestionId does not exist',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: throws InvalidStateTransitionError when suggestion is already accepted or dismissed',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── watchPendingSuggestions ──────────────────────────────────────────────────

  group('SuggestionService.watchPendingSuggestions', () {
    test(
      'TODO: stream emits only suggestions with status == pending',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: stream updates when a pending suggestion is dismissed',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: stream emits an empty list when no pending suggestions exist',
      () {},
      skip: 'Not yet implemented',
    );
  });
}
