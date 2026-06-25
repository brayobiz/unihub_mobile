import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/housing_listing.dart';
import '../../shared/providers.dart';
import '../../../shared/storage_repository.dart';

class AddHousingScreen extends ConsumerStatefulWidget {
  const AddHousingScreen({super.key});

  @override
  ConsumerState<AddHousingScreen> createState() => _AddHousingScreenState();
}

class _AddHousingScreenState extends ConsumerState<AddHousingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _depositController = TextEditingController();
  final _locationController = TextEditingController();
  final _distanceController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  HousingType _selectedType = HousingType.hostel;
  GenderRestriction _selectedGender = GenderRestriction.mixed;
  bool _isLoading = false;
  double _uploadProgress = 0;
  final List<File> _selectedImages = [];

  bool _hasWater = true;
  bool _hasWifi = false;
  bool _hasSecurity = true;
  bool _isFurnished = false;

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _depositController.dispose();
    _locationController.dispose();
    _distanceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 70);
    if (images.isNotEmpty) {
      setState(() => _selectedImages.addAll(images.map((i) => File(i.path))));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one photo')));
      return;
    }

    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _uploadProgress = 0;
    });

    try {
      final housingId = const Uuid().v4();
      final imageUrls = <String>[];

      for (var i = 0; i < _selectedImages.length; i++) {
        final url = await ref.read(storageRepositoryProvider).uploadFile(
          path: 'housing/$housingId',
          id: 'img_$i',
          file: _selectedImages[i],
          onProgress: (sent, total) {
            setState(() {
              _uploadProgress = (i / _selectedImages.length) + 
                               ((sent / total) / _selectedImages.length);
            });
          },
        );
        imageUrls.add(url);
      }

      final listing = HousingListing(
        id: housingId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.tryParse(_priceController.text.trim()) ?? 0.0,
        type: _selectedType,
        university: user.university ?? 'Unknown University',
        campus: user.campus ?? 'Main Campus',
        location: _locationController.text.trim(),
        distance: _distanceController.text.trim(),
        images: imageUrls,
        amenities: [],
        landlordId: user.uid,
        landlordName: user.fullName,
        createdAt: DateTime.now(),
        deposit: double.tryParse(_depositController.text.trim()) ?? 0.0,
        isFurnished: _isFurnished,
        genderRestriction: _selectedGender,
        contactInfo: {'phone': user.phoneNumber ?? ''},
        hasWater: _hasWater,
        hasWifi: _hasWifi,
        hasSecurity: _hasSecurity,
      );

      await ref.read(housingRepositoryProvider).createListing(listing);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Housing listed successfully!')));
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
        title: Text('List Property', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
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
              _buildImageSelector(),
              const SizedBox(height: 32),
              _buildSectionLabel('Basic Info'),
              _buildTextField(
                controller: _titleController,
                label: 'Listing Title',
                hint: 'e.g. Modern Hostel near Main Gate',
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _buildTypeDropdown()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildGenderDropdown()),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _priceController,
                      label: 'Rent / Month',
                      hint: '8000',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.payments_outlined,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _depositController,
                      label: 'Deposit',
                      hint: '8000',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _locationController,
                      label: 'Location / Area',
                      hint: 'e.g. Juja South',
                      prefixIcon: Icons.location_on_outlined,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _distanceController,
                      label: 'Distance to Campus',
                      hint: 'e.g. 5 mins walk',
                      prefixIcon: Icons.directions_walk,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildSectionLabel('Amenities & Features'),
              _buildAmenitiesSwitches(),
              const SizedBox(height: 32),
              _buildTextField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'Describe house rules, nearby shops, etc...',
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

  Widget _buildImageSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Photos'),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              GestureDetector(
                onTap: _isLoading ? null : _pickImages,
                child: Container(
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.indigo.shade100, width: 2),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, color: Colors.indigo),
                      SizedBox(height: 8),
                      Text('Add Photos', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo)),
                    ],
                  ),
                ),
              ),
              ..._selectedImages.map((file) => Container(
                width: 120,
                margin: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(image: FileImage(file), fit: BoxFit.cover),
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.white),
                    onPressed: () => setState(() => _selectedImages.remove(file)),
                  ),
                ),
              )),
            ],
          ),
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
          isExpanded: true,
          items: HousingType.values.map((t) => DropdownMenuItem(
            value: t, 
            child: Text(t.name, style: const TextStyle(fontSize: 13))
          )).toList(),
          onChanged: (v) => setState(() => _selectedType = v!),
          decoration: _inputDecoration(),
        ),
      ],
    );
  }

  Widget _buildGenderDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Gender', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<GenderRestriction>(
          value: _selectedGender,
          isExpanded: true,
          items: GenderRestriction.values.map((t) => DropdownMenuItem(
            value: t, 
            child: Text(t.name, style: const TextStyle(fontSize: 13))
          )).toList(),
          onChanged: (v) => setState(() => _selectedGender = v!),
          decoration: _inputDecoration(),
        ),
      ],
    );
  }

  Widget _buildAmenitiesSwitches() {
    return Column(
      children: [
        _buildSwitchTile('24/7 Water Supply', _hasWater, (v) => setState(() => _hasWater = v)),
        _buildSwitchTile('High Speed WiFi', _hasWifi, (v) => setState(() => _hasWifi = v)),
        _buildSwitchTile('Security / CCTV', _hasSecurity, (v) => setState(() => _hasSecurity = v)),
        _buildSwitchTile('Fully Furnished', _isFurnished, (v) => setState(() => _isFurnished = v)),
      ],
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.indigo,
      contentPadding: EdgeInsets.zero,
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF8F9FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
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
          decoration: _inputDecoration().copyWith(
            hintText: hint,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20, color: Colors.indigo.shade300) : null,
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
            : const Text('Post Listing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
