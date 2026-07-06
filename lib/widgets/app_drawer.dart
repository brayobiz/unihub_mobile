import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import '../features/auth/shared/providers.dart';
import '../features/housing/shared/providers.dart';
import '../features/trust/domain/models/professional_role.dart';
import '../features/trust/domain/models/verification_application.dart';
import '../features/trust/presentation/providers/trust_providers.dart';
import '../features/events/shared/providers.dart';
import '../features/events/domain/models/organizer.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final appUserAsync = ref.watch(appUserProvider);

    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      child: Column(
        children: [
          // Simplified Header / Branding
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.hub_rounded, color: Colors.white, size: 40),
                const SizedBox(height: 12),
                Text(
                  'UniHub Services',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Your campus ecosystem',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _sectionHeader(context, 'Campus Life'),
                _drawerItem(context, Icons.groups_outlined, 'Community', onTap: () {
                  context.push('/community');
                }),
                _drawerItem(context, Icons.work_outline, 'Student Gigs', onTap: () {
                  context.push('/gigs');
                }),
                _drawerItem(context, Icons.favorite_border_rounded, 'Confessions', onTap: () {
                  context.push('/confessions');
                }),
                _drawerItem(context, Icons.calendar_today_outlined, 'My Events', onTap: () {
                  context.push('/my-events');
                }),

                const Divider(),
                _sectionHeader(context, 'Campus Tools'),
                _drawerItem(
                  context, 
                  Icons.map_outlined, 
                  'Campus Map', 
                  onTap: () => context.push('/campus-map'),
                ),
                _drawerItem(
                  context, 
                  Icons.event_note_outlined, 
                  'Events & Clubs', 
                  onTap: () => context.push('/events'),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final managedAsync = ref.watch(userManagedOrganizersProvider);
                    return managedAsync.when(
                      data: (orgs) {
                        final approvedOrgs = orgs.where((o) => 
                          o.verificationStatus == OrganizerVerificationStatus.verified || 
                          o.verificationStatus == OrganizerVerificationStatus.official
                        ).toList();

                        final activeApp = orgs.firstWhere(
                          (o) => o.verificationStatus == OrganizerVerificationStatus.draft || 
                                 o.verificationStatus == OrganizerVerificationStatus.submitted ||
                                 o.verificationStatus == OrganizerVerificationStatus.underReview ||
                                 o.verificationStatus == OrganizerVerificationStatus.rejected,
                          orElse: () => orgs.isNotEmpty ? orgs.first : Organizer(id: '', ownerId: '', name: '', bio: '', campusId: '', createdAt: DateTime.now()),
                        );

                        final hasActiveApp = activeApp.id.isNotEmpty && !approvedOrgs.any((o) => o.id == activeApp.id);

                        if (approvedOrgs.isNotEmpty) {
                          return _drawerItem(
                            context, 
                            Icons.dashboard_customize_outlined, 
                            'My Organizer Profiles', 
                            onTap: () {
                              if (approvedOrgs.length == 1) {
                                context.push('/organizers/${approvedOrgs.first.id}/dashboard');
                              } else {
                                context.push('/events');
                              }
                            },
                          );
                        }

                        if (hasActiveApp) {
                          final isRejected = activeApp.verificationStatus == OrganizerVerificationStatus.rejected;
                          return _drawerItem(
                            context, 
                            isRejected ? Icons.edit_note_rounded : Icons.hourglass_empty_rounded, 
                            isRejected ? 'Application Needs Attention' : 'Application Processing', 
                            onTap: () {
                              if (isRejected) {
                                context.pushNamed('become-organizer', extra: activeApp);
                              } else {
                                context.push('/organizers/${activeApp.id}/dashboard');
                              }
                            },
                          );
                        }

                        return _drawerItem(
                          context, 
                          Icons.add_business_outlined, 
                          'Become an Organizer', 
                          onTap: () => context.pushNamed('organizer-onboarding'),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    );
                  },
                ),

                const Divider(),
                _sectionHeader(context, 'Platform'),
                _drawerItem(context, Icons.info_outline, 'About UniHub', onTap: () {
                   _showAboutDialog(context);
                }),

                appUserAsync.when(
                  data: (user) {
                    return Column(
                      children: [
                        if (user?.isAdmin ?? false) ...[
                          const Divider(),
                          _sectionHeader(context, 'Administrative'),
                          _drawerItem(
                            context, 
                            Icons.admin_panel_settings_outlined, 
                            'Admin Dashboard', 
                            onTap: () => context.push('/admin/dashboard'),
                          ),
                        ],
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              'v1.0.0-rc.2',
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 32),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Center(child: Icon(Icons.hub_rounded, color: AppColors.primary, size: 64)),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'About UniHub',
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Center(
                child: Text(
                  'Your Campus. Connected.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'UniHub is a student-first platform designed to make university life simpler, safer, and more connected.',
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Instead of relying on scattered WhatsApp groups, notice boards, or social media posts, UniHub brings essential campus services together in one place.',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5, color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Text(
                'Whether you\'re looking for a place to stay, selling items, sharing notes, finding gigs, or connecting with other students, UniHub helps you do it within your university community.',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5, color: theme.colorScheme.onSurfaceVariant),
              ),
              
              const SizedBox(height: 40),
              _buildFeatureSection(
                context, 
                Icons.shopping_bag_outlined, 
                'Marketplace', 
                'Buy and sell with fellow students.',
                'Marketplace allows students to list items they no longer need and discover affordable products from others on campus. \n\n'
                '• Beds and mattresses\n'
                '• Laptops and accessories\n'
                '• Phones & Electronics\n'
                '• Furniture & Appliances\n'
                '• Books & Clothing\n\n'
                'A graduating student can easily sell furniture to incoming students, giving useful items a second life while helping others save money.'
              ),

              _buildFeatureSection(
                context, 
                Icons.home_work_outlined, 
                'Housing', 
                'Find student accommodation with confidence.',
                'Browse available hostels, bedsitters, and shared housing around your campus. UniHub supports verified House Plugs who help students discover genuine housing opportunities and reduce the risk of scams.'
              ),

              _buildFeatureSection(
                context, 
                Icons.menu_book_outlined, 
                'Notes', 
                'Learn together.',
                'Students can upload and share study materials like lecture notes, revision kits, past papers, and study guides to help others succeed academically.'
              ),

              _buildFeatureSection(
                context, 
                Icons.work_outline_rounded, 
                'Gigs', 
                'Find opportunities—or get help.',
                'Need a poster designed, help moving, or a tutor? Post a gig and let fellow students reach out. It\'s also a great way to advertise your skills and earn while studying.'
              ),

              _buildFeatureSection(
                context, 
                Icons.chat_bubble_outline_rounded, 
                'Chat', 
                'Connect directly.',
                'Integrated messaging makes communication simple. Negotiate purchases, ask about accommodation, or discuss study notes—all organized inside the app.'
              ),

              _buildFeatureSection(
                context, 
                Icons.notifications_none_rounded, 
                'Notifications', 
                'Stay informed.',
                'Receive instant updates about messages, marketplace activity, housing interactions, and important campus announcements.'
              ),

              _buildFeatureSection(
                context, 
                Icons.verified_user_outlined, 
                'Trust & Verification', 
                'Trust matters.',
                'Verification badges help build confidence when interacting with sellers and contributors, encouraging a safer campus marketplace for everyone.'
              ),

              const SizedBox(height: 24),
              _buildSimpleSection(context, '🎓 Built for Students', 'Every feature in UniHub is designed around real student needs. Whether you\'re a first-year settling in or a finalist preparing to graduate, UniHub helps you connect with opportunities throughout your university journey.'),
              
              _buildSimpleSection(context, 'Our Vision', 'To build the most trusted digital campus community where students can learn, trade, collaborate, and support one another.'),
              
              _buildSimpleSection(context, 'Our Mission', 'To simplify student life by bringing essential campus services together in one secure, reliable, and easy-to-use platform.'),

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 32),
              
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    Text(
                      'UniHub grows with its students.',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We continuously improve the platform based on feedback from our campus communities. Every suggestion helps us build a better experience for everyone.',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              Center(
                child: Text(
                  'UniHub Version 1.0',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5), fontWeight: FontWeight.bold),
                ),
              ),
              Center(
                child: Text(
                  '© 2024 UniHub. All rights reserved.',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3)),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureSection(BuildContext context, IconData icon, String title, String subtitle, String body) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleSection(BuildContext context, String title, String body) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5, color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _drawerItem(
      BuildContext context,
      IconData icon,
      String title, {
        Color? color,
        required VoidCallback onTap,
        bool showInV1 = true,
      }) {
    if (!showInV1) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: color ?? theme.colorScheme.onSurfaceVariant, size: 22),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: color ?? theme.colorScheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      trailing: Icon(Icons.chevron_right, size: 18, color: color ?? theme.colorScheme.onSurfaceVariant.withOpacity(0.3)),
      onTap: onTap,
    );
  }
}
