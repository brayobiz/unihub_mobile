import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../auth/shared/providers.dart';
import 'package:unihub_mobile/features/housing/domain/models/roommate_profile.dart';
import 'package:unihub_mobile/features/housing/shared/providers.dart';

class AddRoommateScreen extends ConsumerStatefulWidget {
  const AddRoommateScreen({super.key});

  @override
  ConsumerState<AddRoommateScreen> createState() => _AddRoommateScreenState();
}

class _AddRoommateScreenState extends ConsumerState<AddRoommateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _budgetController = TextEditingController();
  final _locationController = TextEditingController();
  final _bioController = TextEditingController();
  
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
        gender: user.username ?? 'Mixed', // Using username as placeholder if gender not in model yet
        lifestyle: _selectedLifestyle,
        bio: _bioController.text.trim(),
        profileImage: user.photoUrl ?? '',
        createdAt: DateTime.now(),
      );

      await ref.read(housingRepositoryProvider).createRoommateProfile(profile);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Roommate profile posted!')));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Find a Roommate', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionLabel('Your Requirements'),
              _buildTextField(
                controller: _budgetController,
                label: 'Monthly Budget (KES)',
                hint: 'e.g. 10000',
                keyboardType: TextInputType.number,
                prefixIcon: Icons.payments_outlined,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _locationController,
                label: 'Preferred Location',
                hint: 'e.g. Near West Gate, Juja',
                prefixIcon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 32),
              _buildSectionLabel('Lifestyle & Preferences'),
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
                    selectedColor: Colors.indigo.shade100,
                    checkmarkColor: Colors.indigo,
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              _buildTextField(
                controller: _bioController,
                label: 'About You',
                hint: 'Describe yourself and what you look for in a roommate...',
                maxLines: 4,
              ),
              const SizedBox(height: 40),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: Colors.indigo,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    IconData? prefixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20, color: Colors.indigo.shade300) : null,
            filled: true,
            fillColor: const Color(0xFFF8F9FB),
            contentPadding: const EdgeInsets.all(18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: _isLoading ? null : _submit,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.indigo,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('Post Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
