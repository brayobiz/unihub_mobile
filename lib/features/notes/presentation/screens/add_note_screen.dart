import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import '../../../auth/shared/providers.dart';
import '../../domain/models/note.dart';
import '../../shared/providers.dart';
import '../../../shared/storage_repository.dart';

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
  bool _isLoading = false;
  double _uploadProgress = 0;

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
      _fileName = 'Existing Document (.docx)';
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
      allowedExtensions: ['docx'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final extension = p.extension(file.path).toLowerCase();
      
      if (extension != '.docx') {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text('Only Microsoft Word (.docx) documents are supported at the moment. PDF support will be available in a future update.'),
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFile == null && widget.note == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a .docx file')));
      return;
    }
    if (_tags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one topic tag')));
      return;
    }

    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _uploadProgress = 0;
    });

    try {
      final noteId = widget.note?.id ?? const Uuid().v4();
      String fileUrl = widget.note?.fileUrl ?? '';
      
      if (_selectedFile != null) {
        fileUrl = await ref.read(storageRepositoryProvider).uploadFile(
          path: 'notes/$noteId',
          id: 'document',
          file: _selectedFile!,
          onProgress: (sent, total) {
            setState(() => _uploadProgress = sent / total);
          },
        );
      }

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
        fileUrl: fileUrl,
        noteType: _selectedNoteType,
        yearOfStudy: _selectedYear,
        price: double.tryParse(_priceController.text) ?? 0.0,
        createdAt: widget.note?.createdAt ?? DateTime.now(),
      );

      await ref.read(notesRepositoryProvider).createNote(note);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.note == null ? 'Note published successfully!' : 'Note updated successfully!'),
            backgroundColor: Colors.green,
          )
        );
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(widget.note == null ? 'Share Study Notes' : 'Edit Study Note', 
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeaderHint(),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFileSelector(),
                    const SizedBox(height: 32),
                    
                    _buildSectionHeader('Note Details', Icons.description_outlined),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _titleController,
                      label: 'Title',
                      hint: 'e.g. Introduction to Database Systems',
                      validator: (v) => v!.isEmpty ? 'Please enter a title' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Brief Description',
                      hint: 'Help others understand what is covered...',
                      maxLines: 3,
                    ),
                    
                    const SizedBox(height: 32),
                    _buildSectionHeader('Academic Context', Icons.school_outlined),
                    const SizedBox(height: 16),
                    _buildTextField(
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
                            controller: _unitCodeController,
                            label: 'Unit Code',
                            hint: 'e.g. COM 2101',
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDropdown(
                            label: 'Year of Study',
                            value: _selectedYear,
                            items: ['1', '2', '3', '4', '5', '6'],
                            onChanged: (v) => setState(() => _selectedYear = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _unitNameController,
                      label: 'Unit Name',
                      hint: 'e.g. Operating Systems',
                      validator: (v) => v!.isEmpty ? 'Please enter the unit name' : null,
                    ),
                    
                    const SizedBox(height: 32),
                    _buildSectionHeader('Classification', Icons.category_outlined),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      label: 'Subject Category',
                      value: _selectedCategory,
                      items: _categories,
                      onChanged: (v) => setState(() => _selectedCategory = v!),
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      label: 'Note Type',
                      value: _selectedNoteType,
                      items: _noteTypes,
                      onChanged: (v) => setState(() => _selectedNoteType = v!),
                    ),
                    const SizedBox(height: 16),
                    _buildTagsInput(),
                    
                    const SizedBox(height: 32),
                    _buildSectionHeader('Access & Pricing', Icons.payments_outlined),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _priceController,
                      label: 'Price (KES)',
                      hint: 'Leave empty or 0 for FREE',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.payments_outlined,
                    ),
                    
                    const SizedBox(height: 48),
                    _buildSubmitButton(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: Colors.indigo.shade50,
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.indigo.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Help your fellow students by sharing high-quality .docx notes.',
              style: TextStyle(fontSize: 12, color: Colors.indigo.shade900, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.indigo),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildFileSelector() {
    final bool hasFile = _selectedFile != null || widget.note != null;
    
    return InkWell(
      onTap: _isLoading ? null : _pickFile,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: hasFile ? Colors.white : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: hasFile ? Colors.green.shade300 : Colors.grey.shade200, 
            width: 2, 
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            if (!hasFile) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.indigo.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.upload_file_rounded, size: 32, color: Colors.indigo),
              ),
              const SizedBox(height: 16),
              Text('Select Microsoft Word Document', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text('Only .docx files are supported', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ] else ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_fileName ?? 'Selected Document', 
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Row(
                          children: [
                            Text('.DOCX', style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.bold)),
                            if (_fileSize != null) ...[
                              const SizedBox(width: 8),
                              const CircleAvatar(radius: 2, backgroundColor: Colors.grey),
                              const SizedBox(width: 8),
                              Text(_fileSize!, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : _pickFile,
                    child: const Text('Change', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTagsInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Topics / Tags', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _tagController,
                decoration: InputDecoration(
                  hintText: 'Add a topic (e.g. Java, DBMS)...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                ),
                onFieldSubmitted: (_) => _addTag(),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: _addTag,
              style: IconButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
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
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.indigo.shade100),
              deleteIconColor: Colors.red.shade400,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            )).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildDropdown({required String label, required String value, required List<String> items, required void Function(String?) onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          items: items.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)))).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required String hint, int maxLines = 1, TextInputType? keyboardType, IconData? prefixIcon, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal, fontSize: 13),
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20, color: Colors.indigo.shade300) : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.indigo, width: 1.5)),
            errorStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: FilledButton(
        onPressed: _isLoading ? null : _submit,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.indigo, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: _isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center, 
                children: [
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)), 
                  const SizedBox(width: 16), 
                  Text('Uploading ${(_uploadProgress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                ]
              )
            : Text(widget.note == null ? 'Publish Study Material' : 'Save Changes', 
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
