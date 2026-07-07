import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import 'package:unihub_mobile/core/constants/campus_constants.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
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
  final _additionalInfoController = TextEditingController();

  final _identityFormKey = GlobalKey<FormState>();
  
  bool _isSubmitting = false;

  final List<String> _housingSpecialties = [
    'Hostels',
    'Bedsitters',
    'Single Rooms',
    'One Bedrooms',
    'Two Bedrooms',
    'Shared Apartments',
    'Short Stay / Airbnb',
    'Student Houses',
  ];

  final List<String> _commonAreas = [
    'Main Campus',
    'Gate A Area',
    'Gate B Area',
    'Gate C Area',
    'Town Center',
    'Upper Suburbs',
    'Lower Suburbs',
    'Student Village',
  ];

  @override
  void initState() {
    super.initState();
    final appState = ref.read(plugApplicationControllerProvider);
    _pageController = PageController(initialPage: appState.currentStep);
    
    _introController.text = appState.intro;
    _additionalInfoController.text = appState.additionalInfo;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _introController.dispose();
    _additionalInfoController.dispose();
    super.dispose();
  }

  void _syncState() {
    final step = ref.read(plugApplicationControllerProvider).currentStep;
    final notifier = ref.read(plugApplicationControllerProvider.notifier);
    
    if (step == 1) {
      notifier.updateBasicInfo(
        intro: _introController.text.trim(),
      );
    }
  }

  void _nextPage() {
    _syncState();
    final currentStep = ref.read(plugApplicationControllerProvider).currentStep;

    if (currentStep == 1 && !_identityFormKey.currentState!.validate()) return;
    
    // For step 2 and 3, validation could be done on selection count if needed
    if (currentStep == 2) {
      final state = ref.read(plugApplicationControllerProvider);
      if (state.serviceAreas.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one service area'))
        );
        return;
      }
    }
    if (currentStep == 3) {
      final state = ref.read(plugApplicationControllerProvider);
      if (state.specialties.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one accommodation specialty'))
        );
        return;
      }
    }

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
          'serviceAreas': state.serviceAreas,
          'accommodationSpecialties': state.specialties,
          'availabilityStatus': state.availability,
          'preferredContactMethod': state.preferredContact,
          'additionalInfo': state.additionalInfo,
          'identityVerified': user.isIdentityVerified,
          'studentVerified': user.isStudentVerified,
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
    final appUserAsync = ref.watch(appUserProvider);
    final appState = ref.watch(plugApplicationControllerProvider);
    final currentStep = appState.currentStep;

    return appUserAsync.when(
      data: (user) {
        final theme = Theme.of(context);
        if (user == null) {
          return Scaffold(
            backgroundColor: theme.colorScheme.surface,
            body: const Center(child: Text('Please log in to apply.')),
          );
        }

        if (currentStep == 5) return _buildSuccessScreen();

        return WillPopScope(
          onWillPop: () async {
            if (currentStep == 0) return true;
            final result = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Exit Onboarding?'),
                content: const Text('Your professional profile progress will be saved for this session.'),
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
            backgroundColor: theme.colorScheme.surface,
            appBar: AppBar(
              backgroundColor: theme.colorScheme.surface,
              elevation: 0,
              leading: currentStep > 0 
                ? IconButton(
                    icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
                    onPressed: _prevPage,
                  )
                : IconButton(
                    icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
                    onPressed: () {
                       ref.read(plugApplicationControllerProvider.notifier).reset();
                       context.pop();
                    },
                  ),
              title: currentStep > 0
                ? Text(
                    'Step $currentStep of 4',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
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
                      backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildWelcomeStep(user),
                      _buildProfessionalIdentityStep(user),
                      _buildServiceCoverageStep(),
                      _buildSpecialtiesStep(),
                      _buildFinalReviewStep(user),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: _buildBottomBar(currentStep),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildBottomBar(int currentStep) {
    final theme = Theme.of(context);
    if (currentStep == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
            onPressed: _isSubmitting ? null : (currentStep == 4 ? _submit : _nextPage),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isSubmitting
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    currentStep == 4 ? 'Complete Onboarding' : 'Continue',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
          ),
        ),
      ),
    );
  }

  // --- Step 0: Welcome & Prerequisite Check ---
  Widget _buildWelcomeStep(AppUser user) {
    final theme = Theme.of(context);
    final isVerified = user.isIdentityVerified && user.isStudentVerified;
    
    final bool identityPending = user.identityStatus == 'pending';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.home_work_rounded, color: theme.colorScheme.primary, size: 40),
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome to the\nHousing Plug Network',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.2,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'You\'re about to join UniHub\'s community of trusted housing specialists. Let\'s build your professional profile to help students find you.',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          _buildInfoTile(
            Icons.person_pin_outlined,
            'Professional Identity',
            'Tell students who you are and which campus you primarily serve.',
          ),
          const SizedBox(height: 20),
          _buildInfoTile(
            Icons.map_outlined,
            'Service Coverage',
            'Indicate which areas you cover and whether you\'re currently available.',
          ),
          const SizedBox(height: 20),
          _buildInfoTile(
            Icons.house_siding_outlined,
            'Accommodation Specialties',
            'Select the types of student housing you specialize in.',
          ),
          const SizedBox(height: 32),
          
          // Trust Status Check
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isVerified ? Icons.verified_user_rounded : Icons.shield_outlined,
                      color: isVerified ? AppColors.success : theme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Platform Trust Status',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isVerified
                      ? 'Your platform identity is verified. You are eligible to complete your professional housing profile.'
                      : 'To ensure student safety and platform integrity, all professional service providers must complete UniHub Identity Verification before joining the network.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                if (!isVerified && !identityPending) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You will return here automatically once verified.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
                : (identityPending ? null : () => context.push('/trust-center')),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (identityPending) ...[
                    const Icon(Icons.hourglass_empty_rounded, size: 20, color: Colors.white70),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    identityPending 
                        ? 'Verification in Progress...' 
                        : (isVerified ? 'Continue to Professional Profile' : 'Start Housing Plug Journey'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: theme.colorScheme.onSurface)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  // --- Step 1: Professional Identity ---
  Widget _buildProfessionalIdentityStep(AppUser user) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _identityFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Professional Identity', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text('Introduce yourself to the student community and set your primary campus.', 
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 32),
            _buildTextField(
              controller: _introController,
              label: 'Professional Introduction',
              hint: 'Introduce yourself... (e.g., "Hi! I\'m ${user.fullName.split(' ').first}, a housing specialist dedicated to helping students find affordable hostels near Main Campus since 2021.")',
              maxLines: 5,
              validator: (v) {
                if (v!.trim().length < 30) return 'A more detailed introduction helps build trust (min 30 chars)';
                return null;
              },
            ),
            const SizedBox(height: 32),
            _buildCampusDropdown(user),
          ],
        ),
      ),
    );
  }

  // --- Step 2: Service Coverage ---
  Widget _buildServiceCoverageStep() {
    final theme = Theme.of(context);
    final state = ref.watch(plugApplicationControllerProvider);
    final notifier = ref.read(plugApplicationControllerProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Service Coverage', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text('Select the areas where you actively help students find housing.', 
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 32),
          Text('Primary Service Areas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _commonAreas.map((area) {
              final isSelected = state.serviceAreas.contains(area);
              return ChoiceChip(
                label: Text(area),
                selected: isSelected,
                onSelected: (_) => notifier.toggleArea(area),
                selectedColor: theme.colorScheme.primary.withOpacity(0.1),
                labelStyle: TextStyle(
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 40),
          Text('Current Availability', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text('Let students know if you\'re actively taking inquiries.', 
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          _buildChoiceTile(
            title: 'Accepting Inquiries',
            subtitle: 'You are actively helping students find housing right now.',
            icon: Icons.check_circle_outline,
            isSelected: state.availability == 'Available',
            onTap: () => notifier.setAvailability('Available'),
          ),
          const SizedBox(height: 12),
          _buildChoiceTile(
            title: 'Currently Unavailable',
            subtitle: 'You are not taking new student requests at this time.',
            icon: Icons.do_not_disturb_on_outlined,
            isSelected: state.availability == 'Unavailable',
            onTap: () => notifier.setAvailability('Unavailable'),
          ),
        ],
      ),
    );
  }

  // --- Step 3: Specialties & Contact ---
  Widget _buildSpecialtiesStep() {
    final theme = Theme.of(context);
    final state = ref.watch(plugApplicationControllerProvider);
    final notifier = ref.read(plugApplicationControllerProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Specialties & Contact', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text('What types of housing do you specialize in, and how should students reach you?', 
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 32),
          Text('Accommodation Specialties', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _housingSpecialties.map((type) {
              final isSelected = state.specialties.contains(type);
              return ChoiceChip(
                label: Text(type),
                selected: isSelected,
                onSelected: (_) => notifier.toggleSpecialty(type),
                selectedColor: theme.colorScheme.primary.withOpacity(0.1),
                labelStyle: TextStyle(
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 40),
          Text('Preferred Contact Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 16),
          _buildChoiceTile(
            title: 'In-App Chat',
            subtitle: 'Receive messages directly through UniHub Messenger.',
            icon: Icons.chat_bubble_outline_rounded,
            isSelected: state.preferredContact == 'In-App Chat',
            onTap: () => notifier.setPreferredContact('In-App Chat'),
          ),
          const SizedBox(height: 12),
          _buildChoiceTile(
            title: 'WhatsApp',
            subtitle: 'Students can initiate a WhatsApp chat with you.',
            icon: Icons.phone_android_rounded,
            isSelected: state.preferredContact == 'WhatsApp',
            onTap: () => notifier.setPreferredContact('WhatsApp'),
          ),
        ],
      ),
    );
  }

  // --- Step 4: Final Review ---
  Widget _buildFinalReviewStep(AppUser user) {
    final theme = Theme.of(context);
    final state = ref.watch(plugApplicationControllerProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review Your Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text('Take a moment to review how your profile will appear to the community.', 
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 32),
          
          _buildReviewSection(
            'Professional Identity',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewItem('Introduction', state.intro),
                const SizedBox(height: 16),
                _buildReviewItem('Campus', CampusConstants.getDisplayName(state.selectedCampus ?? user.university)),
              ],
            ),
            onEdit: () => _goToStep(1),
          ),
          const SizedBox(height: 24),
          _buildReviewSection(
            'Service Coverage',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewItem('Service Areas', state.serviceAreas.join(', ')),
                const SizedBox(height: 16),
                _buildReviewItem('Availability', state.availability),
              ],
            ),
            onEdit: () => _goToStep(2),
          ),
          const SizedBox(height: 24),
          _buildReviewSection(
            'Specialties & Contact',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewItem('Specialties', state.specialties.join(', ')),
                const SizedBox(height: 16),
                _buildReviewItem('Contact via', state.preferredContact),
              ],
            ),
            onEdit: () => _goToStep(3),
          ),
          
          const SizedBox(height: 32),
          Text(
            'By completing onboarding, you agree to provide accurate housing information and maintain a professional standard of service.',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildReviewSection(String title, Widget content, {required VoidCallback onEdit}) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurfaceVariant)),
              GestureDetector(
                onTap: onEdit,
                child: Text('Edit', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildReviewItem(String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7), letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
      ],
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

  // --- Success Screen ---
  Widget _buildSuccessScreen() {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
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
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 80),
              ),
              const SizedBox(height: 32),
              Text(
                'Onboarding Complete',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              Text(
                'Your Housing Plug profile is being processed. Students will soon be able to find you and your housing specialties.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurfaceVariant, height: 1.5),
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
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: const Text(
                    'Go to Dashboard',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface),
          decoration: _inputDecoration().copyWith(
            hintText: hint,
            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildCampusDropdown(AppUser user) {
    final appState = ref.watch(plugApplicationControllerProvider);
    final campuses = CampusConstants.campuses;
    
    final String currentCampus = appState.selectedCampus ?? user.university ?? campuses.first.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Primary Campus Served', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: campuses.any((c) => c.id == currentCampus) ? currentCampus : campuses.first.id,
          items: campuses
              .map((c) => DropdownMenuItem<String>(
                    value: c.id, 
                    child: Text(c.name, style: const TextStyle(fontSize: 15)),
                  ))
              .toList(),
          onChanged: (String? v) {
            if (v != null) {
              ref.read(plugApplicationControllerProvider.notifier).updateBasicInfo(campus: v);
            }
          },
          decoration: _inputDecoration(),
        ),
      ],
    );
  }

  Widget _buildChoiceTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withOpacity(0.05) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : theme.colorScheme.surfaceVariant.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration() {
    final theme = Theme.of(context);
    return InputDecoration(
      filled: true,
      fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.error, width: 1),
      ),
    );
  }
}
