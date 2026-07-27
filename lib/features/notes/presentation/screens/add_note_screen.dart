import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/core/widgets/creation_success_dialog.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/note.dart';
import '../../shared/providers.dart';
import '../controllers/note_upload_controller.dart';

class AddNoteScreen extends ConsumerStatefulWidget {
  final NoteListing? note;
  const AddNoteScreen({super.key, this.note});

  @override
  ConsumerState<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends ConsumerState<AddNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _courseController;
  late final TextEditingController _unitCodeController;
  late final TextEditingController _unitNameController;
  late final TextEditingController _tagController;
  late final TextEditingController _priceController;
  late final TextEditingController _descriptionController;
  
  late String _selectedCategory;
  late String _selectedNoteType;
  late String _selectedYear;
  final List<String> _tags = [];
  
  File? _selectedFile;
  String? _fileName;
  String? _fileSize;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title);
    _courseController = TextEditingController(text: widget.note?.course);
    _unitCodeController = TextEditingController(text: widget.note?.unitCode);
    _unitNameController = TextEditingController(text: widget.note?.unitName);
    _tagController = TextEditingController();
    _priceController = TextEditingController(text: widget.note?.price != null && widget.note!.price > 0 ? widget.note!.price.toInt().toString() : '');
    _descriptionController = TextEditingController(text: widget.note?.description);
    
    _selectedCategory = widget.note?.subjectCategory ?? 'Computer Science';
    _selectedNoteType = widget.note?.noteType ?? 'Lecture Note';
    _selectedYear = widget.note?.yearOfStudy ?? '1';
    
    if (widget.note != null) {
      _tags.addAll(widget.note!.tags);
      final ext = p.extension(widget.note!.fileUrl).toUpperCase().replaceAll('.', '');
      _fileName = 'Existing Document ${ext.isNotEmpty ? "($ext)" : ""}';
    }
  }

  final List<String> _categories = [
    'Computer Science', 'Business', 'Law', 'Medicine', 
    'Engineering', 'Social Sciences', 'Arts', 'Natural Sciences'
  ];

  final List<String> _noteTypes = [
    'Lecture Note', 'Revision Kit', 'Assignment', 'Past Paper', 'Summary'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _courseController.dispose();
    _unitCodeController.dispose();
    _unitNameController.dispose();
    _tagController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx', 'pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final extension = p.extension(file.path).toLowerCase();
      
      if (extension != '.docx' && extension != '.pdf') {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text('Supported formats: PDF (.pdf) and Microsoft Word (.docx).'),
               backgroundColor: Colors.orange,
             )
           );
        }
        return;
      }

      final sizeInBytes = await file.length();
      final sizeInKb = sizeInBytes / 1024;
      final sizeStr = sizeInKb > 1024 
          ? '${(sizeInKb / 1024).toStringAsFixed(1)} MB' 
          : '${sizeInKb.toStringAsFixed(1)} KB';

      setState(() {
        _selectedFile = file;
        _fileName = result.files.single.name;
        _fileSize = sizeStr;
        if (_titleController.text.isEmpty) {
          _titleController.text = _fileName!.split('.').first;
        }
      });
    }
  }

  Future<void> _handleBack() async {
    final bool isDirty = _titleController.text.isNotEmpty || 
                        _selectedFile != null || 
                        _courseController.text.isNotEmpty;
    
    if (!isDirty) {
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
    if (_selectedFile == null && widget.note == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a document file (.pdf or .docx)')));
      return;
    }
    if (_tags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one topic tag')));
      return;
    }

    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;

    final noteId = widget.note?.id ?? const Uuid().v4();
    final note = NoteListing(
      id: noteId,
      authorId: widget.note?.authorId ?? user.uid,
      authorName: widget.note?.authorName ?? user.fullName,
      university: widget.note?.university ?? user.university ?? 'Unknown',
      course: _courseController.text.trim(),
      unitCode: _unitCodeController.text.trim().toUpperCase(),
      unitName: _unitNameController.text.trim(),
      subjectCategory: _selectedCategory,
      tags: _tags,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      fileUrl: widget.note?.fileUrl ?? '',
      noteType: _selectedNoteType,
      yearOfStudy: _selectedYear,
      price: double.tryParse(_priceController.text) ?? 0.0,
      createdAt: widget.note?.createdAt ?? DateTime.now(),
    );

    final success = await ref.read(noteUploadControllerProvider.notifier).uploadNote(
      baseNote: note,
      selectedFile: _selectedFile,
    );
      
    if (success && mounted) {
      CreationSuccessDialog.show(
        context,
        title: widget.note == null ? 'Study Material Shared!' : 'Note Updated!',
        message: widget.note == null
            ? '🚀 Awesome! Your study material has been added to the library.'
            : 'Your study material has been updated successfully.',
        onDone: () {
          if (mounted) {
            context.pop();
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(appUserProvider);
    final uploadState = ref.watch(noteUploadControllerProvider);
    final bool isLoading = uploadState.status.isLoading;

    return userAsync.when(
      data: (user) {
        final bool canUpload = user != null && (user.isAdmin || user.roles.contains('class_rep'));
        
        if (!canUpload) {
          return Scaffold(
            appBar: AppBar(title: const Text('Contribution Access')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(Icons.school_rounded, size: 64, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 24),
                    Text('Global Library Access', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    const Text(
                      'Currently, only Class Representatives and verified contributors can upload study materials to ensure quality and academic integrity.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, height: 1.5, color: Colors.grey),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => context.push('/help'), 
                        icon: const Icon(Icons.verified_user_outlined),
                        label: const Text('Apply for Contributor Status'),
                      ),
                    ),
                  ],
                ),
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
              title: Text(widget.note == null ? 'Upload Notes' : 'Edit Study Material', 
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 18)),
              backgroundColor: theme.colorScheme.surface,
              elevation: 0,
              foregroundColor: theme.colorScheme.onSurface,
              centerTitle: true,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface, size: 20),
                onPressed: _handleBack,
              ),
            ),
            body: SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeaderHint(context),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader(context, 'Document File', Icons.upload_file_rounded),
                          const SizedBox(height: 16),
                          _buildFileSelector(context, isLoading),
                          const SizedBox(height: 32),
                          
                          _buildSectionHeader(context, 'Core Details', Icons.description_outlined),
                          const SizedBox(height: 16),
                          _buildTextField(
                            context,
                            controller: _titleController,
                            label: 'Resource Title',
                            hint: 'e.g. Introduction to Database Systems',
                            validator: (v) => v!.isEmpty ? 'Please enter a title' : null,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            context,
                            controller: _descriptionController,
                            label: 'Overview (Optional)',
                            hint: 'Help others understand what is covered...',
                            maxLines: 3,
                          ),
                          
                          const SizedBox(height: 32),
                          _buildSectionHeader(context, 'Academic Context', Icons.school_outlined),
                          const SizedBox(height: 16),
                          _buildTextField(
                            context,
                            controller: _courseController,
                            label: 'Course / Program',
                            hint: 'e.g. BSc. Computer Science',
                            validator: (v) => v!.isEmpty ? 'Please enter your course' : null,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  context,
                                  controller: _unitCodeController,
                                  label: 'Unit Code',
                                  hint: 'e.g. COM 2101',
                                  validator: (v) => v!.isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildDropdown(
                                  context: context,
                                  label: 'Year of Study',
                                  value: _selectedYear,
                                  items: const ['1', '2', '3', '4', '5', '6'],
                                  onChanged: (v) => setState(() => _selectedYear = v!),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            context,
                            controller: _unitNameController,
                            label: 'Unit Name',
                            hint: 'e.g. Operating Systems',
                            validator: (v) => v!.isEmpty ? 'Please enter the unit name' : null,
                          ),
                          
                          const SizedBox(height: 32),
                          _buildSectionHeader(context, 'Classification', Icons.category_outlined),
                          const SizedBox(height: 16),
                          _buildDropdown(
                            context: context,
                            label: 'Subject Category',
                            value: _selectedCategory,
                            items: _categories,
                            onChanged: (v) => setState(() => _selectedCategory = v!),
                          ),
                          const SizedBox(height: 16),
                          _buildDropdown(
                            context: context,
                            label: 'Note Type',
                            value: _selectedNoteType,
                            items: _noteTypes,
                            onChanged: (v) => setState(() => _selectedNoteType = v!),
                          ),
                          const SizedBox(height: 16),
                          _buildTagsInput(context),
                          
                          const SizedBox(height: 32),
                          _buildSectionHeader(context, 'Access Mode', Icons.payments_outlined),
                          const SizedBox(height: 16),
                          _buildTextField(
                            context,
                            controller: _priceController,
                            label: 'Premium Price (Optional)',
                            hint: 'Leave at 0 to share for FREE',
                            keyboardType: TextInputType.number,
                            prefixIcon: Icons.payments_outlined,
                          ),
                          
                          const SizedBox(height: 48),
                          if (isLoading)
                            Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: uploadState.uploadProgress, 
                                    color: theme.colorScheme.primary, 
                                    minHeight: 8,
                                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  uploadState.uploadProgress < 0.99 
                                    ? 'Uploading material... ${(uploadState.uploadProgress * 100).toInt()}%'
                                    : 'Finalizing shared resource...', 
                                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          _buildSubmitButton(context, isLoading),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildHeaderHint(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        border: Border(bottom: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(Icons.tips_and_updates_outlined, size: 18, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'High-quality notes help your community grow. Please ensure all documents are legible and accurate.',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface, fontWeight: FontWeight.w500, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Text(
          title.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurfaceVariant, letterSpacing: 1.2),
        ),
      ],
    );
  }

  Widget _buildFileSelector(BuildContext context, bool isLoading) {
    final theme = Theme.of(context);
    final bool hasFile = _selectedFile != null || widget.note != null;
    
    String fileExt = '';
    if (_selectedFile != null) {
      fileExt = p.extension(_selectedFile!.path).toUpperCase().replaceAll('.', '');
    } else if (widget.note != null) {
      final url = widget.note!.fileUrl.toLowerCase();
      if (url.contains('.pdf')) fileExt = 'PDF';
      else if (url.contains('.docx')) fileExt = 'DOCX';
      else if (url.contains('.doc')) fileExt = 'DOC';
      else fileExt = 'FILE';
    }

    return InkWell(
      onTap: isLoading ? null : _pickFile,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasFile ? AppColors.success : theme.colorScheme.outlineVariant, 
            width: 2, 
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            if (!hasFile) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(Icons.cloud_upload_outlined, size: 40, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 16),
              Text('Drop your study document here', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: theme.colorScheme.onSurface)),
              const SizedBox(height: 6),
              Text('PDF and DOCX are supported', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
            ] else ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (fileExt == 'PDF' ? Colors.red : Colors.blue).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      fileExt == 'PDF' ? Icons.picture_as_pdf_rounded : Icons.description_rounded, 
                      color: fileExt == 'PDF' ? Colors.red : Colors.blue, 
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_fileName ?? 'Selected Document', 
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(fileExt, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w900)),
                            ),
                            if (_fileSize != null) ...[
                              const SizedBox(width: 8),
                              CircleAvatar(radius: 2, backgroundColor: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                              const SizedBox(width: 8),
                              Text(_fileSize!, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: isLoading ? null : _pickFile,
                    icon: Icon(Icons.sync_rounded, color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTagsInput(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Topics / Tags', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _tagController,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Add a topic (e.g. Java, DBMS)...',
                  hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
                ),
                onFieldSubmitted: (_) => _addTag(),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: _addTag,
              style: IconButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white),
              icon: const Icon(Icons.add, size: 20),
            ),
          ],
        ),
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((tag) => Chip(
              label: Text(tag, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              onDeleted: () => setState(() => _tags.remove(tag)),
              backgroundColor: theme.colorScheme.surface,
              side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
              deleteIconColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            )).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildDropdown({required BuildContext context, required String label, required String value, required List<String> items, required void Function(String?) onChanged}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          dropdownColor: theme.colorScheme.surface,
          items: items.map((t) => DropdownMenuItem(value: t, child: Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface)))).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(BuildContext context, {required TextEditingController controller, required String label, required String hint, int maxLines = 1, TextInputType? keyboardType, IconData? prefixIcon, String? Function(String?)? validator}) {
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
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5), fontWeight: FontWeight.normal, fontSize: 13),
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20, color: theme.colorScheme.primary.withValues(alpha: 0.5)) : null,
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            contentPadding: const EdgeInsets.all(18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5)),
            errorStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(BuildContext context, bool isLoading) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: FilledButton(
        onPressed: isLoading ? null : _submit,
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.primary, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: Text(widget.note == null ? 'Complete Upload' : 'Save Changes',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
      ),
    );
  }
}
