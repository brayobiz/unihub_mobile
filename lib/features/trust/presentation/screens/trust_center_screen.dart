import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/trust/presentation/providers/trust_providers.dart';
import 'package:unihub_mobile/features/trust/domain/models/student_verification.dart';
import 'package:unihub_mobile/features/trust/domain/models/identity_verification.dart';

class TrustCenterScreen extends ConsumerWidget {
  const TrustCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUserAsync = ref.watch(appUserProvider);
    final studentVerificationAsync = ref.watch(studentVerificationProvider);
    final identityVerificationAsync = ref.watch(identityVerificationProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Trust & Verification', 
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
      ),
      body: appUserAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('User not found'));
          
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Header & Explanation
              SliverToBoxAdapter(
                child: _buildHeader(),
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
                      const Text(
                        'Platform Verification',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'These verifications establish your identity across all of UniHub.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blueGrey.shade600,
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
                        error: (e, _) => _buildErrorCard('Student Status Error: $e'),
                      ),
                      const SizedBox(height: 12),
                      identityVerificationAsync.when(
                        data: (v) => _buildIdentityVerificationCard(context, user, v),
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, _) => _buildErrorCard('Identity Verification Error: $e'),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Educational Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildEducationSection(),
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

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, style: const TextStyle(color: Colors.red)),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1677F2).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_user_rounded, color: Color(0xFF1677F2), size: 40),
          ),
          const SizedBox(height: 16),
          const Text(
            'Single Identity, Total Trust',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Verify your identity once and unlock professional roles across the entire platform.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.blueGrey.shade600,
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
                  '${user.trustScore.toInt()}%',
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
              value: user.trustScore / 100,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityVerificationCard(BuildContext context, user, IdentityVerification? v) {
    final bool isVerified = user.isIdentityVerified;
    final bool isPending = v?.status == IdentityVerificationStatus.pending;
    final bool isRejected = v?.status == IdentityVerificationStatus.rejected;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isVerified ? const Color(0xFF10B981) : (isRejected ? Colors.red.shade200 : Colors.transparent),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
                  color: (isVerified ? const Color(0xFF10B981) : (isRejected ? Colors.red : const Color(0xFF1677F2))).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isVerified ? Icons.badge_rounded : (isRejected ? Icons.error_outline_rounded : Icons.badge_outlined),
                  color: isVerified ? const Color(0xFF10B981) : (isRejected ? Colors.red : const Color(0xFF1677F2)),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Identity Verification',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      isVerified 
                        ? 'Your identity is confirmed' 
                        : isPending 
                          ? 'Review in progress' 
                          : isRejected 
                            ? 'Verification rejected'
                            : 'Verify your ID and face to build trust',
                      style: TextStyle(
                        fontSize: 13,
                        color: isRejected ? Colors.red.shade700 : Colors.blueGrey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isVerified)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981))
              else if (isPending)
                _buildStatusBadge('Pending', Colors.orange)
              else if (isRejected)
                _buildStatusBadge('Rejected', Colors.red)
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 16),
            _buildInfoBox('Our team is verifying your government ID. This usually takes 12-24 hours.'),
          ],
          if (isRejected && v?.rejectionReason != null) ...[
            const SizedBox(height: 12),
            _buildErrorBox('Reason: ${v!.rejectionReason}'),
          ],
          if (!isVerified && !isPending) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/verify-identity'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRejected ? Colors.red : const Color(0xFF1677F2),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Verify Identity', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
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

  Widget _buildInfoBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1677F2).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1677F2).withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF1677F2)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12, 
                color: Colors.blueGrey.shade700, 
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentVerificationCard(BuildContext context, user, StudentVerification? v) {
    final bool isVerified = user.isStudentVerified;
    final bool isPending = v?.status == StudentVerificationStatus.pending;
    final bool isRejected = v?.status == StudentVerificationStatus.rejected;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isVerified ? const Color(0xFF10B981) : (isRejected ? Colors.red.shade200 : Colors.transparent),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
                  color: (isVerified ? const Color(0xFF10B981) : (isRejected ? Colors.red : const Color(0xFF1677F2))).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isVerified ? Icons.school_rounded : (isRejected ? Icons.error_outline_rounded : Icons.school_outlined),
                  color: isVerified ? const Color(0xFF10B981) : (isRejected ? Colors.red : const Color(0xFF1677F2)),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Student Status',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      isVerified 
                        ? 'Confirmed Student' 
                        : isPending 
                          ? 'Review in progress' 
                          : isRejected 
                            ? 'Verification rejected'
                            : 'Verify your campus enrollment',
                      style: TextStyle(
                        fontSize: 13,
                        color: isRejected ? Colors.red.shade700 : Colors.blueGrey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isVerified)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981))
              else if (isPending)
                _buildStatusBadge('Pending', Colors.orange)
              else if (isRejected)
                _buildStatusBadge('Rejected', Colors.red)
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 16),
            _buildInfoBox('Our team is verifying your student ID. This usually takes 12-24 hours.'),
          ],
          if (isRejected && v?.rejectionReason != null) ...[
            const SizedBox(height: 12),
            _buildErrorBox('Reason: ${v!.rejectionReason}'),
          ],
          if (!isVerified && !isPending) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/verify-student'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRejected ? Colors.red : const Color(0xFF1677F2),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Verify Student Status', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12, 
                color: Colors.red.shade800, 
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEducationSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How Trust Works',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          _buildEduItem(
            Icons.verified_user_outlined,
            'Universal Identity',
            'Your identity is verified once. This confirmation carries across all roles on UniHub, from Selling to Professional Gigs.',
          ),
          const SizedBox(height: 20),
          _buildEduItem(
            Icons.insights_rounded,
            'Dynamic Trust Score',
            'Your score grows as you complete successful transactions, receive positive ratings, and maintain professional behavior.',
          ),
          const SizedBox(height: 20),
          _buildEduItem(
            Icons.security_rounded,
            'Safe Community',
            'Verified badges help students identify legitimate providers and build a safer campus marketplace for everyone.',
          ),
        ],
      ),
    );
  }

  Widget _buildEduItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF1677F2), size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.blueGrey.shade500,
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trust Score Breakdown', 
              style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Your score reflects your reputation within the UniHub ecosystem.', 
              style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 14)),
            const SizedBox(height: 32),
            _buildBreakdownItem(Icons.school_rounded, 'Student Status', user.isStudentVerified ? 'Verified (+30%)' : 'Not Verified', user.isStudentVerified),
            const Divider(height: 32),
            _buildBreakdownItem(Icons.badge_rounded, 'Identity Check', user.isIdentityVerified ? 'Confirmed (+30%)' : 'Not Verified', user.isIdentityVerified),
            const Divider(height: 32),
            _buildBreakdownItem(Icons.star_rounded, 'Community Ratings', user.ratingsCount > 0 ? '${user.averageRating} Avg Rating' : 'No ratings yet', user.ratingsCount > 0),
            const Divider(height: 32),
            _buildBreakdownItem(Icons.history_rounded, 'Account Age', 'Member since ${user.createdAt?.year ?? 2024}', true),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownItem(IconData icon, String title, String subtitle, bool isPositive) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (isPositive ? const Color(0xFF10B981) : Colors.blueGrey).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isPositive ? const Color(0xFF10B981) : Colors.blueGrey, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text(subtitle, style: TextStyle(color: isPositive ? const Color(0xFF059669) : Colors.blueGrey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        if (isPositive)
          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
      ],
    );
  }
}
