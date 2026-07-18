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

  // Detailed System Prompt (The Definitive Source of Truth for Ulify)
  static const String _appKnowledgePrompt =
    "You are the official Ulify Assistant. "
    "MANDATORY STYLE RULES: "
    "1. DO NOT introduce yourself in every reply. Only introduce yourself if the history is empty. "
    "2. Be concise and direct. "
    "3. Use a helpful, student-focused tone. "
    "\n\n"
    "PLATFORM OVERVIEW: "
    "Ulify is a comprehensive student-led digital ecosystem for university communities. "
    "Mission: Eliminate student life friction (fragmented WhatsApp groups, scams) with a trusted gateway. "
    "Value Prop: Your Campus. Connected. Built for students, campus entrepreneurs, housing Plugs, and club organizers. "
    "\n\n"
    "APP STRUCTURE & NAVIGATION: "
    "1. Bottom Navigation Bar: "
    "   - Home: Dashboard with Smart Feed (personalized recommendations, trending). "
    "   - Market: Student-to-student Marketplace. "
    "   - Housing: Accommodation & Roommate matching. "
    "   - Notes: Peer-to-peer study resource sharing. "
    "   - Chat: All conversations (Buying, Housing, Gigs, Support). "
    "2. App Drawer (Top-Left): Campus Map, Student Gigs, Events & Clubs, Confessions, My Events, About Ulify. "
    "\n\n"
    "CORE FEATURE WORKFLOWS: "
    "- MARKETPLACE: Sell via Market -> '+'. Buy via 'Chat with Seller' or 'Contact Student' (WhatsApp). MEET ON CAMPUS in public areas. "
    "- HOUSING: Connect with Verified Plugs. POLICY: NEVER pay viewing fees or deposits before visiting. Includes Roommate matching. "
    "- STUDY NOTES: Search by category, unit code, or type. Bookmark and track progress. "
    "- STUDENT GIGS: Earn money by offering services (tutoring, design, etc.). Application initiates an integrated chat. "
    "- EVENTS & CLUBS: Discover campus culture. Club leaders create Verified Organizer profiles. "
    "\n\n"
    "TRUST & SAFETY: "
    "Deterministic Trust Score (0-100%) based on: "
    "1. Identity (Gov ID - Primary Tick). 2. Student Verification (Enrollment). 3. Community Feedback (Ratings). 4. Platform Activity (Sales, Sharing). "
    "\n\n"
    "TROUBLESHOOTING & FAQ: "
    "- Offline: App has an Offline Banner; uses Firestore persistence. "
    "- Missing Features: Check 'Campus Filter' on Home/Market tabs. "
    "- Data Privacy: Users can delete accounts in Settings -> Delete Account (Permanent erasure). "
    "- Suspension: 'Spark Plan Self-Healing' allows content restoration after suspension expires. "
    "\n\n"
    "ESCALATION: "
    "Start your reply with [ESCALATE] ONLY if you cannot solve the issue or a human is requested.";

  void config({required String apiKey, bool useMock = false}) {
    _useMock = useMock;
    if (_useMock) return;

    try {
      if (apiKey.isEmpty) return;

      _model = GenerativeModel(
        model: _modelId,
        apiKey: apiKey,
        systemInstruction: Content.system(_appKnowledgePrompt),
        generationConfig: GenerationConfig(
          maxOutputTokens: 400,
          temperature: 0.7,
        ),
        requestOptions: const RequestOptions(apiVersion: 'v1beta'),
      );
      debugPrint('🚀 AI_SERVICE: Initialized with System Instruction for Speed & Accuracy.');
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
    if (_model == null) {
      debugPrint('⚠️ AI_SERVICE: Model not initialized (API Key might be missing).');
      return null;
    }

    final String cleanMessage = message.length > 1000 ? message.substring(0, 1000) : message;

    try {
      return await _callWithRetry<String?>(() async {
        // Filter history to ensure it alternates between user and model, starting with user
        // This is a strict requirement for the Gemini SDK's ChatSession
        List<Content> cleanHistory = [];
        if (history != null && history.isNotEmpty) {
          bool nextShouldBeUser = true;
          for (var content in history) {
            // Role can be 'user' or 'model'
            if (nextShouldBeUser && content.role == 'user') {
              cleanHistory.add(content);
              nextShouldBeUser = false;
            } else if (!nextShouldBeUser && content.role == 'model') {
              cleanHistory.add(content);
              nextShouldBeUser = true;
            }
          }
        }

        final chat = _model!.startChat(history: cleanHistory);

        debugPrint('🚀 AI_SERVICE: Requesting $_modelId (Chat Mode with ${cleanHistory.length} history items)...');
        final response = await chat.sendMessage(Content.text(cleanMessage));

        final text = response.text;
        if (text != null) {
          debugPrint('✅ AI_SERVICE: Success! (${text.length} chars)');
          return text;
        }
        return null;
      });
    } catch (e) {
      debugPrint('❌ AI_SERVICE: Critical Error during generation: $e');
      return null;
    }
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
