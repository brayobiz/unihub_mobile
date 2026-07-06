import 'package:cloud_firestore/cloud_firestore.dart';

enum PlatformEventType {
  verificationApproved,
  verificationRejected,
  contentRemoved,
  contentRestored,
  userBanned,
  userRestored,
  userSuspended,
  reportResolved,
  announcementPublished,
}

class PlatformEvent {
  final String id;
  final PlatformEventType type;
  final String recipientId;
  final String title;
  final String body;
  final String? targetId;
  final String? targetType;
  final String? deepLink;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;

  PlatformEvent({
    required this.id,
    required this.type,
    required this.recipientId,
    required this.title,
    required this.body,
    this.targetId,
    this.targetType,
    this.deepLink,
    this.metadata = const {},
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'recipientId': recipientId,
      'title': title,
      'body': body,
      'targetId': targetId,
      'targetType': targetType,
      'deepLink': deepLink,
      'metadata': metadata,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
