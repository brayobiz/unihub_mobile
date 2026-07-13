import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/shared/providers.dart';
import '../../shared/notification_repository.dart';
import '../data/repositories/chat_repository_impl.dart';
import '../domain/repositories/chat_repository.dart';
import '../domain/models/conversation.dart';
import '../domain/models/message.dart';

import 'package:unihub_mobile/services/notification_service.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(
    ref.watch(firestoreProvider),
    ref.watch(notificationServiceProvider),
  );
});

final conversationsProvider = StreamProvider.autoDispose.family<List<Conversation>, String>((ref, userId) {
  final appUser = ref.watch(appUserProvider).valueOrNull;
  final isAdmin = appUser?.isAdmin ?? false;

  return ref.watch(chatRepositoryProvider).watchConversations(userId).map((conversations) {
    if (isAdmin) {
      // Filter out support conversations for admins in the regular list.
      // Admins manage support through the dedicated Support Center.
      return conversations.where((c) => !c.isSupport).toList();
    }
    return conversations;
  });
});

final conversationProvider = StreamProvider.autoDispose.family<Conversation?, String>((ref, conversationId) {
  return ref.watch(chatRepositoryProvider).watchConversation(conversationId);
});

final messagesStreamProvider = StreamProvider.autoDispose.family<List<Message>, String>((ref, conversationId) {
  return ref.watch(chatRepositoryProvider).watchMessages(conversationId);
});

final totalUnreadChatCountProvider = StreamProvider.autoDispose.family<int, String>((ref, userId) {
  return ref.watch(conversationsProvider(userId).stream).map((conversations) {
    return conversations.fold(0, (sum, conv) => sum + (conv.unreadCounts[userId] ?? 0));
  });
});
