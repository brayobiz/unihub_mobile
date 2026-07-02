import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unihub_mobile/features/trust/domain/models/professional_role.dart';
import 'package:unihub_mobile/features/trust/domain/models/verification_application.dart';
import 'package:unihub_mobile/features/trust/presentation/providers/trust_providers.dart';
import '../../models/feed_type.dart';
import '../shared/feed_repository.dart';
import '../../widgets/feed/feed_card.dart';
import '../auth/shared/providers.dart';
import '../shared/add_feed_item_screen.dart';
import '../../widgets/notification_badge.dart';
import '../campus_filter/presentation/widgets/campus_filter_selector.dart';
import '../campus_filter/shared/providers.dart';
import '../campus_filter/domain/models/browsing_scope.dart';
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
        actions: const [
          NotificationBadge(module: 'gig'),
          SizedBox(width: 8),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.work_off_outlined, size: 64, color: theme.colorScheme.outlineVariant),
                        const SizedBox(height: 16),
                        Text('No gigs found.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                        if (isFiltered) ...[
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () {
                              setState(() => _searchQuery = '');
                              ref.read(browsingScopeProvider.notifier).reset();
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Explore All Gigs'),
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                const int adInterval = AdConfig.gigsAdInterval;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredItems.length + (filteredItems.length > 0 ? (filteredItems.length ~/ adInterval) : 0),
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
                        onTap: () => context.push('/gig-detail', extra: item),
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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'gigs_fab',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddFeedItemScreen(type: FeedType.gig)),
          );
        },
        label: const Text('Post a Gig', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_task_rounded),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildRoleApplicationBanner(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(appUserProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    final isVerified = user.isVerified;
    final isIdentityPending = user.identityStatus == 'pending';
    final isIdentityRejected = user.identityStatus == 'rejected';

    // Roles most relevant to Gigs
    final roles = [
      ProfessionalRole.tutor,
      ProfessionalRole.serviceProvider,
      ProfessionalRole.technician,
    ];

    // Filter to roles not yet verified
    final pendingRoles = roles.where((r) => !user.verifiedRoles.contains(r.name)).toList();
    if (pendingRoles.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: (isIdentityRejected) 
          ? theme.colorScheme.errorContainer.withValues(alpha: 0.1) 
          : theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isIdentityRejected ? Icons.error_outline_rounded : (!isVerified ? Icons.lock_outline_rounded : Icons.verified_user_outlined), 
                size: 20, 
                color: isIdentityRejected ? theme.colorScheme.error : theme.colorScheme.primary
              ),
              const SizedBox(width: 8),
              Text(
                isIdentityRejected ? 'Identity Rejected' : (!isVerified ? 'Verification Required' : 'Professional Profiles'),
                style: TextStyle(
                  fontWeight: FontWeight.w800, 
                  color: isIdentityRejected ? theme.colorScheme.error : theme.colorScheme.primary, 
                  fontSize: 13
                ),
              ),
            ],
          ),
          if (!isVerified || isIdentityPending || isIdentityRejected) ...[
            const SizedBox(height: 8),
            Text(
              isIdentityRejected 
                ? 'Your identity verification was not approved. Please fix it in the Trust Center.'
                : (isIdentityPending 
                    ? 'Your identity is under review. You can apply for these roles once approved.'
                    : 'Verify your platform identity to apply for professional badges.'),
              style: TextStyle(
                fontSize: 12, 
                color: isIdentityRejected ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant
              ),
            ),
            if (!isIdentityPending) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.push(isIdentityRejected ? '/trust-center' : '/verify-identity'),
                  style: FilledButton.styleFrom(
                    backgroundColor: isIdentityRejected ? theme.colorScheme.error : theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(isIdentityRejected ? 'Fix Identity Issues' : 'Verify Identity'),
                ),
              ),
            ],
          ] else ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: pendingRoles.map((role) {
                  final appAsync = ref.watch(applicationByRoleProvider(role));
                  
                  return appAsync.when(
                    data: (app) {
                      final isPending = app?.status == VerificationStatus.pending;
                      final isRejected = app?.status == VerificationStatus.rejected;
                      
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ActionChip(
                          onPressed: isPending ? null : () => context.push('/verify-professional/${role.name}'),
                          backgroundColor: isRejected 
                              ? theme.colorScheme.errorContainer.withValues(alpha: 0.2) 
                              : (isPending ? theme.colorScheme.surfaceContainerHighest : theme.colorScheme.surface),
                          side: BorderSide(
                            color: isRejected 
                                ? theme.colorScheme.error.withValues(alpha: 0.2) 
                                : theme.colorScheme.outlineVariant
                          ),
                          label: Text(
                            isRejected ? 'Apply ${role.label} (Rejected)' : (isPending ? '${role.label} (Pending)' : 'Apply as ${role.label}'),
                            style: TextStyle(
                              fontSize: 12, 
                              fontWeight: FontWeight.bold,
                              color: isRejected 
                                  ? theme.colorScheme.error 
                                  : (isPending ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.primary),
                            ),
                          ),
                          avatar: Icon(
                            isRejected ? Icons.error_outline : (isPending ? Icons.access_time : Icons.add_circle_outline),
                            size: 14,
                            color: isRejected 
                                ? theme.colorScheme.error 
                                : (isPending ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.primary),
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                }).toList(),
              ),
            ),
          ],
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
