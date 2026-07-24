import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_colors.dart';
import '../../core/utils/category_utils.dart';
import '../auth/shared/providers.dart';
import '../marketplace/domain/models/listing.dart';
import '../marketplace/shared/providers.dart';
import '../housing/shared/providers.dart';
import '../housing/domain/models/roommate_profile.dart';
import '../housing/domain/models/housing_listing.dart';
import '../notes/domain/models/note.dart';
import '../shared/feed_repository.dart';
import '../housing/presentation/widgets/housing_card.dart';
import '../notes/shared/providers.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/feed/feed_item_card.dart';
import '../../models/feed_type.dart';
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
import '../announcements/presentation/widgets/announcement_display.dart';
import '../campus_filter/presentation/widgets/campus_filter_selector.dart';
import '../events/presentation/widgets/homepage_event_sections.dart';
import '../ads/ads_module.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/empty_state.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider).requestPermission();
      ref.read(historyServiceProvider).updateLastVisit();
    });
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      // Threshold for collapse (expandedHeight is 110)
      final isCollapsed = _scrollController.offset > 60;
      if (isCollapsed != _isCollapsed) {
        setState(() {
          _isCollapsed = isCollapsed;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: AppDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(smartFeedProvider);
          ref.invalidate(listingsProvider);
          ref.invalidate(notesListingsProvider);
          ref.invalidate(newItemsSummaryProvider);
          ref.invalidate(trendingFeedProvider);
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            _DashboardAppBar(isCollapsed: _isCollapsed),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: CampusFilterSelector(),
              ),
            ),
            const SliverToBoxAdapter(
              child: RelevantAnnouncementsWidget(),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 12),
                child: UniversalSearchBar(
                  onTap: null, // Tap logic handled internally now or via GoRouter
                ),
              ),
            ),
            const SliverToBoxAdapter(child: _WhatsNewSection()),
            const SliverToBoxAdapter(child: _QuickActions()),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 20),
                child: BannerAdWidget(),
              ),
            ),
            const SliverToBoxAdapter(child: _ContinueReadingSection()),
            const SliverToBoxAdapter(child: _RecentlyViewedSection()),
            const SliverToBoxAdapter(child: _CampusPulseSection()),
            const SliverToBoxAdapter(child: EventsDashboardOrchestrator()),
            const SliverToBoxAdapter(child: _TrendingSection()),
            const SliverToBoxAdapter(child: _HousingPreviewSection()),
            const SliverToBoxAdapter(child: _SavedItemsSection()),
            const _ActivityFeedSection(),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

class _DashboardAppBar extends ConsumerWidget {
  final bool isCollapsed;
  const _DashboardAppBar({required this.isCollapsed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Optimization: only watch necessary user properties to avoid reloads on presence updates
    final userData = ref.watch(appUserProvider.select((u) {
      final user = u.valueOrNull;
      if (user == null) return null;
      return (
        fullName: user.fullName,
        photoUrl: user.photoUrl,
      );
    }));

    String getGreeting() {
      final hour = DateTime.now().hour;
      if (hour < 12) return 'Good Morning';
      if (hour < 17) return 'Good Afternoon';
      return 'Good Evening';
    }

    final theme = Theme.of(context);
    final contentColor = isCollapsed ? theme.colorScheme.onSurface : Colors.white;

    return SliverAppBar(
      expandedHeight: 110,
      pinned: true,
      backgroundColor: theme.colorScheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: Builder(
        builder: (context) => IconButton(
          icon: Icon(Icons.menu_rounded, color: contentColor),
          onPressed: () => Scaffold.of(context).openDrawer(),
          tooltip: 'Open campus utilities drawer',
        ),
      ),
      actions: [
        Semantics(
          label: 'Notifications',
          button: true,
          child: NotificationBadge(iconColor: contentColor),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => context.push('/profile'),
          child: Semantics(
            label: 'View Profile',
            button: true,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: isCollapsed ? theme.colorScheme.primary.withOpacity(0.1) : Colors.white24,
                backgroundImage: userData?.photoUrl != null ? NetworkImage(userData!.photoUrl!) : null,
                child: userData?.photoUrl == null 
                    ? Text(
                        userData?.fullName.isNotEmpty == true ? userData!.fullName[0].toUpperCase() : 'U',
                        style: TextStyle(color: isCollapsed ? theme.colorScheme.primary : Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryGradientStart, AppColors.primaryGradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${getGreeting()}, ${userData?.fullName.split(' ').first ?? 'Student'}! 🎓',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Explore your campus ecosystem',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Action Shortcuts',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ActionItem(
                icon: CategoryUtils.getIcon(FeedType.notes),
                label: 'Upload Notes',
                color: CategoryUtils.getColor(FeedType.notes),
                onTap: () => context.push('/add-note'),
              ),
              _ActionItem(
                icon: CategoryUtils.getIcon(FeedType.marketplace),
                label: 'Create Listing',
                color: CategoryUtils.getColor(FeedType.marketplace),
                onTap: () => context.push('/add-listing'),
              ),
              _ActionItem(
                icon: CategoryUtils.getIcon(FeedType.housing),
                label: 'Create Vacancy',
                color: CategoryUtils.getColor(FeedType.housing),
                onTap: () => context.push('/submit-vacancy'),
              ),
              _ActionItem(
                icon: CategoryUtils.getIcon(FeedType.gig),
                label: 'Create Gig',
                color: CategoryUtils.getColor(FeedType.gig),
                onTap: () => context.push('/add-feed-item', extra: FeedType.gig),
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
    final theme = Theme.of(context);
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        onTap: onTap,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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
    final theme = Theme.of(context);
    final summaryAsync = ref.watch(newItemsSummaryProvider);

    return summaryAsync.when(
      data: (summary) {
        if (summary.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.highlightOrangeBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.highlightOrangeBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                  child: const Icon(Icons.star_rounded, color: Colors.white, size: 14),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New since your last visit',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.orange.shade900,
                        ),
                      ),
                      Text(
                        summary.entries.map((e) => '${e.value} ${e.key}').join(', '),
                        style: theme.textTheme.bodySmall?.copyWith(
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
                Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.orange.shade700),
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
    final theme = Theme.of(context);
    final trendingAsync = ref.watch(trendingFeedProvider);

    return trendingAsync.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Text(
                      'Trending Now',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
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
                          Icon(Icons.local_fire_department_rounded, size: 11, color: Colors.red.shade700),
                          const SizedBox(width: 4),
                          Text(
                            'HOT',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 8.5,
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
                height: 190,
                child: ListView.builder(
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
                        width: 155,
                        margin: const EdgeInsets.only(right: 14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.colorScheme.outlineVariant),
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
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: Stack(
                                children: [
                                  OptimizedImage(
                                    imageUrl: imageUrl ?? CategoryUtils.getPlaceholder(item.model.type),
                                    height: 95,
                                    width: 155,
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
                                        CategoryUtils.getIcon(item.model.type),
                                        size: 11,
                                        color: CategoryUtils.getColor(item.model.type),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item.model.title,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.model.subtitle,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 10,
                                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
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
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
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
}

class _ActivityFeedSection extends ConsumerWidget {
  const _ActivityFeedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activityAsync = ref.watch(recentActivityProvider);

    return activityAsync.when(
      data: (items) {
        if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

        return SliverMainAxisGroup(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Fresh Activity Feed',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
            SliverPadding(
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
          ],
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (err, __) => SliverToBoxAdapter(
        child: ErrorView(
          error: err,
          onRetry: () => ref.invalidate(recentActivityProvider),
          isFullPage: false,
        ),
      ),
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
    final theme = Theme.of(context);
    final isVeryRecent = DateTime.now().difference(item.originalData?.createdAt as DateTime? ?? DateTime(2000)).inHours < 24;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: CategoryUtils.getColor(item.model.type).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  CategoryUtils.getIcon(item.model.type),
                  size: 20,
                  color: CategoryUtils.getColor(item.model.type),
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
                            style: theme.textTheme.titleSmall?.copyWith(
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
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
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
}

class _CampusPulseSection extends ConsumerWidget {
  const _CampusPulseSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pulseAsync = ref.watch(campusPulseProvider);
    final trendingAsync = ref.watch(trendingFeedProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.highlightIndigoBg, Theme.of(context).colorScheme.surface],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.highlightIndigoBorder.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: AppColors.highlightIndigoBorder, shape: BoxShape.circle),
                    child: const Icon(Icons.bolt_rounded, color: AppColors.secondaryDark, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Campus Pulse',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.secondaryDark,
                          ),
                        ),
                        pulseAsync.when(
                          data: (stats) {
                            final trendingItem = trendingAsync.valueOrNull?.firstOrNull;
                            if (trendingItem != null) {
                              return Text(
                                '🔥 Trending: ${trendingItem.model.title}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11.5,
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            }
                            return Text(
                              'Active: ${stats['listings']} items, ${stats['notes']} notes',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11.5,
                                color: AppColors.secondary,
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
                    onPressed: () => context.push('/campus-pulse'),
                    style: TextButton.styleFrom(
                      backgroundColor: theme.colorScheme.surface,
                      foregroundColor: AppColors.secondary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: AppColors.highlightIndigoBorder),
                      ),
                      textStyle: theme.textTheme.labelLarge?.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('View All'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HousingPreviewSection extends ConsumerWidget {
  const _HousingPreviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final listingsAsync = ref.watch(topHousingProvider);

    return listingsAsync.when(
      data: (listings) {
        if (listings.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 20),
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
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/housing'),
                      child: Text(
                        'View All',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.indigo.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: listings.length > 5 ? 5 : listings.length,
                  itemBuilder: (context, index) => SizedBox(
                    width: 190,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: HousingCard(
                        listing: listings[index],
                        isCompact: true,
                        onTap: () => context.push('/housing-detail/${listings[index].id}', extra: listings[index]),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
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
    if (item.originalData is RoommateProfile) {
      context.push('/roommates'); // Or a specific detail screen if I had one
    } else if (item.originalData is HousingListing) {
      final h = item.originalData as HousingListing;
      context.push('/housing-detail/${h.id}', extra: h);
    }
  } else if (item.model.type == FeedType.notes) {
    if (item.originalData is NoteListing) {
      final n = item.originalData as NoteListing;
      context.push('/note-detail/${n.id}', extra: n);
    }
  } else if (item.model.type == FeedType.marketplace) {
    if (item.originalData is Listing) {
      final l = item.originalData as Listing;
      context.push('/listing-detail/${l.id}', extra: l);
    }
  } else if (item.model.type == FeedType.gig) {
    if (item.originalData is FeedItem) {
      final g = item.originalData as FeedItem;
      context.push('/gig-detail/${g.id}', extra: g);
    }
  } else if (item.model.type == FeedType.community) {
    if (item.originalData is FeedItem) {
      final f = item.originalData as FeedItem;
      context.push('/community-detail/${f.id}', extra: f);
    }
  }
}

class _ContinueReadingSection extends ConsumerWidget {
  const _ContinueReadingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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
              padding: const EdgeInsets.only(top: 20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Continue Reading',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
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
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.highlightIndigoBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.description_rounded, color: AppColors.secondary, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  note.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${note.unitCode} • Page ${recent.lastPage + 1}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                                    fontSize: 12.5
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: () => context.push('/note-detail/${note.id}', extra: note),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Resume', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
    final theme = Theme.of(context);
    final history = ref.watch(recentHistoryProvider);

    if (history.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recently Viewed',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                TextButton(
                  onPressed: () => ref.read(recentHistoryProvider.notifier).clear(),
                  style: TextButton.styleFrom(minimumSize: Size.zero, padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('Clear', style: TextStyle(color: Colors.red, fontSize: 12.5)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 110,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: history.take(10).length,
              itemBuilder: (context, index) {
                final item = history[index];
                return Container(
                  width: 90,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      Container(
                        width: 65,
                        height: 65,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                          image: item.imageUrl != null 
                            ? DecorationImage(image: NetworkImage(item.imageUrl!), fit: BoxFit.cover)
                            : null,
                        ),
                        child: item.imageUrl == null 
                          ? Icon(_getIcon(item.type), color: Colors.indigo.shade200, size: 20)
                          : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5, fontWeight: FontWeight.w600),
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
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'listing': return CategoryUtils.getIcon(FeedType.marketplace);
      case 'housing': return CategoryUtils.getIcon(FeedType.housing);
      case 'note': return CategoryUtils.getIcon(FeedType.notes);
      case 'gig': return CategoryUtils.getIcon(FeedType.gig);
      default: return Icons.remove_red_eye_outlined;
    }
  }
}

class _SavedItemsSection extends ConsumerWidget {
  const _SavedItemsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Optimization: watch specific user properties to prevent unnecessary rebuilds
    final userData = ref.watch(appUserProvider.select((u) {
      final user = u.valueOrNull;
      if (user == null) return null;
      return (
        uid: user.uid,
        accountType: user.accountType,
      );
    }));

    final allSavedListings = ref.watch(savedListingsProvider).valueOrNull ?? [];
    final savedListings = allSavedListings.where((l) => l.status == ListingStatus.active).toList();
    final savedHousing = ref.watch(savedHousingProvider).valueOrNull ?? [];

    if (savedListings.isEmpty && savedHousing.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Saved Items',
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          SizedBox(
            height: 170,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: (savedHousing.length > 3 ? 3 : savedHousing.length) + 
                         (savedListings.length > 3 ? 3 : savedListings.length),
              itemBuilder: (context, index) {
                final limitedHousing = savedHousing.take(3).toList();
                final limitedListings = savedListings.take(3).toList();
                
                if (index < limitedHousing.length) {
                  final h = limitedHousing[index];
                  return _SavedItemCard(
                    title: h.title,
                    subtitle: 'KES ${h.rent.toInt()}',
                    imageUrl: h.images.isNotEmpty ? h.images.first : null,
                    onTap: () => context.push('/housing-detail/${h.id}', extra: h),
                  );
                } else {
                  final l = limitedListings[index - limitedHousing.length];
                  return _SavedItemCard(
                    title: l.title,
                    subtitle: 'KES ${l.price.toInt()}',
                    imageUrl: l.imageUrls.isNotEmpty ? l.imageUrls.first : null,
                    onTap: () => context.push('/listing-detail/${l.id}', extra: l),
                  );
                }
              },
            ),
          ),
        ],
      ),
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
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 135,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
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
                ? OptimizedImage(
                    imageUrl: imageUrl!, 
                    height: 95, 
                    width: 135, 
                    fit: BoxFit.cover,
                    thumbnailWidth: 300,
                  )
                : Container(
                    height: 95, 
                    width: 135, 
                    color: theme.colorScheme.surfaceContainerHighest, 
                    child: Icon(Icons.image_outlined, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5), size: 20)
                  ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title, 
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 11.5), 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle, 
                    style: TextStyle(
                      fontSize: 10.5,
                      color: theme.colorScheme.primary, 
                      fontWeight: FontWeight.w700
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
}
