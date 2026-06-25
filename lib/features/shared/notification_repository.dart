import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/shared/providers.dart';
import '../../services/notification_service.dart';

final notificationRepositoryProvider = Provider((ref) => NotificationRepository(ref.watch(firestoreProvider), ref));

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String? type; // 'chat', 'listing', 'community', 'gig', 'support'
  final String? relatedId;
  final DateTime createdAt;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.type,
    this.relatedId,
    required this.createdAt,
    this.isRead = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      type: json['type'],
      relatedId: json['relatedId'],
      createdAt: json['createdAt'] != null 
          ? (json['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      isRead: json['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'type': type,
    'relatedId': relatedId,
    'createdAt': Timestamp.fromDate(createdAt),
    'isRead': isRead,
  };
}

class NotificationRepository {
  final FirebaseFirestore _firestore;
  final Ref _ref;
  NotificationRepository(this._firestore, this._ref);

  Stream<List<AppNotification>> watchNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => 
          snapshot.docs.map((doc) => AppNotification.fromJson(doc.data())).toList());
  }

  Future<void> markAsRead(String userId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> markAllAsRead(String userId) async {
    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String userId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    String? type,
    String? relatedId,
  }) async {
    final ref = _firestore.collection('users').doc(userId).collection('notifications').doc();
    final notification = AppNotification(
      id: ref.id,
      title: title,
      body: body,
      type: type,
      relatedId: relatedId,
      createdAt: DateTime.now(),
    );
    await ref.set(notification.toJson());

    // Trigger Real Push Notification (handled by NotificationService & backend)
    await _ref.read(notificationServiceProvider).triggerPushNotification(
      recipientId: userId,
      title: title,
      body: body,
      data: {
        'type': type,
        'relatedId': relatedId,
      },
    );
  }
}
