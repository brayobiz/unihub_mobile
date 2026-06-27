import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/presentation/controllers/auth_controller.dart';
import '../auth/shared/providers.dart';
import '../auth/domain/models/app_user.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching the live stream of user data from Firestore
    final appUserAsync = ref.watch(appUserProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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

class _ProfileContent extends ConsumerWidget {
  final AppUser user;
  const _ProfileContent({required this.user});

  static const double avatarRadius = 64.0;
  static const double coverHeight = 200.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // 1. Live Header Section
        SliverToBoxAdapter(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              _buildCoverPhoto(),
              Positioned(
                top: coverHeight - (avatarRadius + 8),
                child: _buildAvatar(),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                right: 16,
                child: _buildEditButton(context),
              ),
            ],
          ),
        ),

        // 2. Main Profile Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, avatarRadius + 24, 16, 40),
            child: Column(
              children: [
                _buildProfileInfo(context),
                const SizedBox(height: 24),
                _buildProfileCompletion(context),
                const SizedBox(height: 16),
                _buildStatsSection(),
                const SizedBox(height: 24),
                _buildBioSection(),
                const SizedBox(height: 16),
                _buildAcademicSection(),
                const SizedBox(height: 16),
                _buildSkillsInterests(),
                const SizedBox(height: 16),
                _buildSocialLinks(),
                const SizedBox(height: 16),
                _buildActionButtons(context, ref),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoverPhoto() {
    return Container(
      height: coverHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1677F2), Color(0xFF19D3C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        image: user.coverPhotoUrl != null
            ? DecorationImage(image: NetworkImage(user.coverPhotoUrl!), fit: BoxFit.cover)
            : null,
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: avatarRadius,
        backgroundColor: const Color(0xFFF1F5F9),
        backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
        child: user.photoUrl == null
            ? Text(
                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 44, 
                  fontWeight: FontWeight.w900, 
                  color: Color(0xFF1677F2)
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildEditButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: IconButton(
            icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
            onPressed: () => GoRouter.of(context).push('/edit-profile'),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileInfo(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              user.fullName,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E293B),
                letterSpacing: -0.5,
              ),
            ),
            if (user.isVerified)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.verified_rounded, color: Color(0xFF1677F2), size: 22),
              ),
          ],
        ),
        if (user.username != null && user.username!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            '@${user.username}',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 12),
        // University & Year Pill
        if (user.university != null || user.yearOfStudy != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (user.university != null) ...[
                  Icon(Icons.school_rounded, size: 14, color: Colors.blueGrey.shade400),
                  const SizedBox(width: 6),
                  Text(
                    user.university!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blueGrey.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (user.university != null && user.yearOfStudy != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('•', style: TextStyle(color: Colors.blueGrey.shade300, fontWeight: FontWeight.bold)),
                  ),
                if (user.yearOfStudy != null)
                  Text(
                    user.yearOfStudy!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blueGrey.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBadge(Icons.shield_rounded, 'Trust ${user.trustScore.toInt()}%', const Color(0xFF10B981)),
            const SizedBox(width: 12),
            _buildBadge(Icons.star_rounded, '${user.averageRating.toStringAsFixed(1)} (${user.ratingsCount})', const Color(0xFFF59E0B)),
          ],
        ),
      ],
    );
  }

  Widget _buildBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    final memberYear = user.createdAt?.year.toString() ?? '2024';
    
    return Column(
      children: [
        Row(
          children: [
            _buildStatCard(
              label: 'Trust Score',
              value: '${user.trustScore.toInt()}%',
              color: const Color(0xFF10B981),
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              label: 'Reputation',
              value: user.averageRating.toStringAsFixed(1),
              color: const Color(0xFF3B82F6),
              zeroLabel: 'No ratings yet',
              isZero: user.averageRating == 0,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              label: 'Achievements',
              value: user.achievements.length.toString(),
              color: const Color(0xFFF59E0B),
              zeroLabel: 'Earn badges',
              isZero: user.achievements.isEmpty,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatCard(
              label: 'Member Since',
              value: memberYear,
              color: const Color(0xFF6366F1),
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              label: 'Status',
              value: user.isVerified ? 'Verified' : 'Student',
              color: user.isVerified ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              label: 'Membership',
              value: user.tier.toUpperCase(),
              color: const Color(0xFF8B5CF6),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required Color color,
    String? zeroLabel,
    bool isZero = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
                letterSpacing: 0.2,
              ),
            ),
            if (isZero && zeroLabel != null) ...[
              const SizedBox(height: 2),
              Text(
                zeroLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBioSection() {
    return _buildSectionCard(
      'About Me',
      _ExpandableBio(bio: user.bio),
    );
  }

  Widget _buildAcademicSection() {
    return _buildSectionCard(
      'Academic Information',
      Column(
        children: [
          _buildAcademicItem(Icons.school_rounded, 'University', user.university ?? 'Not set'),
          _buildAcademicItem(Icons.book_rounded, 'Course', user.course ?? 'Not set'),
          _buildAcademicItem(Icons.calendar_today_rounded, 'Year of Study', user.yearOfStudy ?? 'Not set'),
          _buildAcademicItem(Icons.home_rounded, 'Housing Status', user.housingStatus ?? 'Not set'),
        ],
      ),
    );
  }

  Widget _buildSocialLinks() {
    if (user.socialLinks.isEmpty) return const SizedBox.shrink();
    return _buildSectionCard('Connect', Row(
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
    ));
  }

  Widget _buildAchievementsSection() {
    if (user.achievements.isEmpty) return const SizedBox.shrink();
    return _buildSectionCard('Achievements', Wrap(
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
    ));
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _buildActionButton(Icons.favorite_outline_rounded, 'Saved Items', () => context.push('/saved')),
        const SizedBox(height: 12),
        _buildActionButton(Icons.history_rounded, 'Activity History', () {}),
        const SizedBox(height: 12),
        _buildActionButton(Icons.emoji_events_outlined, 'Achievements', () {
          _showAchievementsDialog(context);
        }),
        const SizedBox(height: 12),
        _buildActionButton(Icons.logout_rounded, 'Log Out', () {
          _showLogoutConfirm(context, ref);
        }, isDestructive: true),
      ],
    );
  }

  void _showLogoutConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out?'),
        content: const Text('Are you sure you want to log out of UniHub?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authControllerProvider.notifier).signOut();
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAchievementsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Achievements',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (user.achievements.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('Start trading and engaging to earn badges!', 
                    style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 12,
                children: user.achievements.map((a) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events_rounded, size: 18, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(a, style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        color: Colors.amber.shade900
                      )),
                    ],
                  ),
                )).toList(),
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, Widget content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          content,
        ],
      ),
    );
  }

  Widget _buildAcademicItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF1677F2)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
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
    if (user.skills.isEmpty && user.interests.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        if (user.skills.isNotEmpty) _buildSectionCard('Skills', Wrap(
          spacing: 8, runSpacing: 8,
          children: user.skills.map((s) => _buildChip(s, Colors.blue)).toList(),
        )),
        const SizedBox(height: 16),
        if (user.interests.isNotEmpty) _buildSectionCard('Interests', Wrap(
          spacing: 8, runSpacing: 8,
          children: user.interests.map((i) => _buildChip(i, Colors.green)).toList(),
        )),
      ],
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildActionButton(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: ListTile(
          leading: Icon(icon, color: isDestructive ? Colors.red : Colors.blueGrey.shade800, size: 20),
          title: Text(title, style: TextStyle(
            fontWeight: FontWeight.w700, 
            fontSize: 15,
            color: isDestructive ? Colors.red : Colors.black87,
          )),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }

  Widget _buildProfileCompletion(BuildContext context) {
    final percentage = user.profileCompletion;
    if (percentage >= 1.0) return const SizedBox.shrink();

    final List<_CompletionItem> items = [
      _CompletionItem(
        label: 'Profile photo',
        isCompleted: user.photoUrl != null,
        onTap: () => context.push('/edit-profile'),
      ),
      _CompletionItem(
        label: 'Username',
        isCompleted: user.username != null && user.username!.isNotEmpty,
        onTap: () => context.push('/edit-profile'),
      ),
      _CompletionItem(
        label: 'Bio',
        isCompleted: user.bio != null && user.bio!.isNotEmpty,
        onTap: () => context.push('/edit-profile'),
      ),
      _CompletionItem(
        label: 'University',
        isCompleted: user.university != null,
        onTap: () => context.push('/edit-profile'),
      ),
      _CompletionItem(
        label: 'Course',
        isCompleted: user.course != null,
        onTap: () => context.push('/edit-profile'),
      ),
      _CompletionItem(
        label: 'Housing Status',
        isCompleted: user.housingStatus != null,
        onTap: () => context.push('/edit-profile'),
      ),
      _CompletionItem(
        label: 'Student Verification',
        isCompleted: user.isVerified,
        onTap: () => context.push('/settings'), // Verification usually in settings or special flow
      ),
      _CompletionItem(
        label: 'Phone Number',
        isCompleted: user.phoneNumber != null,
        onTap: () => context.push('/edit-profile'),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1677F2).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(percentage * 100).toInt()}%',
                  style: const TextStyle(
                    color: Color(0xFF1677F2),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
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
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1677F2)),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Complete your profile',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 16),
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
              ? const Color(0xFF10B981).withValues(alpha: 0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.isCompleted 
                ? const Color(0xFF10B981).withValues(alpha: 0.1)
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
