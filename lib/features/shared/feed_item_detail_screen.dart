import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/theme/app_colors.dart';
import '../auth/shared/providers.dart';
import 'feed_repository.dart';
import '../../models/feed_type.dart';
import '../../widgets/feed/feed_card.dart';
import '../confessions/domain/models/confession_categories.dart';

class FeedItemDetailScreen extends ConsumerWidget {
  final FeedItem? item;
  final String itemId;

  const FeedItemDetailScreen({
    super.key, 
    this.item, 
    required this.itemId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final feedAsync = ref.watch(feedItemByIdProvider(itemId));

    return feedAsync.when(
      data: (feedItem) {
        final currentItem = feedItem ?? item;
        if (currentItem == null) {
          return const Scaffold(body: Center(child: Text('Post no longer available.')));
        }

        final user = ref.watch(appUserProvider).valueOrNull;
        final isConfession = currentItem.type == FeedType.confession;
        final isGig = currentItem.type == FeedType.gig;
        
        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          appBar: AppBar(
            backgroundColor: theme.colorScheme.surface,
            elevation: 0,
            title: Text(
              isConfession ? 'Confession' : (isGig ? 'Gig Details' : 'Post Details'),
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: theme.colorScheme.onSurface,
              ),
            ),
            centerTitle: true,
          ),
          body: isConfession 
              ? _ConfessionDetailView(item: currentItem)
              : _GenericDetailView(item: currentItem, user: user, isGig: isGig),
        );
      },
      loading: () => item != null 
          ? _buildInitialState(item!) 
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }

  Widget _buildInitialState(FeedItem item) {
    return Scaffold(
      appBar: AppBar(title: Text(item.type == FeedType.gig ? 'Gig Details' : 'Post Details')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _GenericDetailView extends ConsumerWidget {
  final FeedItem item;
  final dynamic user;
  final bool isGig;

  const _GenericDetailView({required this.item, required this.user, required this.isGig});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showComments = item.type == FeedType.community || item.type == FeedType.gig;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: FeedCard(
                    item: item,
                    isFullView: true,
                    isLiked: user != null && item.likedBy.contains(user.uid),
                    showDelete: user != null && item.authorId == user.uid,
                    onLike: () => ref.read(feedRepositoryProvider).toggleLike(item.id, user.uid),
                    onDelete: () {
                      ref.read(feedRepositoryProvider).deleteFeedItem(item.id);
                      Navigator.pop(context);
                    },
                  ),
                ),
                if (isGig && item.authorId != user?.uid)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: FilledButton.icon(
                        onPressed: () => _contactAuthor(context, ref, item),
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Apply for Gig'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                if (showComments)
                  _CommentsList(item: item, isAnonymous: false),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        if (showComments)
          _CommentInput(item: item, user: user, isAnonymous: false),
      ],
    );
  }

  void _contactAuthor(BuildContext context, WidgetRef ref, FeedItem item) async {
    final author = await ref.read(authRepositoryProvider).getUser(item.authorId);
    if (author == null) return;

    if (author.whatsappNumber != null && author.whatsappNumber!.isNotEmpty) {
      final url = "https://wa.me/${author.whatsappNumber}?text=Hi ${author.fullName}, I'm interested in your gig: ${item.title}";
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contacting author via internal chat...')),
      );
    }
  }
}

class _ConfessionDetailView extends ConsumerWidget {
  final FeedItem item;
  const _ConfessionDetailView({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(appUserProvider).valueOrNull;
    final timeAgo = DateFormat.yMMMd().format(item.createdAt);
    final categoryColor = ConfessionCategories.getColor(item.category ?? 'Random');

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: categoryColor.withValues(alpha: 0.1),
                      radius: 20,
                      child: Icon(ConfessionCategories.getIcon(item.category ?? 'Random'), 
                        color: categoryColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Anonymous', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 15)),
                        Text('$timeAgo • ${item.category ?? 'Random'}', 
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Content
                Text(
                  item.subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    height: 1.6,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 24),
                // Interaction Bar
                Row(
                  children: [
                    _InteractionChip(
                      icon: item.likedBy.contains(user?.uid) ? Icons.favorite : Icons.favorite_border,
                      label: '${item.likesCount}',
                      color: item.likedBy.contains(user?.uid) ? Colors.red : theme.colorScheme.onSurfaceVariant,
                      onTap: () {
                        if (user != null) {
                          ref.read(feedRepositoryProvider).toggleLike(item.id, user.uid);
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    _InteractionChip(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: '${item.commentsCount}',
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.share_outlined, size: 20),
                      onPressed: () {
                        ref.read(feedRepositoryProvider).incrementShareCount(item.id);
                        Share.share(
                          'Check out this confession on Ulify:\n\n"${item.subtitle}"\n\nJoin the campus community on Ulify!',
                          subject: 'Campus Confession',
                        );
                      },
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _CommentsList(item: item, isAnonymous: true),
              ],
            ),
          ),
        ),
        // Comment Input
        _CommentInput(item: item, user: user, isAnonymous: true),
      ],
    );
  }
}

class _CommentsList extends ConsumerWidget {
  final FeedItem item;
  final bool isAnonymous;
  const _CommentsList({required this.item, required this.isAnonymous});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final commentsAsync = ref.watch(commentsStreamProvider(item.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text('Replies', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${item.commentsCount}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        commentsAsync.when(
          data: (comments) => comments.isEmpty
              ? _buildEmptyState(theme)
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    return _CommentTile(comment: comments[index], isAnonymous: isAnonymous);
                  },
                ),
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
          error: (err, _) => const Center(child: Text('Error loading replies')),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 48, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text('No replies yet. Be the first!', 
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _CommentInput extends ConsumerStatefulWidget {
  final FeedItem item;
  final dynamic user;
  final bool isAnonymous;
  const _CommentInput({required this.item, required this.user, required this.isAnonymous});

  @override
  ConsumerState<_CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends ConsumerState<_CommentInput> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = widget.user;
    if (user == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 12,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              maxLines: null,
              decoration: InputDecoration(
                hintText: 'Add a reply...',
                hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: () {
              if (_commentController.text.trim().isNotEmpty) {
                ref.read(feedRepositoryProvider).addComment(
                  itemId: widget.item.id,
                  userId: user.uid,
                  userName: widget.isAnonymous ? 'Anonymous Student' : (user.fullName ?? 'User'),
                  userPhotoUrl: widget.isAnonymous ? null : user.photoUrl,
                  text: _commentController.text.trim(),
                );
                _commentController.clear();
                FocusScope.of(context).unfocus();
              }
            },
            icon: const Icon(Icons.send_rounded),
            style: IconButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  final bool isAnonymous;
  const _CommentTile({required this.comment, required this.isAnonymous});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userName = isAnonymous ? 'Anonymous' : (comment['userName'] ?? 'User');
    final userPhotoUrl = isAnonymous ? null : comment['userPhotoUrl'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            backgroundImage: userPhotoUrl != null ? CachedNetworkImageProvider(userPhotoUrl) : null,
            child: userPhotoUrl == null 
                ? Icon(isAnonymous ? Icons.person_outline : Icons.person_rounded, size: 14, color: AppColors.primary)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 2),
                Text(comment['text'] ?? '', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _InteractionChip({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

