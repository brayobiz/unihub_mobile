import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unihub_mobile/core/widgets/optimized_image.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../layout/admin_layout.dart';
import '../../../auth/shared/providers.dart';
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
     if (_isProcessing) return;

     if (status == AdminVerificationStatus.rejected || status == AdminVerificationStatus.resubmissionRequested) {
       if (_reasonController.text.trim().isEmpty) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Reason is required for ${status.name}')),
           );
         }
         return;
       }
     }

     setState(() => _isProcessing = true);
     
     // Capture dependencies before the async gap to avoid using 'ref' after dispose
     final adminService = ref.read(adminServiceProvider);
     final admin = ref.read(appUserProvider).valueOrNull;
     final messenger = ScaffoldMessenger.of(context);
     final router = GoRouter.of(context);
     final reason = _reasonController.text.trim();
     final adminNotes = _adminNotesController.text.trim();
     
     try {
       if (admin == null) throw Exception('Admin session not found');

       // DEFENSIVE VALIDATION: Ensure request has valid IDs
       if (widget.request.id.isEmpty || widget.request.id.trim().isEmpty) {
         throw Exception(
           'Approval failed: Verification request ID is empty or invalid. '
           'This may indicate corrupted data in the verification document.'
         );
       }
       
       if (widget.request.userId.isEmpty || widget.request.userId.trim().isEmpty) {
         throw Exception(
           'Approval failed: User ID is empty or invalid for ${widget.request.type.name} verification. '
           'The verification document may be missing the userId field.'
         );
       }

       await adminService.processVerification(
         request: widget.request,
         newStatus: status,
         adminId: admin.uid,
         adminName: admin.fullName,
         reason: reason,
         adminNotes: adminNotes,
       );
       
       if (mounted) {
         messenger.showSnackBar(
           SnackBar(content: Text('✅ Verification ${status.name} successfully - user will be notified')),
         );
         // Small delay to ensure database reflects change
         await Future.delayed(const Duration(milliseconds: 500));
         if (router.canPop()) {
           router.pop(true);  // Return true to indicate success
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
                style: TextStyle(
                  fontSize: 14, 
                  color: Theme.of(context).colorScheme.onSurfaceVariant, 
                  fontWeight: FontWeight.bold,
                ),
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
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
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
            title: 'Additional Information',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.request.metadata.entries.map((e) {
                final value = e.value.toString();
                final isUrl = value.startsWith('http');
                final isImage = isUrl && (
                  value.contains('.jpg') || 
                  value.contains('.png') || 
                  value.contains('.jpeg') || 
                  value.contains('firebasestorage') ||
                  value.contains('cloudinary.com')
                );
                
                if (isImage) {
                  return _buildDocumentPreview(e.key.toUpperCase(), value);
                }
                
                return _buildInfoRow(e.key, value);
              }).toList(),
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
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest, 
                    borderRadius: BorderRadius.circular(8),
                  ),
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
            width: 120, 
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
            child: OptimizedImage(
              imageUrl: url,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
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
                OptimizedImage(imageUrl: url, useCloudinaryTransform: false),
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
