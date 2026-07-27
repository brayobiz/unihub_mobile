import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import '../../models/feed_type.dart';
import '../shared/feed_repository.dart';
import '../auth/shared/providers.dart';
import '../auth/domain/models/app_user.dart';
import '../../widgets/notification_badge.dart';
import 'package:unihub_mobile/core/widgets/authorization_guard.dart';
import 'package:unihub_mobile/core/services/authorization_service.dart';
import 'domain/models/confession_categories.dart';

final confessionsFeedProvider = StreamProvider<List<FeedItem>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  return ref.watch(feedRepositoryProvider).watchFeed(FeedType.confession).map((items) {
    if (user == null || user.blockedUids.isEmpty) return items;
    return items.where((item) => !user.blockedUids.contains(item.authorId)).toList();
  });
});

final selectedConfessionCategoryProvider = StateProvider<String>((ref) => 'Recent');

/// Track items hidden by the user in this session
final hiddenConfessionIdsProvider = StateProvider<Set<String>>((ref) => {});

class ConfessionsScreen extends ConsumerWidget {
  const ConfessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final feedAsync = ref.watch(confessionsFeedProvider);
    final hiddenIds = ref.watch(hiddenConfessionIdsProvider);
    final user = ref.watch(appUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. Sticky Header
            _buildStickyHeader(context, ref),

            // 2. Safety Banner
            SliverToBoxAdapter(child: _buildSafetyBanner(context)),

            // 3. Confession Feed
            feedAsync.when(
              data: (items) {
                // Initial filter: remove hidden items
                final filteredItems = items.where((item) => !hiddenIds.contains(item.id)).toList();

                if (filteredItems.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(context, ref),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = filteredItems[index];
                        return _ConfessionCard(
                          key: ValueKey(item.id),
                          item: item,
                          user: user,
                        );
                      },
                      childCount: filteredItems.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => SliverFillRemaining(
                child: Center(child: Text('Error: $err')),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyHeader(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SliverAppBar(
      pinned: true,
      floating: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      toolbarHeight: 64,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: theme.colorScheme.onSurface),
              onPressed: () => context.pop(),
              tooltip: 'Go back',
            ),
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.theater_comedy_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Confessions',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Speak freely. Stay anonymous.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: () => AuthorizationGuard.run(
                context,
                ref,
                feature: UlifyFeature.confessionsPost,
                action: () => context.push('/add-feed-item', extra: FeedType.confession),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                elevation: 0,
              ),
              child: Text(
                'Confess',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 11),
              ),
            ),
            const SizedBox(width: 4),
            const NotificationBadge(module: 'community'),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips(BuildContext context, WidgetRef ref, String selected) {
    final theme = Theme.of(context);
    final categories = [
      {'label': 'Recent', 'icon': '🔥'},
      {'label': 'Popular', 'icon': '💬'},
      {'label': 'Relationships', 'icon': '💜'},
      {'label': 'Campus Life', 'icon': '🎓'},
      {'label': 'Funny', 'icon': '😂'},
      {'label': 'Academic', 'icon': '📚'},
      {'label': 'Random', 'icon': '💭'},
    ];

    return SizedBox(
      height: 48,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final String catLabel = cat['label'] as String;
          final String catIcon = cat['icon'] as String;
          final isSelected = selected == catLabel;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(catIcon, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      catLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                selected: isSelected,
                onSelected: (val) {
                  if (val) {
                    ref.read(selectedConfessionCategoryProvider.notifier).state = catLabel;
                    HapticFeedback.lightImpact();
                  }
                },
                selectedColor: AppColors.primary,
                backgroundColor: theme.colorScheme.surface,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                  side: BorderSide(
                    color: isSelected ? Colors.transparent : theme.colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
                showCheckmark: false,
                elevation: isSelected ? 1 : 0,
                shadowColor: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSafetyBanner(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.shield_outlined, color: AppColors.primary, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'All confessions are anonymous and moderated for safety.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_rounded,
                size: 56,
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No secrets yet...',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Have something on your mind? Share it anonymously with your campus.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => AuthorizationGuard.run(
                context, 
                ref, 
                feature: UlifyFeature.confessionsPost, 
                action: () => context.push('/add-feed-item', extra: FeedType.confession),
              ),
              icon: const Icon(Icons.favorite_outline_rounded),
              label: const Text('Post Confession'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfessionCard extends ConsumerStatefulWidget {
  final FeedItem item;
  final AppUser? user;

  const _ConfessionCard({
    super.key,
    required this.item,
    this.user,
  });

  @override
  ConsumerState<_ConfessionCard> createState() => _ConfessionCardState();
}

class _ConfessionCardState extends ConsumerState<_ConfessionCard> with SingleTickerProviderStateMixin {
  late AnimationController _likeController;
  late Animation<double> _scaleAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _likeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _likeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _likeController.dispose();
    super.dispose();
  }

  void _handleLike() {
    if (widget.user != null) {
      ref.read(feedRepositoryProvider).toggleLike(widget.item.id, widget.user!.uid);
      _likeController.forward().then((_) => _likeController.reverse());
      HapticFeedback.mediumImpact();
    } else {
       _showLoginPrompt();
    }
  }

  void _showLoginPrompt() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Please log in to interact with confessions.'),
        action: SnackBarAction(label: 'Login', onPressed: () => context.go('/login')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLiked = widget.user != null && widget.item.likedBy.contains(widget.user!.uid);
    
    // Use the functional saved provider
    final savedIds = widget.user != null 
        ? ref.watch(savedFeedItemIdsProvider(widget.user!.uid)).valueOrNull ?? []
        : [];
    final isSaved = savedIds.contains(widget.item.id);

    final timeAgo = _formatTimeAgo(widget.item.createdAt);
    final categoryColor = ConfessionCategories.getColor(widget.item.category ?? 'Random');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Content Area (Clickable)
            GestureDetector(
              onTap: () => context.push('/feed-detail/${widget.item.id}', extra: widget.item),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.face_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Anonymous',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                timeAgo,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _showMoreOptions(context),
                          icon: Icon(Icons.more_horiz_rounded, color: theme.colorScheme.onSurfaceVariant, size: 20),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final textStyle = TextStyle(
                          fontSize: 15.5,
                          height: 1.5,
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.1,
                        );
                        final textSpan = TextSpan(
                          text: widget.item.subtitle, 
                          style: GoogleFonts.plusJakartaSans(textStyle: textStyle),
                        );
                        final textPainter = TextPainter(
                          text: textSpan,
                          maxLines: 4,
                          textDirection: ui.TextDirection.ltr,
                        )..layout(maxWidth: constraints.maxWidth);
                        final bool isOverflowing = textPainter.didExceedMaxLines;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.item.subtitle,
                              maxLines: _isExpanded ? null : 4,
                              overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(textStyle: textStyle),
                            ),
                            if (isOverflowing || _isExpanded)
                              GestureDetector(
                                onTap: () {
                                  setState(() => _isExpanded = !_isExpanded);
                                  HapticFeedback.lightImpact();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    _isExpanded ? 'Show less' : 'Read more',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Actions Row (Standalone interactions)
            Container(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  _ActionButton(
                    onTap: _handleLike,
                    child: Row(
                      children: [
                        ScaleTransition(
                          scale: _scaleAnimation,
                          child: Icon(
                            isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isLiked ? Colors.red : theme.colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.item.likesCount}',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                            color: isLiked ? Colors.red : theme.colorScheme.onSurface,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ActionButton(
                    onTap: () => context.push('/feed-detail/${widget.item.id}', extra: widget.item),
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, color: theme.colorScheme.onSurfaceVariant, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.item.commentsCount}',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _ActionButton(
                    onTap: () {
                      if (widget.user != null) {
                        ref.read(feedRepositoryProvider).toggleSaveFeedItem(widget.user!.uid, widget.item.id);
                        HapticFeedback.selectionClick();
                      } else {
                        _showLoginPrompt();
                      }
                    },
                    child: Icon(
                      isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      color: isSaved ? AppColors.primary : theme.colorScheme.onSurfaceVariant,
                      size: 18,
                    ),
                  ),
                  _ActionButton(
                    onTap: () {
                       ref.read(feedRepositoryProvider).incrementShareCount(widget.item.id);
                       Share.share(
                         'Anonymous Confession on Ulify:\n\n"${widget.item.subtitle}"\n\nJoin the campus community on Ulify!',
                         subject: 'Campus Confession',
                       );
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.share_outlined, color: AppColors.primary, size: 17),
                        const SizedBox(width: 4),
                        Text(
                          'Share',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final duration = DateTime.now().difference(dateTime);
    if (duration.inDays > 7) return DateFormat.yMMMd().format(dateTime);
    if (duration.inDays > 0) return '${duration.inDays}d ago';
    if (duration.inHours > 0) return '${duration.inHours}h ago';
    if (duration.inMinutes > 0) return '${duration.inMinutes}m ago';
    return 'Just now';
  }

  void _showMoreOptions(BuildContext context) {
    final isOwner = widget.user?.uid == widget.item.authorId;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwner)
              _buildModalTile(
                icon: Icons.delete_outline_rounded,
                title: 'Delete Confession',
                color: Colors.red,
                onTap: () {
                  ref.read(feedRepositoryProvider).deleteFeedItem(widget.item.id);
                  Navigator.pop(context);
                },
              ),
            _buildModalTile(
              icon: Icons.flag_outlined,
              title: 'Report Content',
              onTap: () {
                Navigator.pop(context);
                _showReportPicker();
              },
            ),
            _buildModalTile(
              icon: Icons.block_flipped,
              title: 'Hide this post',
              onTap: () {
                ref.read(hiddenConfessionIdsProvider.notifier).update((set) => {...set, widget.item.id});
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Post hidden for this session.')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalTile({required IconData icon, required String title, required VoidCallback onTap, Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }

  void _showReportPicker() {
    final reasons = ['Inappropriate content', 'Harassment', 'Spam', 'False Information', 'Other'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Why are you reporting this?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ...reasons.map((reason) => ListTile(
              title: Text(reason),
              onTap: () {
                if (widget.user != null) {
                  ref.read(feedRepositoryProvider).reportItem(widget.item.id, widget.user!.uid, reason);
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Thank you. Our moderators will review this confession.')),
                );
              },
            )),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _ActionButton({required this.child, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: child,
        ),
      ),
    );
  }
}
