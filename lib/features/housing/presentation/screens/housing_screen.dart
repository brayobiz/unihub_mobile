import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unihub_mobile/core/location/repositories/campus_repository.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/widgets/app_drawer.dart';
import 'package:unihub_mobile/core/widgets/optimized_image.dart';
import 'package:unihub_mobile/widgets/skeleton_loader.dart';
import 'package:unihub_mobile/widgets/notification_badge.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/housing/shared/providers.dart';
import 'package:unihub_mobile/features/trust/domain/models/professional_role.dart';
import 'package:unihub_mobile/features/trust/domain/models/verification_application.dart';
import 'package:unihub_mobile/features/trust/presentation/providers/trust_providers.dart';
import 'package:unihub_mobile/features/housing/presentation/widgets/housing_card.dart';
import 'package:unihub_mobile/features/housing/domain/models/housing_listing.dart';
import 'package:unihub_mobile/features/housing/domain/models/housing_saved_search.dart';
import 'package:uuid/uuid.dart';
import 'package:unihub_mobile/features/announcements/presentation/widgets/announcement_display.dart';
import 'package:unihub_mobile/features/campus_filter/presentation/widgets/campus_filter_selector.dart';
import 'package:unihub_mobile/features/campus_filter/shared/providers.dart';
import 'package:unihub_mobile/features/ads/ads_module.dart';

import '../controllers/paginated_housing_controller.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/empty_state.dart';

class HousingScreen extends ConsumerStatefulWidget {
  const HousingScreen({super.key});

  @override
  ConsumerState<HousingScreen> createState() => _HousingScreenState();
}

class _HousingScreenState extends ConsumerState<HousingScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final filter = _getCurrentFilter();
      ref.read(paginatedHousingProvider(filter).notifier).fetchMore();
    }
  }

  HousingFilterState _getCurrentFilter() {
    final spatialContext = ref.read(housingSpatialSearchProvider);
    final targetUniversity = spatialContext?.isCampus == true ? spatialContext!.id : null;
    final locationFilter = ref.read(housingLocationFilterProvider);

    return HousingFilterState(
      universityId: targetUniversity,
      location: spatialContext != null ? null : locationFilter,
      type: ref.read(housingTypeFilterProvider),
      minRent: ref.read(housingMinRentFilterProvider),
      maxRent: ref.read(housingMaxRentFilterProvider),
      genderRestriction: ref.read(housingGenderFilterProvider),
      isFurnished: ref.read(housingFurnishedFilterProvider),
    );
  }

  Future<void> _loadRecentSearches() async {
    final prefs = ref.read(sharedPreferencesProvider);
    setState(() {
      _recentSearches = prefs.getStringList('recent_housing_searches') ?? <String>[];
    });
  }

  Future<void> _clearRecentSearches() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove('recent_housing_searches');
    setState(() {
      _recentSearches = [];
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Optimization: only watch necessary user properties
    final userData = ref.watch(appUserProvider.select((u) {
      final user = u.valueOrNull;
      if (user == null) return null;
      return (
        verifiedRoles: user.verifiedRoles,
        isVerified: user.isVerified,
      );
    }));

    final isVerifiedPlug = userData?.verifiedRoles.contains('housePlug') ?? false;
    final applicationAsync = ref.watch(applicationByRoleProvider(ProfessionalRole.housePlug));
    
    final locationFilter = ref.watch(housingLocationFilterProvider);
    final spatialContext = ref.watch(housingSpatialSearchProvider);
    final hasActiveFilters = ref.watch(housingTypeFilterProvider) != null || 
                            ref.watch(housingGenderFilterProvider) != null ||
                            ref.watch(housingMaxRentFilterProvider) != null ||
                            (locationFilter != null && locationFilter.isNotEmpty) ||
                            spatialContext != null;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(topHousingProvider);
          ref.invalidate(featuredHousingProvider);
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildSliverAppBar(isVerifiedPlug),
            const SliverToBoxAdapter(
              child: RelevantAnnouncementsWidget(feature: 'housing'),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchBar(),
                    const SizedBox(height: 12),
                    const CampusFilterSelector(),
                    if (_searchController.text.isEmpty && _recentSearches.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildRecentSearches(),
                    ],
                    const SizedBox(height: 16),
                    if (!isVerifiedPlug) ...[
                      applicationAsync.when(
                        data: (application) => _buildBecomePlugCTA(application),
                        loading: () => SkeletonLoader(width: double.infinity, height: 120, borderRadius: 20, color: theme.colorScheme.surfaceVariant),
                        error: (_, __) => _buildBecomePlugCTA(null),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildCompactActionCTA(
                            icon: Icons.add_business_rounded,
                            title: 'Report Vacancy',
                            onTap: () => context.push('/submit-vacancy'),
                            color: theme.colorScheme.primary,
                          )),
                          const SizedBox(width: 10),
                          Expanded(child: _buildCompactActionCTA(
                            icon: Icons.people_outline_rounded,
                            title: 'Find Roommate',
                            onTap: () => context.push('/roommates'),
                            color: theme.colorScheme.secondary,
                          )),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      _buildPlugDashboardQuickCTA(),
                      const SizedBox(height: 16),
                    ],
                    _buildCategorySelector(),
                    if (hasActiveFilters) ...[
                      const SizedBox(height: 12),
                      _buildActiveFiltersRow(),
                    ],
                    const SizedBox(height: 16),
                    if (locationFilter == null || locationFilter.isEmpty) ...[
                      _buildNearbyAreas(),
                      const SizedBox(height: 16),
                      _buildFeaturedSection(),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: BannerAdWidget(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _buildListingsSliver(locationFilter),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildSliverAppBar(bool isVerifiedPlug) {
    final theme = Theme.of(context);
    return SliverAppBar(
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      leading: Builder(
        builder: (context) => IconButton(
          icon: Icon(Icons.menu_rounded, color: theme.colorScheme.onSurface),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.person_add_alt_1_rounded, color: theme.colorScheme.onSurface),
          tooltip: 'Find a Roommate',
          onPressed: () => context.push('/add-roommate'),
        ),
        Consumer(builder: (context, ref, _) {
          final count = ref.watch(housingComparisonProvider).length;
          return Stack(
            children: [
              IconButton(
                icon: Icon(Icons.compare_arrows_rounded, color: theme.colorScheme.onSurface),
                onPressed: () => context.push('/housing-comparison'),
              ),
              if (count > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                    child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          );
        }),
        const NotificationBadge(module: 'housing'),
        IconButton(
          icon: Icon(Icons.favorite_outline_rounded, color: theme.colorScheme.onSurface),
          onPressed: () => context.push('/saved-housing'),
        ),
        GestureDetector(
          onTap: () => context.push('/profile'),
          child: Consumer(
            builder: (context, ref, _) {
              // Optimization: only watch photo and name
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
                backgroundColor: theme.colorScheme.surfaceVariant,
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
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildPlugDashboardQuickCTA() {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push('/plug-dashboard'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
              child: const Icon(Icons.dashboard_customize_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Plug Dashboard', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: theme.colorScheme.primary)),
                  Text('Manage your vacancies and viewing requests', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildBecomePlugCTA(VerificationApplication? application) {
    final theme = Theme.of(context);
    final user = ref.watch(appUserProvider).valueOrNull;
    final isVerified = user?.isVerified ?? false;
    final hasPendingApp = application?.status == VerificationStatus.pending;
    final isRejected = application?.status == VerificationStatus.rejected;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRejected 
            ? AppColors.error
            : hasPendingApp 
                ? theme.colorScheme.secondary
                : theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            !isVerified ? 'Verification Required' : (isRejected ? 'Application Update' : (hasPendingApp ? 'Application Pending' : 'Join Plug Network')),
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            !isVerified 
                ? 'Verify identity to join.'
                : (isRejected
                    ? 'Application not approved. Tap to review.'
                    : (hasPendingApp
                        ? 'Your application is under review.'
                        : 'List hostels and houses as a trusted Housing Plug.')),
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: hasPendingApp ? null : () => context.push('/become-plug'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: isRejected ? AppColors.error : theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              hasPendingApp ? 'Pending' : (isRejected ? 'Review' : 'Get Started'),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactActionCTA({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return InkWell(
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
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: theme.colorScheme.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => showSearch(
              context: context,
              delegate: HousingSearchDelegate(ref: ref),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: theme.colorScheme.onSurfaceVariant, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _searchController.text.isEmpty 
                          ? 'Search campus, area or hostel...' 
                          : _searchController.text,
                      style: TextStyle(
                        color: _searchController.text.isEmpty 
                            ? theme.colorScheme.onSurfaceVariant.withOpacity(0.6) 
                            : theme.colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w500
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          label: 'Filter housing results',
          button: true,
          child: GestureDetector(
            onTap: () => _showFilterSheet(),
            child: Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: theme.colorScheme.primary.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSearches() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Searches', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant)),
            GestureDetector(
              onTap: _clearRecentSearches,
              child: Text('Clear', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _recentSearches.map((s) => GestureDetector(
            onTap: () {
              _searchController.text = s;
              ref.read(housingLocationFilterProvider.notifier).state = s;
              setState(() {});
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(s, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildActiveFiltersRow() {
    final type = ref.watch(housingTypeFilterProvider);
    final gender = ref.watch(housingGenderFilterProvider);
    final spatialContext = ref.watch(housingSpatialSearchProvider);
    final location = ref.watch(housingLocationFilterProvider);
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (spatialContext != null) 
            _buildFilterChip('Near ${spatialContext.name}', () => ref.read(housingSpatialSearchProvider.notifier).state = null),
          if (location != null && location.isNotEmpty) 
            _buildFilterChip('In $location', () => ref.read(housingLocationFilterProvider.notifier).state = null),
          if (type != null) 
            _buildFilterChip(type.name, () => ref.read(housingTypeFilterProvider.notifier).state = null),
          if (gender != null) 
            _buildFilterChip(gender.name, () => ref.read(housingGenderFilterProvider.notifier).state = null),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: theme.colorScheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 14, color: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildCategoryChip('All', null),
          _buildCategoryChip('Hostels', HousingType.hostel),
          _buildCategoryChip('Bedsitters', HousingType.bedsitter),
          _buildCategoryChip('1 Bedroom', HousingType.oneBedroom),
          _buildCategoryChip('2 Bedroom', HousingType.twoBedroom),
          _buildCategoryChip('Short Stay', HousingType.shortStay),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, HousingType? type) {
    final theme = Theme.of(context);
    final isSelected = ref.watch(housingTypeFilterProvider) == type;
    return GestureDetector(
      onTap: () => ref.read(housingTypeFilterProvider.notifier).state = type,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedSection() {
    final featuredAsync = ref.watch(featuredHousingProvider);
    
    return featuredAsync.when(
      data: (listings) {
        if (listings.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Featured Listings'),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 10),
                itemCount: listings.length,
                itemBuilder: (context, index) => _buildFeaturedCard(listings[index]),
              ),
            ),
          ],
        );
      },
      loading: () => _buildFeaturedSkeleton(),
      error: (e, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildFeaturedCard(HousingListing listing) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => context.push('/housing-detail/${listing.id}', extra: listing),
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              OptimizedImage(
                imageUrl: listing.images.isNotEmpty ? listing.images.first : 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?q=80&w=2070&auto=format&fit=crop',
                width: 260,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('FEATURED', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      listing.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 10, color: Colors.white70),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            listing.location,
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'KES ${listing.rent.toInt()}/mo',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
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

  Widget _buildNearbyAreas() {
    return Consumer(
      builder: (context, ref, _) {
        final theme = Theme.of(context);
        final locations = ref.watch(housingUniqueLocationsProvider);
        if (locations.isEmpty) return const SizedBox.shrink();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Popular Areas', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: locations.length,
                itemBuilder: (context, index) {
                  final loc = locations[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(loc),
                      onPressed: () => ref.read(housingLocationFilterProvider.notifier).state = loc,
                      backgroundColor: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        if (title == 'Recently Added')
          TextButton(
            onPressed: () {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
            },
            child: Text('See All', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w800)),
          ),
      ],
    );
  }

  Widget _buildListingsSliver(String? locationFilter) {
    final filter = _getCurrentFilter();
    final paginatedState = ref.watch(paginatedHousingProvider(filter));
    
    if (paginatedState.isLoading) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildListingsSkeleton(),
        ),
      );
    }

    if (paginatedState.hasError && paginatedState.items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorView(
          error: paginatedState.error,
          onRetry: () => ref.read(paginatedHousingProvider(filter).notifier).retry(),
          isFullPage: false,
        ),
      );
    }

    final listings = paginatedState.items;

    if (listings.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyState(locationFilter));
    }

    final bool isSearch = locationFilter != null && locationFilter.isNotEmpty;

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: _buildSectionTitle(isSearch ? 'Search Results' : 'Recently Added'),
          ),
        ),
        _buildSliverListingsWithAds(listings),
        if (paginatedState.isFetchingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _buildSliverListingsWithAds(List<HousingListing> listings) {
    const int adInterval = AdConfig.housingAdInterval;
    
    // We calculate the total number of items including ads
    int adCount = (listings.length / adInterval).floor();
    if (listings.length >= 5) adCount++; // For the bottom ad
    
    final int totalItemCount = listings.length + adCount;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            // Determine if this is an ad position
            // Logic: Ad every adInterval items, plus one at the end if >= 5 items
            
            // Check if it's the very bottom ad
            if (listings.length >= 5 && index == totalItemCount - 1) {
              return const Padding(
                padding: EdgeInsets.only(top: 12, bottom: 32),
                child: BannerAdWidget(),
              );
            }

            // Check for intermediate ads
            // An ad appears after every adInterval listings
            // Position of ads: adInterval, (2*adInterval + 1), (3*adInterval + 2)...
            
            // Simplified logic for interleaved ads in a builder:
            // Every (adInterval + 1) index is an ad, starting from index = adInterval
            if ((index + 1) % (adInterval + 1) == 0) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: BannerAdWidget(),
              );
            }

            // Calculate the actual listing index
            final int listingIndex = index - (index / (adInterval + 1)).floor();
            if (listingIndex >= listings.length) return null;

            final listing = listings[listingIndex];
            return HousingCard(
              listing: listing,
              onTap: () => context.push('/housing-detail/${listing.id}', extra: listing),
              onFavoriteTap: () {
                final user = ref.read(appUserProvider).valueOrNull;
                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to save listings')));
                  return;
                }
                
                final isSaved = ref.read(savedHousingProvider).valueOrNull?.any((l) => l.id == listing.id) ?? false;
                if (isSaved) {
                  ref.read(housingRepositoryProvider).unsaveListing(user.uid, listing.id);
                } else {
                  ref.read(housingRepositoryProvider).saveListing(user.uid, listing.id);
                }
                ref.invalidate(savedHousingProvider);
              },
            );
          },
          childCount: totalItemCount,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String? locationFilter) {
    return EmptyState(
      title: 'No listings found',
      message: 'Try adjusting your search or filters',
      icon: Icons.house_siding_rounded,
      action: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: () async {
              final user = ref.read(appUserProvider).valueOrNull;
              if (user == null) return;
              
              final search = HousingSavedSearch(
                id: const Uuid().v4(),
                userId: user.uid,
                name: 'Alert: ${locationFilter ?? "Search Result"}',
                location: locationFilter,
                type: ref.read(housingTypeFilterProvider),
                maxRent: ref.read(housingMaxRentFilterProvider),
                genderRestriction: ref.read(housingGenderFilterProvider),
                createdAt: DateTime.now(),
              );
              await ref.read(housingRepositoryProvider).saveHousingSearch(search);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Search alert saved! We will notify you of new matches.')),
                );
              }
            },
            icon: const Icon(Icons.notifications_active_outlined, size: 18),
            label: const Text('Notify Me'),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () {
              _searchController.clear();
              ref.read(housingLocationFilterProvider.notifier).state = null;
              ref.read(housingTypeFilterProvider.notifier).state = null;
              ref.read(housingGenderFilterProvider.notifier).state = null;
              ref.read(browsingScopeProvider.notifier).reset();
              setState(() {});
            },
            child: const Text('Explore All'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedSkeleton() {
    final theme = Theme.of(context);
    return Container(
      height: 240,
      margin: const EdgeInsets.only(top: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 2,
        itemBuilder: (context, index) => Container(
          width: 300,
          margin: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
        ),
      ),
    );
  }

  Widget _buildListingsSkeleton() {
    final theme = Theme.of(context);
    return Column(
      children: List.generate(3, (index) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: SkeletonLoader(width: double.infinity, height: 350, borderRadius: 16, color: theme.colorScheme.surfaceVariant),
      )),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const HousingFilterSheet(),
    );
  }
}

class HousingFilterSheet extends ConsumerWidget {
  const HousingFilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filters', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface)),
                TextButton(
                  onPressed: () {
                    ref.read(housingTypeFilterProvider.notifier).state = null;
                    ref.read(housingGenderFilterProvider.notifier).state = null;
                    ref.read(housingMaxRentFilterProvider.notifier).state = null;
                    ref.read(housingLocationFilterProvider.notifier).state = null;
                    Navigator.pop(context);
                  },
                  child: const Text('Reset All', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSectionHeader(context, 'Area / Neighborhood'),
            const SizedBox(height: 16),
            Consumer(builder: (context, ref, _) {
              final locations = ref.watch(housingUniqueLocationsProvider);
              final selectedLocation = ref.watch(housingLocationFilterProvider);
              
              if (locations.isEmpty) {
                return Text(
                  'Search to filter by area...',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, fontStyle: FontStyle.italic),
                );
              }

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: locations.map((loc) {
                  final isSelected = selectedLocation == loc;
                  return _buildChoiceChip(
                    context,
                    label: loc,
                    isSelected: isSelected,
                    onSelected: (val) => ref.read(housingLocationFilterProvider.notifier).state = val ? loc : null,
                  );
                }).toList(),
              );
            }),
            const SizedBox(height: 32),
            _buildSectionHeader(context, 'Accommodation Type'),
            const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: HousingType.values.map((type) {
              final isSelected = ref.watch(housingTypeFilterProvider) == type;
              return _buildChoiceChip(
                context,
                label: type.name.replaceAll(RegExp(r'(?=[A-Z])'), ' '),
                isSelected: isSelected,
                onSelected: (val) => ref.read(housingTypeFilterProvider.notifier).state = val ? type : null,
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          _buildSectionHeader(context, 'Gender Restriction'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: GenderRestriction.values.map((g) {
              final isSelected = ref.watch(housingGenderFilterProvider) == g;
              return _buildChoiceChip(
                context,
                label: g.name.replaceAll(RegExp(r'(?=[A-Z])'), ' '),
                isSelected: isSelected,
                onSelected: (val) => ref.read(housingGenderFilterProvider.notifier).state = val ? g : null,
              );
            }).toList(),
          ),
          const SizedBox(height: 40),
          _buildNotifyMeButton(context, ref),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Show Results', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

  Widget _buildNotifyMeButton(BuildContext context, WidgetRef ref) {
    final type = ref.watch(housingTypeFilterProvider);
    final gender = ref.watch(housingGenderFilterProvider);
    final location = ref.watch(housingLocationFilterProvider);
    final maxRent = ref.watch(housingMaxRentFilterProvider);
    final user = ref.watch(appUserProvider).valueOrNull;

    final hasFilters = type != null || gender != null || (location != null && location.isNotEmpty) || maxRent != null;
    if (!hasFilters || user == null) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton.icon(
        onPressed: () async {
          final search = HousingSavedSearch(
            id: const Uuid().v4(),
            userId: user.uid,
            name: 'Alert: ${type?.name ?? "Any"} in ${location ?? "Any Area"}',
            location: location,
            type: type,
            maxRent: maxRent,
            genderRestriction: gender,
            createdAt: DateTime.now(),
          );
          await ref.read(housingRepositoryProvider).saveHousingSearch(search);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Search alert saved! We will notify you of matches.')),
            );
            Navigator.pop(context);
          }
        },
        icon: const Icon(Icons.notifications_active_outlined, size: 20),
        label: const Text('Notify me of new matches', style: TextStyle(fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Theme.of(context).colorScheme.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface),
    );
  }

  Widget _buildChoiceChip(BuildContext context, {required String label, required bool isSelected, required Function(bool) onSelected}) {
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      backgroundColor: theme.colorScheme.surface,
      selectedColor: theme.colorScheme.primary,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
          width: 1.5,
        ),
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}

class HousingSearchDelegate extends SearchDelegate<String?> {
  final WidgetRef ref;

  HousingSearchDelegate({required this.ref});

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          onPressed: () => query = '',
          icon: const Icon(Icons.clear_rounded, semanticLabel: 'Clear search'),
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back_rounded, semanticLabel: 'Back'),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) return;
      
      final campusRepo = ref.read(campusRepositoryProvider);
      final campuses = await campusRepo.getCampuses();
      
      // Check if query matches a campus
      final matchedCampus = campuses.where((c) => 
        c.name.toLowerCase().contains(query.toLowerCase()) ||
        c.shortName.toLowerCase().contains(query.toLowerCase()) ||
        c.aliases.any((a) => a.toLowerCase().contains(query.toLowerCase()))
      ).firstOrNull;

      if (matchedCampus != null) {
        ref.read(housingSpatialSearchProvider.notifier).state = SpatialSearchContext(
          id: matchedCampus.id,
          name: matchedCampus.name,
          latitude: matchedCampus.latitude,
          longitude: matchedCampus.longitude,
          isCampus: true,
        );
        ref.read(housingLocationFilterProvider.notifier).state = null;
      } else {
        ref.read(housingSpatialSearchProvider.notifier).state = null;
        ref.read(housingLocationFilterProvider.notifier).state = query;
      }

      if (context.mounted) {
        close(context, query);
      }
    });
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final prefs = ref.watch(sharedPreferencesProvider);
    final recentSearches = prefs.getStringList('recent_housing_searches') ?? [];

    final suggestions = query.isEmpty
        ? recentSearches
        : recentSearches.where((s) => s.toLowerCase().contains(query.toLowerCase())).toList();

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final s = suggestions[index];
        return ListTile(
          leading: const Icon(Icons.history_rounded),
          title: Text(s),
          onTap: () {
            query = s;
            showResults(context);
          },
        );
      },
    );
  }
}
