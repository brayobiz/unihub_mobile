import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
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

      // 1. Upload Profile Image if changed
      if (_profileImage != null) {
        photoUrl = await ref.read(storageRepositoryProvider).uploadFile(
          path: 'profiles/${currentUser.uid}',
          id: 'avatar',
          file: _profileImage!,
          onProgress: (sent, total) => setState(() => _uploadProgress = (sent / total)),
        );
      }

      await ref.read(authRepositoryProvider).updateProfile(
        uid: currentUser.uid,
        fullName: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        bio: _bioController.text.trim(),
        photoUrl: photoUrl,
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
        backgroundColor: Colors.white.withOpacity(0.9), // Performance: Avoid blur in AppBar
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_isLoading)
            Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('${(_uploadProgress * 100).toInt()}%', style: const TextStyle(color: Color(0xFF1677F2), fontWeight: FontWeight.w900))))
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _save,
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1677F2))),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Background Decorative Blobs - Wrapped in RepaintBoundary for performance
          RepaintBoundary(
            child: Stack(
              children: [
                Positioned(
                  top: -100,
                  right: -100,
                  child: _buildBlob(300, const Color(0xFF1677F2).withOpacity(0.08)),
                ),
                Positioned(
                  bottom: 200,
                  left: -150,
                  child: _buildBlob(400, const Color(0xFF19D3C5).withOpacity(0.05)),
                ),
                Positioned(
                  top: 400,
                  right: -50,
                  child: _buildBlob(200, const Color(0xFF6366F1).withOpacity(0.06)),
                ),
              ],
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImagePickers(),
                    const SizedBox(height: 40),
                    
                    _buildGlassSection(
                      title: 'Basic Information',
                      icon: Icons.person_rounded,
                      children: [
                        _buildTextField(_nameController, 'Full Name', Icons.badge_outlined, readOnly: true),
                        _buildTextField(_usernameController, 'Username', Icons.alternate_email_rounded),
                        _buildTextField(_bioController, 'Bio', Icons.description_outlined, maxLines: 3),
                      ],
                    ),
                    
                    _buildGlassSection(
                      title: 'Academic Details',
                      icon: Icons.school_rounded,
                      children: [
                        _buildTextField(_universityController, 'University', Icons.account_balance_outlined, readOnly: true),
                        _buildTextField(_courseController, 'Course', Icons.menu_book_rounded, readOnly: true),
                        _buildTextField(_yearController, 'Year of Study', Icons.calendar_today_rounded, readOnly: true),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.indigo.withOpacity(0.1)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF6366F1)),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Identity fields are locked to preserve account integrity.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF4338CA), fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    _buildGlassSection(
                      title: 'Preferences & Contact',
                      icon: Icons.settings_accessibility_rounded,
                      children: [
                        _buildTextField(_housingController, 'Housing Status', Icons.home_outlined),
                        _buildTextField(_whatsappController, 'WhatsApp Number', Icons.phone_android_rounded),
                        _buildTextField(_phoneController, 'Phone Number', Icons.local_phone_outlined),
                      ],
                    ),

                    _buildGlassSection(
                      title: 'Skills & Interests',
                      icon: Icons.auto_awesome_rounded,
                      children: [
                        _buildChipSection('Skills', _skills, const Color(0xFF1677F2)),
                        const SizedBox(height: 24),
                        _buildChipSection('Interests', _interests, const Color(0xFF10B981)),
                      ],
                    ),

                    const SizedBox(height: 32),
                    _buildGradientSaveButton(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withOpacity(0),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassSection({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9), // Increased opacity for better performance
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1677F2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: const Color(0xFF1677F2)),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), letterSpacing: -0.5),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildImagePickers() {
    final user = ref.read(appUserProvider).valueOrNull;
    
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1677F2), Color(0xFF19D3C5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1677F2).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: CircleAvatar(
                radius: 65,
                backgroundColor: const Color(0xFFF1F5F9),
                backgroundImage: _profileImage != null 
                  ? FileImage(_profileImage!) as ImageProvider
                  : (user?.photoUrl != null ? CachedNetworkImageProvider(user!.photoUrl!) : null),
                child: _profileImage == null && user?.photoUrl == null
                  ? Text(
                      user?.fullName != null && user!.fullName.isNotEmpty 
                          ? user.fullName[0].toUpperCase() 
                          : 'U',
                      style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Color(0xFF1677F2)),
                    )
                  : null,
              ),
            ),
          ),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: const Icon(Icons.camera_enhance_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1, bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: readOnly ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            readOnly: readOnly,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: readOnly ? const Color(0xFF64748B) : const Color(0xFF1E293B),
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 20, color: readOnly ? const Color(0xFFCBD5E1) : const Color(0xFF1677F2)),
              filled: true,
              fillColor: readOnly ? const Color(0xFFF1F5F9).withOpacity(0.5) : Colors.white,
              hintText: 'Enter $label',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: const Color(0xFFE2E8F0).withOpacity(0.8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: const Color(0xFFE2E8F0).withOpacity(0.8)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF1677F2), width: 2),
              ),
            ),
            validator: (v) => (label == 'Full Name' && (v == null || v.isEmpty)) ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildChipSection(String title, List<String> list, Color color) {
    final controller = TextEditingController();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 1.2),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: list.map((item) => Container(
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 14, color: color),
                  onPressed: () => setState(() => list.remove(item)),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          )).toList(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Add new ${title.toLowerCase().substring(0, title.length-1)}...',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: IconButton(
              icon: const Icon(Icons.add_circle_rounded, color: Color(0xFF1677F2)),
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() => list.add(controller.text.trim()));
                  controller.clear();
                }
              },
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
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

  Widget _buildGradientSaveButton() {
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1677F2), Color(0xFF19D3C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1677F2).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _save,
          borderRadius: BorderRadius.circular(20),
          child: Center(
            child: _isLoading 
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text(
                  'SAVE CHANGES',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                ),
          ),
        ),
      ),
    );
  }
}
