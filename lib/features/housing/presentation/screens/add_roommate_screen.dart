import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:unihub_mobile/core/widgets/creation_success_dialog.dart';
import '../../../auth/shared/providers.dart';
import 'package:unihub_mobile/features/housing/domain/models/roommate_profile.dart';
import 'package:unihub_mobile/features/housing/domain/models/housing_listing.dart';
import 'package:unihub_mobile/features/housing/shared/providers.dart';

class AddRoommateScreen extends ConsumerStatefulWidget {
  final HousingListing? targetListing;
  const AddRoommateScreen({super.key, this.targetListing});

  @override
  ConsumerState<AddRoommateScreen> createState() => _AddRoommateScreenState();
}

class _AddRoommateScreenState extends ConsumerState<AddRoommateScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _budgetController;
  late final TextEditingController _locationController;
  final _bioController = TextEditingController();
  String _selectedGender = 'Mixed';
  final List<String> _genderOptions = ['Mixed', 'Male', 'Female'];

  @override
  void initState() {
    super.initState();
    _budgetController = TextEditingController();
    _locationController = TextEditingController(text: widget.targetListing?.location);
    _bioController.text = widget.targetListing != null 
          ? "Looking for a roommate for ${widget.targetListing!.title} at ${widget.targetListing!.location}. "
          : "";
  }
  
  final List<String> _selectedLifestyle = [];
  final List<String> _lifestyleOptions = [
    'Early Bird', 'Night Owl', 'Non-smoker', 'Clean Freak', 
    'Studious', 'Social', 'Quiet', 'Pet Friendly'
  ];

  bool _isLoading = false;

  @override
  void dispose() {
    _budgetController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _handleBack() async {
    final bool isDirty = _budgetController.text.isNotEmpty || 
                        _locationController.text.isNotEmpty || 
                        _bioController.text.isNotEmpty;
    
    if (!isDirty) {
      context.pop();
      return;
    }

    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (proceed == true && mounted) {
      context.pop();
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final profile = RoommateProfile(
        id: const Uuid().v4(),
        userId: user.uid,
        name: user.fullName,
        university: user.university ?? 'Unknown',
        campus: user.campus ?? 'Main Campus',
        course: user.course ?? 'General',
        yearOfStudy: int.tryParse(user.yearOfStudy ?? '1') ?? 1,
        budget: double.tryParse(_budgetController.text.trim()) ?? 0.0,
        preferredLocation: _locationController.text.trim(),
        gender: _selectedGender,
        lifestyle: _selectedLifestyle,
        bio: _bioController.text.trim(),
        profileImage: user.photoUrl ?? '',
        createdAt: DateTime.now(),
      );

      await ref.read(housingRepositoryProvider).createRoommateProfile(profile);
      
      if (mounted) {
        CreationSuccessDialog.show(
          context,
          title: 'Profile Posted!',
          message: 'Your roommate profile is now visible to other students looking for houses.',
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: Text('List Roommate Profile', 
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          foregroundColor: theme.colorScheme.onSurface,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface, size: 20),
            onPressed: _handleBack,
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionLabel(context, 'Your Requirements', Icons.assignment_outlined),
                const SizedBox(height: 16),
                _buildTextField(
                  context,
                  controller: _budgetController,
                  label: 'Monthly Budget (KES)',
                  hint: 'e.g. 10000',
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.payments_outlined,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  context,
                  controller: _locationController,
                  label: 'Preferred Location',
                  hint: 'e.g. Near West Gate, Juja',
                  prefixIcon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 20),
                _buildGenderDropdown(),
                const SizedBox(height: 32),
                _buildSectionLabel(context, 'Lifestyle & Preferences', Icons.interests_outlined),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _lifestyleOptions.map((opt) {
                    final isSelected = _selectedLifestyle.contains(opt);
                    return FilterChip(
                      label: Text(opt),
                      selected: isSelected,
                      onSelected: (val) {
                        setState(() {
                          if (val) _selectedLifestyle.add(opt);
                          else _selectedLifestyle.remove(opt);
                        });
                      },
                      selectedColor: theme.colorScheme.primary.withOpacity(0.1),
                      checkmarkColor: theme.colorScheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                _buildSectionLabel(context, 'Bio', Icons.person_outline_rounded),
                const SizedBox(height: 16),
                _buildTextField(
                  context,
                  controller: _bioController,
                  label: 'About You',
                  hint: 'Describe yourself and what you look for in a roommate...',
                  maxLines: 4,
                ),
                const SizedBox(height: 40),
                if (_isLoading)
                  Column(
                    children: [
                      LinearProgressIndicator(color: theme.colorScheme.primary, minHeight: 6, borderRadius: BorderRadius.circular(4)),
                      const SizedBox(height: 24),
                    ],
                  ),
                _buildSubmitButton(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your Gender / Preference', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedGender,
          items: _genderOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
          onChanged: (v) => setState(() => _selectedGender = v!),
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            contentPadding: const EdgeInsets.all(18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5))),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    IconData? prefixIcon,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20, color: theme.colorScheme.primary.withOpacity(0.5)) : null,
            filled: true,
            fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            contentPadding: const EdgeInsets.all(18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5))),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: _isLoading ? null : _submit,
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('Post Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
