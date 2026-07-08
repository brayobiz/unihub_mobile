import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:unihub_mobile/features/auth/domain/models/app_user.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/trust/domain/models/student_verification.dart';
import 'package:unihub_mobile/features/trust/presentation/providers/trust_providers.dart';
import 'package:unihub_mobile/features/shared/storage_repository.dart';

class StudentVerificationScreen extends ConsumerStatefulWidget {
  const StudentVerificationScreen({super.key});

  @override
  ConsumerState<StudentVerificationScreen> createState() => _StudentVerificationScreenState();
}

class _StudentVerificationScreenState extends ConsumerState<StudentVerificationScreen> {
  File? _imageFile;
  bool _isSubmitting = false;
  double _uploadProgress = 0;
  final _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _submit() async {
    if (_imageFile == null || _isSubmitting) return;

    // Capture context-dependent services BEFORE any async gaps
    final messenger = ScaffoldMessenger.of(context);
    final router = Navigator.of(context);

    setState(() {
      _isSubmitting = true;
      _uploadProgress = 0;
    });

    try {
      final user = ref.read(appUserProvider).valueOrNull;
      if (user == null) throw Exception('User not logged in');

      // 1. Upload using the Platform Storage Repository
      final imageUrl = await ref.read(storageRepositoryProvider).uploadFile(
        path: 'verifications/student',
        id: 'student_id_${user.uid}_${DateTime.now().millisecondsSinceEpoch}',
        file: _imageFile!,
        onProgress: (sent, total) {
          if (mounted) {
            setState(() => _uploadProgress = sent / total);
          }
        },
      );

      // 2. Submit to repository
      await ref.read(trustRepositoryProvider).submitStudentVerification(
        user.uid,
        imageUrl,
      );

      // 3. Invalidate provider to force a fresh fetch of the verification status
      ref.invalidate(studentVerificationProvider);
      
      // Also update the appUserProvider to reflect the 'pending' status immediately if needed
      // (The repository already updates the user doc, but triggering a refresh helps)
      ref.invalidate(appUserProvider);

      if (mounted) {
        // Pop first, then show snackbar so it appears on the parent screen
        router.pop();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Verification submitted successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Submission failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final verificationAsync = ref.watch(studentVerificationProvider);
    final user = ref.watch(appUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text('Student Verification', 
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          )),
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            verificationAsync.when(
              data: (v) {
                final isResubmit = v?.status == StudentVerificationStatus.resubmissionRequested || user?.studentStatus == 'resubmissionRequested';
                final isExpired = v?.status == StudentVerificationStatus.expired || user?.studentStatus == 'expired';
                final isRejected = v?.status == StudentVerificationStatus.rejected || user?.studentStatus == 'rejected';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isResubmit || isExpired || isRejected ? 'Update Enrollment' : 'Confirm your enrollment',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isResubmit && v?.rejectionReason != null) 
                      _buildAlert(context, 'Correction Needed', v!.rejectionReason!, Colors.orange)
                    else if (isExpired)
                      _buildAlert(context, 'ID Expired', 'Your previous student verification has expired. Please upload a current Student ID.', Colors.orange)
                    else if (isRejected && v?.rejectionReason != null)
                      _buildAlert(context, 'Previously Rejected', v!.rejectionReason!, theme.colorScheme.error)
                    else
                      Text(
                        'Upload a clear photo of your Student ID card. This helps us ensure that UniHub remains a safe community for verified students.',
                        style: TextStyle(
                          fontSize: 15,
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                  ],
                );
              },
              loading: () => const SizedBox(height: 80),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 32),
            
            // Image Picker Area
            GestureDetector(
              onTap: _isSubmitting ? null : _pickImage,
              child: Container(
                width: double.infinity,
                height: 240,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _imageFile != null ? const Color(0xFF10B981) : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    width: 2,
                    style: _imageFile == null ? BorderStyle.solid : BorderStyle.none,
                  ),
                ),
                child: _imageFile != null
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.file(
                              _imageFile!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: CircleAvatar(
                              backgroundColor: Colors.black.withOpacity(0.5),
                              child: IconButton(
                                icon: const Icon(Icons.edit, color: Colors.white),
                                onPressed: _pickImage,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          Text(
                            'Tap to upload ID photo',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'JPG or PNG, max 5MB',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            _buildRequirementItem(context, Icons.check_circle_outline, 'Ensure your full name is visible'),
            _buildRequirementItem(context, Icons.check_circle_outline, 'University name must be clearly readable'),
            _buildRequirementItem(context, Icons.check_circle_outline, 'ID card should be valid/not expired'),
            
            const SizedBox(height: 48),

            if (_isSubmitting) ...[
              LinearProgressIndicator(
                value: _uploadProgress,
                backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Uploading Document: ${(_uploadProgress * 100).toInt()}%',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (_imageFile == null || _isSubmitting) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Submit for Review',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlert(BuildContext context, String title, String message, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(fontSize: 13, color: color.withValues(alpha: 0.9), height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF10B981)),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
