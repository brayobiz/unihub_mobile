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
  const MarketplaceCard({super.key, required this.listing, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).valueOrNull;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 150 + (index * 30)), // Faster animation
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
        onTap: () => context.push('/listing-detail', extra: listing),
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Hero(
                        tag: 'listing_img_${listing.id}',
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50.withOpacity(0.5),
                          ),
                          child: listing.imageUrls.isNotEmpty
                              ? OptimizedImage(
                                  imageUrl: listing.imageUrls.first,
                                  thumbnailWidth: 400, // Request smaller thumbnail
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
                      if (listing.isFeatured)
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
                        child: Material(
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
                  padding: const EdgeInsets.all(16),
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
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'KES ${NumberFormat('#,###').format(listing.price)}',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.indigo,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified_rounded, size: 10, color: Colors.blue),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Trust ${listing.sellerTrustScore.toInt()}%',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
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
      ),
    );
  }
}
