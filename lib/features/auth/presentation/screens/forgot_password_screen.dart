import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../services/connectivity_service.dart';
import '../../../../core/error/error_handler.dart';
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
      _showSnackBar('Please enter your email', isError: true);
      return;
    }

    final connectivity = ref.read(connectivityServiceProvider);
    if (connectivity == ConnectivityStatus.isDisconnected) {
      _showSnackBar('No internet connection. Please check your network and try again.', isError: true);
      return;
    }

    await ref.read(authControllerProvider.notifier).resetPassword(email);

    if (mounted) {
      final state = ref.read(authControllerProvider);
      if (state.hasError) {
        _showSnackBar(AppErrorHandler.mapError(state.error), isError: true);
      } else {
        _showSnackBar('Reset link sent to your email');
        Navigator.pop(context);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, 
              color: Colors.white, 
              size: 20
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
                text: 'Send Link',
                onPressed: _onResetPassword,
              ),
          ],
        ),
      ),
    );
  }
}
