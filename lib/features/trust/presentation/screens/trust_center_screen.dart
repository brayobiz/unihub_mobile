import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/trust/domain/models/professional_role.dart';
import 'package:unihub_mobile/features/trust/presentation/providers/trust_providers.dart';
import 'package:unihub_mobile/features/trust/domain/models/verification_application.dart';
import 'package:unihub_mobile/features/trust/domain/models/student_verification.dart';

class TrustCenterScreen extends ConsumerWidget {
  const TrustCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUserAsync = ref.watch(appUserProvider);
    final studentVerificationAsync = ref.watch(studentVerificationProvider);
    final applicationsAsync = ref.watch(userApplicationsProvider);

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
                  child: _buildTrustOverview(user),
                ),
              ),

              // 3. Student Verification Status
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: studentVerificationAsync.when(
                    data: (v) => _buildStudentVerificationCard(context, user, v),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                  ),
                ),
              ),

              // 4. Professional Roles
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Verified Roles',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Unlock specialized features by verifying your role in the community.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blueGrey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              applicationsAsync.when(
                data: (apps) {
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final role = ProfessionalRole.values[index];
                          final app = apps.firstWhere(
                            (a) => a.role == role,
                            orElse: () => _emptyApplication(user.uid, role),
                          );
                          final isActuallyVerified = user.verifiedRoles.contains(role.name);
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildRoleCard(context, role, app, isActuallyVerified),
                          );
                        },
                        childCount: ProfessionalRole.values.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
                error: (e, _) => SliverToBoxAdapter(child: Text('Error: $e')),
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

  VerificationApplication _emptyApplication(String userId, ProfessionalRole role) {
    return VerificationApplication(
      id: '',
      userId: userId,
      role: role,
      status: VerificationStatus.expired, // Using expired as "none"
      createdAt: DateTime.now(),
      fullName: '',
      phoneNumber: '',
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
            'Build Your Reputation',
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
            'Verification builds trust across UniHub and helps keep the campus community safe for everyone.',
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
      margin: const EdgeInsets.only(top: 24),
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
                    'Your Trust Score',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Based on your activity',
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

  Widget _buildStudentVerificationCard(BuildContext context, user, StudentVerification? v) {
    final bool isVerified = user.isStudentVerified;
    final bool isPending = v?.status == StudentVerificationStatus.pending;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isVerified ? const Color(0xFF10B981) : Colors.transparent,
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
                  color: (isVerified ? const Color(0xFF10B981) : const Color(0xFF1677F2)).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isVerified ? Icons.school_rounded : Icons.school_outlined,
                  color: isVerified ? const Color(0xFF10B981) : const Color(0xFF1677F2),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Student Verification',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      isVerified 
                        ? 'Your student status is verified' 
                        : isPending 
                          ? 'Verification in review' 
                          : 'Verify your university enrollment',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blueGrey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isVerified)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981))
              else if (isPending)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
            ],
          ),
          if (!isVerified && !isPending) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/verify-student'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1677F2),
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

  Widget _buildRoleCard(BuildContext context, ProfessionalRole role, VerificationApplication app, bool isActuallyVerified) {
    final bool isPending = app.status == VerificationStatus.pending;
    final bool isRejected = app.status == VerificationStatus.rejected;
    
    Color statusColor = Colors.blueGrey;
    String statusText = 'Not Verified';
    IconData statusIcon = Icons.add_circle_outline_rounded;

    if (isActuallyVerified) {
      statusColor = const Color(0xFF10B981);
      statusText = 'Verified';
      statusIcon = Icons.verified_rounded;
    } else if (isPending) {
      statusColor = Colors.orange;
      statusText = 'Pending Review';
      statusIcon = Icons.access_time_rounded;
    } else if (isRejected) {
      statusColor = Colors.red;
      statusText = 'Action Required';
      statusIcon = Icons.error_outline_rounded;
    }

    return InkWell(
      onTap: isActuallyVerified ? null : () => context.push('/verify-professional/${role.name}'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(_getRoleIcon(role), color: statusColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!isActuallyVerified)
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  IconData _getRoleIcon(ProfessionalRole role) {
    switch (role) {
      case ProfessionalRole.seller: return Icons.shopping_bag_rounded;
      case ProfessionalRole.housePlug: return Icons.home_work_rounded;
      case ProfessionalRole.tutor: return Icons.menu_book_rounded;
      case ProfessionalRole.serviceProvider: return Icons.handyman_rounded;
      case ProfessionalRole.technician: return Icons.memory_rounded;
      case ProfessionalRole.business: return Icons.business_center_rounded;
    }
  }
}
