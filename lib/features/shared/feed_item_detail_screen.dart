import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth/shared/providers.dart';
import 'feed_repository.dart';
import '../../models/feed_type.dart';
import '../../widgets/feed/feed_card.dart';

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
        final isGig = currentItem.type == FeedType.gig;
        
        return Scaffold(
          appBar: AppBar(
            title: Text(isGig ? 'Gig Details' : 'Post Details'),
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: FeedCard(
                    item: currentItem,
                    isLiked: user != null && currentItem.likedBy.contains(user.uid),
                    showDelete: user != null && currentItem.authorId == user.uid,
                    onLike: () => ref.read(feedRepositoryProvider).toggleLike(currentItem.id, user!.uid),
                    onDelete: () {
                      ref.read(feedRepositoryProvider).deleteFeedItem(currentItem.id);
                      Navigator.pop(context);
                    },
                  ),
                ),
                if (isGig && currentItem.authorId != user?.uid)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: FilledButton.icon(
                        onPressed: () => _contactAuthor(context, ref, currentItem),
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Apply for Gig'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
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

  void _contactAuthor(BuildContext context, WidgetRef ref, FeedItem item) async {
    final author = await ref.read(authRepositoryProvider).getUser(item.authorId);
    if (author == null) return;

    if (author.whatsappNumber != null && author.whatsappNumber!.isNotEmpty) {
      final url = "https://wa.me/${author.whatsappNumber}?text=Hi ${author.fullName}, I'm interested in your gig: ${item.title}";
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      }
    } else {
      // Fallback to internal chat if WhatsApp isn't available
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contacting author via internal chat...')),
      );
      // In a real app, navigate to chat screen here
    }
  }
}
