import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unihub_mobile/core/location/controllers/campus_maps_controller.dart';
import 'package:unihub_mobile/core/location/repositories/campus_repository.dart';
import 'package:go_router/go_router.dart';
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
import 'package:unihub_mobile/features/campus_filter/domain/models/browsing_scope.dart';
import 'package:unihub_mobile/features/ads/ads_module.dart';
import 'package:unihub_mobile/core/constants/campus_constants.dart';

import '../controllers/paginated_housing_controller.dart';
import '../../../../core/models/paginated_state.dart';

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

  Future<void> _saveSearch(String query) async {
    if (query.isEmpty) return;
    final prefs = ref.read(sharedPreferencesProvider);
    final searches = prefs.getStringList('recent_housing_searches') ?? <String>[];
    if (!searches.contains(query)) {
      searches.insert(0, query);
      if (searches.length > 5) searches.removeLast();
      await prefs.setStringList('recent_housing_searches', searches);
      setState(() => _recentSearches = searches);
    }
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
    final user = ref.watch(appUserProvider).valueOrNull;
    final isVerifiedPlug = user?.verifiedRoles.contains('housePlug') ?? false;
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
      drawer: AppDrawer(),
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchBar(),
                    const SizedBox(height: 16),
                    const CampusFilterSelector(),
                    if (_searchController.text.isEmpty && _recentSearches.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildRecentSearches(),
                    ],
                    const SizedBox(height: 24),
                    if (!isVerifiedPlug) ...[
                      applicationAsync.when(
                        data: (application) => _buildBecomePlugCTA(application),
                        loading: () => SkeletonLoader(width: double.infinity, height: 150, borderRadius: 24, color: theme.colorScheme.surfaceVariant),
                        error: (_, __) => _buildBecomePlugCTA(null),
                      ),
                      const SizedBox(height: 16),
                      _buildReportVacancyCTA(),
                      const SizedBox(height: 16),
                      _buildRoommateFinderCTA(),
                      const SizedBox(height: 24),
                    ],
                    _buildCategorySelector(),
                    if (hasActiveFilters) ...[
                      const SizedBox(height: 16),
                      _buildActiveFiltersRow(),
                    ],
                    const SizedBox(height: 24),
                    if (locationFilter == null || locationFilter.isEmpty) ...[
                      _buildNearbyAreas(),
                      const SizedBox(height: 24),
                      _buildFeaturedSection(),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
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
      floatingActionButton: isVerifiedPlug ? FloatingActionButton.extended(
        heroTag: 'housing_fab',
        onPressed: () => context.push('/add-housing'),
        backgroundColor: theme.colorScheme.primary,
        elevation: 4,
        icon: const Icon(Icons.add_home_work_rounded, color: Colors.white),
        label: const Text('Create Vacancy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
      ) : null,
    );
  }

  Widget _buildSliverAppBar(bool isPlug) {
    final theme = Theme.of(context);
    return SliverAppBar(
      expandedHeight: 100,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
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
              final userProfile = ref.watch(appUserProvider).valueOrNull;
              return CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.surfaceVariant,
                backgroundImage: userProfile?.photoUrl != null ? NetworkImage(userProfile!.photoUrl!) : null,
                child: userProfile?.photoUrl == null 
                    ? Text(
                        userProfile?.fullName.isNotEmpty == true ? userProfile!.fullName[0].toUpperCase() : 'U',
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

  Widget _buildBecomePlugCTA(VerificationApplication? application) {
    final theme = Theme.of(context);
    final user = ref.watch(appUserProvider).valueOrNull;
    final isVerified = user?.isVerified ?? false;
    final hasPendingApp = application?.status == VerificationStatus.pending;
    final isRejected = application?.status == VerificationStatus.rejected;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isRejected 
              ? [AppColors.error, AppColors.error.withOpacity(0.8)]
              : hasPendingApp 
                  ? [theme.colorScheme.secondary, theme.colorScheme.secondary.withOpacity(0.8)]
                  : [theme.colorScheme.primary, const Color(0xFF19D3C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isRejected ? AppColors.error : theme.colorScheme.primary).withOpacity(0.2), 
            blurRadius: 20, 
            offset: const Offset(0, 10)
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            !isVerified ? 'Verification Required' : (isRejected ? 'Application Update' : (hasPendingApp ? 'Application Pending' : 'Helping students find houses?')),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            !isVerified 
                ? 'You must verify your platform identity before joining the Plug Network.'
                : (isRejected
                    ? 'Your application was not approved. You can review our guidelines and try again.'
                    : (hasPendingApp
                        ? 'Your application to join the Plug Network is currently under review. We\'ll notify you soon.'
                        : 'List hostels and houses, manage enquiries and build your reputation as a trusted Housing Plug.')),
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: hasPendingApp ? null : () => context.push('/become-plug'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              disabledBackgroundColor: Colors.white.withOpacity(0.8),
              foregroundColor: isRejected ? AppColors.error : theme.colorScheme.primary,
              disabledForegroundColor: theme.colorScheme.primary.withOpacity(0.6),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasPendingApp) ...[
                  const Icon(Icons.hourglass_empty_rounded, size: 16),
                  const SizedBox(width: 10),
                ],
                Text(
                  hasPendingApp ? 'Application Under Review' : (isRejected ? 'Review Application' : 'Become a Housing Plug'),
                  style: const TextStyle(fontWeight: FontWeight.w900)
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportVacancyCTA() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.add_business_rounded, color: theme.colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Know an available room?',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  'Report it here and help a fellow student find a home.',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/submit-vacancy'),
            child: Text('Report', style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildRoommateFinderCTA() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.people_outline_rounded, color: theme.colorScheme.secondary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Looking for a Roommate?',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  'Find fellow students to share housing costs with.',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/roommates'),
            child: Text('Find', style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.secondary)),
          ),
        ],
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
        margin: const EdgeInsets.only(right: 14),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            width: 1.5,
          ),
          boxShadow: isSelected ? [
            BoxShadow(color: theme.colorScheme.primary.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
            fontSize: 13,
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
        width: 300,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              OptimizedImage(
                imageUrl: listing.images.isNotEmpty ? listing.images.first : 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?q=80&w=2070&auto=format&fit=crop',
                width: 300,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                    stops: const [0.5, 1.0],
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('FEATURED', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                    ),
                    if (listing.videoUrl != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_circle_fill_rounded, color: theme.colorScheme.primary, size: 10),
                            const SizedBox(width: 4),
                            Text('VIRTUAL TOUR', style: TextStyle(color: theme.colorScheme.primary, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      listing.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 12, color: Colors.white70),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${CampusConstants.getDisplayName(listing.university)} • ${listing.location}',
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (listing.previousRent != null && listing.previousRent! > listing.rent)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              'KES ${listing.previousRent!.toInt()}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                decoration: TextDecoration.lineThrough,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        Text(
                          'KES ${listing.rent.toInt()}/mo',
                          style: TextStyle(
                            color: (listing.previousRent != null && listing.previousRent! > listing.rent)
                                ? AppColors.success
                                : AppColors.success, // Keeping it green for featured? Actually featured was already success color.
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ],
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
    final theme = Theme.of(context);
    return Consumer(
      builder: (context, ref, _) {
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
    final theme = Theme.of(context);
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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 64, color: AppColors.error),
                const SizedBox(height: 24),
                Text(
                  'Connection lost',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'We couldn\'t load the properties. Please check your network and try again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => ref.read(paginatedHousingProvider(filter).notifier).retry(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
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
            
            int listingsBefore = 0;
            int currentPos = 0;
            
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
    final theme = Theme.of(context);

    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.house_siding_rounded, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
          ),
          const SizedBox(height: 24),
          Text('No listings found', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text('Try adjusting your search or filters', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
          const SizedBox(height: 24),
          Row(
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
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
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
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Explore All'),
              ),
            ],
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

      close(context, query);
    });
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final theme = Theme.of(context);
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
