import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/features/trust/domain/models/professional_role.dart';
import 'package:unihub_mobile/features/trust/domain/models/verification_application.dart';
import 'package:unihub_mobile/features/trust/presentation/providers/trust_providers.dart';
import '../auth/shared/providers.dart';
import 'domain/models/listing.dart';
import 'domain/models/marketplace_categories.dart';
import 'domain/repositories/marketplace_repository.dart';
import 'presentation/controllers/marketplace_controller.dart';
import 'presentation/controllers/saved_searches_controller.dart';
import 'shared/providers.dart';
import 'domain/models/listing_filter.dart';
import 'presentation/widgets/marketplace_card.dart';
import '../campus_filter/domain/models/browsing_scope.dart';
import '../campus_filter/shared/providers.dart';
import '../campus_filter/presentation/widgets/campus_filter_selector.dart';
import '../../core/constants/campus_constants.dart';
import '../../core/utils/debouncer.dart';
import '../../core/utils/category_utils.dart';
import '../../models/feed_type.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/notification_badge.dart';
import 'package:unihub_mobile/features/announcements/presentation/widgets/announcement_display.dart';
import 'package:unihub_mobile/features/ads/ads_module.dart';

import 'presentation/controllers/paginated_listings_controller.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/empty_state.dart';

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> with SingleTickerProviderStateMixin {
  final _searchDebouncer = Debouncer(milliseconds: 500);
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final filterState = ref.read(marketplaceControllerProvider);
      ref.read(paginatedListingsProvider(filterState).notifier).fetchMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _searchDebouncer.dispose();
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu_rounded, color: theme.colorScheme.onSurface),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Open campus utilities drawer',
          ),
        ),
        title: Text(
          'Marketplace',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmarks_outlined),
            tooltip: 'Saved Searches',
            onPressed: () => context.push('/saved-searches'),
          ),
          Semantics(
            label: 'Marketplace Notifications',
            button: true,
            child: const NotificationBadge(module: 'marketplace'),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => context.push('/profile'),
            child: Semantics(
              label: 'View Profile',
              button: true,
              child: Consumer(
                builder: (context, ref, _) {
                  // Optimization: only watch necessary user properties to avoid reloads on presence updates
                  final userData = ref.watch(appUserProvider.select((u) {
                    final user = u.valueOrNull;
                    if (user == null) return null;
                    return (
                      photoUrl: user.photoUrl,
                      fullName: user.fullName,
                    );
                  }));
                  
                  return CircleAvatar(
                    radius: 16,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    backgroundImage: userData?.photoUrl != null ? NetworkImage(userData!.photoUrl!) : null,
                    child: userData?.photoUrl == null 
                        ? Text(
                            userData?.fullName.isNotEmpty == true ? userData!.fullName[0].toUpperCase() : 'U',
                            style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                          )
                        : null,
                  );
                }
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.secondary,
          unselectedLabelColor: AppColors.grey,
          indicatorColor: AppColors.secondary,
          labelStyle: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Discover'),
            Tab(text: 'My Listings'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'marketplace_fab',
        onPressed: () => context.push('/add-listing'),
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('Create Listing'),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDiscoverTab(),
          _buildMyListingsTab(),
        ],
      ),
    );
  }

  Widget _buildDiscoverTab() {
    final filterState = ref.watch(marketplaceControllerProvider);
    final controller = ref.read(marketplaceControllerProvider.notifier);
    final user = ref.watch(appUserProvider).valueOrNull;

    final bool isDiscoveryMode = filterState.searchQuery.isEmpty && 
                                 filterState.selectedCategory == null &&
                                 filterState.selectedConditions.isEmpty &&
                                 filterState.priceRange == null &&
                                 filterState.sortBy == ListingSortType.newest;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(trendingListingsProvider);
        ref.invalidate(recommendedListingsProvider);
        ref.invalidate(recentlyViewedProvider);
        ref.invalidate(listingsProvider);
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          const SliverToBoxAdapter(
            child: RelevantAnnouncementsWidget(feature: 'marketplace'),
          ),
          
          if (isDiscoveryMode)
            SliverToBoxAdapter(
              child: _buildDiscoveryHeader(controller, filterState),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                child: Column(
                  children: [
                    _buildSearchBar(controller, filterState),
                    const SizedBox(height: 12),
                    _buildCategoryChips(filterState, controller),
                  ],
                ),
              ),
            ),

          if (isDiscoveryMode)
            SliverToBoxAdapter(
              child: _buildDiscoveryContent(),
            ),

          // Growth Phase: Featured Section in Main Feed
          if (isDiscoveryMode)
            ref.watch(listingsProvider(ListingFilter(isFeaturedOnly: true, itemsLimit: 10))).when(
              data: (featured) {
                if (featured.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                final theme = Theme.of(context);
                return SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Featured Listings',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 260,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: featured.length,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: SizedBox(
                              width: 170,
                              child: MarketplaceCard(
                                listing: featured[index], 
                                index: index,
                                heroTag: 'hero_featured_${featured[index].id}',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),

          _buildListingsGrid(isDiscoveryMode ? ListingFilter() : filterState),
        ],
      ),
    );
  }

  Widget _buildDiscoveryHeader(MarketplaceController controller, ListingFilter filterState) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(controller, filterState),
          const SizedBox(height: 20),
          const CampusFilterSelector(),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Explore Categories',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              TextButton(
                onPressed: () => _showAllCategoriesSheet(context),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  'View All', 
                  style: TextStyle(
                    color: theme.colorScheme.primary, 
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildModernCategoryGrid(),
        ],
      ),
    );
  }

  Widget _buildModernCategoryGrid() {
    final theme = Theme.of(context);
    final categories = MarketplaceCategories.mainFilters.where((c) => c != 'All').toList();
    
    return SizedBox(
      height: 180,
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 12,
          childAspectRatio: 1.15,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push('/category-discovery/$cat'),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        MarketplaceCategories.getIcon(cat),
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 70,
                      child: Text(
                        cat,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                          height: 1.1,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAllCategoriesSheet(BuildContext context) {
    final theme = Theme.of(context);
    final categories = MarketplaceCategories.mainFilters.where((c) => c != 'All').toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: theme.colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Text(
                    'All Categories',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/category-discovery/$cat');
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                          ),
                          alignment: Alignment.center,
                          child: Text(MarketplaceCategories.getIcon(cat), style: const TextStyle(fontSize: 32)),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          cat,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(MarketplaceController controller, ListingFilter filterState) {
    final theme = Theme.of(context);
    final hasSearch = filterState.searchQuery.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => showSearch(
                context: context,
                delegate: MarketplaceSearchDelegate(ref: ref, scrollController: _scrollController),
              ),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: hasSearch ? theme.colorScheme.primary.withValues(alpha: 0.3) : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded, 
                      color: hasSearch ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        filterState.searchQuery.isEmpty 
                            ? 'Search campus listings...' 
                            : filterState.searchQuery,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: filterState.searchQuery.isEmpty ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6) : theme.colorScheme.onSurface,
                          fontWeight: hasSearch ? FontWeight.w600 : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasSearch)
                      GestureDetector(
                        onTap: () => controller.setSearchQuery(''),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close_rounded, size: 14, color: theme.colorScheme.onSurface),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Stack(
          children: [
            IconButton(
              onPressed: () => _showFilterSheet(context, filterState, controller), 
              icon: Icon(Icons.tune_rounded, color: theme.colorScheme.onSurface),
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surface,
                padding: const EdgeInsets.all(12),
                side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
            ),
            if (filterState.selectedCategory != null || filterState.selectedConditions.isNotEmpty || filterState.priceRange != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryChips(ListingFilter filterState, MarketplaceController controller) {
    final theme = Theme.of(context);
    const categories = MarketplaceCategories.mainFilters;
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = filterState.selectedCategory == cat || (cat == 'All' && filterState.selectedCategory == null);
          
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(
                cat,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  controller.setCategory(cat);
                }
              },
              backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              selectedColor: AppColors.secondary,
              showCheckmark: false,
              pressElevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? AppColors.secondary : theme.colorScheme.outlineVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDiscoveryContent() {
    // Optimization: watch specific user properties
    final userData = ref.watch(appUserProvider.select((u) {
      final user = u.valueOrNull;
      if (user == null) return null;
      return (university: user.university);
    }));
    
    final scope = ref.watch(browsingScopeProvider);

    String trendingTitle = 'Trending';
    String recentlyPostedTitle = 'Recently Posted';
    
    if (scope.type == BrowsingScopeType.myCampus) {
      final uniName = CampusConstants.getDisplayName(
        CampusConstants.resolveToId(userData?.university) ?? userData?.university
      );
      trendingTitle = 'Trending in $uniName';
      recentlyPostedTitle = 'New in $uniName';
    } else if (scope.type == BrowsingScopeType.specific) {
      final campusName = CampusConstants.getDisplayName(scope.campusId);
      trendingTitle = 'Trending in $campusName';
      recentlyPostedTitle = 'New in $campusName';
    }

    return Column(
      children: [
        _DiscoverySection(
          title: 'Continue Browsing',
          provider: recentlyViewedProvider,
          scrollController: _scrollController,
          onClear: () => ref.read(marketplaceControllerProvider.notifier).clearRecentlyViewed(),
        ),
        _DiscoverySection(
          title: 'Recommended For You',
          provider: recommendedListingsProvider,
          scrollController: _scrollController,
        ),
        _DiscoverySection(
          title: recentlyPostedTitle,
          provider: listingsProvider(ListingFilter(sortBy: ListingSortType.newest, itemsLimit: 10)),
          scrollController: _scrollController,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: BannerAdWidget(),
        ),
        _DiscoverySection(
          title: 'Most Saved',
          provider: listingsProvider(ListingFilter(sortBy: ListingSortType.mostSaved, itemsLimit: 10)),
          scrollController: _scrollController,
        ),
        _DiscoverySection(
          title: 'Popular This Week',
          provider: listingsProvider(ListingFilter(sortBy: ListingSortType.mostViewed, itemsLimit: 10)),
          scrollController: _scrollController,
        ),
        _DiscoverySection(
          title: trendingTitle,
          provider: trendingListingsProvider,
          scrollController: _scrollController,
        ),
      ],
    );
  }

  Widget _buildListingsGrid(ListingFilter filter) {
    final theme = Theme.of(context);
    final paginatedState = ref.watch(paginatedListingsProvider(filter));
    final controller = ref.read(marketplaceControllerProvider.notifier);

    if (paginatedState.isLoading) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.75,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => const SkeletonLoader(width: double.infinity, height: 250),
            childCount: 4,
          ),
        ),
      );
    }

    if (paginatedState.hasError && paginatedState.items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorView(
          error: paginatedState.error,
          onRetry: () => ref.read(paginatedListingsProvider(filter).notifier).retry(),
          isFullPage: false,
        ),
      );
    }

    final listings = paginatedState.items;
    
    if (listings.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          title: 'No items match your search',
          message: 'Try switching to "All Campuses" or explore another category to find what you\'re looking for.',
          icon: CategoryUtils.getIcon(FeedType.marketplace),
          action: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => controller.resetFilters(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Clear Filters'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () {
                  controller.resetFilters();
                  ref.read(browsingScopeProvider.notifier).reset();
                },
                child: const Text('Explore All'),
              ),
            ],
          ),
        ),
      );
    }

    final List<Widget> gridChunks = [];
    const int adInterval = AdConfig.marketplaceAdInterval;

    for (int i = 0; i < listings.length; i += adInterval) {
      final int end = (i + adInterval < listings.length) ? i + adInterval : listings.length;
      final chunk = listings.sublist(i, end);

      gridChunks.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.7,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => MarketplaceCard(
                listing: chunk[index],
                index: i + index,
                heroTag: 'hero_grid_${chunk[index].id}',
              ),
              childCount: chunk.length,
            ),
          ),
        ),
      );

      if (end < listings.length) {
        gridChunks.add(
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: BannerAdWidget(),
            ),
          ),
        );
      }
    }

    return SliverMainAxisGroup(
      slivers: [
        if (filter.searchQuery.isNotEmpty || filter.selectedCategory != null || filter.sortBy != ListingSortType.newest)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          filter.searchQuery.isNotEmpty 
                            ? 'Results for "${filter.searchQuery}"'
                            : (filter.selectedCategory != null 
                                ? 'Browsing ${filter.selectedCategory}'
                                : 'Sorted by ${filter.sortBy.name}'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => controller.resetFilters(),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showSaveSearchDialog(context, filter),
                          icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                          label: const Text('Save Search & Alert Me'),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ...gridChunks,
        if (paginatedState.isFetchingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildMyListingsTab() {
    final theme = Theme.of(context);
    final userData = ref.watch(appUserProvider.select((u) {
      final user = u.valueOrNull;
      if (user == null) return null;
      return (
        uid: user.uid,
        verifiedRoles: user.verifiedRoles,
      );
    }));

    if (userData == null) return const Center(child: Text('Please log in to see your listings'));

    final applicationAsync = ref.watch(applicationByRoleProvider(ProfessionalRole.seller));
    final myListingsAsync = ref.watch(sellerListingsProvider(userData.uid));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(sellerListingsProvider(userData.uid));
        ref.invalidate(applicationByRoleProvider(ProfessionalRole.seller));
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        children: [
          applicationAsync.when(
            data: (app) => (userData.verifiedRoles.contains('seller')) ? const SizedBox.shrink() : _buildSellerVerificationCTA(app),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: _buildHubCard(
                    title: 'Seller Dashboard',
                    subtitle: 'Track performance',
                    icon: Icons.analytics_outlined,
                    color: theme.colorScheme.primary,
                    onTap: () => context.push('/seller-dashboard'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildHubCard(
                    title: 'Active Offers',
                    subtitle: 'Manage negotiations',
                    icon: Icons.handshake_outlined,
                    color: Colors.orange,
                    onTap: () => context.push('/seller-offers'), // Ensure this route exists or redirect to dashboard
                  ),
                ),
              ],
            ),
          ),

          Consumer(
            builder: (context, ref, _) {
              final user = ref.watch(appUserProvider).valueOrNull;
              if (user == null || user.accountType == 'business') return const SizedBox.shrink();
              
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: InkWell(
                  onTap: () => context.push('/business-upgrade'),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.business_center_rounded, color: Colors.blue, size: 18),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Upgrade to Business', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('Get a professional badge & pro tools', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
                      ],
                    ),
                  ),
                ),
              );
            }
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: BannerAdWidget(),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Items',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/add-listing'),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New Listing'),
                ),
              ],
            ),
          ),

          myListingsAsync.when(
            data: (listings) {
              if (listings.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
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
                            Icons.shopping_bag_outlined, 
                            size: 56, 
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No active listings', 
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Start selling to your campus community.', 
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppColors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.7,
                ),
                itemCount: listings.length,
                itemBuilder: (context, index) => MarketplaceCard(
                  listing: listings[index], 
                  index: index,
                  heroTag: 'hero_my_${listings[index].id}',
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(40),
              child: Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHubCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerVerificationCTA(VerificationApplication? app) {
    // Optimization: watch only verification-relevant properties
    final userData = ref.watch(appUserProvider.select((u) {
      final user = u.valueOrNull;
      if (user == null) return null;
      return (
        isVerified: user.isVerified,
        identityStatus: user.identityStatus,
        verifiedRoles: user.verifiedRoles,
      );
    }));

    final bool isVerified = userData?.isVerified ?? false;
    final bool isIdentityPending = userData?.identityStatus == 'pending';
    final bool isIdentityRejected = userData?.identityStatus == 'rejected';
    
    final isRolePending = app?.status == VerificationStatus.pending;
    final isRoleRejected = app?.status == VerificationStatus.rejected;

    final bool showIdentityIssue = !isVerified || isIdentityPending || isIdentityRejected;

    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (isRoleRejected || isIdentityRejected) ? theme.colorScheme.errorContainer : theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (isRoleRejected || isIdentityRejected) ? theme.colorScheme.error : theme.colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                (isRoleRejected || isIdentityRejected) ? Icons.error_outline : ((isRolePending || isIdentityPending) ? Icons.access_time : Icons.verified_user_outlined),
                color: (isRoleRejected || isIdentityRejected) ? theme.colorScheme.error : theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                showIdentityIssue 
                  ? (isIdentityRejected ? 'Identity Rejected' : (isIdentityPending ? 'Identity Reviewing' : 'Identity Required'))
                  : (isRoleRejected ? 'Seller Application Rejected' : (isRolePending ? 'Review Pending' : 'Apply as Trusted Seller')),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: (isRoleRejected || isIdentityRejected) ? theme.colorScheme.onErrorContainer : theme.colorScheme.onPrimaryContainer,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            showIdentityIssue
                ? (isIdentityRejected 
                    ? 'Your identity verification was not approved. Please update it in the Trust Center.' 
                    : (isIdentityPending 
                        ? 'We are currently verifying your platform identity. You can apply as a seller once approved.' 
                        : 'You must verify your platform identity before applying for a seller badge.'))
                : (isRoleRejected
                    ? 'Your seller application was not approved. Review the guidelines and try again.'
                    : (isRolePending 
                        ? 'Our team is reviewing your application. You\'ll get a badge once approved.'
                        : 'Get a verification badge next to your items and build trust with buyers.')),
            style: TextStyle(
              fontSize: 13,
              color: (isRoleRejected || isIdentityRejected) ? theme.colorScheme.onErrorContainer.withOpacity(0.8) : theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
            ),
          ),
          if (!isRolePending && !isIdentityPending) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.push(isVerified ? '/verify-professional/seller' : (isIdentityRejected ? '/trust-center' : '/verify-identity')),
                style: FilledButton.styleFrom(
                  backgroundColor: (isRoleRejected || isIdentityRejected) ? theme.colorScheme.error : theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(showIdentityIssue ? (isIdentityRejected ? 'Go to Trust Center' : 'Verify Identity') : (isRoleRejected ? 'Re-apply Now' : 'Apply Now')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategorySpecificFilters(BuildContext context, ListingFilter state, MarketplaceController controller, StateSetter setModalState) {
    final theme = Theme.of(context);
    final category = state.selectedCategory;
    
    List<Widget> filterWidgets = [];

    if (category == 'Phones') {
      filterWidgets.addAll([
        _buildFilterDropdown(
          label: 'Brand',
          value: state.categoryAttributes['brand'],
          options: ['Apple', 'Samsung', 'Google', 'Xiaomi', 'Oppo', 'Other'],
          onChanged: (val) => controller.updateAttribute('brand', val),
          setModalState: setModalState,
        ),
        _buildFilterDropdown(
          label: 'Storage',
          value: state.categoryAttributes['storage'],
          options: ['64GB', '128GB', '256GB', '512GB', '1TB'],
          onChanged: (val) => controller.updateAttribute('storage', val),
          setModalState: setModalState,
        ),
      ]);
    } else if (category == 'Shoes') {
      filterWidgets.addAll([
        _buildFilterDropdown(
          label: 'Brand',
          value: state.categoryAttributes['brand'],
          options: ['Nike', 'Adidas', 'Puma', 'Jordan', 'New Balance', 'Other'],
          onChanged: (val) => controller.updateAttribute('brand', val),
          setModalState: setModalState,
        ),
        _buildFilterDropdown(
          label: 'Size',
          value: state.categoryAttributes['size'],
          options: ['38', '39', '40', '41', '42', '43', '44', '45'],
          onChanged: (val) => controller.updateAttribute('size', val),
          setModalState: setModalState,
        ),
      ]);
    }

    if (filterWidgets.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$category Filters', 
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold, 
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        ...filterWidgets,
      ],
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required dynamic value,
    required List<String> options,
    required Function(String?) onChanged,
    required StateSetter setModalState,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        hint: Text('Select $label'),
        dropdownColor: theme.colorScheme.surface,
        style: TextStyle(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
        items: [
          const DropdownMenuItem<String>(value: null, child: Text('Any')),
          ...options.map((o) => DropdownMenuItem(value: o, child: Text(o))),
        ],
        onChanged: (val) {
          onChanged(val);
          setModalState(() {});
        },
      ),
    );
  }
  
  void _showSaveSearchDialog(BuildContext context, ListingFilter filter) {
    final nameController = TextEditingController(
      text: filter.searchQuery.isNotEmpty ? filter.searchQuery : (filter.selectedCategory ?? 'Saved Search')
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Search'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Get notified when new items match these filters.'),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. MacBook Air',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              ref.read(savedSearchesControllerProvider.notifier).saveCurrentSearch(
                name: nameController.text,
                filter: filter,
                campusId: ref.read(browsingScopeProvider).campusId,
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search saved! You\'ll be alerted for new matches.')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context, ListingFilter state, MarketplaceController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final mTheme = Theme.of(context);
          return Container(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Refine Search',
                      style: mTheme.textTheme.titleLarge?.copyWith(
                        fontSize: 22, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: mTheme.colorScheme.onSurface),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Sort By', 
                  style: mTheme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, 
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ListingSortType>(
                  value: state.sortBy,
                  dropdownColor: mTheme.colorScheme.surface,
                  style: TextStyle(color: mTheme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: mTheme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: ListingSortType.values.map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.name.replaceFirst(s.name[0], s.name[0].toUpperCase())),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      controller.setSortBy(val);
                      setModalState(() {});
                    }
                  },
                ),
                if (state.selectedCategory != null) ...[
                  const SizedBox(height: 24),
                  _buildCategorySpecificFilters(context, state, controller, setModalState),
                ],
                const SizedBox(height: 24),
                Text(
                  'Condition', 
                  style: mTheme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, 
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: ['newCondition', 'likeNew', 'good', 'fair'].map((cond) {
                    final isSelected = state.selectedConditions.contains(cond);
                    return ChoiceChip(
                      label: Text(cond.replaceFirst('newCondition', 'New')),
                      selected: isSelected,
                      onSelected: (_) {
                        controller.toggleCondition(cond);
                        setModalState(() {});
                      },
                      selectedColor: mTheme.colorScheme.primaryContainer,
                      backgroundColor: mTheme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      labelStyle: TextStyle(
                        color: isSelected ? mTheme.colorScheme.primary : mTheme.colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Text(
                  'Price Range (KES)', 
                  style: mTheme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, 
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                RangeSlider(
                  values: state.priceRange ?? const RangeValues(0, 50000),
                  min: 0,
                  max: 100000,
                  divisions: 100,
                  activeColor: AppColors.secondary,
                  inactiveColor: AppColors.secondary.withOpacity(0.2),
                  labels: RangeLabels(
                    '${state.priceRange?.start.toInt() ?? 0}',
                    '${state.priceRange?.end.toInt() ?? 50000}',
                  ),
                  onChanged: (val) {
                    controller.setPriceRange(val);
                    setModalState(() {});
                  },
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DiscoverySection extends ConsumerWidget {
  final String title;
  final ProviderListenable<AsyncValue<List<Listing>>> provider;
  final ScrollController scrollController;
  final VoidCallback? onClear;

  const _DiscoverySection({
    required this.title,
    required this.provider,
    required this.scrollController,
    this.onClear,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(provider);
    final theme = Theme.of(context);
    final sectionPrefix = title.replaceAll(' ', '_').toLowerCase();

    return listingsAsync.when(
      data: (listings) {
        if (listings.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (onClear != null)
                    TextButton(
                      onPressed: onClear,
                      child: Text('Clear', style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold, fontSize: 13)),
                    )
                  else
                    TextButton(
                      onPressed: () {
                        final controller = ref.read(marketplaceControllerProvider.notifier);
                        if (title.contains('Trending')) {
                          controller.setSortBy(ListingSortType.mostViewed);
                        } else if (title.contains('Recently Posted') || title.contains('New in')) {
                           scrollController.animateTo(
                             scrollController.position.maxScrollExtent,
                             duration: const Duration(milliseconds: 500),
                             curve: Curves.easeInOut,
                           );
                        } else if (title == 'Most Saved') {
                          controller.setSortBy(ListingSortType.mostSaved);
                        } else if (title == 'Popular This Week') {
                          controller.setSortBy(ListingSortType.mostViewed);
                        }
                      },
                      child: Text(
                        (title.contains('Recently Posted') || title.contains('New in')) ? 'See Grid' : 'See All', 
                        style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 260,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: listings.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 170,
                    child: MarketplaceCard(
                      listing: listings[index], 
                      index: index,
                      heroTag: 'hero_${sectionPrefix}_${listings[index].id}',
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}

class MarketplaceSearchDelegate extends SearchDelegate<String?> {
  final WidgetRef ref;
  final ScrollController scrollController;

  MarketplaceSearchDelegate({required this.ref, required this.scrollController});

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          onPressed: () => query = '',
          icon: const Icon(Icons.clear_rounded),
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back_rounded),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final controller = ref.read(marketplaceControllerProvider.notifier);
    final user = ref.read(appUserProvider).valueOrNull;
    
    if (user != null && query.isNotEmpty) {
      ref.read(marketplaceRepositoryProvider).saveSearchQuery(user.uid, query);
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      controller.setSearchQuery(query);
      close(context, query);
    });
    
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final theme = Theme.of(context);
        final recentSearchesAsync = ref.watch(recentSearchesProvider);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (query.isEmpty) ...[
              recentSearchesAsync.when(
                data: (searches) {
                  if (searches.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recent Searches',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            TextButton(
                              onPressed: () => ref.read(marketplaceControllerProvider.notifier).clearRecentSearches(),
                              child: Text('Clear All', style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                      ...searches.take(5).map((s) => ListTile(
                        leading: const Icon(Icons.history_rounded, size: 20),
                        title: Text(s),
                        trailing: const Icon(Icons.north_west_rounded, size: 16, color: AppColors.grey),
                        onTap: () {
                          query = s;
                          showResults(context);
                        },
                      )),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              FutureBuilder<List<String>>(
                future: ref.read(marketplaceRepositoryProvider).getPopularSearches(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                        child: Text(
                          'Popular Searches',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 0,
                          children: snapshot.data!.map((s) => ActionChip(
                            label: Text(s, style: const TextStyle(fontSize: 12)),
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              query = s;
                              showResults(context);
                            },
                          )).toList(),
                        ),
                      ),
                    ],
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text(
                  'Popular Categories',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 10,
                  children: MarketplaceCategories.mainFilters.where((c) => c != 'All').take(6).map((cat) => ActionChip(
                    label: Text(cat),
                    onPressed: () {
                      ref.read(marketplaceControllerProvider.notifier).setCategory(cat);
                      close(context, cat);
                    },
                  )).toList(),
                ),
              ),
            ] else ...[
              FutureBuilder<List<String>>(
                future: ref.read(marketplaceRepositoryProvider).getSearchSuggestions(query),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final suggestion = snapshot.data![index];
                      return ListTile(
                        leading: const Icon(Icons.search_rounded, size: 20),
                        title: Text(suggestion),
                        onTap: () {
                          query = suggestion;
                          showResults(context);
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }
}
