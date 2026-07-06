import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/core/widgets/optimized_image.dart';
import '../../domain/models/housing_listing.dart';
import '../../shared/providers.dart';
import '../../../auth/shared/providers.dart';

class HousingComparisonScreen extends ConsumerWidget {
  const HousingComparisonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comparisonList = ref.watch(housingComparisonProvider);
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: 'KES ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Compare Properties', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          if (comparisonList.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(housingComparisonProvider.notifier).state = [],
              child: const Text('Clear All', style: TextStyle(color: AppColors.error)),
            ),
        ],
      ),
      body: comparisonList.isEmpty
          ? _buildEmptyState(context)
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabelsColumn(context),
                      ...comparisonList.map((listing) => _buildPropertyColumn(context, ref, listing, currencyFormat)),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.compare_arrows_rounded, size: 64, color: theme.colorScheme.primary.withOpacity(0.2)),
          const SizedBox(height: 24),
          const Text('No properties selected for comparison', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Add up to 3 properties to compare details.'),
        ],
      ),
    );
  }

  Widget _buildLabelsColumn(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.only(top: 180, left: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _labelCell('Price'),
          _labelCell('Type'),
          _labelCell('Freshness'),
          _labelCell('Distance'),
          _labelCell('Plug Trust'),
          _labelCell('Deposit'),
          _labelCell('Gender'),
          _labelCell('Furnished'),
          _labelCell('Amenities'),
        ],
      ),
    );
  }

  Widget _labelCell(String text) {
    return Container(
      height: 60,
      alignment: Alignment.centerLeft,
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
    );
  }

  Widget _buildPropertyColumn(BuildContext context, WidgetRef ref, HousingListing listing, NumberFormat currencyFormat) {
    final theme = Theme.of(context);
    return Container(
      width: 200,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: OptimizedImage(imageUrl: listing.images.first, height: 100, width: 180, fit: BoxFit.cover),
                ),
                const SizedBox(height: 12),
                Text(listing.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2, textAlign: TextAlign.center),
              ],
            ),
          ),
          _valueCell(currencyFormat.format(listing.rent), isPrimary: true),
          _valueCell(listing.type.name),
          _freshnessCell(listing.lastVerifiedAt),
          _valueCell(listing.distance),
          _trustScoreCell(listing.plugId, ref),
          _valueCell(currencyFormat.format(listing.deposit)),
          _valueCell(listing.genderRestriction.name),
          _valueCell(listing.isFurnished ? 'Yes' : 'No'),
          _amenitiesCell(listing.amenities),
        ],
      ),
    );
  }

  Widget _freshnessCell(DateTime lastVerified) {
    final diff = DateTime.now().difference(lastVerified);
    final isFresh = diff.inHours < 24;
    return Container(
      height: 60,
      alignment: Alignment.center,
      child: Text(
        isFresh ? 'Verified Today' : '${diff.inDays}d ago',
        style: TextStyle(
          color: isFresh ? AppColors.success : Colors.grey,
          fontWeight: isFresh ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _valueCell(String text, {bool isPrimary = false}) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      child: Text(
        text, 
        style: TextStyle(
          fontWeight: isPrimary ? FontWeight.w900 : FontWeight.w600, 
          color: isPrimary ? AppColors.primary : null,
          fontSize: 13,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _trustScoreCell(String plugId, WidgetRef ref) {
    final plugAsync = ref.watch(userByIdProvider(plugId));
    return Container(
      height: 60,
      alignment: Alignment.center,
      child: plugAsync.when(
        data: (plug) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '${plug?.displayTrustScore.toInt() ?? 70}%',
            style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w900, fontSize: 13),
          ),
        ),
        loading: () => const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        error: (_, __) => const Text('N/A'),
      ),
    );
  }

  Widget _amenitiesCell(List<String> amenities) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: amenities.take(3).map((a) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
          child: Text(a, style: const TextStyle(fontSize: 9)),
        )).toList(),
      ),
    );
  }
}
