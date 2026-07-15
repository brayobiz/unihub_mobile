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
import '../features/shared/about_screen.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Optimization: only watch isAdmin to avoid reloads on presence updates
    final isAdmin =
        ref.watch(appUserProvider.select((u) => u.valueOrNull?.isAdmin)) ??
        false;

    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      child: Column(
        children: [
          // Simplified Header / Branding
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + 20,
              20,
              20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withOpacity(0.8),
                ],
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
                  'Ulify Services',
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
                _drawerItem(
                  context,
                  Icons.groups_outlined,
                  'Community',
                  onTap: () {
                    context.push('/community');
                  },
                ),
                _drawerItem(
                  context,
                  Icons.work_outline,
                  'Student Gigs',
                  onTap: () {
                    context.push('/gigs');
                  },
                ),
                _drawerItem(
                  context,
                  Icons.favorite_border_rounded,
                  'Confessions',
                  onTap: () {
                    context.push('/confessions');
                  },
                ),
                _drawerItem(
                  context,
                  Icons.calendar_today_outlined,
                  'My Events',
                  onTap: () {
                    context.push('/my-events');
                  },
                ),

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
                    final managedAsync = ref.watch(
                      userManagedOrganizersProvider,
                    );
                    return managedAsync.when(
                      data: (orgs) {
                        final approvedOrgs = orgs
                            .where(
                              (o) =>
                                  o.verificationStatus ==
                                      OrganizerVerificationStatus.verified ||
                                  o.verificationStatus ==
                                      OrganizerVerificationStatus.official,
                            )
                            .toList();

                        final activeApp = orgs.firstWhere(
                          (o) =>
                              o.verificationStatus ==
                                  OrganizerVerificationStatus.draft ||
                              o.verificationStatus ==
                                  OrganizerVerificationStatus.submitted ||
                              o.verificationStatus ==
                                  OrganizerVerificationStatus.underReview ||
                              o.verificationStatus ==
                                  OrganizerVerificationStatus.rejected,
                          orElse: () => orgs.isNotEmpty
                              ? orgs.first
                              : Organizer(
                                  id: '',
                                  ownerId: '',
                                  name: '',
                                  bio: '',
                                  campusId: '',
                                  createdAt: DateTime.now(),
                                ),
                        );

                        final hasActiveApp =
                            activeApp.id.isNotEmpty &&
                            !approvedOrgs.any((o) => o.id == activeApp.id);

                        if (approvedOrgs.isNotEmpty) {
                          return _drawerItem(
                            context,
                            Icons.dashboard_customize_outlined,
                            'My Organizer Profiles',
                            onTap: () {
                              if (approvedOrgs.length == 1) {
                                context.push(
                                  '/organizers/${approvedOrgs.first.id}/dashboard',
                                );
                              } else {
                                context.push('/events');
                              }
                            },
                          );
                        }

                        if (hasActiveApp) {
                          final isRejected =
                              activeApp.verificationStatus ==
                              OrganizerVerificationStatus.rejected;
                          return _drawerItem(
                            context,
                            isRejected
                                ? Icons.edit_note_rounded
                                : Icons.hourglass_empty_rounded,
                            isRejected
                                ? 'Application Needs Attention'
                                : 'Application Processing',
                            onTap: () {
                              if (isRejected) {
                                context.pushNamed(
                                  'become-organizer',
                                  extra: activeApp,
                                );
                              } else {
                                context.push(
                                  '/organizers/${activeApp.id}/dashboard',
                                );
                              }
                            },
                          );
                        }

                        return _drawerItem(
                          context,
                          Icons.add_business_outlined,
                          'Become an Organizer',
                          onTap: () =>
                              context.pushNamed('organizer-onboarding'),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    );
                  },
                ),

                const Divider(),
                _sectionHeader(context, 'Platform'),
                _drawerItem(
                  context,
                  Icons.info_outline,
                  'About Ulify',
                  onTap: () {
                    Navigator.of(context).pop();
                    context.push('/about');
                  },
                ),

                if (isAdmin) ...[
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
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              'v1.0.1+3',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ),
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
      leading: Icon(
        icon,
        color: color ?? theme.colorScheme.onSurfaceVariant,
        size: 22,
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: color ?? theme.colorScheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      trailing: Icon(
        Icons.chevron_right,
        size: 18,
        color: color ?? theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
      ),
      onTap: onTap,
    );
  }
}
