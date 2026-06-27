import 'package:unihub_mobile/features/shared/domain/models/uni_notification.dart';

abstract class NotificationRepository {
  Stream<List<UniNotification>> watchNotifications(String userId);
  Stream<int> watchUnreadCount(String userId);
  Future<UniNotification> createNotification(UniNotification notification);
  Future<void> markAsRead(String userId, String notificationId);
  Future<void> markAllAsRead(String userId);
  Future<void> deleteNotification(String userId, String notificationId);
  
  // Backward compatibility for Phase 1 transition
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    String? type,
    String? relatedId,
  });
}
