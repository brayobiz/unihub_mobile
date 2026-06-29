import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unihub_mobile/features/shared/domain/models/uni_notification.dart';
import 'package:unihub_mobile/features/shared/domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final FirebaseFirestore _firestore;

  NotificationRepositoryImpl(this._firestore);

  @override
  Stream<List<UniNotification>> watchNotifications(String userId, {String? module}) {
    // We use server-side ordering but client-side filtering for module
    // This avoids complex composite index requirements for every possible module/type combination
    final query = _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(100); // Limit to last 100 notifications for performance

    return query.snapshots().map((snapshot) {
      final all = snapshot.docs.map((doc) => UniNotification.fromFirestore(doc)).toList();
      
      if (module == null) return all;

      final List<String> types = [module];
      if (module == 'marketplace') {
        types.addAll(['listing', 'review']);
      }

      return all.where((n) {
        // Match by type enum name or targetType string
        return types.contains(n.type.name) || n.targetType == module;
      }).toList();
    });
  }

  @override
  Stream<int> watchUnreadCount(String userId, {String? module}) {
    // We remove orderBy here because it's not needed for count and 
    // requires a composite index when combined with where('isRead').
    final query = _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false);

    return query.snapshots().map((snapshot) {
      if (module == null) return snapshot.docs.length;

      final List<String> types = [module];
      if (module == 'marketplace') {
        types.addAll(['listing', 'review']);
      }

      return snapshot.docs.where((doc) {
        final data = doc.data();
        final type = data['type'] as String?;
        final targetType = data['targetType'] as String?;
        return types.contains(type) || targetType == module;
      }).length;
    });
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
    final query = _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false);

    final snapshot = await query.get();
    final batch = _firestore.batch();
    
    final List<String> types = module != null ? [module] : [];
    if (module == 'marketplace') {
      types.addAll(['listing', 'review']);
    }

    int count = 0;
    for (var doc in snapshot.docs) {
      if (module == null) {
        batch.update(doc.reference, {'isRead': true});
        count++;
      } else {
        final data = doc.data();
        final type = data['type'] as String?;
        final targetType = data['targetType'] as String?;
        
        if (types.contains(type) || targetType == module) {
          batch.update(doc.reference, {'isRead': true});
          count++;
        }
      }
    }
    
    if (count > 0) {
      await batch.commit();
    }
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
