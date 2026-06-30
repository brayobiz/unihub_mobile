import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../layout/admin_layout.dart';
import '../../domain/models/verification_request.dart';
import '../../shared/providers.dart';

class VerificationDetailScreen extends ConsumerStatefulWidget {
  final AdminVerificationRequest request;

  const VerificationDetailScreen({super.key, required this.request});

  @override
  ConsumerState<VerificationDetailScreen> createState() => _VerificationDetailScreenState();
}

class _VerificationDetailScreenState extends ConsumerState<VerificationDetailScreen> {
  final _reasonController = TextEditingController();
  final _adminNotesController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _adminNotesController.text = widget.request.adminNotes ?? '';
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _adminNotesController.dispose();
    super.dispose();
  }

  Future<void> _processAction(AdminVerificationStatus status) async {
    if (status == AdminVerificationStatus.rejected || status == AdminVerificationStatus.resubmissionRequested) {
      if (_reasonController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reason is required for ${status.name}')),
        );
        return;
      }
    }

    setState(() => _isProcessing = true);
    try {
      await ref.read(adminRepositoryProvider).processVerification(
        request: widget.request,
        newStatus: status,
        reason: _reasonController.text.trim(),
        adminNotes: _adminNotesController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action processed successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return AdminLayout(
      title: 'Review Request',
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
                  _buildDetailsSection(),
                  const SizedBox(height: 24),
                  _buildActionsSection(),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: _buildDetailsSection()),
                  const SizedBox(width: 24),
                  Expanded(flex: 1, child: _buildActionsSection()),
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
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.request.type.name.toUpperCase()} Verification',
                style: const TextStyle(fontSize: 14, color: AppColors.grey600, fontWeight: FontWeight.bold),
              ),
              Text(
                'Request ID: ${widget.request.id}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
    switch (widget.request.status) {
      case AdminVerificationStatus.pending: color = AppColors.warning; break;
      case AdminVerificationStatus.underReview: color = AppColors.primary; break;
      case AdminVerificationStatus.approved: color = AppColors.success; break;
      case AdminVerificationStatus.rejected: color = AppColors.error; break;
      case AdminVerificationStatus.resubmissionRequested: color = AppColors.warning; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(widget.request.status.name.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          title: 'Applicant Information',
          child: Column(
            children: [
              _buildInfoRow('User ID', widget.request.userId),
              if (widget.request.fullName != null) _buildInfoRow('Full Name', widget.request.fullName!),
              if (widget.request.role != null) _buildInfoRow('Role', widget.request.role!),
              _buildInfoRow('Submitted At', DateFormat('MMM dd, yyyy HH:mm').format(widget.request.submittedAt)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionCard(
          title: 'Documents',
          child: Column(
            children: [
              if (widget.request.idDocumentUrl != null)
                _buildDocumentPreview('ID Document', widget.request.idDocumentUrl!),
              if (widget.request.selfieUrl != null)
                _buildDocumentPreview('Selfie', widget.request.selfieUrl!),
              if (widget.request.studentIdUrl != null)
                _buildDocumentPreview('Student ID', widget.request.studentIdUrl!),
            ],
          ),
        ),
        if (widget.request.metadata.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionCard(
            title: 'Metadata',
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: widget.request.metadata.entries.map((e) => _buildInfoRow(e.key, e.value.toString())).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionsSection() {
    return Column(
      children: [
        _buildSectionCard(
          title: 'Admin Controls',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Admin Notes (Internal)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _adminNotesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Internal notes...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Reason for Rejection/Resubmit', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Required for rejection or resubmit...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              if (_isProcessing)
                const Center(child: CircularProgressIndicator())
              else if (widget.request.status == AdminVerificationStatus.pending || widget.request.status == AdminVerificationStatus.underReview)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.request.status == AdminVerificationStatus.pending) ...[
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () => _processAction(AdminVerificationStatus.underReview),
                        child: const Text('Mark as Under Review'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => _processAction(AdminVerificationStatus.approved),
                      child: const Text('Approve Verification'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => _processAction(AdminVerificationStatus.resubmissionRequested),
                      child: const Text('Request Resubmission'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => _processAction(AdminVerificationStatus.rejected),
                      child: const Text('Reject Request'),
                    ),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(8)),
                  child: const Text('This request has already been processed.', textAlign: TextAlign.center),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.grey200)),
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
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: AppColors.grey600, fontWeight: FontWeight.w500))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildDocumentPreview(String label, String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () => _showFullImage(url),
            child: CachedNetworkImage(
              imageUrl: url,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: AppColors.grey100, child: const Center(child: CircularProgressIndicator())),
              errorWidget: (context, url, error) => Container(color: AppColors.grey100, child: const Icon(Icons.error)),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _showFullImage(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                CachedNetworkImage(imageUrl: url),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
