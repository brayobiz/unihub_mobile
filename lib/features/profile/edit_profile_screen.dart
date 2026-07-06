import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/shared/storage_repository.dart';
import 'package:unihub_mobile/core/constants/campus_constants.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _universityController;
  late TextEditingController _courseController;
  late TextEditingController _yearController;
  late TextEditingController _housingController;
  late TextEditingController _whatsappController;
  late TextEditingController _phoneController;
  
  late List<String> _skills;
  late List<String> _interests;
  
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
    _universityController = TextEditingController(text: CampusConstants.getDisplayName(user?.university));
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
      if (kDebugMode) {
        debugPrint('Update Profile Error: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface)),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_isLoading)
            Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('${(_uploadProgress * 100).toInt()}%', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w900))))
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _save,
                child: Text('Save', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: theme.colorScheme.primary)),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          RepaintBoundary(
            child: Stack(
              children: [
                Positioned(
                  top: -100,
                  right: -100,
                  child: _buildBlob(300, theme.colorScheme.primary.withValues(alpha: 0.08)),
                ),
                Positioned(
                  bottom: 200,
                  left: -150,
                  child: _buildBlob(400, const Color(0xFF19D3C5).withValues(alpha: 0.05)),
                ),
                Positioned(
                  top: 400,
                  right: -50,
                  child: _buildBlob(200, theme.colorScheme.secondary.withValues(alpha: 0.06)),
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
                    _buildImagePickers(context),
                    const SizedBox(height: 40),
                    
                    _buildGlassSection(
                      context: context,
                      title: 'Basic Information',
                      icon: Icons.person_rounded,
                      children: [
                        _buildTextField(context, _nameController, 'Full Name', Icons.badge_outlined, readOnly: true),
                        _buildTextField(context, _usernameController, 'Username', Icons.alternate_email_rounded),
                        _buildTextField(context, _bioController, 'Bio', Icons.description_outlined, maxLines: 3),
                      ],
                    ),
                    
                    _buildGlassSection(
                      context: context,
                      title: 'Academic Details',
                      icon: Icons.school_rounded,
                      children: [
                        _buildTextField(context, _universityController, 'University', Icons.account_balance_outlined, readOnly: true),
                        _buildTextField(context, _courseController, 'Course', Icons.menu_book_rounded, readOnly: true),
                        _buildTextField(context, _yearController, 'Year of Study', Icons.calendar_today_rounded, readOnly: true),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lock_outline_rounded, size: 16, color: theme.colorScheme.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Identity fields are locked to preserve account integrity.',
                                  style: TextStyle(fontSize: 11, color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    _buildGlassSection(
                      context: context,
                      title: 'Preferences & Contact',
                      icon: Icons.settings_accessibility_rounded,
                      children: [
                        _buildTextField(context, _housingController, 'Housing Status', Icons.home_outlined),
                        _buildTextField(context, _whatsappController, 'WhatsApp Number', Icons.phone_android_rounded),
                        _buildTextField(context, _phoneController, 'Phone Number', Icons.local_phone_outlined),
                      ],
                    ),

                    _buildGlassSection(
                      context: context,
                      title: 'Skills & Interests',
                      icon: Icons.auto_awesome_rounded,
                      children: [
                        _buildChipSection(context, 'Skills', _skills, theme.colorScheme.primary),
                        const SizedBox(height: 24),
                        _buildChipSection(context, 'Interests', _interests, AppColors.success),
                      ],
                    ),

                    const SizedBox(height: 32),
                    _buildGradientSaveButton(context),
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
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassSection({required BuildContext context, required String title, required IconData icon, required List<Widget> children}) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface, letterSpacing: -0.5),
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

  Widget _buildImagePickers(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.read(appUserProvider).valueOrNull;
    
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF0F172A), theme.colorScheme.primary, const Color(0xFF19D3C5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: theme.colorScheme.surface, shape: BoxShape.circle),
              child: CircleAvatar(
                radius: 65,
                backgroundColor: theme.colorScheme.surfaceVariant,
                backgroundImage: _profileImage != null 
                  ? FileImage(_profileImage!) as ImageProvider
                  : (user?.photoUrl != null ? CachedNetworkImageProvider(user!.photoUrl!) : null),
                child: _profileImage == null && user?.photoUrl == null
                  ? Text(
                      user?.fullName != null && user!.fullName.isNotEmpty 
                          ? user.fullName[0].toUpperCase() 
                          : 'U',
                      style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: theme.colorScheme.primary),
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
                color: theme.colorScheme.onSurface,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.surface, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Icon(Icons.camera_enhance_rounded, color: theme.colorScheme.surface, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(BuildContext context, TextEditingController controller, String label, IconData icon, {int maxLines = 1, bool readOnly = false}) {
    final theme = Theme.of(context);
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
              color: readOnly ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5) : theme.colorScheme.onSurfaceVariant,
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
              color: readOnly ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 20, color: readOnly ? theme.colorScheme.outlineVariant : theme.colorScheme.primary),
              filled: true,
              fillColor: readOnly ? theme.colorScheme.surfaceVariant.withValues(alpha: 0.2) : theme.colorScheme.surface,
              hintText: 'Enter $label',
              hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5), fontWeight: FontWeight.normal),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
            ),
            validator: (v) => (label == 'Full Name' && (v == null || v.isEmpty)) ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildChipSection(BuildContext context, String title, List<String> list, Color color) {
    final theme = Theme.of(context);
    final controller = TextEditingController();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurfaceVariant, letterSpacing: 1.2),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: list.map((item) => Container(
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.1)),
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
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Add new ${title.toLowerCase().substring(0, title.length-1)}...',
            hintStyle: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            filled: true,
            fillColor: theme.colorScheme.surface,
            suffixIcon: IconButton(
              icon: Icon(Icons.add_circle_rounded, color: theme.colorScheme.primary),
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() => list.add(controller.text.trim()));
                  controller.clear();
                }
              },
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
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

  Widget _buildGradientSaveButton(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF0F172A), theme.colorScheme.primary, const Color(0xFF19D3C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
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
                  'Save Changes',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                ),
          ),
        ),
      ),
    );
  }
}
