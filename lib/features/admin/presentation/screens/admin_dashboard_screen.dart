import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../layout/admin_layout.dart';
import '../../shared/providers.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);

    return AdminLayout(
      title: 'Admin Dashboard',
      child: statsAsync.when(
        data: (stats) => RefreshIndicator(
          onRefresh: () => ref.refresh(adminStatsProvider.future),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 32),
                _buildStatsGrid(context, stats),
                const SizedBox(height: 32),
                _buildRecentActivityPlaceholder(context),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Real-time metrics from the UniHub database.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.grey600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(BuildContext context, stats) {
    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _SummaryCard(
          title: 'Total Users',
          value: stats.totalUsers.toString(),
          icon: Icons.people,
          color: AppColors.primary,
          trend: '+5% this week', // Placeholder for now until we have historical data
        ),
        _SummaryCard(
          title: 'Pending Verifications',
          value: stats.pendingVerifications.toString(),
          icon: Icons.verified_user,
          color: AppColors.warning,
          trend: 'Requires action',
        ),
        _SummaryCard(
          title: 'Marketplace Listings',
          value: stats.totalMarketplaceListings.toString(),
          icon: Icons.shopping_bag,
          color: AppColors.marketplace,
        ),
        _SummaryCard(
          title: 'Housing Listings',
          value: stats.totalHousingListings.toString(),
          icon: Icons.home,
          color: AppColors.housing,
        ),
        _SummaryCard(
          title: 'Shared Notes',
          value: stats.totalNotes.toString(),
          icon: Icons.note,
          color: AppColors.notes,
        ),
        _SummaryCard(
          title: 'Active Reports',
          value: stats.totalReports.toString(),
          icon: Icons.report,
          color: AppColors.error,
          trend: 'Urgent',
        ),
      ],
    );
  }

  Widget _buildRecentActivityPlaceholder(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Platform Activity',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('View All'),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(Icons.history, size: 48, color: AppColors.grey400),
                    SizedBox(height: 16),
                    Text('Activity logs will appear here in Phase 6', style: TextStyle(color: AppColors.grey600)),
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

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? trend;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.grey200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                if (trend != null)
                  Text(
                    trend!,
                    style: TextStyle(
                      fontSize: 12,
                      color: trend!.contains('Urgent') || trend!.contains('Requires') 
                        ? AppColors.error 
                        : AppColors.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.grey600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
