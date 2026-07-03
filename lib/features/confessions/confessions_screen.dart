import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/feed_type.dart';
import '../shared/feed_repository.dart';
import '../../widgets/feed/feed_card.dart';
import '../auth/shared/providers.dart';
import '../shared/add_feed_item_screen.dart';
import '../../widgets/notification_badge.dart';
import '../campus_filter/presentation/widgets/campus_filter_selector.dart';
import 'package:unihub_mobile/features/announcements/presentation/widgets/announcement_display.dart';

final confessionsFeedProvider = StreamProvider<List<FeedItem>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  return ref.watch(feedRepositoryProvider).watchFeed(FeedType.confession).map((items) {
    if (user == null || user.blockedUids.isEmpty) return items;
    return items.where((item) => !user.blockedUids.contains(item.authorId)).toList();
  });
});

class ConfessionsScreen extends ConsumerWidget {
  const ConfessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(confessionsFeedProvider);
    final user = ref.watch(appUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anonymous Confessions'),
        actions: const [
          NotificationBadge(module: 'community'),
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const RelevantAnnouncementsWidget(feature: 'confessions'),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CampusFilterSelector(),
          ),
          Expanded(
            child: feedAsync.when(
              data: (items) {
                if (items.isEmpty) {
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
                              color: Colors.red.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.favorite_rounded,
                              size: 56,
                              color: Colors.red.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No secrets yet...',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Have something on your mind? Share it anonymously with your campus.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 32),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AddFeedItemScreen(type: FeedType.confession)),
                              );
                            },
                            icon: const Icon(Icons.favorite_outline_rounded),
                            label: const Text('Post Confession'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red.shade400,
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

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
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
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddFeedItemScreen(type: FeedType.confession)),
          );
        },
        label: const Text('Confess'),
        icon: const Icon(Icons.favorite_border),
        backgroundColor: Colors.red.shade400,
      ),
    );
  }
}
