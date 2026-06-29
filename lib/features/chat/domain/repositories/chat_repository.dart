import '../models/conversation.dart';
import '../models/message.dart';
import '../models/chat_context.dart';

abstract class ChatRepository {
  Stream<List<Conversation>> watchConversations(String userId);
  Stream<Conversation?> watchConversation(String conversationId);
  Stream<List<Message>> watchMessages(String conversationId);
  Future<void> sendMessage(String conversationId, Message message);
  Future<String> getOrCreateConversation({
    required List<String> participantIds,
    required ChatContext context,
  });
  Future<void> markAsRead(String conversationId, String userId);
  Future<String> getSupportConversation(String userId);
  Future<void> deleteMessage(String conversationId, String messageId);
  Future<void> deleteConversation(String conversationId);
  Future<void> updateTypingStatus(String conversationId, String userId, bool isTyping);
}
