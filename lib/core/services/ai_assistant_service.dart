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
  String _baseUrl = 'https://api.dify.ai/v1';

  void config({required String apiKey, String? baseUrl}) {
    _apiKey = apiKey;
    if (baseUrl != null) _baseUrl = baseUrl;
    debugPrint('🚀 UniBot: Configured with Dify AI');
  }

  Future<String?> getAiResponse({
    required String message,
    required String conversationId,
    required String userId,
  }) async {
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
        debugPrint('❌ Dify AI API ERROR: ${e.response?.statusCode} - ${e.response?.data}');
      } else {
        debugPrint('❌ Dify AI ERROR: $e');
      }
    }
    return null;
  }
}
