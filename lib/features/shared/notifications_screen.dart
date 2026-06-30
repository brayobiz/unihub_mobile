import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/core/utils/date_formatter.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/shared/notification_repository.dart';
import 'package:unihub_mobile/features/marketplace/shared/providers.dart';
import 'package:unihub_mobile/features/marketplace/domain/models/offer.dart';
import 'package:unihub_mobile/features/housing/shared/providers.dart';
import 'package:unihub_mobile/features/notes/shared/providers.dart';
import 'package:unihub_mobile/features/chat/domain/models/chat_context.dart';
import 'package:unihub_mobile/features/chat/shared/providers.dart';

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
            TextButton(
              onPressed: () => ref.read(notificationRepositoryProvider).markFeatureNotificationsAsRead(user.uid, module: module),
              child: Text(
                'Mark all read',
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
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
            padding: const EdgeInsets.only(bottom: 24, top: 8),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final item = grouped[index];
              if (item is String) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.2,
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
        loading: () => Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
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
    final theme = Theme.of(context);
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
        color: AppColors.error.withValues(alpha: 0.1),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
      ),
      onDismissed: (_) {
        ref.read(notificationRepositoryProvider).deleteNotification(userId, notification.id);
      },
      child: Material(
        color: notification.isRead ? Colors.transparent : theme.colorScheme.primary.withValues(alpha: 0.05),
        child: ListTile(
          onTap: () async {
            if (!notification.isRead) {
              ref.read(notificationRepositoryProvider).markAsRead(userId, notification.id);
            }
            await _handleNavigation(context, ref, notification);
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: notification.isRead ? theme.colorScheme.surfaceVariant : iconColor.withValues(alpha: 0.1),
                backgroundImage: notification.actorPhotoUrl != null 
                    ? NetworkImage(notification.actorPhotoUrl!) 
                    : null,
                child: notification.actorPhotoUrl == null 
                    ? Icon(iconData, color: notification.isRead ? theme.colorScheme.onSurfaceVariant : iconColor, size: 18)
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
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.colorScheme.surface, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          title: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface,
                height: 1.3,
                fontFamily: theme.textTheme.bodyMedium?.fontFamily,
              ),
              children: [
                TextSpan(
                  text: '${notification.title} ',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(text: notification.body, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  DateFormatter.formatRelative(notification.createdAt),
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7), 
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (notification.targetType == 'marketplace_offer' && !notification.isRead)
                _buildOfferActions(context, ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfferActions(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final offerId = notification.metadata['offerId'] as String?;
    if (offerId == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 36,
              child: OutlinedButton(
                onPressed: () => _handleOfferResponse(context, ref, offerId, OfferStatus.rejected),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: EdgeInsets.zero,
                ),
                child: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 36,
              child: FilledButton(
                onPressed: () => _handleOfferResponse(context, ref, offerId, OfferStatus.accepted),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: EdgeInsets.zero,
                ),
                child: const Text('Accept', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleOfferResponse(BuildContext context, WidgetRef ref, String offerId, OfferStatus status) async {
    final theme = Theme.of(context);
    final controller = TextEditingController();
    final isAccept = status == OfferStatus.accepted;
    
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(isAccept ? 'Accept Offer?' : 'Reject Offer?', style: TextStyle(color: theme.colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isAccept 
              ? 'Accepting this offer will mark the item as sold. You can add a message for the buyer below.' 
              : 'Add an optional reason for rejecting this offer.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: isAccept ? 'e.g. Great! Let\'s meet at...' : 'e.g. Price too low, sorry!',
                hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: isAccept ? AppColors.success : AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isAccept ? 'Accept & Close Deal' : 'Reject Offer', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final messenger = ScaffoldMessenger.of(context);
      final sellerMessage = controller.text.trim();
      
      await ref.read(marketplaceRepositoryProvider).respondToOffer(
        offerId, 
        status, 
        sellerMessage: sellerMessage.isNotEmpty ? sellerMessage : null,
      );
      
      // Mark notification as read after responding
      await ref.read(notificationRepositoryProvider).markAsRead(userId, notification.id);

      if (context.mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text(status == OfferStatus.accepted ? 'Offer accepted! Redirecting to chat...' : 'Offer rejected.'),
          backgroundColor: status == OfferStatus.accepted ? AppColors.success : AppColors.error,
        ));

        if (status == OfferStatus.accepted) {
          // If accepted, redirect to chat
          final buyerId = notification.metadata['buyerId'] as String?;
          final listingId = notification.targetId;
          
          if (buyerId != null && listingId != null) {
            final listing = await ref.read(marketplaceRepositoryProvider).getListingById(listingId);
            if (listing != null && context.mounted) {
              final chatContext = ChatContext(
                type: 'marketplace',
                id: listingId,
                title: listing.title,
                thumbnail: listing.imageUrls.isNotEmpty ? listing.imageUrls.first : null,
              );
              
              final convId = await ref.read(chatRepositoryProvider).getOrCreateConversation(
                participantIds: [userId, buyerId],
                context: chatContext,
              );
              
              if (context.mounted) {
                context.push('/chat', extra: {
                  'conversationId': convId,
                  'otherUserName': notification.actorName ?? 'Buyer',
                  'context': chatContext,
                });
              }
            }
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _handleNavigation(BuildContext context, WidgetRef ref, UniNotification n) async {
    // 1. Check for explicit deepLink first
    if (n.deepLink != null && n.deepLink!.isNotEmpty) {
      try {
        context.push(n.deepLink!);
      } catch (e) {
        debugPrint('Navigation error: $e');
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
          context.push('/chat', extra: {
            'conversationId': n.targetId,
            'otherUserName': n.actorName ?? (n.type == NotificationType.support ? 'UniHub Support' : 'Message'),
          });
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
                  participantIds: [n.recipientId, otherId],
                  context: chatContext,
                );
                if (context.mounted) {
                  context.push('/chat', extra: {
                    'conversationId': convId,
                    'otherUserName': n.actorName ?? 'Seller',
                    'context': chatContext,
                  });
                  return;
                }
              }
            }
          }

          final listing = await ref.read(marketplaceRepositoryProvider).getListingById(n.targetId!);
          if (context.mounted) {
            if (listing != null) {
              context.push('/listing-detail', extra: listing);
            } else {
              messenger.showSnackBar(const SnackBar(content: Text('This listing is no longer available.')));
            }
          }
          break;

        case NotificationType.review:
          if (n.targetType == 'marketplace') {
            final listing = await ref.read(marketplaceRepositoryProvider).getListingById(n.targetId!);
            if (context.mounted) {
              if (listing != null) {
                context.push('/seller-profile', extra: listing.sellerId);
              } else if (n.actorId != null) {
                context.push('/seller-profile', extra: n.actorId);
              }
            }
          } else {
            // Default to profile for other review types
            if (n.actorId != null) context.push('/seller-profile', extra: n.actorId);
          }
          break;

        case NotificationType.housing:
          final listing = await ref.read(housingRepositoryProvider).getListingById(n.targetId!);
          if (context.mounted) {
            if (listing != null) {
              context.push('/housing-detail', extra: listing);
            } else {
              // Try navigating to dashboard if it was a status update for a plug
              if (n.deepLink == null && (n.title.contains('Moderation') || n.title.contains('Reported'))) {
                context.push('/plug-dashboard');
              } else {
                messenger.showSnackBar(const SnackBar(content: Text('This property listing is no longer available.')));
              }
            }
          }
          break;

        case NotificationType.notes:
          final note = await ref.read(notesRepositoryProvider).getNoteById(n.targetId!);
          if (context.mounted) {
            if (note != null) {
              context.push('/note-detail', extra: note);
            } else {
              messenger.showSnackBar(const SnackBar(content: Text('These study notes are no longer available.')));
            }
          }
          break;

        case NotificationType.gig:
          if (n.title.contains('Application Update')) {
            context.push('/my-gig-applications');
          } else if (n.title.contains('New Gig Application')) {
            context.push('/employer-dashboard');
          } else {
            // Default to general gigs if targetId is a gigId
            context.push('/gigs');
          }
          break;

        case NotificationType.follower:
          if (n.actorId != null) {
            context.push('/seller-profile', extra: n.actorId);
          }
          break;

        case NotificationType.community:
          context.push('/community');
          break;

        default:
          if (n.deepLink != null) context.push(n.deepLink!);
          break;
      }
    } catch (e) {
      debugPrint('Navigation error: $e');
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Could not open: $e')));
      }
    }
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(Icons.notifications_off_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
          ),
          const SizedBox(height: 24),
          Text(
            'All caught up!',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'No new notifications for now. We\'ll let you know when things happen.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
