import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/shared/providers.dart';
import '../../shared/notification_repository.dart';
import '../data/repositories/chat_repository_impl.dart';
import '../domain/repositories/chat_repository.dart';
import '../domain/models/conversation.dart';
import '../domain/models/message.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(
    ref.watch(firestoreProvider),
    ref.watch(notificationRepositoryProvider),
  );
});

final conversationsProvider = StreamProvider.family<List<Conversation>, String>((ref, userId) {
  return ref.watch(chatRepositoryProvider).watchConversations(userId);
});

final messagesStreamProvider = StreamProvider.family<List<Message>, String>((ref, conversationId) {
  return ref.watch(chatRepositoryProvider).watchMessages(conversationId);
});
