import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/core/widgets/optimized_image.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/models/listing.dart';
import '../../shared/providers.dart';

class MarketplaceCard extends ConsumerWidget {
  final Listing listing;
  final int index;
  final String? heroTag;
  
  const MarketplaceCard({
    super.key, 
    required this.listing, 
    required this.index,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentUserId = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final isOwner = currentUserId == listing.sellerId;
    final user = ref.watch(appUserProvider).valueOrNull;
    
    final effectiveHeroTag = heroTag ?? 'listing_img_${listing.id}_$index';

    return RepaintBoundary(
      child: Semantics(
        label: 'Listing: ${listing.title}, KES ${NumberFormat('#,###').format(listing.price)}. Condition: ${listing.condition.name}. From ${listing.sellerName}.',
        hint: 'Double tap to view listing details',
        child: GestureDetector(
          onTap: () {
            context.push('/listing-detail/${listing.id}', extra: {
              'listing': listing,
              'heroTag': effectiveHeroTag,
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Hero(
                        tag: effectiveHeroTag,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.05),
                          ),
                          child: listing.imageUrls.isNotEmpty
                              ? OptimizedImage(
                                  imageUrl: listing.imageUrls.first,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  thumbnailWidth: 400,
                                )
                              : Center(
                                  child: Icon(
                                    Icons.shopping_bag_outlined,
                                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                    size: 40,
                                  ),
                                ),
                        ),
                      ),
                      if (listing.isFeatured == true)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.warning,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.warning.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Text(
                              'FEATURED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      
                      if (listing.status != ListingStatus.active || DateTime.now().difference(listing.createdAt).inHours < 48)
                        Positioned(
                          bottom: 12,
                          left: 12,
                          child: _buildStatusBadge(listing),
                        ),

                      Positioned(
                        top: 8,
                        right: 8,
                        child: isOwner 
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildActionIcon(
                                  context,
                                  icon: Icons.edit_outlined,
                                  color: theme.colorScheme.primary,
                                  onTap: () => context.push('/add-listing', extra: listing),
                                ),
                                const SizedBox(width: 6),
                                _buildActionIcon(
                                  context,
                                  icon: Icons.delete_outline,
                                  color: AppColors.error,
                                  onTap: () => _confirmDelete(context, ref, listing),
                                ),
                              ],
                            )
                          : Material(
                              color: theme.colorScheme.surface.withValues(alpha: 0.9),
                              shape: const CircleBorder(),
                              child: IconButton(
                                icon: const Icon(Icons.favorite_rounded, size: 18),
                                color: theme.colorScheme.outlineVariant,
                                onPressed: () {
                                  if (user != null) {
                                    ref.read(marketplaceRepositoryProvider).toggleSaveListing(user.uid, listing.id);
                                  }
                                },
                              ),
                            ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold, 
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'KES ${NumberFormat('#,###').format(listing.price)}',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormatter.formatRelative(listing.createdAt),
                            style: TextStyle(
                              fontSize: 9,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (listing.viewsCount > 10)
                            Row(
                              children: [
                                Icon(Icons.visibility_outlined, size: 10, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                                const SizedBox(width: 4),
                                Text(
                                  '${NumberFormat.compact().format(listing.viewsCount)} views',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Consumer(
                        builder: (context, ref, child) {
                          final sellerAsync = ref.watch(otherUserProvider(listing.sellerId));
                          return sellerAsync.when(
                            data: (seller) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 9,
                                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                      backgroundImage: seller.photoUrl != null 
                                          ? CachedNetworkImageProvider(seller.photoUrl!)
                                          : null,
                                      child: seller.photoUrl == null
                                        ? Text(
                                            seller.fullName[0].toUpperCase(),
                                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                                          )
                                        : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        seller.fullName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (seller.isVerifiedSeller) ...[
                                      Icon(Icons.verified, color: theme.colorScheme.primary, size: 12),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (seller.displayTrustScore > 80 ? AppColors.success : AppColors.warning).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.shield_rounded, 
                                        size: 10, 
                                        color: seller.displayTrustScore > 80 ? AppColors.success : AppColors.warning
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${seller.displayTrustScore.toInt()}% Trust',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: seller.displayTrustScore > 80 ? AppColors.success : AppColors.warning,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            loading: () => const SizedBox(height: 24),
                            error: (_, __) => Text(
                              'By Student',
                              style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionIcon(BuildContext context, {required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))
          ],
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  Widget _buildStatusBadge(Listing listing) {
    Color color;
    String label;
    final isRecent = DateTime.now().difference(listing.createdAt).inHours < 48;

    if (listing.status == ListingStatus.sold) {
      color = AppColors.error;
      label = 'SOLD';
    } else if (listing.status == ListingStatus.reserved) {
      color = Colors.orange;
      label = 'RESERVED';
    } else if (isRecent) {
      color = AppColors.secondary;
      label = 'NEW';
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Listing listing) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Listing'),
        content: const Text('This will permanently remove this item from the marketplace.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final user = ref.read(appUserProvider).valueOrNull;
                if (user == null) return;
                await ref.read(marketplaceRepositoryProvider).deleteListing(listing.id, user.uid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Listing deleted successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete listing: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
