import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/listing.dart';
import '../../shared/providers.dart';

class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).valueOrNull;
    final listingsAsync = ref.watch(sellerListingsProvider(user?.uid ?? ''));

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Seller Hub'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: listingsAsync.when(
        data: (listings) {
          if (listings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 80, color: theme.colorScheme.outlineVariant),
                  const SizedBox(height: 20),
                  Text('You haven\'t listed anything yet.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Go to Marketplace'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: listings.length,
            itemBuilder: (context, index) {
              final listing = listings[index];
              return _MyListingCard(listing: listing);
            },
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
        error: (err, _) => Center(child: Text('Error: $err', style: TextStyle(color: theme.colorScheme.error))),
      ),
    );
  }
}

class _MyListingCard extends ConsumerWidget {
  final Listing listing;

  const _MyListingCard({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), 
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: listing.imageUrls.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(listing.imageUrls.first, fit: BoxFit.cover),
                        )
                      : Icon(Icons.shopping_bag_outlined, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.title, 
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 16,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'KES ${NumberFormat('#,###').format(listing.price)}', 
                        style: TextStyle(
                          color: theme.brightness == Brightness.dark ? Colors.greenAccent : Colors.green.shade700, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: listing.status == ListingStatus.active 
                            ? theme.colorScheme.primary.withValues(alpha: 0.1) 
                            : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          listing.status.name.toUpperCase(), 
                          style: TextStyle(
                            fontSize: 10, 
                            fontWeight: FontWeight.bold,
                            color: listing.status == ListingStatus.active ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  color: theme.colorScheme.surface,
                  iconColor: theme.colorScheme.onSurface,
                  onSelected: (val) async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      if (val == 'delete') {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: theme.colorScheme.surface,
                            title: Text('Delete Listing?', style: TextStyle(color: theme.colorScheme.onSurface)),
                            content: Text('This action cannot be undone.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete', style: TextStyle(color: theme.colorScheme.error))),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await ref.read(marketplaceRepositoryProvider).deleteListing(listing.id);
                          messenger.showSnackBar(const SnackBar(content: Text('Listing deleted')));
                        }
                      } else if (val == 'sold') {
                        await ref.read(marketplaceRepositoryProvider).updateListingStatus(listing.id, ListingStatus.sold);
                        messenger.showSnackBar(const SnackBar(content: Text('Item marked as sold! 🎉')));
                      } else if (val == 'pause') {
                        await ref.read(marketplaceRepositoryProvider).updateListingStatus(listing.id, ListingStatus.paused);
                        messenger.showSnackBar(const SnackBar(content: Text('Listing paused')));
                      } else if (val == 'activate') {
                        await ref.read(marketplaceRepositoryProvider).updateListingStatus(listing.id, ListingStatus.active);
                        messenger.showSnackBar(const SnackBar(content: Text('Listing is now active')));
                      } else if (val == 'edit') {
                        context.push('/add-listing', extra: listing);
                      }
                    } catch (e) {
                      messenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: theme.colorScheme.error));
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: theme.colorScheme.onSurface))),
                    if (listing.status == ListingStatus.active)
                      PopupMenuItem(value: 'sold', child: Text('Mark as Sold', style: TextStyle(color: theme.colorScheme.onSurface))),
                    if (listing.status == ListingStatus.active)
                      PopupMenuItem(value: 'pause', child: Text('Pause Listing', style: TextStyle(color: theme.colorScheme.onSurface)))
                    else if (listing.status == ListingStatus.paused)
                      PopupMenuItem(value: 'activate', child: Text('Re-activate', style: TextStyle(color: theme.colorScheme.onSurface))),
                    PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: theme.colorScheme.error))),
                  ],
                ),
              ],
            ),
            Divider(height: 24, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.visibility_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('${listing.viewsCount} views', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
                if (!listing.isFeatured)
                  FilledButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: theme.colorScheme.surface,
                          title: Text('Boost Listing', style: TextStyle(color: theme.colorScheme.onSurface)),
                          content: Text('Would you like to boost this listing to the top of the feed for better visibility?', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Boost Now')),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        await ref.read(marketplaceRepositoryProvider).boostListing(listing.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Listing boosted successfully!')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.bolt, size: 18),
                    label: const Text('Boost Ad'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1), 
                      borderRadius: BorderRadius.circular(8)
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.bolt, color: Colors.orange, size: 16),
                        SizedBox(width: 4),
                        Text('BOOSTED', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
