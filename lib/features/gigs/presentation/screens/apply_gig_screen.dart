import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../auth/shared/providers.dart';
import '../../../shared/feed_repository.dart';
import '../../domain/models/gig_application.dart';
import '../../shared/providers.dart';

class ApplyGigScreen extends ConsumerStatefulWidget {
  final FeedItem gig;
  const ApplyGigScreen({super.key, required this.gig});

  @override
  ConsumerState<ApplyGigScreen> createState() => _ApplyGigScreenState();
}

class _ApplyGigScreenState extends ConsumerState<ApplyGigScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  final _coverLetterController = TextEditingController();
  final _portfolioController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(appUserProvider).valueOrNull;
    _nameController = TextEditingController(text: user?.fullName);
    _emailController = TextEditingController(text: user?.email);
    _phoneController = TextEditingController(text: user?.phoneNumber);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _coverLetterController.dispose();
    _portfolioController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;

    // Check for legacy data with missing authorId
    if (widget.gig.authorId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This gig post is invalid (missing owner ID). Please try applying for a newer gig.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final application = GigApplication(
        id: const Uuid().v4(),
        gigId: widget.gig.id,
        gigTitle: widget.gig.title,
        employerId: widget.gig.authorId,
        freelancerId: user.uid,
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        coverLetter: _coverLetterController.text.trim(),
        portfolioLink: _portfolioController.text.trim().isNotEmpty 
            ? _portfolioController.text.trim() 
            : null,
        createdAt: DateTime.now(),
      );

      await ref.read(gigsRepositoryProvider).submitApplication(application);
      
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Application Submitted!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                SizedBox(height: 8),
                Text(
                  'Your application has been sent to the employer. We\'ve also created a chat room for you to discuss further.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context); // Pop dialog
                    Navigator.pop(context); // Pop Apply screen
                    Navigator.pop(context); // Pop Details screen
                  },
                  child: const Text('Great!'),
                ),
              ),
            ],
          ),
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Apply for Gig'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Applying for: ${widget.gig.title}',
                    style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 32),
                  
                  _buildLabel('Full Name'),
                  TextFormField(
                    controller: _nameController,
                    decoration: _inputDecoration('e.g., John Doe'),
                    validator: (v) => v!.isEmpty ? 'Enter your full name' : null,
                  ),
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Email Address'),
                            TextFormField(
                              controller: _emailController,
                              decoration: _inputDecoration('email@example.com'),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => v!.isEmpty ? 'Enter email' : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Phone Number'),
                            TextFormField(
                              controller: _phoneController,
                              decoration: _inputDecoration('07...'),
                              keyboardType: TextInputType.phone,
                              validator: (v) => v!.isEmpty ? 'Enter phone' : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  _buildLabel('Cover Letter'),
                  TextFormField(
                    controller: _coverLetterController,
                    decoration: _inputDecoration('Explain why you are the best fit for this gig...'),
                    maxLines: 6,
                    validator: (v) => v!.isEmpty ? 'Please provide a cover letter' : null,
                  ),
                  const SizedBox(height: 20),
                  
                  _buildLabel('Portfolio Link (Optional)'),
                  TextFormField(
                    controller: _portfolioController,
                    decoration: _inputDecoration('e.g., GitHub, Behance, or Website link'),
                  ),
                  const SizedBox(height: 40),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Submit Application', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
    );
  }
}
