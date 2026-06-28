import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
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

  Future<void> _pickImage(bool isSelfie) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: isSelfie ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      setState(() {
        if (isSelfie) _selfieFile = File(pickedFile.path);
        else _idFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _submit() async {
    if (_idFile == null || _selfieFile == null) return;

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
        onProgress: (sent, total) {
          setState(() => _uploadProgress = (sent / total) * 0.5);
        },
      );

      // 2. Upload Selfie
      final selfieUrl = await storage.uploadFile(
        path: 'verifications/identity/selfies',
        id: 'selfie_${user.uid}_${DateTime.now().millisecondsSinceEpoch}',
        file: _selfieFile!,
        onProgress: (sent, total) {
          setState(() => _uploadProgress = 0.5 + (sent / total) * 0.5);
        },
      );

      // 3. Submit to repository
      await ref.read(trustRepositoryProvider).submitIdentityVerification(
        user.uid,
        idUrl,
        selfieUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Identity verification submitted!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Platform Identity', 
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Identity Verification',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),
            Text(
              'Verify your legal identity once to unlock professional roles across the entire UniHub platform.',
              style: TextStyle(fontSize: 15, color: Colors.blueGrey.shade600, height: 1.5),
            ),
            const SizedBox(height: 32),
            
            _buildUploadCard(
              title: 'National ID / Driver\'s License',
              subtitle: 'Clear photo of your official identification',
              file: _idFile,
              onTap: () => _pickImage(false),
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 20),
            _buildUploadCard(
              title: 'Live Selfie',
              subtitle: 'Face confirmation to match your ID',
              file: _selfieFile,
              onTap: () => _pickImage(true),
              icon: Icons.face_retouching_natural_rounded,
              isCamera: true,
            ),
            
            const SizedBox(height: 48),
            _buildRequirements(),
            const SizedBox(height: 48),
            
            if (_isSubmitting) ...[
              LinearProgressIndicator(
                value: _uploadProgress,
                backgroundColor: const Color(0xFFF1F5F9),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1677F2)),
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Uploading Documents: ${(_uploadProgress * 100).toInt()}%',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700),
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
                  backgroundColor: const Color(0xFF1677F2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Submit Verification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard({
    required String title,
    required String subtitle,
    File? file,
    required VoidCallback onTap,
    required IconData icon,
    bool isCamera = false,
  }) {
    return GestureDetector(
      onTap: _isSubmitting ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: file != null ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: (file != null ? const Color(0xFF10B981) : const Color(0xFF1677F2)).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: file != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(file, fit: BoxFit.cover),
                    )
                  : Icon(icon, color: const Color(0xFF1677F2), size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(file != null ? 'Document ready' : subtitle, 
                    style: TextStyle(color: file != null ? const Color(0xFF059669) : Colors.blueGrey.shade400, fontSize: 12)),
                ],
              ),
            ),
            if (file != null)
              const Icon(Icons.check_circle, color: Color(0xFF10B981))
            else
              const Icon(Icons.add_a_photo_outlined, color: Color(0xFF1677F2), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirements() {
    return Column(
      children: [
        _requirementItem(Icons.lightbulb_outline, 'Use a well-lit environment'),
        _requirementItem(Icons.document_scanner_outlined, 'Ensure text on ID is legible'),
        _requirementItem(Icons.no_photography_outlined, 'No glare or blur on documents'),
      ],
    );
  }

  Widget _requirementItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey.shade400),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
