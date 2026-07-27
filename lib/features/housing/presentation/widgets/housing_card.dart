import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/core/widgets/optimized_image.dart';
import '../../domain/models/housing_listing.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/shared/providers.dart';
import '../../shared/providers.dart' as housing_providers;

import 'package:unihub_mobile/features/chat/domain/models/chat_context.dart';

class HousingCard extends ConsumerWidget {
  final HousingListing listing;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteTap;
  final EdgeInsetsGeometry? margin;
  final bool isCompact;

  const HousingCard({
    super.key,
    required this.listing,
    required this.onTap,
    this.onFavoriteTap,
    this.margin,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: 'KES ', decimalDigits: 0);
    final isTaken = listing.status == HousingStatus.taken;
    
    // Watch relevant data only
    final plugAsync = ref.watch(publicUserProvider(listing.plugId));
    final savedHousingAsync = ref.watch(housing_providers.savedHousingProvider);
    
    final plug = plugAsync.valueOrNull;
    final plugIsVerified = plug?.isVerifiedPlug ?? false;
    final trustScore = plug?.displayTrustScore ?? 70.0;
    final isSaved = savedHousingAsync.valueOrNull?.any((l) => l.id == listing.id) ?? false;

    if (isCompact) {
      return _buildCompact(context, currencyFormat, isTaken, listing.distance, plugIsVerified, trustScore, isSaved);
    }

    return RepaintBoundary(
      child: Semantics(
        label: 'Housing listing: ${listing.title}, ${currencyFormat.format(listing.rent)} per month. Located in ${listing.location}, ${listing.distance}.',
        hint: 'Double tap to view details',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            margin: margin ?? const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    ExcludeSemantics(
                      child: Hero(
                        tag: 'housing_${listing.id}',
                        child: OptimizedImage(
                          imageUrl: listing.images.isNotEmpty 
                              ? listing.images.first 
                              : 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?q=80&w=2070&auto=format&fit=crop',
                          height: 155,
                          width: double.infinity,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          thumbnailWidth: 600,
                        ),
                      ),
                    ),
                    // Badges Row
                    Positioned(
                      top: 10,
                      left: 10,
                      right: 10,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (plugIsVerified)
                            Semantics(
                              label: 'Verified trusted plug',
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.verified_user_rounded, color: Colors.white, size: 9),
                                    const SizedBox(width: 4),
                                    Text('TRUSTED ${trustScore.toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
                                  ],
                                ),
                              ),
                            ),
                          const Spacer(),
                          Semantics(
                            label: 'Share property details',
                            button: true,
                            child: GestureDetector(
                              onTap: () => _shareListing(context, ref),
                              child: Container(
                                height: 36,
                                width: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface.withValues(alpha: 0.9),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.share_outlined, 
                                  size: 16, 
                                  color: theme.colorScheme.onSurfaceVariant
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Semantics(
                            label: isSaved ? 'Remove from favorites' : 'Save to favorites',
                            button: true,
                            child: GestureDetector(
                              onTap: onFavoriteTap,
                              child: Container(
                                height: 36,
                                width: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface.withValues(alpha: 0.9),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isSaved ? Icons.favorite : Icons.favorite_border, 
                                  size: 16, 
                                  color: isSaved ? AppColors.error : theme.colorScheme.primary
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Availability Badge
                    Positioned(
                      bottom: 10,
                      left: 10,
                      right: 10,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isTaken ? theme.colorScheme.error.withValues(alpha: 0.9) : Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isTaken ? 'TAKEN' : listing.type.name.replaceAll(RegExp(r'(?=[A-Z])'), ' ').toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                          ),
                          if (!isTaken)
                            _buildFreshnessBadge(context),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  listing.title,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.location_on_rounded, size: 11, color: theme.colorScheme.primary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        listing.location,
                                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                currencyFormat.format(listing.rent),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              Text(
                                '/month',
                                style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 9, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.surfaceContainerHighest,
                              image: listing.plugPhotoUrl != null 
                                  ? DecorationImage(
                                      image: CachedNetworkImageProvider(listing.plugPhotoUrl!), 
                                      fit: BoxFit.cover
                                    )
                                  : null,
                            ),
                            child: listing.plugPhotoUrl == null 
                                ? Center(child: Text(listing.plugName.isNotEmpty ? listing.plugName[0] : '?', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant))) 
                                : null,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              listing.plugName,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.directions_walk_rounded, size: 9, color: theme.colorScheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text(
                                  listing.distance,
                                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 9, fontWeight: FontWeight.w700),
                                ),
                              ],
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

  Widget _buildFreshnessBadge(BuildContext context) {
    final diff = DateTime.now().difference(listing.lastVerifiedAt);
    final isVeryFresh = diff.inHours < 24;
    
    String label;
    if (diff.inHours < 1) {
      label = 'Verified Just Now';
    } else if (diff.inHours < 24) {
      label = 'Verified Today';
    } else {
      label = 'Verified ${diff.inDays}d ago';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: isVeryFresh ? Border.all(color: AppColors.success.withValues(alpha: 0.5), width: 1) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isVeryFresh)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.circle, color: AppColors.success, size: 6),
            ),
          Text(
            label.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  void _shareListing(BuildContext context, WidgetRef ref) {
    final chatContext = ChatContext(
      type: 'housing',
      id: listing.id,
      title: listing.title,
      thumbnail: listing.images.isNotEmpty ? listing.images.first : null,
      metadata: {
        'rent': listing.rent,
        'location': listing.location,
      },
    );
    context.push('/share-to-chat', extra: chatContext);
    ref.read(housing_providers.housingRepositoryProvider).incrementShareCount(listing.id);
  }

  Widget _buildCompact(
    BuildContext context, 
    NumberFormat currencyFormat, 
    bool isTaken, 
    String? distanceLabel,
    bool plugIsVerified,
    double trustScore,
    bool isSaved,
  ) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  OptimizedImage(
                    imageUrl: listing.images.isNotEmpty 
                        ? listing.images.first 
                        : 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?q=80&w=2070&auto=format&fit=crop',
                    height: 120,
                    width: double.infinity,
                    thumbnailWidth: 400,
                  ),
                  if (plugIsVerified)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_user_rounded, color: Colors.white, size: 8),
                            const SizedBox(width: 4),
                            Text('${trustScore.toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onFavoriteTap,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSaved ? Icons.favorite : Icons.favorite_border, 
                          size: 14, 
                          color: isSaved ? AppColors.error : theme.colorScheme.primary
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${listing.type.name} • ${listing.location}',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (listing.previousRent != null && listing.previousRent! > listing.rent)
                            Text(
                              currencyFormat.format(listing.previousRent),
                              style: TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                fontSize: 9,
                              ),
                            ),
                          Text(
                            currencyFormat.format(listing.rent),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: (listing.previousRent != null && listing.previousRent! > listing.rent) 
                                ? AppColors.success 
                                : theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isTaken ? theme.colorScheme.error.withValues(alpha: 0.1) : theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isTaken ? 'TAKEN' : 'AVAIL',
                          style: TextStyle(
                            color: isTaken ? theme.colorScheme.error : theme.colorScheme.primary,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
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
    );
  }
}
