import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/notification_service.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/auth/domain/models/app_user.dart';
import 'package:unihub_mobile/features/auth/presentation/controllers/auth_controller.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final isDark = prefs.getBool('isDarkMode') ?? false;
  return isDark ? ThemeMode.dark : ThemeMode.light;
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final userAsync = ref.watch(appUserProvider);
    final authState = ref.watch(authControllerProvider);

    // Listen to AuthController for global loading/error feedback
    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (err, _) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err.toString()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        ),
      );
    });

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF8F9FB),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'Settings',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
          ),
          body: userAsync.when(
            data: (user) => _buildBody(context, ref, user, themeMode),
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.indigo)),
            error: (err, _) => Center(child: Text('Error: $err')),
          ),
        ),
        if (authState.isLoading)
          Container(
            color: Colors.black26,
            child: const Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, AppUser? user, ThemeMode themeMode) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      children: [
        _buildSectionHeader('Appearance'),
        _buildSettingsCard([
          _buildSettingTile(
            icon: Icons.dark_mode_outlined,
            title: 'Dark Mode',
            subtitle: 'Toggle app theme',
            trailing: Switch.adaptive(
              value: themeMode == ThemeMode.dark,
              activeColor: Colors.indigo,
              onChanged: (val) {
                ref.read(themeModeProvider.notifier).state = val ? ThemeMode.dark : ThemeMode.light;
                ref.read(sharedPreferencesProvider).setBool('isDarkMode', val);
              },
            ),
          ),
        ]),
        
        _buildSectionHeader('Privacy & Visibility'),
        _buildSettingsCard([
          _buildSettingTile(
            icon: Icons.visibility_outlined,
            title: 'Profile Visibility',
            subtitle: 'Who can see your detailed profile',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                user?.privacySettings['profile_visibility']?.capitalize() ?? 'University',
                style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            onTap: () => user != null ? _showProfileVisibilityDialog(context, ref, user) : null,
          ),
          const Divider(height: 1, indent: 50),
          _buildSettingTile(
            icon: Icons.share_location_outlined,
            title: 'Show My University',
            subtitle: 'Allow students to see your campus',
            trailing: Switch.adaptive(
              value: user?.privacySettings['show_university'] != 'private',
              activeColor: Colors.indigo,
              onChanged: (val) {
                if (user != null) {
                  _updatePrivacySetting(ref, user.uid, 'show_university', val ? 'public' : 'private');
                }
              },
            ),
          ),
          const Divider(height: 1, indent: 50),
          _buildSettingTile(
            icon: Icons.contact_mail_outlined,
            title: 'Show Social Links',
            subtitle: 'Visible on your seller profile',
            trailing: Switch.adaptive(
              value: user?.privacySettings['show_socials'] != 'private',
              activeColor: Colors.indigo,
              onChanged: (val) {
                if (user != null) {
                  _updatePrivacySetting(ref, user.uid, 'show_socials', val ? 'university' : 'private');
                }
              },
            ),
          ),
        ]),

        _buildSectionHeader('Notifications'),
        _buildSettingsCard([
          _buildSwitchTile(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Messages',
            value: user?.notificationSettings['new_messages'] ?? true,
            onChanged: (val) => user != null ? _updateNotificationSetting(ref, user.uid, 'new_messages', val) : null,
          ),
          const Divider(height: 1, indent: 50),
          _buildSwitchTile(
            icon: Icons.storefront_outlined,
            title: 'Marketplace',
            value: user?.notificationSettings['marketplace'] ?? true,
            onChanged: (val) => user != null ? _updateNotificationSetting(ref, user.uid, 'marketplace', val) : null,
          ),
          const Divider(height: 1, indent: 50),
          _buildSwitchTile(
            icon: Icons.home_work_outlined,
            title: 'Housing',
            value: user?.notificationSettings['housing'] ?? true,
            onChanged: (val) => user != null ? _updateNotificationSetting(ref, user.uid, 'housing', val) : null,
          ),
          const Divider(height: 1, indent: 50),
          _buildSwitchTile(
            icon: Icons.menu_book_outlined,
            title: 'Study Notes',
            value: user?.notificationSettings['notes'] ?? true,
            onChanged: (val) => user != null ? _updateNotificationSetting(ref, user.uid, 'notes', val) : null,
          ),
          const Divider(height: 1, indent: 50),
          _buildSwitchTile(
            icon: Icons.electrical_services_outlined,
            title: 'Plug Requests',
            value: user?.notificationSettings['plug'] ?? true,
            onChanged: (val) => user != null ? _updateNotificationSetting(ref, user.uid, 'plug', val) : null,
          ),
          const Divider(height: 1, indent: 50),
          _buildSwitchTile(
            icon: Icons.star_outline_rounded,
            title: 'Reviews & Feedback',
            value: user?.notificationSettings['reviews'] ?? true,
            onChanged: (val) => user != null ? _updateNotificationSetting(ref, user.uid, 'reviews', val) : null,
          ),
          const Divider(height: 1, indent: 50),
          _buildSwitchTile(
            icon: Icons.person_add_outlined,
            title: 'New Followers',
            value: user?.notificationSettings['followers'] ?? true,
            onChanged: (val) => user != null ? _updateNotificationSetting(ref, user.uid, 'followers', val) : null,
          ),
          const Divider(height: 1, indent: 50),
          _buildSwitchTile(
            icon: Icons.campaign_outlined,
            title: 'System Announcements',
            value: user?.notificationSettings['system'] ?? true,
            onChanged: (val) => user != null ? _updateNotificationSetting(ref, user.uid, 'system', val) : null,
          ),
          const Divider(height: 1, indent: 50),
          _buildSwitchTile(
            icon: Icons.groups_outlined,
            title: 'Community Activity',
            value: user?.notificationSettings['community_activity'] ?? true,
            onChanged: (val) => user != null ? _updateNotificationSetting(ref, user.uid, 'community_activity', val) : null,
          ),
          const Divider(height: 1, indent: 50),
          _buildSettingTile(
            icon: Icons.notification_important_outlined,
            title: 'Push Notifications',
            subtitle: 'Check system permissions',
            onTap: () async {
              final granted = await ref.read(notificationServiceProvider).requestPermission();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(granted ? 'Notifications enabled!' : 'Permission denied. Check device settings.'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: granted ? Colors.green : Colors.red,
                  ),
                );
              }
            },
          ),
        ]),

        _buildSectionHeader('Account & Security'),
        _buildSettingsCard([
          _buildSettingTile(
            icon: Icons.verified_user_outlined,
            title: 'Trust & Verification',
            onTap: () => context.push('/trust-center'),
          ),
          const Divider(height: 1, indent: 50),
          _buildSettingTile(
            icon: Icons.lock_outline_rounded,
            title: 'Change Password',
            onTap: () => _showChangePasswordDialog(context, ref),
          ),
          const Divider(height: 1, indent: 50),
          _buildSettingTile(
            icon: Icons.delete_outline_rounded,
            title: 'Delete Account',
            titleColor: Colors.red,
            onTap: () => _showDeleteAccountDialog(context, ref),
          ),
        ]),

        _buildSectionHeader('Support'),
        _buildSettingsCard([
          _buildSettingTile(
            icon: Icons.help_outline_rounded,
            title: 'Help Centre',
            onTap: () => context.push('/help'),
          ),
          const Divider(height: 1, indent: 50),
          _buildSettingTile(
            icon: Icons.policy_outlined,
            title: 'Privacy Policy',
            onTap: () => _launchPrivacyPolicy(),
          ),
        ]),

        const SizedBox(height: 32),
        Center(
          child: Column(
            children: [
              TextButton(
                onPressed: () => _showSignOutDialog(context, ref),
                child: const Text('Sign Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
              const Text('UniHub v1.2.5 (Stable)', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 24, 20, 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (titleColor ?? Colors.indigo).withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: titleColor ?? Colors.indigo),
      ),
      title: Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: titleColor)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildSwitchTile({required IconData icon, required String title, required bool value, required ValueChanged<bool> onChanged}) {
    return _buildSettingTile(
      icon: icon,
      title: title,
      trailing: Switch.adaptive(
        value: value,
        activeColor: Colors.indigo,
        onChanged: onChanged,
      ),
    );
  }

  void _updateNotificationSetting(WidgetRef ref, String uid, String key, bool value) {
    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;
    
    final Map<String, bool> newSettings = Map.from(user.notificationSettings);
    newSettings[key] = value;
    
    ref.read(authControllerProvider.notifier).updateNotificationSettings(newSettings);
  }

  void _updatePrivacySetting(WidgetRef ref, String uid, String key, String value) {
    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;
    
    final Map<String, String> newSettings = Map.from(user.privacySettings);
    newSettings[key] = value;
    
    ref.read(authControllerProvider.notifier).updatePrivacySettings(newSettings);
  }

  void _showProfileVisibilityDialog(BuildContext context, WidgetRef ref, AppUser user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profile Visibility', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Control who can see your detailed profile and contact info.', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            _visibilityOption(context, ref, user, 'public', 'Public', 'Visible to everyone on UniHub', Icons.public),
            _visibilityOption(context, ref, user, 'university', 'My University', 'Only students from your campus', Icons.school_outlined),
            _visibilityOption(context, ref, user, 'private', 'Private', 'Hidden from all users', Icons.lock_outline),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _visibilityOption(BuildContext context, WidgetRef ref, AppUser user, String value, String title, String subtitle, IconData icon) {
    final isSelected = user.privacySettings['profile_visibility'] == value;
    return ListTile(
      onTap: () {
        _updatePrivacySetting(ref, user.uid, 'profile_visibility', value);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Visibility updated to $title'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      },
      leading: Icon(icon, color: isSelected ? Colors.indigo : Colors.grey),
      title: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.indigo) : null,
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset Password'),
        content: Text('We will send a password reset link to ${user.email}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              ref.read(authControllerProvider.notifier).resetPassword(user.email);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reset link sent!'), behavior: SnackBarBehavior.floating),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of UniHub?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(authControllerProvider.notifier).signOut();
              Navigator.pop(context);
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Account?'),
        content: const Text('This action is permanent and will remove all your listings, messages, and profile data from UniHub.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(authControllerProvider.notifier).deleteAccount();
              Navigator.pop(context);
            },
            child: const Text('Delete Permanently', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _launchPrivacyPolicy() async {
    final Uri url = Uri.parse('https://unihub-mobile.web.app/privacy');
    if (!await launchUrl(url)) {
      debugPrint('Could not launch $url');
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
