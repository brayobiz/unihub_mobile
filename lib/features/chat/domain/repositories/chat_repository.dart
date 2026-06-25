import '../models/conversation.dart';
import '../models/message.dart';

abstract class ChatRepository {
  Stream<List<Conversation>> watchConversations(String userId);
  Stream<List<Message>> watchMessages(String conversationId);
  Future<void> sendMessage(String conversationId, Message message);
  Future<String> getOrCreateConversation({
    required String buyerId,
    required String sellerId,
    required String listingId,
    required String listingTitle,
  });
  Future<void> markAsRead(String conversationId, String userId);
  Future<String> getSupportConversation(String userId);
}
