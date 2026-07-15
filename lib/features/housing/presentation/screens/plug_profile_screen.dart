import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/auth/domain/models/app_user.dart';
import 'package:unihub_mobile/features/housing/domain/models/housing_listing.dart';
import 'package:unihub_mobile/features/housing/domain/models/housing_review.dart';
import 'package:unihub_mobile/features/housing/shared/providers.dart';
import 'package:unihub_mobile/features/chat/domain/models/chat_context.dart';
import 'package:unihub_mobile/features/chat/shared/providers.dart';
import 'package:unihub_mobile/core/constants/campus_constants.dart';

class PlugProfileScreen extends ConsumerStatefulWidget {
  final String plugId;

  const PlugProfileScreen({super.key, required this.plugId});

  @override
  ConsumerState<PlugProfileScreen> createState() => _PlugProfileScreenState();
}

class _PlugProfileScreenState extends ConsumerState<PlugProfileScreen> {
  static const double avatarRadius = 55.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final plugAsync = ref.watch(publicUserProvider(widget.plugId));
    final listingsAsync = ref.watch(plugListingsProvider(widget.plugId));
    final reviewsAsync = ref.watch(plugReviewsProvider(widget.plugId));

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => context.pop(),
        ),
        actions: [
          plugAsync.when(
            data: (plug) => plug != null ? IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
              onPressed: () => _showShareMenu(context, plug),
            ) : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: plugAsync.when(
        data: (plug) {
          if (plug == null) {
            return const Center(child: Text('Housing Plug not found.'));
          }
          return Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // 1. Identity Header Section
                  SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipPath(
                            clipper: _HeaderClipper(),
                            child: Container(
                              height: 160,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF0F172A),
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
                            top: 70,
                            left: 16,
                            right: 16,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildAvatar(plug),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: _buildIdentityInfo(context, plug),
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
                    padding: const EdgeInsets.fromLTRB(16, 100, 16, 140),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildStatsSection(plug),
                        const SizedBox(height: 24),
                        _buildTrustSummary(plug),
                        const SizedBox(height: 24),
                        _buildAboutSection(plug),
                        const SizedBox(height: 24),
                        _buildPlugExpertise(plug),
                        const SizedBox(height: 24),
                        _buildActiveListingsSection(context, plug, listingsAsync),
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
                child: _buildStickyActionBar(context, plug),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildAvatar(AppUser plug) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
            backgroundColor: colorScheme.surfaceVariant,
            backgroundImage: plug.photoUrl != null ? CachedNetworkImageProvider(plug.photoUrl!) : null,
            child: plug.photoUrl == null
                ? Text(
                    plug.fullName.isNotEmpty ? plug.fullName[0].toUpperCase() : 'P',
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: colorScheme.primary),
                  )
                : null,
          ),
          if (plug.isVerifiedPlug)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.verified, color: AppColors.success, size: 24),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIdentityInfo(BuildContext context, AppUser plug) {
    final theme = Theme.of(context);
    final isOnline = plug.isOnline == true;
    final lastSeen = plug.lastSeen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                plug.fullName,
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
            if (plug.isVerifiedPlug)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.verified_rounded, color: Colors.white, size: 22),
              ),
          ],
        ),
        Row(
          children: [
            Text(
              'Housing Plug',
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
              _buildSmallInfoPill(
                context, 
                Icons.school_rounded, 
                CampusConstants.getDisplayName(plug.university),
                isVerified: plug.isStudentVerified,
              ),
              const SizedBox(width: 8),
              _buildSmallInfoPill(context, Icons.location_on_rounded, CampusConstants.getDisplayName(plug.campus)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildTrustBadge(plug.displayTrustScore.toInt()),
            const SizedBox(width: 10),
            _buildRatingBadge(plug.averageRating, plug.ratingsCount),
          ],
        ),
      ],
    );
  }

  Widget _buildSmallInfoPill(BuildContext context, IconData icon, String label, {bool isVerified = false}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isVerified 
            ? AppColors.success.withOpacity(0.1)
            : theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(100),
        border: isVerified 
            ? Border.all(color: AppColors.success.withOpacity(0.2))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon, 
            size: 12, 
            color: isVerified ? AppColors.success : theme.colorScheme.onSurfaceVariant
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12, 
              color: isVerified ? AppColors.success : theme.colorScheme.onSurface, 
              fontWeight: FontWeight.w700
            ),
          ),
          if (isVerified) ...[
            const SizedBox(width: 4),
            const Icon(Icons.verified_rounded, size: 10, color: AppColors.success),
          ],
        ],
      ),
    );
  }

  Widget _buildTrustBadge(int score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.success.withOpacity(0.1)),
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
        color: AppColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.warning.withOpacity(0.1)),
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

  Widget _buildStatsSection(AppUser plug) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem(Icons.home_work_outlined, plug.housingListingsCount.toString(), 'Listings'),
            _buildVerticalDivider(),
            _buildStatItem(Icons.people_outline_rounded, plug.completedSalesCount.toString(), 'Helped'),
            _buildVerticalDivider(),
            _buildStatItem(Icons.calendar_today_outlined, plug.createdAt != null ? DateFormat('yyyy').format(plug.createdAt!) : '2024', 'Joined'),
            _buildVerticalDivider(),
            _buildStatItem(Icons.timer_outlined, plug.responseRate, 'Responds'),
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
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface, letterSpacing: -0.5),
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

  Widget _buildAboutSection(AppUser plug) {
    return _buildSectionCard(
      'About ${plug.fullName.split(' ').first}',
      _ExpandableBio(bio: plug.bio),
      icon: Icons.person_outline_rounded,
    );
  }

  Widget _buildTrustSummary(AppUser plug) {
    return _buildSectionCard(
      'Trust & Verification',
      Column(
        children: [
          _buildVerificationRow(Icons.verified_user_rounded, 'House Plug Status', plug.isVerifiedPlug ? 'Verified Platform Plug' : 'Not Verified', plug.isVerifiedPlug),
          const SizedBox(height: 16),
          _buildVerificationRow(Icons.school_rounded, 'Student Status', plug.isStudentVerified ? 'Verified Student' : 'Not Verified', plug.isStudentVerified),
          const SizedBox(height: 16),
          _buildVerificationRow(Icons.badge_rounded, 'Identity Status', plug.isIdentityVerified ? 'Identity Confirmed' : 'Not Verified', plug.isIdentityVerified),
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
            color: (isVerified ? AppColors.success : theme.colorScheme.outlineVariant).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isVerified ? AppColors.success : theme.colorScheme.onSurfaceVariant, size: 18),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              Text(status, style: TextStyle(color: isVerified ? AppColors.success : theme.colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        if (isVerified) const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
      ],
    );
  }

  Widget _buildPlugExpertise(AppUser plug) {
    return _buildSectionCard(
      'Expertise & Areas',
      Column(
        children: [
          _buildInfoItem(Icons.location_on_rounded, 'Areas Served', CampusConstants.getDisplayName(plug.campus)),
          _buildInfoItem(Icons.home_rounded, 'Accommodation Specialties', plug.skills.isNotEmpty ? plug.skills.join(', ') : 'Hostels, Bedsitters'),
        ],
      ),
      icon: Icons.map_outlined,
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

  Widget _buildActiveListingsSection(BuildContext context, AppUser plug, AsyncValue<List<HousingListing>> listingsAsync) {
    return listingsAsync.when(
      data: (listings) => _buildSectionCard(
        'Active Listings',
        listings.isEmpty
            ? const Text('No active listings.')
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
                onPressed: () => _showAllListings(context, plug.fullName, listings),
                child: const Text('View All', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
              )
            : null,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildListingCard(BuildContext context, HousingListing listing) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => context.push('/housing-detail/${listing.id}', extra: listing),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: CachedNetworkImage(
                  imageUrl: listing.images.isNotEmpty ? listing.images.first : 'https://picsum.photos/400/300',
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
                  Text(listing.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text('KES ${NumberFormat('#,###').format(listing.rent)}', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsSection(AsyncValue<List<HousingReview>> reviewsAsync) {
    final theme = Theme.of(context);
    final user = ref.watch(appUserProvider).valueOrNull;
    final isOwnProfile = user?.uid == widget.plugId;

    return _buildSectionCard(
      'Student Reviews',
      Column(
        children: [
          if (reviewsAsync.valueOrNull?.isEmpty ?? true)
            const Text('No reviews yet.')
          else
            ...reviewsAsync.valueOrNull!.take(3).map((r) => _buildReviewItem(r)),
          if (!isOwnProfile && user != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showReviewDialog(context),
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Leave a Review'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
      icon: Icons.star_outline_rounded,
    );
  }

  void _showReviewDialog(BuildContext context) {
    final commentController = TextEditingController();
    double rating = 5.0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Review Housing Plug'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How was your experience with this plug?'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) => IconButton(
                  icon: Icon(
                    index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: AppColors.warning,
                    size: 32,
                  ),
                  onPressed: () => setDialogState(() => rating = index + 1.0),
                )),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Share your experience (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final user = ref.read(appUserProvider).valueOrNull;
                if (user == null) return;

                final review = HousingReview(
                  id: const Uuid().v4(),
                  plugId: widget.plugId,
                  userId: user.uid,
                  userName: user.fullName,
                  userPhotoUrl: user.photoUrl,
                  rating: rating,
                  comment: commentController.text.trim(),
                  createdAt: DateTime.now(),
                );

                await ref.read(housingRepositoryProvider).submitReview(review);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review submitted! Thank you.')));
                  ref.invalidate(plugReviewsProvider(widget.plugId));
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewItem(HousingReview review) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            backgroundImage: review.userPhotoUrl != null ? CachedNetworkImageProvider(review.userPhotoUrl!) : null,
            child: review.userPhotoUrl == null 
                ? Text(review.userName.isNotEmpty ? review.userName[0].toUpperCase() : 'S', 
                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(review.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Row(children: List.generate(5, (index) => Icon(Icons.star_rounded, size: 12, color: index < review.rating ? AppColors.warning : theme.colorScheme.outlineVariant))),
                  ],
                ),
                const SizedBox(height: 4),
                Text(review.comment, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(DateFormat('MMM dd, yyyy').format(review.createdAt), style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyActionBar(BuildContext context, AppUser plug) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                HapticFeedback.lightImpact();
                final currentUser = ref.read(authStateProvider).valueOrNull;
                if (currentUser == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to chat')));
                  return;
                }
                
                final chatContext = ChatContext(
                  type: 'plug',
                  id: plug.uid,
                  title: '${plug.fullName}\'s Plug Profile',
                  thumbnail: plug.photoUrl,
                );

                final conversationId = await ref.read(chatRepositoryProvider).getOrCreateConversation(
                  participantIds: [currentUser.uid, plug.uid],
                  context: chatContext,
                );

                if (context.mounted) {
                  context.push('/chat', extra: {
                    'conversationId': conversationId,
                    'otherUserName': plug.fullName,
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
              onPressed: () {
                HapticFeedback.lightImpact();
                _launchWhatsApp(context, plug.whatsappNumber ?? plug.phoneNumber, plug.fullName);
              },
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
    final whatsappUrl = Uri.parse("https://wa.me/$cleanNumber?text=Hi $name, I'm interested in one of your listings on Ulify.");
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

  void _showShareMenu(BuildContext context, AppUser plug) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Share Plug Profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildShareOption(
                    context,
                    Icons.chat_bubble_outline_rounded,
                    'Ulify Chat',
                    () {
                      Navigator.pop(context);
                      final chatContext = ChatContext(
                        type: 'plug',
                        id: plug.uid,
                        title: plug.fullName,
                        thumbnail: plug.photoUrl,
                        metadata: {'bio': plug.bio},
                      );
                      context.push('/share-to-chat', extra: chatContext);
                    },
                  ),
                  _buildShareOption(
                    context,
                    Icons.share_rounded,
                    'External Apps',
                    () {
                      Navigator.pop(context);
                      Share.share(
                        'Check out ${plug.fullName}, a Housing Plug on Ulify!\n\n'
                        '${plug.bio ?? ''}\n'
                        'Download Ulify to see their listings.',
                        subject: '${plug.fullName} on Ulify',
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareOption(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showAllListings(BuildContext context, String name, List<HousingListing> listings) {
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
      return Text('This plug has not provided a bio yet.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 15, fontStyle: FontStyle.italic, height: 1.6));
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
