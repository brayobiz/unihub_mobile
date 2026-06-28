import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import 'package:unihub_mobile/features/auth/domain/models/app_user.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/trust/domain/models/professional_role.dart';
import 'package:unihub_mobile/features/trust/domain/models/verification_application.dart';
import 'package:unihub_mobile/features/trust/presentation/providers/trust_providers.dart';
import 'package:unihub_mobile/features/housing/presentation/controllers/plug_application_controller.dart';

class BecomePlugScreen extends ConsumerStatefulWidget {
  const BecomePlugScreen({super.key});

  @override
  ConsumerState<BecomePlugScreen> createState() => _BecomePlugScreenState();
}

class _BecomePlugScreenState extends ConsumerState<BecomePlugScreen> {
  late PageController _pageController;
  
  final _introController = TextEditingController();
  final _areasController = TextEditingController();
  final _additionalInfoController = TextEditingController();

  final _professionalFormKey = GlobalKey<FormState>();
  final _experienceFormKey = GlobalKey<FormState>();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final appState = ref.read(plugApplicationControllerProvider);
    _pageController = PageController(initialPage: appState.currentStep);
    
    _introController.text = appState.intro;
    _areasController.text = appState.areasServed;
    _additionalInfoController.text = appState.additionalInfo;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _introController.dispose();
    _areasController.dispose();
    _additionalInfoController.dispose();
    super.dispose();
  }

  void _syncState() {
    final step = ref.read(plugApplicationControllerProvider).currentStep;
    final notifier = ref.read(plugApplicationControllerProvider.notifier);
    
    if (step == 1) {
      notifier.updateProfessional(
        intro: _introController.text.trim(),
        areas: _areasController.text.trim(),
      );
    } else if (step == 2) {
      notifier.updateExperience(
        additionalInfo: _additionalInfoController.text.trim(),
      );
    }
  }

  void _nextPage() {
    _syncState();
    final currentStep = ref.read(plugApplicationControllerProvider).currentStep;

    if (currentStep == 1 && !_professionalFormKey.currentState!.validate()) return;
    if (currentStep == 2 && !_experienceFormKey.currentState!.validate()) return;

    if (currentStep < 4) {
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

      final application = VerificationApplication(
        id: '${user.uid}_housing_plug',
        userId: user.uid,
        role: ProfessionalRole.housePlug,
        status: VerificationStatus.pending,
        fullName: user.fullName,
        phoneNumber: user.phoneNumber ?? '',
        createdAt: DateTime.now(),
        metadata: {
          'type': 'role_activation',
          'professionalIntro': state.intro,
          'primaryCampus': state.selectedCampus ?? user.campus ?? 'Unknown',
          'areasServed': areas,
          'hasExperience': state.hasExperience,
          'experienceLevel': state.experienceLevel,
          'additionalInfo': state.additionalInfo,
          'platformVerified': user.isStudentVerified,
        },
      );

      await ref.read(trustRepositoryProvider).submitProfessionalApplication(application);

      if (mounted) {
        ref.read(plugApplicationControllerProvider.notifier).updateStep(5);
        _pageController.jumpToPage(5);
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
    debugPrint('🛠 Building BecomePlugScreen');
    final appUserAsync = ref.watch(appUserProvider);
    final appState = ref.watch(plugApplicationControllerProvider);
    final currentStep = appState.currentStep;

    return appUserAsync.when(
      data: (user) {
        try {
          if (user == null) {
            return const Scaffold(body: Center(child: Text('Please log in to apply.')));
          }

          if (currentStep == 5) return _buildSuccessScreen();

          return WillPopScope(
            onWillPop: () async {
              if (currentStep == 0) return true;
              final result = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Discard Application?'),
                  content: const Text('You are leaving the Housing Plug application. Your progress will be reset.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep Editing')),
                    TextButton(
                      onPressed: () {
                        ref.read(plugApplicationControllerProvider.notifier).reset();
                        Navigator.pop(context, true);
                      }, 
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
                      onPressed: () {
                         ref.read(plugApplicationControllerProvider.notifier).reset();
                         context.pop();
                      },
                    ),
                title: currentStep > 0
                  ? Text(
                      'Step $currentStep of 4',
                      style: const TextStyle(
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
                  if (currentStep > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: LinearProgressIndicator(
                        value: currentStep / 4,
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
                        _buildIntroStep(user),
                        _buildProfessionalStep(user),
                        _buildExperienceStep(),
                        _buildReviewStep(user),
                        const SizedBox.shrink(), // Success placeholder
                      ],
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: _buildBottomBar(currentStep),
            ),
          );
        } catch (e, stack) {
          debugPrint('❌ Error in BecomePlugScreen: $e\n$stack');
          return Scaffold(body: Center(child: SelectableText('Internal Error: $e\n$stack')));
        }
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
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
            onPressed: _isSubmitting ? null : (currentStep == 3 ? _submit : _nextPage),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1677F2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isSubmitting
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    currentStep == 3 ? 'Submit Application' : 'Continue',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
          ),
        ),
      ),
    );
  }

  // --- Step 0: Intro & Prerequisite Check ---
  Widget _buildIntroStep(AppUser user) {
    final isStudentVerified = user.isStudentVerified;
    final isIdentityVerified = user.isIdentityVerified;
    final isVerified = isStudentVerified && isIdentityVerified;

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
            'Housing Plug Network',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Join our professional network of housing specialists and help students find their perfect home away from home.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              color: const Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          _buildInfoTile(
            Icons.verified_user_outlined,
            'Role Activation',
            'This application activates your professional role. Identity verification is managed by the UniHub Trust Engine.',
          ),
          const SizedBox(height: 20),
          _buildInfoTile(
            Icons.business_center_outlined,
            'Professional Tools',
            'Manage property listings, track leads, and build your reputation as a trusted provider.',
          ),
          const SizedBox(height: 32),
          
          // Prerequisite Notice
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isVerified ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isVerified ? const Color(0xFFBBF7D0) : const Color(0xFFFEE2E2)),
            ),
            child: Row(
              children: [
                Icon(
                  isVerified ? Icons.check_circle : Icons.warning_rounded,
                  color: isVerified ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isVerified
                        ? 'Universal Platform Verification complete. You are ready to apply for the Housing Plug role.'
                        : !isIdentityVerified 
                          ? 'UniHub Identity Verification is required before joining the Housing Plug Network.'
                          : 'UniHub Student Verification is required before joining the Housing Plug Network.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isVerified ? const Color(0xFF166534) : const Color(0xFF991B1B),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton(
              onPressed: isVerified 
                ? _nextPage 
                : () => context.push(!isIdentityVerified ? '/verify-identity' : '/trust-center'),
              style: FilledButton.styleFrom(
                backgroundColor: isVerified ? const Color(0xFF1677F2) : const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: Text(
                isVerified ? 'Apply for Role' : 'Complete Verification First',
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

  // --- Step 1: Professional Profile ---
  Widget _buildProfessionalStep(AppUser user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _professionalFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Professional Profile', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Tell students about your professional focus and service areas.', 
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B))),
            const SizedBox(height: 32),
            _buildTextField(
              controller: _introController,
              label: 'Professional Introduction',
              hint: 'e.g. Dedicated housing specialist helping students find affordable hostels since 2021.',
              maxLines: 4,
              validator: (v) {
                if (v!.trim().length < 20) return 'Please provide a more detailed introduction (min 20 chars)';
                return null;
              },
            ),
            const SizedBox(height: 24),
            _buildCampusDropdown(user),
            const SizedBox(height: 24),
            _buildTextField(
              controller: _areasController,
              label: 'Areas Served',
              hint: 'e.g. Juja South, Gate C, Bypass (separate with commas)',
              validator: (v) => v!.trim().isEmpty ? 'Please list at least one area' : null,
            ),
          ],
        ),
      ),
    );
  }

  // --- Step 2: Experience ---
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
            Text('Optional professional information to help students trust your expertise.', 
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
            Text('Experience Level', 
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: appState.experienceLevel,
              items: ['Newcomer', '1-2 years', '3+ years'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) {
                if (v != null) {
                  ref.read(plugApplicationControllerProvider.notifier).updateExperience(level: v);
                }
              },
              decoration: _inputDecoration(),
            ),
            const SizedBox(height: 24),
            _buildTextField(
              controller: _additionalInfoController,
              label: 'Additional Information',
              hint: 'Anything else students may find helpful to know about you.',
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  // --- Step 3: Review ---
  Widget _buildReviewStep(AppUser user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review Application', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Review your professional profile before submitting.', 
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B))),
          const SizedBox(height: 32),
          
          // Platform Trust Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Platform Verification', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(user.isStudentVerified == true ? 'Verified as ${user.fullName}' : 'Verification Incomplete', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          _buildReviewCard(),
          const SizedBox(height: 24),
          Text(
            'By submitting, you agree to UniHub\'s Professional Conduct Guidelines for Housing Plugs.',
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
          _buildReviewItem('Introduction', appState.intro.isNotEmpty ? appState.intro : 'Not set', onEdit: () => _goToStep(1)),
          _buildReviewItem('Campus', appState.selectedCampus ?? 'Default Campus', onEdit: () => _goToStep(1)),
          _buildReviewItem('Areas Served', appState.areasServed.isNotEmpty ? appState.areasServed : 'Not set', onEdit: () => _goToStep(1)),
          _buildReviewItem('Experience', '${appState.experienceLevel} (${appState.hasExperience == 'Yes' ? 'Has experience' : 'Newcomer'})', isLast: true, onEdit: () => _goToStep(2)),
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

  // --- Step 5: Success Screen ---
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
                'Application Submitted',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              Text(
                'Your request to join the Housing Plug Network is now being reviewed. Since you are already verified, this process will be quick.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 16, color: const Color(0xFF64748B), height: 1.5),
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

  Widget _buildCampusDropdown(AppUser user) {
    final appState = ref.watch(plugApplicationControllerProvider);
    
    final String currentCampus = appState.selectedCampus ?? user.campus ?? 'Unknown University';
    
    final Set<String> itemsSet = {
      currentCampus,
      if (user.campus != null && user.campus!.isNotEmpty) user.campus!,
      if (user.university != null && user.university!.isNotEmpty) user.university!,
      'Unknown University',
    };
    final List<String> items = itemsSet.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Primary Campus Served', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: items.contains(currentCampus) ? currentCampus : items.first,
          items: items
              .map((String c) => DropdownMenuItem<String>(
                    value: c, 
                    child: Text(c, style: const TextStyle(fontSize: 15)),
                  ))
              .toList(),
          onChanged: (String? v) {
            if (v != null) {
              ref.read(plugApplicationControllerProvider.notifier).updateProfessional(campus: v);
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
