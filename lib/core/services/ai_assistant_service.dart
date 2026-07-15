import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/app_logger.dart';

final aiAssistantServiceProvider = Provider<AIAssistantService>((ref) {
  return AIAssistantService();
});

class AIAssistantService {
  final _dio = Dio();
  String? _apiKey;
  bool _useMock = false;
  String _baseUrl = 'https://api.dify.ai/v1';

  void config({required String apiKey, String? baseUrl, bool useMock = false}) {
    _apiKey = apiKey;
    _useMock = useMock;
    if (baseUrl != null) _baseUrl = baseUrl;
    debugPrint('🚀 UniBot: Configured with Dify AI (Mock Mode: $_useMock)');
  }

  Future<String?> getAiResponse({
    required String message,
    required String conversationId,
    required String userId,
  }) async {
    if (_useMock) {
      await Future.delayed(const Duration(seconds: 2)); // Simulating network lag
      return _getMockResponse(message);
    }
    if (_apiKey == null) {
      debugPrint('❌ Dify AI: API Key not configured.');
      return null;
    }

    final effectiveUserId = userId.isNotEmpty ? userId : 'user_${conversationId.hashCode.abs()}';
    debugPrint('🚀 Dify AI: Sending message for user: $effectiveUserId');

    try {
      final response = await _dio.post(
        '$_baseUrl/chat-messages',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'inputs': {},
          'query': message,
          'response_mode': 'blocking', // Wait for the full response
          'conversation_id': '', // Let Dify manage the history internally for now or pass conversationId
          'user': effectiveUserId,
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final String? answer = response.data['answer'];
        debugPrint('🚀 Dify AI SUCCESS: $answer');
        return answer;
      }
    } catch (e) {
      if (e is DioException) {
        final errorData = e.response?.data;
        if (errorData is Map && errorData['code'] == 'invalid_param') {
          debugPrint('❌ Dify AI: Credits exhausted or Model unconfigured. Check Dify dashboard.');
        }
        debugPrint('❌ Dify AI API ERROR: ${e.response?.statusCode} - $errorData');
      } else {
        debugPrint('❌ Dify AI ERROR: $e');
      }
    }
    return null;
  }

  String _getMockResponse(String userQuery) {
    final query = userQuery.toLowerCase();
    if (query.contains('help') || query.contains('support') || query.contains('human')) {
      return "I'll get a human to help you with that right away. [ESCALATE]";
    }
    
    final responses = [
      "Hello! I'm UniBot. How can I assist you today?",
      "That's an interesting question. Let me look into that for you.",
      "I'm currently in maintenance mode, but I can still answer basic questions!",
      "You can find more info about that in the Campus Guide section.",
      "I've noted your request. Is there anything else you need?"
    ];
    return responses[DateTime.now().second % responses.length];
  }
}
