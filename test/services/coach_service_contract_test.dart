// test/services/coach_service_contract_test.dart
//
// Contract tests for CoachService — backend-controlled AI mode.
// The AI Coach Reply MVP group is active; broader legacy contract groups remain
// skipped until those public surfaces exist.
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

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus2/core/config/app_config.dart';
import 'package:optivus2/repositories/user_repository.dart';
import 'package:optivus2/services/cloudflare_api_service.dart';
import 'package:optivus2/services/coach_service.dart';
import 'package:optivus2/services/event_service.dart';
import 'package:optivus2/services/firestore_service.dart';
import 'package:optivus2/services/gemini_service.dart';
import 'package:optivus2/services/habit_service.dart';
import 'package:optivus2/services/streak_service.dart';
import 'package:optivus2/services/task_service.dart';

void main() {
  group('AI Coach Reply MVP', () {
    test('missing endpoint returns a saved friendly fallback', () async {
      final harness = _CoachHarness(
        featureFlags: _featureFlags(aiCoachMessagesReady: true),
        replyClient: ({
          required String threadId,
          required String text,
          required String mode,
        }) async {
          throw const CloudflareConfigException(
            endpointLabel: 'Coach reply endpoint',
            message: 'COACH_REPLY_ENDPOINT is not configured.',
          );
        },
      );

      final reply = await harness.service.generateAndSaveAssistantReply(
        userText: 'Can you help?',
        mode: CoachTopicMode.askAnything,
      );

      expect(reply.isUser, isFalse);
      expect(reply.text, CoachService.missingEndpointFallbackText);

      final messages = await harness.messages();
      expect(messages, hasLength(1));
      expect(messages.single['role'], 'coach');
      expect(messages.single['text'], CoachService.missingEndpointFallbackText);
      expect(messages.single['source'], 'local_missing_endpoint');
      expect(messages.single['fallbackReason'], 'missing_endpoint');
      expect(messages.single['aiGenerated'], isFalse);
    });

    test('AI disabled does not call Worker and returns local fallback',
        () async {
      var workerCalls = 0;
      final harness = _CoachHarness(
        featureFlags: _featureFlags(aiCoachMessagesReady: false),
        buildConfig: _buildConfig(coachReplyEndpoint: 'https://coach.example'),
        replyClient: ({
          required String threadId,
          required String text,
          required String mode,
        }) async {
          workerCalls += 1;
          return const CoachReplyResult(text: 'Should not be used');
        },
      );

      final reply = await harness.service.generateAndSaveAssistantReply(
        userText: 'I need a plan',
        mode: CoachTopicMode.study,
      );

      expect(workerCalls, 0);
      expect(reply.text, CoachService.aiDisabledFallbackText);
      final messages = await harness.messages();
      expect(messages, hasLength(1));
      expect(messages.single['source'], 'local_ai_disabled');
      expect(messages.single['fallbackReason'], 'ai_disabled');
    });

    test('Worker error is surfaced for retry without assistant save', () async {
      final harness = _CoachHarness(
        featureFlags: _featureFlags(aiCoachMessagesReady: true),
        replyClient: ({
          required String threadId,
          required String text,
          required String mode,
        }) async {
          throw const CloudflareServerException(
            endpointLabel: 'Coach reply endpoint',
            message: 'Coach reply endpoint failed with HTTP 502.',
            statusCode: 502,
          );
        },
      );

      await expectLater(
        harness.service.generateAndSaveAssistantReply(
          userText: 'Hello',
          mode: CoachTopicMode.askAnything,
        ),
        throwsA(isA<CloudflareServerException>()),
      );

      expect(await harness.messages(), isEmpty);
    });

    test('successful Worker response maps to one assistant message', () async {
      final harness = _CoachHarness(
        featureFlags: _featureFlags(aiCoachMessagesReady: true),
        replyClient: ({
          required String threadId,
          required String text,
          required String mode,
        }) async {
          return const CoachReplyResult(
            text: 'Start with a 10 minute review block.',
            messageId: 'assistant_1',
            safetyBranch: 'standard',
          );
        },
      );

      final reply = await harness.service.generateAndSaveAssistantReply(
        userText: 'I need to study',
        mode: CoachTopicMode.study,
      );

      expect(reply.id, 'assistant_1');
      expect(reply.text, 'Start with a 10 minute review block.');

      final messages = await harness.messages();
      expect(messages, hasLength(1));
      expect(messages.single['messageId'], 'assistant_1');
      expect(messages.single['role'], 'coach');
      expect(messages.single['text'], 'Start with a 10 minute review block.');
      expect(messages.single['source'], 'cloudflare_coach_reply');
    });

    test(
        'cloudflare assistant message parses as assistant with alternate text key',
        () {
      final message = CoachChatMessage.fromMap(
        {
          'messageId': 'assistant_cloudflare',
          'role': 'coach',
          'source': 'cloudflare_coach_reply',
          'fallbackReason': 'none',
          'aiGenerated': true,
          'reply': 'Use one focused block, then reassess.',
          'createdAt': Timestamp.fromDate(DateTime(2026, 5, 15, 8)),
        },
        fallbackId: 'assistant_cloudflare',
      );

      expect(message.id, 'assistant_cloudflare');
      expect(message.isUser, isFalse);
      expect(message.text, 'Use one focused block, then reassess.');
      expect(message.createdAt, DateTime(2026, 5, 15, 8));
    });

    test('watchLatestMessages includes cloudflare assistant messages',
        () async {
      final harness = _CoachHarness(
        featureFlags: _featureFlags(aiCoachMessagesReady: true),
        replyClient: ({
          required String threadId,
          required String text,
          required String mode,
        }) async {
          return const CoachReplyResult(text: 'unused');
        },
      );

      await harness.writeMessage(
        id: 'assistant_stream',
        data: {
          'messageId': 'assistant_stream',
          'role': 'coach',
          'isUser': false,
          'source': 'cloudflare_coach_reply',
          'fallbackReason': 'none',
          'aiGenerated': true,
          'text': 'This should appear in the Coach tab.',
          'createdAt': Timestamp.fromDate(DateTime(2026, 5, 15, 8)),
        },
      );

      final messages =
          await harness.service.watchLatestMessages(limit: 10).first;

      expect(messages, hasLength(1));
      expect(messages.single.id, 'assistant_stream');
      expect(messages.single.isUser, isFalse);
      expect(messages.single.text, 'This should appear in the Coach tab.');
    });

    test('watchLatestMessages sorts ascending after service reversal',
        () async {
      final harness = _CoachHarness(
        featureFlags: _featureFlags(aiCoachMessagesReady: true),
        replyClient: ({
          required String threadId,
          required String text,
          required String mode,
        }) async {
          return const CoachReplyResult(text: 'unused');
        },
      );

      await harness.writeMessage(
        id: 'newest',
        data: _messageDoc(
          id: 'newest',
          text: 'Newest',
          createdAt: DateTime(2026, 5, 15, 9, 2),
        ),
      );
      await harness.writeMessage(
        id: 'oldest',
        data: _messageDoc(
          id: 'oldest',
          text: 'Oldest',
          createdAt: DateTime(2026, 5, 15, 9),
        ),
      );
      await harness.writeMessage(
        id: 'middle',
        data: _messageDoc(
          id: 'middle',
          text: 'Middle',
          createdAt: DateTime(2026, 5, 15, 9, 1),
        ),
      );

      final messages =
          await harness.service.watchLatestMessages(limit: 10).first;

      expect(messages.map((message) => message.id), [
        'oldest',
        'middle',
        'newest',
      ]);
    });

    test('Worker 200 with empty reply saves empty_response fallback', () async {
      final harness = _CoachHarness(
        featureFlags: _featureFlags(aiCoachMessagesReady: true),
        replyClient: ({
          required String threadId,
          required String text,
          required String mode,
        }) async {
          return const CoachReplyResult(text: '');
        },
      );

      final reply = await harness.service.generateAndSaveAssistantReply(
        userText: 'Say something',
        mode: CoachTopicMode.askAnything,
      );

      expect(reply.text, CoachService.emptyResponseFallbackText);

      final messages = await harness.messages();
      expect(messages, hasLength(1));
      expect(messages.single['source'], 'local_empty_response');
      expect(messages.single['fallbackReason'], 'empty_response');
      expect(messages.single['aiGenerated'], isFalse);
    });

    test('Worker response alternate text key is parsed correctly', () {
      final result = CoachReplyResult.fromMap({
        'message': 'Use one 15 minute focus block.',
        'messageId': 'assistant_alt_key',
        'safetyBranch': 'standard',
      });

      expect(result.text, 'Use one 15 minute focus block.');
      expect(result.messageId, 'assistant_alt_key');
      expect(result.safetyBranch, 'standard');
    });

    test('user and assistant messages are each saved once', () async {
      final harness = _CoachHarness(
        featureFlags: _featureFlags(aiCoachMessagesReady: true),
        replyClient: ({
          required String threadId,
          required String text,
          required String mode,
        }) async {
          return const CoachReplyResult(
            text: 'Pick one concrete next step.',
            messageId: 'assistant_once',
          );
        },
      );

      final user = await harness.service.saveUserMessage(
        text: 'I feel stuck',
        mode: CoachTopicMode.recovery,
      );
      final assistant = await harness.service.generateAndSaveAssistantReply(
        userText: user.text,
        mode: CoachTopicMode.recovery,
      );

      expect(assistant.id, 'assistant_once');

      final messages = await harness.messages();
      expect(messages, hasLength(2));
      expect(
          messages.where((message) => message['role'] == 'user'), hasLength(1));
      expect(
        messages.where((message) => message['role'] == 'coach'),
        hasLength(1),
      );
      expect(
        messages.map((message) => message['messageId']).toSet(),
        hasLength(2),
      );
    });
  });

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

class _CoachHarness {
  static const uid = 'coach_test_uid';

  late final FakeFirebaseFirestore firestore;
  late final MockFirebaseAuth auth;
  late final CoachService service;

  _CoachHarness({
    required AppFeatureFlags featureFlags,
    required CoachReplyClient replyClient,
    AppBuildConfig? buildConfig,
  }) {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(
      mockUser: MockUser(uid: uid),
      signedIn: true,
    );
    final eventService = EventService(firestore: firestore, auth: auth);
    service = CoachService(
      taskService: TaskService(
        eventService: eventService,
        firestore: firestore,
        auth: auth,
      ),
      streakService: StreakService(
        eventService: eventService,
        firestore: firestore,
        auth: auth,
      ),
      habitService: HabitService(
        eventService: eventService,
        firestore: firestore,
        auth: auth,
      ),
      userRepo: UserRepository(
        FirestoreService(db: firestore, auth: auth),
      ),
      featureFlags: featureFlags,
      auth: auth,
      firestore: firestore,
      coachReplyClient: replyClient,
      buildConfig: buildConfig,
      eventEmitter: (
        String eventName,
        Map<String, dynamic> payload, {
        String priority = 'normal',
        String source = 'ui',
      }) async {},
    );
  }

  Future<List<Map<String, dynamic>>> messages() async {
    final snap = await firestore
        .collection('users')
        .doc(uid)
        .collection('coach_messages')
        .get();
    return snap.docs.map((doc) => doc.data()).toList(growable: false);
  }

  Future<void> writeMessage({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return firestore
        .collection('users')
        .doc(uid)
        .collection('coach_messages')
        .doc(id)
        .set(data);
  }
}

Map<String, dynamic> _messageDoc({
  required String id,
  required String text,
  required DateTime createdAt,
}) {
  return {
    'messageId': id,
    'role': 'coach',
    'isUser': false,
    'source': 'cloudflare_coach_reply',
    'fallbackReason': 'none',
    'aiGenerated': true,
    'text': text,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

AppBuildConfig _buildConfig({String coachReplyEndpoint = ''}) {
  return AppBuildConfig(
    features: const CompileTimeFeatureFlags(
      enableR2Uploads: false,
      enableImageRoutineImport: false,
      enableProfileImageUpload: false,
      enableClassTimetableImageImport: false,
      enableHostelMessImageImport: false,
      enableSkinProductImageImport: false,
      enableAiCoachWorker: true,
    ),
    cloudflare: CloudflareEndpointConfig(
      coachReplyEndpoint: coachReplyEndpoint,
      aiGenerateEndpoint: '',
      routineImportEndpoint: '',
    ),
    r2: const R2EndpointConfig(
      signedUploadEndpoint: '',
      deleteUploadEndpoint: '',
    ),
    mapbox: const MapboxClientConfig(accessToken: ''),
  );
}

AppFeatureFlags _featureFlags({required bool aiCoachMessagesReady}) {
  return AppFeatureFlags(
    coachEnabled: true,
    aiFeaturesEnabled: aiCoachMessagesReady,
    aiCoachMessagesReady: aiCoachMessagesReady,
    aiRoutineSuggestionsReady: false,
    aiIdentitySummariesReady: false,
    fitnessAiFeedbackReady: false,
    routineImportWorkerReady: false,
    r2UploadsReady: false,
    profileImageUploadReady: false,
    imageRoutineImportReady: false,
    classTimetableImageImportReady: false,
    hostelMessImageImportReady: false,
    skinProductImageImportReady: false,
    mapboxMapsReady: false,
  );
}
