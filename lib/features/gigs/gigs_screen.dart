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

final gigsFeedProvider = StreamProvider<List<FeedItem>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  return ref.watch(feedRepositoryProvider).watchFeed(FeedType.gig, university: user?.university);
});

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
    final feedAsync = ref.watch(gigsFeedProvider);
    final user = ref.watch(appUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Student Gigs', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: const [
          NotificationBadge(module: 'gig'),
          SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search for gigs...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildRoleApplicationBanner(context, ref),
          Expanded(
            child: feedAsync.when(
              data: (items) {
                final filteredItems = items.where((i) => 
                  i.title.toLowerCase().contains(_searchQuery) || 
                  i.subtitle.toLowerCase().contains(_searchQuery)
                ).toList();

                if (filteredItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.work_off_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No gigs found matching your search.', style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
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
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddFeedItemScreen(type: FeedType.gig)),
          );
        },
        label: const Text('Post a Gig', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_task_rounded),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildRoleApplicationBanner(BuildContext context, WidgetRef ref) {
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
      color: (isIdentityRejected) ? Colors.red.shade50 : Colors.indigo.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isIdentityRejected ? Icons.error_outline_rounded : (!isVerified ? Icons.lock_outline_rounded : Icons.verified_user_outlined), 
                size: 20, 
                color: isIdentityRejected ? Colors.red.shade700 : Colors.indigo.shade700
              ),
              const SizedBox(width: 8),
              Text(
                isIdentityRejected ? 'Identity Rejected' : (!isVerified ? 'Verification Required' : 'Professional Profiles'),
                style: TextStyle(fontWeight: FontWeight.w800, color: isIdentityRejected ? Colors.red.shade900 : Colors.indigo.shade900, fontSize: 13),
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
              style: TextStyle(fontSize: 12, color: isIdentityRejected ? Colors.red.shade700 : Colors.indigo.shade700),
            ),
            if (!isIdentityPending) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.push(isIdentityRejected ? '/trust-center' : '/verify-identity'),
                  style: FilledButton.styleFrom(
                    backgroundColor: isIdentityRejected ? Colors.red : Colors.indigo,
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
                          backgroundColor: isRejected ? Colors.red.shade100 : (isPending ? Colors.grey.shade200 : Colors.white),
                          side: BorderSide(color: isRejected ? Colors.red.shade200 : Colors.indigo.shade100),
                          label: Text(
                            isRejected ? 'Apply ${role.label} (Rejected)' : (isPending ? '${role.label} (Pending)' : 'Apply as ${role.label}'),
                            style: TextStyle(
                              fontSize: 12, 
                              fontWeight: FontWeight.bold,
                              color: isRejected ? Colors.red.shade900 : (isPending ? Colors.grey.shade600 : Colors.indigo.shade700),
                            ),
                          ),
                          avatar: Icon(
                            isRejected ? Icons.error_outline : (isPending ? Icons.access_time : Icons.add_circle_outline),
                            size: 14,
                            color: isRejected ? Colors.red.shade700 : (isPending ? Colors.grey.shade600 : Colors.indigo.shade700),
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
