import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import '../widgets/logout_dialog.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_text_field.dart';
import '../../shared/providers.dart';
import '../../../shared/storage_repository.dart';
import '../../../../core/constants/campus_constants.dart';
import '../../../../core/location/models/campus.dart';
import '../../../../core/location/repositories/campus_repository.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final universityController = TextEditingController();
  final courseController = TextEditingController();
  final yearController = TextEditingController();
  Campus? _selectedCampus;
  File? _selectedImage;
  String? _uploadedImageUrl;
  bool _localLoading = false;
  double _uploadProgress = 0;

  @override
  void dispose() {
    universityController.dispose();
    courseController.dispose();
    yearController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _uploadedImageUrl = null; // Reset if new image picked
      });
      _uploadImage();
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;
    
    setState(() {
      _localLoading = true;
      _uploadProgress = 0;
    });

    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) return;

      final url = await ref.read(storageRepositoryProvider).uploadFile(
        path: 'profiles/${user.uid}',
        id: 'avatar',
        file: _selectedImage!,
        onProgress: (sent, total) {
          setState(() => _uploadProgress = sent / total);
        },
      );

      setState(() {
        _uploadedImageUrl = url;
        _localLoading = false;
      });
    } catch (e) {
      setState(() => _localLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  void _showMissingCampusDialog() {
    final nameController = TextEditingController();
    final cityController = TextEditingController();
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Your Campus'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Campus Name',
                hintText: 'e.g. Maseno University',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: cityController,
              decoration: const InputDecoration(
                labelText: 'City / Town',
                hintText: 'e.g. Kisumu',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final city = cityController.text.trim();
              if (name.isEmpty || city.isEmpty) return;

              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close picker bottom sheet

              setState(() => _localLoading = true);
              try {
                final newCampus = await ref.read(campusRepositoryProvider).suggestCampus(
                  name: name,
                  city: city,
                );
                setState(() {
                  _selectedCampus = newCampus;
                  universityController.text = newCampus.name;
                  _localLoading = false;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Successfully added ${newCampus.name}!')),
                  );
                }
              } catch (e) {
                setState(() => _localLoading = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add campus: $e')),
                  );
                }
              }
            },
            child: const Text('Add & Select'),
          ),
        ],
      ),
    );
  }

  void _showCampusPicker() async {
    final campuses = await ref.read(campusRepositoryProvider).getCampuses();
    
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final theme = Theme.of(context);
          final query = TextEditingController();
          List<Campus> filtered = campuses;

          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller: query,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search University...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        filtered = campuses.where((c) => 
                          c.name.toLowerCase().contains(val.toLowerCase()) ||
                          c.shortName.toLowerCase().contains(val.toLowerCase()) ||
                          c.aliases.any((a) => a.toLowerCase().contains(val.toLowerCase()))
                        ).toList();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length + 1,
                    itemBuilder: (context, index) {
                      if (index == filtered.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          child: OutlinedButton.icon(
                            onPressed: _showMissingCampusDialog,
                            icon: const Icon(Icons.add_location_alt_outlined),
                            label: const Text('My Campus is missing'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        );
                      }
                      final campus = filtered[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                        title: Text(campus.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(campus.city),
                        onTap: () {
                          setState(() {
                            _selectedCampus = campus;
                            universityController.text = campus.name;
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _onContinue() async {
    final university = _selectedCampus?.id ?? universityController.text.trim();
    final course = courseController.text.trim();
    final year = yearController.text.trim();

    if (university.isEmpty || course.isEmpty || year.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    await ref.read(authControllerProvider.notifier).updateProfile(
      university: university,
      course: course,
      yearOfStudy: year,
      photoUrl: _uploadedImageUrl,
    );

    if (mounted) {
      final state = ref.read(authControllerProvider);
      if (state.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.error.toString().replaceAll('Exception: ', '')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final isProcessing = authState.isLoading || _localLoading;

    // Listen for auth errors
    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (err, _) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        ),
      );
    });

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: theme.colorScheme.primary),
            onPressed: isProcessing ? null : () => LogoutDialog.show(context, ref),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              'Complete Your Profile',
              style: theme.textTheme.displaySmall?.copyWith(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.6,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Help us personalize your campus experience',
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 48),
            
            // Profile Photo
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: isProcessing ? null : _pickImage,
                    child: CircleAvatar(
                      radius: 58,
                      backgroundColor: theme.colorScheme.surfaceVariant,
                      backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null,
                      child: _selectedImage == null 
                          ? Icon(Icons.person, size: 60, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)) 
                          : null,
                    ),
                  ),
                  if (_localLoading && _uploadProgress < 1)
                    Positioned.fill(
                      child: CircularProgressIndicator(
                        value: _uploadProgress,
                        strokeWidth: 4,
                        color: Colors.white,
                        backgroundColor: Colors.black26,
                      ),
                    ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: isProcessing ? null : _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_localLoading && _uploadProgress > 0)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Uploading: ${(_uploadProgress * 100).toInt()}%',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            const SizedBox(height: 50),
            
            GestureDetector(
              onTap: isProcessing ? null : _showCampusPicker,
              child: AbsorbPointer(
                child: AuthTextField(
                  controller: universityController,
                  hintText: 'University / Campus',
                  icon: Icons.school_outlined,
                  enabled: !isProcessing,
                ),
              ),
            ),
            const SizedBox(height: 18),
            AuthTextField(
              controller: courseController,
              hintText: 'Course / Major',
              icon: Icons.menu_book_outlined,
              enabled: !isProcessing,
            ),
            const SizedBox(height: 18),
            AuthTextField(
              controller: yearController,
              hintText: 'Year of Study',
              icon: Icons.calendar_today_outlined,
              keyboardType: TextInputType.number,
              enabled: !isProcessing,
            ),
            const SizedBox(height: 50),
            
            SizedBox(
              width: double.infinity,
              height: 56,
              child: isProcessing
                  ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                  : FilledButton(
                      onPressed: _onContinue,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Continue', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                'This information helps tailor marketplace,\nhousing, and community recommendations.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7), height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
