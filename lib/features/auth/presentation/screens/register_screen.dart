import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  bool _localLoading = false;

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

    setState(() => _localLoading = true);

    await ref.read(authControllerProvider.notifier).signUp(
      email: email, 
      password: password,
      fullName: fullName,
    );

    if (mounted) {
      final state = ref.read(authControllerProvider);
      if (state.hasError) {
        setState(() => _localLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // Hero Section
            const Text(
              'Create Account',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Join the campus marketplace',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 48),

            // Full Name
            AuthTextField(
              controller: fullNameController,
              hintText: 'Full Name',
              icon: Icons.person_outline,
              enabled: !_localLoading,
            ),

            const SizedBox(height: 18),

            // Email
            AuthTextField(
              controller: emailController,
              hintText: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              enabled: !_localLoading,
            ),

            const SizedBox(height: 18),

            // Password
            PasswordField(
              controller: passwordController,
              hintText: 'Password',
              enabled: !_localLoading,
            ),

            const SizedBox(height: 18),

            // Confirm Password
            PasswordField(
              controller: confirmPasswordController,
              hintText: 'Confirm Password',
              enabled: !_localLoading,
            ),

            const SizedBox(height: 32),

            // Create Account Button
            if (_localLoading)
              const Center(child: CircularProgressIndicator())
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
              onPressed: _localLoading ? null : () async {
                setState(() => _localLoading = true);
                await ref.read(authControllerProvider.notifier).signInWithGoogle();
                if (mounted) {
                  final state = ref.read(authControllerProvider);
                  if (state.hasError) {
                    setState(() => _localLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(state.error.toString().replaceAll('Exception: ', ''))),
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
                  color: Colors.grey.shade500,
                  height: 1.4,
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Already have account
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Already have an account?'),
                TextButton(
                  onPressed: _localLoading ? null : () {
                    context.push('/login');
                  },
                  child: const Text(
                    'Sign In',
                    style: TextStyle(fontWeight: FontWeight.w600),
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
