import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vacancy submitted! Housing Plugs will be notified.'))
        );
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
        title: Text('Report a Vacancy', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
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
              _buildTypeDropdown(),
              const SizedBox(height: 24),
              _buildTextField(
                controller: _locationController,
                label: 'Location / Area',
                hint: 'e.g. Wendani, Juja South',
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),
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
              const SizedBox(height: 24),
              _buildTextField(
                controller: _descriptionController,
                label: 'Brief Details',
                hint: 'How many rooms? When available? Any special rules?',
                maxLines: 3,
              ),
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
          'Know an available room or moving out?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Submit the details here. A verified Housing Plug will verify and list it for other students.',
          style: TextStyle(color: Colors.blueGrey.shade600, height: 1.5),
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
            : const Text('Submit Vacancy', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      ),
    );
  }
}
