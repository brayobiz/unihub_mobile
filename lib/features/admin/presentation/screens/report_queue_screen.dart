import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../layout/admin_layout.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/report.dart';
import '../../shared/providers.dart';

class ReportQueueScreen extends ConsumerStatefulWidget {
  const ReportQueueScreen({super.key});

  @override
  ConsumerState<ReportQueueScreen> createState() => _ReportQueueScreenState();
}

class _ReportQueueScreenState extends ConsumerState<ReportQueueScreen> {
  ReportStatus? _selectedStatus = ReportStatus.pending;
  ReportType? _selectedType;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _selectedIds = {};
  bool _isBulkProcessing = false;

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _handleBulkAction(String action, List<AdminReport> reports) async {
    final selectedReports = reports.where((r) => _selectedIds.contains(r.id)).toList();
    if (selectedReports.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bulk $action'),
        content: Text('Are you sure you want to $action ${selectedReports.length} report(s)?\n\n${selectedReports.map((r) => '• ${r.reason.length > 40 ? r.reason.substring(0, 40) + "..." : r.reason}').take(5).join('\n')}${selectedReports.length > 5 ? '\n... and ${selectedReports.length - 5} more' : ''}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isBulkProcessing = true);
    final messenger = ScaffoldMessenger.of(context);
    
    try {
      final admin = ref.read(appUserProvider).valueOrNull;
      if (admin == null) throw Exception('Admin session not found');

      if (selectedReports.isEmpty) {
        throw Exception('No reports selected for processing');
      }

      await ref.read(adminServiceProvider).bulkResolveReports(
        reports: selectedReports,
        action: action,
        adminId: admin.uid,
        adminName: admin.fullName,
      );
      
      if (mounted) {
        setState(() {
          _selectedIds.clear();
          _isBulkProcessing = false;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text('✅ Bulk $action completed: ${selectedReports.length} report(s) processed'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
        // Refresh the provider
        ref.refresh(adminReportsProvider((status: _selectedStatus, type: _selectedType)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBulkProcessing = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('❌ Bulk action failed: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(adminReportsProvider((status: _selectedStatus, type: _selectedType)));

    return AdminLayout(
      title: 'Moderation Queue',
      child: Column(
        children: [
          _buildFilters(reportsAsync.valueOrNull?.length ?? 0, reportsAsync.valueOrNull ?? []),
          _buildSearchBar(),
          Expanded(
            child: reportsAsync.when(
              data: (reports) {
                final filtered = _applySearch(reports);
                return _buildQueue(filtered);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).cardColor,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by User ID or Content ID...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty 
            ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              })
            : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          fillColor: Theme.of(context).colorScheme.surface,
        ),
        onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
      ),
    );
  }

  List<AdminReport> _applySearch(List<AdminReport> reports) {
    if (_searchQuery.isEmpty) return reports;
    return reports.where((r) => 
      r.reporterId.toLowerCase().contains(_searchQuery) ||
      (r.reportedUserId?.toLowerCase().contains(_searchQuery) ?? false) ||
      (r.targetId?.toLowerCase().contains(_searchQuery) ?? false) ||
      r.reason.toLowerCase().contains(_searchQuery)
    ).toList();
  }

  Widget _buildFilters(int count, List<AdminReport> reports) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                DropdownButton<ReportStatus?>(
                  value: _selectedStatus,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    ...ReportStatus.values.map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.name[0].toUpperCase() + s.name.substring(1)),
                    )),
                  ],
                  onChanged: (val) => setState(() => _selectedStatus = val),
                ),
                const SizedBox(width: 24),
                const Text('Feature: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                DropdownButton<ReportType?>(
                  value: _selectedType,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    ...ReportType.values.map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.name[0].toUpperCase() + t.name.substring(1)),
                    )),
                  ],
                  onChanged: (val) => setState(() => _selectedType = val),
                ),
                const SizedBox(width: 24),
                Text('$count Reports Found', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (_selectedIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text('${_selectedIds.length} Selected', 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(width: 16),
                  if (_isBulkProcessing) 
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else ...[
                    TextButton.icon(
                      onPressed: () => _handleBulkAction('resolve', reports),
                      icon: const Icon(Icons.check_circle_outline, color: AppColors.success),
                      label: const Text('Resolve Selected', style: TextStyle(color: AppColors.success)),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _handleBulkAction('dismiss', reports),
                      icon: const Icon(Icons.close, color: AppColors.grey600),
                      label: const Text('Dismiss Selected', style: TextStyle(color: AppColors.grey600)),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => setState(() => _selectedIds.clear()),
                      icon: const Icon(Icons.close),
                      tooltip: 'Clear Selection',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQueue(List<AdminReport> reports) {
    if (reports.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gpp_good_outlined, size: 64, color: AppColors.grey400),
            SizedBox(height: 16),
            Text('No active reports. Good job!', style: TextStyle(color: AppColors.grey600)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final report = reports[index];
        final isSelected = _selectedIds.contains(report.id);

        return Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleSelection(report.id),
            ),
            Expanded(child: _ReportListItem(report: report)),
          ],
        );
      },
    );
  }
}

class _ReportListItem extends StatelessWidget {
  final AdminReport report;

  const _ReportListItem({required this.report});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        onTap: () => context.push('/admin/reports/${report.id}', extra: report),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              _buildTypeIcon(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            report.reason,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: _buildStatusChip(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Target ID: ${report.targetId ?? "User Report"}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant, 
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('MMM dd').format(report.createdAt),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    DateFormat('HH:mm').format(report.createdAt),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant, 
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              const Icon(Icons.chevron_right, color: AppColors.grey400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon() {
    IconData icon;
    Color color;
    switch (report.type) {
      case ReportType.marketplace:
        icon = Icons.shopping_bag;
        color = AppColors.marketplace;
        break;
      case ReportType.housing:
        icon = Icons.home;
        color = AppColors.housing;
        break;
      case ReportType.feedItem:
        icon = Icons.article;
        color = AppColors.notes;
        break;
      case ReportType.user:
        icon = Icons.person;
        color = AppColors.primary;
        break;
      case ReportType.chat:
        icon = Icons.chat;
        color = AppColors.secondary;
        break;
      case ReportType.note:
        icon = Icons.description;
        color = AppColors.notes;
        break;
      case ReportType.event:
        icon = Icons.event;
        color = AppColors.primary;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildStatusChip() {
    Color color;
    switch (report.status) {
      case ReportStatus.pending: color = AppColors.warning; break;
      case ReportStatus.underReview: color = AppColors.primary; break;
      case ReportStatus.resolved: color = AppColors.success; break;
      case ReportStatus.dismissed: color = AppColors.grey500; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        report.status.name.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
