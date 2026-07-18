import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:unihub_mobile/features/chat/domain/models/conversation.dart';
import 'package:unihub_mobile/features/chat/domain/models/message.dart';
import 'package:unihub_mobile/features/chat/domain/models/chat_context.dart';
import 'package:unihub_mobile/features/chat/domain/repositories/chat_repository.dart';
import 'package:unihub_mobile/services/notification_service.dart';
import 'package:unihub_mobile/core/services/notification_sender.dart';
import 'package:unihub_mobile/features/shared/notification_repository.dart';
import 'package:unihub_mobile/core/utils/app_logger.dart';
import 'package:unihub_mobile/core/services/ai_assistant_service.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:unihub_mobile/core/error/error_handler.dart';

class ChatRepositoryImpl implements ChatRepository {
  final FirebaseFirestore _firestore;
  final NotificationSender _notificationSender;
  final Ref _ref; // Need ref to call AI service
  
  // Cache for blocked users to avoid frequent Firestore reads during stream updates
  final Map<String, List<String>> _blockedCache = {};

  // Track active AI requests to prevent overlapping replies
  final Set<String> _botThinkingConversations = {};
  // Track message IDs already processed by the bot to prevent double-replies
  final Set<String> _processedMessageIds = {};
  // Debounce timers for each conversation to batch messages
  final Map<String, Timer> _botDebouncers = {};
  
  // Tracking usage to prevent quota abuse (Simple in-memory for now)
  // Note: todayKey is computed dynamically in sendMessage to handle midnight transitions
  final Map<String, int> _userDailyAiCount = {};

  ChatRepositoryImpl(this._firestore, this._notificationSender, this._ref);

  @override
  Stream<List<Conversation>> watchConversations(String userId) {
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
            
            // Filter 2: Personal chats only for admins
            // If the user is an admin, we might want to hide support chats from this specific personal stream
            // BUT, the repository doesn't know if 'userId' is an admin.
            // We handle this in the Provider layer for better separation of concerns.
            
            // Filter 3: No participants are in our blocked list
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
            .toList())
        .handleError((e) {
          AppLogger.error('Chat: Error watching messages', e, null, 'CHAT_REPO');
          throw Exception(AppErrorHandler.mapError(e));
        });
  }

  @override
  Future<void> sendMessage(String conversationId, Message message) async {
    try {
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
      if (conversationId.contains('ulify_admin') || (data['isSupport'] ?? false)) {
        final realAdminId = message.metadata?['adminId'] as String?;
        
        // Auto-assign admin to participants if they are sending a message but aren't in the list
        if (realAdminId != null && realAdminId.isNotEmpty && !participants.contains(realAdminId)) {
          participants.add(realAdminId);
          batch.update(convRef, {
            'participants': FieldValue.arrayUnion([realAdminId]),
            'unreadCounts.$realAdminId': 0, // Initialize unread count for the newly joined admin
          });
        }

        // Logic: If the sender is NOT an admin, it's a student request waiting for admin response.
        // Firestore rules ONLY allow students to set status to 'waiting_admin'.
        final bool isSenderAdmin = message.senderId == 'ulify_admin' || (message.metadata?['adminId'] != null);
        final bool isSenderHumanAdmin = isSenderAdmin && message.metadata?['isAi'] != true;
        
        if (!isSenderAdmin) {
          updateData['supportStatus'] = 'waiting_admin';
        } else {
          updateData['supportStatus'] = 'waiting_user';
          
          // Auto-handover: If a human admin replies to an unassigned ticket, assign it to them
          if (isSenderHumanAdmin && data['assignedAdminId'] == null && realAdminId != null) {
            updateData['assignedAdminId'] = realAdminId;
            AppLogger.info('Support: Auto-assigning ticket $conversationId to admin $realAdminId', 'CHAT_REPO');
          }
        }
      }
      
      batch.update(convRef, updateData);

      // 4. Increment unread counts for other participants
      // We use a Set to avoid duplicates if participants list is messy
      final Map<String, dynamic> unreadUpdates = {};
      final bool isSupportMsg = (data['isSupport'] ?? false) || conversationId.contains('ulify_admin');
      final String studentId = participants.isNotEmpty ? participants[0] : '';
      
      for (final participantId in participants.toSet()) {
        if (participantId.isEmpty || participantId == message.senderId) continue;
        
        // LOGIC: In Support Chats, we only increment the student's unread count 
        // if an admin is sending, and vice versa. 
        // We NEVER increment an admin's unread count if an admin is sending (even if they use different IDs).
        
        if (isSupportMsg) {
          final bool isSenderAdmin = message.senderId == 'ulify_admin' || (message.metadata?['adminId'] != null);
          
          if (isSenderAdmin) {
            // Admin -> Student: Notify only the student
            if (participantId == studentId) {
              unreadUpdates['unreadCounts.$participantId'] = FieldValue.increment(1);
            }
          } else {
            // Student -> Admin: WE DO NOT increment admin unread counts.
            // Support tickets use 'supportStatus' for admin visibility.
            // This keeps the admin's personal chat badge clean.
          }
        } else {
          // Standard P2P chat: notify everyone else
          unreadUpdates['unreadCounts.$participantId'] = FieldValue.increment(1);
        }
      }

      if (unreadUpdates.isNotEmpty) {
        batch.update(convRef, unreadUpdates);
      }

      await batch.commit();

      // 5. Send Notification (non-blocking)
      _sendNotificationForMessage(conversationId, sentMessage, data);

      // 6. Ulify Assistant Logic (Client-Side AI)
      // Trigger if:
      // A) It is a support message
      // B) The sender is a student (not an admin)
      // C) NO human admin is assigned yet
      final bool isStudentMsg = message.senderId != 'ulify_admin' && message.metadata?['adminId'] == null;
      final bool hasHumanAdmin = data['assignedAdminId'] != null;
      final bool isReopened = data['supportStatus'] == 'resolved' || data['supportStatus'] == 'closed';
      final bool isWaiting = data['supportStatus'] == 'waiting_admin' ||
                             data['supportStatus'] == 'waiting_user' ||
                             data['supportStatus'] == 'active';
      
      // CRITICAL: Bot stays silent if a human admin has joined the chat
      // NEW: Bot stays silent if already escalated AND waiting for admin (unless we're in a new session or re-opened state)
      final bool isEscalated = data['supportStatus'] == 'waiting_admin' && data['supportPriority'] == 'high';
      final bool shouldBotRespond = isSupportMsg && !hasHumanAdmin && (isReopened || isWaiting || data['supportStatus'] == null) && isStudentMsg && !isEscalated;

      debugPrint('🚀 Ulify Assistant: Status=${data['supportStatus']}, hasHuman=$hasHumanAdmin, isEscalated=$isEscalated, shouldBotRespond=$shouldBotRespond');
      
      if (shouldBotRespond) {
        final currentUid = _ref.read(firebaseAuthProvider).currentUser?.uid ?? message.senderId;
        final todayKey = DateTime.now().toIso8601String().substring(0, 10);

        // 1. Persistent Fair Use Cap: Check Firestore for daily usage
        try {
          final usageDoc = await _firestore
              .collection('users')
              .doc(currentUid)
              .collection('metadata')
              .doc('ai_usage')
              .get();

          final usageData = usageDoc.data();
          final int currentUsage = (usageData?[todayKey] as int?) ?? 0;

          if (currentUsage >= 10) {
            debugPrint('⚠️ Ulify Assistant: User $currentUid reached daily limit ($currentUsage/10)');
            return;
          }

          // 2. Phrase Filter
          final cleanMsg = message.content.trim().toLowerCase();
          if (cleanMsg.length < 3 || cleanMsg == 'hi' || cleanMsg == 'hello' || cleanMsg == 'hey') return;

          // 3. Debouncing
          _botDebouncers[conversationId]?.cancel();
          _botDebouncers[conversationId] = Timer(const Duration(seconds: 3), () async {
            if (!_processedMessageIds.contains(message.id)) {
              // Limit size of processed IDs set
              if (_processedMessageIds.length > 100) _processedMessageIds.remove(_processedMessageIds.first);
              _processedMessageIds.add(message.id);

              // Increment persistent counter before processing to prevent race condition abuse
              try {
                await _firestore
                    .collection('users')
                    .doc(currentUid)
                    .collection('metadata')
                    .doc('ai_usage')
                    .set({todayKey: FieldValue.increment(1)}, SetOptions(merge: true));
              } catch (e) {
                AppLogger.warning('Ulify Assistant: Failed to increment usage counter: $e', 'AI_SERVICE');
                // We proceed anyway to ensure the user gets a reply even if quota tracking fails
              }

              // Escalation check: Status must be waiting_admin AND priority must be high
              final bool isEscalated = data['supportStatus'] == 'waiting_admin' && data['supportPriority'] == 'high';
              _triggerUlifyAssistantReply(conversationId, message.content, currentUid, isEscalated: isEscalated);
            }
            _botDebouncers.remove(conversationId);
          });
        } catch (e) {
          AppLogger.warning('Ulify Assistant: Usage check failed, skipping reply to be safe: $e', 'AI_SERVICE');
        }
      }
    } catch (e) {
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  Future<void> _triggerUlifyAssistantReply(String conversationId, String userMessage, String userId, {bool isEscalated = false}) async {
    // 1. Concurrency Check
    if (_botThinkingConversations.contains(conversationId)) return;

    try {
      _botThinkingConversations.add(conversationId);

      // 2. Immediate Check: If already escalated, respond with a polite hold message instead of calling Gemini
      if (isEscalated) {
        // Audit Fix: Prevent spamming "I've already notified" messages if one was sent recently.
        final lastMsgSnap = await _firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(5)
            .get();

        bool recentlyNotified = false;
        for (var doc in lastMsgSnap.docs) {
          final mData = doc.data();
          if (mData['senderId'] == 'ulify_admin' && 
              (mData['content'] as String).contains('notified')) {
            // Check if it was sent in the last 10 minutes
            final ts = (mData['timestamp'] as Timestamp?)?.toDate();
            if (ts != null && DateTime.now().difference(ts).inMinutes < 10) {
              recentlyNotified = true;
              break;
            }
          }
        }

        if (!recentlyNotified) {
          await Future.delayed(const Duration(seconds: 1)); // Feel natural
          await _injectBotMessage(
            conversationId, 
            "I've already notified the Ulify team about your request! 🚀 A human admin will be with you as soon as possible. Thanks for your patience.",
            keepWaitingAdmin: true,
          );
        }
        return;
      }

      // 2b. Audit Fix: Keyword-based manual escalation shortcut
      final lowerMsg = userMessage.toLowerCase();
      final panicKeywords = ['human', 'person', 'representative', 'staff', 'escalate', 'talk to someone', 'admin'];
      if (panicKeywords.any((k) => lowerMsg.contains(k))) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _injectBotMessage(
          conversationId, 
          "I understand you'd like to speak with a human. I've escalated your request to our support team! 🚀 An admin will be with you shortly.",
          isEscalating: true,
        );
        return;
      }

      // 3. Show "Bot is typing" status
      await updateTypingStatus(conversationId, 'ulify_admin', true);

      // 4. Fetch recent history for context
      final historySnap = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(7) // Last 7 messages (current one included)
          .get();
      
      final recentMessages = historySnap.docs
          .map((doc) => Message.fromJson(doc.data()))
          .toList()
          .reversed
          .toList();

      // Remove the current message from history (Gemini SDK adds the current message via sendMessage)
      if (recentMessages.isNotEmpty && recentMessages.last.content == userMessage) {
        recentMessages.removeLast();
      }

      // Convert to Gemini Content format
      final List<Content> geminiHistory = recentMessages.map((m) {
        if (m.senderId == 'ulify_admin') {
          return Content.model([TextPart(m.content)]);
        } else {
          return Content.text(m.content);
        }
      }).toList();

      debugPrint('🚀 Ulify Assistant: Calling getAiResponse with ${geminiHistory.length} history messages...');

      // 4. Get AI Response
      final aiService = _ref.read(aiAssistantServiceProvider);
      debugPrint('🚀 Ulify Assistant: Service instance: ${aiService.runtimeType}');

      final aiReply = await aiService.getAiResponse(
        message: userMessage,
        conversationId: conversationId,
        userId: userId,
        history: geminiHistory,
      );
      
      debugPrint('🚀 Ulify Assistant: Received reply: ${aiReply?.substring(0, 10)}...');

      if (aiReply == null || aiReply.isEmpty) {
        AppLogger.warning('Ulify Assistant: No reply received from service.', 'AI_SERVICE');
        
        // Fallback: If AI fails, ensure admins are notified so a human can step in
        _notificationSender.triggerPushNotification(
          recipientId: '',
          isBroadcast: true,
          title: '🤖 Assistant Unavailable',
          body: 'A student is waiting and Ulify Assistant failed to respond. Please check the support queue.',
          data: {'route': '/admin/support/$conversationId', 'topic': 'admins'},
        );
      }

      // 4. Clear typing status immediately after response (or failure)
      await updateTypingStatus(conversationId, 'ulify_admin', false);

      if (aiReply != null && aiReply.isNotEmpty) {
        // Human Takeover Check: Verify if an admin has been assigned while we were thinking
        final currentConv = await _firestore.collection('conversations').doc(conversationId).get();
        if (currentConv.exists && currentConv.data()?['assignedAdminId'] != null) {
          debugPrint('🚀 Ulify Assistant: Aborting reply injection - human admin took over.');
          return;
        }

        // Audit Fix: Case-insensitive and robust tag detection
        final bool needsEscalation = aiReply.toUpperCase().contains('[ESCALATE]');
        
        // Clean up the reply: Remove [ESCALATE] tag and any common Markdown symbols
        final cleanReply = aiReply
            .replaceAll(RegExp(r'\[ESCALATE\]', caseSensitive: false), '')
            .replaceAll('**', '') // Remove bold
            .replaceAll('__', '') // Remove italic
            .replaceAll('#', '')  // Remove headers
            .trim();

        AppLogger.info('Ulify Assistant: Injecting reply into Firestore', 'AI_SERVICE');

        final botMessage = Message(
          id: const Uuid().v4(),
          senderId: 'ulify_admin',
          content: cleanReply,
          type: MessageType.text,
          status: MessageStatus.sent,
          timestamp: DateTime.now(),
          metadata: {
            'isAi': true, 
            'escalated': needsEscalation,
            'botName': 'Ulify Assistant',
          },
        );

        final batch = _firestore.batch();
        
        final messageRef = _firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .doc(botMessage.id);
            
        batch.set(messageRef, botMessage.toJson());

        // Update conversation metadata
        final convRef = _firestore.collection('conversations').doc(conversationId);
        batch.update(convRef, {
          'lastMessage': cleanReply,
          'lastMessageSenderId': 'ulify_admin',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'supportStatus': needsEscalation ? 'waiting_admin' : 'waiting_user',
          'supportPriority': needsEscalation ? 'high' : 'normal',
        });

        await batch.commit();
        AppLogger.info('Ulify Assistant: Reply saved successfully', 'AI_SERVICE');

        if (needsEscalation) {
           // Notify admins that a human is needed
           _notificationSender.triggerPushNotification(
             recipientId: '',
             isBroadcast: true,
             title: '🚨 Human Required',
             body: 'Ulify Assistant has escalated a support request.',
             data: {'route': '/admin/support/$conversationId', 'topic': 'admins'},
           );
        }
      }
    } catch (e) {
      AppLogger.error('Ulify Assistant: Error injecting reply', e);
      // Ensure typing status is cleared on error
      await updateTypingStatus(conversationId, 'ulify_admin', false);
    } finally {
      _botThinkingConversations.remove(conversationId);
    }
  }

  Future<void> _injectBotMessage(String conversationId, String content, {bool isEscalating = false, bool keepWaitingAdmin = false}) async {
    final botMessage = Message(
      id: const Uuid().v4(),
      senderId: 'ulify_admin',
      content: content,
      type: MessageType.text,
      status: MessageStatus.sent,
      timestamp: DateTime.now(),
      metadata: {
        'isAi': true,
        'botName': 'Ulify Assistant',
        if (isEscalating) 'escalated': true,
      },
    );

    final batch = _firestore.batch();
    final messageRef = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(botMessage.id);

    batch.set(messageRef, botMessage.toJson());

    final convRef = _firestore.collection('conversations').doc(conversationId);
    final Map<String, dynamic> convUpdate = {
      'lastMessage': content,
      'lastMessageSenderId': 'ulify_admin',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'supportStatus': (isEscalating || keepWaitingAdmin) ? 'waiting_admin' : 'waiting_user',
    };

    if (isEscalating) {
      convUpdate['supportPriority'] = 'high';
    }

    batch.update(convRef, convUpdate);

    await batch.commit();

    if (isEscalating) {
      _notificationSender.triggerPushNotification(
        recipientId: '',
        isBroadcast: true,
        title: '🚨 Human Required',
        body: 'A student manually requested a human or the assistant escalated the request.',
        data: {'route': '/admin/support/$conversationId', 'topic': 'admins'},
      );
    }

    // Clear typing status
    await updateTypingStatus(conversationId, 'ulify_admin', false);
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
        final bool isSenderAdmin = message.senderId == 'ulify_admin' || (message.metadata?['adminId'] != null);
        
        if (isSenderAdmin) {
          // Message from admin, notify student (always at index 0 for support)
          if (participants.isNotEmpty) recipients.add(participants[0]);
        } else {
          // Message from student, notify assigned admin
          if (assignedAdminId != null) {
            recipients.add(assignedAdminId);
          } else {
            // NEW: Unassigned ticket: Use broadcast to admins topic
            await _notificationSender.triggerPushNotification(
              recipientId: '',
              isBroadcast: true,
              title: 'New Support Message',
              body: message.type == MessageType.text ? message.content : 'Sent an attachment',
              data: {
                'type': NotificationType.support.name,
                'targetId': conversationId,
                'route': '/admin/support/$conversationId',
                'topic': 'admins',
              },
            );
            return; // Exit as we've handled unassigned via broadcast
          }
        }
      } else {
        // Standard Chat Logic
        final recipientId = participants.firstWhere((id) => id != message.senderId, orElse: () => '');
        if (recipientId.isNotEmpty) recipients.add(recipientId);
        
        actorName = message.metadata?['senderName'] as String?;
      }
      
      for (final recipientId in recipients) {
        // IMPORTANT: We do not send standard in-app notifications if the recipient is an admin 
        // to avoid permission issues and workflow pollution. Admins use the Support Center.
        final bool isRecipientAdmin = (recipientId == 'ulify_admin');
        if (isRecipientAdmin) continue;

        final contextData = data['context'] as Map<String, dynamic>?;
        final module = contextData?['type'] as String?;
        
        await _notificationSender.sendNotification(
          recipientId: recipientId,
          actorId: message.senderId,
          actorName: isSupport ? 'Ulify Support' : actorName,
          title: isSupport ? 'Support Request Update' : 'New Message',
          body: message.type == MessageType.text ? message.content : 'Sent an attachment',
          type: isSupport ? NotificationType.support : NotificationType.chat,
          targetId: conversationId,
          targetType: isSupport ? 'support' : module,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error sending notification: $e');
      }
    }
  }

  String _getDeterministicConversationId(List<String> ids) {
    final cleanIds = ids.where((id) => id.isNotEmpty).toList();
    if (cleanIds.length < 2) {
      // If we only have one ID (e.g. current user), we can't make a P2P chat ID safely.
      // But for support, we always have 'ulify_admin'.
      if (!cleanIds.contains('ulify_admin')) {
         cleanIds.add('ulify_admin');
      }
    }
    final sortedIds = List<String>.from(cleanIds)..sort();
    return 'chat_${sortedIds.join('_')}';
  }

  @override
  Future<String> getOrCreateConversation({
    required List<String> participantIds,
    required ChatContext context,
  }) async {
    // Filter out empty IDs to prevent malformed conversation IDs (like chat__uid)
    final validIds = participantIds.where((id) => id.isNotEmpty).toList();
    if (validIds.length < 2) throw Exception('At least two participants required');

    final conversationId = _getDeterministicConversationId(validIds);
    final convRef = _firestore.collection('conversations').doc(conversationId);
    
    try {
      final doc = await convRef.get();
      if (doc.exists) {
        // If it exists, we update the context to the latest one being accessed
        await convRef.update({'context': context.toJson()});
        return conversationId;
      }
    } catch (e) {
      // If get() fails due to permissions, it might not exist yet.
      // We proceed to try and create it.
      debugPrint('ChatRepo: get() failed or doc missing, attempting create: $e');
    }

    final now = DateTime.now();
    final conversation = Conversation(
      id: conversationId,
      participants: validIds,
      context: context,
      lastMessageTime: now,
      unreadCounts: {for (var id in validIds) id: 0},
      expiresAt: now.add(const Duration(hours: 48)),
    );

    await convRef.set(conversation.toJson());
    return conversationId;
  }

  @override
  Future<void> markAsRead(String conversationId, String userId) async {
    if (userId.isEmpty) return;
    
    final convRef = _firestore.collection('conversations').doc(conversationId);
    
    try {
      // 1. Reset unread count
      await convRef.update({
        'unreadCounts.$userId': 0,
      }).catchError((e) {
        AppLogger.warning('Failed to reset unread count: $e', 'CHAT_REPO');
      });

      // 2. Clear associated notifications
      await _notificationSender.markAsReadByTarget(userId, conversationId);

      // 3. Mark messages from others as read
      final snapshot = await convRef
          .collection('messages')
          .where('status', isNotEqualTo: MessageStatus.read.name)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        bool needsCommit = false;
        
        for (var doc in snapshot.docs) {
          if (doc.data()['senderId'] != userId) {
            batch.update(doc.reference, {'status': MessageStatus.read.name});
            needsCommit = true;
          }
        }
        
        if (needsCommit) {
          // Check lastMessageStatus on the conversation
          final convDoc = await convRef.get(const GetOptions(source: Source.cache));
          if (convDoc.exists && convDoc.data()?['lastMessageSenderId'] != userId) {
            batch.update(convRef, {'lastMessageStatus': MessageStatus.read.name});
          }
          
          await batch.commit();
        }
      }
    } catch (e) {
      AppLogger.warning('markAsRead background error (likely rules): $e', 'CHAT_REPO');
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  @override
  Future<void> markAsDelivered(String conversationId, String userId) async {
    final convRef = _firestore.collection('conversations').doc(conversationId);
    
    try {
      final snapshot = await convRef
          .collection('messages')
          .where('status', isEqualTo: MessageStatus.sent.name)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        bool needsCommit = false;
        
        for (var doc in snapshot.docs) {
          if (doc.data()['senderId'] != userId) {
            batch.update(doc.reference, {'status': MessageStatus.delivered.name});
            needsCommit = true;
          }
        }
        
        if (needsCommit) {
          final convDoc = await convRef.get(const GetOptions(source: Source.cache));
          if (convDoc.exists && 
              convDoc.data()?['lastMessageSenderId'] != userId && 
              convDoc.data()?['lastMessageStatus'] == MessageStatus.sent.name) {
            batch.update(convRef, {'lastMessageStatus': MessageStatus.delivered.name});
          }
          await batch.commit();
        }
      }
    } catch (e) {
      AppLogger.warning('markAsDelivered background error: $e', 'CHAT_REPO');
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  @override
  Future<String> getSupportConversation(String userId) async {
    if (userId.isEmpty) throw Exception('User ID cannot be empty');

    const adminId = 'ulify_admin';
    final participantIds = [userId, adminId];
    final conversationId = _getDeterministicConversationId(participantIds);
    
    final convRef = _firestore.collection('conversations').doc(conversationId);

    try {
      final doc = await convRef.get();

      if (doc.exists) {
        final data = doc.data()!;
        final status = data['supportStatus'] as String?;

        // If the session was resolved or closed, we RE-OPEN it for the new request
        if (status == 'resolved' || status == 'closed') {
          final now = DateTime.now();
          await convRef.update({
            'supportStatus': 'active', // Reset to active so AI can try again
            'supportPriority': 'normal', // Reset priority to clear previous escalation
            'assignedAdminId': FieldValue.delete(), // Clear previous admin
            'lastMessage': 'Re-opened support request',
            'lastMessageSenderId': userId,
            'lastMessageTime': FieldValue.serverTimestamp(),
            'expiresAt': Timestamp.fromDate(now.add(const Duration(hours: 48))),
          });
        }
        return conversationId;
      }
    } catch (e) {
      debugPrint('ChatRepo: Support get() failed, attempting create: $e');
    }

    final now = DateTime.now();
    final conversation = Conversation(
      id: conversationId,
      participants: participantIds,
      context: ChatContext(
        type: 'support',
        id: 'support_$userId',
        title: 'Ulify Support',
      ),
      lastMessageTime: now,
      unreadCounts: {userId: 0, adminId: 0},
      isSupport: true,
      supportStatus: 'active', // Initial state is active, not escalated
      supportPriority: 'normal',
      expiresAt: now.add(const Duration(hours: 48)),
    );

    await convRef.set(conversation.toJson());
    return conversationId;
  }

  @override
  Future<void> deleteMessage(String conversationId, String messageId, String userId) async {
    try {
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
    } catch (e) {
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  @override
  Future<void> deleteConversation(String conversationId, String userId) async {
    try {
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
    } catch (e) {
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  // Hardening: Cache typing status locally to avoid redundant Firestore writes
  final Map<String, bool> _localTypingStatus = {};

  @override
  Future<void> updateTypingStatus(String conversationId, String userId, bool isTyping) async {
    if (conversationId.isEmpty || userId.isEmpty) return;

    final cacheKey = '${conversationId}_$userId';
    if (_localTypingStatus[cacheKey] == isTyping) return;

    try {
      _localTypingStatus[cacheKey] = isTyping;
      await _firestore.collection('conversations').doc(conversationId).update({
        'typing.$userId': isTyping ? FieldValue.serverTimestamp() : FieldValue.delete(),
      });
    } catch (e) {
      // Hardware: Ensure failure doesn't leave the cache in a bad state
      _localTypingStatus.remove(cacheKey);
      AppLogger.warning('Failed to update typing status: $e', 'CHAT_REPO');
    }
  }
}
