import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
      final now = DateTime.now();
      final items = snapshot.docs
          .map((doc) => Conversation.fromJson(doc.data()))
          .where((c) => c.expiresAt == null || c.expiresAt!.isAfter(now))
          .toList();
      // Sort in-memory to avoid requiring a composite index in Firestore
      // while maintaining the real-time order.
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
        .map((doc) {
          if (!doc.exists) return null;
          final conv = Conversation.fromJson(doc.data()!);
          if (conv.expiresAt != null && conv.expiresAt!.isBefore(DateTime.now())) {
            return null;
          }
          return conv;
        });
  }

  @override
  Stream<List<Message>> watchMessages(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Message.fromJson(doc.data()))
            .toList());
  }

  @override
  Future<void> sendMessage(String conversationId, Message message) async {
    // 1. Prepare message with 'sent' status for Firestore
    final sentMessage = message.copyWith(status: MessageStatus.sent);
    final batch = _firestore.batch();
    
    final messageRef = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(message.id);
    
    batch.set(messageRef, sentMessage.toJson());
    
    final convRef = _firestore.collection('conversations').doc(conversationId);
    
    // 2. Update conversation metadata using server timestamp for consistency
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 48));
    
    batch.update(convRef, {
      'lastMessage': message.type == MessageType.text ? message.content : '[${message.type.name}]',
      'lastMessageSenderId': message.senderId,
      'lastMessageStatus': MessageStatus.sent.name,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt), // Reset expiration timer
    });

    // 3. Increment unread counts for other participants (Optimistic + Fallback)
    try {
      final cacheDoc = await convRef.get(const GetOptions(source: Source.cache));
      List<String> participants = [];
      if (cacheDoc.exists) {
        participants = List<String>.from(cacheDoc.data()?['participants'] ?? []);
      } else {
        final serverDoc = await convRef.get();
        if (serverDoc.exists) {
          participants = List<String>.from(serverDoc.data()?['participants'] ?? []);
        }
      }
      
      for (final participantId in participants) {
        if (participantId != message.senderId) {
          batch.update(convRef, {
            'unreadCounts.$participantId': FieldValue.increment(1),
          });
        }
      }
    } catch (e) {
      debugPrint('Error updating unread counts: $e');
    }

    await batch.commit();

    // 4. Send Notification (non-blocking)
    convRef.get().then((doc) {
      if (doc.exists) {
        _sendNotificationForMessage(conversationId, sentMessage, doc.data()!);
      }
    });
  }

  Future<void> _sendNotificationForMessage(String conversationId, Message message, Map<String, dynamic> data) async {
    try {
      final participants = List<String>.from(data['participants'] ?? []);
      final recipientId = participants.firstWhere((id) => id != message.senderId, orElse: () => '');
      
      if (recipientId.isNotEmpty) {
        final contextData = data['context'] as Map<String, dynamic>?;
        final module = contextData?['type'] as String?;
        final isSupport = data['isSupport'] ?? false;
        
        await _notificationService.sendNotification(
          recipientId: recipientId,
          title: isSupport ? 'UniHub Support' : 'New Message',
          body: message.type == MessageType.text ? message.content : 'Sent an attachment',
          type: isSupport ? NotificationType.support : NotificationType.chat,
          targetId: conversationId,
          targetType: module,
        );
      }
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  @override
  Future<String> getOrCreateConversation({
    required List<String> participantIds,
    required ChatContext context,
  }) async {
    // Filter by context.id and then check type/participants in memory to avoid index requirement
    final existing = await _firestore
        .collection('conversations')
        .where('context.id', isEqualTo: context.id)
        .get();

    for (var doc in existing.docs) {
      final data = doc.data();
      if (data['context']['type'] != context.type) continue;
      
      final participants = List<String>.from(data['participants']);
      if (participants.length == participantIds.length && 
          participants.every((p) => participantIds.contains(p))) {
        return doc.id;
      }
    }

    final newConvRef = _firestore.collection('conversations').doc();
    final now = DateTime.now();
    final conversation = Conversation(
      id: newConvRef.id,
      participants: participantIds,
      context: context,
      lastMessageTime: now,
      unreadCounts: {for (var id in participantIds) id: 0},
      expiresAt: now.add(const Duration(hours: 48)),
    );

    await newConvRef.set(conversation.toJson());
    return newConvRef.id;
  }

  @override
  Future<void> markAsRead(String conversationId, String userId) async {
    final convRef = _firestore.collection('conversations').doc(conversationId);
    
    // 1. Reset unread count
    await convRef.update({
      'unreadCounts.$userId': 0,
    });

    // 2. Mark messages from others as read
    // Use a single property filter to avoid composite index requirement
    final unreadMessages = await convRef
        .collection('messages')
        .where('status', isNotEqualTo: MessageStatus.read.name)
        .limit(50) 
        .get();

    if (unreadMessages.docs.isNotEmpty) {
      final batch = _firestore.batch();
      bool updatedAny = false;
      for (var doc in unreadMessages.docs) {
        if (doc.data()['senderId'] != userId) {
          batch.update(doc.reference, {'status': MessageStatus.read.name});
          updatedAny = true;
        }
      }
      
      if (!updatedAny) return;

      // Update lastMessageStatus if it was from someone else
      final convDoc = await convRef.get(const GetOptions(source: Source.cache));
      if (convDoc.exists && convDoc.data()?['lastMessageSenderId'] != userId) {
        batch.update(convRef, {'lastMessageStatus': MessageStatus.read.name});
      }
      
      await batch.commit();
    }
  }

  @override
  Future<void> markAsDelivered(String conversationId, String userId) async {
    final convRef = _firestore.collection('conversations').doc(conversationId);
    
    // Use a single property filter to avoid composite index requirement
    final undeliveredMessages = await convRef
        .collection('messages')
        .where('status', isEqualTo: MessageStatus.sent.name)
        .limit(50)
        .get();

    if (undeliveredMessages.docs.isNotEmpty) {
      final batch = _firestore.batch();
      bool updatedAny = false;
      for (var doc in undeliveredMessages.docs) {
        if (doc.data()['senderId'] != userId) {
          batch.update(doc.reference, {'status': MessageStatus.delivered.name});
          updatedAny = true;
        }
      }
      
      if (!updatedAny) return;
      
      final convDoc = await convRef.get(const GetOptions(source: Source.cache));
      if (convDoc.exists && 
          convDoc.data()?['lastMessageSenderId'] != userId && 
          convDoc.data()?['lastMessageStatus'] == MessageStatus.sent.name) {
        batch.update(convRef, {'lastMessageStatus': MessageStatus.delivered.name});
      }
      
      await batch.commit();
    }
  }

  @override
  Future<String> getSupportConversation(String userId) async {
    const adminId = 'unihub_admin';
    
    // Fetch user's conversations and filter in-memory to avoid index requirement
    final existing = await _firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .get();

    final supportConv = existing.docs.where((doc) {
      final data = doc.data();
      return data['isSupport'] == true;
    });

    if (supportConv.isNotEmpty) {
      return supportConv.first.id;
    }

    final newConvRef = _firestore.collection('conversations').doc();
    final now = DateTime.now();
    final conversation = Conversation(
      id: newConvRef.id,
      participants: [userId, adminId],
      context: ChatContext(
        type: 'support',
        id: 'support_$userId',
        title: 'UniHub Support',
      ),
      lastMessageTime: now,
      unreadCounts: {userId: 0, adminId: 0},
      isSupport: true,
      expiresAt: now.add(const Duration(hours: 48)),
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
