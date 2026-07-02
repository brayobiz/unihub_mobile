import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/auth/domain/models/app_user.dart';
import 'package:unihub_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:unihub_mobile/features/marketplace/domain/models/review.dart';
import 'package:unihub_mobile/features/marketplace/shared/providers.dart';
import 'package:unihub_mobile/features/marketplace/domain/models/listing.dart';
import 'package:unihub_mobile/features/chat/domain/models/chat_context.dart';
import 'package:unihub_mobile/features/chat/shared/providers.dart';

class SellerProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const SellerProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends ConsumerState<SellerProfileScreen> {
  static const double avatarRadius = 55.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final sellerAsync = ref.watch(otherUserProvider(widget.userId));
    final listingsAsync = ref.watch(sellerListingsProvider(widget.userId));
    final reviewsAsync = ref.watch(sellerReviewsProvider(widget.userId));

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: sellerAsync.when(
        data: (seller) {
          if (seller == null) {
            return const Center(child: Text('Seller not found.'));
          }
          return Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // 1. Identity Header Section (Transition)
                  SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipPath(
                            clipper: _HeaderClipper(),
                            child: Container(
                              height: 220,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    theme.brightness == Brightness.dark ? const Color(0xFF0F172A) : const Color(0xFF1e293b),
                                    theme.colorScheme.primary,
                                    const Color(0xFF19D3C5),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: MediaQuery.of(context).padding.top + 10,
                            left: 16,
                            right: 16,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                                  onPressed: () => context.pop(),
                                ),
                                Row(
                                  children: [
                                    _buildBlockButton(seller),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.share_outlined, color: Colors.white),
                                      onPressed: () {},
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 130,
                            left: 16,
                            right: 16,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildAvatar(seller),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: _buildIdentityInfo(context, seller),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Main Content
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 60, 16, 140),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildStatsSection(seller),
                        const SizedBox(height: 24),
                        _buildTrustSummary(seller),
                        const SizedBox(height: 24),
                        _buildAboutSection(seller),
                        const SizedBox(height: 24),
                        _buildMarketplaceInfo(seller),
                        const SizedBox(height: 24),
                        _buildActiveListingsSection(context, seller, listingsAsync),
                        const SizedBox(height: 24),
                        _buildReviewsSection(reviewsAsync),
                      ]),
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildStickyActionBar(context, seller),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildAvatar(AppUser seller) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: theme.brightness == Brightness.dark ? theme.colorScheme.outlineVariant : Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: avatarRadius,
            backgroundColor: colorScheme.surfaceContainerHighest,
            backgroundImage: seller.photoUrl != null ? CachedNetworkImageProvider(seller.photoUrl!) : null,
            child: seller.photoUrl == null
                ? Text(
                    seller.fullName.isNotEmpty ? seller.fullName[0].toUpperCase() : 'U',
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: colorScheme.primary),
                  )
                : null,
          ),
          if (seller.isVerified)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface, 
                  shape: BoxShape.circle
                ),
                child: const Icon(Icons.verified, color: AppColors.success, size: 24),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBlockButton(AppUser seller) {
    final currentUser = ref.watch(appUserProvider).valueOrNull;
    if (currentUser == null || currentUser.uid == seller.uid) return const SizedBox.shrink();
    
    final isBlocked = currentUser.blockedUids.contains(seller.uid);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: IconButton(
        icon: Icon(
          isBlocked ? Icons.check_circle_outline_rounded : Icons.block_flipped, 
          color: isBlocked ? Colors.greenAccent : Colors.white, 
          size: 20
        ),
        onPressed: () {
          if (isBlocked) {
            ref.read(authControllerProvider.notifier).unblockUser(seller.uid);
          } else {
            _showBlockConfirmation(seller);
          }
        },
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  void _showBlockConfirmation(AppUser seller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User?'),
        content: Text('You will no longer receive messages or see listings from ${seller.fullName}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(authControllerProvider.notifier).blockUser(seller.uid);
              Navigator.pop(context);
            }, 
            child: const Text('Block', style: TextStyle(color: AppColors.error))
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityInfo(BuildContext context, AppUser seller) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isOnline = seller.isOnline == true;
    final lastSeen = seller.lastSeen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                seller.fullName,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.8,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (seller.isVerified)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.verified_rounded, color: Colors.white, size: 22),
              ),
          ],
        ),
        Row(
          children: [
            Text(
              '@${seller.username ?? 'unihub_seller'}',
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            if (isOnline)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'AVAILABLE NOW',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  lastSeen != null ? _formatLastSeen(lastSeen).toUpperCase() : 'OFFLINE',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildSmallInfoPill(context, Icons.school_rounded, seller.university ?? 'Uni'),
              const SizedBox(width: 8),
              _buildSmallInfoPill(context, Icons.calendar_today_rounded, seller.yearOfStudy ?? 'Year'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildTrustBadge(seller.displayTrustScore.toInt()),
            const SizedBox(width: 10),
            _buildRatingBadge(seller.averageRating, seller.ratingsCount),
          ],
        ),
      ],
    );
  }

  Widget _buildSmallInfoPill(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12, 
              color: theme.colorScheme.onSurface, 
              fontWeight: FontWeight.w700
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustBadge(int score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield_rounded, size: 14, color: AppColors.success),
          const SizedBox(width: 6),
          Text(
            'Trust Score $score%',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.success),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBadge(double rating, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
          const SizedBox(width: 6),
          Text(
            '${rating.toStringAsFixed(1)} ($count)',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.warning),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(AppUser seller) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem(Icons.inventory_2_outlined, seller.activeListingsCount.toString(), 'Listings'),
            _buildVerticalDivider(),
            _buildStatItem(Icons.handshake_outlined, seller.completedSalesCount.toString(), 'Deals'),
            _buildVerticalDivider(),
            _buildStatItem(Icons.calendar_today_outlined, seller.createdAt != null ? DateFormat('yyyy').format(seller.createdAt!) : '2024', 'Joined'),
            _buildVerticalDivider(),
            _buildStatItem(Icons.timer_outlined, seller.responseRate, 'Responds'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return VerticalDivider(color: Theme.of(context).colorScheme.outlineVariant, thickness: 1, indent: 8, endIndent: 8);
  }

  Widget _buildSectionCard(String title, Widget content, {IconData? icon, Widget? trailing}) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.w900, 
                      color: theme.colorScheme.onSurface, 
                      letterSpacing: -0.5
                    ),
                  ),
                ],
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 20),
          content,
        ],
      ),
    );
  }

  Widget _buildAboutSection(AppUser seller) {
    return _buildSectionCard(
      'About ${seller.fullName.split(' ').first}',
      _ExpandableBio(bio: seller.bio),
      icon: Icons.person_outline_rounded,
    );
  }

  Widget _buildTrustSummary(AppUser seller) {
    return _buildSectionCard(
      'Trust & Verification',
      Column(
        children: [
          _buildVerificationRow(Icons.school_rounded, 'Student Status', seller.isStudentVerified ? 'Verified Student' : 'Not Verified', seller.isStudentVerified),
          const SizedBox(height: 16),
          _buildVerificationRow(Icons.badge_rounded, 'Identity Status', seller.isIdentityVerified ? 'Identity Confirmed' : 'Not Verified', seller.isIdentityVerified),
          const SizedBox(height: 16),
          _buildVerificationRow(Icons.phone_android_rounded, 'Phone Status', seller.isPhoneVerified ? 'Phone Verified' : 'Not Verified', seller.isPhoneVerified),
        ],
      ),
      icon: Icons.verified_user_outlined,
    );
  }

  Widget _buildVerificationRow(IconData icon, String title, String status, bool isVerified) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isVerified ? AppColors.success : theme.colorScheme.outlineVariant).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isVerified ? AppColors.success : theme.colorScheme.onSurfaceVariant, size: 18),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: theme.colorScheme.onSurface)),
              Text(status, style: TextStyle(color: isVerified ? AppColors.success : theme.colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        if (isVerified) const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
      ],
    );
  }

  Widget _buildMarketplaceInfo(AppUser seller) {
    return _buildSectionCard(
      'Marketplace Context',
      Column(
        children: [
          _buildInfoItem(Icons.location_on_rounded, 'Preferred Meetup', seller.campus ?? 'Main Campus'),
          _buildInfoItem(Icons.category_rounded, 'Selling Expertise', seller.skills.isNotEmpty ? seller.skills.join(', ') : 'General Items'),
        ],
      ),
      icon: Icons.shopping_bag_outlined,
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 18, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: theme.colorScheme.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveListingsSection(BuildContext context, AppUser seller, AsyncValue<List<Listing>> listingsAsync) {
    final theme = Theme.of(context);
    return listingsAsync.when(
      data: (listings) => _buildSectionCard(
        'Active Listings',
        listings.isEmpty
            ? Text('No active listings.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: listings.length > 4 ? 4 : listings.length,
                itemBuilder: (context, index) => _buildListingCard(context, listings[index]),
              ),
        icon: Icons.grid_view_rounded,
        trailing: listings.isNotEmpty
            ? TextButton(
                onPressed: () => _showAllListings(context, seller.fullName, listings),
                child: Text('View All', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
              )
            : null,
      ),
      loading: () => Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildListingCard(BuildContext context, Listing listing) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => context.push('/listing-detail', extra: listing),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: CachedNetworkImage(
                  imageUrl: listing.imageUrls.isNotEmpty ? listing.imageUrls.first : 'https://picsum.photos/400/300',
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title, 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis, 
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 12,
                      color: theme.colorScheme.onSurface,
                    )
                  ),
                  Text(
                    'KES ${NumberFormat('#,###').format(listing.price)}', 
                    style: TextStyle(
                      color: theme.colorScheme.primary, 
                      fontWeight: FontWeight.w900, 
                      fontSize: 13
                    )
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsSection(AsyncValue<List<Map<String, dynamic>>> reviewsAsync) {
    final theme = Theme.of(context);
    return reviewsAsync.when(
      data: (reviews) => _buildSectionCard(
        'Buyer Reviews',
        reviews.isEmpty
            ? Text('No reviews yet.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))
            : Column(
                children: reviews.take(3).map((r) => _buildReviewItem(Review.fromJson(r))).toList(),
              ),
        icon: Icons.star_outline_rounded,
      ),
      loading: () => Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildReviewItem(Review review) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            child: Text(review.reviewerName[0].toUpperCase(), style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(review.reviewerName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)),
                    Row(children: List.generate(5, (index) => Icon(Icons.star_rounded, size: 12, color: index < review.rating ? AppColors.warning : theme.colorScheme.outlineVariant))),
                  ],
                ),
                const SizedBox(height: 4),
                Text(review.comment, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(DateFormat('MMM dd, yyyy').format(review.createdAt), style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyActionBar(BuildContext context, AppUser seller) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: OutlinedButton(
              onPressed: () async {
                final currentUser = ref.read(authStateProvider).valueOrNull;
                if (currentUser == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to chat')));
                  return;
                }
                
                final chatContext = ChatContext(
                  type: 'profile',
                  id: seller.uid,
                  title: '${seller.fullName}\'s Profile',
                  thumbnail: seller.photoUrl,
                );

                final conversationId = await ref.read(chatRepositoryProvider).getOrCreateConversation(
                  participantIds: [currentUser.uid, seller.uid],
                  context: chatContext,
                );

                if (context.mounted) {
                  context.push('/chat', extra: {
                    'conversationId': conversationId,
                    'otherUserName': seller.fullName,
                    'context': chatContext,
                  });
                }
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: theme.colorScheme.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('In-App Chat', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: ElevatedButton(
              onPressed: () => _launchWhatsApp(context, seller.whatsappNumber ?? seller.phoneNumber, seller.fullName),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.message, size: 20),
                  SizedBox(width: 8),
                  Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _launchWhatsApp(BuildContext context, String? number, String name) async {
    if (number == null || number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No WhatsApp number provided.')));
      return;
    }
    String cleanNumber = number.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanNumber.startsWith('0')) {
      cleanNumber = '254${cleanNumber.substring(1)}';
    } else if (cleanNumber.length == 9 && (cleanNumber.startsWith('7') || cleanNumber.startsWith('1'))) {
      cleanNumber = '254$cleanNumber';
    }
    final whatsappUrl = Uri.parse("https://wa.me/$cleanNumber?text=Hi $name, I'm interested in one of your listings on UniHub.");
    try {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
      }
    }
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('MMM d').format(lastSeen);
  }

  void _showAllListings(BuildContext context, String name, List<Listing> listings) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Listings by $name', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.75, crossAxisSpacing: 16, mainAxisSpacing: 16),
                  itemCount: listings.length,
                  itemBuilder: (context, index) => _buildListingCard(context, listings[index]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 60);
    path.quadraticBezierTo(size.width / 2, size.height, size.width, size.height - 60);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _ExpandableBio extends StatefulWidget {
  final String? bio;
  const _ExpandableBio({this.bio});

  @override
  State<_ExpandableBio> createState() => _ExpandableBioState();
}

class _ExpandableBioState extends State<_ExpandableBio> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.bio == null || widget.bio!.trim().isEmpty) {
      return Text('This seller has not provided a bio yet.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 15, fontStyle: FontStyle.italic, height: 1.6));
    }
    final bioText = widget.bio!;
    const int maxChars = 160;
    final bool canExpand = bioText.length > maxChars;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Text(
            canExpand && !isExpanded ? '${bioText.substring(0, maxChars)}...' : bioText,
            style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface, height: 1.6, fontWeight: FontWeight.w500),
          ),
        ),
        if (canExpand) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => isExpanded = !isExpanded),
            child: Text(isExpanded ? 'Show Less' : 'Read More', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w800, fontSize: 14)),
          ),
        ],
      ],
    );
  }
}
