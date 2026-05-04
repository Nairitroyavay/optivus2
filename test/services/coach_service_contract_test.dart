// test/services/coach_service_contract_test.dart
//
// Contract tests for CoachService — backend-controlled AI mode.
// All groups are skipped (TODO) — the backend-safe AI call path, safety routing,
// speak budget, and topic modes are not yet fully implemented.
//
// Intended public surface (partially implemented in lib/services/coach_service.dart):
//   CoachService.sendMessage(uid, text, {mode}) → CoachMessage
//   CoachService.getRecentMessages(uid) → List<CoachMessage>
//   CoachService.canSpeak(uid) → bool
//   CoachService.buildContextSnapshot(uid) → ContextSnapshot
//
// Firestore paths:
//   /users/{uid}/coach_messages/{messageId}
//   /users/{uid}/coach_chats/{chatId}/turns/{turnId}
//   /users/{uid}/coach_speak_log/{logId}
//   /users/{uid}/ai_context_snapshots/{snapshotId}
//
// Events:
//   coach_message_sent, coach_replied

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── sendMessage — happy path ─────────────────────────────────────────────────

  group('CoachService.sendMessage — happy path', () {
    test(
      'TODO: writes user message to /users/{uid}/coach_messages with role=user',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: calls backend aiGenerate callable — never calls AI SDK directly from client',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: writes coach reply to /users/{uid}/coach_messages with role=coach',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: emits coach_message_sent event with payload containing messageId and mode',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: emits coach_replied event after backend response is persisted',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: returned CoachMessage contains non-empty text and a valid timestamp',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── sendMessage — topic modes ────────────────────────────────────────────────

  group('CoachService.sendMessage — topic modes', () {
    test(
      'TODO: mode=Recovery passes recovery context to aiGenerate payload',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: mode=Study passes study context to aiGenerate payload',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: mode=Fitness passes fitness context to aiGenerate payload',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: mode=Calm passes calm context to aiGenerate payload',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: mode=AskAnything does not add a topic filter to the payload',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── safety routing ───────────────────────────────────────────────────────────

  group('CoachService.sendMessage — safety routing', () {
    test(
      'TODO: crisis-like input text routes to safety branch, not normal coaching',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: safety branch response does not contain motivational coaching copy',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: safety branch still writes a coach_message doc with safetyBranch=true',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: normal input does not set safetyBranch=true on the reply doc',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── speak budget ─────────────────────────────────────────────────────────────

  group('CoachService.canSpeak', () {
    test(
      'TODO: returns true when coach_speak_log count for today is below the daily cap',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: returns false when coach_speak_log count for today meets or exceeds the daily cap',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: cap value is read from Remote Config, not hard-coded',
      () {},
      skip: 'Not yet implemented',
    );
  });

  group('CoachService.sendMessage — speak budget enforcement', () {
    test(
      'TODO: throws BudgetExceededError when canSpeak returns false',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: logs each successful send to /users/{uid}/coach_speak_log',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── backend key safety ───────────────────────────────────────────────────────

  group('CoachService — backend key safety', () {
    test(
      'TODO: AI API key is never included in any value returned to Flutter',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: raw AI response text is never forwarded verbatim without sanitization',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── getRecentMessages ────────────────────────────────────────────────────────

  group('CoachService.getRecentMessages', () {
    test(
      'TODO: returns messages ordered by timestamp ascending',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: returns empty list when no messages exist',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: each message has role (user|coach), text, and a valid timestamp',
      () {},
      skip: 'Not yet implemented',
    );
  });

  // ── buildContextSnapshot ─────────────────────────────────────────────────────

  group('CoachService.buildContextSnapshot', () {
    test(
      'TODO: snapshot includes profile, recent tasks, habit logs, goals, and streak states',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: snapshot is written to /users/{uid}/ai_context_snapshots with a fresh timestamp',
      () {},
      skip: 'Not yet implemented',
    );

    test(
      'TODO: snapshot does not include other users\' data',
      () {},
      skip: 'Not yet implemented',
    );
  });
}
