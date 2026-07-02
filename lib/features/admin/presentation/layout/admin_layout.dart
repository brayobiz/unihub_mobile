import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../widgets/notification_badge.dart';
import '../widgets/admin_sidebar.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../auth/shared/providers.dart';

class AdminLayout extends ConsumerWidget {
  final Widget child;
  final String title;
  final List<Widget>? actions;

  const AdminLayout({
    super.key,
    required this.child,
    required this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = GoRouterState.of(context).matchedLocation;
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final admin = ref.watch(appUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          if (actions != null) ...actions!,
          if (!isDesktop && admin != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Center(
                child: Text(
                  admin.fullName.split(' ').first,
                  style: TextStyle(
                    fontSize: 12, 
                    fontWeight: FontWeight.bold, 
                    color: Theme.of(context).colorScheme.onSurfaceVariant
                  ),
                ),
              ),
            ),
          NotificationBadge(
            iconColor: Theme.of(context).colorScheme.onSurface,
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary,
            backgroundImage: admin?.photoUrl != null ? NetworkImage(admin!.photoUrl!) : null,
            child: admin?.photoUrl == null ? const Icon(Icons.person, color: Colors.white, size: 20) : null,
          ),
          const SizedBox(width: 16),
        ],
      ),
      drawer: isDesktop ? null : AdminSidebar(currentPath: currentPath),
      body: Row(
        children: [
          if (isDesktop)
            SizedBox(
              width: 280,
              child: AdminSidebar(currentPath: currentPath),
            ),
          if (isDesktop) const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
