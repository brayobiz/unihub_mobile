import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unihub_mobile/features/auth/domain/models/app_user.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/trust/presentation/providers/trust_providers.dart';
import 'package:unihub_mobile/features/trust/domain/models/student_verification.dart';
import 'package:unihub_mobile/features/trust/domain/models/identity_verification.dart';

class TrustCenterScreen extends ConsumerWidget {
  const TrustCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final appUserAsync = ref.watch(appUserProvider);
    final studentVerificationAsync = ref.watch(studentVerificationProvider);
    final identityVerificationAsync = ref.watch(identityVerificationProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text('Trust & Verification', 
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          )),
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: appUserAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('User not found'));
          
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Header & Explanation
              SliverToBoxAdapter(
                child: _buildHeader(context),
              ),

              // 2. Trust Score & Status
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: InkWell(
                    onTap: () => _showTrustBreakdown(context, user),
                    borderRadius: BorderRadius.circular(24),
                    child: _buildTrustOverview(user),
                  ),
                ),
              ),

              // 3. Platform Verification
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Platform Verification',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'These verifications establish your identity across all of UniHub.',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      studentVerificationAsync.when(
                        data: (v) => _buildStudentVerificationCard(context, user, v),
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, _) => _buildErrorCard(context, 'Student Status Error: $e'),
                      ),
                      const SizedBox(height: 12),
                      identityVerificationAsync.when(
                        data: (v) => _buildIdentityVerificationCard(context, user, v),
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, _) => _buildErrorCard(context, 'Identity Verification Error: $e'),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Educational Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildEducationSection(context),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.2)),
      ),
      child: Text(message, style: TextStyle(color: theme.colorScheme.error)),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.verified_user_rounded, color: theme.colorScheme.primary, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            'Single Identity, Total Trust',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Verify your identity once and unlock professional roles across the entire platform.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustOverview(user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1677F2), Color(0xFF19D3C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1677F2).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Platform Trust Score',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Overall reputation on UniHub',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '${user.displayTrustScore.toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: user.displayTrustScore / 100,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityVerificationCard(BuildContext context, AppUser user, IdentityVerification? v) {
    final theme = Theme.of(context);
    final bool isVerified = user.isIdentityVerified;
    
    // Check both sources of truth
    final bool isPending = v?.status == IdentityVerificationStatus.pending || user.identityStatus == 'pending';
    final bool isRejected = v?.status == IdentityVerificationStatus.rejected || user.identityStatus == 'rejected';
    final bool isUnderReview = v?.status == IdentityVerificationStatus.underReview || user.identityStatus == 'underReview';
    final bool isResubmit = v?.status == IdentityVerificationStatus.resubmissionRequested || user.identityStatus == 'resubmissionRequested';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isVerified ? const Color(0xFF10B981) : (isRejected ? theme.colorScheme.error : (isResubmit ? Colors.orange : theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isVerified ? const Color(0xFF10B981) : (isRejected ? theme.colorScheme.error : (isResubmit ? Colors.orange : theme.colorScheme.primary))).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isVerified ? Icons.badge_rounded : (isRejected ? Icons.error_outline_rounded : (isResubmit ? Icons.refresh_rounded : Icons.badge_outlined)),
                  color: isVerified ? const Color(0xFF10B981) : (isRejected ? theme.colorScheme.error : (isResubmit ? Colors.orange : theme.colorScheme.primary)),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Identity Verification',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      isVerified 
                        ? 'Your identity is confirmed' 
                        : isPending 
                          ? 'Review in progress' 
                          : isUnderReview
                            ? 'Actively being reviewed'
                            : isResubmit
                              ? 'Action required: Resubmit docs'
                              : isRejected 
                                ? 'Verification rejected'
                                : 'Verify your ID and face to build trust',
                      style: TextStyle(
                        fontSize: 13,
                        color: isRejected ? theme.colorScheme.error : (isResubmit ? Colors.orange : theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              if (isVerified)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981))
              else if (isPending || isUnderReview)
                _buildStatusBadge(context, isUnderReview ? 'Reviewing' : 'Pending', Colors.orange)
              else if (isResubmit)
                _buildStatusBadge(context, 'Resubmit', Colors.orange)
              else if (isRejected)
                _buildStatusBadge(context, 'Rejected', theme.colorScheme.error)
            ],
          ),
          if (isPending || isUnderReview) ...[
            const SizedBox(height: 16),
            _buildInfoBox(context, isUnderReview 
              ? 'An administrator is currently reviewing your documents.'
              : 'Our team is verifying your government ID. This usually takes 12-24 hours.'),
          ],
          if (isResubmit && v?.rejectionReason != null) ...[
            const SizedBox(height: 12),
            _buildWarningBox(context, 'Resubmission Needed: ${v!.rejectionReason}'),
          ],
          if (isRejected && v?.rejectionReason != null) ...[
            const SizedBox(height: 12),
            _buildErrorBox(context, 'Reason: ${v!.rejectionReason}'),
          ],
          if (!isVerified && !isPending && !isUnderReview) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/verify-identity'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRejected ? theme.colorScheme.error : (isResubmit ? Colors.orange : theme.colorScheme.primary),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(isResubmit ? 'Resubmit Identity' : 'Verify Identity', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWarningBox(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12, 
                color: Colors.orange, 
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text, 
            style: TextStyle(
              fontSize: 11, 
              fontWeight: FontWeight.w800, 
              color: color
            )
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12, 
                color: theme.colorScheme.onSurfaceVariant, 
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentVerificationCard(BuildContext context, AppUser user, StudentVerification? v) {
    final theme = Theme.of(context);
    final bool isVerified = user.isStudentVerified;
    
    // Check both the verification document status and the user document status for robustness
    final bool isPending = v?.status == StudentVerificationStatus.pending || user.studentStatus == 'pending';
    final bool isRejected = v?.status == StudentVerificationStatus.rejected || user.studentStatus == 'rejected';
    final bool isUnderReview = v?.status == StudentVerificationStatus.underReview || user.studentStatus == 'underReview';
    final bool isResubmit = v?.status == StudentVerificationStatus.resubmissionRequested || user.studentStatus == 'resubmissionRequested';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isVerified ? const Color(0xFF10B981) : (isRejected ? theme.colorScheme.error : (isResubmit ? Colors.orange : theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isVerified ? const Color(0xFF10B981) : (isRejected ? theme.colorScheme.error : (isResubmit ? Colors.orange : theme.colorScheme.primary))).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isVerified ? Icons.school_rounded : (isRejected ? Icons.error_outline_rounded : (isResubmit ? Icons.refresh_rounded : Icons.school_outlined)),
                  color: isVerified ? const Color(0xFF10B981) : (isRejected ? theme.colorScheme.error : (isResubmit ? Colors.orange : theme.colorScheme.primary)),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student Status',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      isVerified 
                        ? 'Confirmed Student' 
                        : isPending 
                          ? 'Review in progress' 
                          : isUnderReview
                            ? 'Actively being reviewed'
                            : isResubmit
                              ? 'Action required: Resubmit ID'
                              : isRejected 
                                ? 'Verification rejected'
                                : 'Verify your campus enrollment',
                      style: TextStyle(
                        fontSize: 13,
                        color: isRejected ? theme.colorScheme.error : (isResubmit ? Colors.orange : theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              if (isVerified)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981))
              else if (isPending || isUnderReview)
                _buildStatusBadge(context, isUnderReview ? 'Reviewing' : 'Pending', Colors.orange)
              else if (isResubmit)
                _buildStatusBadge(context, 'Resubmit', Colors.orange)
              else if (isRejected)
                _buildStatusBadge(context, 'Rejected', theme.colorScheme.error)
            ],
          ),
          if (isPending || isUnderReview) ...[
            const SizedBox(height: 16),
            _buildInfoBox(context, isUnderReview
              ? 'An administrator is currently reviewing your student ID.'
              : 'Our team is verifying your student ID. This usually takes 12-24 hours.'),
          ],
          if (isResubmit && v?.rejectionReason != null) ...[
            const SizedBox(height: 12),
            _buildWarningBox(context, 'Resubmission Needed: ${v!.rejectionReason}'),
          ],
          if (isRejected && v?.rejectionReason != null) ...[
            const SizedBox(height: 12),
            _buildErrorBox(context, 'Reason: ${v!.rejectionReason}'),
          ],
          if (!isVerified && !isPending && !isUnderReview) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/verify-student'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRejected ? theme.colorScheme.error : (isResubmit ? Colors.orange : theme.colorScheme.primary),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(isResubmit ? 'Resubmit Student ID' : 'Verify Student Status', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorBox(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12, 
                color: theme.colorScheme.error, 
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEducationSection(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How Trust Works',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildEduItem(
            context,
            Icons.verified_user_outlined,
            'Universal Identity',
            'Your identity is verified once. This confirmation carries across all roles on UniHub, from Selling to Professional Gigs.',
          ),
          const SizedBox(height: 20),
          _buildEduItem(
            context,
            Icons.insights_rounded,
            'Dynamic Trust Score',
            'Your score grows as you complete successful transactions, receive positive ratings, and maintain professional behavior.',
          ),
          const SizedBox(height: 20),
          _buildEduItem(
            context,
            Icons.security_rounded,
            'Safe Community',
            'Verified badges help students identify legitimate providers and build a safer campus marketplace for everyone.',
          ),
        ],
      ),
    );
  }

  Widget _buildEduItem(BuildContext context, IconData icon, String title, String description) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showTrustBreakdown(BuildContext context, dynamic user) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trust Score Breakdown', 
              style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text('Your score is a deterministic reflection of your verified milestones and platform activity.', 
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14)),
            const SizedBox(height: 32),
            _buildBreakdownItem(context, Icons.badge_rounded, 'Identity Verification', user.isIdentityVerified ? 'Confirmed (+30%)' : 'Not Verified', user.isIdentityVerified),
            Divider(height: 32, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            _buildBreakdownItem(context, Icons.school_rounded, 'Student Verification', user.isStudentVerified ? 'Verified (+20%)' : 'Not Verified', user.isStudentVerified),
            Divider(height: 32, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            _buildBreakdownItem(context, Icons.verified_user_rounded, 'Professional Roles', user.verifiedRoles.isNotEmpty ? '${user.verifiedRoles.length} Roles (+${(user.verifiedRoles.length.clamp(0, 3) * 5).toInt()}%)' : 'No verified roles', user.verifiedRoles.isNotEmpty),
            Divider(height: 32, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            _buildBreakdownItem(context, Icons.person_outline_rounded, 'Profile Completion', '${(user.profileCompletion * 100).toInt()}% (+${(user.profileCompletion * 10).toInt()}%)', user.profileCompletion > 0),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownItem(BuildContext context, IconData icon, String title, String subtitle, bool isPositive) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (isPositive ? const Color(0xFF10B981) : theme.colorScheme.outlineVariant).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isPositive ? const Color(0xFF10B981) : theme.colorScheme.onSurfaceVariant, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: theme.colorScheme.onSurface)),
              Text(subtitle, style: TextStyle(color: isPositive ? const Color(0xFF059669) : theme.colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        if (isPositive)
          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
      ],
    );
  }
}
