import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers.dart';
import '../controllers/auth_controller.dart';
import '../widgets/logout_dialog.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> with WidgetsBindingObserver {
  bool _isResending = false;
  Timer? _timer;
  int _resendCountdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Background timer to check status every 5 seconds
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      ref.read(authControllerProvider.notifier).checkVerificationStatus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check immediately when user returns to app
      ref.read(authControllerProvider.notifier).checkVerificationStatus();
    }
  }

  void _startResendCountdown() {
    setState(() => _resendCountdown = 60);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown == 0) {
        timer.cancel();
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  Future<void> _checkVerificationStatus() async {
    // Check silently without changing UI state to 'loading'
    try {
      await ref.read(authControllerProvider.notifier).checkVerificationStatus();
      
      if (mounted) {
        final user = ref.read(firebaseAuthProvider).currentUser;
        if (user != null && user.emailVerified) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email verified successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          // Only show message if they manually clicked, otherwise it's annoying
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Still waiting for verification... Please click the link in your email.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      // Silent fail for polling
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_resendCountdown > 0) return;

    setState(() => _isResending = true);
    try {
      await ref.read(authControllerProvider.notifier).sendEmailVerification();
      if (mounted) {
        final state = ref.read(authControllerProvider);
        if (state.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${state.error.toString()}')),
          );
        } else {
          _startResendCountdown();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification email resent! Please check your inbox.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(firebaseAuthProvider).currentUser;

    // Automatic Closure when verified (Phase 2.2)
    ref.listen(authStateProvider, (previous, next) {
      if (next.value?.emailVerified == true) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    });

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: () => LogoutDialog.show(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mark_email_read_outlined,
                  size: 80,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Confirm Your Identity',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16, height: 1.5),
                  children: [
                    const TextSpan(text: 'We sent a verification link to:\n'),
                    TextSpan(
                      text: user?.email ?? "your email",
                      style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.help_outline_rounded, size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 10),
                        const Text('Can\'t find the email?', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTip(Icons.folder_outlined, 'Check your Spam or Junk folder.'),
                    _buildTip(Icons.label_important_outline, 'Check your Promotions tab (Gmail).'),
                    _buildTip(Icons.search_rounded, 'Search "Ulify" in your inbox.'),
                  ],
                ),
              ),
              
              const SizedBox(height: 48),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: _checkVerificationStatus,
                  icon: const Icon(Icons.verified_user_rounded),
                  label: const Text('I Have Verified', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              TextButton(
                onPressed: (_isResending || _resendCountdown > 0) ? null : _resendVerificationEmail,
                child: _isResending 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      _resendCountdown > 0 
                        ? 'Resend Email in ${_resendCountdown}s' 
                        : 'Resend Verification Email',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
              ),
              
              const SizedBox(height: 40),
              Text(
                'Verification allows you to participate in the community, list items, and chat with others.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTip(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
