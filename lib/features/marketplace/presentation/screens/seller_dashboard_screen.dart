import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/listing.dart';
import '../../domain/models/seller_stats.dart';
import '../controllers/seller_dashboard_controller.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';

class SellerDashboardScreen extends ConsumerWidget {
  const SellerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).valueOrNull;
    if (user == null) return const Scaffold(body: Center(child: Text('Please login')));

    final statsAsync = ref.watch(sellerStatsProvider(user.uid));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Seller Dashboard'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(sellerStatsProvider(user.uid).notifier).refresh(),
          ),
        ],
      ),
      body: statsAsync.when(
        data: (stats) => _DashboardContent(stats: stats),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading dashboard: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-listing'),
        label: const Text('Add Listing'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final SellerStats stats;

  const _DashboardContent({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return RefreshIndicator(
      onRefresh: () async {
        // Handled by the refresh button too, but good for UX
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildWelcomeSection(context),
          const SizedBox(height: 24),
          _buildMetricsGrid(context),
          const SizedBox(height: 24),
          _buildIntelligenceSection(context),
          const SizedBox(height: 24),
          _buildPerformanceSection(context),
          const SizedBox(height: 24),
          _buildQuickActions(context),
          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildIntelligenceSection(BuildContext context) {
    final theme = Theme.of(context);
    final insights = _generateInsights(stats);
    final suggestions = _generateSuggestions(stats);

    if (insights.isEmpty && suggestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Seller Intelligence',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (insights.isNotEmpty)
          ...insights.map((i) => _InsightCard(insight: i)),
        if (suggestions.isNotEmpty)
          ...suggestions.map((s) => _InsightCard(insight: s, isSuggestion: true)),
      ],
    );
  }

  List<_SellerInsight> _generateInsights(SellerStats stats) {
    final insights = <_SellerInsight>[];

    if (stats.totalViews > 50) {
      insights.add(_SellerInsight(
        title: 'High Visibility',
        message: 'Your listings have been viewed by students ${stats.totalViews} times.',
        icon: Icons.trending_up,
        color: Colors.green,
      ));
    }

    if (stats.topPerformingListings.isNotEmpty) {
      final top = stats.topPerformingListings.first;
      if (top.saves > 2) {
        insights.add(_SellerInsight(
          title: 'Student Interest',
          message: 'Students are saving "${top.title}". This is your most popular item.',
          icon: Icons.favorite,
          color: Colors.pink,
        ));
      }
      
      final daysOld = DateTime.now().difference(top.createdAt).inDays;
      if (daysOld == 0 && top.views > 5) {
        insights.add(_SellerInsight(
          title: 'Off to a great start!',
          message: '"${top.title}" is already getting attention today.',
          icon: Icons.bolt,
          color: Colors.orange,
        ));
      }
    }

    return insights;
  }

  List<_SellerInsight> _generateSuggestions(SellerStats stats) {
    final suggestions = <_SellerInsight>[];

    for (var listing in stats.topPerformingListings) {
      if (listing.views > 30 && listing.chats == 0) {
        suggestions.add(_SellerInsight(
          title: 'Listing Tip',
          message: 'Buyers are viewing "${listing.title}" but not chatting. Consider clarifying the description.',
          icon: Icons.lightbulb_outline,
          color: Colors.amber,
        ));
        break; 
      }
    }

    if (stats.activeListingsCount > 0 && stats.totalViews < 5) {
       suggestions.add(_SellerInsight(
          title: 'Boost Discovery',
          message: 'New listings take time to trend. Share your items on campus to speed things up!',
          icon: Icons.campaign_outlined,
          color: AppColors.secondary,
        ));
    }

    return suggestions;
  }

  Widget _buildWelcomeSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Marketplace Performance',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Monitor how your listings are performing on campus.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _MetricCard(
          title: 'Active Listings',
          value: stats.activeListingsCount.toString(),
          icon: Icons.inventory_2_outlined,
          color: AppColors.primary,
        ),
        _MetricCard(
          title: 'Total Views',
          value: NumberFormat.compact().format(stats.totalViews),
          icon: Icons.visibility_outlined,
          color: Colors.blue,
        ),
        _MetricCard(
          title: 'Total Saves',
          value: stats.totalSaves.toString(),
          icon: Icons.bookmark_outline,
          color: Colors.orange,
        ),
        _MetricCard(
          title: 'Buyer Chats',
          value: stats.totalChatsStarted.toString(),
          icon: Icons.chat_bubble_outline,
          color: Colors.green,
        ),
      ],
    );
  }

  Widget _buildPerformanceSection(BuildContext context) {
    final theme = Theme.of(context);
    
    if (stats.topPerformingListings.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Performing Listings',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...stats.topPerformingListings.map((l) => _ListingEngagementCard(engagement: l)),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.list_alt),
            title: const Text('Manage All Listings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/marketplace/my-listings'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: const Text('Sold Items'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to my listings with sold filter or similar
            },
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ListingEngagementCard extends StatelessWidget {
  final ListingEngagement engagement;

  const _ListingEngagementCard({required this.engagement});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              engagement.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSmallMetric(context, Icons.visibility_outlined, '${engagement.views} views'),
                _buildSmallMetric(context, Icons.bookmark_outline, '${engagement.saves} saves'),
                _buildSmallMetric(context, Icons.chat_bubble_outline, '${engagement.chats} chats'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallMetric(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _SellerInsight {
  final String title;
  final String message;
  final IconData icon;
  final Color color;

  _SellerInsight({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });
}

class _InsightCard extends StatelessWidget {
  final _SellerInsight insight;
  final bool isSuggestion;

  const _InsightCard({
    required this.insight,
    this.isSuggestion = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSuggestion 
            ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.3)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSuggestion 
              ? theme.colorScheme.secondary.withValues(alpha: 0.2)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: insight.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(insight.icon, color: insight.color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  insight.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
