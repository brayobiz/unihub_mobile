import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/divider_text.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/password_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _onSignUp() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();
    final fullName = fullNameController.text.trim();

    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty || fullName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    await ref.read(authControllerProvider.notifier).signUp(
      email: email, 
      password: password,
      fullName: fullName,
    );

    if (mounted) {
      final state = ref.read(authControllerProvider);
      if (state.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.error.toString().replaceAll('Exception: ', '')),
            behavior: SnackBarBehavior.floating,
          ),
        );
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
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // Hero Section
            Text(
              'Create Account',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Join the campus marketplace',
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 48),

            // Full Name
            AuthTextField(
              controller: fullNameController,
              hintText: 'Full Name',
              icon: Icons.person_outline,
              enabled: !isLoading,
            ),

            const SizedBox(height: 18),

            // Email
            AuthTextField(
              controller: emailController,
              hintText: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              enabled: !isLoading,
            ),

            const SizedBox(height: 18),

            // Password
            PasswordField(
              controller: passwordController,
              hintText: 'Password',
              enabled: !isLoading,
            ),

            const SizedBox(height: 18),

            // Confirm Password
            PasswordField(
              controller: confirmPasswordController,
              hintText: 'Confirm Password',
              enabled: !isLoading,
            ),

            const SizedBox(height: 32),

            // Create Account Button
            if (isLoading)
              Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
            else
              AuthButton(
                text: 'Create Account',
                onPressed: _onSignUp,
              ),

            const SizedBox(height: 32),

            const DividerText(),

            const SizedBox(height: 32),

            // Google Sign In
            GoogleSignInButton(
              onPressed: isLoading ? null : () async {
                await ref.read(authControllerProvider.notifier).signInWithGoogle();
                if (mounted) {
                  final state = ref.read(authControllerProvider);
                  if (state.hasError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.error.toString().replaceAll('Exception: ', '')),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
            ),

            const SizedBox(height: 40),

            // Privacy Note
            Center(
              child: Text(
                'We respect your privacy.\nOnly minimal data is used for personalization.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Already have account
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Already have an account?', style: TextStyle(color: theme.colorScheme.onSurface)),
                TextButton(
                  onPressed: isLoading ? null : () {
                    context.push('/login');
                  },
                  child: Text(
                    'Sign In',
                    style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
