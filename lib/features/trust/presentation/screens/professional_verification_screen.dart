import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/trust/domain/models/professional_role.dart';
import 'package:unihub_mobile/features/trust/domain/models/verification_application.dart';
import 'package:unihub_mobile/features/trust/presentation/providers/trust_providers.dart';
import 'package:unihub_mobile/features/shared/storage_repository.dart';

class ProfessionalVerificationScreen extends ConsumerStatefulWidget {
  final ProfessionalRole role;

  const ProfessionalVerificationScreen({super.key, required this.role});

  @override
  ConsumerState<ProfessionalVerificationScreen> createState() => _ProfessionalVerificationScreenState();
}

class _ProfessionalVerificationScreenState extends ConsumerState<ProfessionalVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  File? _idDocumentFile;
  File? _selfieFile;
  bool _isSubmitting = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Pre-fill name from user profile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(appUserProvider).valueOrNull;
      if (user != null) {
        _nameController.text = user.fullName;
        _phoneController.text = user.phoneNumber ?? '';
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isSelfie) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: isSelfie ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        if (isSelfie) {
          _selfieFile = File(pickedFile.path);
        } else {
          _idDocumentFile = File(pickedFile.path);
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_idDocumentFile == null || _selfieFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload both ID and selfie'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(appUserProvider).valueOrNull;
      if (user == null) throw Exception('User not logged in');

      final storage = ref.read(storageRepositoryProvider);
      
      // Upload images using Platform Storage Repository
      final idUrl = await storage.uploadFile(
        path: 'verifications/${widget.role.name}/docs',
        id: 'id_${user.uid}_${DateTime.now().millisecondsSinceEpoch}',
        file: _idDocumentFile!,
      );

      final selfieUrl = await storage.uploadFile(
        path: 'verifications/${widget.role.name}/selfies',
        id: 'selfie_${user.uid}_${DateTime.now().millisecondsSinceEpoch}',
        file: _selfieFile!,
      );

      final application = VerificationApplication(
        id: const Uuid().v4(),
        userId: user.uid,
        role: widget.role,
        status: VerificationStatus.pending,
        createdAt: DateTime.now(),
        fullName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        idDocumentUrl: idUrl,
        selfieUrl: selfieUrl,
      );

      await ref.read(trustRepositoryProvider).submitProfessionalApplication(application);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted successfully!'),
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
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Role Verification', 
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildExplanationHeader(primaryColor),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Personal Details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name (as on ID)',
                      hint: 'Enter your legal name',
                      icon: Icons.person_outline_rounded,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      primaryColor: primaryColor,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      hint: 'Enter your WhatsApp/Phone number',
                      icon: Icons.phone_android_rounded,
                      keyboardType: TextInputType.phone,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      primaryColor: primaryColor,
                    ),
                    
                    const SizedBox(height: 32),
                    const Text(
                      'Identity Verification',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We need to verify your identity to grant you the ${widget.role.label} badge.',
                      style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    
                    _buildUploadTile(
                      title: 'National ID / Driver\'s License',
                      subtitle: 'Upload a clear photo of your official ID',
                      file: _idDocumentFile,
                      onTap: () => _pickImage(false),
                      primaryColor: primaryColor,
                    ),
                    const SizedBox(height: 16),
                    _buildUploadTile(
                      title: 'Live Selfie',
                      subtitle: 'Take a clear photo of your face',
                      file: _selfieFile,
                      onTap: () => _pickImage(true),
                      isCamera: true,
                      primaryColor: primaryColor,
                    ),
                    
                    const SizedBox(height: 48),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'Submit Application',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanationHeader(Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_getRoleIcon(widget.role), color: primaryColor, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            'Become a ${widget.role.label}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Verification adds a badge to your profile, increasing your trust score and credibility across the UniHub community.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.blueGrey.shade600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color primaryColor,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadTile({
    required String title,
    required String subtitle,
    required Color primaryColor,
    File? file,
    required VoidCallback onTap,
    bool isCamera = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: file != null ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: (file != null ? const Color(0xFF10B981) : const Color(0xFFF1F5F9)).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: file != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(file, fit: BoxFit.cover),
                  )
                : Icon(isCamera ? Icons.camera_alt_rounded : Icons.file_upload_outlined, 
                    color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                  ),
                  Text(
                    file != null ? 'File uploaded' : subtitle,
                    style: TextStyle(
                      fontSize: 12, 
                      color: file != null ? const Color(0xFF10B981) : Colors.blueGrey.shade400,
                      fontWeight: file != null ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (file != null)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981))
            else
              Icon(Icons.add_circle_outline_rounded, color: primaryColor),
          ],
        ),
      ),
    );
  }

  IconData _getRoleIcon(ProfessionalRole role) {
    switch (role) {
      case ProfessionalRole.seller: return Icons.shopping_bag_rounded;
      case ProfessionalRole.housePlug: return Icons.home_work_rounded;
      case ProfessionalRole.tutor: return Icons.menu_book_rounded;
      case ProfessionalRole.serviceProvider: return Icons.handyman_rounded;
      case ProfessionalRole.technician: return Icons.memory_rounded;
      case ProfessionalRole.business: return Icons.business_center_rounded;
    }
  }
}
