import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';

class OrganizerOnboardingScreen extends ConsumerWidget {
  const OrganizerOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(appUserProvider).valueOrNull;
    
    final isIdentityVerified = user?.isIdentityVerified ?? false;
    final identityStatus = user?.identityStatus ?? 'none';

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  isIdentityVerified ? Icons.verified_user_rounded : Icons.fingerprint_rounded,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                isIdentityVerified ? 'Host events on campus' : 'Identity Verification Required',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isIdentityVerified 
                  ? 'To publish events on Ulify, you\'ll first create an Organizer Profile. This helps keep campus events trustworthy by showing students who is hosting each event.'
                  : 'To ensure campus safety and trust, all organizers must first complete Ulify Identity Verification. This process only takes a few minutes.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              if (!isIdentityVerified && identityStatus == 'pending')
                _buildStatusBanner(
                  context, 
                  Icons.hourglass_empty_rounded, 
                  'Your identity verification is currently being reviewed. Please check back later.',
                  Colors.amber,
                )
              else if (!isIdentityVerified && identityStatus == 'rejected')
                _buildStatusBanner(
                  context, 
                  Icons.error_outline_rounded, 
                  'Your previous identity verification was rejected. Please re-verify to continue.',
                  theme.colorScheme.error,
                )
              else
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isIdentityVerified
                          ? 'Your application will be reviewed by Ulify administrators before you can publish events.'
                          : 'You will need a valid student ID or Government-issued ID to complete this step.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (isIdentityVerified) {
                      context.pushReplacementNamed('become-organizer');
                    } else if (identityStatus == 'pending') {
                      context.pop();
                    } else {
                      context.push('/verify-identity');
                    }
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    isIdentityVerified 
                      ? 'Get Started' 
                      : (identityStatus == 'pending' ? 'Go Back' : 'Verify Identity'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Maybe Later'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context, IconData icon, String message, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13, 
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
