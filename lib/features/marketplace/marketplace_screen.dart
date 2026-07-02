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
import 'shared/providers.dart';
import 'domain/models/listing_filter.dart';
import 'presentation/widgets/marketplace_card.dart';
import '../campus_filter/domain/models/browsing_scope.dart';
import '../campus_filter/shared/providers.dart';
import '../campus_filter/presentation/widgets/campus_filter_selector.dart';
import '../../core/constants/campus_constants.dart';
import '../../core/utils/debouncer.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/notification_badge.dart';
import '../../services/notification_service.dart';
import 'package:unihub_mobile/features/announcements/presentation/widgets/announcement_display.dart';
import 'package:unihub_mobile/features/ads/ads_module.dart';

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
  }

  @override
  void dispose() {
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
          const NotificationBadge(module: 'marketplace'),
          const SizedBox(width: 4),
          if (ref.watch(appUserProvider).valueOrNull?.isAdmin ?? false)
            IconButton(
              icon: const Icon(Icons.campaign_outlined, color: AppColors.secondary),
              tooltip: 'Broadcast Marketplace Reminder',
              onPressed: () => _showBroadcastConfirm(context, ref),
            ),
          const SizedBox(width: 8),
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
        label: const Text('Post Listing'),
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
    final theme = Theme.of(context);
    final filterState = ref.watch(marketplaceControllerProvider);
    final controller = ref.read(marketplaceControllerProvider.notifier);

    final bool isBrowsingHome = filterState.searchQuery.isEmpty && 
                                filterState.selectedCategory == null &&
                                filterState.selectedConditions.isEmpty &&
                                filterState.priceRange == null;

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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(controller, filterState),
                  const SizedBox(height: 16),
                  const CampusFilterSelector(),
                  const SizedBox(height: 12),
                  if (isBrowsingHome) ...[
                    _buildPopularCategories(),
                    _buildDiscoveryContent(ref),
                  ] else ...[
                    const SizedBox(height: 8),
                    _buildCategoryChips(filterState, controller),
                  ],
                ],
              ),
            ),
          ),

          _buildListingsGrid(isBrowsingHome ? ListingFilter() : filterState),
        ],
      ),
    );
  }

  Widget _buildSearchBar(MarketplaceController controller, ListingFilter filterState) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => showSearch(
              context: context,
              delegate: MarketplaceSearchDelegate(ref: ref),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: AppColors.secondary),
                  const SizedBox(width: 12),
                  Text(
                    filterState.searchQuery.isEmpty 
                        ? 'What are you looking for?' 
                        : filterState.searchQuery,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: filterState.searchQuery.isEmpty ? AppColors.grey : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          onPressed: () => _showFilterSheet(context, filterState, controller), 
          icon: Icon(Icons.tune_rounded, color: theme.colorScheme.onSurface),
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            padding: const EdgeInsets.all(12),
          ),
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
              backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              selectedColor: AppColors.secondary,
              showCheckmark: false,
              pressElevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
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

  Widget _buildPopularCategories() {
    final theme = Theme.of(context);
    const categories = MarketplaceCategories.mainFilters;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Shop by Category',
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return Padding(
                padding: const EdgeInsets.only(right: 14),
                child: GestureDetector(
                  onTap: () => context.push('/category-discovery/$cat'),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          MarketplaceCategories.getIcon(cat),
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cat,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoveryContent(WidgetRef ref) {
    final discoveryAsync = ref.watch(marketplaceDiscoveryProvider);
    final scope = ref.watch(browsingScopeProvider);
    final user = ref.watch(appUserProvider).valueOrNull;

    String trendingTitle = 'Trending';
    if (scope.type == BrowsingScopeType.myCampus) {
      final uniName = CampusConstants.getDisplayName(
        CampusConstants.resolveToId(user?.university)
      );
      trendingTitle = 'Trending in $uniName';
    } else if (scope.type == BrowsingScopeType.specific) {
      trendingTitle = 'Trending in ${CampusConstants.getDisplayName(scope.campusId)}';
    } else {
      trendingTitle = 'Trending across Campuses';
    }

    return discoveryAsync.when(
      data: (data) => Column(
        children: [
          _buildDiscoverySection(
            context: context,
            title: 'Continue Browsing',
            listings: data.recentlyViewed,
            emptyWidget: const SizedBox.shrink(),
          ),
          _buildDiscoverySection(
            context: context,
            title: 'Recommended For You',
            listings: data.recommended,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: BannerAdWidget(),
          ),
          _buildDiscoverySection(
            context: context,
            title: trendingTitle,
            listings: data.trending,
          ),
        ],
      ),
      loading: () => const Column(
        children: [
          SizedBox(height: 24),
          SkeletonLoader(width: double.infinity, height: 200),
          SizedBox(height: 24),
          SkeletonLoader(width: double.infinity, height: 200),
        ],
      ),
      error: (e, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildDiscoverySection({
    required BuildContext context,
    required String title,
    required List<Listing> listings,
    Widget? emptyWidget,
  }) {
    final theme = Theme.of(context);
    final sectionPrefix = title.replaceAll(' ', '_').toLowerCase();

    if (listings.isEmpty) return emptyWidget ?? const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            if (title == 'Continue Browsing')
              TextButton(
                onPressed: () => ref.read(marketplaceControllerProvider.notifier).clearRecentlyViewed(),
                child: Text('Clear', style: TextStyle(color: theme.colorScheme.error)),
              )
            else
              TextButton(
                onPressed: () {}, // Show all
                child: const Text('See All'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: listings.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 160,
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
  }

  Widget _buildListingsGrid(ListingFilter filter) {
    final theme = Theme.of(context);
    final listingsAsync = ref.watch(listingsProvider(filter));
    final controller = ref.read(marketplaceControllerProvider.notifier);

    return listingsAsync.when(
      data: (listings) {
        if (listings.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.search_off_rounded, size: 64, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No items match your search',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Try switching to "All Campuses" or explore another category to find what you\'re looking for.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => controller.resetFilters(),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Clear Filters'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: () {
                            controller.resetFilters();
                            ref.read(browsingScopeProvider.notifier).reset();
                          },
                          child: const Text('Explore All'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final bool isSearching = filter.searchQuery.isNotEmpty || filter.selectedCategory != null;

        // Adaptive chunking to insert ads using central config
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
                  childAspectRatio: 0.75,
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

          // Add banner ad between chunks, but not at the very top (i=0) or very end if no more items
          if (end < listings.length) {
            gridChunks.add(
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: const BannerAdWidget(),
                ),
              ),
            );
          }
        }

        return SliverMainAxisGroup(
          slivers: [
            if (isSearching)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        filter.searchQuery.isNotEmpty 
                          ? 'Results for "${filter.searchQuery}"'
                          : 'Browsing ${filter.selectedCategory ?? 'Items'}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => controller.resetFilters(),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Reset'),
                      ),
                    ],
                  ),
                ),
              ),
            ...gridChunks,
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
      loading: () => SliverPadding(
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
      ),
      error: (err, _) => SliverToBoxAdapter(
        child: Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildMyListingsTab() {
    final theme = Theme.of(context);
    final user = ref.watch(appUserProvider).valueOrNull;
    if (user == null) return const Center(child: Text('Please log in to see your listings'));

    final isVerifiedSeller = user.verifiedRoles.contains('seller');
    final applicationAsync = ref.watch(applicationByRoleProvider(ProfessionalRole.seller));

    final myListingsAsync = ref.watch(sellerListingsProvider(user.uid));

    return Column(
      children: [
        if (!isVerifiedSeller)
          applicationAsync.when(
            data: (app) => _buildSellerVerificationCTA(app),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        Expanded(
          child: myListingsAsync.when(
            data: (listings) {
              if (listings.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_bag_outlined, size: 64, color: theme.colorScheme.outlineVariant),
                      const SizedBox(height: 16),
                      Text('You haven\'t posted any listings yet', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => context.push('/add-listing'),
                        child: const Text('Add Your First Listing'),
                      ),
                    ],
                  ),
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: listings.length,
                itemBuilder: (context, index) => MarketplaceCard(
                  listing: listings[index], 
                  index: index,
                  heroTag: 'hero_my_${listings[index].id}',
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }

  Widget _buildSellerVerificationCTA(VerificationApplication? app) {
    final user = ref.watch(appUserProvider).valueOrNull;
    final isVerified = user?.isVerified ?? false;
    final isIdentityPending = user?.identityStatus == 'pending';
    final isIdentityRejected = user?.identityStatus == 'rejected';
    
    final isRolePending = app?.status == VerificationStatus.pending;
    final isRoleRejected = app?.status == VerificationStatus.rejected;

    final bool showIdentityIssue = !isVerified || isIdentityPending || isIdentityRejected;

    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (isRoleRejected || isIdentityRejected) ? theme.colorScheme.errorContainer : theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
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
    } else if (category == 'Vehicles') {
      filterWidgets.addAll([
        _buildFilterDropdown(
          label: 'Fuel Type',
          value: state.categoryAttributes['fuelType'],
          options: ['Petrol', 'Diesel', 'Electric', 'Hybrid'],
          onChanged: (val) => controller.updateAttribute('fuelType', val),
          setModalState: setModalState,
        ),
      ]);
    } else if (category == 'Furniture') {
      filterWidgets.addAll([
        _buildFilterDropdown(
          label: 'Material',
          value: state.categoryAttributes['material'],
          options: ['Wood', 'Metal', 'Plastic', 'Glass', 'Fabric', 'Leather'],
          onChanged: (val) => controller.updateAttribute('material', val),
          setModalState: setModalState,
        ),
        _buildFilterDropdown(
          label: 'Type',
          value: state.categoryAttributes['type'],
          options: ['Chair', 'Table', 'Bed', 'Desk', 'Sofa', 'Storage'],
          onChanged: (val) => controller.updateAttribute('type', val),
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
          fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
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
  void _showBroadcastConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Broadcast Reminder?'),
        content: const Text(
          'This will send a random marketplace push notification to ALL UniHub users. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(notificationServiceProvider).triggerMarketplaceReminder();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Marketplace reminder broadcast triggered!')),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.secondary),
            child: const Text('Broadcast Now'),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
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
                    fillColor: mTheme.colorScheme.surfaceVariant.withOpacity(0.3),
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
                      backgroundColor: mTheme.colorScheme.surfaceVariant.withOpacity(0.3),
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

class MarketplaceSearchDelegate extends SearchDelegate<String?> {
  final WidgetRef ref;

  MarketplaceSearchDelegate({required this.ref});

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
    
    // Save search query
    if (user != null && query.isNotEmpty) {
      ref.read(marketplaceRepositoryProvider).saveSearchQuery(user.uid, query);
    }
    
    // We don't build results here, we just close and set the filter in controller
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.setSearchQuery(query);
      close(context, query);
    });
    
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
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
  }
}
