import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/feed_type.dart';
import '../shared/feed_repository.dart';
import '../../widgets/feed/feed_card.dart';
import '../auth/shared/providers.dart';
import '../shared/add_feed_item_screen.dart';
import '../../widgets/notification_badge.dart';
import '../campus_filter/presentation/widgets/campus_filter_selector.dart';
import 'package:unihub_mobile/core/utils/category_utils.dart';
import 'package:unihub_mobile/features/announcements/presentation/widgets/announcement_display.dart';
import 'package:unihub_mobile/features/ads/ads_module.dart';
import 'shared/providers.dart';

class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final feedAsync = ref.watch(communityFeedProvider);
    final user = ref.watch(appUserProvider).valueOrNull;
    const int adInterval = AdConfig.communityAdInterval;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text('Community Feed', 
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          )),
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: const [
          NotificationBadge(module: 'community'),
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const RelevantAnnouncementsWidget(feature: 'community'),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CampusFilterSelector(),
          ),
          Expanded(
            child: feedAsync.when(
              data: (items) => items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                CategoryUtils.getIcon(FeedType.community),
                                size: 56,
                                color: CategoryUtils.getColor(FeedType.community).withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'The feed is quiet',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Be the first to share an update, ask a question, or start a discussion with your campus mates.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 32),
                            FilledButton.icon(
                              onPressed: () => context.push('/add-feed-item', extra: FeedType.community),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Start Discussion'),
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length + (items.length > 0 ? (items.length ~/ adInterval) : 0),
                      itemBuilder: (context, index) {
                        // If it's an ad position
                        if ((index + 1) % (adInterval + 1) == 0) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: BannerAdWidget(),
                          );
                        }

                        // Calculate the actual item index
                        final int itemIndex = index - (index ~/ (adInterval + 1));
                        
                        if (itemIndex >= items.length) return null;

                        final item = items[itemIndex];
                        final isLiked = user != null && item.likedBy.contains(user.uid);
                        final isOwner = user != null && item.authorId == user.uid;

                        return FeedCard(
                          item: item,
                          isLiked: isLiked,
                          showDelete: isOwner,
                          onLike: () {
                            if (user != null) {
                              ref.read(feedRepositoryProvider).toggleLike(item.id, user.uid);
                            }
                          },
                          onDelete: () {
                            ref.read(feedRepositoryProvider).deleteFeedItem(item.id);
                          },
                        );
                      },
                    ),
              loading: () => Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
              error: (err, _) => Center(child: Text('Error: $err', style: TextStyle(color: theme.colorScheme.error))),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'community_fab',
        onPressed: () => context.push('/add-feed-item', extra: FeedType.community),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
