import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_text_field.dart';
import '../../shared/providers.dart';
import '../../../shared/storage_repository.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final universityController = TextEditingController();
  final courseController = TextEditingController();
  final yearController = TextEditingController();
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

  void _onContinue() async {
    final university = universityController.text.trim();
    final course = courseController.text.trim();
    final year = yearController.text.trim();

    if (university.isEmpty || course.isEmpty || year.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _localLoading = true);
    
    await ref.read(authControllerProvider.notifier).updateProfile(
      university: university,
      course: course,
      yearOfStudy: year,
      photoUrl: _uploadedImageUrl,
    );

    if (mounted) {
      final state = ref.read(authControllerProvider);
      if (state.hasError) {
        setState(() => _localLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Complete Your Profile',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Help us personalize your campus experience',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 48),
            
            // Profile Photo
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _localLoading ? null : _pickImage,
                    child: CircleAvatar(
                      radius: 58,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null,
                      child: _selectedImage == null 
                          ? const Icon(Icons.person, size: 60, color: Colors.grey) 
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
                      onTap: _localLoading ? null : _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
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
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            const SizedBox(height: 50),
            
            AuthTextField(
              controller: universityController,
              hintText: 'University / Campus',
              icon: Icons.school_outlined,
              enabled: !_localLoading,
            ),
            const SizedBox(height: 18),
            AuthTextField(
              controller: courseController,
              hintText: 'Course / Major',
              icon: Icons.menu_book_outlined,
              enabled: !_localLoading,
            ),
            const SizedBox(height: 18),
            AuthTextField(
              controller: yearController,
              hintText: 'Year of Study',
              icon: Icons.calendar_today_outlined,
              keyboardType: TextInputType.number,
              enabled: !_localLoading,
            ),
            const SizedBox(height: 50),
            
            SizedBox(
              width: double.infinity,
              height: 56,
              child: _localLoading
                  ? const Center(child: CircularProgressIndicator())
                  : FilledButton(
                      onPressed: _onContinue,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Continue', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    ),
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                'This information helps tailor marketplace,\nhousing, and community recommendations.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
