import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unihub_mobile/features/trust/domain/models/professional_role.dart';
import 'package:unihub_mobile/features/trust/domain/models/verification_application.dart';
import 'package:unihub_mobile/features/trust/presentation/providers/trust_providers.dart';
import '../auth/shared/providers.dart';
import 'domain/models/marketplace_categories.dart';
import 'presentation/controllers/marketplace_controller.dart';
import 'shared/providers.dart';
import 'domain/models/listing_filter.dart';
import 'presentation/widgets/marketplace_card.dart';
import '../../core/utils/debouncer.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Marketplace',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          const NotificationBadge(),
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
    final listingsAsync = ref.watch(scoredListingsProvider);
    final filterState = ref.watch(marketplaceControllerProvider);
    final controller = ref.read(marketplaceControllerProvider.notifier);
    const List<String> categories = MarketplaceCategories.mainFilters;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(listingsProvider);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Hero(
                          tag: 'marketplace_search',
                          child: Material(
                            color: Colors.transparent,
                            child: TextField(
                              onChanged: (value) {
                                _searchDebouncer.run(() {
                                  controller.setSearchQuery(value);
                                });
                              },
                              decoration: InputDecoration(
                                hintText: 'What are you looking for?',
                                hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey.shade400),
                                prefixIcon: const Icon(Icons.search_rounded, color: Colors.indigo),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(color: Colors.grey.shade100),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(color: Colors.grey.shade100),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(color: Colors.indigo, width: 1.5),
                                ),
                              ),
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
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
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
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '🔥 Trending Items',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          listingsAsync.when(
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
                      ],
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
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
                    addAutomaticKeepAlives: true,
                  ),
                ),
              );
            },
            loading: () => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
          ),
        ],
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
    final isPending = app?.status == VerificationStatus.pending;
    final isRejected = app?.status == VerificationStatus.rejected;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isRejected ? Colors.red.shade50 : Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isRejected ? Colors.red.shade100 : Colors.indigo.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isRejected ? Icons.error_outline : (isPending ? Icons.access_time : Icons.verified_user_outlined),
                color: isRejected ? Colors.red : Colors.indigo,
              ),
              const SizedBox(width: 12),
              Text(
                !isVerified ? 'Verification Required' : (isRejected ? 'Application Rejected' : (isPending ? 'Review Pending' : 'Apply as Trusted Seller')),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isRejected ? Colors.red.shade900 : Colors.indigo.shade900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            !isVerified 
                ? 'You must verify your platform identity before applying for a seller badge.'
                : (isRejected
                    ? 'Your seller application was not approved. Review the guidelines and try again.'
                    : (isPending 
                        ? 'Our team is reviewing your application. You\'ll get a badge once approved.'
                        : 'Get a verification badge next to your items and build trust with buyers.')),
            style: TextStyle(
              fontSize: 13,
              color: isRejected ? Colors.red.shade700 : Colors.indigo.shade700,
            ),
          ),
          if (!isPending) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.push(isVerified ? '/verify-professional/seller' : '/trust-center'),
                style: FilledButton.styleFrom(
                  backgroundColor: isRejected ? Colors.red : Colors.indigo,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(!isVerified ? 'Verify Identity' : (isRejected ? 'Re-apply Now' : 'Apply Now')),
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
              const SizedBox(height: 32),
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
