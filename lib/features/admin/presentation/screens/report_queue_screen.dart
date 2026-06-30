import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../layout/admin_layout.dart';
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
          _buildFilters(reportsAsync.valueOrNull?.length ?? 0),
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
      color: Colors.white,
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

  Widget _buildFilters(int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: SingleChildScrollView(
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
            Text('$count Reports Found', style: const TextStyle(color: AppColors.grey600)),
          ],
        ),
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
        return _ReportListItem(report: report);
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
        side: BorderSide(color: AppColors.grey200),
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
                        Flexible(
                          child: Text(
                            report.reason,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Target ID: ${report.targetId ?? "User Report"}',
                      style: const TextStyle(color: AppColors.grey600, fontSize: 12),
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
                    style: const TextStyle(color: AppColors.grey600, fontSize: 12),
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
