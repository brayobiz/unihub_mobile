import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth/shared/providers.dart';
import 'feed_repository.dart';
import '../../models/feed_type.dart';
import '../../widgets/feed/feed_card.dart';

class FeedItemDetailScreen extends ConsumerWidget {
  final FeedItem item;
  const FeedItemDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).valueOrNull;
    final isGig = item.type == FeedType.gig;
    
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
                item: item,
                isLiked: user != null && item.likedBy.contains(user.uid),
                showDelete: user != null && item.authorId == user.uid,
                onLike: () => ref.read(feedRepositoryProvider).toggleLike(item.id, user!.uid),
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
            const SizedBox(height: 20),
          ],
        ),
      ),
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
