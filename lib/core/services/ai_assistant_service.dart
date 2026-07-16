import 'dart:async';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/app_logger.dart';

final aiAssistantServiceProvider = Provider<AIAssistantService>((ref) {
  return AIAssistantService();
});

class AIAssistantService {
  GenerativeModel? _model;
  bool _useMock = false;

  // VERIFIED LITE MODEL: Optimized for speed and low latency
  static const String _modelId = 'gemini-flash-lite-latest';

  // Detailed System Prompt (Verified against actual app structure)
  static const String _appKnowledgePrompt =
    "You are Ulify Assistant. "
    "MANDATORY STYLE RULES: "
    "1. DO NOT introduce yourself in every reply. Only introduce yourself if the history is empty. "
    "2. Be concise and direct. "
    "3. Use a helpful, student-focused tone. "
    "\n\n"
    "APP STRUCTURE & NAVIGATION: "
    "1. Bottom Navigation Bar: Home, Market, Housing, Notes, and Chat (Messages). "
    "2. App Drawer (Top-Left): Community, Student Gigs, Confessions, My Events, Campus Map, and Events & Clubs. "
    "\n\n"
    "FEATURE WORKFLOWS: "
    "- MARKETPLACE: Sell by tapping Market -> '+' button. Buy by browsing -> 'Chat with Seller'. "
    "- HOUSING: Find houses/roommates via the Housing tab. "
    "- NOTES: Access and search study notes directly via the Notes tab in the Bottom Nav. "
    "- GIGS/EVENTS: Found in the App Drawer. "
    "- ESCALATION: Start your reply with [ESCALATE] ONLY if you cannot solve the issue or a human is requested.";

  void config({required String apiKey, bool useMock = false}) {
    _useMock = useMock;
    if (_useMock) return;

    try {
      if (apiKey.isEmpty) return;

      _model = GenerativeModel(
        model: _modelId,
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          maxOutputTokens: 400,
          temperature: 0.7,
        ),
        requestOptions: const RequestOptions(apiVersion: 'v1beta'),
      );
      debugPrint('🚀 AI_SERVICE: Initialized for Speed & Accuracy.');
    } catch (e) {
      debugPrint('❌ AI_SERVICE: Init Error: $e');
    }
  }

  Future<String?> getAiResponse({
    required String message,
    required String conversationId,
    required String userId,
    List<Content>? history,
  }) async {
    if (_useMock) return "Mock response.";
    if (_model == null) return null;

    final String cleanMessage = message.length > 1000 ? message.substring(0, 1000) : message;

    return _callWithRetry<String?>(() async {
      // Start a chat session with the provided history and system instructions
      final chat = _model!.startChat(
        history: [
          Content.text(_appKnowledgePrompt),
          Content.model([TextPart('Understood. I am the Ulify Assistant. I will follow your instructions and help the student without repeating my introduction unless necessary.')]),
          ...?history,
        ],
      );

      debugPrint('🚀 AI_SERVICE: Requesting $_modelId (Chat Mode)...');
      final response = await chat.sendMessage(Content.text(cleanMessage));

      final text = response.text;
      if (text != null) debugPrint('✅ AI_SERVICE: Success! (${text.length} chars)');
      return text;
    });
  }

  Future<T?> _callWithRetry<T>(Future<T> Function() call, {int maxRetries = 2}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        return await call().timeout(const Duration(seconds: 90));
      } catch (e) {
        if (e is TimeoutException) {
          debugPrint('⏳ AI_SERVICE: Attempt ${i+1} timed out. Retrying...');
        } else {
          debugPrint('❌ AI_SERVICE: Attempt ${i+1} failed: $e');
        }

        if (i == maxRetries - 1) break;
        await Future.delayed(const Duration(seconds: 3));
      }
    }
    return null;
  }
}
