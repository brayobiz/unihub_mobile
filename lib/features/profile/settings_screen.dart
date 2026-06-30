import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import '../../../services/notification_service.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/auth/domain/models/app_user.dart';
import 'package:unihub_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:unihub_mobile/app/theme/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final userAsync = ref.watch(appUserProvider);
    final authState = ref.watch(authControllerProvider);

    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (err, _) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err.toString()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        ),
      );
    });

    return Stack(
      children: [
        Scaffold(
          backgroundColor: theme.colorScheme.surface,
          appBar: AppBar(
            backgroundColor: theme.colorScheme.surface,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface, size: 20),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'Settings',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
          ),
          body: userAsync.when(
            data: (user) => _buildBody(context, ref, user, themeMode),
            loading: () => Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
            error: (err, _) => Center(child: Text('Error: $err')),
          ),
        ),
        if (authState.isLoading)
          Container(
            color: Colors.black26,
            child: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
          ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, AppUser? user, ThemeMode themeMode) {
    final theme = Theme.of(context);
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      children: [
        _buildSectionHeader(context, 'Appearance'),
        _buildSettingsCard(context, [
          _buildSettingTile(
            context,
            icon: Icons.dark_mode_outlined,
            title: 'Dark Mode',
            subtitle: 'Toggle app theme',
            trailing: Switch.adaptive(
              value: themeMode == ThemeMode.dark,
              activeTrackColor: theme.colorScheme.primary,
              onChanged: (val) {
                ref.read(themeModeProvider.notifier).state = val ? ThemeMode.dark : ThemeMode.light;
                ref.read(sharedPreferencesProvider).setBool('isDarkMode', val);
              },
            ),
          ),
        ]),
        
        _buildSectionHeader(context, 'Privacy & Visibility'),
        _buildSettingsCard(context, [
          _buildSettingTile(
            context,
            icon: Icons.visibility_outlined,
            title: 'Profile Visibility',
            subtitle: 'Who can see your detailed profile',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                user?.privacySettings['profile_visibility']?.capitalize() ?? 'University',
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            onTap: () => user != null ? _showProfileVisibilityDialog(context, ref, user) : null,
          ),
          const Divider(height: 1, indent: 50),
          _buildSettingTile(
            context,
            icon: Icons.share_location_outlined,
            title: 'Show My University',
            subtitle: 'Allow students to see your campus',
            trailing: Switch.adaptive(
              value: user?.privacySettings['show_university'] != 'private',
              activeTrackColor: theme.colorScheme.primary,
              onChanged: (val) {
                if (user != null) {
                  _updatePrivacySetting(ref, user.uid, 'show_university', val ? 'public' : 'private');
                }
              },
            ),
          ),
          const Divider(height: 1, indent: 50),
          _buildSettingTile(
            context,
            icon: Icons.contact_mail_outlined,
            title: 'Show Social Links',
            subtitle: 'Visible on your seller profile',
            trailing: Switch.adaptive(
              value: user?.privacySettings['show_socials'] != 'private',
              activeTrackColor: theme.colorScheme.primary,
              onChanged: (val) {
                if (user != null) {
                  _updatePrivacySetting(ref, user.uid, 'show_socials', val ? 'university' : 'private');
                }
              },
            ),
          ),
        ]),

        _buildSectionHeader(context, 'Notifications'),
        _buildSettingsCard(context, [
          _buildSwitchTile(context, icon: Icons.chat_bubble_outline_rounded, title: 'Messages', value: user?.notificationSettings['new_messages'] ?? true, onChanged: (val) => user != null ? _updateNotificationSetting(ref, user.uid, 'new_messages', val) : null),
          const Divider(height: 1, indent: 50),
          _buildSwitchTile(context, icon: Icons.storefront_outlined, title: 'Marketplace', value: user?.notificationSettings['marketplace'] ?? true, onChanged: (val) => user != null ? _updateNotificationSetting(ref, user.uid, 'marketplace', val) : null),
          const Divider(height: 1, indent: 50),
          _buildSwitchTile(context, icon: Icons.home_work_outlined, title: 'Housing', value: user?.notificationSettings['housing'] ?? true, onChanged: (val) => user != null ? _updateNotificationSetting(ref, user.uid, 'housing', val) : null),
          const Divider(height: 1, indent: 50),
          _buildSwitchTile(context, icon: Icons.menu_book_outlined, title: 'Study Notes', value: user?.notificationSettings['notes'] ?? true, onChanged: (val) => user != null ? _updateNotificationSetting(ref, user.uid, 'notes', val) : null),
          const Divider(height: 1, indent: 50),
          _buildSwitchTile(context, icon: Icons.electrical_services_outlined, title: 'Plug Requests', value: user?.notificationSettings['plug'] ?? true, onChanged: (val) => user != null ? _updateNotificationSetting(ref, user.uid, 'plug', val) : null),
          const Divider(height: 1, indent: 50),
          _buildSwitchTile(context, icon: Icons.star_outline_rounded, title: 'Reviews & Feedback', value: user?.notificationSettings['reviews'] ?? true, onChanged: (val) => user != null ? _updateNotificationSetting(ref, user.uid, 'reviews', val) : null),
          const Divider(height: 1, indent: 50),
          _buildSwitchTile(context, icon: Icons.person_add_outlined, title: 'New Followers', value: user?.notificationSettings['followers'] ?? true, onChanged: (val) => user != null ? _updateNotificationSetting(ref, user.uid, 'followers', val) : null),
          const Divider(height: 1, indent: 50),
          _buildSwitchTile(context, icon: Icons.campaign_outlined, title: 'System Announcements', value: user?.notificationSettings['system'] ?? true, onChanged: (val) => user != null ? _updateNotificationSetting(ref, user.uid, 'system', val) : null),
          const Divider(height: 1, indent: 50),
          _buildSwitchTile(context, icon: Icons.groups_outlined, title: 'Community Activity', value: user?.notificationSettings['community_activity'] ?? true, onChanged: (val) => user != null ? _updateNotificationSetting(ref, user.uid, 'community_activity', val) : null),
          const Divider(height: 1, indent: 50),
          _buildSettingTile(
            context,
            icon: Icons.notification_important_outlined,
            title: 'Push Notifications',
            subtitle: 'Check system permissions',
            onTap: () async {
              final granted = await ref.read(notificationServiceProvider).requestPermission();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(granted ? 'Notifications enabled!' : 'Permission denied. Check device settings.'), behavior: SnackBarBehavior.floating, backgroundColor: granted ? AppColors.success : AppColors.error));
              }
            },
          ),
        ]),

        _buildSectionHeader(context, 'Account & Security'),
        _buildSettingsCard(context, [
          _buildSettingTile(context, icon: Icons.verified_user_outlined, title: 'Trust & Verification', onTap: () => context.push('/trust-center')),
          const Divider(height: 1, indent: 50),
          _buildSettingTile(context, icon: Icons.lock_outline_rounded, title: 'Change Password', onTap: () => _showChangePasswordDialog(context, ref)),
          const Divider(height: 1, indent: 50),
          _buildSettingTile(context, icon: Icons.delete_outline_rounded, title: 'Delete Account', titleColor: AppColors.error, onTap: () => _showDeleteAccountDialog(context, ref)),
        ]),

        _buildSectionHeader(context, 'Support'),
        _buildSettingsCard(context, [
          _buildSettingTile(context, icon: Icons.help_outline_rounded, title: 'Help Centre', onTap: () => context.push('/help')),
          const Divider(height: 1, indent: 50),
          _buildSettingTile(context, icon: Icons.policy_outlined, title: 'Privacy Policy', onTap: () => _launchPrivacyPolicy()),
        ]),

        const SizedBox(height: 32),
        Center(child: Column(children: [
          TextButton(onPressed: () => _showSignOutDialog(context, ref), child: const Text('Sign Out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold))),
          Text('UniHub v1.2.5 (Stable)', style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 12)),
        ])),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(padding: const EdgeInsets.fromLTRB(10, 24, 20, 12), child: Text(title.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7), letterSpacing: 1.2)));
  }

  Widget _buildSettingsCard(BuildContext context, List<Widget> children) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildSettingTile(BuildContext context, {required IconData icon, required String title, String? subtitle, Widget? trailing, VoidCallback? onTap, Color? titleColor}) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: (titleColor ?? theme.colorScheme.primary).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 20, color: titleColor ?? theme.colorScheme.primary)),
      title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: titleColor ?? theme.colorScheme.onSurface)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7))) : null,
      trailing: trailing ?? Icon(Icons.chevron_right_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildSwitchTile(BuildContext context, {required IconData icon, required String title, required bool value, required ValueChanged<bool> onChanged}) {
    final theme = Theme.of(context);
    return _buildSettingTile(context, icon: icon, title: title, trailing: Switch.adaptive(value: value, activeTrackColor: theme.colorScheme.primary, onChanged: onChanged));
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
    final theme = Theme.of(context);
    showModalBottomSheet(context: context, backgroundColor: theme.colorScheme.surface, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))), builder: (context) => Container(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Profile Visibility', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
      const SizedBox(height: 12),
      Text('Control who can see your detailed profile and contact info.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 24),
      _visibilityOption(context, ref, user, 'public', 'Public', 'Visible to everyone on UniHub', Icons.public),
      _visibilityOption(context, ref, user, 'university', 'My University', 'Only students from your campus', Icons.school_outlined),
      _visibilityOption(context, ref, user, 'private', 'Private', 'Hidden from all users', Icons.lock_outline),
      const SizedBox(height: 20),
    ])));
  }

  Widget _visibilityOption(BuildContext context, WidgetRef ref, AppUser user, String value, String title, String subtitle, IconData icon) {
    final theme = Theme.of(context);
    final isSelected = user.privacySettings['profile_visibility'] == value;
    return ListTile(
      onTap: () {
        _updatePrivacySetting(ref, user.uid, 'profile_visibility', value);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Visibility updated to $title'), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
      },
      leading: Icon(icon, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
      title: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: theme.colorScheme.onSurface)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
      trailing: isSelected ? Icon(Icons.check_circle, color: theme.colorScheme.primary) : null,
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;
    showDialog(context: context, builder: (context) => AlertDialog(backgroundColor: theme.colorScheme.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: const Text('Reset Password'), content: Text('We will send a password reset link to ${user.email}.'), actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () { ref.read(authControllerProvider.notifier).resetPassword(user.email); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reset link sent!'), behavior: SnackBarBehavior.floating)); }, style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.primary), child: const Text('Send Link')),
    ]));
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    showDialog(context: context, builder: (context) => AlertDialog(backgroundColor: theme.colorScheme.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: const Text('Sign Out'), content: const Text('Are you sure you want to sign out of UniHub?'), actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      TextButton(onPressed: () { ref.read(authControllerProvider.notifier).signOut(); Navigator.pop(context); }, child: const Text('Sign Out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold))),
    ]));
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    showDialog(context: context, builder: (context) => AlertDialog(backgroundColor: theme.colorScheme.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: const Text('Delete Account?'), content: const Text('This action is permanent and will remove all your listings, messages, and profile data from UniHub.'), actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      TextButton(onPressed: () { ref.read(authControllerProvider.notifier).deleteAccount(); Navigator.pop(context); }, child: const Text('Delete Permanently', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold))),
    ]));
  }

  Future<void> _launchPrivacyPolicy() async {
    final Uri url = Uri.parse('https://unihub-mobile.web.app/privacy');
    if (!await launchUrl(url)) { debugPrint('Could not launch $url'); }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
