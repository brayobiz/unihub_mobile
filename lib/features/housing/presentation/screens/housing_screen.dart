import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
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

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).valueOrNull;
    final isVerifiedPlug = user?.verifiedRoles.contains('housePlug') ?? false;
    final applicationAsync = ref.watch(applicationByRoleProvider(ProfessionalRole.housePlug));
    
    final locationFilter = ref.watch(housingLocationFilterProvider);
    final hasActiveFilters = ref.watch(housingTypeFilterProvider) != null || 
                            ref.watch(housingGenderFilterProvider) != null ||
                            ref.watch(housingMaxRentFilterProvider) != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(topHousingProvider);
          ref.invalidate(featuredHousingProvider);
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
          _buildSliverAppBar(isVerifiedPlug),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(),
                  if (_searchController.text.isEmpty && _recentSearches.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildRecentSearches(),
                  ],
                  const SizedBox(height: 24),
                  if (!isVerifiedPlug) ...[
                    applicationAsync.when(
                      data: (application) => _buildBecomePlugCTA(application),
                      loading: () => const SkeletonLoader(width: double.infinity, height: 150, borderRadius: 24),
                      error: (_, __) => _buildBecomePlugCTA(null),
                    ),
                    const SizedBox(height: 16),
                    _buildReportVacancyCTA(),
                    const SizedBox(height: 32),
                  ],
                  _buildCategorySelector(),
                  if (hasActiveFilters) ...[
                    const SizedBox(height: 16),
                    _buildActiveFiltersRow(),
                  ],
                  const SizedBox(height: 24),
                  if (locationFilter == null || locationFilter.isEmpty) ...[
                    _buildFeaturedSection(),
                    const SizedBox(height: 32),
                  ],
                  _buildSectionTitle(locationFilter != null && locationFilter.isNotEmpty 
                      ? 'Search Results' 
                      : 'Recently Added'),
                  const SizedBox(height: 16),
                  _buildListingsList(),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
      floatingActionButton: isVerifiedPlug ? FloatingActionButton.extended(
        onPressed: () => context.push('/add-housing'),
        backgroundColor: const Color(0xFF1677F2),
        elevation: 4,
        icon: const Icon(Icons.add_home_work_rounded, color: Colors.white),
        label: const Text('List Property', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
      ) : null,
    );
  }

  Widget _buildSliverAppBar(bool isPlug) {
    return SliverAppBar(
      expandedHeight: 100,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        centerTitle: false,
        title: Text(
          'UniHub Housing',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF1A1C1E),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      actions: [
        const NotificationBadge(),
        if (!isPlug)
          IconButton(
            icon: const Icon(Icons.add_business_outlined, color: Color(0xFF1A1C1E)),
            onPressed: () => context.push('/submit-vacancy'),
            tooltip: 'Report a Vacancy',
          ),
        IconButton(
          icon: const Icon(Icons.favorite_outline_rounded, color: Color(0xFF1A1C1E)),
          onPressed: () => context.push('/saved-housing'),
        ),
        if (isPlug)
          IconButton(
            icon: const Icon(Icons.dashboard_customize_outlined, color: Color(0xFF1A1C1E)),
            onPressed: () => context.push('/plug-dashboard'),
          ),
      ],
    );
  }

  Widget _buildBecomePlugCTA(VerificationApplication? application) {
    final user = ref.watch(appUserProvider).valueOrNull;
    final isVerified = user?.isVerified ?? false;
    final hasPendingApp = application?.status == VerificationStatus.pending;
    final isRejected = application?.status == VerificationStatus.rejected;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isRejected 
              ? [const Color(0xFFEF4444), const Color(0xFF991B1B)]
              : hasPendingApp 
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [const Color(0xFF1677F2), const Color(0xFF19D3C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isRejected ? Colors.red : const Color(0xFF1677F2)).withOpacity(0.2), 
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
              foregroundColor: isRejected ? Colors.red : const Color(0xFF1677F2),
              disabledForegroundColor: const Color(0xFF1677F2).withOpacity(0.6),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_business_rounded, color: Color(0xFF1677F2), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Know an available room?',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1A1C1E)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Report it here and help a fellow student find a home.',
                  style: TextStyle(color: const Color(0xFF64748B), fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/submit-vacancy'),
            child: const Text('Report', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search campus, area or hostel...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    onChanged: (value) {
                      setState(() {});
                      if (value.isEmpty) {
                        ref.read(housingLocationFilterProvider.notifier).state = null;
                      }
                    },
                    onSubmitted: (value) {
                      ref.read(housingLocationFilterProvider.notifier).state = value;
                      _saveSearch(value);
                    },
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(housingLocationFilterProvider.notifier).state = null;
                      setState(() {});
                    },
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => _showFilterSheet(),
          child: Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF1677F2),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: const Color(0xFF1677F2).withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSearches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Searches', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
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
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history_rounded, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(s, style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
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
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (type != null) _buildFilterChip(type.name, () => ref.read(housingTypeFilterProvider.notifier).state = null),
          if (gender != null) _buildFilterChip(gender.name, () => ref.read(housingGenderFilterProvider.notifier).state = null),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1677F2).withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1677F2).withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF1677F2), fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF1677F2)),
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
    final isSelected = ref.watch(housingTypeFilterProvider) == type;
    return GestureDetector(
      onTap: () => ref.read(housingTypeFilterProvider.notifier).state = type,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1677F2) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF1677F2) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          boxShadow: isSelected ? [
            BoxShadow(color: const Color(0xFF1677F2).withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF475569),
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
            const SizedBox(height: 16),
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
    return GestureDetector(
      onTap: () => context.push('/housing-detail', extra: listing),
      child: Container(
        width: 300,
        margin: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
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
                        color: const Color(0xFF1677F2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('FEATURED', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                    ),
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
                            '${listing.university} • ${listing.location}',
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'KES ${listing.rent.toInt()}/mo',
                      style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 18),
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

  Widget _buildSectionTitle(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1C1E),
          ),
        ),
        if (title == 'Recently Added')
          TextButton(
            onPressed: () {},
            child: const Text('See All', style: TextStyle(color: Color(0xFF1677F2), fontWeight: FontWeight.w800)),
          ),
      ],
    );
  }

  Widget _buildListingsList() {
    final listingsAsync = ref.watch(topHousingProvider);
    
    return listingsAsync.when(
      data: (listings) => listings.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: listings.length,
              itemBuilder: (context, index) => HousingCard(
                listing: listings[index],
                onTap: () => context.push('/housing-detail', extra: listings[index]),
              ),
            ),
      loading: () => _buildListingsSkeleton(),
      error: (e, _) => Center(child: Text('Error loading listings: $e')),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.house_siding_rounded, size: 64, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 24),
          const Text('No listings found', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF1A1C1E))),
          const SizedBox(height: 8),
          const Text('Try adjusting your search or filters', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () {
              _searchController.clear();
              ref.read(housingLocationFilterProvider.notifier).state = null;
              ref.read(housingTypeFilterProvider.notifier).state = null;
              ref.read(housingGenderFilterProvider.notifier).state = null;
              setState(() {});
            },
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Clear all filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedSkeleton() {
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
        ),
      ),
    );
  }

  Widget _buildListingsSkeleton() {
    return Column(
      children: List.generate(3, (index) => const Padding(
        padding: EdgeInsets.only(bottom: 20),
        child: SkeletonLoader(width: double.infinity, height: 350, borderRadius: 24),
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Filters', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E))),
              TextButton(
                onPressed: () {
                  ref.read(housingTypeFilterProvider.notifier).state = null;
                  ref.read(housingGenderFilterProvider.notifier).state = null;
                  ref.read(housingMaxRentFilterProvider.notifier).state = null;
                  Navigator.pop(context);
                },
                child: const Text('Reset All', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('Accommodation Type'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: HousingType.values.map((type) {
              final isSelected = ref.watch(housingTypeFilterProvider) == type;
              return _buildChoiceChip(
                label: type.name.replaceAll(RegExp(r'(?=[A-Z])'), ' '),
                isSelected: isSelected,
                onSelected: (val) => ref.read(housingTypeFilterProvider.notifier).state = val ? type : null,
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('Gender Restriction'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: GenderRestriction.values.map((g) {
              final isSelected = ref.watch(housingGenderFilterProvider) == g;
              return _buildChoiceChip(
                label: g.name.replaceAll(RegExp(r'(?=[A-Z])'), ' '),
                isSelected: isSelected,
                onSelected: (val) => ref.read(housingGenderFilterProvider.notifier).state = val ? g : null,
              );
            }).toList(),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1677F2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              child: const Text('Show Results', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A1C1E)),
    );
  }

  Widget _buildChoiceChip({required String label, required bool isSelected, required Function(bool) onSelected}) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF475569),
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF1677F2),
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? const Color(0xFF1677F2) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}
