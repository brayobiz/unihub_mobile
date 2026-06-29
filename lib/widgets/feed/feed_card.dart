import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../features/shared/feed_repository.dart';
import '../../models/feed_type.dart';
import '../../features/auth/shared/providers.dart';
import '../feed/feed_type.dart' as widgets;
import 'package:unihub_mobile/core/widgets/optimized_image.dart';

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
    IconData icon;
    Color color;

    switch (item.type) {
      case FeedType.marketplace:
        icon = Icons.storefront_outlined;
        color = Colors.blue;
        break;
      case FeedType.housing:
        icon = Icons.home_work_outlined;
        color = Colors.green;
        break;
      case FeedType.notes:
        icon = Icons.menu_book_outlined;
        color = Colors.orange;
        break;
      case FeedType.community:
        icon = Icons.groups_outlined;
        color = Colors.purple;
        break;
      case FeedType.confession:
        icon = Icons.favorite_border;
        color = Colors.red;
        break;
      case FeedType.event:
        icon = Icons.event_outlined;
        color = Colors.teal;
        break;
      case FeedType.gig:
        icon = Icons.work_outline;
        color = Colors.indigo;
        break;
      case FeedType.lostFound:
        icon = Icons.search;
        color = Colors.brown;
        break;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.1),
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
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${DateFormat.jm().format(item.createdAt)} • ${item.university ?? 'UniHub'}',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (val) {
                    if (val == 'delete' && onDelete != null) {
                      onDelete!();
                    } else if (val == 'report') {
                      _showReportDialog(context, ref);
                    }
                  },
                  itemBuilder: (context) => [
                    if (showDelete)
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                    const PopupMenuItem(value: 'report', child: Text('Report')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (item.title.isNotEmpty)
              Text(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            const SizedBox(height: 4),
            Text(
              item.subtitle,
              style: TextStyle(color: Colors.grey.shade800, height: 1.4),
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

            const Divider(height: 24),
            Row(
              children: [
                _InteractionButton(
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
                  label: item.likesCount.toString(),
                  color: isLiked ? Colors.red : Colors.grey,
                  onTap: onLike,
                ),
                const SizedBox(width: 16),
                _InteractionButton(
                  icon: Icons.chat_bubble_outline,
                  label: 'Comment',
                  onTap: () => _showComments(context, ref),
                ),
                const Spacer(),
                Icon(icon, size: 16, color: color.withOpacity(0.5)),
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
    final commentsAsync = ref.watch(commentsStreamProvider(widget.item.id));
    final user = ref.watch(appUserProvider).valueOrNull;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Comments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: commentsAsync.when(
              data: (comments) => comments.isEmpty
                  ? const Center(child: Text('No comments yet.'))
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
                              Text(comment['userName'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 2),
                              Text(comment['text'] ?? ''),
                            ],
                          ),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16, left: 16, right: 16, top: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
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

final commentsStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, itemId) {
  return ref.watch(feedRepositoryProvider).watchComments(itemId);
});

class _InteractionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  const _InteractionButton({
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color ?? Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
