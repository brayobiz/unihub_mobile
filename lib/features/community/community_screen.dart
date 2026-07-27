import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import '../../models/feed_type.dart';
import '../shared/feed_repository.dart';
import '../../widgets/feed/feed_card.dart';
import '../auth/shared/providers.dart';
import '../../widgets/notification_badge.dart';
import '../campus_filter/presentation/widgets/campus_filter_selector.dart';
import 'package:unihub_mobile/core/utils/category_utils.dart';
import 'package:unihub_mobile/features/announcements/presentation/widgets/announcement_display.dart';
import 'package:unihub_mobile/core/widgets/authorization_guard.dart';
import 'package:unihub_mobile/core/services/authorization_service.dart';
import 'package:unihub_mobile/features/ads/ads_module.dart';
import 'shared/providers.dart';

final selectedCommunityCategoryProvider = StateProvider<String>((ref) => 'Recent');

class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final feedAsync = ref.watch(communityFeedProvider);
    final selectedCategory = ref.watch(selectedCommunityCategoryProvider);
    final user = ref.watch(appUserProvider).valueOrNull;
    const int adInterval = AdConfig.communityAdInterval;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. Sticky Header
            _buildStickyHeader(context, ref),

            // 2. Announcements & Filters
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const RelevantAnnouncementsWidget(feature: 'community'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: const CampusFilterSelector(),
                  ),
                ],
              ),
            ),

            // 3. Community Feed
            feedAsync.when(
              data: (items) {
                if (items.isEmpty) {
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
                        // Calculate ad interleaved index
                        if ((index + 1) % (adInterval + 1) == 0) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: BannerAdWidget(),
                          );
                        }

                        final int itemIndex = index - (index ~/ (adInterval + 1));
                        if (itemIndex >= items.length) return null;

                        final item = items[itemIndex];
                        final isLiked = user != null && item.likedBy.contains(user.uid);
                        final isOwner = user != null && item.authorId == user.uid;

                        return FeedCard(
                          key: ValueKey(item.id),
                          item: item,
                          isLiked: isLiked,
                          showDelete: isOwner,
                          onLike: () {
                            if (user != null) {
                              ref.read(feedRepositoryProvider).toggleLike(item.id, user.uid);
                              HapticFeedback.lightImpact();
                            }
                          },
                          onDelete: () {
                            ref.read(feedRepositoryProvider).deleteFeedItem(item.id);
                          },
                        );
                      },
                      childCount: items.length + (items.length ~/ adInterval),
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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CategoryUtils.getIcon(FeedType.community),
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Campus Feed',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Join the discussion',
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
                feature: UlifyFeature.communityPost,
                action: () => context.push('/add-feed-item', extra: FeedType.community),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                elevation: 0,
              ),
              child: Text(
                'Discuss',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 11),
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
      {'label': 'Recent', 'icon': '🕒'},
      {'label': 'Popular', 'icon': '🔥'},
      {'label': 'Questions', 'icon': '❓'},
      {'label': 'Academic', 'icon': '📚'},
      {'label': 'Events', 'icon': '🎉'},
      {'label': 'Sports', 'icon': '⚽'},
      {'label': 'Lost & Found', 'icon': '🔍'},
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
                    ref.read(selectedCommunityCategoryProvider.notifier).state = catLabel;
                    HapticFeedback.lightImpact();
                  }
                },
                selectedColor: theme.colorScheme.primary,
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
                shadowColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
          );
        },
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
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CategoryUtils.getIcon(FeedType.community),
                size: 56,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'The feed is quiet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Be the first to share an update, ask a question, or start a discussion with your campus mates.',
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
                feature: UlifyFeature.communityPost, 
                action: () => context.push('/add-feed-item', extra: FeedType.community),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Start Discussion'),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
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
