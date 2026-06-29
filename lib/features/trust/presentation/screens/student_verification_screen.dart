import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
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
    if (_imageFile == null) return;

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
          setState(() => _uploadProgress = sent / total);
        },
      );

      // 2. Submit to repository
      await ref.read(trustRepositoryProvider).submitStudentVerification(
        user.uid,
        imageUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification submitted successfully!'),
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
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Student Verification', 
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Confirm your enrollment',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E293B),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Upload a clear photo of your Student ID card. This helps us ensure that UniHub remains a safe community for verified students.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.blueGrey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            
            // Image Picker Area
            GestureDetector(
              onTap: _isSubmitting ? null : _pickImage,
              child: Container(
                width: double.infinity,
                height: 240,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
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
                          Icon(Icons.add_a_photo_outlined, size: 48, color: Colors.blueGrey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'Tap to upload ID photo',
                            style: TextStyle(
                              color: Colors.blueGrey.shade400,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'JPG or PNG, max 5MB',
                            style: TextStyle(
                              color: Colors.blueGrey.shade300,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            _buildRequirementItem(Icons.check_circle_outline, 'Ensure your full name is visible'),
            _buildRequirementItem(Icons.check_circle_outline, 'University name must be clearly readable'),
            _buildRequirementItem(Icons.check_circle_outline, 'ID card should be valid/not expired'),
            
            const SizedBox(height: 48),

            if (_isSubmitting) ...[
              LinearProgressIndicator(
                value: _uploadProgress,
                backgroundColor: const Color(0xFFF1F5F9),
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Uploading Document: ${(_uploadProgress * 100).toInt()}%',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700),
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

  Widget _buildRequirementItem(IconData icon, String text) {
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
              color: Colors.blueGrey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
