import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final appUserAsync = ref.watch(appUserProvider);

    return Drawer(
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
                  colors: [Colors.indigo.shade600, Colors.indigo.shade400],
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
          _sectionHeader('Marketplace & Gigs'),
          _drawerItem(Icons.inventory_2_outlined, 'My Listings (Seller Hub)', onTap: () {
            context.push('/my-listings');
          }),
          _drawerItem(Icons.assignment_ind_outlined, 'Employer Dashboard', onTap: () {
            context.push('/employer-dashboard');
          }),
          
          _sectionHeader('Housing'),
          appUserAsync.when(
            data: (user) {
              final isPlug = user?.isHousingPlug ?? false;
              if (isPlug) {
                return _drawerItem(Icons.dashboard_customize_outlined, 'Plug Dashboard', onTap: () {
                  context.push('/plug-dashboard');
                });
              } else {
                final applicationAsync = ref.watch(applicationByRoleProvider(ProfessionalRole.housePlug));
                return applicationAsync.when(
                  data: (app) {
                    if (app?.status == VerificationStatus.pending) {
                      return _drawerItem(Icons.hourglass_empty_rounded, 'Plug App Pending', color: Colors.indigo, onTap: () {
                        context.push('/plug-dashboard');
                      });
                    }
                    return _drawerItem(Icons.add_home_work_outlined, 'Become a Housing Plug', onTap: () {
                      context.push('/become-plug');
                    });
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => _drawerItem(Icons.add_home_work_outlined, 'Become a Housing Plug', onTap: () {
                    context.push('/become-plug');
                  }),
                );
              }
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          _drawerItem(Icons.favorite_border, 'Saved Housing', onTap: () {
            context.push('/saved-housing');
          }),
          
          _sectionHeader('Campus Life'),
          _drawerItem(Icons.groups_outlined, 'Community', onTap: () {
            context.push('/community');
          }),
          _drawerItem(Icons.work_outline, 'Student Gigs', onTap: () {
            context.push('/gigs');
          }),
          _drawerItem(Icons.favorite_border, 'Confessions', onTap: () {
            context.push('/confessions');
          }),

          const Divider(),

          // More Section
          _sectionHeader('More'),
          _drawerItem(Icons.notifications_outlined, 'Notifications', onTap: () {
            context.push('/notifications');
          }),
          _drawerItem(Icons.settings_outlined, 'Settings', onTap: () {
            context.push('/settings');
          }),
          _drawerItem(Icons.help_outline, 'Help Centre', onTap: () {
            context.push('/help');
          }),

          const Divider(),

          // Logout
          _drawerItem(
            Icons.logout,
            'Log Out',
            color: Colors.red,
            onTap: () => _showLogoutConfirm(context, ref),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Log Out?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to log out of UniHub?',
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authControllerProvider.notifier).signOut();
            },
            child: Text(
              'Log Out',
              style: GoogleFonts.plusJakartaSans(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _drawerItem(
      IconData icon,
      String title, {
        Color? color,
        required VoidCallback onTap,
      }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.black87, size: 22),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          color: color ?? Colors.black87,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      trailing: Icon(Icons.chevron_right, size: 18, color: color ?? Colors.grey.shade400),
      onTap: onTap,
    );
  }
}
