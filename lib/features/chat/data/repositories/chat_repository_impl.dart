import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/conversation.dart';
import '../../domain/models/message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../shared/notification_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final FirebaseFirestore _firestore;
  final NotificationRepository _notificationRepository;

  ChatRepositoryImpl(this._firestore, this._notificationRepository);

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
      // Sort in memory to avoid Firestore Composite Index requirements
      items.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      return items;
    });
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
    
    // 1. Add message to sub-collection
    final messageRef = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(message.id);
    batch.set(messageRef, message.toJson());
    
    // 2. Update conversation summary
    final convRef = _firestore.collection('conversations').doc(conversationId);
    batch.update(convRef, {
      'lastMessage': message.content,
      'lastMessageTime': Timestamp.fromDate(message.timestamp),
    });

    await batch.commit();

    // 3. Send Notification to Recipient
    final convDoc = await _firestore.collection('conversations').doc(conversationId).get();
    if (convDoc.exists) {
      final participants = List<String>.from(convDoc.data()?['participants'] ?? []);
      final recipientId = participants.firstWhere((id) => id != message.senderId, orElse: () => '');
      
      if (recipientId.isNotEmpty) {
        await _notificationRepository.sendNotification(
          userId: recipientId,
          title: 'New Message',
          body: message.content,
          type: 'chat',
          relatedId: conversationId,
        );
      }
    }
  }

  @override
  Future<String> getOrCreateConversation({
    required String buyerId,
    required String sellerId,
    required String listingId,
    required String listingTitle,
  }) async {
    // Check if conversation already exists for this listing between these two
    final existing = await _firestore
        .collection('conversations')
        .where('participants', arrayContains: buyerId)
        .where('listingId', isEqualTo: listingId)
        .get();

    for (var doc in existing.docs) {
      final participants = List<String>.from(doc.data()['participants']);
      if (participants.contains(sellerId)) {
        return doc.id;
      }
    }

    // Create new conversation
    final newConvRef = _firestore.collection('conversations').doc();
    final conversation = Conversation(
      id: newConvRef.id,
      participants: [buyerId, sellerId],
      listingId: listingId,
      listingTitle: listingTitle,
      lastMessageTime: DateTime.now(),
      unreadCounts: {buyerId: 0, sellerId: 0},
    );

    await newConvRef.set(conversation.toJson());
    return newConvRef.id;
  }

  @override
  Future<void> markAsRead(String conversationId, String userId) async {
    await _firestore.collection('conversations').doc(conversationId).update({
      'unreadCounts.$userId': 0,
    });
  }

  @override
  Future<String> getSupportConversation(String userId) async {
    const adminId = 'unihub_admin'; // Global admin account ID
    
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
      listingTitle: 'UniHub Support',
      lastMessageTime: DateTime.now(),
      unreadCounts: {userId: 0, adminId: 0},
      lastMessage: 'Hi! How can we help you today?',
    );

    final data = conversation.toJson();
    data['isSupport'] = true;
    
    await newConvRef.set(data);
    return newConvRef.id;
  }
}
