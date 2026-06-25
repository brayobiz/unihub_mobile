import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/note.dart';
import '../../shared/providers.dart';
import '../../../shared/storage_repository.dart';

class AddNoteScreen extends ConsumerStatefulWidget {
  const AddNoteScreen({super.key});

  @override
  ConsumerState<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends ConsumerState<AddNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _courseController = TextEditingController();
  final _unitCodeController = TextEditingController();
  final _unitNameController = TextEditingController();
  final _tagController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedCategory = 'Computer Science';
  String _selectedNoteType = 'Lecture Note';
  String _selectedYear = '1';
  final List<String> _tags = [];
  
  File? _selectedFile;
  String? _fileName;
  bool _isLoading = false;
  double _uploadProgress = 0;

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
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _fileName = result.files.single.name;
        if (_titleController.text.isEmpty) {
          _titleController.text = _fileName!.split('.').first;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a file')));
      return;
    }
    if (_tags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one tag')));
      return;
    }

    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _uploadProgress = 0;
    });

    try {
      final noteId = const Uuid().v4();
      
      final fileUrl = await ref.read(storageRepositoryProvider).uploadFile(
        path: 'notes/$noteId',
        id: 'document',
        file: _selectedFile!,
        onProgress: (sent, total) {
          setState(() => _uploadProgress = sent / total);
        },
      );

      final note = NoteListing(
        id: noteId,
        authorId: user.uid,
        authorName: user.fullName,
        university: user.university ?? 'Unknown',
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
        createdAt: DateTime.now(),
      );

      await ref.read(notesRepositoryProvider).createNote(note);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note uploaded successfully!')));
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Upload Study Note', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFileSelector(),
              const SizedBox(height: 32),
              _buildSectionLabel('Academic Info'),
              _buildTextField(
                controller: _courseController,
                label: 'Course / Program',
                hint: 'e.g. BSc. Computer Science',
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _unitCodeController,
                      label: 'Unit Code',
                      hint: 'e.g. BIT 2204',
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
                hint: 'e.g. Data Structures and Algorithms',
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 32),
              _buildSectionLabel('Categorization'),
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
              _buildSectionLabel('Note Details'),
              _buildTextField(
                controller: _titleController,
                label: 'Title',
                hint: 'e.g. Detailed Linked Lists Notes',
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'What is covered in this note?',
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _priceController,
                label: 'Price (KES) - Optional',
                hint: '0 for free',
                keyboardType: TextInputType.number,
                prefixIcon: Icons.payments_outlined,
              ),
              const SizedBox(height: 40),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileSelector() {
    return InkWell(
      onTap: _isLoading ? null : _pickFile,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: _selectedFile != null ? Colors.green.shade50 : Colors.indigo.shade50.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _selectedFile != null ? Colors.green.shade200 : Colors.indigo.shade100, 
            width: 2, 
            style: BorderStyle.solid
          ),
        ),
        child: Column(
          children: [
            AnimatedRotation(
              duration: const Duration(milliseconds: 500),
              turns: _selectedFile != null ? 1 : 0,
              child: Icon(
                _selectedFile != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined, 
                size: 48, 
                color: _selectedFile != null ? Colors.green : Colors.indigo
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _fileName ?? 'Tap to select PDF, DOC, or PPT', 
              textAlign: TextAlign.center, 
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                color: _selectedFile != null ? Colors.green.shade700 : Colors.indigo.shade700
              )
            ),
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
                  hintText: 'Add a topic...',
                  filled: true,
                  fillColor: const Color(0xFFF8F9FB),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
                onFieldSubmitted: (_) => _addTag(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _addTag,
              icon: const Icon(Icons.add_circle, color: Colors.indigo),
            ),
          ],
        ),
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((tag) => Chip(
              label: Text(tag, style: const TextStyle(fontSize: 12)),
              onDeleted: () => setState(() => _tags.remove(tag)),
              backgroundColor: Colors.indigo.shade50,
              deleteIconColor: Colors.indigo,
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
          items: items.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8F9FB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.indigo, letterSpacing: 0.5)),
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
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20, color: Colors.indigo.shade300) : null,
            filled: true,
            fillColor: const Color(0xFFF8F9FB),
            contentPadding: const EdgeInsets.all(18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.indigo, width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: _isLoading ? null : _submit,
        style: FilledButton.styleFrom(backgroundColor: Colors.indigo, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: _isLoading
            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)), const SizedBox(width: 12), Text('Uploading ${(_uploadProgress * 100).toInt()}%')])
            : const Text('Publish Study Material', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
