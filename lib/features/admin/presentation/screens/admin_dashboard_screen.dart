import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../layout/admin_layout.dart';
import '../../shared/providers.dart';
import '../../domain/models/audit_log.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);
    final auditLogsAsync = ref.watch(adminAuditLogsProvider(10));

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
                _buildRecentActivity(context, auditLogsAsync),
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
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Real-time metrics from the UniHub database.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          trend: stats.newUsersToday > 0 ? '+${stats.newUsersToday} today' : 'Stable',
        ),
        _SummaryCard(
          title: 'Resolved Reports',
          value: stats.resolvedReports.toString(),
          icon: Icons.check_circle,
          color: AppColors.success,
          trend: 'Platform health',
        ),
        _SummaryCard(
          title: 'Pending Verifications',
          value: stats.pendingVerifications.toString(),
          icon: Icons.verified_user,
          color: AppColors.warning,
          trend: 'Requires action',
          onTap: () => context.push('/admin/verifications'),
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
          title: 'Total Events',
          value: stats.totalEvents.toString(),
          icon: Icons.event,
          color: Colors.deepPurple,
          trend: stats.pendingEventApprovals > 0 ? '${stats.pendingEventApprovals} pending' : null,
          onTap: stats.pendingEventApprovals > 0 ? () => context.push('/admin/events/approvals') : null,
        ),
        _SummaryCard(
          title: 'Active Reports',
          value: stats.totalReports.toString(),
          icon: Icons.report,
          color: AppColors.error,
          trend: 'Urgent',
          onTap: () => context.push('/admin/reports'),
        ),
        _SummaryCard(
          title: 'Support Tickets',
          value: stats.openSupportTickets.toString(),
          icon: Icons.support_agent,
          color: AppColors.secondary,
          trend: stats.openSupportTickets > 0 ? 'Action needed' : 'All clear',
          onTap: () => context.push('/admin/support'),
        ),
        _SummaryCard(
          title: 'Active Announcements',
          value: stats.activeAnnouncements.toString(),
          icon: Icons.campaign,
          color: AppColors.secondaryDark,
        ),
      ],
    );
  }

  Widget _buildRecentActivity(BuildContext context, AsyncValue<List<AdminAuditLog>> logsAsync) {
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
                  'Recent Administrative Activity',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => context.push('/admin/audit-logs'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const Divider(),
            logsAsync.when(
              data: (logs) {
                if (logs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No recent activity found.', style: TextStyle(color: AppColors.grey600)),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _buildActionIcon(log.actionType),
                      title: Text(
                        _getActionDescription(log),
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                      ),
                      subtitle: Text(
                        'By ${log.adminName} • ${DateFormat('MMM dd, HH:mm').format(log.timestamp)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: log.reason != null 
                          ? Tooltip(message: log.reason, child: const Icon(Icons.info_outline, size: 16))
                          : null,
                    );
                  },
                );
              },
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              )),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIcon(AdminActionType type) {
    IconData icon;
    Color color;
    switch (type) {
      case AdminActionType.verificationApproval:
        icon = Icons.verified; color = AppColors.success; break;
      case AdminActionType.verificationRejection:
        icon = Icons.cancel; color = AppColors.error; break;
      case AdminActionType.userBan:
        icon = Icons.block; color = AppColors.error; break;
      case AdminActionType.contentRemoval:
        icon = Icons.delete_forever; color = AppColors.error; break;
      case AdminActionType.reportResolution:
        icon = Icons.check_circle; color = AppColors.primary; break;
      case AdminActionType.eventApproval:
        icon = Icons.event_available; color = AppColors.success; break;
      case AdminActionType.eventRejection:
        icon = Icons.event_busy; color = AppColors.error; break;
      default:
        icon = Icons.admin_panel_settings; color = AppColors.grey600;
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: color.withValues(alpha: 0.1),
      child: Icon(icon, size: 16, color: color),
    );
  }

  String _getActionDescription(AdminAuditLog log) {
    switch (log.actionType) {
      case AdminActionType.verificationApproval: return 'Approved ${log.targetType} verification';
      case AdminActionType.verificationRejection: return 'Rejected ${log.targetType} verification';
      case AdminActionType.userBan: return 'Banned user';
      case AdminActionType.userSuspension: return 'Suspended user';
      case AdminActionType.contentRemoval: return 'Removed ${log.targetType} content';
      case AdminActionType.reportResolution: return 'Resolved report';
      case AdminActionType.eventApproval: return 'Approved event';
      case AdminActionType.eventRejection: return 'Rejected event';
      case AdminActionType.bulkAction: return log.reason ?? 'Performed bulk action';
      default: return 'Performed administrative action';
    }
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
      child: InkWell(
        onTap: onTap,
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Theme.of(context).dividerColor),
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
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    if (trend != null)
                      Text(
                        trend!,
                        style: TextStyle(
                          fontSize: 12,
                          color: trend!.contains('Urgent') || trend!.contains('Requires') || trend!.contains('pending')
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
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
