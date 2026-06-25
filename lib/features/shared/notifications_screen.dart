import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../auth/shared/providers.dart';
import 'notification_repository.dart';

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(notificationRepositoryProvider).watchNotifications(user.uid);
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).valueOrNull;
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (user != null)
            TextButton(
              onPressed: () => ref.read(notificationRepositoryProvider).markAllAsRead(user.uid),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle),
                    child: Icon(Icons.notifications_none_outlined, size: 64, color: Colors.grey.shade300),
                  ),
                  const SizedBox(height: 24),
                  const Text('No notifications yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('We\'ll notify you when something important happens.', 
                    style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final n = notifications[index];
              return _NotificationTile(notification: n, userId: user!.uid);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final AppNotification notification;
  final String userId;
  const _NotificationTile({required this.notification, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    IconData iconData;
    Color iconColor;
    
    switch (notification.type) {
      case 'chat':
        iconData = Icons.chat_bubble_outline;
        iconColor = Colors.blue;
        break;
      case 'listing':
        iconData = Icons.storefront_outlined;
        iconColor = Colors.green;
        break;
      case 'gig':
        iconData = Icons.work_outline;
        iconColor = Colors.indigo;
        break;
      case 'support':
        iconData = Icons.help_outline;
        iconColor = Colors.orange;
        break;
      default:
        iconData = Icons.notifications_none;
        iconColor = Colors.grey;
    }

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => ref.read(notificationRepositoryProvider).deleteNotification(userId, notification.id),
      child: ListTile(
        onTap: () {
          ref.read(notificationRepositoryProvider).markAsRead(userId, notification.id);
          _handleNavigation(context, notification);
        },
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: iconColor.withValues(alpha: 0.1),
              child: Icon(iconData, color: iconColor, size: 20),
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
        title: Text(notification.title, 
          style: TextStyle(fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold, fontSize: 15)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.body, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            const SizedBox(height: 4),
            Text(DateFormat('MMM dd, HH:mm').format(notification.createdAt), 
              style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  void _handleNavigation(BuildContext context, AppNotification n) {
    if (n.relatedId == null) return;
    
    switch (n.type) {
      case 'chat':
      case 'support':
        context.push('/chat', extra: {
          'conversationId': n.relatedId,
          'otherUserName': n.type == 'support' ? 'UniHub Support' : 'Message',
        });
        break;
      case 'listing':
        // Navigate to listing detail if we have the ID
        break;
    }
  }
}
