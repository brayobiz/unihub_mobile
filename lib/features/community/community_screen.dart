import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/feed_type.dart';
import '../shared/feed_repository.dart';
import '../../widgets/feed/feed_card.dart';
import '../auth/shared/providers.dart';
import '../shared/add_feed_item_screen.dart';

final communityFeedProvider = StreamProvider<List<FeedItem>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  return ref.watch(feedRepositoryProvider).watchFeed(FeedType.community, university: user?.university);
});

class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(communityFeedProvider);
    final user = ref.watch(appUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Community Feed')),
      body: feedAsync.when(
        data: (items) => items.isEmpty
            ? const Center(child: Text('No community updates yet.'))
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddFeedItemScreen(type: FeedType.community)),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
