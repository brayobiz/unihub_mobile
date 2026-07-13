import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:unihub_mobile/features/marketplace/shared/providers.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/auth/domain/models/app_user.dart';
import 'package:unihub_mobile/features/marketplace/domain/models/seller_stats.dart';
import 'package:unihub_mobile/features/marketplace/presentation/controllers/seller_dashboard_controller.dart';
import 'package:unihub_mobile/features/ads/ads_module.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';

class SellerDashboardScreen extends ConsumerWidget {
  const SellerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).valueOrNull;
    if (user == null) return const Scaffold(body: Center(child: Text('Please login')));

    final isBusiness = user.accountType == 'business';
    final statsAsync = ref.watch(sellerStatsProvider(user.uid));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(isBusiness ? 'Business Suite' : 'Seller Dashboard'),
        backgroundColor: isBusiness ? AppColors.business : theme.colorScheme.surface,
        foregroundColor: isBusiness ? Colors.white : theme.colorScheme.onSurface,
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
        label: Text(isBusiness ? 'List New Product' : 'Create Listing'),
        icon: const Icon(Icons.add),
        backgroundColor: isBusiness ? AppColors.business : theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  final SellerStats stats;

  const _DashboardContent({required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).valueOrNull;
    final bool isVerified = user?.isIdentityVerified == true || user?.isStudentVerified == true;
    final bool isBusiness = user?.accountType == 'business';
    
    return RefreshIndicator(
      onRefresh: () async {
        if (user != null) {
          ref.invalidate(sellerStatsProvider(user.uid));
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildWelcomeSection(context, user),
          const SizedBox(height: 24),
          _buildMetricsGrid(context),
          const SizedBox(height: 24),
          _buildGrowthCenter(context, isVerified, isBusiness),
          const SizedBox(height: 24),
          _buildIntelligenceSection(context),
          const SizedBox(height: 24),
          _buildPerformanceSection(context),
          const SizedBox(height: 24),
          _buildQuickActions(context),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: BannerAdWidget(),
          ),
          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildGrowthCenter(BuildContext context, bool isVerified, bool isBusiness) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Grow Your Sales',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (!isVerified)
              _buildSmallBadge(context, 'VERIFY TO UNLOCK', Colors.orange)
            else if (!isBusiness)
              _buildSmallBadge(context, 'EARLY BIRD ACTIVE', Colors.green),
          ],
        ),
        const SizedBox(height: 12),
        if (!isVerified)
          _buildLockedGrowthCard(context)
        else ...[
          _buildActiveGrowthCard(context, isBusiness),
          const SizedBox(height: 12),
          if (!isBusiness) _buildBusinessUpsellCard(context),
        ],
      ],
    );
  }

  Widget _buildLockedGrowthCard(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push('/trust-center'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.lock_outline_rounded, color: Colors.orange, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Premium Tools Locked', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    'Verify your identity to unlock free Boosts, Featured slots, and Sponsored search.',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveGrowthCard(BuildContext context, bool isBusiness) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primaryContainer, theme.colorScheme.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.rocket_launch_rounded, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Free Promotions Active',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'As a verified seller, you have access to free premium visibility during our Early Bird phase.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/my-listings'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.colorScheme.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Promote Items'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessUpsellCard(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push('/business-upgrade'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.business_center_rounded, color: Colors.blue, size: 24),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Become a Business', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    'Get a business badge and unlock pro analytics for free.',
                    style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallBadge(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
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

  Widget _buildWelcomeSection(BuildContext context, AppUser? user) {
    final theme = Theme.of(context);
    final isBusiness = user?.accountType == 'business';

    if (isBusiness) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.business, AppColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_rounded, color: AppColors.businessGold, size: 20),
                const SizedBox(width: 8),
                Text(
                  'BUSINESS PRO',
                  style: TextStyle(
                    color: AppColors.businessGold.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              user?.businessName ?? 'Your Business',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              '${user?.businessCategory ?? 'Retail'} • Premium Suite Active',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
            ),
          ],
        ),
      );
    }

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
            onTap: () => context.push('/my-listings'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: const Text('View Sales History'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/my-listings'),
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
