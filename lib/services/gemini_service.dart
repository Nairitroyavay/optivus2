// lib/services/gemini_service.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class GeminiService {
  // Singleton instance
  static final GeminiService _instance = GeminiService._internal();

  factory GeminiService() {
    return _instance;
  }

  GeminiService._internal();

  /// Single-shot text generation via Firebase Cloud Functions
  Future<String> generate({
    required String systemPrompt,
    required String userMessage,
    List<Map<String, dynamic>>? history,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable('aiGenerate');
    final response = await callable.call({
      'systemPrompt': systemPrompt,
      'userMessage': userMessage,
      if (history != null) 'history': history,
    });

    final text = response.data['text'] as String?;
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
  /// The Cloud Function receives the [contextPayload] (onboarding data,
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

    final callable = FirebaseFunctions.instance.httpsCallable('aiGenerate');
    final response = await callable.call({
      'contextPayload': {
        ...contextPayload,
        'rulePrompt': rulePrompt,
      },
    });

    final text = response.data['text'] as String?;
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
  }) {
    return GeminiChatSession(
      systemPrompt: systemPrompt,
      service: this,
      initialHistory: initialHistory,
    );
  }
}

class GeminiChatSession {
  final String systemPrompt;
  final GeminiService service;

  // Track chat history locally
  final List<Map<String, dynamic>> _history;

  GeminiChatSession({
    required this.systemPrompt,
    required this.service,
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
      final reply = await service.generate(
        systemPrompt: systemPrompt,
        userMessage: message,
        history: _history,
      );

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
