import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unihub_mobile/features/shared/notification_repository.dart';
import '../../services/notification_service.dart';

import '../dashboard/dashboard_screen.dart';
import '../housing/presentation/screens/housing_screen.dart';
import '../marketplace/marketplace_screen.dart';
import '../notes/notes_screen.dart';
import '../profile/profile_screen.dart';
import '../../widgets/app_drawer.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // For existing users who land on the main screen, check for notification permissions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider).requestPermission();
    });
  }

  final List<Widget> pages = const [
    DashboardScreen(),
    MarketplaceScreen(),
    HousingScreen(),
    NotesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: pages[currentIndex],

      bottomNavigationBar: Consumer(
        builder: (context, ref, child) {
          final unreadCount = ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;
          return NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                currentIndex = index;
              });
            },
            destinations: [
              NavigationDestination(
                icon: unreadCount > 0 
                  ? Badge(
                      label: Text(unreadCount > 9 ? '9+' : '$unreadCount'),
                      child: const Icon(Icons.home_outlined),
                    )
                  : const Icon(Icons.home_outlined),
                selectedIcon: unreadCount > 0
                  ? Badge(
                      label: Text(unreadCount > 9 ? '9+' : '$unreadCount'),
                      child: const Icon(Icons.home),
                    )
                  : const Icon(Icons.home),
                label: 'Home',
              ),

              const NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront),
                label: 'Marketplace',
              ),

              const NavigationDestination(
                icon: Icon(Icons.home_work_outlined),
                selectedIcon: Icon(Icons.home_work),
                label: 'Housing',
              ),

              const NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book),
                label: 'Notes',
              ),

              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          );
        },
      ),
    );
  }
}