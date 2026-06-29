import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:unihub_mobile/widgets/app_drawer.dart';
import 'package:unihub_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/auth/domain/models/app_user.dart';
import 'package:unihub_mobile/features/trust/domain/models/professional_role.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching the live stream of user data from Firestore
    final appUserAsync = ref.watch(appUserProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppDrawer(),
      body: appUserAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User profile not found. Please log in again.'));
          }
          return _ProfileContent(user: user);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Live Sync Error: $err')),
      ),
    );
  }
}

class _ProfileContent extends ConsumerStatefulWidget {
  final AppUser user;
  const _ProfileContent({required this.user});

  @override
  ConsumerState<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends ConsumerState<_ProfileContent> {
  static const double avatarRadius = 55.0;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // 1. Identity Header Section
        SliverToBoxAdapter(
          child: RepaintBoundary(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Curved Header
                ClipPath(
                  clipper: _HeaderClipper(),
                  child: Container(
                    height: 220,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF0F172A),
                          Color(0xFF1677F2),
                          Color(0xFF19D3C5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                
                // Actions on Header
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu_rounded, color: Colors.white),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                      _buildEditButton(context),
                    ],
                  ),
                ),
  
                // Identity Card (overlaps the header)
                Positioned(
                  top: 130,
                  left: 16,
                  right: 16,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildAvatar(),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _buildIdentityInfo(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // 2. Main Content
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 60, 16, 40),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildStatsSection(),
              const SizedBox(height: 24),
              _buildTrustSummary(),
              const SizedBox(height: 24),
              _buildProfileCompletion(context),
              const SizedBox(height: 24),
              _buildAboutSection(),
              const SizedBox(height: 24),
              _buildAcademicSection(),
              if (user.skills.isNotEmpty || user.interests.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSkillsInterests(),
              ],
              if (user.socialLinks.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSocialLinks(),
              ],
              const SizedBox(height: 24),
              const Text(
                'Account Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 16),
              _buildActionButtons(context, ref),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    final user = widget.user;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: avatarRadius,
            backgroundColor: const Color(0xFFF1F5F9),
            backgroundImage: user.photoUrl != null ? CachedNetworkImageProvider(user.photoUrl!) : null,
            child: user.photoUrl == null
                ? Text(
                    user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1677F2)
                    ),
                  )
                : null,
          ),
          if (user.isVerified)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.verified, color: Color(0xFF10B981), size: 24),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: IconButton(
        icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
        onPressed: () => GoRouter.of(context).push('/edit-profile'),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildIdentityInfo(BuildContext context) {
    final user = widget.user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                user.fullName,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.8,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (user.isVerified)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.verified_rounded, color: Colors.white, size: 22),
              ),
          ],
        ),
        Text(
          '@${user.username ?? 'unihub_user'}',
          style: TextStyle(
            fontSize: 15,
            color: Colors.white.withOpacity(0.8),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        // University & Year Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildSmallInfoPill(Icons.school_rounded, user.university ?? 'Uni'),
              const SizedBox(width: 8),
              _buildSmallInfoPill(Icons.calendar_today_rounded, user.yearOfStudy ?? 'Year'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Trust & Rating Row
        Row(
          children: [
            _buildTrustBadge(user.displayTrustScore.toInt()),
            const SizedBox(width: 10),
            _buildRatingBadge(user.averageRating, user.ratingsCount),
          ],
        ),
      ],
    );
  }

  Widget _buildSmallInfoPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustBadge(int score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.08),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield_rounded, size: 14, color: Color(0xFF10B981)),
          const SizedBox(width: 6),
          Text(
            'Trust Score $score%',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF059669),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBadge(double rating, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withOpacity(0.08),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
          const SizedBox(width: 6),
          Text(
            '${rating.toStringAsFixed(1)} ($count)',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFFD97706),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    final user = widget.user;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem(Icons.shield_outlined, '${user.displayTrustScore.toInt()}%', 'Trust Score'),
            _buildVerticalDivider(),
            _buildStatItem(Icons.star_outline_rounded, user.averageRating.toStringAsFixed(1), 'Reputation'),
            _buildVerticalDivider(),
            _buildStatItem(Icons.menu_book_outlined, user.resourcesSharedCount.toString(), 'Notes Shared'),
            _buildVerticalDivider(),
            _buildStatItem(Icons.handshake_outlined, user.completedSalesCount.toString(), 'Deals Closed'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 22, color: const Color(0xFF6366F1)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return VerticalDivider(
      color: Colors.grey.withOpacity(0.1),
      thickness: 1,
      indent: 8,
      endIndent: 8,
    );
  }

  Widget _buildAboutSection() {
    return _buildSectionCard(
      'About ${widget.user.fullName.split(' ').first}',
      _ExpandableBio(bio: widget.user.bio),
      icon: Icons.person_outline_rounded,
    );
  }

  Widget _buildSectionCard(String title, Widget content, {IconData? icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: const Color(0xFF6366F1)),
                const SizedBox(width: 12),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          content,
        ],
      ),
    );
  }

  Widget _buildAcademicSection() {
    return _buildSectionCard(
      'Academic Information',
      Column(
        children: [
          _buildAcademicItem(Icons.school_rounded, 'University', widget.user.university ?? 'Not set'),
          _buildAcademicItem(Icons.book_rounded, 'Course', widget.user.course ?? 'Not set'),
          _buildAcademicItem(Icons.calendar_today_rounded, 'Year of Study', widget.user.yearOfStudy ?? 'Not set'),
        ],
      ),
      icon: Icons.auto_stories_rounded,
    );
  }

  Widget _buildAcademicItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF6366F1)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsInterests() {
    if (widget.user.skills.isEmpty && widget.user.interests.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        if (widget.user.skills.isNotEmpty) 
          _buildSectionCard(
            'Skills', 
            Wrap(
              spacing: 8, runSpacing: 8,
              children: widget.user.skills.map((s) => _buildChip(s, const Color(0xFF1677F2))).toList(),
            ),
            icon: Icons.psychology_rounded,
          ),
        const SizedBox(height: 24),
        if (widget.user.interests.isNotEmpty) 
          _buildSectionCard(
            'Interests', 
            Wrap(
              spacing: 8, runSpacing: 8,
              children: widget.user.interests.map((i) => _buildChip(i, const Color(0xFF10B981))).toList(),
            ),
            icon: Icons.interests_rounded,
          ),
      ],
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildAchievementsSection() {
    final user = widget.user;
    if (user.achievements.isEmpty) return const SizedBox.shrink();
    return _buildSectionCard(
      'Achievements', 
      Wrap(
        spacing: 8, runSpacing: 8,
        children: user.achievements.map((a) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events_rounded, size: 14, color: Colors.amber),
              const SizedBox(width: 4),
              Text(a, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
            ],
          ),
        )).toList(),
      ),
      icon: Icons.workspace_premium_rounded,
    );
  }

  Widget _buildSocialLinks() {
    final user = widget.user;
    if (user.socialLinks.isEmpty) return const SizedBox.shrink();
    return _buildSectionCard(
      'Connect', 
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: user.socialLinks.entries.map((entry) {
          IconData icon = Icons.link_rounded;
          if (entry.key.contains('instagram')) icon = Icons.camera_alt_rounded;
          if (entry.key.contains('linkedin')) icon = Icons.work_rounded;
          if (entry.key.contains('twitter')) icon = Icons.alternate_email_rounded;
          
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(icon, size: 24, color: Colors.blueGrey.shade700),
          );
        }).toList(),
      ),
      icon: Icons.connect_without_contact_rounded,
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _buildActionButton(Icons.verified_user_outlined, 'Trust & Verification', () => context.push('/trust-center')),
        const SizedBox(height: 8),
        _buildActionButton(Icons.favorite_outline_rounded, 'Saved Items', () => context.push('/saved')),
        const SizedBox(height: 8),
        _buildActionButton(Icons.emoji_events_outlined, 'Achievements (Coming Soon)', () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Achievements are coming soon! Stay tuned.')),
          );
        }),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isDestructive ? Colors.red : const Color(0xFF6366F1)).withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: isDestructive ? Colors.red : const Color(0xFF6366F1), size: 20),
        ),
        title: Text(title, style: TextStyle(
          fontWeight: FontWeight.w700, 
          fontSize: 15,
          color: isDestructive ? Colors.red : const Color(0xFF1E293B),
        )),
        trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildTrustSummary() {
    final user = widget.user;
    return _buildSectionCard(
      'Trust & Verification',
      Column(
        children: [
          _buildVerificationRow(
            Icons.school_rounded,
            'Student Status',
            user.isStudentVerified ? 'Verified Student' : 'Not Verified',
            user.isStudentVerified,
          ),
          const SizedBox(height: 16),
          _buildVerificationRow(
            Icons.badge_rounded,
            'Identity Status',
            user.isIdentityVerified ? 'Identity Confirmed' : 'Not Verified',
            user.isIdentityVerified,
          ),
          if (user.verifiedRoles.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),
            const Row(
              children: [
                Icon(Icons.workspace_premium_rounded, size: 16, color: Color(0xFF6366F1)),
                SizedBox(width: 8),
                Text(
                  'Verified Professional Roles',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: user.verifiedRoles.map((roleName) {
                final role = ProfessionalRole.values.firstWhere(
                  (e) => e.name == roleName,
                  orElse: () => ProfessionalRole.seller,
                );
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1677F2).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1677F2).withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF1677F2)),
                      const SizedBox(width: 6),
                      Text(
                        role.label,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1677F2)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
      icon: Icons.verified_user_outlined,
    );
  }

  Widget _buildVerificationRow(IconData icon, String title, String status, bool isVerified) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isVerified ? const Color(0xFF10B981) : Colors.grey).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isVerified ? const Color(0xFF10B981) : Colors.grey, size: 18),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              Text(status, style: TextStyle(color: isVerified ? const Color(0xFF059669) : Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        if (isVerified)
          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
      ],
    );
  }

  Widget _buildProfileCompletion(BuildContext context) {
    final percentage = widget.user.profileCompletion;
    if (percentage >= 1.0) return const SizedBox.shrink();

    final List<_CompletionItem> items = [
      _CompletionItem(
        label: 'Profile photo',
        isCompleted: widget.user.photoUrl != null,
        onTap: () => context.push('/edit-profile'),
      ),
      _CompletionItem(
        label: 'Username',
        isCompleted: widget.user.username != null && widget.user.username!.isNotEmpty,
        onTap: () => context.push('/edit-profile'),
      ),
      _CompletionItem(
        label: 'Bio',
        isCompleted: widget.user.bio != null && widget.user.bio!.isNotEmpty,
        onTap: () => context.push('/edit-profile'),
      ),
      _CompletionItem(
        label: 'University',
        isCompleted: widget.user.university != null,
        onTap: () => context.push('/edit-profile'),
      ),
      _CompletionItem(
        label: 'Student Verification',
        isCompleted: widget.user.isStudentVerified,
        onTap: () => context.push('/trust-center'),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Profile Strength',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${(percentage * 100).toInt()}%',
                  style: const TextStyle(
                    color: Color(0xFF6366F1),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 10,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: items.map((item) => _buildCompletionChip(item)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionChip(_CompletionItem item) {
    return InkWell(
      onTap: item.isCompleted ? null : item.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: item.isCompleted 
              ? const Color(0xFF10B981).withOpacity(0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.isCompleted 
                ? const Color(0xFF10B981).withOpacity(0.1)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.isCompleted ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
              size: 16,
              color: item.isCompleted ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 8),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: item.isCompleted ? FontWeight.w600 : FontWeight.w500,
                color: item.isCompleted ? const Color(0xFF065F46) : const Color(0xFF64748B),
                decoration: item.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 60);
    path.quadraticBezierTo(
      size.width / 2, 
      size.height, 
      size.width, 
      size.height - 60
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _ExpandableBio extends StatefulWidget {
  final String? bio;
  const _ExpandableBio({this.bio});

  @override
  State<_ExpandableBio> createState() => _ExpandableBioState();
}

class _ExpandableBioState extends State<_ExpandableBio> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.bio == null || widget.bio!.trim().isEmpty) {
      return const Text(
        'Tell other students a little about yourself.',
        style: TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 15,
          fontStyle: FontStyle.italic,
          height: 1.6,
        ),
      );
    }

    final bioText = widget.bio!;
    const int maxChars = 160;
    final bool canExpand = bioText.length > maxChars;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Text(
            canExpand && !isExpanded 
                ? '${bioText.substring(0, maxChars)}...' 
                : bioText,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF475569),
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (canExpand) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => isExpanded = !isExpanded),
            child: Text(
              isExpanded ? 'Show Less' : 'Read More',
              style: const TextStyle(
                color: Color(0xFF1677F2),
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CompletionItem {
  final String label;
  final bool isCompleted;
  final VoidCallback onTap;

  _CompletionItem({
    required this.label,
    required this.isCompleted,
    required this.onTap,
  });
}
