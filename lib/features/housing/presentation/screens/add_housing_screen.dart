import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/housing_listing.dart';
import '../../domain/models/vacancy_request.dart';
import '../../shared/providers.dart';
import '../../../shared/storage_repository.dart';

class AddHousingScreen extends ConsumerStatefulWidget {
  final HousingListing? listing;
  final VacancyRequest? opportunity;
  const AddHousingScreen({super.key, this.listing, this.opportunity});

  @override
  ConsumerState<AddHousingScreen> createState() => _AddHousingScreenState();
}

class _AddHousingScreenState extends ConsumerState<AddHousingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _rentController;
  late final TextEditingController _depositController;
  late final TextEditingController _locationController;
  late final TextEditingController _distanceController;
  late final TextEditingController _descriptionController;
  
  HousingType _selectedType = HousingType.hostel;
  GenderRestriction _selectedGender = GenderRestriction.mixed;
  PropertySource _selectedSource = PropertySource.plugDiscovery;
  bool _isLoading = false;
  double _uploadProgress = 0;
  final List<File> _selectedImages = [];
  List<String> _existingImages = [];
  File? _selectedVideo;
  String? _existingVideo;

  final List<String> _selectedAmenities = [];
  final List<String> _allAmenities = [
    '24/7 Water', 'WiFi', 'Security', 'Furnished', 'Tokens', 'Laundry', 'Parking', 'Borehole'
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.listing?.title);
    _rentController = TextEditingController(text: widget.listing?.rent.toInt().toString());
    _depositController = TextEditingController(text: widget.listing?.deposit.toInt().toString());
    _locationController = TextEditingController(text: widget.listing?.location ?? widget.opportunity?.location);
    _distanceController = TextEditingController(text: widget.listing?.distance);
    _descriptionController = TextEditingController(text: widget.listing?.description ?? widget.opportunity?.description);
    
    if (widget.listing != null) {
      _selectedType = widget.listing!.type;
      _selectedGender = widget.listing!.genderRestriction;
      _selectedSource = widget.listing!.source;
      _selectedAmenities.addAll(widget.listing!.amenities);
      _existingImages = List<String>.from(widget.listing!.images);
      _existingVideo = widget.listing!.videoUrl;
    } else if (widget.opportunity != null) {
      _selectedType = widget.opportunity!.type;
      _selectedSource = PropertySource.landlord; // Assumption for leads
      _rentController.text = widget.opportunity!.expectedRent.toInt().toString();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _rentController.dispose();
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

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() => _selectedVideo = File(video.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty && _existingImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one photo')));
      return;
    }

    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;

    // Duplicate Check only for new listings
    if (widget.listing == null) {
      final isDuplicate = await ref.read(housingRepositoryProvider).checkPossibleDuplicate(
        location: _locationController.text.trim(),
        rent: double.tryParse(_rentController.text.trim()) ?? 0.0,
        type: _selectedType,
      );

      if (isDuplicate && mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Possible Duplicate'),
            content: const Text('A similar listing already exists in this area with the same rent. Are you sure you want to post this?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Post Anyway')),
            ],
          ),
        );
        if (proceed != true) return;
      }
    }

    setState(() {
      _isLoading = true;
      _uploadProgress = 0;
    });

    try {
      final housingId = widget.listing?.id ?? const Uuid().v4();
      final imageUrls = List<String>.from(_existingImages);
      String? videoUrl = _existingVideo;

      // Upload Images
      for (var i = 0; i < _selectedImages.length; i++) {
        final url = await ref.read(storageRepositoryProvider).uploadFile(
          path: 'housing/$housingId',
          id: 'img_${DateTime.now().millisecondsSinceEpoch}_$i',
          file: _selectedImages[i],
          onProgress: (sent, total) {
            setState(() {
              _uploadProgress = (i / (_selectedImages.length + (_selectedVideo != null ? 1 : 0))) + 
                               ((sent / total) / (_selectedImages.length + (_selectedVideo != null ? 1 : 0)));
            });
          },
        );
        imageUrls.add(url);
      }

      // Upload Video
      if (_selectedVideo != null) {
        videoUrl = await ref.read(storageRepositoryProvider).uploadFile(
          path: 'housing/$housingId',
          id: 'video_${DateTime.now().millisecondsSinceEpoch}',
          file: _selectedVideo!,
          onProgress: (sent, total) {
             setState(() {
              _uploadProgress = (_selectedImages.length / (_selectedImages.length + 1)) + 
                               ((sent / total) / (_selectedImages.length + 1));
            });
          }
        );
      }

      final listing = HousingListing(
        id: housingId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        rent: double.tryParse(_rentController.text.trim()) ?? 0.0,
        deposit: double.tryParse(_depositController.text.trim()) ?? 0.0,
        type: _selectedType,
        university: user.university ?? 'Unknown University',
        campus: user.campus ?? 'Main Campus',
        location: _locationController.text.trim(),
        distance: _distanceController.text.trim(),
        images: imageUrls,
        videoUrl: videoUrl,
        amenities: _selectedAmenities,
        createdAt: widget.listing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        status: widget.listing?.status ?? HousingStatus.available,
        source: _selectedSource,
        plugId: user.uid,
        plugName: user.fullName,
        plugPhotoUrl: user.photoUrl,
        isFurnished: _selectedAmenities.contains('Furnished'),
        genderRestriction: _selectedGender,
      );

      if (widget.listing != null) {
        await ref.read(housingRepositoryProvider).updateListing(listing);
      } else {
        await ref.read(housingRepositoryProvider).createListing(listing);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.listing != null ? 'Listing updated!' : 'Housing listed successfully!')));
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
    final user = ref.watch(appUserProvider).valueOrNull;
    if (user == null) return const Scaffold(body: Center(child: Text('Please log in')));

    // Strictly consume the platform's professional role verification
    final isVerifiedPlug = user.verifiedRoles.contains('housePlug');
    final isVerified = user.isVerified;

    if (!isVerifiedPlug) {
      final theme = Theme.of(context);
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: Text(!isVerified ? 'Verification Required' : 'Role Application Required'),
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          foregroundColor: theme.colorScheme.onSurface,
        ),
        body: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(!isVerified ? Icons.verified_user_rounded : Icons.home_work_rounded, size: 64, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 32),
              Text(
                !isVerified ? 'Identity Verification Required' : 'Housing Plug Role Required',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                !isVerified 
                    ? 'To list properties on UniHub, you must first verify your platform identity via the Trust Center.'
                    : 'To list properties on UniHub, you must activate the Housing Plug role for your account.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: FilledButton(
                  onPressed: () => context.push(isVerified ? '/verify-professional/housePlug' : '/trust-center'),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: Text(!isVerified ? 'Go to Trust Center' : 'Apply for Role', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.pop(),
                child: Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant)),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text('List Property', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMediaSelector(),
              const SizedBox(height: 32),
              _buildSectionLabel('Basic Details'),
              _buildTextField(
                controller: _titleController,
                label: 'Property Title',
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
              _buildSourceDropdown(),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _rentController,
                      label: 'Rent per Month (KES)',
                      hint: '8500',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.payments_outlined,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Invalid amount';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _depositController,
                      label: 'Deposit (KES)',
                      hint: '8500',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v != null && v.isNotEmpty && double.tryParse(v) == null) return 'Invalid';
                        return null;
                      },
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
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _distanceController,
                      label: 'Distance from Campus',
                      hint: 'e.g. 5 mins walk',
                      prefixIcon: Icons.directions_walk,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildSectionLabel('Amenities'),
              _buildAmenitiesWrap(),
              const SizedBox(height: 32),
              _buildSectionLabel('Description'),
              _buildTextField(
                controller: _descriptionController,
                label: 'About the property',
                hint: 'Describe house rules, nearby features, availability...',
                maxLines: 4,
              ),
              const SizedBox(height: 40),
              if (_isLoading)
                Column(
                  children: [
                    LinearProgressIndicator(value: _uploadProgress, color: theme.colorScheme.primary),
                    const SizedBox(height: 8),
                    Text('Uploading media... ${(100 * _uploadProgress).toInt()}%', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 16),
                  ],
                ),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Photos & Video Walkthrough'),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildAddMediaButton(
                onTap: _pickImages,
                icon: Icons.add_a_photo_rounded,
                label: 'Add Photos',
                subtitle: '${_selectedImages.length + _existingImages.length} total',
              ),
              const SizedBox(width: 16),
              _buildAddMediaButton(
                onTap: _pickVideo,
                icon: Icons.videocam_rounded,
                label: 'Add Video',
                subtitle: (_selectedVideo != null || _existingVideo != null) ? 'Selected' : 'Optional',
                isDone: _selectedVideo != null || _existingVideo != null,
              ),
              ..._existingImages.map((url) => Container(
                width: 120,
                margin: const EdgeInsets.only(left: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _existingImages.remove(url)),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
              ..._selectedImages.map((file) => Container(
                width: 120,
                margin: const EdgeInsets.only(left: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(image: FileImage(file), fit: BoxFit.cover),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedImages.remove(file)),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddMediaButton({
    required VoidCallback onTap, 
    required IconData icon, 
    required String label, 
    required String subtitle,
    bool isDone = false,
  }) {
    final theme = Theme.of(context);
    final color = isDone ? AppColors.success : theme.colorScheme.primary;
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.2), 
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color.withOpacity(0.7))),
          ],
        ),
      ),
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
        const Text('Gender Restrictions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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

  Widget _buildSourceDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Property Source (Internal)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<PropertySource>(
          value: _selectedSource,
          isExpanded: true,
          items: PropertySource.values.map((s) {
            String label = switch(s) {
              PropertySource.plugDiscovery => 'Plug Discovery',
              PropertySource.landlord => 'Landlord Lead',
              PropertySource.caretaker => 'Caretaker Lead',
              PropertySource.hostelManagement => 'Hostel Management',
              PropertySource.studentMovingOut => 'Student Moving Out',
              PropertySource.other => 'Other Source',
            };
            return DropdownMenuItem(value: s, child: Text(label, style: const TextStyle(fontSize: 13)));
          }).toList(),
          onChanged: (v) => setState(() => _selectedSource = v!),
          decoration: _inputDecoration(),
        ),
      ],
    );
  }

  Widget _buildAmenitiesWrap() {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _allAmenities.map((a) {
        final isSelected = _selectedAmenities.contains(a);
        return FilterChip(
          label: Text(a, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : theme.colorScheme.onSurface)),
          selected: isSelected,
          onSelected: (val) {
            setState(() {
              if (val) _selectedAmenities.add(a);
              else _selectedAmenities.remove(a);
            });
          },
          selectedColor: theme.colorScheme.primary,
          checkmarkColor: Colors.white,
        );
      }).toList(),
    );
  }

  InputDecoration _inputDecoration() {
    final theme = Theme.of(context);
    return InputDecoration(
      filled: true,
      fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16), 
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16), 
        borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5), width: 1),
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

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF1A1C1E),
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
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20, color: theme.colorScheme.primary.withOpacity(0.5)) : null,
          ),
        ),
      ],
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('Post Listing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
