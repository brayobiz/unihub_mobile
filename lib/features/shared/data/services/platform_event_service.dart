import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/platform_event.dart';
import '../../../../core/services/notification_sender.dart';
import '../../domain/models/uni_notification.dart';

class PlatformEventService {
  final FirebaseFirestore _firestore;
  final NotificationSender _notificationSender;

  PlatformEventService(this._firestore, this._notificationSender);

  Future<void> publishEvent(PlatformEvent event) async {
    // 1. Immutable Audit Record of the event itself
    await _firestore.collection('platform_events').add(event.toJson());

    // 2. Trigger actual notification
    await _notificationSender.sendNotification(
      recipientId: event.recipientId,
      title: event.title,
      body: event.body,
      type: _mapToNotificationType(event.type),
      targetId: event.targetId,
      targetType: event.targetType,
      deepLink: event.deepLink,
      metadata: event.metadata,
    );
  }

  NotificationType _mapToNotificationType(PlatformEventType type) {
    switch (type) {
      case PlatformEventType.verificationApproved:
      case PlatformEventType.verificationRejected:
      case PlatformEventType.userBanned:
      case PlatformEventType.userRestored:
      case PlatformEventType.userSuspended:
        return NotificationType.system;
      case PlatformEventType.contentRemoved:
      case PlatformEventType.contentRestored:
        return NotificationType.system; // Could be module specific if needed
      case PlatformEventType.reportResolved:
        return NotificationType.system;
      case PlatformEventType.announcementPublished:
        return NotificationType.system;
    }
  }
}
