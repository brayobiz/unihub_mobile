import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/shared/providers.dart';
import '../../shared/providers.dart';

class BecomePlugScreen extends ConsumerStatefulWidget {
  const BecomePlugScreen({super.key});

  @override
  ConsumerState<BecomePlugScreen> createState() => _BecomePlugScreenState();
}

class _BecomePlugScreenState extends ConsumerState<BecomePlugScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _areasController = TextEditingController();
  String? _selectedCampus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(appUserProvider).valueOrNull;
    if (user != null) {
      _phoneController.text = user.phoneNumber ?? '';
      _selectedCampus = user.campus;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _bioController.dispose();
    _areasController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCampus == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select your primary campus')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(appUserProvider).valueOrNull!;
      final areas = _areasController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      await ref.read(housingRepositoryProvider).becomeHousingPlug(
        userId: user.uid,
        phoneNumber: _phoneController.text.trim(),
        bio: _bioController.text.trim(),
        campus: _selectedCampus!,
        areasServed: areas,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Success! You are now a Housing Plug.')),
        );
        context.pushReplacement('/plug-dashboard');
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
        title: Text('Become a Plug', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
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
              _buildHeader(),
              const SizedBox(height: 32),
              _buildTextField(
                controller: _phoneController,
                label: 'Phone Number',
                hint: 'e.g. 0712345678',
                keyboardType: TextInputType.phone,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              _buildCampusDropdown(),
              const SizedBox(height: 24),
              _buildTextField(
                controller: _areasController,
                label: 'Areas Served',
                hint: 'e.g. Juja South, KM, Bypass (separate with commas)',
                validator: (v) => v!.isEmpty ? 'Please list at least one area' : null,
              ),
              const SizedBox(height: 24),
              _buildTextField(
                controller: _bioController,
                label: 'About You (Short Bio)',
                hint: 'Tell students why they should trust you...',
                maxLines: 3,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 40),
              _buildRequirementsSection(),
              const SizedBox(height: 40),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Start your professional housing business on UniHub.',
          style: TextStyle(fontSize: 16, color: Colors.blueGrey, height: 1.5),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1677F2).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text('PHASE 1: ACTIVATION', style: TextStyle(color: Color(0xFF1677F2), fontSize: 10, fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }

  Widget _buildCampusDropdown() {
    final user = ref.watch(appUserProvider).valueOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Primary Campus', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedCampus,
          items: [user?.university ?? 'Unknown University'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => _selectedCampus = v),
          decoration: _inputDecoration(),
        ),
      ],
    );
  }

  Widget _buildRequirementsSection() {
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
          const Row(
            children: [
              Icon(Icons.verified_user_rounded, color: Color(0xFF1677F2), size: 20),
              SizedBox(width: 12),
              Text('Trust & Safety', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          _requirementItem('Provide accurate property information.'),
          _requirementItem('Respond to student inquiries professionally.'),
          _requirementItem('Maintain high trust scores to stay active.'),
        ],
      ),
    );
  }

  Widget _requirementItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF475569)))),
        ],
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          decoration: _inputDecoration().copyWith(hintText: hint),
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
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFF1F5F9))),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton(
        onPressed: _isLoading ? null : _submit,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF1677F2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: _isLoading 
            ? const CircularProgressIndicator(color: Colors.white) 
            : const Text('Activate Plug Role', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      ),
    );
  }
}
