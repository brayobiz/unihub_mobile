import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

class _ProfileContent extends StatelessWidget {
  final AppUser user;
  const _ProfileContent({required this.user});

  static const double avatarRadius = 60.0;
  static const double coverHeight = 180.0;

  @override
  Widget build(BuildContext context) {
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
                top: coverHeight - avatarRadius,
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
            padding: const EdgeInsets.fromLTRB(16, avatarRadius + 16, 16, 40),
            child: Column(
              children: [
                _buildProfileInfo(context),
                const SizedBox(height: 24),
                _buildProfileCompletion(),
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
                _buildActionButtons(context),
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: CircleAvatar(
        radius: avatarRadius,
        backgroundColor: const Color(0xFF1677F2),
        backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
        child: user.photoUrl == null
            ? Text(
                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
              )
            : null,
      ),
    );
  }

  Widget _buildEditButton(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.2),
      shape: const CircleBorder(),
      child: IconButton(
        icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 22),
        onPressed: () => GoRouter.of(context).push('/edit-profile'),
      ),
    );
  }

  Widget _buildProfileInfo(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(user.fullName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            if (user.isVerified)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.verified, color: Color(0xFF1677F2), size: 20),
              ),
          ],
        ),
        if (user.username != null)
          Text('@${user.username}', style: TextStyle(color: Colors.blueGrey.shade400, fontWeight: FontWeight.w500)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBadge(Icons.shield_outlined, 'Trust ${user.trustScore.toInt()}%', Colors.green),
            const SizedBox(width: 8),
            _buildBadge(Icons.star_rounded, '${user.averageRating.toStringAsFixed(1)} (${user.ratingsCount})', Colors.amber.shade700),
          ],
        ),
      ],
    );
  }

  Widget _buildBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Row(
      children: [
        _buildStatCard('Listings', user.activeListingsCount.toString(), Colors.blue),
        const SizedBox(width: 12),
        _buildStatCard('Seller', user.sellerRating > 0 ? user.sellerRating.toStringAsFixed(1) : 'N/A', Colors.green),
        const SizedBox(width: 12),
        _buildStatCard('Buyer', user.buyerRating > 0 ? user.buyerRating.toStringAsFixed(1) : 'N/A', Colors.purple),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blueGrey.shade300)),
          ],
        ),
      ),
    );
  }

  Widget _buildBioSection() {
    return _buildSectionCard('About Me', Text(
      user.bio ?? 'No bio shared yet.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: user.bio == null ? Colors.blueGrey.shade200 : Colors.blueGrey.shade700,
        height: 1.5,
      ),
    ));
  }

  Widget _buildAcademicSection() {
    return _buildSectionCard('Academic Information', Column(
      children: [
        _buildAcademicItem(Icons.school_rounded, 'University', user.university ?? 'Not set'),
        const Divider(height: 24, thickness: 0.5),
        _buildAcademicItem(Icons.book_rounded, 'Course', user.course ?? 'Not set'),
        const Divider(height: 24, thickness: 0.5),
        _buildAcademicItem(Icons.calendar_today_rounded, 'Year of Study', user.yearOfStudy ?? 'Not set'),
        const Divider(height: 24, thickness: 0.5),
        _buildAcademicItem(Icons.home_rounded, 'Housing Status', user.housingStatus ?? 'Not set'),
      ],
    ));
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

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        _buildActionButton(Icons.history_rounded, 'Activity History', () {}),
        const SizedBox(height: 12),
        _buildActionButton(Icons.emoji_events_outlined, 'Achievements', () {
          // Future: Navigate to dedicated Achievements screen
          _showAchievementsDialog(context);
        }),
      ],
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Center(child: content),
        ],
      ),
    );
  }

  Widget _buildAcademicItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1677F2)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade300, fontWeight: FontWeight.w600)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
        ),
      ],
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

  Widget _buildActionButton(IconData icon, String title, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: ListTile(
          leading: Icon(icon, color: Colors.blueGrey.shade800, size: 20),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }

  Widget _buildProfileCompletion() {
    final percentage = user.profileCompletion;
    if (percentage >= 1.0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Profile Strength', style: TextStyle(fontWeight: FontWeight.w700)),
              Text('${(percentage * 100).toInt()}%', style: const TextStyle(color: Color(0xFF1677F2), fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 8,
              backgroundColor: Colors.blue.shade50,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1677F2)),
            ),
          ),
        ],
      ),
    );
  }
}
