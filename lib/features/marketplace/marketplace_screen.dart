import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../../core/utils/debouncer.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/notification_badge.dart';

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
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          'Marketplace',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          const NotificationBadge(module: 'marketplace'),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.indigo,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.indigo,
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Discover'),
            Tab(text: 'My Listings'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-listing'),
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('Post Listing'),
        backgroundColor: Colors.indigo,
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

    // Use specific sections when no search/filter is active
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(controller, filterState),
                  const SizedBox(height: 20),
                  _buildCategoryChips(filterState, controller),
                  if (isBrowsingHome) ...[
                    const SizedBox(height: 24),
                    _buildDiscoverySection(
                      title: 'Recently Viewed',
                      provider: recentlyViewedProvider,
                      emptyWidget: const SizedBox.shrink(),
                    ),
                    _buildDiscoverySection(
                      title: 'Recommended For You',
                      provider: recommendedListingsProvider,
                    ),
                    _buildDiscoverySection(
                      title: 'Trending in ${user?.university ?? 'Campus'}',
                      provider: trendingListingsProvider(user?.university),
                    ),
                    _buildPopularCategories(),
                    const SizedBox(height: 24),
                    Text(
                      'Recently Added',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Search Results',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
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
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: Colors.indigo),
                  const SizedBox(width: 12),
                  Text(
                    filterState.searchQuery.isEmpty 
                        ? 'What are you looking for?' 
                        : filterState.searchQuery,
                    style: GoogleFonts.plusJakartaSans(
                      color: filterState.searchQuery.isEmpty ? Colors.grey.shade400 : Colors.black87,
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
          icon: const Icon(Icons.tune_rounded, color: Colors.black),
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey.shade50,
            padding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChips(ListingFilter filterState, MarketplaceController controller) {
    const List<String> categories = MarketplaceCategories.mainFilters;
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
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  controller.setCategory(cat);
                }
              },
              backgroundColor: Colors.grey.shade50,
              selectedColor: Colors.indigo,
              showCheckmark: false,
              pressElevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isSelected ? Colors.indigo : Colors.grey.shade200,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPopularCategories() {
    final categories = MarketplaceCategories.mainFilters.where((c) => c != 'All').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Popular Categories',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ActionChip(
                  onPressed: () => context.push('/category-discovery/$cat'),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(cat, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  backgroundColor: Colors.indigo.shade50,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoverySection({
    required String title,
    required StreamProvider<List<Listing>> provider,
    Widget? emptyWidget,
  }) {
    final asyncListings = ref.watch(provider);

    return asyncListings.when(
      data: (listings) {
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
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
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
                    child: MarketplaceCard(listing: listings[index], index: index),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 24),
        child: SkeletonLoader(width: double.infinity, height: 200),
      ),
      error: (e, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildListingsGrid(ListingFilter filter) {
    final listingsAsync = ref.watch(listingsProvider(filter));

    return listingsAsync.when(
      data: (listings) {
        if (listings.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade200),
                  const SizedBox(height: 16),
                  Text(
                    'No items found',
                    style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => ref.read(marketplaceControllerProvider.notifier).resetFilters(),
                    child: const Text('Clear all filters'),
                  ),
                ],
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => MarketplaceCard(listing: listings[index], index: index),
              childCount: listings.length,
            ),
          ),
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
                      Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey.shade200),
                      const SizedBox(height: 16),
                      const Text('You haven\'t posted any listings yet', style: TextStyle(color: Colors.grey)),
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
                itemBuilder: (context, index) => MarketplaceCard(listing: listings[index], index: index),
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

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (isRoleRejected || isIdentityRejected) ? Colors.red.shade50 : Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: (isRoleRejected || isIdentityRejected) ? Colors.red.shade100 : Colors.indigo.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                (isRoleRejected || isIdentityRejected) ? Icons.error_outline : ((isRolePending || isIdentityPending) ? Icons.access_time : Icons.verified_user_outlined),
                color: (isRoleRejected || isIdentityRejected) ? Colors.red : Colors.indigo,
              ),
              const SizedBox(width: 12),
              Text(
                showIdentityIssue 
                  ? (isIdentityRejected ? 'Identity Rejected' : (isIdentityPending ? 'Identity Reviewing' : 'Identity Required'))
                  : (isRoleRejected ? 'Seller Application Rejected' : (isRolePending ? 'Review Pending' : 'Apply as Trusted Seller')),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: (isRoleRejected || isIdentityRejected) ? Colors.red.shade900 : Colors.indigo.shade900,
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
              color: (isRoleRejected || isIdentityRejected) ? Colors.red.shade700 : Colors.indigo.shade700,
            ),
          ),
          if (!isRolePending && !isIdentityPending) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.push(isVerified ? '/verify-professional/seller' : (isIdentityRejected ? '/trust-center' : '/verify-identity')),
                style: FilledButton.styleFrom(
                  backgroundColor: (isRoleRejected || isIdentityRejected) ? Colors.red : Colors.indigo,
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

  void _showFilterSheet(BuildContext context, ListingFilter state, MarketplaceController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
                    style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Sort By', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              DropdownButtonFormField<ListingSortType>(
                value: state.sortBy,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade50,
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
              const SizedBox(height: 24),
              Text('Condition', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16)),
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
                    selectedColor: Colors.indigo.shade50,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.indigo : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Text('Price Range (KES)', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              RangeSlider(
                values: state.priceRange ?? const RangeValues(0, 50000),
                min: 0,
                max: 100000,
                divisions: 100,
                activeColor: Colors.indigo,
                inactiveColor: Colors.indigo.shade50,
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
                    backgroundColor: Colors.indigo,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
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
    final user = ref.watch(appUserProvider).valueOrNull;
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
                    child: Text(
                      'Recent Searches',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  ...searches.take(5).map((s) => ListTile(
                    leading: const Icon(Icons.history_rounded, size: 20),
                    title: Text(s),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text(
              'Popular Categories',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
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
