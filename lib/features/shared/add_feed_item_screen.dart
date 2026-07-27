import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../app/theme/app_colors.dart';
import '../../models/feed_type.dart';
import '../auth/shared/providers.dart';
import 'feed_repository.dart';
import 'add_feed_item_controller.dart';
import 'package:unihub_mobile/core/widgets/creation_success_dialog.dart';
import '../marketplace/domain/models/marketplace_categories.dart';
import '../gigs/domain/models/gig_categories.dart';
import '../confessions/domain/models/confession_categories.dart';
import '../community/domain/models/community_categories.dart';

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
    
    final isConfession = widget.type == FeedType.confession;
    final content = _contentController.text.trim();

    // Harden Validation: Minimum length for quality content
    if (content.length < (isConfession ? 10 : 3)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isConfession ? 'Confession too short. Please express yourself a bit more.' : 'Post content too short.'))
      );
      return;
    }

    if (widget.type == FeedType.gig && _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category.'))
      );
      return;
    }

    final success = await ref.read(addFeedItemControllerProvider.notifier).submit(
      type: widget.type,
      title: _titleController.text.trim(),
      content: content,
      price: _priceController.text.trim(),
      deadline: _selectedDeadline,
      images: _selectedImages.map((e) => File(e.path)).toList(),
      category: _selectedCategory,
    );
      
    if (success && mounted) {
      String successTitle = 'Post Shared!';
      String successMsg = 'Your post is now visible in the community feed.';
      
      if (widget.type == FeedType.gig) {
        successTitle = 'Gig Listed!';
        successMsg = 'Your student gig is now live. Interested students can now apply.';
      } else if (widget.type == FeedType.confession) {
        successTitle = 'Confession Shared!';
        successMsg = 'Your secret is safe with us. It has been posted anonymously to the community.';
      }

      CreationSuccessDialog.show(
        context,
        title: successTitle,
        message: successMsg,
        onDone: () {
          if (mounted) {
            if (isConfession) {
              context.go('/confessions');
            } else if (widget.type == FeedType.community) {
              context.go('/community');
            } else if (widget.type == FeedType.gig) {
              context.go('/gigs');
            } else {
              context.pop();
            }
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(addFeedItemControllerProvider);
    
    final isGig = widget.type == FeedType.gig;
    final isConfession = widget.type == FeedType.confession;
    
    String title = 'Post to Community';
    if (isGig) title = 'Create Gig';
    if (isConfession) title = 'Share Confession';

    ref.listen(addFeedItemControllerProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: AppColors.error),
        );
      }
    });

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
            style: GoogleFonts.plusJakartaSans(
              color: theme.colorScheme.onSurface, 
              fontWeight: FontWeight.w700,
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
                if (isConfession) ...[
                  _buildConfessionHeader(context),
                  const SizedBox(height: 32),
                  _buildSectionLabel(context, 'Your Confession', Icons.favorite_rounded),
                  const SizedBox(height: 16),
                ] else if (isGig) ...[
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
                ] else ...[
                  _buildSectionLabel(context, 'Post Details', Icons.title_rounded),
                  const SizedBox(height: 16),
                  _buildModernField(
                    context,
                    controller: _titleController,
                    hint: 'Title (optional)',
                  ),
                  const SizedBox(height: 24),
                ],
                
                _buildModernField(
                  context,
                  controller: _contentController,
                  hint: isGig 
                      ? 'Describe the work, requirements, and what you expect...' 
                      : (isConfession ? 'What\'s your secret? No one will ever know it was you.' : 'What\'s on your mind?'),
                  maxLines: isConfession ? 8 : 12,
                  maxLength: 2000,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Content cannot be empty';
                    if (isConfession && v.trim().length < 10) return 'Please write at least 10 characters';
                    return null;
                  },
                ),
                
                if (isConfession) ...[
                   const SizedBox(height: 24),
                   Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined, color: AppColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Strictly Anonymous: Your profile, name, and location are never attached to confessions.',
                            style: GoogleFonts.plusJakartaSans(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

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
                if (state.isLoading)
                  Column(
                    children: [
                      LinearProgressIndicator(value: state.uploadProgress, color: theme.colorScheme.primary, minHeight: 6, borderRadius: BorderRadius.circular(4)),
                      const SizedBox(height: 8),
                      Text('Sharing your post... ${(state.uploadProgress * 100).toInt()}%', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 12)),
                      const SizedBox(height: 24),
                    ],
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: FilledButton(
                    onPressed: state.isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: isConfession ? AppColors.primary : (isGig ? theme.colorScheme.primary : theme.colorScheme.secondary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      isConfession ? 'Post Anonymously' : (isGig ? 'Create Gig' : 'Post Now'), 
                      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)
                    ),
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

  Widget _buildConfessionHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Speak freely.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          'Share your thoughts without revealing your identity.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }


  Widget _buildCommunityCategoryPicker(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _showCommunityCategorySheet(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(
              _selectedCategory != null 
                  ? CommunityCategories.getIcon(_selectedCategory!) 
                  : Icons.category_outlined, 
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              _selectedCategory ?? 'Select a category',
              style: TextStyle(
                fontSize: 14,
                color: _selectedCategory == null 
                    ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5) 
                    : theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            Icon(Icons.expand_more_rounded, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7), size: 18),
          ],
        ),
      ),
    );
  }

  void _showCommunityCategorySheet() {
    final theme = Theme.of(context);
    final categories = CommunityCategories.all;
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
            Text('Select Category', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 10),
            Text('Where does this post fit best?', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(CommunityCategories.getIcon(cat), color: theme.colorScheme.primary, size: 20),
                    ),
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

  Widget _buildConfessionCategoryPicker(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _showConfessionCategorySheet(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(
              _selectedCategory != null 
                  ? ConfessionCategories.getIcon(_selectedCategory!) 
                  : Icons.category_outlined, 
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              _selectedCategory ?? 'Select a category',
              style: TextStyle(
                fontSize: 14,
                color: _selectedCategory == null 
                    ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5) 
                    : theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            Icon(Icons.expand_more_rounded, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7), size: 18),
          ],
        ),
      ),
    );
  }

  void _showConfessionCategorySheet() {
    final theme = Theme.of(context);
    final categories = ConfessionCategories.all;
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
            Text('Select Category', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 10),
            Text('Tag your confession for better discoverability.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ConfessionCategories.getColor(cat).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(ConfessionCategories.getIcon(cat), color: ConfessionCategories.getColor(cat), size: 20),
                    ),
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
                style: TextStyle(fontSize: 11, color: theme.colorScheme.primary, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
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
            Text('Select Gig Category', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
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
              Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: theme.colorScheme.onSurface)),
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
            fontSize: 14,
            fontWeight: FontWeight.w600,
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
      style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5), fontWeight: FontWeight.w400),
        prefixIcon: icon != null ? Icon(icon, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)) : null,
        prefixText: prefixText,
        prefixStyle: TextStyle(fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface),
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
