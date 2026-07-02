import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  chat,
  listing,
  community,
  gig,
  support,
  follower,
  review,
  system,
  marketplace,
  housing,
  notes,
}

enum NotificationPriority {
  low,
  normal,
  high,
}

class UniNotification {
  final String id;
  final String recipientId;
  final String? actorId;
  final String? actorName;
  final String? actorPhotoUrl;
  final NotificationType type;
  final String title;
  final String body;
  final String? imageUrl;
  final String? targetId;
  final String? targetType;
  final String? deepLink;
  final bool isRead;
  final NotificationPriority priority;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  UniNotification({
    required this.id,
    required this.recipientId,
    this.actorId,
    this.actorName,
    this.actorPhotoUrl,
    required this.type,
    required this.title,
    required this.body,
    this.imageUrl,
    this.targetId,
    this.targetType,
    this.deepLink,
    this.isRead = false,
    this.priority = NotificationPriority.normal,
    required this.createdAt,
    this.metadata = const {},
  });

  factory UniNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UniNotification(
      id: doc.id,
      recipientId: data['recipientId'] ?? '',
      actorId: data['actorId'],
      actorName: data['actorName'],
      actorPhotoUrl: data['actorPhotoUrl'],
      type: NotificationType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => NotificationType.system,
      ),
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      imageUrl: data['imageUrl'],
      targetId: data['targetId'],
      targetType: data['targetType'],
      deepLink: data['deepLink'],
      isRead: data['isRead'] ?? false,
      priority: NotificationPriority.values.firstWhere(
        (e) => e.name == data['priority'],
        orElse: () => NotificationPriority.normal,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: data['metadata'] ?? {},
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'recipientId': recipientId,
      'actorId': actorId,
      'actorName': actorName,
      'actorPhotoUrl': actorPhotoUrl,
      'type': type.name,
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'targetId': targetId,
      'targetType': targetType,
      'deepLink': deepLink,
      'isRead': isRead,
      'priority': priority.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'metadata': metadata,
    };
  }

  UniNotification copyWith({
    String? id,
    String? recipientId,
    String? actorId,
    String? actorName,
    String? actorPhotoUrl,
    NotificationType? type,
    String? title,
    String? body,
    String? imageUrl,
    String? targetId,
    String? targetType,
    String? deepLink,
    bool? isRead,
    NotificationPriority? priority,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return UniNotification(
      id: id ?? this.id,
      recipientId: recipientId ?? this.recipientId,
      actorId: actorId ?? this.actorId,
      actorName: actorName ?? this.actorName,
      actorPhotoUrl: actorPhotoUrl ?? this.actorPhotoUrl,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      imageUrl: imageUrl ?? this.imageUrl,
      targetId: targetId ?? this.targetId,
      targetType: targetType ?? this.targetType,
      deepLink: deepLink ?? this.deepLink,
      isRead: isRead ?? this.isRead,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }
}
