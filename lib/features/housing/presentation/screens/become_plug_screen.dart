import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../auth/shared/providers.dart';
import '../../shared/providers.dart';
import '../controllers/plug_application_controller.dart';
import '../../domain/models/housing_plug_application.dart';
import '../../../shared/storage_repository.dart';

class BecomePlugScreen extends ConsumerStatefulWidget {
  const BecomePlugScreen({super.key});

  @override
  ConsumerState<BecomePlugScreen> createState() => _BecomePlugScreenState();
}

class _BecomePlugScreenState extends ConsumerState<BecomePlugScreen> {
  late PageController _pageController;
  
  // Local controllers to sync with provider state
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _introController = TextEditingController();
  final _areasController = TextEditingController();
  final _experienceController = TextEditingController();

  final _personalFormKey = GlobalKey<FormState>();
  final _professionalFormKey = GlobalKey<FormState>();
  final _experienceFormKey = GlobalKey<FormState>();

  bool _isSubmitting = false;
  bool _isUploadingDoc = false;
  bool _isUploadingPhoto = false;
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    final appState = ref.read(plugApplicationControllerProvider);
    _pageController = PageController(initialPage: appState.currentStep);
    
    // Initialize controllers from state
    _fullNameController.text = appState.fullName;
    _phoneController.text = appState.phoneNumber;
    _introController.text = appState.intro;
    _areasController.text = appState.areasServed;
    _experienceController.text = appState.experienceCount;

    // If state is empty, try to prefill from user profile
    if (appState.fullName.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final user = ref.read(appUserProvider).valueOrNull;
        if (user != null) {
          _fullNameController.text = user.fullName;
          _phoneController.text = user.phoneNumber ?? '';
          ref.read(plugApplicationControllerProvider.notifier).updatePersonal(
            fullName: user.fullName,
            phoneNumber: user.phoneNumber,
            campus: user.campus,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _introController.dispose();
    _areasController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  void _syncState() {
    final step = ref.read(plugApplicationControllerProvider).currentStep;
    final notifier = ref.read(plugApplicationControllerProvider.notifier);
    
    if (step == 1) {
      notifier.updatePersonal(
        fullName: _fullNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      );
    } else if (step == 2) {
      notifier.updateProfessional(
        intro: _introController.text.trim(),
        areas: _areasController.text.trim(),
      );
    } else if (step == 3) {
      notifier.updateExperience(
        count: _experienceController.text.trim(),
      );
    }
  }

  void _nextPage() {
    _syncState();
    final currentStep = ref.read(plugApplicationControllerProvider).currentStep;

    if (currentStep == 1 && !_personalFormKey.currentState!.validate()) return;
    if (currentStep == 2 && !_professionalFormKey.currentState!.validate()) return;
    if (currentStep == 3 && !_experienceFormKey.currentState!.validate()) return;
    if (currentStep == 4) {
      final state = ref.read(plugApplicationControllerProvider);
      if (state.idDocumentPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload your ID document to continue.')),
        );
        return;
      }
    }

    if (currentStep < 5) {
      ref.read(plugApplicationControllerProvider.notifier).updateStep(currentStep + 1);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    _syncState();
    final currentStep = ref.read(plugApplicationControllerProvider).currentStep;
    if (currentStep > 0) {
      ref.read(plugApplicationControllerProvider.notifier).updateStep(currentStep - 1);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (image != null) {
      setState(() => _isUploadingPhoto = true);
      try {
        final user = ref.read(appUserProvider).valueOrNull!;
        final url = await ref.read(storageRepositoryProvider).uploadFile(
          path: 'users/${user.uid}/profile',
          id: 'plug_profile_${const Uuid().v4()}',
          file: File(image.path),
        );
        ref.read(plugApplicationControllerProvider.notifier).updateProfilePhoto(url);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      } finally {
        if (mounted) setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      
      // Check file size (max 5MB)
      if (file.lengthSync() > 5 * 1024 * 1024) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File too large. Maximum size is 5MB.')));
        return;
      }

      setState(() {
        _isUploadingDoc = true;
        _uploadProgress = 0;
      });

      try {
        final user = ref.read(appUserProvider).valueOrNull!;
        final url = await ref.read(storageRepositoryProvider).uploadFile(
          path: 'users/${user.uid}/documents',
          id: 'id_verification_${const Uuid().v4()}',
          file: file,
          onProgress: (sent, total) {
            setState(() => _uploadProgress = sent / total);
          },
        );
        ref.read(plugApplicationControllerProvider.notifier).updateIdDocument(url);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Document upload failed: $e')));
      } finally {
        if (mounted) setState(() => _isUploadingDoc = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      final user = ref.read(appUserProvider).valueOrNull!;
      final state = ref.read(plugApplicationControllerProvider);
      
      final areas = state.areasServed
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final application = HousingPlugApplication(
        id: user.uid,
        userId: user.uid,
        fullName: state.fullName,
        phoneNumber: state.phoneNumber,
        campus: state.selectedCampus ?? user.campus ?? 'Unknown',
        bio: state.intro,
        areasServed: areas,
        experience: state.hasExperience == 'Yes' ? state.experienceCount : 'None',
        idDocumentUrl: state.idDocumentPath,
        profilePhotoUrl: state.profilePhotoPath ?? user.photoUrl,
        createdAt: DateTime.now(),
      );

      await ref.read(housingRepositoryProvider).submitPlugApplication(application);

      if (mounted) {
        // We use step 6 as the success state in the PageView or just show a success widget
        ref.read(plugApplicationControllerProvider.notifier).updateStep(6);
        _pageController.jumpToPage(6);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submission failed: $e. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(plugApplicationControllerProvider);
    final currentStep = appState.currentStep;

    if (currentStep == 6) return _buildSuccessScreen();

    return WillPopScope(
      onWillPop: () async {
        if (currentStep == 0) return true;
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard Application?'),
            content: const Text('Your progress is saved, but you are leaving the application flow.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep Editing')),
              TextButton(
                onPressed: () => Navigator.pop(context, true), 
                child: const Text('Exit', style: TextStyle(color: Colors.red))
              ),
            ],
          ),
        );
        return result ?? false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: currentStep > 0 
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: _prevPage,
              )
            : IconButton(
                icon: const Icon(Icons.close, color: Colors.black),
                onPressed: () => context.pop(),
              ),
          title: currentStep > 0 && currentStep < 6
            ? Text(
                'Step $currentStep of 5',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
          centerTitle: true,
        ),
        body: Column(
          children: [
            if (currentStep > 0 && currentStep < 6)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LinearProgressIndicator(
                  value: currentStep / 5,
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1677F2)),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildIntroStep(),
                  _buildPersonalStep(),
                  _buildProfessionalStep(),
                  _buildExperienceStep(),
                  _buildVerificationStep(),
                  _buildReviewStep(),
                  const SizedBox.shrink(), // Success placeholder
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(currentStep),
      ),
    );
  }

  Widget _buildBottomBar(int currentStep) {
    if (currentStep == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: _isSubmitting || _isUploadingDoc || _isUploadingPhoto ? null : (currentStep == 5 ? _submit : _nextPage),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1677F2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isSubmitting
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    currentStep == 5 ? 'Submit Application' : 'Continue',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
          ),
        ),
      ),
    );
  }

  // --- Step 0: Intro ---
  Widget _buildIntroStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1677F2).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.home_work_rounded, color: Color(0xFF1677F2), size: 40),
          ),
          const SizedBox(height: 24),
          Text(
            'Join the Housing Plug Network',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Become a trusted partner in the UniHub ecosystem and help students find their perfect home away from home.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              color: const Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          _buildInfoTile(
            Icons.verified_user_outlined,
            'Professional Status',
            'Gain a verified badge and professional profile that students trust.',
          ),
          const SizedBox(height: 20),
          _buildInfoTile(
            Icons.business_center_outlined,
            'Business Tools',
            'Access the Plug Dashboard to manage listings, track views, and see leads.',
          ),
          const SizedBox(height: 20),
          _buildInfoTile(
            Icons.security_outlined,
            'Safe Marketplace',
            'We verify every plug to maintain a high-quality, secure network.',
          ),
          const SizedBox(height: 48),
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF94A3B8)),
              const SizedBox(width: 8),
              Text(
                'Application takes approximately 3–5 minutes.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton(
              onPressed: _nextPage,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1677F2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: Text(
                'Start Application',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF1677F2), size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 4),
              Text(subtitle, style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  // --- Step 1: Personal Information ---
  Widget _buildPersonalStep() {
    final appState = ref.watch(plugApplicationControllerProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _personalFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Personal Information', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Tell us who you are. This information will be used for your professional profile.', 
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B))),
            const SizedBox(height: 32),
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _isUploadingPhoto ? null : _pickImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFFF1F5F9),
                      backgroundImage: appState.profilePhotoPath != null 
                        ? NetworkImage(appState.profilePhotoPath!) 
                        : null,
                      child: appState.profilePhotoPath == null 
                        ? const Icon(Icons.person, size: 50, color: Color(0xFF94A3B8)) 
                        : null,
                    ),
                  ),
                  if (_isUploadingPhoto)
                    const Positioned.fill(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _isUploadingPhoto ? null : _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Color(0xFF1677F2), shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildTextField(
              controller: _fullNameController,
              label: 'Full Name',
              hint: 'Your legal name',
              validator: (v) => v!.trim().isEmpty ? 'Please enter your full name' : null,
            ),
            const SizedBox(height: 24),
            _buildTextField(
              controller: _phoneController,
              label: 'Phone Number',
              hint: 'e.g. 0712345678',
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v!.isEmpty) return 'Required for verification';
                if (!RegExp(r'^(?:[+0]9)?[0-9]{10,12}$').hasMatch(v.replaceAll(' ', ''))) {
                  return 'Please enter a valid phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            _buildCampusDropdown(),
          ],
        ),
      ),
    );
  }

  // --- Step 2: Professional Information ---
  Widget _buildProfessionalStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _professionalFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Professional Information', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Help students trust you by sharing your professional focus.', 
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B))),
            const SizedBox(height: 32),
            _buildTextField(
              controller: _introController,
              label: 'Professional Introduction',
              hint: 'e.g. Dedicated housing specialist helping students find affordable hostels since 2021.',
              maxLines: 4,
              validator: (v) {
                if (v!.trim().length < 20) return 'Please provide a more detailed introduction (min 20 chars)';
                if (v.trim().length > 500) return 'Introduction is too long (max 500 chars)';
                return null;
              },
            ),
            const SizedBox(height: 24),
            _buildTextField(
              controller: _areasController,
              label: 'Areas Served',
              hint: 'e.g. Juja South, Gate C, Bypass (separate with commas)',
              validator: (v) => v!.trim().isEmpty ? 'Please list at least one area' : null,
            ),
            const SizedBox(height: 12),
            Text(
              'Specify the neighborhoods or campuses where you primarily operate.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  // --- Step 3: Experience ---
  Widget _buildExperienceStep() {
    final appState = ref.watch(plugApplicationControllerProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _experienceFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Experience', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('We welcome both experienced agents and newcomers. This helps us tailor your onboarding.', 
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B))),
            const SizedBox(height: 32),
            Text('Have you previously helped students find accommodation?', 
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: appState.hasExperience,
              items: ['Yes', 'No'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) {
                if (v != null) {
                  ref.read(plugApplicationControllerProvider.notifier).updateExperience(hasExperience: v);
                }
              },
              decoration: _inputDecoration(),
            ),
            const SizedBox(height: 24),
            if (appState.hasExperience == 'Yes') ...[
              _buildTextField(
                controller: _experienceController,
                label: 'Approximately how many students have you helped?',
                hint: 'e.g. 15',
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v!.isEmpty) return 'Please provide a number';
                  if (int.tryParse(v) == null) return 'Please enter a valid number';
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- Step 4: Verification ---
  Widget _buildVerificationStep() {
    final appState = ref.watch(plugApplicationControllerProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Verification', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('We verify every Housing Plug to help create a trusted and safe housing marketplace for students.', 
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B))),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Icon(
                  appState.idDocumentPath != null ? Icons.check_circle_rounded : Icons.shield_rounded, 
                  color: appState.idDocumentPath != null ? Colors.green : const Color(0xFF1677F2), 
                  size: 48
                ),
                const SizedBox(height: 16),
                Text(
                  appState.idDocumentPath != null ? 'Document Uploaded' : 'ID Verification Required',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  appState.idDocumentPath != null 
                    ? 'Your document has been uploaded successfully and is ready for review.'
                    : 'Please upload a clear photo of your National ID or Student ID to proceed with your application.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF64748B), height: 1.5),
                ),
                const SizedBox(height: 24),
                if (_isUploadingDoc) ...[
                  LinearProgressIndicator(value: _uploadProgress),
                  const SizedBox(height: 12),
                  Text('${(_uploadProgress * 100).toInt()}% uploaded', style: const TextStyle(fontSize: 12)),
                ] else
                  OutlinedButton.icon(
                    onPressed: _pickDocument,
                    icon: Icon(appState.idDocumentPath != null ? Icons.refresh_rounded : Icons.upload_file_rounded),
                    label: Text(appState.idDocumentPath != null ? 'Replace Document' : 'Upload Document'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoItem(Icons.lock_outline, 'Your data is encrypted and stored securely.'),
          _buildInfoItem(Icons.visibility_off_outlined, 'Only authorized moderators can view your documents.'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B)))),
        ],
      ),
    );
  }

  // --- Step 5: Review ---
  Widget _buildReviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review Application', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Please review your details before submitting.', 
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B))),
          const SizedBox(height: 32),
          _buildReviewCard(),
          const SizedBox(height: 24),
          Text(
            'By submitting, you agree to UniHub\'s Housing Plug Terms of Service and Professional Conduct Guidelines.',
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF94A3B8), height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard() {
    final appState = ref.watch(plugApplicationControllerProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReviewItem('Name', appState.fullName, onEdit: () => _goToStep(1)),
          _buildReviewItem('Phone', appState.phoneNumber, onEdit: () => _goToStep(1)),
          _buildReviewItem('Campus', appState.selectedCampus ?? 'Not selected', onEdit: () => _goToStep(1)),
          _buildReviewItem('Introduction', appState.intro, onEdit: () => _goToStep(2)),
          _buildReviewItem('Areas Served', appState.areasServed, onEdit: () => _goToStep(2)),
          _buildReviewItem('Experience', appState.hasExperience == 'Yes' ? '${appState.hasExperience} (${appState.experienceCount} students)' : 'No', onEdit: () => _goToStep(3)),
          _buildReviewItem('Verification', appState.idDocumentPath != null ? 'Document uploaded ✓' : 'Missing ✗', isLast: true, onEdit: () => _goToStep(4)),
        ],
      ),
    );
  }

  void _goToStep(int step) {
    ref.read(plugApplicationControllerProvider.notifier).updateStep(step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 500),
      curve: Curves.ease,
    );
  }

  Widget _buildReviewItem(String label, String value, {bool isLast = false, VoidCallback? onEdit}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8))),
                const SizedBox(height: 4),
                Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF1677F2)),
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  // --- Success Screen ---
  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 80),
              ),
              const SizedBox(height: 32),
              Text(
                'Application Received!',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              Text(
                'Thank you for applying to join the UniHub Housing Plug Network. Your application is now being reviewed by our team.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 16, color: const Color(0xFF64748B), height: 1.5),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    _buildSuccessDetail(Icons.update_rounded, 'Review typically takes 24–48 hours.'),
                    const SizedBox(height: 12),
                    _buildSuccessDetail(Icons.notifications_active_outlined, 'You will receive a notification once approved.'),
                    const SizedBox(height: 12),
                    _buildSuccessDetail(Icons.dashboard_customize_outlined, 'Approval grants full access to the Plug Dashboard.'),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: FilledButton(
                  onPressed: () {
                    ref.read(plugApplicationControllerProvider.notifier).reset();
                    context.go('/main');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: Text(
                    'Return to Home',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessDetail(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF475569)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF475569), fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  // --- Helper Widgets ---
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w500),
          decoration: _inputDecoration().copyWith(hintText: hint),
        ),
      ],
    );
  }

  Widget _buildCampusDropdown() {
    final user = ref.watch(appUserProvider).valueOrNull;
    final appState = ref.watch(plugApplicationControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Primary Campus', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: appState.selectedCampus ?? user?.campus,
          items: [user?.university ?? 'Unknown University']
              .map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.plusJakartaSans(fontSize: 15))))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              ref.read(plugApplicationControllerProvider.notifier).updatePersonal(campus: v);
            }
          },
          decoration: _inputDecoration(),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFF1F5F9)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF1677F2), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
    );
  }
}
