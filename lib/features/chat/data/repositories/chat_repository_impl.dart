import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unihub_mobile/features/chat/domain/models/conversation.dart';
import 'package:unihub_mobile/features/chat/domain/models/message.dart';
import 'package:unihub_mobile/features/chat/domain/models/chat_context.dart';
import 'package:unihub_mobile/features/chat/domain/repositories/chat_repository.dart';
import 'package:unihub_mobile/services/notification_service.dart';
import 'package:unihub_mobile/features/shared/notification_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final FirebaseFirestore _firestore;
  final NotificationService _notificationService;

  ChatRepositoryImpl(this._firestore, this._notificationService);

  @override
  Stream<List<Conversation>> watchConversations(String userId) {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => Conversation.fromJson(doc.data()))
          .toList();
      items.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      return items;
    });
  }

  @override
  Stream<Conversation?> watchConversation(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .snapshots()
        .map((doc) => doc.exists ? Conversation.fromJson(doc.data()!) : null);
  }

  @override
  Stream<List<Message>> watchMessages(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Message.fromJson(doc.data()))
            .toList());
  }

  @override
  Future<void> sendMessage(String conversationId, Message message) async {
    final batch = _firestore.batch();
    
    final messageRef = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(message.id);
    batch.set(messageRef, message.toJson());
    
    final convRef = _firestore.collection('conversations').doc(conversationId);
    batch.update(convRef, {
      'lastMessage': message.content,
      'lastMessageSenderId': message.senderId,
      'lastMessageStatus': message.status.name,
      'lastMessageTime': Timestamp.fromDate(message.timestamp),
    });

    // Update unread counts for other participants
    final convDoc = await convRef.get();
    if (convDoc.exists) {
      final participants = List<String>.from(convDoc.data()?['participants'] ?? []);
      for (final participantId in participants) {
        if (participantId != message.senderId) {
          batch.update(convRef, {
            'unreadCounts.$participantId': FieldValue.increment(1),
          });
        }
      }
    }

    await batch.commit();

    // Send Notification
    if (convDoc.exists) {
      final data = convDoc.data()!;
      final participants = List<String>.from(data['participants'] ?? []);
      final recipientId = participants.firstWhere((id) => id != message.senderId, orElse: () => '');
      
      if (recipientId.isNotEmpty) {
        final contextData = data['context'] as Map<String, dynamic>?;
        final module = contextData?['type'] as String?;
        final isSupport = data['isSupport'] ?? false;
        
        await _notificationService.sendNotification(
          recipientId: recipientId,
          title: 'New Message',
          body: message.content,
          type: isSupport ? NotificationType.support : NotificationType.chat,
          targetId: conversationId,
          targetType: module,
        );
      }
    }
  }

  @override
  Future<String> getOrCreateConversation({
    required List<String> participantIds,
    required ChatContext context,
  }) async {
    // Check if conversation already exists for this context between these participants
    final existing = await _firestore
        .collection('conversations')
        .where('context.id', isEqualTo: context.id)
        .where('context.type', isEqualTo: context.type)
        .get();

    for (var doc in existing.docs) {
      final participants = List<String>.from(doc.data()['participants']);
      if (participants.length == participantIds.length && 
          participants.every((p) => participantIds.contains(p))) {
        return doc.id;
      }
    }

    // Create new conversation
    final newConvRef = _firestore.collection('conversations').doc();
    final conversation = Conversation(
      id: newConvRef.id,
      participants: participantIds,
      context: context,
      lastMessageTime: DateTime.now(),
      unreadCounts: {for (var id in participantIds) id: 0},
    );

    await newConvRef.set(conversation.toJson());
    return newConvRef.id;
  }

  @override
  Future<void> markAsRead(String conversationId, String userId) async {
    final convRef = _firestore.collection('conversations').doc(conversationId);
    
    // Mark conversation unread count to 0 for this user
    await convRef.update({
      'unreadCounts.$userId': 0,
    });

    final convDoc = await convRef.get();
    if (convDoc.exists) {
      final data = convDoc.data()!;
      if (data['lastMessageSenderId'] != userId) {
        await convRef.update({'lastMessageStatus': MessageStatus.read.name});
      }
    }

    // Optionally mark all messages as read (status = read)
    // This can be expensive if there are many messages, usually done in batches or for visible messages
    final unreadMessages = await convRef
        .collection('messages')
        .where('senderId', isNotEqualTo: userId)
        .where('status', isNotEqualTo: MessageStatus.read.name)
        .get();

    if (unreadMessages.docs.isNotEmpty) {
      final batch = _firestore.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'status': MessageStatus.read.name});
      }
      await batch.commit();
    }
  }

  @override
  Future<String> getSupportConversation(String userId) async {
    const adminId = 'unihub_admin';
    
    final existing = await _firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .where('isSupport', isEqualTo: true)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    final newConvRef = _firestore.collection('conversations').doc();
    final conversation = Conversation(
      id: newConvRef.id,
      participants: [userId, adminId],
      context: ChatContext(
        type: 'support',
        id: 'support_$userId',
        title: 'UniHub Support',
      ),
      lastMessageTime: DateTime.now(),
      unreadCounts: {userId: 0, adminId: 0},
      isSupport: true,
    );

    await newConvRef.set(conversation.toJson());
    return newConvRef.id;
  }

  @override
  Future<void> deleteMessage(String conversationId, String messageId) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    // In a real app, we might want to just "hide" it for the user, 
    // but the requirement says "Delete conversation".
    // Deleting subcollections requires deleting all documents inside.
    final messages = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .get();
        
    final batch = _firestore.batch();
    for (var doc in messages.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_firestore.collection('conversations').doc(conversationId));
    
    await batch.commit();
  }

  @override
  Future<void> updateTypingStatus(String conversationId, String userId, bool isTyping) async {
    await _firestore.collection('conversations').doc(conversationId).update({
      'typing.$userId': isTyping ? FieldValue.serverTimestamp() : FieldValue.delete(),
    });
  }
}
