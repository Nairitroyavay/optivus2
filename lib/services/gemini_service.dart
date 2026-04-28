// lib/services/gemini_service.dart

import 'package:cloud_functions/cloud_functions.dart';

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
      return text;
    } else {
      throw Exception('Failed fetching AI generation or empty response');
    }
  }

  /// Start a multi-turn chat
  GeminiChatSession startChat(String systemPrompt, {List<Map<String, dynamic>>? initialHistory}) {
    return GeminiChatSession(systemPrompt: systemPrompt, service: this, initialHistory: initialHistory);
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
        'parts': [{'text': message}],
      });
      _history.add({
        'role': 'model',
        'parts': [{'text': reply}],
      });
      
      return reply;
    } catch (e) {
      rethrow;
    }
  }
}
