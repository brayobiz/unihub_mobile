import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/feed_type.dart';
import '../shared/feed_repository.dart';
import '../../widgets/feed/feed_card.dart';
import '../auth/shared/providers.dart';
import '../../widgets/notification_badge.dart';
import '../campus_filter/presentation/widgets/campus_filter_selector.dart';
import '../campus_filter/shared/providers.dart';
import '../campus_filter/domain/models/browsing_scope.dart';
import 'package:unihub_mobile/core/utils/category_utils.dart';
import 'package:unihub_mobile/core/widgets/authorization_guard.dart';
import 'package:unihub_mobile/core/services/authorization_service.dart';
import 'package:unihub_mobile/features/announcements/presentation/widgets/announcement_display.dart';
import 'package:unihub_mobile/features/ads/ads_module.dart';
import 'shared/providers.dart';

class GigsScreen extends ConsumerStatefulWidget {
  const GigsScreen({super.key});

  @override
  ConsumerState<GigsScreen> createState() => _GigsScreenState();
}

class _GigsScreenState extends ConsumerState<GigsScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Clean up expired gigs (older than 3 days) as soon as the screen opens
    Future.microtask(() => ref.read(feedRepositoryProvider).cleanupExpiredGigs());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final feedAsync = ref.watch(gigsFeedProvider);
    final user = ref.watch(appUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text('Student Gigs', 
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          )),
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          TextButton.icon(
            onPressed: () => AuthorizationGuard.run(
              context, 
              ref, 
              feature: UlifyFeature.gigsPost, 
              action: () => context.push('/add-feed-item', extra: FeedType.gig),
            ),
            icon: Icon(Icons.add_circle_outline_rounded, size: 20, color: theme.colorScheme.primary),
            label: Text(
              'Post Gig', 
              style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const NotificationBadge(module: 'gig'),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search for gigs...',
                hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const RelevantAnnouncementsWidget(feature: 'gigs'),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CampusFilterSelector(),
          ),
          _buildRoleApplicationBanner(context, ref),
          Expanded(
            child: feedAsync.when(
              data: (items) {
                final filteredItems = items.where((i) => 
                  i.title.toLowerCase().contains(_searchQuery) || 
                  i.subtitle.toLowerCase().contains(_searchQuery)
                ).toList();

                if (filteredItems.isEmpty) {
                  final isFiltered = _searchQuery.isNotEmpty || ref.read(browsingScopeProvider).type != BrowsingScopeType.all;
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              CategoryUtils.getIcon(FeedType.gig),
                              size: 56,
                              color: theme.colorScheme.primary.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            isFiltered ? 'No matching gigs' : 'No gigs available',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isFiltered 
                                ? 'Try adjusting your search or switching to "All Campuses".' 
                                : 'Be the first to post a student gig and help your fellow students!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                              height: 1.5,
                            ),
                          ),
                          if (isFiltered) ...[
                            const SizedBox(height: 32),
                            FilledButton.icon(
                              onPressed: () {
                                setState(() => _searchQuery = '');
                                ref.read(browsingScopeProvider.notifier).reset();
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Explore All Gigs'),
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                const int adInterval = AdConfig.gigsAdInterval;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredItems.length + (filteredItems.isNotEmpty ? (filteredItems.length ~/ adInterval) : 0),
                  itemBuilder: (context, index) {
                    // If it's an ad position
                    if ((index + 1) % (adInterval + 1) == 0) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: BannerAdWidget(),
                      );
                    }

                    // Calculate the actual item index
                    final int itemIndex = index - (index ~/ (adInterval + 1));
                    
                    if (itemIndex >= filteredItems.length) return null;

                    final item = filteredItems[itemIndex];
                    final isLiked = user != null && item.likedBy.contains(user.uid);
                    final isOwner = user != null && item.authorId == user.uid;

                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: GestureDetector(
                        onTap: () => AuthorizationGuard.run(
                          context, 
                          ref, 
                          feature: UlifyFeature.gigsApply, 
                          action: () => context.push('/gig-detail/${item.id}', extra: item),
                        ),
                        child: FeedCard(
                          item: _truncateGigDescription(item),
                          isLiked: isLiked,
                          showDelete: isOwner,
                          onLike: () {
                            if (user != null) {
                              ref.read(feedRepositoryProvider).toggleLike(item.id, user.uid);
                            }
                          },
                          onDelete: () {
                            ref.read(feedRepositoryProvider).deleteFeedItem(item.id);
                          },
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
              error: (err, _) => Center(child: Text('Error: $err', style: TextStyle(color: theme.colorScheme.error))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleApplicationBanner(BuildContext context, WidgetRef ref) {
    // Optimization: watch only verification-relevant properties
    final userData = ref.watch(appUserProvider.select((u) {
      final user = u.valueOrNull;
      if (user == null) return null;
      return (
        isVerified: user.isVerified,
        identityStatus: user.identityStatus,
      );
    }));

    final bool isVerified = userData?.isVerified ?? false;
    
    // If user is already identity verified, we remove the suggestion completely
    if (isVerified) return const SizedBox.shrink();

    final bool isIdentityPending = userData?.identityStatus == 'pending';
    final bool isIdentityRejected = userData?.identityStatus == 'rejected';

    final theme = Theme.of(context);
    
    // Banner Configuration - Reusing Marketplace Style
    Color baseColor = theme.colorScheme.primary;
    IconData icon = Icons.verified_user_rounded;
    String title = 'Identity Required';
    String message = 'Verify your platform identity to unlock all student gig features.';
    String buttonText = 'Verify Identity';
    
    if (isIdentityRejected) {
      baseColor = theme.colorScheme.error;
      icon = Icons.error_outline_rounded;
      title = 'Identity Rejected';
      message = 'Your platform identity was not approved. Please update it to continue.';
      buttonText = 'Trust Center';
    } else if (isIdentityPending) {
      baseColor = Colors.orange;
      icon = Icons.auto_awesome_rounded;
      title = 'Verification Pending';
      message = 'Our team is reviewing your profile. You\'ll receive a notification once approved.';
      buttonText = ''; // Hide button during pending state
    } else if (!isVerified) {
      baseColor = theme.colorScheme.primary;
      icon = Icons.security_rounded;
      title = 'Identity Required';
      message = 'Verify your platform identity to unlock all student gig features.';
      buttonText = 'Verify Identity';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [baseColor, baseColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background Decorative Icon
          Positioned(
            right: -15,
            bottom: -15,
            child: Icon(
              icon,
              size: 100,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 30),
                        child: Text(
                          message,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                      if (buttonText.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.only(left: 30),
                          child: ElevatedButton(
                            onPressed: () => context.push(isIdentityRejected ? '/trust-center' : '/verify-identity'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: baseColor,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: Text(
                              buttonText, 
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  FeedItem _truncateGigDescription(FeedItem item) {
    if (item.subtitle.length <= 300) return item;
    
    return FeedItem(
      id: item.id,
      authorId: item.authorId,
      authorName: item.authorName,
      authorPhotoUrl: item.authorPhotoUrl,
      title: item.title,
      subtitle: '${item.subtitle.substring(0, 300)}... Read More',
      price: item.price,
      type: item.type,
      university: item.university,
      createdAt: item.createdAt,
      deadline: item.deadline,
      images: item.images,
      likesCount: item.likesCount,
      likedBy: item.likedBy,
    );
  }
}
