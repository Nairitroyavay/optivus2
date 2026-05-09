// lib/services/gemini_service.dart

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:optivus2/core/config/app_config.dart';
import 'package:optivus2/core/constants/event_names.dart';
import 'package:optivus2/services/event_service.dart';

const String _localRunDartDefines = 'Required local run flags:\n'
    '--dart-define=COACH_REPLY_ENDPOINT=https://...\n'
    '--dart-define=AI_GENERATE_ENDPOINT=https://...\n'
    '--dart-define=ROUTINE_IMPORT_ENDPOINT=https://...';

class CoachReplyResult {
  final String text;
  final List<String> suggestedActions;
  final String? messageId;
  final String? safetyBranch;

  const CoachReplyResult({
    required this.text,
    this.suggestedActions = const [],
    this.messageId,
    this.safetyBranch,
  });

  factory CoachReplyResult.fromCallableData(Object? data) {
    final map = Map<String, dynamic>.from(data as Map);
    return CoachReplyResult.fromMap(map);
  }

  factory CoachReplyResult.fromMap(Map<String, dynamic> map) {
    final actions = (map['suggestedActions'] as List? ?? const [])
        .map((action) => action.toString())
        .where((action) => action.trim().isNotEmpty)
        .toList(growable: false);

    return CoachReplyResult(
      text: (map['text'] as String? ?? map['reply'] as String? ?? '').trim(),
      suggestedActions: actions,
      messageId: map['messageId'] as String?,
      safetyBranch: map['safetyBranch'] as String?,
    );
  }
}

class GeminiService {
  // Singleton instance
  static final GeminiService _instance = GeminiService._internal();
  final AppBuildConfig _buildConfig;

  factory GeminiService() {
    return _instance;
  }

  GeminiService._internal() : _buildConfig = AppBuildConfig.current;

  GeminiService.forConfig({
    required AppBuildConfig buildConfig,
  }) : _buildConfig = buildConfig;

  /// Interactive coach reply via the Cloudflare `coachReply` endpoint.
  ///
  /// The Worker verifies the Firebase ID token and calls Gemini server-side so
  /// the Gemini key is never shipped in Flutter.
  Future<CoachReplyResult> coachReply({
    required String userId,
    required String threadId,
    required String text,
    required String mode,
  }) async {
    final decoded = await _postAuthenticatedJson(
      endpoint: _buildConfig.cloudflare.normalizedCoachReplyEndpoint,
      dartDefineName: 'COACH_REPLY_ENDPOINT',
      endpointLabel: 'Coach reply endpoint',
      payload: {
        'userId': userId,
        'threadId': threadId,
        'text': text,
        'mode': mode,
      },
    );

    final result = CoachReplyResult.fromMap(
      decoded,
    );
    if (result.text.isEmpty) {
      throw Exception('Empty coach reply from endpoint');
    }
    return result;
  }

  /// Single-shot text generation via the Cloudflare `aiGenerate` endpoint.
  Future<String> generate({
    required String systemPrompt,
    required String userMessage,
    List<Map<String, dynamic>>? history,
  }) async {
    final decoded = await _postAuthenticatedJson(
      endpoint: _buildConfig.cloudflare.normalizedAiGenerateEndpoint,
      dartDefineName: 'AI_GENERATE_ENDPOINT',
      endpointLabel: 'AI generation endpoint',
      payload: {
        'systemPrompt': systemPrompt,
        'userMessage': userMessage,
        if (history != null) 'history': history,
      },
    );

    final text = decoded['text'] as String?;
    if (text != null) {
      return text.trim();
    } else {
      throw Exception('Failed fetching AI generation or empty response');
    }
  }

  Future<String> generateOnce(String promptTemplate) {
    return generate(
      systemPrompt:
          'You are the Optivus coach. Return only the final coach message text, with no JSON or markdown.',
      userMessage: promptTemplate,
    );
  }

  /// Rule-triggered generation with full context payload.
  ///
  /// The Worker receives the [contextPayload] (onboarding data,
  /// today's tasks, streaks, rule intent, etc.) and builds an enriched
  /// system prompt server-side.  The LLM generates text — it does NOT
  /// decide whether to speak; that decision was already made by the rule
  /// engine before this method is called.
  Future<String> generateWithContext({
    required String rulePrompt,
    required Map<String, dynamic> contextPayload,
  }) async {
    debugPrint(
      '[GeminiService] Calling aiGenerate after rule selection: '
      'ruleId=${contextPayload['ruleId'] ?? "unknown"} '
      'intent=${contextPayload['ruleIntent'] ?? "unknown"}',
    );

    final decoded = await _postAuthenticatedJson(
      endpoint: _buildConfig.cloudflare.normalizedAiGenerateEndpoint,
      dartDefineName: 'AI_GENERATE_ENDPOINT',
      endpointLabel: 'AI generation endpoint',
      payload: {
        'contextPayload': {
          ...contextPayload,
          'rulePrompt': rulePrompt,
        },
      },
    );

    final text = decoded['text'] as String?;
    if (text != null) {
      return text.trim();
    } else {
      throw Exception('Failed fetching AI generation or empty response');
    }
  }

  /// Start a multi-turn chat
  GeminiChatSession startChat(
    String systemPrompt, {
    List<Map<String, dynamic>>? initialHistory,
    String threadId = 'main_thread',
    String mode = 'chat',
  }) {
    return GeminiChatSession(
      systemPrompt: systemPrompt,
      service: this,
      initialHistory: initialHistory,
      threadId: threadId,
      mode: mode,
    );
  }

  Future<Map<String, dynamic>> _postAuthenticatedJson({
    required String endpoint,
    required String dartDefineName,
    required String endpointLabel,
    required Map<String, dynamic> payload,
  }) async {
    if (endpoint.isEmpty) {
      throw Exception(
        '$dartDefineName is not configured. $_localRunDartDefines',
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Cannot call $endpointLabel without auth token');
    }

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        '$endpointLabel failed: ${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('$endpointLabel returned invalid JSON');
    }

    return Map<String, dynamic>.from(decoded);
  }
}

class GeminiChatSession {
  final String systemPrompt;
  final GeminiService service;
  final String threadId;
  final String mode;

  // Track chat history locally
  final List<Map<String, dynamic>> _history;

  GeminiChatSession({
    required this.systemPrompt,
    required this.service,
    required this.threadId,
    required this.mode,
    List<Map<String, dynamic>>? initialHistory,
  }) : _history = initialHistory ?? [];

  void appendModelMessage(String message) {
    _history.add({
      'role': 'model',
      'parts': [
        {'text': message},
      ],
    });
  }

  Future<String> sendMessage(String message) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Cannot send coach message without auth');
      }

      try {
        await EventService().emit(
          eventName: EventNames.coachMessageSent,
          payload: {'text': message},
          source: 'ui',
        );
      } catch (e) {
        debugPrint('[GeminiChatSession] coach_message_sent event failed: $e');
      }

      final result = await service.coachReply(
        userId: user.uid,
        threadId: threadId,
        text: message,
        mode: mode,
      );
      final reply = result.text;

      // Update history after successful generation
      _history.add({
        'role': 'user',
        'parts': [
          {'text': message}
        ],
      });
      _history.add({
        'role': 'model',
        'parts': [
          {'text': reply}
        ],
      });

      return reply;
    } catch (e) {
      rethrow;
    }
  }
}
