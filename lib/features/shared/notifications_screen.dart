import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unihub_mobile/core/utils/date_formatter.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/shared/notification_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).valueOrNull;
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Notifications',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (user != null)
            TextButton(
              onPressed: () => ref.read(notificationRepositoryProvider).markAllAsRead(user.uid),
              child: Text(
                'Mark all read',
                style: TextStyle(color: Colors.indigo.shade700, fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return _EmptyState();
          }

          final grouped = _groupNotifications(notifications);

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final item = grouped[index];
              if (item is String) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Text(
                    item,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.5,
                    ),
                  ),
                );
              } else {
                final n = item as UniNotification;
                return _NotificationTile(
                  notification: n,
                  userId: user!.uid,
                );
              }
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  List<dynamic> _groupNotifications(List<UniNotification> notifications) {
    if (notifications.isEmpty) return [];

    final List<dynamic> grouped = [];
    String? currentGroup;

    for (var n in notifications) {
      final group = DateFormatter.groupDate(n.createdAt);
      if (group != currentGroup) {
        grouped.add(group);
        currentGroup = group;
      }
      grouped.add(n);
    }

    return grouped;
  }
}

class _NotificationTile extends ConsumerWidget {
  final UniNotification notification;
  final String userId;
  
  const _NotificationTile({required this.notification, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    IconData iconData;
    Color iconColor;
    
    switch (notification.type) {
      case NotificationType.chat:
        iconData = Icons.chat_bubble_outline_rounded;
        iconColor = Colors.blue;
        break;
      case NotificationType.marketplace:
        iconData = Icons.shopping_bag_outlined;
        iconColor = Colors.orange;
        break;
      case NotificationType.housing:
        iconData = Icons.home_work_outlined;
        iconColor = Colors.green;
        break;
      case NotificationType.gig:
        iconData = Icons.work_outline_rounded;
        iconColor = Colors.indigo;
        break;
      case NotificationType.support:
        iconData = Icons.help_outline_rounded;
        iconColor = Colors.orange;
        break;
      case NotificationType.follower:
        iconData = Icons.person_add_outlined;
        iconColor = Colors.purple;
        break;
      case NotificationType.review:
        iconData = Icons.star_outline_rounded;
        iconColor = Colors.amber;
        break;
      case NotificationType.community:
        iconData = Icons.groups_outlined;
        iconColor = Colors.teal;
        break;
      case NotificationType.notes:
        iconData = Icons.description_outlined;
        iconColor = Colors.red;
        break;
      default:
        iconData = Icons.notifications_none_rounded;
        iconColor = Colors.grey;
    }

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red.shade50,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
      ),
      onDismissed: (_) {
        ref.read(notificationRepositoryProvider).deleteNotification(userId, notification.id);
      },
      child: Container(
        color: notification.isRead ? Colors.transparent : Colors.indigo.withOpacity(0.03),
        child: ListTile(
          onTap: () {
            if (!notification.isRead) {
              ref.read(notificationRepositoryProvider).markAsRead(userId, notification.id);
            }
            _handleNavigation(context, notification);
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: notification.isRead ? Colors.grey.shade100 : iconColor.withOpacity(0.1),
                backgroundImage: notification.actorPhotoUrl != null 
                    ? NetworkImage(notification.actorPhotoUrl!) 
                    : null,
                child: notification.actorPhotoUrl == null 
                    ? Icon(iconData, color: notification.isRead ? Colors.grey : iconColor, size: 22)
                    : null,
              ),
              if (!notification.isRead)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          title: RichText(
            text: TextSpan(
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: Colors.black87,
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: '${notification.title} ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: notification.body),
              ],
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              DateFormatter.formatRelative(notification.createdAt),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }

  void _handleNavigation(BuildContext context, UniNotification n) {
    if (n.deepLink != null && n.deepLink!.isNotEmpty) {
      try {
        context.push(n.deepLink!);
      } catch (e) {
        debugPrint('Navigation error: $e');
      }
      return;
    }

    if (n.targetId == null) return;

    switch (n.type) {
      case NotificationType.chat:
      case NotificationType.support:
        context.push('/chat', extra: {
          'conversationId': n.targetId,
          'otherUserName': n.type == NotificationType.support ? 'UniHub Support' : 'Message',
        });
        break;
      case NotificationType.marketplace:
        // We might need to fetch the full listing here, but for now we'll fail gracefully
        // or just navigate if the router supports it.
        break;
      case NotificationType.housing:
        break;
      default:
        break;
    }
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(Icons.notifications_off_outlined, size: 64, color: Colors.indigo.shade200),
          ),
          const SizedBox(height: 24),
          Text(
            'All caught up!',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'No new notifications for now. We\'ll let you know when things happen.',
              style: TextStyle(color: Colors.grey.shade600, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
