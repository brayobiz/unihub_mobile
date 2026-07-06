import '../utils/app_logger.dart';

enum NotificationType {
  chat,
  support,
  marketplace,
  listing,
  housing,
  notes,
  gig,
  follower,
  community,
  events,
  system,
  review,
}

enum NotificationPriority {
  low,
  normal,
  high,
}

abstract class NotificationSender {
  Future<void> sendNotification({
    required String recipientId,
    required String title,
    required String body,
    required NotificationType type,
    String? actorId,
    String? actorName,
    String? actorPhotoUrl,
    String? imageUrl,
    String? targetId,
    String? targetType,
    String? deepLink,
    NotificationPriority priority = NotificationPriority.normal,
    Map<String, dynamic>? metadata,
  });

  Future<void> notifyAdmins({
    required String title,
    required String body,
    required String route,
    Map<String, dynamic>? data,
  });

  Future<void> triggerPushNotification({
    required String recipientId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    bool isBroadcast = false,
  });

  Future<void> markAsReadByTarget(String userId, String targetId);
}
