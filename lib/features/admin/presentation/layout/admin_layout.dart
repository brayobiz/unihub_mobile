import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/admin_sidebar.dart';
import '../../../../app/theme/app_colors.dart';

class AdminLayout extends StatelessWidget {
  final Widget child;
  final String title;

  const AdminLayout({
    super.key,
    required this.child,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).matchedLocation;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.person, color: Colors.white, size: 20),
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
              color: AppColors.backgroundLight,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
