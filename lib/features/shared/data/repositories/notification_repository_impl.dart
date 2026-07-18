import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unihub_mobile/core/error/error_handler.dart';
import 'package:unihub_mobile/core/utils/app_logger.dart';
import 'package:unihub_mobile/core/services/notification_sender.dart';
import 'package:unihub_mobile/features/shared/domain/models/uni_notification.dart';
import 'package:unihub_mobile/features/shared/domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final FirebaseFirestore _firestore;

  NotificationRepositoryImpl(this._firestore);

  @override
  Stream<List<UniNotification>> watchNotifications(String userId, {String? module}) {
    if (userId.isEmpty) return Stream.value([]);
    
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
    if (userId.isEmpty) return Stream.value(0);

    // We remove orderBy here because it's not needed for count and 
    // requires a composite index when combined with where('isRead').
    final query = _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false);

    return query.snapshots().map((snapshot) {
      if (module == null) {
        int total = 0;
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final metadata = data['metadata'] as Map<String, dynamic>?;
          total += (metadata?['aggregationCount'] as int? ?? 1);
        }
        return total;
      }

      final List<String> types = [module];
      if (module == 'marketplace') {
        types.addAll(['listing', 'review']);
      }

      int total = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final type = data['type'] as String?;
        final targetType = data['targetType'] as String?;
        
        if (types.contains(type) || targetType == module) {
          final metadata = data['metadata'] as Map<String, dynamic>?;
          total += (metadata?['aggregationCount'] as int? ?? 1);
        }
      }
      return total;
    }).handleError((error) {
      AppLogger.error('Error watching unread count', error, null, 'NOTIF_REPO');
      return 0;
    });
  }

  @override
  Future<UniNotification> createNotification(UniNotification notification) async {
    try {
      final bool aggregatable = _isAggregatable(notification);
      String notificationId = notification.id;

      if (notificationId.isEmpty) {
        if (aggregatable) {
          notificationId = _generateAggregationId(notification);
        } else if (notification.title.toLowerCase().contains('saved')) {
          // Keep existing legacy de-duplication for saved items
          notificationId = '${notification.recipientId}_save_${notification.targetId}';
        }
      }

      final ref = _firestore
          .collection('users')
          .doc(notification.recipientId)
          .collection('notifications')
          .doc(notificationId.isEmpty ? null : notificationId);
      
      if (aggregatable) {
        return await _firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(ref);
          
          if (snapshot.exists) {
            final existing = UniNotification.fromFirestore(snapshot);
            
            // Only aggregate if the existing notification is still unread
            if (!existing.isRead) {
              final aggregated = _aggregate(existing, notification);
              transaction.set(ref, aggregated.toFirestore());
              AppLogger.notification('Notification aggregated: ${aggregated.id} (count: ${aggregated.metadata['aggregationCount']})');
              return aggregated;
            }
          }
          
          // Create as a new notification (either first time or previous was read)
          final finalNotification = notification.copyWith(
            id: notificationId.isEmpty ? ref.id : notificationId,
            metadata: {
              ...notification.metadata,
              'aggregationCount': 1,
              'originalTitle': notification.title,
              'originalBody': notification.body,
            },
          );
          
          transaction.set(ref, finalNotification.toFirestore());
          AppLogger.notification('Notification created: ${finalNotification.id}');
          return finalNotification;
        });
      }

      // Default non-aggregatable path
      final finalNotification = notificationId.isEmpty 
        ? notification.copyWith(id: ref.id)
        : notification.copyWith(id: notificationId);

      await ref.set(finalNotification.toFirestore(), SetOptions(merge: true));
      AppLogger.notification('Notification created: ${finalNotification.id}');
      return finalNotification;
    } catch (e) {
      AppLogger.error('Error creating/aggregating notification', e, null, 'NOTIF_REPO');
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  bool _isAggregatable(UniNotification n) {
    // 1. Messaging is always aggregatable by conversation
    if (n.type == NotificationType.chat || n.type == NotificationType.support) {
      return true;
    }

    // 2. High-volume engagement events
    if (n.type == NotificationType.follower) return true;
    if (n.type == NotificationType.community) return true; // Likes/Comments
    if (n.type == NotificationType.review) return true;

    // 3. Resource-specific engagement (Saves/Downloads)
    final title = n.title.toLowerCase();
    final body = n.body.toLowerCase();
    if (title.contains('saved') || body.contains('saved') || 
        title.contains('downloaded') || body.contains('downloaded')) {
      return true;
    }

    // STRICTLY EXCLUDED (Transactional)
    // - marketplace_offer (Each is a distinct negotiation step/order-like)
    // - gig (Transactional)
    // - system (Official announcements)

    return false;
  }

  String _generateAggregationId(UniNotification n) {
    if (n.type == NotificationType.chat || n.type == NotificationType.support) {
      return '${n.recipientId}_chat_${n.targetId}';
    }
    if (n.type == NotificationType.follower) {
      return '${n.recipientId}_follower_summary';
    }
    if (n.type == NotificationType.review) {
      return '${n.recipientId}_review_${n.targetId}';
    }
    if (n.title.toLowerCase().contains('saved')) {
      return '${n.recipientId}_save_${n.targetId}';
    }
    return '${n.recipientId}_${n.type.name}_${n.targetId}';
  }

  UniNotification _aggregate(UniNotification existing, UniNotification incoming) {
    final metadata = Map<String, dynamic>.from(existing.metadata);
    final int count = (metadata['aggregationCount'] ?? 1) + 1;
    metadata['aggregationCount'] = count;
    
    String updatedTitle = incoming.title;
    String updatedBody = incoming.body;

    // Formatting Logic
    if (existing.type == NotificationType.chat || existing.type == NotificationType.support) {
      // "Alice: Hey" -> "Alice (3 new messages): [Latest message]"
      updatedTitle = incoming.actorName ?? existing.title;
      updatedBody = '$count new messages: ${incoming.body}';
    } else if (existing.type == NotificationType.follower) {
      updatedTitle = 'New Followers';
      updatedBody = '${incoming.actorName} and ${count - 1} others followed you';
    } else if (existing.type == NotificationType.review) {
      updatedTitle = 'New Reviews';
      updatedBody = '${incoming.actorName} and ${count - 1} others reviewed your item';
    } else if (existing.title.toLowerCase().contains('saved')) {
      updatedTitle = 'New Saves';
      updatedBody = '$count people saved your ${incoming.targetType ?? 'item'}';
    } else if (existing.title.toLowerCase().contains('downloaded')) {
      updatedTitle = 'Material Downloads';
      updatedBody = '$count people downloaded "${incoming.title.replaceAll('Downloaded: ', '')}"';
    } else if (existing.type == NotificationType.community) {
      final isLike = incoming.title.toLowerCase().contains('liked');
      updatedBody = isLike 
          ? '${incoming.actorName} and ${count - 1} others liked your post'
          : '${incoming.actorName} and ${count - 1} others interacted with your post';
    }

    return existing.copyWith(
      title: updatedTitle,
      body: updatedBody,
      actorId: incoming.actorId,
      actorName: incoming.actorName,
      actorPhotoUrl: incoming.actorPhotoUrl,
      createdAt: DateTime.now(), // Move to top
      isRead: false, // Ensure it's unread
      metadata: metadata,
    );
  }

  @override
  Future<void> markAsRead(String userId, String notificationId) async {
    if (userId.isEmpty || notificationId.isEmpty) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      AppLogger.error('Error marking as read', e, null, 'NOTIF_REPO');
    }
  }

  @override
  Future<void> markTargetAsRead(String userId, String targetId) async {
    if (userId.isEmpty || targetId.isEmpty) return;
    
    try {
      final query = _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('targetId', isEqualTo: targetId)
          .where('isRead', isEqualTo: false);

      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
      AppLogger.info('Marked notifications for target $targetId as read', 'NOTIF_REPO');
    } catch (e) {
      AppLogger.error('Error marking target notifications as read', e, null, 'NOTIF_REPO');
    }
  }

  @override
  Future<void> markFeatureNotificationsAsRead(String userId, {String? module}) async {
    if (userId.isEmpty) {
      AppLogger.warning('Attempted to mark all notifications as read with empty userId', 'NOTIF_REPO');
      return;
    }
    
    try {
      final query = _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false);

      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) return;

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
        AppLogger.info('Marked $count notifications as read for user $userId', 'NOTIF_REPO');
      }
    } catch (e) {
      AppLogger.error('Error marking all as read for user $userId', e, null, 'NOTIF_REPO');
    }
  }

  @override
  Future<void> deleteNotification(String userId, String notificationId) async {
    if (userId.isEmpty || notificationId.isEmpty) return;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      AppLogger.error('Error deleting notification', e, null, 'NOTIF_REPO');
    }
  }
}
