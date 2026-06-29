import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unihub_mobile/features/shared/domain/models/uni_notification.dart';
import 'package:unihub_mobile/features/shared/domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final FirebaseFirestore _firestore;

  NotificationRepositoryImpl(this._firestore);

  @override
  Stream<List<UniNotification>> watchNotifications(String userId, {String? module}) {
    var query = _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true);

    if (module != null) {
      List<String> types = [module];
      
      // Feature aliases for broader matching (especially for older notifications)
      if (module == 'marketplace') {
        types.addAll(['listing', 'review']);
      }
      
      query = query.where(
        Filter.or(
          Filter('type', whereIn: types),
          Filter('targetType', isEqualTo: module),
        ),
      );
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => UniNotification.fromFirestore(doc)).toList());
  }

  @override
  Stream<int> watchUnreadCount(String userId, {String? module}) {
    var query = _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false);

    if (module != null) {
      List<String> types = [module];
      
      if (module == 'marketplace') {
        types.addAll(['listing', 'review']);
      }

      query = query.where(
        Filter.or(
          Filter('type', whereIn: types),
          Filter('targetType', isEqualTo: module),
        ),
      );
    }

    return query.snapshots().map((snapshot) => snapshot.docs.length);
  }

  @override
  Future<UniNotification> createNotification(UniNotification notification) async {
    final ref = _firestore
        .collection('users')
        .doc(notification.recipientId)
        .collection('notifications')
        .doc(notification.id.isEmpty ? null : notification.id);
    
    final finalNotification = notification.id.isEmpty 
      ? notification.copyWith(id: ref.id)
      : notification;

    await ref.set(finalNotification.toFirestore());
    return finalNotification;
  }

  @override
  Future<void> markAsRead(String userId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  @override
  Future<void> markFeatureNotificationsAsRead(String userId, {String? module}) async {
    final batch = _firestore.batch();
    var query = _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false);

    if (module != null) {
      List<String> types = [module];
      if (module == 'marketplace') {
        types.addAll(['listing', 'review']);
      }

      query = query.where(
        Filter.or(
          Filter('type', whereIn: types),
          Filter('targetType', isEqualTo: module),
        ),
      );
    }

    final snapshot = await query.get();

    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  @override
  Future<void> deleteNotification(String userId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  @override
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    String? type,
    String? relatedId,
    String? targetType,
  }) async {
    final notificationType = NotificationType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => NotificationType.system,
    );

    await createNotification(UniNotification(
      id: '',
      recipientId: userId,
      type: notificationType,
      title: title,
      body: body,
      targetId: relatedId,
      targetType: targetType,
      createdAt: DateTime.now(),
    ));
  }
}
