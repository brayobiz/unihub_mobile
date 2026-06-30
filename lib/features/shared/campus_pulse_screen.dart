import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/features/dashboard/controllers/smart_feed_controller.dart';
import 'package:unihub_mobile/widgets/feed/feed_type.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class CampusPulseScreen extends ConsumerWidget {
  const CampusPulseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pulseAsync = ref.watch(campusPulseProvider);
    final trendingAsync = ref.watch(trendingFeedProvider);
    final recentAsync = ref.watch(recentActivityProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(
          'Campus Pulse',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(smartFeedProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatsGrid(context, pulseAsync),
              const SizedBox(height: 32),
              _sectionHeader(context, 'Trending on Campus'),
              const SizedBox(height: 16),
              _buildTrendingList(context, trendingAsync),
              const SizedBox(height: 32),
              _sectionHeader(context, 'Live Activity Feed'),
              const SizedBox(height: 16),
              _buildRecentActivity(context, recentAsync),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: theme.colorScheme.onSurface,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, AsyncValue<Map<String, int>> pulseAsync) {
    return pulseAsync.when(
      data: (stats) => GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.5,
        children: [
          _StatCard(label: 'Marketplace', value: stats['listings'] ?? 0, icon: Icons.shopping_bag_outlined, color: AppColors.marketplace),
          _StatCard(label: 'Study Notes', value: stats['notes'] ?? 0, icon: Icons.description_outlined, color: AppColors.notes),
          _StatCard(label: 'Campus Gigs', value: stats['gigs'] ?? 0, icon: Icons.work_outline, color: AppColors.gigs),
          _StatCard(label: 'Housing', value: stats['housing'] ?? 0, icon: Icons.home_work_outlined, color: AppColors.housing),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildTrendingList(BuildContext context, AsyncValue<List<SmartFeedItem>> trendingAsync) {
    return trendingAsync.when(
      data: (items) => Column(
        children: items.map((item) => _TrendingPulseItem(
          item: item,
          onTap: () => _handleItemTap(context, item),
        )).toList(),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildRecentActivity(BuildContext context, AsyncValue<List<SmartFeedItem>> recentAsync) {
    return recentAsync.when(
      data: (items) => Column(
        children: items.map((item) => _ActivityPulseItem(
          item: item,
          onTap: () => _handleItemTap(context, item),
        )).toList(),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _handleItemTap(BuildContext context, SmartFeedItem item) {
    if (item.model.type == FeedType.housing) {
      context.push('/housing-detail', extra: item.originalData);
    } else if (item.model.type == FeedType.notes) {
      context.push('/note-detail', extra: item.originalData);
    } else if (item.model.type == FeedType.marketplace) {
      context.push('/marketplace-detail', extra: item.originalData);
    } else if (item.model.type == FeedType.gig) {
      context.push('/gig-detail', extra: item.originalData);
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendingPulseItem extends StatelessWidget {
  final SmartFeedItem item;
  final VoidCallback onTap;
  const _TrendingPulseItem({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_fire_department_rounded, color: AppColors.error, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.model.title,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    item.model.subtitle,
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _ActivityPulseItem extends StatelessWidget {
  final SmartFeedItem item;
  final VoidCallback onTap;
  const _ActivityPulseItem({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createdAt = item.originalData?.createdAt as DateTime?;
    final timeStr = createdAt != null ? DateFormat('HH:mm').format(createdAt) : '--:--';

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Container(
                  width: 2,
                  height: 40,
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.model.title,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Posted in ${item.model.type.name.capitalize()}',
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
