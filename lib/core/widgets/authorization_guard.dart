import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/authorization_service.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../app/theme/app_colors.dart';

class AuthorizationGuard {
  /// The central method to run protected actions.
  /// If the user meets the requirements, [action] is executed.
  /// Otherwise, an appropriate dialog is shown.
  static void run(
    BuildContext context,
    WidgetRef ref, {
    required UlifyFeature feature,
    required VoidCallback action,
  }) {
    final authService = ref.read(authorizationServiceProvider);
    final status = authService.checkAccess(feature);

    switch (status) {
      case AccessStatus.granted:
        action();
        break;
      case AccessStatus.needsEmailVerification:
        _showVerificationRequired(context, ref, feature);
        break;
      case AccessStatus.needsRole:
        _showRoleRequired(context, ref, feature);
        break;
      case AccessStatus.denied:
        _showAccessDenied(context);
        break;
    }
  }

  static void _showVerificationRequired(BuildContext context, WidgetRef ref, UlifyFeature feature) {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.mark_email_read_rounded, size: 40, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Text(
              'Email Verification Required',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'To ensure a safe campus community, we require students to verify their email before performing actions like ${_getFeatureActionLabel(feature)}.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/verify-email');
                },
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Verify My Email', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            Consumer(builder: (context, ref, _) {
              return TextButton(
                onPressed: () {
                  ref.read(authControllerProvider.notifier).sendEmailVerification();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Verification email resent!'), behavior: SnackBarBehavior.floating),
                  );
                },
                child: const Text('Resend Link', style: TextStyle(fontWeight: FontWeight.bold)),
              );
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  static void _showRoleRequired(BuildContext context, WidgetRef ref, UlifyFeature feature) {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.stars_rounded, size: 40, color: Colors.orange),
            ),
            const SizedBox(height: 24),
            Text(
              'Professional Status Needed',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${_getFeatureActionLabel(feature, capitalize: true)} requires a specialized role. Visit the Trust Center to apply for student or professional verification.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/trust-center');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Go to Trust Center', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Maybe Later', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  static void _showAccessDenied(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You do not have permission to perform this action.')),
    );
  }

  static String _getFeatureActionLabel(UlifyFeature feature, {bool capitalize = false}) {
    String label = '';
    switch (feature) {
      case UlifyFeature.marketplacePost: label = 'listing items'; break;
      case UlifyFeature.marketplaceContact: label = 'contacting sellers'; break;
      case UlifyFeature.housingPost: label = 'posting housing'; break;
      case UlifyFeature.housingContact: label = 'requesting viewings'; break;
      case UlifyFeature.communityPost: label = 'posting in community'; break;
      case UlifyFeature.confessionsPost: label = 'posting confessions'; break;
      case UlifyFeature.notesUpload: label = 'uploading notes'; break;
      case UlifyFeature.notesDownload: label = 'downloading materials'; break;
      case UlifyFeature.eventsRSVP: label = 'RSVPing to events'; break;
      case UlifyFeature.eventsOrganize: label = 'organizing events'; break;
      case UlifyFeature.chatStart: label = 'starting new chats'; break;
      case UlifyFeature.gigsPost: label = 'posting gigs'; break;
      case UlifyFeature.gigsApply: label = 'applying for gigs'; break;
      case UlifyFeature.adminDashboard: label = 'accessing admin tools'; break;
      default: label = 'this action';
    }
    
    if (capitalize && label.isNotEmpty) {
      return label[0].toUpperCase() + label.substring(1);
    }
    return label;
  }
}
