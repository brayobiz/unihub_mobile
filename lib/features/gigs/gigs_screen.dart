import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/feed_type.dart';
import '../shared/feed_repository.dart';
import '../../widgets/feed/feed_card.dart';
import '../auth/shared/providers.dart';
import '../shared/add_feed_item_screen.dart';

final gigsFeedProvider = StreamProvider<List<FeedItem>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  return ref.watch(feedRepositoryProvider).watchFeed(FeedType.gig, university: user?.university);
});

class GigsScreen extends ConsumerStatefulWidget {
  const GigsScreen({super.key});

  @override
  ConsumerState<GigsScreen> createState() => _GigsScreenState();
}

class _GigsScreenState extends ConsumerState<GigsScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Clean up expired gigs (older than 3 days) as soon as the screen opens
    Future.microtask(() => ref.read(feedRepositoryProvider).cleanupExpiredGigs());
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(gigsFeedProvider);
    final user = ref.watch(appUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Student Gigs', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search for gigs...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
        ),
      ),
      body: feedAsync.when(
        data: (items) {
          final filteredItems = items.where((i) => 
            i.title.toLowerCase().contains(_searchQuery) || 
            i.subtitle.toLowerCase().contains(_searchQuery)
          ).toList();

          if (filteredItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.work_off_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No gigs found matching your search.', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filteredItems.length,
            itemBuilder: (context, index) {
              final item = filteredItems[index];
              final isLiked = user != null && item.likedBy.contains(user.uid);
              final isOwner = user != null && item.authorId == user.uid;

              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: GestureDetector(
                  onTap: () => context.push('/gig-detail', extra: item),
                  child: FeedCard(
                    item: _truncateGigDescription(item),
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
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddFeedItemScreen(type: FeedType.gig)),
          );
        },
        label: const Text('Post a Gig', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_task_rounded),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
    );
  }

  FeedItem _truncateGigDescription(FeedItem item) {
    if (item.subtitle.length <= 300) return item;
    
    return FeedItem(
      id: item.id,
      authorId: item.authorId,
      authorName: item.authorName,
      authorPhotoUrl: item.authorPhotoUrl,
      title: item.title,
      subtitle: '${item.subtitle.substring(0, 300)}... Read More',
      price: item.price,
      type: item.type,
      university: item.university,
      createdAt: item.createdAt,
      deadline: item.deadline,
      images: item.images,
      likesCount: item.likesCount,
      likedBy: item.likedBy,
    );
  }
}
