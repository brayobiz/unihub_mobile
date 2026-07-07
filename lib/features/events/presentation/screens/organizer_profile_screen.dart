import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/core/constants/campus_constants.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/events/presentation/controllers/organizer_profile_controller.dart';
import '../../shared/providers.dart';
import '../../domain/models/organizer.dart';
import '../../domain/models/organizer_member.dart';
import '../../domain/models/event.dart';

class OrganizerProfileScreen extends ConsumerStatefulWidget {
  final String organizerId;

  const OrganizerProfileScreen({super.key, required this.organizerId});

  @override
  ConsumerState<OrganizerProfileScreen> createState() => _OrganizerProfileScreenState();
}

class _OrganizerProfileScreenState extends ConsumerState<OrganizerProfileScreen> {
  static const double logoRadius = 55.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final organizerAsync = ref.watch(organizerProvider(widget.organizerId));
    final membersAsync = ref.watch(organizerMembersProvider(widget.organizerId));
    final isFollowingAsync = ref.watch(isFollowingOrganizerProvider(widget.organizerId));

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: organizerAsync.when(
        data: (organizer) {
          if (organizer == null) {
            return const Center(child: Text('Organizer not found.'));
          }
          return Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // 1. Header Section
                  SliverToBoxAdapter(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _buildBanner(organizer),
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 10,
                          left: 16,
                          right: 16,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                                onPressed: () => context.pop(),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.share_outlined, color: Colors.white),
                                    onPressed: () => ref.read(organizerProfileControllerProvider(organizer.id).notifier).shareOrganizer(context, organizer),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                                    onPressed: () => _showMoreMenu(context, organizer),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 130,
                          left: 16,
                          right: 16,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildLogo(organizer),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: _buildIdentityInfo(context, organizer),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Main Content
          SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 80, 16, 120),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildStatsSection(organizer),
                        const SizedBox(height: 24),
                        _buildAboutSection(organizer),
                        const SizedBox(height: 24),
                        _buildTrustSection(organizer),
                        const SizedBox(height: 24),
                        _buildMembersSection(membersAsync),
                        const SizedBox(height: 24),
                        _buildOrganizerEvents(organizer.id),
                      ]),
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildStickyActionBar(context, organizer, isFollowingAsync.value ?? false),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildBanner(Organizer organizer) {
    final theme = Theme.of(context);
    return ClipPath(
      clipper: _HeaderClipper(),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.brightness == Brightness.dark ? const Color(0xFF0F172A) : const Color(0xFF1e293b),
              theme.colorScheme.primary,
              const Color(0xFF19D3C5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: organizer.bannerUrl != null
            ? CachedNetworkImage(
                imageUrl: organizer.bannerUrl!,
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.2),
                colorBlendMode: BlendMode.darken,
              )
            : null,
      ),
    );
  }

  Widget _buildLogo(Organizer organizer) {
    final theme = Theme.of(context);
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
      child: CircleAvatar(
        radius: logoRadius,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        backgroundImage: organizer.logoUrl != null ? CachedNetworkImageProvider(organizer.logoUrl!) : null,
        child: organizer.logoUrl == null
            ? Text(
                organizer.name.isNotEmpty ? organizer.name[0].toUpperCase() : 'O',
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: theme.colorScheme.primary),
              )
            : null,
      ),
    );
  }

  Widget _buildIdentityInfo(BuildContext context, Organizer organizer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                organizer.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.8,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (organizer.verificationStatus == OrganizerVerificationStatus.verified || 
                organizer.verificationStatus == OrganizerVerificationStatus.official)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.verified_rounded, color: Colors.white, size: 20),
              ),
          ],
        ),
        Text(
          organizer.type.name.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.school_rounded, size: 12, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                CampusConstants.getDisplayName(organizer.campusId),
                style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection(Organizer organizer) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(Icons.people_outline_rounded, organizer.followerCount.toString(), 'Followers'),
          _buildVerticalDivider(),
          _buildStatItem(Icons.event_note_rounded, organizer.eventCount.toString(), 'Events'),
          _buildVerticalDivider(),
          _buildStatItem(Icons.shield_outlined, '${organizer.trustScore.toInt()}%', 'Trust'),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: 22, color: theme.colorScheme.primary),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 30, width: 1, color: Theme.of(context).colorScheme.outlineVariant);
  }

  Widget _buildAboutSection(Organizer organizer) {
    return _buildSectionCard(
      'About',
      Text(
        organizer.bio,
        style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface, height: 1.6),
      ),
      icon: Icons.info_outline_rounded,
    );
  }

  Widget _buildTrustSection(Organizer organizer) {
    return _buildSectionCard(
      'Verification Status',
      Column(
        children: [
          _buildVerificationRow(
            Icons.verified_user_outlined, 
            'Organizer Verification', 
            organizer.verificationStatus.name.toUpperCase(), 
            organizer.verificationStatus == OrganizerVerificationStatus.verified || 
            organizer.verificationStatus == OrganizerVerificationStatus.official
          ),
          if (organizer.contactEmail != null || organizer.contactPhone != null) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            if (organizer.contactEmail != null)
              _buildContactRow(Icons.email_outlined, organizer.contactEmail!),
            if (organizer.contactPhone != null) ...[
              const SizedBox(height: 12),
              _buildContactRow(Icons.phone_outlined, organizer.contactPhone!),
            ],
          ],
          if (organizer.socialLinks.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: organizer.socialLinks.entries.map((e) => _buildSocialIcon(e.key, e.value)).toList(),
            ),
          ],
        ],
      ),
      icon: Icons.shield_outlined,
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildSocialIcon(String platform, String url) {
    // Simplified social icon builder
    IconData iconData = Icons.link;
    if (platform.toLowerCase().contains('instagram')) iconData = Icons.camera_alt_outlined;
    if (platform.toLowerCase().contains('twitter') || platform.toLowerCase().contains('x')) iconData = Icons.close;
    
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, size: 20, color: Theme.of(context).colorScheme.primary),
    );
  }

  Widget _buildVerificationRow(IconData icon, String title, String status, bool isVerified) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: isVerified ? AppColors.success : theme.colorScheme.onSurfaceVariant, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: theme.colorScheme.onSurface)),
              Text(status, style: TextStyle(color: isVerified ? AppColors.success : theme.colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        if (isVerified) const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
      ],
    );
  }

  Widget _buildMembersSection(AsyncValue<List<OrganizerMember>> membersAsync) {
    return _buildSectionCard(
      'Team Members',
      membersAsync.when(
        data: (members) => SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundImage: member.userPhotoUrl != null ? CachedNetworkImageProvider(member.userPhotoUrl!) : null,
                      child: member.userPhotoUrl == null ? Text(member.userName.isNotEmpty ? member.userName[0].toUpperCase() : '?') : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      member.userName.isNotEmpty ? member.userName.split(' ').first : 'User',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        loading: () => const CircularProgressIndicator(),
        error: (_, __) => const Text('Failed to load members'),
      ),
      icon: Icons.groups_outlined,
    );
  }

  Widget _buildOrganizerEvents(String organizerId) {
    return Consumer(
      builder: (context, ref, _) {
        final eventsAsync = ref.watch(organizerEventsProvider(organizerId));
        return _buildSectionCard(
          'Upcoming Events',
          eventsAsync.when(
            data: (events) {
              final activeEvents = events.where((e) => e.status == EventStatus.approved || e.status == EventStatus.scheduled || e.status == EventStatus.live).toList();
              if (activeEvents.isEmpty) {
                return const Center(
                  child: Column(
                    children: [
                      Icon(Icons.event_available_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No events scheduled yet.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }
              return SizedBox(
                height: 150,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: activeEvents.length,
                  itemBuilder: (context, index) {
                    final event = activeEvents[index];
                    return Container(
                      width: 200,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        onTap: () => context.push('/events/${event.id}'),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const Spacer(),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(DateFormat('MMM dd').format(event.startAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text('Failed to load events'),
          ),
          icon: Icons.calendar_today_outlined,
        );
      },
    );
  }

  Widget _buildSectionCard(String title, Widget content, {IconData? icon}) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
              ],
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 20),
          content,
        ],
      ),
    );
  }

  Widget _buildStickyActionBar(BuildContext context, Organizer organizer, bool isFollowing) {
    final theme = Theme.of(context);
    final user = ref.watch(appUserProvider).valueOrNull;
    final isOwner = user?.uid == organizer.ownerId;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: Row(
        children: [
          if (isOwner)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => context.push('/organizers/${organizer.id}/dashboard'),
                icon: const Icon(Icons.dashboard_outlined),
                label: const Text('Organizer Dashboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            )
          else ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => ref.read(organizerProfileControllerProvider(organizer.id).notifier).toggleFollow(),
                icon: Icon(isFollowing ? Icons.notifications_active_rounded : Icons.notifications_none_rounded),
                label: Text(isFollowing ? 'Following' : 'Follow'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => ref.read(organizerProfileControllerProvider(organizer.id).notifier).contactOrganizer(organizer),
                icon: const Icon(Icons.mail_outline_rounded),
                label: const Text('Contact'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 60);
    path.quadraticBezierTo(size.width / 2, size.height, size.width, size.height - 60);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

extension _OrganizerProfileScreenActions on _OrganizerProfileScreenState {
  void _showMoreMenu(BuildContext context, Organizer organizer) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy Organizer ID'),
              onTap: () {
                // To be implemented: Clipboard.setData
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_problem_outlined, color: Colors.red),
              title: const Text('Report Organizer', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report submitted. Thank you for keeping campus safe.')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
