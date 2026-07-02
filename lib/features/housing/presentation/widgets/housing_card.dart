import 'package:flutter/material.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/core/widgets/optimized_image.dart';
import '../../domain/models/housing_listing.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/shared/providers.dart';

class HousingCard extends ConsumerWidget {
  final HousingListing listing;
  final VoidCallback onTap;
  final EdgeInsetsGeometry? margin;
  final bool isCompact;

  const HousingCard({
    super.key,
    required this.listing,
    required this.onTap,
    this.margin,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: 'KES ', decimalDigits: 0);
    final isTaken = listing.status == HousingStatus.taken;
    
    // Efficiently fetch plug's verification status from the platform cache
    final plugAsync = ref.watch(userByIdProvider(listing.plugId));
    final plug = plugAsync.valueOrNull;
    final plugIsVerified = plug?.isVerifiedPlug ?? false;
    final trustScore = plug?.displayTrustScore ?? 70.0;

    if (isCompact) {
      return _buildCompact(context, currencyFormat, isTaken);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin ?? const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Hero(
                  tag: 'housing_${listing.id}',
                  child: OptimizedImage(
                    imageUrl: listing.images.isNotEmpty 
                        ? listing.images.first 
                        : 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?q=80&w=2070&auto=format&fit=crop',
                    height: 180,
                    width: double.infinity,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    thumbnailWidth: 600,
                  ),
                ),
                // Badges Row
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (plugIsVerified)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_user_rounded, color: Colors.white, size: 10),
                              const SizedBox(width: 4),
                              Text('TRUSTED ${trustScore.toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                            ],
                          ),
                        ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.favorite_border, size: 16, color: theme.colorScheme.primary),
                      ),
                    ],
                  ),
                ),
                // Availability Badge
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isTaken ? theme.colorScheme.error.withValues(alpha: 0.9) : Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isTaken ? 'TAKEN' : listing.type.name.replaceAll(RegExp(r'(?=[A-Z])'), ' ').toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
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
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.location_on_rounded, size: 12, color: theme.colorScheme.primary),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${listing.university} • ${listing.location}',
                                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500),
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
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            '/month',
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.surfaceContainerHighest,
                          image: listing.plugPhotoUrl != null 
                              ? DecorationImage(image: NetworkImage(listing.plugPhotoUrl!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: listing.plugPhotoUrl == null 
                            ? Center(child: Text(listing.plugName.isNotEmpty ? listing.plugName[0] : '?', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant))) 
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          listing.plugName,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.directions_walk_rounded, size: 10, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              listing.distance,
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w700),
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
    );
  }

  Widget _buildCompact(BuildContext context, NumberFormat currencyFormat, bool isTaken) {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: OptimizedImage(
                imageUrl: listing.images.isNotEmpty 
                    ? listing.images.first 
                    : 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?q=80&w=2070&auto=format&fit=crop',
                height: 120,
                width: double.infinity,
                thumbnailWidth: 400,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
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
                      Text(
                        currencyFormat.format(listing.rent),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.primary,
                        ),
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
