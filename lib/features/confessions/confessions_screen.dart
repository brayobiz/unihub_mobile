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
              data: (items) => items.isEmpty
                  ? const Center(child: Text('No confessions yet. Be the first!'))
                  : ListView.builder(
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
                    ),
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
