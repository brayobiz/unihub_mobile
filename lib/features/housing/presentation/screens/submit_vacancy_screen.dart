import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/core/widgets/creation_success_dialog.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/housing_listing.dart';
import '../../domain/models/vacancy_request.dart';
import '../../shared/providers.dart';

class SubmitVacancyScreen extends ConsumerStatefulWidget {
  const SubmitVacancyScreen({super.key});

  @override
  ConsumerState<SubmitVacancyScreen> createState() => _SubmitVacancyScreenState();
}

class _SubmitVacancyScreenState extends ConsumerState<SubmitVacancyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _rentController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  
  HousingType _selectedType = HousingType.hostel;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(appUserProvider).valueOrNull;
    if (user != null) {
      _phoneController.text = user.phoneNumber ?? '';
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _rentController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleBack() async {
    final bool isDirty = _locationController.text.isNotEmpty || 
                        _rentController.text.isNotEmpty || 
                        _descriptionController.text.isNotEmpty;
    
    if (!isDirty) {
      context.pop();
      return;
    }

    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes'),
        content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard', style: TextStyle(color: AppColors.error)),
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
      final request = VacancyRequest(
        id: '',
        providerId: user.uid,
        providerName: user.fullName,
        providerPhone: _phoneController.text.trim(),
        type: _selectedType,
        location: _locationController.text.trim(),
        campus: user.campus ?? 'Main Campus',
        university: user.university ?? 'Unknown University',
        expectedRent: double.tryParse(_rentController.text.trim()) ?? 0.0,
        description: _descriptionController.text.trim(),
        createdAt: DateTime.now(),
      );

      await ref.read(housingRepositoryProvider).submitVacancyRequest(request);
      
      if (mounted) {
        CreationSuccessDialog.show(
          context,
          title: 'Vacancy Reported!',
          message: 'Thank you! A verified Housing Plug will verify these details and list them for other students.',
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
          title: Text('Create Vacancy', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 18)),
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
                _buildHeader(context),
                const SizedBox(height: 32),
                _buildSectionHeader(context, 'Basic Details', Icons.home_work_outlined),
                const SizedBox(height: 16),
                _buildTypeDropdown(),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: _locationController,
                  label: 'Location / Area',
                  hint: 'e.g. Wendani, Juja South',
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 32),
                _buildSectionHeader(context, 'Pricing & Contact', Icons.payments_outlined),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _rentController,
                  label: 'Expected Rent (KES)',
                  hint: 'e.g. 8000',
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final rent = double.tryParse(v);
                    if (rent == null || rent <= 0) return 'Invalid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: _phoneController,
                  label: 'Your Phone Number',
                  hint: '07...',
                  keyboardType: TextInputType.phone,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 32),
                _buildSectionHeader(context, 'Additional Info', Icons.description_outlined),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _descriptionController,
                  label: 'Brief Details',
                  hint: 'How many rooms? When available? Any special rules?',
                  maxLines: 3,
                ),
                const SizedBox(height: 40),
                if (_isLoading)
                  Column(
                    children: [
                      LinearProgressIndicator(color: theme.colorScheme.primary, minHeight: 6, borderRadius: BorderRadius.circular(4)),
                      const SizedBox(height: 24),
                    ],
                  ),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Know an available room or moving out?',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
        ),
        const SizedBox(height: 8),
        Text(
          'Submit the details here. A verified Housing Plug will verify and list it for other students.',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Housing Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<HousingType>(
          value: _selectedType,
          items: HousingType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
          onChanged: (v) => setState(() => _selectedType = v!),
          decoration: _inputDecoration(),
        ),
      ],
    );
  }

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
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: _inputDecoration().copyWith(
            hintText: hint,
            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration() {
    final theme = Theme.of(context);
    return InputDecoration(
      filled: true,
      fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.primary)),
    );
  }

  Widget _buildSubmitButton() {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton(
        onPressed: _isLoading ? null : _submit,
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Create Vacancy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}
