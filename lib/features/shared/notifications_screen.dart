import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/core/utils/date_formatter.dart';
import 'package:unihub_mobile/core/services/notification_sender.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/shared/notification_repository.dart';
import 'package:unihub_mobile/features/marketplace/shared/providers.dart';
import 'package:unihub_mobile/features/marketplace/domain/models/offer.dart';
import 'package:unihub_mobile/features/housing/shared/providers.dart';
import 'package:unihub_mobile/features/notes/shared/providers.dart';
import 'package:unihub_mobile/features/chat/domain/models/chat_context.dart';
import 'package:unihub_mobile/features/chat/shared/providers.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/empty_state.dart';
import 'feed_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  final String? module;
  const NotificationsScreen({super.key, this.module});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(appUserProvider).valueOrNull;
    final notificationsAsync = ref.watch(notificationsProvider(module));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(
          (module != null && module!.isNotEmpty)
              ? '${module![0].toUpperCase()}${module!.substring(1)} Notifications' 
              : 'Notifications',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (user != null)
            Consumer(
              builder: (context, ref, _) {
                final unreadCount = ref.watch(unreadNotificationsCountProvider(module)).valueOrNull ?? 0;
                if (unreadCount == 0) return const SizedBox.shrink();
                
                return TextButton(
                  onPressed: () => ref.read(notificationRepositoryProvider).markFeatureNotificationsAsRead(user.uid, module: module),
                  child: const Text('Mark all read'),
                );
              },
            ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) => notifications.isEmpty
            ? _buildEmptyState(context)
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(notificationsProvider(module)),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) => _NotificationTile(
                    notification: notifications[index],
                    userId: user?.uid ?? '',
                  ),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => ErrorView(
          error: err,
          onRetry: () => ref.invalidate(notificationsProvider(module)),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return const EmptyState(
      title: 'All caught up!',
      message: 'No new notifications for now.',
      icon: Icons.notifications_off_outlined,
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final UniNotification notification;
  final String userId;
  
  const _NotificationTile({required this.notification, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final aggregationCount = notification.metadata['aggregationCount'] as int? ?? 1;
    IconData iconData;
    Color iconColor;
    
    switch (notification.type) {
      case NotificationType.chat:
        iconData = Icons.chat_bubble_outline_rounded;
        iconColor = theme.colorScheme.primary;
        break;
      case NotificationType.marketplace:
        iconData = Icons.shopping_bag_outlined;
        iconColor = AppColors.marketplace;
        break;
      case NotificationType.housing:
        iconData = Icons.home_work_outlined;
        iconColor = AppColors.housing;
        break;
      case NotificationType.gig:
        iconData = Icons.work_outline_rounded;
        iconColor = AppColors.gigs;
        break;
      case NotificationType.support:
        iconData = Icons.help_outline_rounded;
        iconColor = AppColors.marketplace;
        break;
      case NotificationType.follower:
        iconData = Icons.person_add_outlined;
        iconColor = Colors.purple;
        break;
      case NotificationType.review:
        iconData = Icons.star_outline_rounded;
        iconColor = AppColors.warning;
        break;
      case NotificationType.community:
        iconData = Icons.groups_outlined;
        iconColor = Colors.teal;
        break;
      case NotificationType.notes:
        iconData = Icons.description_outlined;
        iconColor = AppColors.notes;
        break;
      default:
        iconData = Icons.notifications_none_rounded;
        iconColor = theme.colorScheme.onSurfaceVariant;
    }

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.error,
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) {
        ref.read(notificationRepositoryProvider).deleteNotification(userId, notification.id);
      },
      child: InkWell(
        onTap: () => _handleNotificationTap(context, ref, notification),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notification.isRead ? Colors.transparent : theme.colorScheme.primary.withOpacity(0.05),
            border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5))),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    backgroundColor: iconColor.withOpacity(0.1),
                    child: Icon(iconData, color: iconColor),
                  ),
                  if (aggregationCount > 1)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          aggregationCount.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          DateFormatter.formatRelative(notification.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(left: 8, top: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleNotificationTap(BuildContext context, WidgetRef ref, UniNotification n) async {
    final repository = ref.read(notificationRepositoryProvider);
    await repository.markAsRead(userId, n.id);

    if (n.deepLink != null && n.deepLink!.isNotEmpty) {
      if (context.mounted) {
        context.push(n.deepLink!);
      }
      return;
    }

    if (n.targetId == null || n.targetId!.isEmpty) return;

    // Show loading indicator for async fetches
    final messenger = ScaffoldMessenger.of(context);
    
    try {
      switch (n.type) {
        case NotificationType.chat:
        case NotificationType.support:
          final isAdmin = ref.read(appUserProvider).valueOrNull?.isAdmin ?? false;
          if (isAdmin && n.type == NotificationType.support) {
            context.push('/admin/support/${n.targetId}');
          } else {
            context.push('/chat', extra: {
              'conversationId': n.targetId,
              'otherUserName': n.actorName ?? (n.type == NotificationType.support ? 'UniHub Support' : 'Message'),
            });
          }
          break;

        case NotificationType.marketplace:
        case NotificationType.listing:
          // Special case: If it's an offer response, take them to chat
          if (n.title.contains('Offer Accepted') || n.targetType == 'marketplace_offer') {
            final listing = await ref.read(marketplaceRepositoryProvider).getListingById(n.targetId!);
            if (listing != null && context.mounted) {
              final otherId = n.actorId;
              if (otherId != null) {
                final chatContext = ChatContext(
                  type: 'marketplace',
                  id: listing.id,
                  title: listing.title,
                  thumbnail: listing.imageUrls.isNotEmpty ? listing.imageUrls.first : null,
                );
                
                final convId = await ref.read(chatRepositoryProvider).getOrCreateConversation(
                  participantIds: [userId, otherId],
                  context: chatContext,
                );
                
                if (context.mounted) {
                  context.push('/chat', extra: {
                    'conversationId': convId,
                    'otherUserName': n.actorName ?? 'Seller',
                    'context': chatContext,
                  });
                }
                return;
              }
            }
          }
          
          if (context.mounted) {
            context.push('/listing-detail/${n.targetId}');
          }
          break;

        case NotificationType.review:
          if (context.mounted) {
            context.push('/seller-profile/$userId');
          }
          break;

        case NotificationType.housing:
          if (n.targetType == 'viewing_request') {
            if (context.mounted) context.push('/viewing-requests');
            break;
          }
          if (context.mounted) context.push('/housing-detail/${n.targetId}');
          break;

        case NotificationType.notes:
          if (context.mounted) context.push('/note-detail/${n.targetId}');
          break;

        case NotificationType.gig:
          if (n.title.contains('Application Update')) {
            if (context.mounted) context.push('/my-gig-applications');
          } else if (n.title.contains('New Gig Application')) {
            if (context.mounted) context.push('/employer-dashboard');
          } else {
            if (context.mounted) context.push('/gig-detail/${n.targetId}');
          }
          break;

        case NotificationType.follower:
          if (n.actorId != null && context.mounted) {
            context.push('/seller-profile/${n.actorId}');
          }
          break;

        case NotificationType.community:
          if (context.mounted) context.push('/community');
          break;

        default:
          break;
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Could not open item: $e')));
      }
    }
  }
}
