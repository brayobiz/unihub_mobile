import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/core/widgets/optimized_image.dart';
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
    final currentUserId = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final isOwner = currentUserId == listing.sellerId;
    final user = ref.watch(appUserProvider).valueOrNull;
    
    // Ensure the tag is unique to this instance
    final effectiveHeroTag = heroTag ?? 'listing_img_${listing.id}_$index';

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 150 + (index * 30)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          if (currentUserId != null) {
            ref.read(marketplaceRepositoryProvider).recordView(listing.id, userId: currentUserId);
          }
          context.push('/listing-detail', extra: {
            'listing': listing,
            'heroTag': effectiveHeroTag,
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
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
                          color: Colors.indigo.shade50.withOpacity(0.5),
                        ),
                        child: listing.imageUrls.isNotEmpty
                            ? OptimizedImage(
                                imageUrl: listing.imageUrls.first,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                thumbnailWidth: 400,
                              )
                            : Center(
                                child: Icon(
                                  Icons.shopping_bag_outlined,
                                  color: Colors.indigo.shade200,
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
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.3),
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
                    Positioned(
                      top: 8,
                      right: 8,
                      child: isOwner 
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildActionIcon(
                                icon: Icons.edit_outlined,
                                color: Colors.indigo,
                                onTap: () => context.push('/add-listing', extra: listing),
                              ),
                              const SizedBox(width: 6),
                              _buildActionIcon(
                                icon: Icons.delete_outline,
                                color: Colors.red,
                                onTap: () => _confirmDelete(context, ref),
                              ),
                            ],
                          )
                        : Material(
                            color: Colors.white.withOpacity(0.9),
                            shape: const CircleBorder(),
                            child: IconButton(
                              icon: const Icon(Icons.favorite_rounded, size: 18),
                              color: Colors.grey.shade400,
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
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'KES ${NumberFormat('#,###').format(listing.price)}',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.indigo,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 8,
                          backgroundColor: Colors.indigo.shade50,
                          child: Text(
                            listing.sellerName.isNotEmpty ? listing.sellerName[0].toUpperCase() : 'S',
                            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.indigo),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            listing.sellerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.shield_rounded, size: 10, color: Colors.green.shade400),
                        const SizedBox(width: 4),
                        Text(
                          'Trust ${listing.sellerTrustScore.toInt()}%',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionIcon({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Listing?'),
        content: const Text('This will permanently remove this item from the marketplace.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(marketplaceRepositoryProvider).deleteListing(listing.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
