import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';

class AdminSidebar extends StatelessWidget {
  final String currentPath;

  const AdminSidebar({
    super.key,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: AppColors.primary,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.admin_panel_settings, color: Colors.white, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'UniHub Admin',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _SidebarItem(
                  icon: Icons.dashboard,
                  title: 'Dashboard',
                  path: '/admin/dashboard',
                  currentPath: currentPath,
                ),
                _SidebarItem(
                  icon: Icons.verified_user,
                  title: 'Verifications',
                  path: '/admin/verifications',
                  currentPath: currentPath,
                ),
                _SidebarItem(
                  icon: Icons.report,
                  title: 'Reports',
                  path: '/admin/reports',
                  currentPath: currentPath,
                ),
                const Divider(),
                _SidebarItem(
                  icon: Icons.shopping_bag,
                  title: 'Marketplace',
                  path: '/admin/marketplace',
                  currentPath: currentPath,
                ),
                _SidebarItem(
                  icon: Icons.home,
                  title: 'Housing',
                  path: '/admin/housing',
                  currentPath: currentPath,
                ),
                _SidebarItem(
                  icon: Icons.description,
                  title: 'Notes',
                  path: '/admin/notes',
                  currentPath: currentPath,
                ),
                _SidebarItem(
                  icon: Icons.event,
                  title: 'Events',
                  path: '/admin/events',
                  currentPath: currentPath,
                ),
                const Divider(),
                _SidebarItem(
                  icon: Icons.people,
                  title: 'Users',
                  path: '/admin/users',
                  currentPath: currentPath,
                ),
                _SidebarItem(
                  icon: Icons.support_agent,
                  title: 'Support Center',
                  path: '/admin/support',
                  currentPath: currentPath,
                ),
                _SidebarItem(
                  icon: Icons.campaign,
                  title: 'Announcements',
                  path: '/admin/announcements',
                  currentPath: currentPath,
                ),
                _SidebarItem(
                  icon: Icons.settings,
                  title: 'Settings',
                  path: '/admin/settings',
                  currentPath: currentPath,
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: AppColors.error),
            title: const Text('Exit Admin', style: TextStyle(color: AppColors.error)),
            onTap: () => context.go('/main'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String path;
  final String currentPath;
  final bool isPlaceholder;

  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.path,
    required this.currentPath,
    this.isPlaceholder = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentPath.startsWith(path);
    
    return Semantics(
      label: '$title navigation link',
      hint: 'Navigate to $title',
      selected: isSelected,
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? AppColors.primary : AppColors.grey600,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected 
                ? AppColors.primary 
                : Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: isPlaceholder 
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Soon',
                style: TextStyle(
                  fontSize: 10, 
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : null,
        selected: isSelected,
        onTap: isPlaceholder ? null : () => context.go(path),
      ),
    );
  }
}
