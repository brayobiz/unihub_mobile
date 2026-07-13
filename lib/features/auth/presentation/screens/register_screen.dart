import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/theme/app_colors.dart';
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
  bool _isAgreed = false;

  @override
  void initState() {
    super.initState();
    // Rebuild UI when any input changes to update button states
    fullNameController.addListener(_updateState);
    emailController.addListener(_updateState);
    passwordController.addListener(_updateState);
    confirmPasswordController.addListener(_updateState);
  }

  void _updateState() => setState(() {});

  bool get _isFormValid {
    return fullNameController.text.trim().isNotEmpty &&
           emailController.text.trim().isNotEmpty &&
           passwordController.text.trim().isNotEmpty &&
           confirmPasswordController.text.trim().isNotEmpty &&
           _isAgreed;
  }

  @override
  void dispose() {
    fullNameController.removeListener(_updateState);
    emailController.removeListener(_updateState);
    passwordController.removeListener(_updateState);
    confirmPasswordController.removeListener(_updateState);
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

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // 1. Decorative Background Elements
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            top: 200,
            right: -80,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.03),
              ),
            ),
          ),

          // 2. Main Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Branding
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                        onPressed: () => context.pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'UniHub',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Hero Section
                  Text(
                    'Get Started',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -1.2,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                      children: [
                        const TextSpan(text: 'Join thousands of students in your '),
                        TextSpan(
                          text: 'digital campus',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Form Container
                  Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Column(
                      children: [
                        AuthTextField(
                          controller: fullNameController,
                          hintText: 'Full Name',
                          icon: Icons.person_outline,
                          enabled: !isLoading,
                        ),
                        Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.4), indent: 50),
                        AuthTextField(
                          controller: emailController,
                          hintText: 'Email Address',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !isLoading,
                        ),
                        Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.4), indent: 50),
                        PasswordField(
                          controller: passwordController,
                          hintText: 'Password',
                          enabled: !isLoading,
                        ),
                        Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.4), indent: 50),
                        PasswordField(
                          controller: confirmPasswordController,
                          hintText: 'Confirm Password',
                          enabled: !isLoading,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Age & Terms Agreement
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _isAgreed,
                          onChanged: isLoading ? null : (val) => setState(() => _isAgreed = val ?? false),
                          activeColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isAgreed = !_isAgreed),
                          child: Text(
                            'I confirm I am 18+ and agree to the Terms & Privacy',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Create Account Button
                  if (isLoading)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ))
                  else
                    AuthButton(
                      text: 'Create My Account',
                      onPressed: _isFormValid ? _onSignUp : null,
                    ),

                  const SizedBox(height: 20),

                  const DividerText(),

                  const SizedBox(height: 20),

                  // Google Sign In
                  GoogleSignInButton(
                    onPressed: (isLoading || !_isAgreed) ? null : () async {
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

                  const SizedBox(height: 24),

                  // Footer links
                  Center(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () => _launchUrl('https://unihub-3663e.web.app/terms'),
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              child: Text('Terms', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary.withValues(alpha: 0.7))),
                            ),
                            const Text('•', style: TextStyle(color: Colors.grey, fontSize: 10)),
                            TextButton(
                              onPressed: () => _launchUrl('https://unihub-3663e.web.app/privacy'),
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              child: Text('Privacy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary.withValues(alpha: 0.7))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Already have an account?", 
                              style: GoogleFonts.plusJakartaSans(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 14,
                              ),
                            ),
                            TextButton(
                              onPressed: isLoading ? null : () {
                                context.push('/login');
                              },
                              child: Text(
                                'Sign In',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800, 
                                  color: theme.colorScheme.primary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
