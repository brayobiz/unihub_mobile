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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _onSignIn() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    await ref.read(authControllerProvider.notifier).signIn(email, password);

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
            const SizedBox(height: 40),

            // Hero Section
            Text(
              'Welcome Back',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to your campus marketplace',
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

            const SizedBox(height: 18),

            PasswordField(
              controller: passwordController,
              hintText: 'Password',
              enabled: !isLoading,
            ),

            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isLoading ? null : () {
                  context.push('/forgot-password');
                },
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                ),
              ),
            ),

            const SizedBox(height: 28),

            if (isLoading)
              Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
            else
              AuthButton(
                text: 'Sign In',
                onPressed: _onSignIn,
              ),

            const SizedBox(height: 32),

            const DividerText(),

            const SizedBox(height: 32),

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

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Don't have an account?", style: TextStyle(color: theme.colorScheme.onSurface)),
                TextButton(
                  onPressed: isLoading ? null : () {
                    context.push('/register');
                  },
                  child: Text(
                    'Create Account',
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
