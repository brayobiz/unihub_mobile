import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../layout/admin_layout.dart';
import '../../domain/models/report.dart';
import '../../shared/providers.dart';
import '../../../auth/shared/providers.dart';

class ReportDetailScreen extends ConsumerStatefulWidget {
  final AdminReport report;

  const ReportDetailScreen({super.key, required this.report});

  @override
  ConsumerState<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends ConsumerState<ReportDetailScreen> {
  final _notesController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleAction(String action, {int? suspensionDays}) async {
    if (_isProcessing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${action[0].toUpperCase()}${action.substring(1)} Action'),
        content: Text('Are you sure you want to $action this ${reportActionTarget(action)}? This action will be logged and notification sent if applicable.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: action == 'dismiss' ? AppColors.grey600 : AppColors.error),
            child: Text('Confirm $action'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isProcessing = true);
    
    // Capture dependencies before the async gap to avoid using 'ref' after dispose
    final adminService = ref.read(adminServiceProvider);
    final currentAdmin = ref.read(appUserProvider).valueOrNull;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final notes = _notesController.text.trim();

    try {
      if (currentAdmin == null) throw Exception('Admin not logged in');

      if (widget.report.id.isEmpty) {
        throw Exception('Invalid report ID - cannot process');
      }

      await adminService.resolveReport(
        report: widget.report,
        action: action,
        adminId: currentAdmin.uid,
        adminName: currentAdmin.fullName,
        notes: notes,
        suspensionDays: suspensionDays,
      );

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('✅ Report $action completed successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        // Small delay to ensure database reflects change
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Refresh the reports provider before leaving
        ref.invalidate(adminReportsProvider);
        
        // Safety check again before popping
        if (mounted && router.canPop()) {
          router.pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String reportActionTarget(String action) {
    if (action == 'remove') return 'content';
    if (action == 'warn' || action == 'suspend' || action == 'ban') return 'user';
    return 'report';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return AdminLayout(
      title: 'Review Report',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            if (isMobile)
              Column(
                children: [
                  _buildReportDetails(),
                  const SizedBox(height: 24),
                  _buildModerationPanel(),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: _buildReportDetails()),
                  const SizedBox(width: 24),
                  Expanded(flex: 1, child: _buildModerationPanel()),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('REPORT #${widget.report.id.toUpperCase()}', 
                style: TextStyle(
                  fontSize: 12, 
                  color: Theme.of(context).colorScheme.onSurfaceVariant, 
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(widget.report.reason, 
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildStatusChip(),
      ],
    );
  }

  Widget _buildStatusChip() {
    Color color;
    switch (widget.report.status) {
      case ReportStatus.pending: color = AppColors.warning; break;
      case ReportStatus.underReview: color = AppColors.primary; break;
      case ReportStatus.resolved: color = AppColors.success; break;
      case ReportStatus.dismissed: color = AppColors.grey500; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(widget.report.status.name.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildReportDetails() {
    return Column(
      children: [
        _buildSectionCard(
          title: 'Report Context',
          child: Column(
            children: [
              _buildInfoRow('Reporter ID', widget.report.reporterId),
              _buildInfoRow('Reported User ID', widget.report.reportedUserId ?? 'Unknown'),
              _buildInfoRow('Feature', widget.report.type.name.toUpperCase()),
              _buildInfoRow('Target Content ID', widget.report.targetId ?? 'N/A'),
              _buildInfoRow('Submission Date', DateFormat('MMM dd, yyyy HH:mm').format(widget.report.createdAt)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (widget.report.history.isNotEmpty) ...[
          _buildSectionCard(
            title: 'Moderation History',
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.report.history.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final item = widget.report.history[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.action.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(item.notes ?? 'No notes'),
                  trailing: Text(DateFormat('MMM dd').format(item.timestamp)),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
        _buildSectionCard(
          title: 'Reported Content (Actions)',
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Icon(Icons.outbound_outlined, size: 48, color: AppColors.primary),
                  const SizedBox(height: 16),
                  const Text('Direct Content Moderation', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Quickly jump to the moderation panel for this ${widget.report.type.name}.', 
                    textAlign: TextAlign.center, 
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  if (widget.report.type == ReportType.marketplace || widget.report.type == ReportType.housing || widget.report.type == ReportType.note || widget.report.type == ReportType.event)
                    ElevatedButton(
                      onPressed: () {
                        String path = '/admin/marketplace';
                        if (widget.report.type == ReportType.housing) path = '/admin/housing';
                        if (widget.report.type == ReportType.note) path = '/admin/notes';
                        if (widget.report.type == ReportType.event) path = '/admin/events';
                        context.push(path);
                      },
                      child: const Text('Open Content Queue'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModerationPanel() {
    return _buildSectionCard(
      title: 'Moderation Actions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Admin Response/Notes', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Describe the outcome or internal notes...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          if (_isProcessing)
            const Center(child: CircularProgressIndicator())
          else if (widget.report.status == ReportStatus.resolved || widget.report.status == ReportStatus.dismissed)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest, 
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('This report has already been resolved.', textAlign: TextAlign.center),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ActionButton(
                  label: 'Dismiss Report', 
                  icon: Icons.close, 
                  color: Theme.of(context).colorScheme.onSurfaceVariant, 
                  onPressed: () => _handleAction('dismiss'),
                ),
                const SizedBox(height: 12),
                _ActionButton(label: 'Issue Warning', icon: Icons.warning_amber, color: AppColors.warning, onPressed: () => _handleAction('warn')),
                const SizedBox(height: 12),
                _ActionButton(label: 'Remove Content', icon: Icons.delete_forever, color: AppColors.error, onPressed: () => _handleAction('remove')),
                const SizedBox(height: 12),
                _ActionButton(label: 'Suspend User (7 Days)', icon: Icons.timer_outlined, color: AppColors.error, onPressed: () => _handleAction('suspend', suspensionDays: 7)),
                const SizedBox(height: 12),
                _ActionButton(label: 'Permanent Ban', icon: Icons.block, color: AppColors.error, onPressed: () => _handleAction('ban')),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), 
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 32),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140, 
            child: Text(
              label, 
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant, 
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({required this.label, required this.icon, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
    );
  }
}
