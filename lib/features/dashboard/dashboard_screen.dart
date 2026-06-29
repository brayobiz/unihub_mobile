import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth/shared/providers.dart';
import '../marketplace/shared/providers.dart';
import '../housing/shared/providers.dart';
import '../housing/presentation/widgets/housing_card.dart';
import '../notes/shared/providers.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/feed/feed_item_card.dart';
import '../../widgets/feed/feed_type.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/notification_badge.dart';
import '../../widgets/universal_search_bar.dart';
import '../../core/widgets/optimized_image.dart';
import 'controllers/smart_feed_controller.dart';
import '../../services/notification_service.dart';
import '../../services/history_service.dart';
import '../shared/add_feed_item_screen.dart';
import '../shared/global_search_screen.dart';
import '../shared/campus_pulse_screen.dart';
import '../../models/feed_type.dart' as models;
import 'package:intl/intl.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Request notification permission if not already granted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider).requestPermission();
      // Record visit for next time
      ref.read(historyServiceProvider).updateLastVisit();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(smartFeedProvider);
          ref.invalidate(listingsProvider);
          ref.invalidate(notesListingsProvider);
          ref.invalidate(newItemsSummaryProvider);
          ref.invalidate(trendingFeedProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            const _DashboardAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: UniversalSearchBar(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const GlobalSearchScreen()),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: _WhatsNewSection()),
            const SliverToBoxAdapter(child: _QuickActions()),
            const SliverToBoxAdapter(child: _ContinueReadingSection()),
            const SliverToBoxAdapter(child: _RecentlyViewedSection()),
            const SliverToBoxAdapter(child: _CampusPulseSection()),
            const SliverToBoxAdapter(child: _TrendingSection()),
            const SliverToBoxAdapter(child: _HousingPreviewSection()),
            const SliverToBoxAdapter(child: _SavedItemsSection()),
            
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Fresh Activity Feed',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A1C1E),
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
            
            const _ActivityFeedSection(),
            
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

class _DashboardAppBar extends ConsumerWidget {
  const _DashboardAppBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).valueOrNull;

    String getGreeting() {
      final hour = DateTime.now().hour;
      if (hour < 12) return 'Good Morning';
      if (hour < 17) return 'Good Afternoon';
      return 'Good Evening';
    }

    return SliverAppBar(
      expandedHeight: 150,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.black),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      actions: const [
        NotificationBadge(),
        SizedBox(width: 12),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade800, Colors.indigo.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${getGreeting()}, ${user?.fullName.split(' ').first ?? 'Student'}! 🎓',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Explore your campus ecosystem',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Action Shortcuts',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1C1E),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ActionItem(
                icon: Icons.note_add_outlined,
                label: 'Upload Notes',
                color: Colors.green.shade700,
                onTap: () => context.push('/add-note'),
              ),
              _ActionItem(
                icon: Icons.add_shopping_cart_outlined,
                label: 'Sell Item',
                color: Colors.orange.shade700,
                onTap: () => context.push('/add-listing'),
              ),
              _ActionItem(
                icon: Icons.campaign_outlined,
                label: 'Report Vacancy',
                color: Colors.blue.shade700,
                onTap: () => context.push('/submit-vacancy'),
              ),
              _ActionItem(
                icon: Icons.add_task_rounded,
                label: 'Post Gig',
                color: Colors.purple.shade700,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddFeedItemScreen(type: models.FeedType.gig)),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WhatsNewSection extends ConsumerWidget {
  const _WhatsNewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(newItemsSummaryProvider);

    return summaryAsync.when(
      data: (summary) {
        if (summary.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade100),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star_rounded, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New since your last visit',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.orange.shade900,
                        ),
                      ),
                      Text(
                        summary.entries.map((e) => '${e.value} ${e.key}').join(', '),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.orange.shade700),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _TrendingSection extends ConsumerWidget {
  const _TrendingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingAsync = ref.watch(trendingFeedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            children: [
              Text(
                'Trending Now',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A1C1E),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_fire_department_rounded, size: 12, color: Colors.red.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'HOT',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: trendingAsync.when(
            data: (items) => ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: items.take(5).length,
              itemBuilder: (context, index) {
                final item = items[index];
                final imageUrl = _getImageUrl(item);

                return GestureDetector(
                  onTap: () => _handleItemTap(context, item),
                  child: Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
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
                          child: Stack(
                            children: [
                              OptimizedImage(
                                imageUrl: imageUrl ?? _getPlaceholder(item.model.type),
                                height: 100,
                                width: 160, // Fixed width instead of infinity
                              ),
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _getCategoryIcon(item.model.type),
                                    size: 12,
                                    color: _getCategoryColor(item.model.type),
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.model.title,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1A1C1E),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.model.subtitle,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  String? _getImageUrl(SmartFeedItem item) {
    final data = item.originalData;
    if (data == null) return null;

    try {
      if (item.model.type == FeedType.marketplace) {
        return (data.imageUrls as List?)?.firstOrNull;
      } else if (item.model.type == FeedType.housing) {
        return (data.images as List?)?.firstOrNull;
      } else if (item.model.type == FeedType.gig || item.model.type == FeedType.community) {
        return (data.images as List?)?.firstOrNull;
      }
    } catch (_) {}
    return null;
  }

  String _getPlaceholder(FeedType type) {
    switch (type) {
      case FeedType.marketplace:
        return 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?q=80&w=1999&auto=format&fit=crop';
      case FeedType.housing:
        return 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?q=80&w=2070&auto=format&fit=crop';
      case FeedType.notes:
        return 'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?q=80&w=1973&auto=format&fit=crop';
      case FeedType.gig:
        return 'https://images.unsplash.com/photo-1515378791036-0648a3ef77b2?q=80&w=2070&auto=format&fit=crop';
      default:
        return 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?q=80&w=2070&auto=format&fit=crop';
    }
  }

  IconData _getCategoryIcon(FeedType type) {
    switch (type) {
      case FeedType.marketplace:
        return Icons.shopping_bag_outlined;
      case FeedType.housing:
        return Icons.home_work_outlined;
      case FeedType.notes:
        return Icons.description_outlined;
      case FeedType.gig:
        return Icons.work_outline;
      default:
        return Icons.star_outline;
    }
  }

  Color _getCategoryColor(FeedType type) {
    switch (type) {
      case FeedType.marketplace:
        return Colors.orange;
      case FeedType.housing:
        return Colors.blue;
      case FeedType.notes:
        return Colors.green;
      case FeedType.gig:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

class _ActivityFeedSection extends ConsumerWidget {
  const _ActivityFeedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(recentActivityProvider);

    return activityAsync.when(
      data: (items) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = items[index];
              final createdAt = item.originalData?.createdAt as DateTime?;
              final timeAgo = createdAt != null ? _formatTimeAgo(createdAt) : '';
              
              return _ActivityItem(
                item: item,
                timeAgo: timeAgo,
                onTap: () => _handleItemTap(context, item),
              );
            },
            childCount: items.length,
          ),
        ),
      ),
      loading: () => const SliverToBoxAdapter(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final duration = DateTime.now().difference(dateTime);
    if (duration.inDays > 0) return '${duration.inDays}d ago';
    if (duration.inHours > 0) return '${duration.inHours}h ago';
    if (duration.inMinutes > 0) return '${duration.inMinutes}m ago';
    return 'Just now';
  }
}

class _ActivityItem extends StatelessWidget {
  final SmartFeedItem item;
  final String timeAgo;
  final VoidCallback onTap;

  const _ActivityItem({
    required this.item,
    required this.timeAgo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isVeryRecent = DateTime.now().difference(item.originalData?.createdAt as DateTime? ?? DateTime(2000)).inHours < 24;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getCategoryColor(item.model.type).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getCategoryIcon(item.model.type),
                  size: 20,
                  color: _getCategoryColor(item.model.type),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.model.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVeryRecent)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'NEW',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.model.subtitle} • $timeAgo',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  IconData _getCategoryIcon(FeedType type) {
    switch (type) {
      case FeedType.marketplace: return Icons.shopping_bag_outlined;
      case FeedType.housing: return Icons.home_work_outlined;
      case FeedType.notes: return Icons.description_outlined;
      case FeedType.gig: return Icons.work_outline;
      default: return Icons.notifications_none_rounded;
    }
  }

  Color _getCategoryColor(FeedType type) {
    switch (type) {
      case FeedType.marketplace: return Colors.orange;
      case FeedType.housing: return Colors.blue;
      case FeedType.notes: return Colors.green;
      case FeedType.gig: return Colors.purple;
      default: return Colors.grey;
    }
  }
}

class _CampusPulseSection extends ConsumerWidget {
  const _CampusPulseSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pulseAsync = ref.watch(campusPulseProvider);
    final trendingAsync = ref.watch(trendingFeedProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade50, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.indigo.shade100.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.bolt_rounded, color: Colors.indigo.shade700, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Campus Pulse',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.indigo.shade900,
                        ),
                      ),
                      pulseAsync.when(
                        data: (stats) {
                          final trendingItem = trendingAsync.valueOrNull?.firstOrNull;
                          if (trendingItem != null) {
                            return Text(
                              '🔥 Trending: ${trendingItem.model.title}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: Colors.indigo.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          }
                          return Text(
                            'Active: ${stats['listings']} items, ${stats['notes']} notes',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: Colors.indigo.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CampusPulseScreen()),
                    );
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.indigo.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.indigo.shade100),
                    ),
                    textStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('View All'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HousingPreviewSection extends ConsumerWidget {
  const _HousingPreviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(topHousingProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nearby Housing',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A1C1E),
                    letterSpacing: -0.5,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/housing'),
                  child: Text(
                    'View All',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.indigo.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          listingsAsync.when(
            data: (listings) => SizedBox(
              height: 230,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: listings.length > 5 ? 5 : listings.length,
                itemBuilder: (context, index) => SizedBox(
                  width: 200,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: HousingCard(
                      listing: listings[index],
                      isCompact: true,
                      onTap: () => context.push('/housing-detail', extra: listings[index]),
                    ),
                  ),
                ),
              ),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: SkeletonLoader(width: double.infinity, height: 200),
            ),
            error: (e, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _SmartFeedSection extends ConsumerWidget {
  const _SmartFeedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(personalizedRecommendationsProvider);

    return feedAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: Text('No recommendations yet. Explore to see more!')),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = items[index];
                return FeedItemCard(
                  item: item.model,
                  onTap: () => _handleItemTap(context, item),
                );
              },
              childCount: items.length,
            ),
          ),
        );
      },
      loading: () => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => const SkeletonFeedItem(),
            childCount: 5,
          ),
        ),
      ),
      error: (err, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}

void _handleItemTap(BuildContext context, SmartFeedItem item) {
  if (item.model.type == FeedType.housing) {
    context.push('/housing-detail', extra: item.originalData);
  } else if (item.model.type == FeedType.notes) {
    context.push('/note-detail', extra: item.originalData);
  } else if (item.model.type == FeedType.marketplace) {
    context.push('/marketplace-detail', extra: item.originalData);
  } else if (item.model.type == FeedType.gig) {
    context.push('/gig-detail', extra: item.originalData);
  } else if (item.model.type == FeedType.community) {
    context.push('/community-detail', extra: item.originalData);
  }
}

class _ContinueReadingSection extends ConsumerWidget {
  const _ContinueReadingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(studyHistoryProvider);

    return historyAsync.when(
      data: (history) {
        if (history.isEmpty) return const SizedBox.shrink();

        final recent = history.first;
        final noteAsync = ref.watch(noteByIdProvider(recent.noteId));

        return noteAsync.when(
          data: (note) {
            if (note == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Continue Reading',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A1C1E),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.description_rounded, color: Colors.indigo),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                note.title,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${note.unitCode} • Page ${recent.lastPage + 1}',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: () => context.push('/note-detail', extra: note),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Resume', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _RecentlyViewedSection extends ConsumerWidget {
  const _RecentlyViewedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(recentHistoryProvider);

    if (history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recently Viewed',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A1C1E),
                  letterSpacing: -0.5,
                ),
              ),
              TextButton(
                onPressed: () => ref.read(recentHistoryProvider.notifier).clear(),
                child: const Text('Clear', style: TextStyle(color: Colors.red, fontSize: 13)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: history.take(10).length,
            itemBuilder: (context, index) {
              final item = history[index];
              return Container(
                width: 100,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        image: item.imageUrl != null 
                          ? DecorationImage(image: NetworkImage(item.imageUrl!), fit: BoxFit.cover)
                          : null,
                      ),
                      child: item.imageUrl == null 
                        ? Icon(_getIcon(item.type), color: Colors.indigo.shade200)
                        : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'listing': return Icons.shopping_bag_outlined;
      case 'housing': return Icons.home_work_outlined;
      case 'note': return Icons.description_outlined;
      case 'gig': return Icons.work_outline;
      default: return Icons.remove_red_eye_outlined;
    }
  }
}

class _SavedItemsSection extends ConsumerWidget {
  const _SavedItemsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedListings = ref.watch(savedListingsProvider).valueOrNull ?? [];
    final savedHousing = ref.watch(savedHousingProvider).valueOrNull ?? [];

    if (savedListings.isEmpty && savedHousing.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(
            'Your Favorites',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1C1E),
              letterSpacing: -0.5,
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              ...savedHousing.take(3).map((h) => _SavedItemCard(
                title: h.title,
                subtitle: 'KES ${h.rent.toInt()}',
                imageUrl: h.images.isNotEmpty ? h.images.first : null,
                onTap: () => context.push('/housing-detail', extra: h),
              )),
              ...savedListings.take(3).map((l) => _SavedItemCard(
                title: l.title,
                subtitle: 'KES ${l.price.toInt()}',
                imageUrl: l.imageUrls.isNotEmpty ? l.imageUrls.first : null,
                onTap: () => context.push('/listing-detail', extra: l),
              )),
            ],
          ),
        ),
      ],
    );
  }
}

class _SavedItemCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback onTap;

  const _SavedItemCard({
    required this.title,
    required this.subtitle,
    this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: imageUrl != null 
                ? Image.network(imageUrl!, height: 100, width: 140, fit: BoxFit.cover)
                : Container(height: 100, width: 140, color: Colors.grey.shade100, child: const Icon(Icons.image_outlined, color: Colors.grey)),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.indigo.shade700, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
