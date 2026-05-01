// test/services/event_service_contract_test.dart
//
// Contract tests for EventService.
// All groups are skipped (TODO) — implement with fake Firestore / fake Auth
// once the firebase_auth_mocks / fake_cloud_firestore packages are added as
// dev-dependencies.
//
// Public surface under test:
//   EventService.emit(...)
//   EventService.on(eventName)
//   EventService.onAny()
//   EventService.replayRecentEvents()
//   EventService.dispose()

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── emit ────────────────────────────────────────────────────────────────────

  group('EventService.emit — happy path', () {
    test(
      'TODO: writes doc to /users/{uid}/events/{eventId}',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: writes doc to /users/{uid}/events_recent/{eventId}',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: publishes event on the local _eventBus stream',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: persists eventId to SharedPreferences processed-id cache',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('EventService.emit — idempotency / deduplication', () {
    test(
      'TODO: skips write when Firestore doc already exists for the same eventId',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: generates deterministic eventId from eventName + ts + payload',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: caller-supplied eventId overrides deterministic ID',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('EventService.emit — WriteBatch passthrough', () {
    test(
      'TODO: when batch is provided, sets docs on batch instead of committing',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('EventService.emit — error cases', () {
    test(
      'TODO: throws NotAuthenticatedError when no user is signed in',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── on / onAny ──────────────────────────────────────────────────────────────

  group('EventService.on', () {
    test(
      'TODO: returns stream that emits only events matching eventName',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: does not emit events with a different eventName',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('EventService.onAny', () {
    test(
      'TODO: emits every event regardless of eventName',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── replayRecentEvents ───────────────────────────────────────────────────────

  group('EventService.replayRecentEvents', () {
    test(
      'TODO: publishes unprocessed events from events_recent on the local bus',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: skips events whose IDs are already in the processed cache',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: replays events in chronological (ascending ts) order',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: limits replay to the 50 most recent documents',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: does not throw when events_recent collection is empty',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── dispose ─────────────────────────────────────────────────────────────────

  group('EventService.dispose', () {
    test(
      'TODO: closes the internal StreamController without error',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: after dispose, emit does not publish on a closed sink',
      () {},
      skip: 'Not yet implemented',
    );
  });
}
