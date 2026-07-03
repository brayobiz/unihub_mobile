import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controllers/saved_searches_controller.dart';
import '../controllers/marketplace_controller.dart';
import '../../domain/models/saved_search.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';

class SavedSearchesScreen extends ConsumerWidget {
  const SavedSearchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final searchesAsync = ref.watch(savedSearchesProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Saved Searches'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: searchesAsync.when(
        data: (searches) {
          if (searches.isEmpty) {
            return _buildEmptyState(context);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: searches.length,
            itemBuilder: (context, index) {
              return _SavedSearchCard(search: searches[index]);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 80, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 20),
          Text(
            'No saved searches yet',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Save your searches to get notified when new items match your criteria.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.pop(),
            child: const Text('Go to Marketplace'),
          ),
        ],
      ),
    );
  }
}

class _SavedSearchCard extends ConsumerWidget {
  final SavedSearch search;

  const _SavedSearchCard({required this.search});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filter = search.filter;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: InkWell(
        onTap: () {
          ref.read(marketplaceControllerProvider.notifier).applyFilter(filter);
          context.pop(); // Go back to marketplace with this filter applied
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      search.name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Switch.adaptive(
                    value: search.notificationsEnabled,
                    onChanged: (val) {
                      ref.read(savedSearchesControllerProvider.notifier).toggleNotifications(search.id, val);
                    },
                    activeColor: AppColors.secondary,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildFilterChips(context),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Saved on ${search.createdAt.day}/${search.createdAt.month}/${search.createdAt.year}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => _confirmDelete(context, ref),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final filter = search.filter;
    final List<String> chips = [];

    if (filter.searchQuery.isNotEmpty) chips.add('"${filter.searchQuery}"');
    if (filter.selectedCategory != null) chips.add(filter.selectedCategory!);
    if (filter.priceRange != null) {
      chips.add('KES ${filter.priceRange!.start.toInt()} - ${filter.priceRange!.end.toInt()}');
    }
    for (var condition in filter.selectedConditions) {
      chips.add(condition.replaceFirst('newCondition', 'New'));
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: chips.map((chip) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          chip,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
        ),
      )).toList(),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Saved Search?'),
        content: const Text('You will no longer receive notifications for this search.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(savedSearchesControllerProvider.notifier).deleteSearch(search.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
