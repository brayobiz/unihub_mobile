import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/shared/providers.dart';
import '../features/housing/shared/providers.dart';
import '../features/trust/domain/models/professional_role.dart';
import '../features/trust/domain/models/verification_application.dart';
import '../features/trust/presentation/providers/trust_providers.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final appUserAsync = ref.watch(appUserProvider);

    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header
          GestureDetector(
            onTap: () {
              context.push('/profile');
            },
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: DrawerHeader(
                margin: EdgeInsets.zero,
                child: appUserAsync.when(
                  data: (user) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.white24,
                        backgroundImage: user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
                        child: user?.photoUrl == null ? const Icon(Icons.person, size: 35, color: Colors.white) : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user?.fullName ?? 'User',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
                  error: (_, __) => const Text('Error loading profile', style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
          ),

          // Discover Section
          _sectionHeader(context, 'Marketplace & Gigs'),
          _drawerItem(context, Icons.inventory_2_outlined, 'My Listings (Seller Hub)', onTap: () {
            context.push('/my-listings');
          }),
          _drawerItem(context, Icons.assignment_ind_outlined, 'Employer Dashboard', onTap: () {
            context.push('/employer-dashboard');
          }),
          
          _sectionHeader(context, 'Housing'),
          appUserAsync.when(
            data: (user) {
              final isPlug = user?.isHousingPlug ?? false;
              if (isPlug) {
                return _drawerItem(context, Icons.dashboard_customize_outlined, 'Plug Dashboard', onTap: () {
                  context.push('/plug-dashboard');
                });
              } else {
                final applicationAsync = ref.watch(applicationByRoleProvider(ProfessionalRole.housePlug));
                return applicationAsync.when(
                  data: (app) {
                    if (app?.status == VerificationStatus.pending) {
                      return _drawerItem(context, Icons.hourglass_empty_rounded, 'Plug App Pending', color: theme.colorScheme.primary, onTap: () {
                        context.push('/plug-dashboard');
                      });
                    }
                    return _drawerItem(context, Icons.add_home_work_outlined, 'Become a Housing Plug', onTap: () {
                      context.push('/become-plug');
                    });
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => _drawerItem(context, Icons.add_home_work_outlined, 'Become a Housing Plug', onTap: () {
                    context.push('/become-plug');
                  }),
                );
              }
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          _drawerItem(context, Icons.favorite_border, 'Saved Housing', onTap: () {
            context.push('/saved-housing');
          }),
          
          _sectionHeader(context, 'Campus Life'),
          _drawerItem(context, Icons.groups_outlined, 'Community', onTap: () {
            context.push('/community');
          }),
          _drawerItem(context, Icons.work_outline, 'Student Gigs', onTap: () {
            context.push('/gigs');
          }),
          _drawerItem(context, Icons.favorite_border, 'Confessions', onTap: () {
            context.push('/confessions');
          }),

          Divider(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),

          // More Section
          _sectionHeader(context, 'More'),
          _drawerItem(context, Icons.notifications_outlined, 'Notifications', onTap: () {
            context.push('/notifications');
          }),
          _drawerItem(context, Icons.settings_outlined, 'Settings', onTap: () {
            context.push('/settings');
          }),
          _drawerItem(context, Icons.help_outline, 'Help Centre', onTap: () {
            context.push('/help');
          }),

          Divider(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),

          // Logout
          _drawerItem(
            context,
            Icons.logout,
            'Log Out',
            color: AppColors.error,
            onTap: () => _showLogoutConfirm(context, ref),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirm(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Log Out?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
        ),
        content: Text(
          'Are you sure you want to log out of UniHub?',
          style: GoogleFonts.plusJakartaSans(color: theme.colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7), fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authControllerProvider.notifier).signOut();
            },
            child: Text(
              'Log Out',
              style: GoogleFonts.plusJakartaSans(color: AppColors.error, fontWeight: FontWeight.bold),
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
        style: GoogleFonts.plusJakartaSans(
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
      }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: color ?? theme.colorScheme.onSurfaceVariant, size: 22),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
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
