import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/feed_type.dart';
import '../auth/shared/providers.dart';
import 'feed_repository.dart';
import 'storage_repository.dart';
import 'package:unihub_mobile/core/widgets/creation_success_dialog.dart';
import '../marketplace/domain/models/marketplace_categories.dart';
import '../gigs/domain/models/gig_categories.dart';

class AddFeedItemScreen extends ConsumerStatefulWidget {
  final FeedType type;
  const AddFeedItemScreen({super.key, required this.type});

  @override
  ConsumerState<AddFeedItemScreen> createState() => _AddFeedItemScreenState();
}

class _AddFeedItemScreenState extends ConsumerState<AddFeedItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _priceController = TextEditingController();
  DateTime? _selectedDeadline;
  final List<XFile> _selectedImages = [];
  bool _isLoading = false;
  double _uploadProgress = 0;
  String? _selectedCategory;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _handleBack() async {
    final bool isDirty = _titleController.text.isNotEmpty || 
                        _contentController.text.isNotEmpty || 
                        _selectedImages.isNotEmpty;
    
    if (!isDirty) {
      Navigator.pop(context);
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
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (proceed == true && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final content = _contentController.text.trim();
    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _uploadProgress = 0;
    });

    try {
      final itemId = const Uuid().v4();
      final imageUrls = <String>[];
      
      // Upload images if any
      for (var i = 0; i < _selectedImages.length; i++) {
        final url = await ref.read(storageRepositoryProvider).uploadFile(
          path: 'feed/$itemId',
          id: 'img_$i',
          file: File(_selectedImages[i].path),
          onProgress: (sent, total) {
            // Since we have multiple images, we approximate the total progress
            setState(() {
              _uploadProgress = (i / _selectedImages.length) + 
                               ((sent / total) / _selectedImages.length);
            });
          },
        );
        imageUrls.add(url);
      }

      setState(() => _uploadProgress = 1.0);

      final item = FeedItem(
        id: itemId,
        authorId: user.uid,
        authorName: user.fullName,
        authorPhotoUrl: user.photoUrl,
        title: _titleController.text.trim(),
        subtitle: content,
        price: _priceController.text.isNotEmpty ? 'KES ${_priceController.text.trim()}' : null,
        type: widget.type,
        university: user.university,
        createdAt: DateTime.now(),
        deadline: _selectedDeadline,
        images: imageUrls,
        category: _selectedCategory,
      );

      await ref.read(feedRepositoryProvider).postToFeed(item);
      if (mounted) {
        String successTitle = 'Post Shared!';
        String successMsg = 'Your post is now visible in the community feed.';
        
        if (widget.type == FeedType.gig) {
          successTitle = 'Gig Listed!';
          successMsg = 'Your student gig is now live. Interested students can now apply.';
        } else if (widget.type == FeedType.confession) {
          successTitle = 'Confession Shared!';
          successMsg = 'Your anonymous confession has been posted to the feed.';
        }

        CreationSuccessDialog.show(
          context,
          title: successTitle,
          message: successMsg,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGig = widget.type == FeedType.gig;
    final isConfession = widget.type == FeedType.confession;
    
    String title = 'Post to Community';
    if (isGig) title = 'Create Gig';
    if (isConfession) title = 'Share Confession';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          title: Text(title, 
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface, 
              fontWeight: FontWeight.bold,
              fontSize: 18,
            )),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
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
                if (isGig) ...[
                  _buildSectionLabel(context, 'Gig Details', Icons.work_outline),
                  const SizedBox(height: 16),
                  _buildModernField(
                    context,
                    controller: _titleController,
                    hint: 'e.g., Graphic Designer for Logo',
                    validator: (v) => v!.isEmpty ? 'Please enter a title' : null,
                  ),
                  const SizedBox(height: 24),
                  _buildSectionLabel(context, 'Classification', Icons.category_outlined),
                  const SizedBox(height: 16),
                  _buildGigCategoryPicker(context),
                  const SizedBox(height: 24),
                  _buildSectionLabel(context, 'Budget & Deadline', Icons.payments_outlined),
                  const SizedBox(height: 16),
                  _buildModernField(
                    context,
                    controller: _priceController,
                    hint: 'Budget (e.g., 1000)',
                    keyboardType: TextInputType.number,
                    prefixText: 'KES ',
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (date != null) setState(() => _selectedDeadline = date);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7), size: 20),
                          const SizedBox(width: 12),
                          Text(
                            _selectedDeadline == null 
                                ? 'Select application deadline' 
                                : 'Deadline: ${DateFormat.yMMMd().format(_selectedDeadline!)}',
                            style: TextStyle(
                              color: _selectedDeadline == null 
                                  ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5) 
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionLabel(context, 'Photos & Media', Icons.camera_alt_outlined),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            final picker = ImagePicker();
                            final images = await picker.pickMultiImage();
                            if (images.isNotEmpty) {
                              setState(() => _selectedImages.addAll(images));
                            }
                          },
                          child: Container(
                            width: 100,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5), style: BorderStyle.solid),
                            ),
                            child: Icon(Icons.add_a_photo_outlined, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                          ),
                        ),
                        ..._selectedImages.map((img) => Container(
                          width: 100,
                          margin: const EdgeInsets.only(left: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: FileImage(File(img.path)),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.topRight,
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedImages.remove(img)),
                              child: Container(
                                margin: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionLabel(context, 'Description', Icons.description_outlined),
                  const SizedBox(height: 16),
                ] else if (!isConfession) ...[
                  _buildSectionLabel(context, 'Post Details', Icons.title_rounded),
                  const SizedBox(height: 16),
                  _buildModernField(
                    context,
                    controller: _titleController,
                    hint: 'Title (optional)',
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  _buildSectionLabel(context, 'Confession', Icons.favorite_rounded),
                  const SizedBox(height: 16),
                ],
                
                _buildModernField(
                  context,
                  controller: _contentController,
                  hint: isGig 
                      ? 'Describe the work, requirements, and what you expect...' 
                      : (isConfession ? 'Share your secret anonymously...' : 'What\'s on your mind?'),
                  maxLines: 12,
                  maxLength: 10000,
                  validator: (v) => v!.isEmpty ? 'Content cannot be empty' : null,
                ),
                
                if (isGig) ...[
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Keep it campus-focused for better responses from fellow students.',
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                if (_isLoading)
                  Column(
                    children: [
                      LinearProgressIndicator(value: _uploadProgress, color: theme.colorScheme.primary, minHeight: 6, borderRadius: BorderRadius.circular(4)),
                      const SizedBox(height: 8),
                      Text('Sharing your post... ${(_uploadProgress * 100).toInt()}%', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 24),
                    ],
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: isGig ? theme.colorScheme.primary : (isConfession ? theme.colorScheme.error : theme.colorScheme.secondary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(isGig ? 'Create Gig' : 'Post Now', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGigCategoryPicker(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionLabel(context, 'Gig Category', Icons.category_outlined),
            GestureDetector(
              onTap: () => _showMarketplaceDifferentiator(),
              child: Text('Selling an item?', 
                style: TextStyle(fontSize: 11, color: theme.colorScheme.primary, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
            ),
          ],
        ),
        InkWell(
          onTap: () => _showGigCategorySheet(),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.category_outlined, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                const SizedBox(width: 12),
                Text(
                  _selectedCategory ?? 'Select a category',
                  style: TextStyle(
                    color: _selectedCategory == null 
                        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5) 
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Icon(Icons.expand_more_rounded, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showGigCategorySheet() {
    final theme = Theme.of(context);
    final categories = GigCategories.all;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select Gig Category', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 10),
            Text('Services and tasks only. Selling items? Go to Marketplace.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 4),
                    title: Text(cat, style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                    trailing: _selectedCategory == cat ? Icon(Icons.check_circle, color: theme.colorScheme.primary) : null,
                    onTap: () {
                      setState(() => _selectedCategory = cat);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMarketplaceDifferentiator() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.lightbulb_outline, color: Colors.amber),
            const SizedBox(width: 10),
            Text('Gigs vs Marketplace', style: TextStyle(color: theme.colorScheme.onSurface)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDiffItem(
              context,
              icon: Icons.work_rounded,
              title: 'Student Gigs',
              desc: 'Offering or hiring for services like tutoring, errands, or design.',
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            _buildDiffItem(
              context,
              icon: Icons.shopping_bag_rounded,
              title: 'Marketplace',
              desc: 'Selling physical items like textbooks, laptops, or clothes.',
              color: Colors.green,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Close add gig
              // Here we'd navigate to add-listing
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Go to Marketplace'),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffItem(BuildContext context, {required IconData icon, required String title, required String desc, required Color color}) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)),
              const SizedBox(height: 2),
              Text(desc, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
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

  Widget _buildModernField(
    BuildContext context, {
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    String? prefixText,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
        prefixIcon: icon != null ? Icon(icon, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)) : null,
        prefixText: prefixText,
        prefixStyle: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.all(16),
        counterStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
      ),
    );
  }
}
