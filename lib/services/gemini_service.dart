// lib/services/gemini_service.dart

import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  // Singleton instance
  static final GeminiService _instance = GeminiService._internal();

  factory GeminiService() {
    return _instance;
  }

  GeminiService._internal();

  GenerativeModel _getModel(String systemPrompt) {
    const apiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    if (apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in environment.');
    }
    
    return GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      systemInstruction: Content.system(systemPrompt),
    );
  }

  /// Single-shot text generation
  Future<String> generate({
    required String systemPrompt,
    required String userMessage,
  }) async {
    final model = _getModel(systemPrompt);
    final response = await model.generateContent([Content.text(userMessage)]);
    
    if (response.text != null) {
      return response.text!;
    } else {
      throw Exception('Failed fetching AI generation or empty response');
    }
  }

  /// Start a multi-turn chat
  GeminiChatSession startChat(String systemPrompt) {
    final model = _getModel(systemPrompt);
    final chat = model.startChat();
    return GeminiChatSession(chatSession: chat);
  }
}

class GeminiChatSession {
  final ChatSession chatSession;

  GeminiChatSession({required this.chatSession});

  Future<String> sendMessage(String message) async {
    try {
      final response = await chatSession.sendMessage(Content.text(message));
      if (response.text != null) {
        return response.text!;
      } else {
        throw Exception('Chat API returned empty text');
      }
    } catch (e) {
      rethrow;
    }
  }
}
