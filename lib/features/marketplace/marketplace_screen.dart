import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth/shared/providers.dart';
import 'domain/models/marketplace_categories.dart';
import 'presentation/controllers/marketplace_controller.dart';
import 'domain/models/listing.dart';
import 'shared/providers.dart';
import 'domain/models/listing_filter.dart';
import 'presentation/widgets/marketplace_card.dart';
import '../../core/utils/debouncer.dart';
import '../../widgets/skeleton_loader.dart';

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  final _searchDebouncer = Debouncer(milliseconds: 500);

  @override
  void dispose() {
    _searchDebouncer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(scoredListingsProvider);
    final filterState = ref.watch(marketplaceControllerProvider);
    final controller = ref.read(marketplaceControllerProvider.notifier);

    final List<String> categories = MarketplaceCategories.mainFilters;

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-listing'),
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('Post Listing'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(listingsProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverAppBar(
              pinned: true,
              floating: true,
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
                IconButton(
                  onPressed: () => _showFilterSheet(context, filterState, controller), 
                  icon: const Icon(Icons.tune_rounded, color: Colors.black),
                ),
              ],
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
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
