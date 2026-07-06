import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:unihub_mobile/features/chat/domain/models/conversation.dart';
import 'package:unihub_mobile/features/chat/domain/models/message.dart';
import 'package:unihub_mobile/features/chat/domain/models/chat_context.dart';
import 'package:unihub_mobile/features/chat/domain/repositories/chat_repository.dart';
import 'package:unihub_mobile/services/notification_service.dart';
import 'package:unihub_mobile/core/services/notification_sender.dart';
import 'package:unihub_mobile/features/shared/notification_repository.dart';
import 'package:unihub_mobile/core/utils/app_logger.dart';

class ChatRepositoryImpl implements ChatRepository {
  final FirebaseFirestore _firestore;
  final NotificationSender _notificationSender;

  ChatRepositoryImpl(this._firestore, this._notificationSender);

  @override
  Stream<List<Conversation>> watchConversations(String userId) {
    // Cache for blocked users to avoid frequent Firestore reads during stream updates
    final Map<String, List<String>> _blockedCache = {};
    
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .snapshots()
        .asyncMap((snapshot) async {
      final now = DateTime.now();
      
      // Fetch user's blocked list (using local cache or serverAndCache to save reads)
      List<String> blockedUids = _blockedCache[userId] ?? [];
      if (blockedUids.isEmpty) {
        final userDoc = await _firestore.collection('users').doc(userId).get(const GetOptions(source: Source.serverAndCache));
        blockedUids = List<String>.from(userDoc.data()?['blockedUids'] ?? []);
        _blockedCache[userId] = blockedUids;
      }

      final items = snapshot.docs
          .map((doc) => Conversation.fromJson(doc.data()))
          .where((c) {
            // Filter 1: Not expired
            final isNotExpired = c.expiresAt == null || c.expiresAt!.isAfter(now);
            // Filter 2: No participants are in our blocked list
            final otherParticipant = c.participants.firstWhere((id) => id != userId, orElse: () => '');
            final isNotBlocked = !blockedUids.contains(otherParticipant);
            
            return isNotExpired && isNotBlocked;
          })
          .toList();
      // Sort in-memory
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
    final convRef = _firestore.collection('conversations').doc(conversationId);
    final convDoc = await convRef.get();
    
    if (!convDoc.exists) throw Exception('Conversation not found');
    
    final Map<String, dynamic> data = convDoc.data()!;
    final participants = List<String>.from(data['participants'] ?? []);
    
    if (participants.isEmpty) {
      AppLogger.warning('Conversation $conversationId has no participants', 'CHAT_REPO');
    }

    final recipientId = participants.firstWhere((id) => id != message.senderId, orElse: () => '');
    
    if (recipientId.isNotEmpty) {
      // 1. Check if recipient has blocked sender (Only for P2P chats)
      if (!(data['isSupport'] ?? false)) {
        final recipientDoc = await _firestore.collection('users').doc(recipientId).get();
        if (recipientDoc.exists) {
          final blockedUids = List<String>.from(recipientDoc.data()?['blockedUids'] ?? []);
          if (blockedUids.contains(message.senderId)) {
            throw Exception('You cannot message this user.');
          }
        }
      }
    }

    // 2. Prepare message
    final sentMessage = message.copyWith(status: MessageStatus.sent);
    final batch = _firestore.batch();
    
    final messageRef = convRef.collection('messages').doc(message.id);
    batch.set(messageRef, sentMessage.toJson());
    
    // 3. Update conversation metadata
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 48));
    
    final Map<String, dynamic> updateData = {
      'lastMessage': message.type == MessageType.text ? message.content : '[${message.type.name}]',
      'lastMessageSenderId': message.senderId,
      'lastMessageStatus': MessageStatus.sent.name,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };

    if (message.context != null) {
      updateData['context'] = message.context!.toJson();
    }

    // Support Chat specific logic:
    if (conversationId.contains('unihub_admin') || (data['isSupport'] ?? false)) {
      final realAdminId = message.metadata?['adminId'] as String?;
      
      // Auto-assign admin to participants if they are sending a message but aren't in the list
      if (realAdminId != null && realAdminId.isNotEmpty && !participants.contains(realAdminId)) {
        participants.add(realAdminId);
        batch.update(convRef, {
          'participants': FieldValue.arrayUnion([realAdminId]),
          'unreadCounts.$realAdminId': 0, // Initialize unread count for the newly joined admin
        });
      }

      // If the sender is the student (usually index 0), it's waiting for admin
      if (participants.isNotEmpty && message.senderId == participants[0]) {
        updateData['supportStatus'] = 'waiting_admin';
      } else {
        updateData['supportStatus'] = 'waiting_user';
      }
    }
    
    batch.update(convRef, updateData);

    // 4. Increment unread counts for other participants
    // We use a Set to avoid duplicates if participants list is messy
    final Map<String, dynamic> unreadUpdates = {};
    for (final participantId in participants.toSet()) {
      if (participantId.isNotEmpty && participantId != message.senderId) {
        unreadUpdates['unreadCounts.$participantId'] = FieldValue.increment(1);
      }
    }

    if (unreadUpdates.isNotEmpty) {
      batch.update(convRef, unreadUpdates);
    }

    await batch.commit();

    // 5. Send Notification (non-blocking)
    _sendNotificationForMessage(conversationId, sentMessage, data);
  }

  Future<void> _sendNotificationForMessage(String conversationId, Message message, Map<String, dynamic> data) async {
    try {
      final participants = List<String>.from(data['participants'] ?? []);
      final isSupport = data['isSupport'] ?? false;
      final assignedAdminId = data['assignedAdminId'] as String?;
      
      final List<String> recipients = [];
      String? actorName = message.metadata?['adminName'] as String?;
      
      if (isSupport) {
        // Support Logic
        if (message.senderId == 'unihub_admin' || (participants.contains(message.senderId) && message.senderId != participants[0])) {
          // Message from admin, notify student (always at index 0 for support)
          if (participants.isNotEmpty) recipients.add(participants[0]);
        } else {
          // Message from student, notify assigned admin
          if (assignedAdminId != null) {
            recipients.add(assignedAdminId);
          } else {
            // NEW: Unassigned ticket: Notify the generic support identity or use a broadcast
            // Since 'unihub_admin' might not have a token, we broadcast to 'admins' topic
            await _notificationSender.triggerPushNotification(
              recipientId: '',
              isBroadcast: true,
              title: 'New Support Message',
              body: message.type == MessageType.text ? message.content : 'Sent an attachment',
              data: {
                'type': NotificationType.support.name,
                'targetId': conversationId,
                'route': '/admin/support/$conversationId',
                'topic': 'admins', // Hint for backend to only send to admin tokens
              },
            );
          }
        }
      } else {
        // Standard Chat Logic
        final recipientId = participants.firstWhere((id) => id != message.senderId, orElse: () => '');
        if (recipientId.isNotEmpty) recipients.add(recipientId);
        
        // Use sender's name if we have it in metadata (optional enhancement)
        actorName = message.metadata?['senderName'] as String?;
      }
      
      for (final recipientId in recipients) {
        final contextData = data['context'] as Map<String, dynamic>?;
        final module = contextData?['type'] as String?;
        
        await _notificationSender.sendNotification(
          recipientId: recipientId,
          actorName: actorName,
          title: isSupport ? (actorName != null ? 'UniHub Support ($actorName)' : 'UniHub Support') : 'New Message',
          body: message.type == MessageType.text ? message.content : 'Sent an attachment',
          type: isSupport ? NotificationType.support : NotificationType.chat,
          targetId: conversationId,
          targetType: module,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error sending notification: $e');
      }
    }
  }

  String _getDeterministicConversationId(List<String> ids) {
    final sortedIds = List<String>.from(ids)..sort();
    return 'chat_${sortedIds.join('_')}';
  }

  @override
  Future<String> getOrCreateConversation({
    required List<String> participantIds,
    required ChatContext context,
  }) async {
    final conversationId = _getDeterministicConversationId(participantIds);
    final convRef = _firestore.collection('conversations').doc(conversationId);
    
    final doc = await convRef.get();
    if (doc.exists) {
      // If it exists, we update the context to the latest one being accessed
      await convRef.update({'context': context.toJson()});
      return conversationId;
    }

    final now = DateTime.now();
    final conversation = Conversation(
      id: conversationId,
      participants: participantIds,
      context: context,
      lastMessageTime: now,
      unreadCounts: {for (var id in participantIds) id: 0},
      expiresAt: now.add(const Duration(hours: 48)),
    );

    await convRef.set(conversation.toJson());
    return conversationId;
  }

  @override
  Future<void> markAsRead(String conversationId, String userId) async {
    if (userId.isEmpty) return;
    
    final convRef = _firestore.collection('conversations').doc(conversationId);
    
    // 1. Reset unread count
    try {
      await convRef.update({
        'unreadCounts.$userId': 0,
      });
    } catch (e) {
      AppLogger.warning('Failed to reset unread count for $userId in $conversationId: $e', 'CHAT_REPO');
    }

    // 2. Clear associated notifications
    await _notificationSender.markAsReadByTarget(userId, conversationId);

    // 3. Mark messages from others as read
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
    if (userId.isEmpty) throw Exception('User ID cannot be empty');

    const adminId = 'unihub_admin';
    final participantIds = [userId, adminId];
    final conversationId = _getDeterministicConversationId(participantIds);
    
    final convRef = _firestore.collection('conversations').doc(conversationId);
    final doc = await convRef.get();

    if (doc.exists) {
      return conversationId;
    }

    final now = DateTime.now();
    final conversation = Conversation(
      id: conversationId,
      participants: participantIds,
      context: ChatContext(
        type: 'support',
        id: 'support_$userId',
        title: 'UniHub Support',
      ),
      lastMessageTime: now,
      unreadCounts: {userId: 0, adminId: 0},
      isSupport: true,
      supportStatus: 'waiting_admin',
      supportPriority: 'normal',
      expiresAt: now.add(const Duration(hours: 48)),
    );

    await convRef.set(conversation.toJson());
    return conversationId;
  }

  @override
  Future<void> deleteMessage(String conversationId, String messageId, String userId) async {
    final msgDoc = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .get();
    
    if (msgDoc.exists && msgDoc.data()?['senderId'] == userId) {
      await msgDoc.reference.delete();
    } else {
      throw Exception('Unauthorized: You can only delete your own messages');
    }
  }

  @override
  Future<void> deleteConversation(String conversationId, String userId) async {
    final convDoc = await _firestore.collection('conversations').doc(conversationId).get();
    if (!convDoc.exists) return;
    
    final participants = List<String>.from(convDoc.data()?['participants'] ?? []);
    if (!participants.contains(userId)) {
      throw Exception('Unauthorized: You are not a participant in this conversation');
    }

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
