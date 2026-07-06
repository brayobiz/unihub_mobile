import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/providers.dart';
import '../controllers/auth_controller.dart';
import '../widgets/logout_dialog.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _isResending = false;

  Future<void> _checkVerificationStatus() async {
    await ref.read(authControllerProvider.notifier).checkVerificationStatus();
    
    if (mounted) {
      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user != null && !user.emailVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email not verified yet. Please check your inbox.')),
        );
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    setState(() => _isResending = true);
    await ref.read(authControllerProvider.notifier).sendEmailVerification();
    
    if (mounted) {
      final state = ref.read(authControllerProvider);
      if (state.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${state.error.toString()}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email resent!')),
        );
      }
      setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(firebaseAuthProvider).currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => LogoutDialog.show(context, ref),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            Icon(
              Icons.mark_email_read_outlined,
              size: 100,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 32),
            Text(
              'Verify Your Email',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'We sent a verification link to:\n${user?.email ?? "your email"}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your inbox (and spam folder) and click the link to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: _checkVerificationStatus,
                icon: const Icon(Icons.refresh),
                label: const Text('I Have Verified', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _isResending ? null : _resendVerificationEmail,
              child: _isResending 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Resend Verification Email', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            const Text(
              'Wrong email address? Sign out to register with a different one.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
