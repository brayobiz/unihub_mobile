import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/features/auth/presentation/controllers/auth_controller.dart';
import '../../features/shared/feed_repository.dart';
import '../../models/feed_type.dart';
import '../../features/auth/shared/providers.dart';
import 'package:unihub_mobile/core/widgets/optimized_image.dart';
import '../../core/utils/category_utils.dart';

class FeedCard extends ConsumerWidget {
  final FeedItem item;
  final VoidCallback? onLike;
  final VoidCallback? onDelete;
  final bool isLiked;
  final bool showDelete;

  const FeedCard({
    super.key,
    required this.item,
    this.onLike,
    this.onDelete,
    this.isLiked = false,
    this.showDelete = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final icon = CategoryUtils.getIcon(item.type);
    final color = CategoryUtils.getColor(item.type);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.1),
                  radius: 20,
                  child: item.type == FeedType.confession 
                      ? Icon(Icons.favorite, color: color, size: 20)
                      : (item.authorPhotoUrl != null 
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: item.authorPhotoUrl!,
                                fit: BoxFit.cover,
                                memCacheWidth: 80, // Optimized for small size
                                width: 40,
                                height: 40,
                              ),
                            )
                          : Icon(Icons.person, color: color)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.type == FeedType.confession ? 'Anonymous' : item.authorName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${DateFormat.jm().format(item.createdAt)} • ${item.university ?? 'UniHub'}',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 20, color: theme.colorScheme.onSurfaceVariant),
                  color: theme.colorScheme.surface,
                  onSelected: (val) {
                    if (val == 'delete' && onDelete != null) {
                      onDelete!();
                    } else if (val == 'report') {
                      _showReportDialog(context, ref);
                    } else if (val == 'block') {
                      _showBlockConfirmation(context, ref);
                    }
                  },
                  itemBuilder: (context) {
                    final currentUser = ref.read(appUserProvider).valueOrNull;
                    final isBlocked = currentUser?.blockedUids.contains(item.authorId) ?? false;
                    final isNotMe = currentUser?.uid != item.authorId;
                    final isNotConfession = item.type != FeedType.confession;

                    return [
                      if (showDelete)
                        PopupMenuItem(
                          value: 'delete', 
                          child: Text('Delete', style: TextStyle(color: theme.colorScheme.error))
                        ),
                      PopupMenuItem(
                        value: 'report', 
                        child: Text('Report', style: TextStyle(color: theme.colorScheme.onSurface))
                      ),
                      if (isNotMe && isNotConfession)
                        PopupMenuItem(
                          value: 'block', 
                          child: Text(isBlocked ? 'Unblock Author' : 'Block Author', style: TextStyle(color: theme.colorScheme.error))
                        ),
                    ];
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (item.title.isNotEmpty)
              Text(
                item.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 16,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              item.subtitle,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant, 
                height: 1.4
              ),
            ),
            if (item.price != null && item.price!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.price!,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
            
            if (item.images.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: item.images.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: OptimizedImage(
                      imageUrl: item.images[index],
                      width: 300,
                      height: 200,
                      borderRadius: BorderRadius.circular(12),
                      thumbnailWidth: 600,
                    ),
                  ),
                ),
              ),
            ],

            Divider(height: 24, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            Row(
              children: [
                _InteractionButton(
                  context: context,
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
                  label: item.likesCount.toString(),
                  color: isLiked ? Colors.red : theme.colorScheme.onSurfaceVariant,
                  onTap: onLike,
                ),
                const SizedBox(width: 16),
                _InteractionButton(
                  context: context,
                  icon: Icons.chat_bubble_outline,
                  label: 'Comment',
                  color: theme.colorScheme.onSurfaceVariant,
                  onTap: () => _showComments(context, ref),
                ),
                const Spacer(),
                Icon(icon, size: 16, color: color.withValues(alpha: 0.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Post'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Reason for reporting...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final user = ref.read(appUserProvider).valueOrNull;
              if (user != null) {
                ref.read(feedRepositoryProvider).reportItem(item.id, user.uid, controller.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted.')));
              }
            },
            child: const Text('Report', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showBlockConfirmation(BuildContext context, WidgetRef ref) {
    final currentUser = ref.read(appUserProvider).valueOrNull;
    if (currentUser == null) return;
    
    final isBlocked = currentUser.blockedUids.contains(item.authorId);

    if (isBlocked) {
      ref.read(authControllerProvider.notifier).unblockUser(item.authorId);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block Author?'),
        content: Text('You will no longer see any posts, listings, or messages from ${item.authorName}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(authControllerProvider.notifier).blockUser(item.authorId);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Blocked ${item.authorName}'))
              );
            }, 
            child: const Text('Block', style: TextStyle(color: AppColors.error))
          ),
        ],
      ),
    );
  }

  void _showComments(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentsSheet(item: item),
    );
  }
}

class _CommentsSheet extends ConsumerStatefulWidget {
  final FeedItem item;
  const _CommentsSheet({required this.item});

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final commentsAsync = ref.watch(commentsStreamProvider(widget.item.id));
    final user = ref.watch(appUserProvider).valueOrNull;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, 
            height: 4, 
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5), 
              borderRadius: BorderRadius.circular(2)
            )
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Comments', 
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              )
            ),
          ),
          Expanded(
            child: commentsAsync.when(
              data: (comments) => comments.isEmpty
                  ? Center(
                      child: Text('No comments yet.', 
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant)
                      )
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(comment['userName'] ?? 'User', 
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface,
                                )
                              ),
                              const SizedBox(height: 2),
                              Text(comment['text'] ?? '',
                                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              loading: () => Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
              error: (err, _) => Center(child: Text('Error: $err', style: TextStyle(color: theme.colorScheme.error))),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16, left: 16, right: 16, top: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: theme.colorScheme.primary),
                  onPressed: () {
                    if (_commentController.text.isNotEmpty && user != null) {
                      ref.read(feedRepositoryProvider).addComment(
                        itemId: widget.item.id,
                        userId: user.uid,
                        userName: user.fullName,
                        text: _commentController.text.trim(),
                      );
                      _commentController.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractionButton extends StatelessWidget {
  final BuildContext context;
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  const _InteractionButton({
    required this.context,
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(label, 
              style: TextStyle(
                color: color ?? theme.colorScheme.onSurfaceVariant, 
                fontSize: 13, 
                fontWeight: FontWeight.w500
              )
            ),
          ],
        ),
      ),
    );
  }
}
