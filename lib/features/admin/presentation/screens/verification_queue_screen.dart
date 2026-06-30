import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../layout/admin_layout.dart';
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

  @override
  Widget build(BuildContext context) {
    final filters = (status: _selectedStatus, type: _selectedType);
    final requestsAsync = ref.watch(verificationRequestsProvider(filters));

    return AdminLayout(
      title: 'Verification Management',
      child: Column(
        children: [
          _buildFilters(requestsAsync.valueOrNull?.length ?? 0),
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
              style: const TextStyle(color: AppColors.grey600)),
          ],
        ),
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
        return _VerificationListItem(request: request);
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
        side: BorderSide(color: AppColors.grey200),
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
                        Flexible(
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
                        _buildStatusChip(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'User ID: ${request.userId}',
                      style: const TextStyle(color: AppColors.grey600, fontSize: 12),
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

  String _getDisplayName() {
    if (request.fullName != null) return request.fullName!;
    switch (request.type) {
      case AdminVerificationType.identity: return 'Identity Verification';
      case AdminVerificationType.student: return 'Student Verification';
      case AdminVerificationType.professional: return '${request.role ?? "Professional"} App';
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        request.status.name.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
