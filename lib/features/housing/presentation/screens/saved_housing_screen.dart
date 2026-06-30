import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../shared/providers.dart';
import '../widgets/housing_card.dart';

class SavedHousingScreen extends ConsumerWidget {
  const SavedHousingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final savedListingsAsync = ref.watch(savedHousingProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text('Saved Housing', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: savedListingsAsync.when(
        data: (listings) => listings.isEmpty
            ? _buildEmptyState(context)
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: listings.length,
                itemBuilder: (context, index) => HousingCard(
                  listing: listings[index],
                  onTap: () => context.push('/housing-detail', extra: listings[index]),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: theme.colorScheme.surfaceVariant.withOpacity(0.3), shape: BoxShape.circle),
            child: Icon(Icons.favorite_rounded, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
          ),
          const SizedBox(height: 24),
          Text('Your wishlist is empty', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text('Save properties to keep track of them here', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => context.pop(),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Start Browsing', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
