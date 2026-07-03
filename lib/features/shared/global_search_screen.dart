import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/features/dashboard/controllers/smart_feed_controller.dart';
import 'package:unihub_mobile/models/feed_type.dart';
import 'package:go_router/go_router.dart';
import 'package:unihub_mobile/core/utils/category_utils.dart';
import 'package:unihub_mobile/features/campus_filter/presentation/widgets/campus_filter_selector.dart';
import 'package:unihub_mobile/features/campus_filter/shared/providers.dart';
import 'package:unihub_mobile/features/campus_filter/domain/models/browsing_scope.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allFeedAsync = ref.watch(smartFeedProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
        titleSpacing: 0,
        title: Container(
          height: 44,
          margin: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Search marketplace, housing, notes...',
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.onSurfaceVariant, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (value) {
              setState(() => _query = value.trim().toLowerCase());
            },
          ),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
              onPressed: () {
                _searchController.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: CampusFilterSelector(),
          ),
          Expanded(
            child: _query.isEmpty 
                ? _buildSearchSuggestions(context)
                : allFeedAsync.when(
                    data: (items) {
                      final filtered = items.where((item) {
                        return item.model.title.toLowerCase().contains(_query) ||
                               item.model.subtitle.toLowerCase().contains(_query);
                      }).toList();

                      if (filtered.isEmpty) {
                        return _buildNoResults(context);
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return _SearchItemCard(
                            item: item,
                            onTap: () => _handleItemTap(context, item),
                          );
                        },
                      );
                    },
                    loading: () => Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
                    error: (err, _) => Center(child: Text('Error: $err')),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSuggestions(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Try searching for',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SuggestionChip(label: 'Calculus Notes', icon: Icons.description_rounded, color: AppColors.notes, onTap: () => _setQuery('Calculus')),
              _SuggestionChip(label: 'iPhone 13', icon: Icons.smartphone_rounded, color: AppColors.marketplace, onTap: () => _setQuery('iPhone')),
              _SuggestionChip(label: 'Single Rooms', icon: Icons.home_rounded, color: AppColors.housing, onTap: () => _setQuery('Single')),
              _SuggestionChip(label: 'Graphic Design', icon: Icons.palette_rounded, color: AppColors.gigs, onTap: () => _setQuery('Design')),
            ],
          ),
          const SizedBox(height: 40),
          _SearchCategoryRow(
            title: 'Marketplace',
            subtitle: 'Find gadgets, books, and more',
            icon: Icons.shopping_bag_outlined,
            color: AppColors.marketplace,
          ),
          _SearchCategoryRow(
            title: 'Campus Housing',
            subtitle: 'Rentals, roommates and hostels',
            icon: Icons.home_work_outlined,
            color: AppColors.housing,
          ),
          _SearchCategoryRow(
            title: 'Study Materials',
            subtitle: 'Notes, past papers and guides',
            icon: Icons.menu_book_rounded,
            color: AppColors.notes,
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults(BuildContext context) {
    final theme = Theme.of(context);
    final isCampusFiltered = ref.read(browsingScopeProvider).type != BrowsingScopeType.all;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.search_off_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 24),
          Text(
            'No results for "$_query"',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try checking for typos or searching \nfor something else.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          if (isCampusFiltered) ...[
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                ref.read(browsingScopeProvider.notifier).reset();
              },
              icon: const Icon(Icons.public, size: 18),
              label: const Text('Search All Campuses'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _setQuery(String q) {
    _searchController.text = q;
    setState(() => _query = q.toLowerCase());
  }

  void _handleItemTap(BuildContext context, SmartFeedItem item) {
    if (item.model.type == FeedType.housing) {
      context.push('/housing-detail', extra: item.originalData);
    } else if (item.model.type == FeedType.notes) {
      context.push('/note-detail', extra: item.originalData);
    } else if (item.model.type == FeedType.marketplace) {
      context.push('/listing-detail', extra: item.originalData);
    } else if (item.model.type == FeedType.gig) {
      context.push('/gig-detail', extra: item.originalData);
    }
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchCategoryRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SearchCategoryRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
        ],
      ),
    );
  }
}

class _SearchItemCard extends StatelessWidget {
  final SmartFeedItem item;
  final VoidCallback onTap;

  const _SearchItemCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.all(12),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: CategoryUtils.getColor(item.model.type).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              CategoryUtils.getIcon(item.model.type),
              color: CategoryUtils.getColor(item.model.type),
            ),
          ),
          title: Text(
            item.model.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            item.model.subtitle,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}
