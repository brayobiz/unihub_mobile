import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../shared/providers.dart';
import '../../domain/models/audit_log.dart';
import '../layout/admin_layout.dart';

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(adminAuditLogsProvider(100));

    return AdminLayout(
      title: 'Administrative Audit Log',
      child: logsAsync.when(
        data: (logs) => _buildLogList(context, logs),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildLogList(BuildContext context, List<AdminAuditLog> logs) {
    if (logs.isEmpty) {
      return const Center(
        child: Text('No audit logs recorded yet.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: logs.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final log = logs[index];
        return ListTile(
          leading: _buildActionIcon(log.actionType),
          title: Text(_getActionDescription(log), style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Performed by ${log.adminName}'),
              if (log.reason != null && log.reason!.isNotEmpty)
                Text('Reason: ${log.reason}', style: const TextStyle(fontStyle: FontStyle.italic)),
              Text('Target ID: ${log.targetId}', style: const TextStyle(fontSize: 10)),
            ],
          ),
          trailing: Text(
            DateFormat('MMM dd, yyyy\nHH:mm:ss').format(log.timestamp),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12),
          ),
          isThreeLine: true,
        );
      },
    );
  }

  Widget _buildActionIcon(AdminActionType type) {
    IconData icon;
    Color color;
    switch (type) {
      case AdminActionType.verificationApproval: icon = Icons.verified; color = AppColors.success; break;
      case AdminActionType.verificationRejection: icon = Icons.cancel; color = AppColors.error; break;
      case AdminActionType.userBan: icon = Icons.block; color = AppColors.error; break;
      case AdminActionType.contentRemoval: icon = Icons.delete_forever; color = AppColors.error; break;
      case AdminActionType.reportResolution: icon = Icons.check_circle; color = AppColors.primary; break;
      default: icon = Icons.history; color = AppColors.grey;
    }
    return CircleAvatar(
      backgroundColor: color.withOpacity(0.1),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _getActionDescription(AdminAuditLog log) {
    switch (log.actionType) {
      case AdminActionType.verificationApproval: return 'Verification Approved';
      case AdminActionType.verificationRejection: return 'Verification Rejected';
      case AdminActionType.userBan: return 'Account Banned';
      case AdminActionType.userRestore: return 'Account Restored';
      case AdminActionType.userSuspension: return 'Account Suspended';
      case AdminActionType.contentRemoval: return 'Content Removed';
      case AdminActionType.reportResolution: return 'Report Resolved';
      case AdminActionType.bulkAction: return log.reason ?? 'Bulk Action Performed';
      default: return 'Admin Action';
    }
  }
}
