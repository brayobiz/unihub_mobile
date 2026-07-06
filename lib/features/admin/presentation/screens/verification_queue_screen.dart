import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../layout/admin_layout.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/verification_request.dart';
import '../../shared/providers.dart';

class VerificationQueueScreen extends ConsumerStatefulWidget {
  const VerificationQueueScreen({super.key});

  @override
  ConsumerState<VerificationQueueScreen> createState() => _VerificationQueueScreenState();
}

class _VerificationQueueScreenState extends ConsumerState<VerificationQueueScreen> {
  AdminVerificationStatus? _selectedStatus = AdminVerificationStatus.pending;
  AdminVerificationType? _selectedType;
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

  Future<void> _handleBulkAction(AdminVerificationStatus status, List<AdminVerificationRequest> requests) async {
    final selectedRequests = requests.where((r) => _selectedIds.contains(r.id)).toList();
    if (selectedRequests.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bulk ${status.name}'),
        content: Text('Are you sure you want to ${status.name} ${selectedRequests.length} verification request(s)?\n\n${selectedRequests.map((r) => '• ${r.type.name} for ${r.userId}').take(5).join('\n')}${selectedRequests.length > 5 ? '\n... and ${selectedRequests.length - 5} more' : ''}'),
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

      if (selectedRequests.isEmpty) {
        throw Exception('No requests selected for processing');
      }

      await ref.read(adminServiceProvider).bulkProcessVerifications(
        requests: selectedRequests,
        status: status,
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
            content: Text('✅ Bulk ${status.name} completed: ${selectedRequests.length} verification(s) processed'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
        // Refresh the provider
        ref.refresh(verificationRequestsProvider((status: _selectedStatus, type: _selectedType)));
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
  Widget build(BuildContext context) {
    final filters = (status: _selectedStatus, type: _selectedType);
    final requestsAsync = ref.watch(verificationRequestsProvider(filters));

    return AdminLayout(
      title: 'Verification Management',
      child: Column(
        children: [
          _buildFilters(requestsAsync.valueOrNull?.length ?? 0, requestsAsync.valueOrNull ?? []),
          Expanded(
            child: requestsAsync.when(
              data: (requests) => _buildQueue(requests),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(int count, List<AdminVerificationRequest> requests) {
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
                DropdownButton<AdminVerificationStatus?>(
                  value: _selectedStatus,
                  hint: const Text('All'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    ...AdminVerificationStatus.values.map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.name[0].toUpperCase() + s.name.substring(1)),
                    )),
                  ],
                  onChanged: (val) => setState(() => _selectedStatus = val),
                ),
                const SizedBox(width: 24),
                const Text('Type: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                DropdownButton<AdminVerificationType?>(
                  value: _selectedType,
                  hint: const Text('All'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    ...AdminVerificationType.values.map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.name[0].toUpperCase() + t.name.substring(1)),
                    )),
                  ],
                  onChanged: (val) => setState(() => _selectedType = val),
                ),
                const SizedBox(width: 24),
                Text('$count Requests Found',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                      onPressed: () => _handleBulkAction(AdminVerificationStatus.approved, requests),
                      icon: const Icon(Icons.check_circle_outline, color: AppColors.success),
                      label: const Text('Approve', style: TextStyle(color: AppColors.success)),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _handleBulkAction(AdminVerificationStatus.rejected, requests),
                      icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
                      label: const Text('Reject', style: TextStyle(color: AppColors.error)),
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

  Widget _buildQueue(List<AdminVerificationRequest> requests) {
    if (requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user_outlined, size: 64, color: AppColors.grey400),
            SizedBox(height: 16),
            Text('No verification requests found.', style: TextStyle(color: AppColors.grey600)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final request = requests[index];
        final isSelected = _selectedIds.contains(request.id);
        
        return Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleSelection(request.id),
            ),
            Expanded(
              child: _VerificationListItem(request: request),
            ),
          ],
        );
      },
    );
  }
}

class _VerificationListItem extends StatelessWidget {
  final AdminVerificationRequest request;

  const _VerificationListItem({required this.request});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        onTap: () => context.push('/admin/verifications/${request.id}', extra: request),
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
                            _getDisplayName(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
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
                      'User ID: ${request.userId}',
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
                    DateFormat('MMM dd, yyyy').format(request.submittedAt),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    DateFormat('HH:mm').format(request.submittedAt),
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
    switch (request.type) {
      case AdminVerificationType.identity:
        icon = Icons.badge;
        color = AppColors.primary;
        break;
      case AdminVerificationType.student:
        icon = Icons.school;
        color = AppColors.success;
        break;
      case AdminVerificationType.professional:
        icon = Icons.workspace_premium;
        color = AppColors.warning;
        break;
      case AdminVerificationType.organizer:
        icon = Icons.groups_rounded;
        color = AppColors.primary;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  String _getDisplayName() {
    if (request.fullName != null) return request.fullName!;
    switch (request.type) {
      case AdminVerificationType.identity: return 'Identity Verification';
      case AdminVerificationType.student: return 'Student Verification';
      case AdminVerificationType.professional: return '${request.role ?? "Professional"} App';
      case AdminVerificationType.organizer: return 'Organizer Profile';
    }
  }

  Widget _buildStatusChip() {
    Color color;
    switch (request.status) {
      case AdminVerificationStatus.pending: color = AppColors.warning; break;
      case AdminVerificationStatus.underReview: color = AppColors.primary; break;
      case AdminVerificationStatus.approved: color = AppColors.success; break;
      case AdminVerificationStatus.rejected: color = AppColors.error; break;
      case AdminVerificationStatus.resubmissionRequested: color = AppColors.warning; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        request.status.name.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
