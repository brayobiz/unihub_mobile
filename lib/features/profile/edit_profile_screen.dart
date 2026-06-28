import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/auth/domain/models/app_user.dart';
import 'package:unihub_mobile/features/shared/storage_repository.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _universityController;
  late TextEditingController _courseController;
  late TextEditingController _yearController;
  late TextEditingController _housingController;
  late TextEditingController _whatsappController;
  late TextEditingController _phoneController;
  
  // Lists
  late List<String> _skills;
  late List<String> _interests;
  
  // Images
  File? _profileImage;
  File? _coverImage;
  
  bool _isLoading = false;
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    final user = ref.read(appUserProvider).valueOrNull;
    _nameController = TextEditingController(text: user?.fullName);
    _usernameController = TextEditingController(text: user?.username);
    _bioController = TextEditingController(text: user?.bio);
    _universityController = TextEditingController(text: user?.university);
    _courseController = TextEditingController(text: user?.course);
    _yearController = TextEditingController(text: user?.yearOfStudy);
    _housingController = TextEditingController(text: user?.housingStatus);
    _whatsappController = TextEditingController(text: user?.whatsappNumber);
    _phoneController = TextEditingController(text: user?.phoneNumber);
    
    _skills = List.from(user?.skills ?? []);
    _interests = List.from(user?.interests ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _universityController.dispose();
    _courseController.dispose();
    _yearController.dispose();
    _housingController.dispose();
    _whatsappController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isProfile) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() {
        if (isProfile) {
          _profileImage = File(image.path);
        } else {
          _coverImage = File(image.path);
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _uploadProgress = 0;
    });

    try {
      final currentUser = ref.read(firebaseAuthProvider).currentUser;
      if (currentUser == null) throw Exception('No authenticated user found');

      final user = ref.read(appUserProvider).valueOrNull;
      
      String? photoUrl = user?.photoUrl;
      String? coverPhotoUrl = user?.coverPhotoUrl;

      // 1. Upload Profile Image if changed
      if (_profileImage != null) {
        photoUrl = await ref.read(storageRepositoryProvider).uploadFile(
          path: 'profiles/${currentUser.uid}',
          id: 'avatar',
          file: _profileImage!,
          onProgress: (sent, total) => setState(() => _uploadProgress = (sent / total) * 0.5),
        );
      }

      // 2. Upload Cover Image if changed
      if (_coverImage != null) {
        final startProgress = _profileImage != null ? 0.5 : 0.0;
        coverPhotoUrl = await ref.read(storageRepositoryProvider).uploadFile(
          path: 'profiles/${currentUser.uid}',
          id: 'cover',
          file: _coverImage!,
          onProgress: (sent, total) => setState(() => _uploadProgress = startProgress + (sent / total) * 0.5),
        );
      }

      await ref.read(authRepositoryProvider).updateProfile(
        uid: currentUser.uid,
        fullName: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        bio: _bioController.text.trim(),
        photoUrl: photoUrl,
        coverPhotoUrl: coverPhotoUrl,
        university: _universityController.text.trim(),
        course: _courseController.text.trim(),
        yearOfStudy: _yearController.text.trim(),
        housingStatus: _housingController.text.trim(),
        whatsappNumber: _whatsappController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        skills: _skills,
        interests: _interests,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully')));
        context.pop();
      }
    } catch (e) {
      debugPrint('Update Profile Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isLoading)
            Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('${(_uploadProgress * 100).toInt()}%', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))))
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImagePickers(),
              const SizedBox(height: 50),
              
              _buildSectionTitle('Basic Information'),
              _buildTextField(_nameController, 'Full Name', Icons.person_outline),
              _buildTextField(_usernameController, 'Username', Icons.alternate_email),
              _buildTextField(_bioController, 'Bio', Icons.info_outline, maxLines: 3),
              
              const SizedBox(height: 24),
              _buildSectionTitle('Academic Details'),
              _buildTextField(_universityController, 'University', Icons.school_outlined),
              _buildTextField(_courseController, 'Course', Icons.book_outlined),
              _buildTextField(_yearController, 'Year of Study', Icons.calendar_today_outlined),
              _buildTextField(_housingController, 'Housing Status', Icons.home_outlined),

              const SizedBox(height: 24),
              _buildSectionTitle('Contact & Social'),
              _buildTextField(_whatsappController, 'WhatsApp Number', Icons.phone_android),
              _buildTextField(_phoneController, 'Phone Number', Icons.phone_outlined),

              const SizedBox(height: 24),
              _buildChipSection('Skills', _skills, Colors.blue),
              const SizedBox(height: 16),
              _buildChipSection('Interests', _interests, Colors.green),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _isLoading ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePickers() {
    final user = ref.read(appUserProvider).valueOrNull;
    
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Cover Photo
            GestureDetector(
              onTap: () => _pickImage(false),
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  image: _coverImage != null 
                    ? DecorationImage(image: FileImage(_coverImage!), fit: BoxFit.cover)
                    : (user?.coverPhotoUrl != null 
                        ? DecorationImage(image: NetworkImage(user!.coverPhotoUrl!), fit: BoxFit.cover)
                        : null),
                ),
                child: _coverImage == null && user?.coverPhotoUrl == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, color: Colors.grey),
                        SizedBox(height: 4),
                        Text('Add Cover Photo', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    )
                  : const Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.edit, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
              ),
            ),
            
            // Profile Photo
            Positioned(
              bottom: -40,
              left: 20,
              child: GestureDetector(
                onTap: () => _pickImage(true),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.indigo.shade50,
                    backgroundImage: _profileImage != null 
                      ? FileImage(_profileImage!) as ImageProvider
                      : (user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null),
                    child: _profileImage == null && user?.photoUrl == null
                      ? Text(
                          user?.fullName != null && user!.fullName.isNotEmpty 
                              ? user.fullName[0].toUpperCase() 
                              : 'U',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.indigo),
                        )
                      : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: Colors.grey),
          filled: true,
          fillColor: const Color(0xFFF8F9FB),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        validator: (v) => (label == 'Full Name' && (v == null || v.isEmpty)) ? 'Required' : null,
      ),
    );
  }

  Widget _buildChipSection(String title, List<String> list, Color color) {
    final controller = TextEditingController();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: list.map((item) => Chip(
            label: Text(item, style: const TextStyle(fontSize: 12)),
            onDeleted: () => setState(() => list.remove(item)),
            backgroundColor: color.withOpacity(0.05),
            side: BorderSide.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          )).toList(),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Add ${title.toLowerCase().substring(0, title.length-1)}...',
            hintStyle: const TextStyle(fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF8F9FB),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add, size: 20),
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() => list.add(controller.text.trim()));
                  controller.clear();
                }
              },
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          onSubmitted: (v) {
            if (v.isNotEmpty) {
              setState(() => list.add(v.trim()));
              controller.clear();
            }
          },
        ),
      ],
    );
  }
}
