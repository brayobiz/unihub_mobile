import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final emailController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  void _onResetPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email')),
      );
      return;
    }

    await ref.read(authControllerProvider.notifier).resetPassword(email);

    if (mounted) {
      final state = ref.read(authControllerProvider);
      if (state.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.error.toString().replaceAll('Exception: ', '')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reset link sent to your email'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              'Forgot Password',
              style: theme.textTheme.displayLarge?.copyWith(
                fontSize: 32,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Enter your email and we will send you a reset link.',
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 48),
            AuthTextField(
              controller: emailController,
              hintText: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              enabled: !isLoading,
            ),
            const SizedBox(height: 32),
            if (isLoading)
              Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
            else
              AuthButton(
                text: 'Send Reset Link',
                onPressed: _onResetPassword,
              ),
          ],
        ),
      ),
    );
  }
}
