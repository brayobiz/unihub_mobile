import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:unihub_mobile/features/auth/domain/models/app_user.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/trust/domain/models/identity_verification.dart';
import 'package:unihub_mobile/features/trust/presentation/providers/trust_providers.dart';
import 'package:unihub_mobile/features/shared/storage_repository.dart';

class IdentityVerificationScreen extends ConsumerStatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  ConsumerState<IdentityVerificationScreen> createState() => _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState extends ConsumerState<IdentityVerificationScreen> {
  File? _idFile;
  File? _selfieFile;
  bool _isSubmitting = false;
  double _uploadProgress = 0;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _checkLostData();
  }

  Future<void> _checkLostData() async {
    if (Platform.isAndroid) {
      final LostDataResponse response = await _picker.retrieveLostData();
      if (response.isEmpty) return;
      if (response.file != null) {
        setState(() {
          // Note: In a real app we might need to know if it was a selfie or ID
          // For now, we'll try to guess or just set it to ID by default if both null
          if (_idFile == null) {
            _idFile = File(response.file!.path);
          } else if (_selfieFile == null) {
            _selfieFile = File(response.file!.path);
          }
        });
      }
    }
  }

  Future<void> _pickImage(bool isSelfie) async {
    // Explicitly check for camera permission on Android/iOS when using camera
    if (isSelfie) {
      final status = await Permission.camera.request();
      if (status.isPermanentlyDenied) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Camera Permission'),
              content: const Text('Camera access is required for selfies. Please enable it in settings.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                TextButton(onPressed: () {
                  openAppSettings();
                  Navigator.pop(ctx);
                }, child: const Text('Settings')),
              ],
            ),
          );
        }
        return;
      }
      if (!status.isGranted) return;
    }

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: isSelfie ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1800, // Prevent OOM by constraining large images
        maxHeight: 1800,
        preferredCameraDevice: isSelfie ? CameraDevice.front : CameraDevice.rear,
      );

      if (pickedFile != null) {
        setState(() {
          if (isSelfie) {
            _selfieFile = File(pickedFile.path);
          } else {
            _idFile = File(pickedFile.path);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing image: $e')),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (_idFile == null || _selfieFile == null || _isSubmitting) return;

    // Capture services before async gap
    final messenger = ScaffoldMessenger.of(context);
    final router = Navigator.of(context);

    setState(() {
      _isSubmitting = true;
      _uploadProgress = 0;
    });

    try {
      final user = ref.read(appUserProvider).valueOrNull;
      if (user == null) throw Exception('User not logged in');

      final storage = ref.read(storageRepositoryProvider);

      // 1. Upload ID
      final idUrl = await storage.uploadFile(
        path: 'verifications/identity/ids',
        id: 'id_${user.uid}_${DateTime.now().millisecondsSinceEpoch}',
        file: _idFile!,
        isPrivate: true,
        onProgress: (sent, total) {
          if (mounted) {
            setState(() => _uploadProgress = (sent / total) * 0.5);
          }
        },
      );

      // 2. Upload Selfie
      final selfieUrl = await storage.uploadFile(
        path: 'verifications/identity/selfies',
        id: 'selfie_${user.uid}_${DateTime.now().millisecondsSinceEpoch}',
        file: _selfieFile!,
        isPrivate: true,
        onProgress: (sent, total) {
          if (mounted) {
            setState(() => _uploadProgress = 0.5 + (sent / total) * 0.5);
          }
        },
      );

      // 3. Submit to repository
      await ref.read(trustRepositoryProvider).submitIdentityVerification(
        user.uid,
        idUrl,
        selfieUrl,
      );

      // 4. Invalidate provider to force a fresh fetch
      ref.invalidate(identityVerificationProvider);
      ref.invalidate(appUserProvider);

      if (mounted) {
        // Pop first, then show snackbar
        router.pop();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Identity verification submitted!'),
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identityAsync = ref.watch(identityVerificationProvider);
    final user = ref.watch(appUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text('Platform Identity', 
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
            identityAsync.when(
              data: (v) {
                final isResubmit = v?.status == IdentityVerificationStatus.resubmissionRequested || user?.identityStatus == 'resubmissionRequested';
                final isRejected = v?.status == IdentityVerificationStatus.rejected || user?.identityStatus == 'rejected';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isResubmit || isRejected ? 'Update Identity' : 'Identity Verification',
                      style: TextStyle(
                        fontSize: 24, 
                        fontWeight: FontWeight.w900, 
                        color: theme.colorScheme.onSurface
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isResubmit && v?.rejectionReason != null)
                      _buildAlert(context, 'Correction Needed', v!.rejectionReason!, Colors.orange)
                    else if (isRejected && v?.rejectionReason != null)
                      _buildAlert(context, 'Previously Rejected', v!.rejectionReason!, theme.colorScheme.error)
                    else
                      Text(
                        'Verify your legal identity once to unlock professional roles across the entire UniHub platform.',
                        style: TextStyle(
                          fontSize: 15, 
                          color: theme.colorScheme.onSurfaceVariant, 
                          height: 1.5
                        ),
                      ),
                  ],
                );
              },
              loading: () => const SizedBox(height: 80),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 32),
            
            _buildUploadCard(
              context,
              title: 'National ID / Driver\'s License',
              subtitle: 'Clear photo of your official identification',
              file: _idFile,
              onTap: () => _pickImage(false),
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 20),
            _buildUploadCard(
              context,
              title: 'Live Selfie',
              subtitle: 'Face confirmation to match your ID',
              file: _selfieFile,
              onTap: () => _pickImage(true),
              icon: Icons.face_retouching_natural_rounded,
              isCamera: true,
            ),
            
            const SizedBox(height: 48),
            _buildRequirements(context),
            const SizedBox(height: 48),
            
            if (_isSubmitting) ...[
              LinearProgressIndicator(
                value: _uploadProgress,
                backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Uploading Documents: ${(_uploadProgress * 100).toInt()}%',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (_idFile == null || _selfieFile == null || _isSubmitting) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Submit Verification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _buildUploadCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    File? file,
    required VoidCallback onTap,
    required IconData icon,
    bool isCamera = false,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: _isSubmitting ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: file != null ? const Color(0xFF10B981) : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: (file != null ? const Color(0xFF10B981) : theme.colorScheme.primary).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: file != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(file, fit: BoxFit.cover),
                    )
                  : Icon(icon, color: theme.colorScheme.primary, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 4),
                  Text(file != null ? 'Document ready' : subtitle, 
                    style: TextStyle(color: file != null ? const Color(0xFF059669) : theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
            if (file != null)
              const Icon(Icons.check_circle, color: Color(0xFF10B981))
            else
              Icon(Icons.add_a_photo_outlined, color: theme.colorScheme.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirements(BuildContext context) {
    return Column(
      children: [
        _requirementItem(context, Icons.lightbulb_outline, 'Use a well-lit environment'),
        _requirementItem(context, Icons.document_scanner_outlined, 'Ensure text on ID is legible'),
        _requirementItem(context, Icons.no_photography_outlined, 'No glare or blur on documents'),
      ],
    );
  }

  Widget _requirementItem(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
