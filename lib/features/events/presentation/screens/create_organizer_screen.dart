import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/features/events/domain/models/organizer.dart';
import 'package:unihub_mobile/features/events/shared/providers.dart';
import 'package:unihub_mobile/features/events/presentation/controllers/create_organizer_controller.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/core/widgets/creation_success_dialog.dart';
import 'package:unihub_mobile/core/constants/campus_constants.dart';

class CreateOrganizerScreen extends ConsumerStatefulWidget {
  final Organizer? organizer;
  const CreateOrganizerScreen({super.key, this.organizer});

  @override
  ConsumerState<CreateOrganizerScreen> createState() => _CreateOrganizerScreenState();
}

class _CreateOrganizerScreenState extends ConsumerState<CreateOrganizerScreen> {
  late final PageController _pageController;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(createOrganizerControllerProvider(widget.organizer));
    final controller = ref.read(createOrganizerControllerProvider(widget.organizer).notifier);
    final appUser = ref.watch(appUserProvider).valueOrNull;

    // Safety Guard 1: Identity Verification Check
    if (appUser != null && !appUser.isIdentityVerified && !state.isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.goNamed('organizer-onboarding'); 
        }
      });
    }
    
    // Safety Guard 2: If user already has an application and this isn't an edit, redirect
    if (!state.isEditing && widget.organizer == null && appUser != null) {
      final managedOrgs = ref.watch(userManagedOrganizersProvider).valueOrNull ?? [];
      final hasActiveApp = managedOrgs.any((o) => 
        o.verificationStatus == OrganizerVerificationStatus.draft || 
        o.verificationStatus == OrganizerVerificationStatus.submitted || 
        o.verificationStatus == OrganizerVerificationStatus.underReview ||
        o.verificationStatus == OrganizerVerificationStatus.rejected
      );
      
      if (hasActiveApp) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go('/main'); // Redirect away from creation if app exists
          }
        });
      }
    }

    ref.listen<CreateOrganizerState>(createOrganizerControllerProvider(widget.organizer), (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: AppColors.error),
        );
      }
    });

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface, size: 20),
          onPressed: () {
            if (_currentStep > 0) {
              _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              setState(() => _currentStep--);
            } else {
              context.pop();
            }
          },
        ),
        title: Column(
          children: [
            Text(
              widget.organizer == null ? 'Organizer Application' : 'Edit Organizer Profile',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            _buildStepIndicator(),
          ],
        ),
      ),
      body: state.isLoading 
        ? const Center(child: CircularProgressIndicator())
        : PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStep1(state, controller),
              _buildStep2(state, controller),
              _buildStep3(state, controller),
            ],
          ),
      bottomNavigationBar: _buildBottomAction(state, controller),
    );
  }

  Widget _buildStepIndicator() {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final bool isActive = index <= _currentStep;
        return Container(
          width: 24,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isActive ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Widget _buildStep1(CreateOrganizerState state, CreateOrganizerController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Basic Information', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Tell us about your organization or yourself as an organizer. This information will form your Organizer Profile after approval.'),
          const SizedBox(height: 32),
          _buildTextField(
            label: 'Organizer Name',
            hint: 'e.g. Computer Science Society',
            initialValue: state.name,
            onChanged: controller.updateName,
          ),
          const SizedBox(height: 24),
          const Text('Organizer Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: OrganizerType.values.map((type) {
              final isSelected = state.type == type;
              return ChoiceChip(
                label: Text(type.name.toUpperCase()),
                selected: isSelected,
                onSelected: (val) => controller.updateType(type),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          _buildCampusPicker(state, controller),
          const SizedBox(height: 24),
          const Text('Contact Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildTextField(
            label: 'Contact Email',
            hint: 'e.g. contact@mysociety.com',
            initialValue: state.contactEmail,
            onChanged: controller.updateContactEmail,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Contact Phone (Optional)',
            hint: 'e.g. +1 234 567 890',
            initialValue: state.contactPhone,
            onChanged: controller.updateContactPhone,
          ),
          const SizedBox(height: 24),
          _buildTextField(
            label: 'Bio',
            hint: 'Describe what you do...',
            initialValue: state.bio,
            maxLines: 4,
            onChanged: controller.updateBio,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${state.bio.length} / 500 characters',
              style: TextStyle(
                fontSize: 12, 
                color: state.bio.length < 20 ? AppColors.error : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2(CreateOrganizerState state, CreateOrganizerController controller) {
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Branding', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Help students recognize your organization with a logo and banner.'),
          const SizedBox(height: 32),
          
          // Logo Section
          const Text('Logo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: controller.pickLogo,
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                      image: state.logoFile != null 
                        ? DecorationImage(image: FileImage(state.logoFile!), fit: BoxFit.cover)
                        : (state.logoUrl != null 
                            ? DecorationImage(image: NetworkImage(state.logoUrl!), fit: BoxFit.cover)
                            : null),
                    ),
                    child: (state.logoFile == null && state.logoUrl == null)
                        ? Icon(Icons.add_a_photo_outlined, size: 40, color: theme.colorScheme.primary)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.edit_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Banner Section
          const Text('Banner Image (Optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: controller.pickBanner,
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant),
                image: state.bannerFile != null 
                  ? DecorationImage(image: FileImage(state.bannerFile!), fit: BoxFit.cover)
                  : (state.bannerUrl != null 
                      ? DecorationImage(image: NetworkImage(state.bannerUrl!), fit: BoxFit.cover)
                      : null),
              ),
              child: (state.bannerFile == null && state.bannerUrl == null)
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 32, color: theme.colorScheme.primary),
                        const SizedBox(height: 4),
                        const Text('Upload Cover Photo', style: TextStyle(fontSize: 12)),
                      ],
                    )
                  : null,
            ),
          ),

          const SizedBox(height: 32),
          const Text('Social Links', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildTextField(
            label: 'Instagram',
            hint: '@username',
            initialValue: state.socialLinks['instagram'] ?? '',
            onChanged: (val) => controller.updateSocialLink('instagram', val),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Twitter/X',
            hint: '@username',
            initialValue: state.socialLinks['twitter'] ?? '',
            onChanged: (val) => controller.updateSocialLink('twitter', val),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3(CreateOrganizerState state, CreateOrganizerController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Review & Submit', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 32),
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundImage: state.logoFile != null 
                ? FileImage(state.logoFile!) 
                : (state.logoUrl != null ? NetworkImage(state.logoUrl!) : null) as ImageProvider?,
              child: (state.logoFile == null && state.logoUrl == null) ? const Icon(Icons.person, size: 50) : null,
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            title: const Text('Organizer Name'),
            subtitle: Text(state.name.isEmpty ? 'Not set' : state.name),
            leading: const Icon(Icons.business_rounded),
            contentPadding: EdgeInsets.zero,
          ),
          ListTile(
            title: const Text('Organizer Type'),
            subtitle: Text(state.type.name.toUpperCase()),
            leading: const Icon(Icons.category_outlined),
            contentPadding: EdgeInsets.zero,
          ),
          ListTile(
            title: const Text('Target Campus'),
            subtitle: Text(state.campusId.isEmpty ? 'Not set' : CampusConstants.getDisplayName(state.campusId)),
            leading: const Icon(Icons.school_outlined),
            contentPadding: EdgeInsets.zero,
          ),
          if (state.contactEmail.isNotEmpty)
            ListTile(
              title: const Text('Contact Email'),
              subtitle: Text(state.contactEmail),
              leading: const Icon(Icons.email_outlined),
              contentPadding: EdgeInsets.zero,
            ),
          if (state.contactPhone.isNotEmpty)
            ListTile(
              title: const Text('Contact Phone'),
              subtitle: Text(state.contactPhone),
              leading: const Icon(Icons.phone_outlined),
              contentPadding: EdgeInsets.zero,
            ),
          if (state.socialLinks.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Social Presence', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: state.socialLinks.entries.map((e) => Chip(
                avatar: const Icon(Icons.link, size: 16),
                label: Text(e.value),
              )).toList(),
            ),
          ],
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
            Icon(Icons.info_outline, color: Colors.amber),
            const SizedBox(width: 12),
            Expanded(
                  child: Text(
                    'Your application will be reviewed. Once approved, you can start publishing events.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'By becoming an organizer, you agree to Ulify\'s Community Guidelines for events.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({required String label, required String hint, required Function(String) onChanged, String? initialValue, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: initialValue,
          onChanged: (val) {
            onChanged(val);
          },
          maxLines: maxLines,
          maxLength: maxLines > 1 ? 500 : null,
          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildCampusPicker(CreateOrganizerState state, CreateOrganizerController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Campus', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: state.campusId.isEmpty ? null : state.campusId,
          items: CampusConstants.campuses.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
          onChanged: (val) => val != null ? controller.updateCampus(val) : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomAction(CreateOrganizerState state, CreateOrganizerController controller) {
    final theme = Theme.of(context);
    final bool isLastStep = _currentStep >= 2;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  setState(() => _currentStep--);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: state.isLoading ? null : () async {
                if (isLastStep) {
                  final success = await controller.submit();
                  if (success && mounted) {
                    CreationSuccessDialog.show(
                      context,
                      title: 'Application Submitted!',
                      message: 'Your organizer application is now under review. You\'ll be notified once your profile is active.',
                      onDone: () => context.go('/main'), // Go back to main/home
                    );
                  }
                } else {
                  if (controller.validateStep(_currentStep)) {
                    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                    setState(() => _currentStep++);
                  }
                }
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: state.isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(isLastStep ? 'Submit Application' : 'Continue'),
            ),
          ),
        ],
      ),
    );
  }
}
