import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/listing.dart';
import '../../domain/repositories/marketplace_repository.dart';
import '../../shared/providers.dart';
import '../../domain/models/listing_filter.dart';
import '../widgets/marketplace_card.dart';
import '../../../../widgets/skeleton_loader.dart';

class CategoryDiscoveryScreen extends ConsumerWidget {
  final String category;

  const CategoryDiscoveryScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isAll = category == 'All';

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    context,
                    title: isAll ? 'Most Popular Items' : 'Trending $category',
                    provider: listingsProvider(ListingFilter(
                      selectedCategory: isAll ? null : category,
                      sortBy: ListingSortType.mostViewed,
                      itemsLimit: 10,
                    )),
                  ),
                  _buildSection(
                    context,
                    title: 'Best Deals',
                    provider: listingsProvider(ListingFilter(
                      selectedCategory: isAll ? null : category,
                      sortBy: ListingSortType.lowestPrice,
                      itemsLimit: 10,
                    )),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isAll ? 'Everything on Marketplace' : 'All $category',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildAllListingsGrid(ref, isAll),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    final theme = Theme.of(context);
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      elevation: 0,
      backgroundColor: theme.colorScheme.surface,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          category == 'All' ? 'Discover All' : category,
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 60, bottom: 16),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required ProviderListenable<AsyncValue<List<Listing>>> provider,
  }) {
    final theme = Theme.of(context);
    return Consumer(
      builder: (context, ref, child) {
        final asyncListings = ref.watch(provider);
        return asyncListings.when(
          data: (listings) {
            if (listings.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 240,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: listings.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: SizedBox(
                        width: 170,
                        child: MarketplaceCard(
                          listing: listings[index], 
                          index: index,
                          heroTag: 'hero_cat_${title.replaceAll(' ', '_').toLowerCase()}_${listings[index].id}',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => SkeletonLoader(width: double.infinity, height: 200, color: theme.colorScheme.surfaceContainerHighest),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildAllListingsGrid(WidgetRef ref, bool isAll) {
    final listingsAsync = ref.watch(listingsProvider(ListingFilter(
      selectedCategory: isAll ? null : category,
    )));

    return listingsAsync.when(
      data: (listings) {
        if (listings.isEmpty) {
          return const SliverFillRemaining(
            child: Center(child: Text('No items found')),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => MarketplaceCard(
                listing: listings[index], 
                index: index,
                heroTag: 'hero_cat_grid_${listings[index].id}',
              ),
              childCount: listings.length,
            ),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
      error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
    );
  }
}
