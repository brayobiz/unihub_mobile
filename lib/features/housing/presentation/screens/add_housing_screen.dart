import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/core/widgets/creation_success_dialog.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/housing_listing.dart';
import '../../domain/models/vacancy_request.dart';
import '../../shared/providers.dart';
import '../controllers/add_housing_controller.dart';
import '../../../shared/storage_repository.dart';
import '../../../../core/location/widgets/location_picker.dart';
import '../../../../core/location/models/location_data.dart';
import '../../../../core/location/services/location_service.dart';
import '../../../../core/constants/campus_constants.dart';

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

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.listing?.title);
    _rentController = TextEditingController(text: widget.listing?.rent.toInt().toString());
    _depositController = TextEditingController(text: widget.listing?.deposit.toInt().toString());
    _locationController = TextEditingController(text: widget.listing?.location ?? widget.opportunity?.location);
    _distanceController = TextEditingController(text: widget.listing?.distance);
    _descriptionController = TextEditingController(text: widget.listing?.description ?? widget.opportunity?.description);
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

  Future<void> _handleBack() async {
    final state = ref.read(addHousingControllerProvider((listing: widget.listing, opportunity: widget.opportunity)));
    final bool isDirty = state.title.isNotEmpty || 
                        state.rent > 0 || 
                        state.selectedImages.isNotEmpty;
    
    if (!isDirty || state.isLoading) {
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
    
    final controller = ref.read(addHousingControllerProvider((listing: widget.listing, opportunity: widget.opportunity)).notifier);
    final state = ref.read(addHousingControllerProvider((listing: widget.listing, opportunity: widget.opportunity)));

    if (state.selectedImages.isEmpty && state.existingImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one photo')));
      return;
    }

    final success = await controller.submit();
    
    if (success && mounted) {
      CreationSuccessDialog.show(
        context,
        title: widget.listing != null ? 'Listing Updated!' : 'Property Listed!',
        message: widget.listing != null 
            ? 'Your property details have been successfully updated.'
            : 'Your property is now live on UniHub. Students can now view and contact you.',
      );
    } else if (state.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${state.error}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(appUserProvider).valueOrNull;
    if (user == null) return const Scaffold(body: Center(child: Text('Please log in')));

    final state = ref.watch(addHousingControllerProvider((listing: widget.listing, opportunity: widget.opportunity)));
    final controller = ref.read(addHousingControllerProvider((listing: widget.listing, opportunity: widget.opportunity)).notifier);

    // Strictly consume the platform's professional role verification
    final isVerifiedPlug = user.verifiedRoles.contains('housePlug');
    final isVerified = user.isVerified;

    if (!isVerifiedPlug) {
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: Text(widget.listing == null ? 'Create Vacancy' : 'Edit Property', 
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          foregroundColor: theme.colorScheme.onSurface,
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
                _buildSectionLabel(context, 'Photos & Video', Icons.camera_alt_outlined),
                const SizedBox(height: 12),
                _buildMediaSelector(state, controller),
                const SizedBox(height: 32),
                _buildSectionLabel(context, 'Property Details', Icons.home_work_outlined),
                const SizedBox(height: 12),
                _buildUniversityDropdown(state, controller),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _titleController,
                  label: 'Property Title',
                  hint: 'e.g. Modern Hostel near Main Gate',
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                  onChanged: controller.updateTitle,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _buildTypeDropdown(state, controller)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildGenderDropdown(state, controller)),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSourceDropdown(state, controller),
                const SizedBox(height: 24),
                _buildSectionLabel(context, 'Pricing & Location', Icons.payments_outlined),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _rentController,
                        label: 'Rent / Month (KES)',
                        hint: '8500',
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.payments_outlined,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Invalid amount';
                          return null;
                        },
                        onChanged: (v) => controller.updateRent(double.tryParse(v) ?? 0),
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
                        onChanged: (v) => controller.updateDeposit(double.tryParse(v) ?? 0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildMapSelector(state, controller),
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
                        onChanged: controller.updateLocation,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _distanceController,
                        label: 'Distance (Manual or Auto)',
                        hint: 'e.g. 5 mins walk',
                        prefixIcon: Icons.directions_walk,
                        onChanged: controller.updateDistance,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildSectionLabel(context, 'Amenities', Icons.checklist_rounded),
                const SizedBox(height: 12),
                _buildAmenitiesWrap(state, controller),
                const SizedBox(height: 32),
                _buildSectionLabel(context, 'Description', Icons.description_outlined),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _descriptionController,
                  label: 'About the property',
                  hint: 'Describe house rules, nearby features, availability...',
                  maxLines: 4,
                  onChanged: controller.updateDescription,
                ),
                const SizedBox(height: 40),
                if (state.isLoading)
                  Column(
                    children: [
                      LinearProgressIndicator(value: state.uploadProgress, color: theme.colorScheme.primary, minHeight: 6, borderRadius: BorderRadius.circular(4)),
                      const SizedBox(height: 8),
                      Text('Uploading media... ${(100 * state.uploadProgress).toInt()}%', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 24),
                    ],
                  ),
                _buildSubmitButton(state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaSelector(AddHousingState state, AddHousingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 140,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildAddMediaButton(
                onTap: () async {
                  final picker = ImagePicker();
                  final images = await picker.pickMultiImage(imageQuality: 70);
                  if (images.isNotEmpty) {
                    controller.addImages(images.map((i) => File(i.path)).toList());
                  }
                },
                icon: Icons.add_a_photo_rounded,
                label: 'Add Photos',
                subtitle: '${state.selectedImages.length + state.existingImages.length} total',
                isLoading: state.isLoading,
              ),
              const SizedBox(width: 16),
              _buildAddMediaButton(
                onTap: () async {
                  final picker = ImagePicker();
                  final video = await picker.pickVideo(source: ImageSource.gallery);
                  if (video != null) {
                    controller.setSelectedVideo(File(video.path));
                  }
                },
                icon: Icons.videocam_rounded,
                label: 'Add Video',
                subtitle: (state.selectedVideo != null || state.existingVideo != null) ? 'Selected' : 'Optional',
                isDone: state.selectedVideo != null || state.existingVideo != null,
                isLoading: state.isLoading,
              ),
              ...state.existingImages.map((url) => Container(
                width: 120,
                margin: const EdgeInsets.only(left: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
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
                        onTap: () => controller.removeExistingImage(url),
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
              ...state.selectedImages.map((file) => Container(
                width: 120,
                margin: const EdgeInsets.only(left: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
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
                        onTap: () => controller.removeSelectedImage(file),
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
    bool isLoading = false,
  }) {
    final theme = Theme.of(context);
    final color = isDone ? AppColors.success : theme.colorScheme.primary;
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
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

  Widget _buildTypeDropdown(AddHousingState state, AddHousingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Housing Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<HousingType>(
          value: state.type,
          isExpanded: true,
          items: HousingType.values.map((t) => DropdownMenuItem(
            value: t, 
            child: Text(t.name.replaceAll(RegExp(r'(?=[A-Z])'), ' '), style: const TextStyle(fontSize: 13))
          )).toList(),
          onChanged: (v) => controller.updateType(v!),
          decoration: _inputDecoration(),
        ),
      ],
    );
  }

  Widget _buildUniversityDropdown(AddHousingState state, AddHousingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Target Campus / University', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: state.university,
          isExpanded: true,
          items: CampusConstants.campuses.map((c) => DropdownMenuItem(
            value: c.id, 
            child: Text(c.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)
          )).toList(),
          onChanged: (v) {
            controller.updateUniversity(v);
            // Recalculate distance if location is already pinned
            if (state.latitude != null && state.longitude != null) {
              final campus = CampusConstants.getById(v);
              if (campus != null) {
                final dist = ref.read(locationServiceProvider).calculateDistance(
                  state.latitude!, 
                  state.longitude!, 
                  campus.latitude, 
                  campus.longitude
                );
                _distanceController.text = '${dist.toStringAsFixed(1)} km from campus';
                controller.updateDistance(_distanceController.text);
              }
            }
          },
          decoration: _inputDecoration(),
          validator: (v) => v == null ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildGenderDropdown(AddHousingState state, AddHousingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Gender Restrictions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<GenderRestriction>(
          value: state.genderRestriction,
          isExpanded: true,
          items: GenderRestriction.values.map((t) => DropdownMenuItem(
            value: t, 
            child: Text(t.name, style: const TextStyle(fontSize: 13))
          )).toList(),
          onChanged: (v) => controller.updateGender(v!),
          decoration: _inputDecoration(),
        ),
      ],
    );
  }

  Widget _buildSourceDropdown(AddHousingState state, AddHousingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Property Source (Internal)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<PropertySource>(
          value: state.source,
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
          onChanged: (v) => controller.updateSource(v!),
          decoration: _inputDecoration(),
        ),
      ],
    );
  }

  Widget _buildAmenitiesWrap(AddHousingState state, AddHousingController controller) {
    final theme = Theme.of(context);
    final List<String> allAmenities = [
      '24/7 Water', 'WiFi', 'Security', 'Furnished', 'Tokens', 'Laundry', 'Parking', 'Borehole'
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: allAmenities.map((a) {
        final isSelected = state.amenities.contains(a);
        return FilterChip(
          label: Text(a, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : theme.colorScheme.onSurface)),
          selected: isSelected,
          onSelected: (val) => controller.toggleAmenity(a),
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
        borderRadius: BorderRadius.circular(12), 
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), 
        borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), 
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), 
        borderSide: BorderSide(color: theme.colorScheme.error, width: 1),
      ),
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

  Widget _buildMapSelector(AddHousingState state, AddHousingController controller) {
    final theme = Theme.of(context);
    final hasCoords = state.latitude != null && state.longitude != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Map Location', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final campus = CampusConstants.getById(state.university);
            
            final result = await Navigator.push<LocationData>(
              context,
              MaterialPageRoute(
                builder: (context) => LocationPicker(
                  initialLat: state.latitude ?? campus?.latitude,
                  initialLng: state.longitude ?? campus?.longitude,
                  title: 'Pin Property Location',
                ),
              ),
            );

            if (result != null) {
              controller.updateCoordinates(result.latitude, result.longitude);
              
              // Auto-calculate distance if campus is selected
              if (state.university != null) {
                final campus = CampusConstants.getById(state.university);
                if (campus != null) {
                  final dist = ref.read(locationServiceProvider).calculateDistance(
                    result.latitude, 
                    result.longitude, 
                    campus.latitude, 
                    campus.longitude
                  );
                  _distanceController.text = '${dist.toStringAsFixed(1)} km from campus';
                  controller.updateDistance(_distanceController.text);
                }
              }
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasCoords ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasCoords ? Icons.location_on_rounded : Icons.add_location_alt_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasCoords ? 'Location Pinned' : 'Pin Property on Map',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: hasCoords ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                          fontSize: 14,
                        ),
                      ),
                      if (hasCoords)
                        Text(
                          '${state.latitude!.toStringAsFixed(6)}, ${state.longitude!.toStringAsFixed(6)}',
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                if (!hasCoords)
                  TextButton.icon(
                    onPressed: () async {
                      final loc = await ref.read(locationServiceProvider).getCurrentLocation();
                      if (loc != null) {
                        controller.updateCoordinates(loc.latitude, loc.longitude);

                        // Auto-calculate distance
                        if (state.university != null) {
                          final campus = CampusConstants.getById(state.university);
                          if (campus != null) {
                            final dist = ref.read(locationServiceProvider).calculateDistance(
                              loc.latitude, 
                              loc.longitude, 
                              campus.latitude, 
                              campus.longitude
                            );
                            _distanceController.text = '${dist.toStringAsFixed(1)} km from campus';
                            controller.updateDistance(_distanceController.text);
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.my_location, size: 16),
                    label: const Text('Current', style: TextStyle(fontSize: 12)),
                  )
                else
                  const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
              ],
            ),
          ),
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
    IconData? prefixIcon,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
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
          onChanged: onChanged,
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

  Widget _buildSubmitButton(AddHousingState state) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton(
        onPressed: state.isLoading ? null : _submit,
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: state.isLoading
            ? const Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
            : Text(widget.listing != null ? 'Save Changes' : 'Create Vacancy', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
