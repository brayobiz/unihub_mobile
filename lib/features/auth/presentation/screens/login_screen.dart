import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  bool _localLoading = false;

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

    setState(() => _localLoading = true);

    await ref.read(authControllerProvider.notifier).signIn(email, password);

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
            const SizedBox(height: 80),

            // Hero Section
            const Text(
              'Welcome Back',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to your campus marketplace',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 48),

            AuthTextField(
              controller: emailController,
              hintText: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              enabled: !_localLoading,
            ),

            const SizedBox(height: 18),

            PasswordField(
              controller: passwordController,
              hintText: 'Password',
              enabled: !_localLoading,
            ),

            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _localLoading ? null : () {
                  context.push('/forgot-password');
                },
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ),

            const SizedBox(height: 28),

            if (_localLoading)
              const Center(child: CircularProgressIndicator())
            else
              AuthButton(
                text: 'Sign In',
                onPressed: _onSignIn,
              ),

            const SizedBox(height: 32),

            const DividerText(),

            const SizedBox(height: 32),

            // Professional Google Sign-In Button
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

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Don't have an account?"),
                TextButton(
                  onPressed: _localLoading ? null : () {
                    context.push('/register');
                  },
                  child: const Text(
                    'Create Account',
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
