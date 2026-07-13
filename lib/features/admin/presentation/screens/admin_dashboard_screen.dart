import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../layout/admin_layout.dart';
import '../../shared/providers.dart';
import '../../domain/models/platform_analytics.dart';
import '../../domain/models/user_analytics.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../domain/models/report.dart';
import '../../domain/models/verification_request.dart';
import '../../../chat/domain/models/conversation.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(platformAnalyticsProvider);
    final userAnalyticsAsync = ref.watch(userAnalyticsProvider);
    final auditLogsAsync = ref.watch(adminAuditLogsProvider(6));

    return AdminLayout(
      title: 'Executive Dashboard',
      child: analyticsAsync.when(
        data: (stats) => RefreshIndicator(
          onRefresh: () {
            ref.invalidate(platformAnalyticsProvider);
            ref.invalidate(userAnalyticsProvider);
            return ref.refresh(adminAuditLogsProvider(6).future);
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, stats),
                const SizedBox(height: 32),
                _buildActionableInsights(context, stats),
                const SizedBox(height: 32),
                _buildStatsGrid(context, stats),
                const SizedBox(height: 32),
                if (MediaQuery.of(context).size.width > 1100)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            _buildGrowthPreview(context, userAnalyticsAsync),
                            const SizedBox(height: 32),
                            _buildOperationalHighlights(context, ref),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        flex: 2,
                        child: _buildRecentActivity(context, auditLogsAsync),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildGrowthPreview(context, userAnalyticsAsync),
                      const SizedBox(height: 32),
                      _buildOperationalHighlights(context, ref),
                      const SizedBox(height: 32),
                      _buildRecentActivity(context, auditLogsAsync),
                    ],
                  ),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, PlatformAnalytics stats) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Overview',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Last platform sync: ${DateFormat('HH:mm:ss').format(stats.updatedAt)}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => context.push('/admin/analytics'),
          icon: const Icon(Icons.analytics_outlined),
          label: const Text('Detailed Analytics'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildActionableInsights(BuildContext context, PlatformAnalytics stats) {
    final insights = <Widget>[];

    if (stats.pendingReports > 0) {
      insights.add(_InsightChip(
        label: '${stats.pendingReports} Pending Reports',
        color: AppColors.error,
        icon: Icons.report_gmailerrorred_rounded,
        onTap: () => context.push('/admin/reports'),
      ));
    }

    if (stats.pendingVerifications > 10) {
      insights.add(_InsightChip(
        label: '${stats.pendingVerifications} Verification Backlog',
        color: AppColors.warning,
        icon: Icons.verified_user_outlined,
        onTap: () => context.push('/admin/verifications'),
      ));
    }

    if (stats.openSupportConversations > 0) {
      insights.add(_InsightChip(
        label: '${stats.openSupportConversations} Active Support Tickets',
        color: AppColors.secondary,
        icon: Icons.support_agent,
        onTap: () => context.push('/admin/support'),
      ));
    }

    if (insights.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actionable Insights',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.1),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: insights,
        ),
      ],
    );
  }

  Widget _buildStatsGrid(BuildContext context, PlatformAnalytics stats) {
    final width = MediaQuery.of(context).size.width;
    return GridView.count(
      crossAxisCount: width > 1400 ? 5 : (width > 900 ? 3 : 2),
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: width > 600 ? 1.4 : 1.1,
      children: [
        _SummaryCard(
          title: 'Total Users',
          value: NumberFormat.compact().format(stats.totalUsers),
          icon: Icons.people_alt_rounded,
          color: AppColors.primary,
          trend: '+${stats.newUsersToday} today',
          onTap: () => context.push('/admin/users'),
        ),
        _SummaryCard(
          title: 'Online Now',
          value: stats.currentlyActive.toString(),
          icon: Icons.online_prediction_rounded,
          color: Colors.green,
          trend: 'Real-time',
        ),
        _SummaryCard(
          title: 'Marketplace',
          value: NumberFormat.compact().format(stats.totalMarketplaceListings),
          icon: Icons.shopping_bag_rounded,
          color: AppColors.marketplace,
          onTap: () => context.push('/admin/marketplace'),
        ),
        _SummaryCard(
          title: 'Housing',
          value: NumberFormat.compact().format(stats.totalHousingListings),
          icon: Icons.home_work_rounded,
          color: AppColors.housing,
          onTap: () => context.push('/admin/housing'),
        ),
        _SummaryCard(
          title: 'Study Notes',
          value: NumberFormat.compact().format(stats.totalNotes),
          icon: Icons.menu_book_rounded,
          color: AppColors.notes,
          onTap: () => context.push('/admin/notes'),
        ),
      ],
    );
  }

  Widget _buildGrowthPreview(BuildContext context, AsyncValue<UserAnalytics> userStats) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User Growth (7 Days)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 24),
            userStats.when(
              data: (data) => SizedBox(
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: data.growthTrend.map((p) {
                    final max = data.growthTrend.fold(0, (m, point) => point.count > m ? point.count : m);
                    final height = max > 0 ? (p.count / max) * 100 : 0.0;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 24,
                          height: height.clamp(4.0, 100.0),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(DateFormat('E').format(p.date), style: const TextStyle(fontSize: 10)),
                      ],
                    );
                  }).toList(),
                ),
              ),
              loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
              error: (_, __) => const SizedBox(height: 120, child: Center(child: Text('Growth data unavailable'))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationalHighlights(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    return GridView.count(
      crossAxisCount: width > 600 ? 2 : 1,
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: width > 600 ? 1.1 : 1.5,
      children: [
        _OperationalCard<AppUser>(
          title: 'Latest Registrations',
          icon: Icons.person_add_rounded,
          data: ref.watch(adminUsersProvider((
            search: null, isBanned: null, isSuspended: null, isVerified: null,
            role: null, university: null, sortBy: 'date', descending: true,
            startDate: null, endDate: null
          ))),
          itemBuilder: (user) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
              child: user.photoUrl == null ? const Icon(Icons.person) : null,
            ),
            title: Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text(user.university ?? 'New User', style: const TextStyle(fontSize: 11)),
            trailing: Text(
              user.createdAt != null ? DateFormat('HH:mm').format(user.createdAt!) : '',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            onTap: () => context.push('/admin/users/${user.uid}'),
          ),
        ),
        _OperationalCard<AdminReport>(
          title: 'Latest Reports',
          icon: Icons.flag_rounded,
          data: ref.watch(adminReportsProvider((status: ReportStatus.pending, type: null))),
          itemBuilder: (report) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFFFEBEE),
              child: Icon(Icons.priority_high, color: AppColors.error, size: 20),
            ),
            title: Text(report.reason, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text(report.type.name.toUpperCase(), style: const TextStyle(fontSize: 11, color: AppColors.error)),
            onTap: () => context.push('/admin/reports/${report.id}', extra: report),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity(BuildContext context, AsyncValue<List<dynamic>> logsAsync) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Audit Timeline',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                IconButton(
                  onPressed: () => context.push('/admin/audit-logs'),
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: 'Full Audit Log',
                ),
              ],
            ),
            const Divider(height: 32),
            logsAsync.when(
              data: (logs) {
                if (logs.isEmpty) return const Center(child: Text('No recent activity'));
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildActionIndicator(log.actionType),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getActionDescription(log),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                '${log.adminName} • ${DateFormat('MMM d, HH:mm').format(log.timestamp)}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('Failed to load logs')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIndicator(dynamic type) {
    Color color = Colors.grey;
    if (type.toString().contains('Approval')) color = AppColors.success;
    if (type.toString().contains('Rejection') || type.toString().contains('Ban')) color = AppColors.error;

    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  String _getActionDescription(dynamic log) {
    final type = log.actionType.toString().split('.').last;
    final target = log.targetType ?? 'system';
    return '${type[0].toUpperCase()}${type.substring(1).replaceAll(RegExp(r'(?=[A-Z])'), ' ')}: $target';
  }
}

class _InsightChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _InsightChip({required this.label, required this.color, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _OperationalCard<T> extends StatelessWidget {
  final String title;
  final IconData icon;
  final AsyncValue<List<T>> data;
  final Widget Function(T) itemBuilder;

  const _OperationalCard({required this.title, required this.icon, required this.data, required this.itemBuilder});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: data.when(
                data: (items) {
                  if (items.isEmpty) return const Center(child: Text('No recent items', style: TextStyle(fontSize: 12)));
                  return ListView.builder(
                    itemCount: items.length > 3 ? 3 : items.length,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) => itemBuilder(items[index]),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('Unavailable')),
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
  final VoidCallback? onTap;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.trend,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    if (onTap != null)
                      const Icon(Icons.open_in_new, size: 12, color: Colors.grey),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (trend != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              trend!,
                              style: const TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
