import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unihub_mobile/features/shared/notification_repository.dart';
import '../../services/notification_service.dart';
import '../../services/presence_service.dart';

import '../dashboard/dashboard_screen.dart';
import '../housing/presentation/screens/housing_screen.dart';
import '../marketplace/marketplace_screen.dart';
import '../notes/notes_screen.dart';
import '../profile/profile_screen.dart';
import '../chat/presentation/screens/conversations_list_screen.dart';
import '../chat/shared/providers.dart';
import '../auth/shared/providers.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider).requestPermission();
      ref.read(presenceServiceProvider).init();
    });
  }

  @override
  void dispose() {
    ref.read(presenceServiceProvider).dispose();
    super.dispose();
  }

  final List<Widget> pages = const [
    DashboardScreen(),
    MarketplaceScreen(),
    HousingScreen(),
    ConversationsListScreen(),
    NotesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final unreadCount = ref.watch(unreadNotificationsCountProvider(null)).valueOrNull ?? 0;
    final marketplaceUnreadCount = ref.watch(unreadNotificationsCountProvider('marketplace')).valueOrNull ?? 0;
    final housingUnreadCount = ref.watch(unreadNotificationsCountProvider('housing')).valueOrNull ?? 0;
    final chatUnreadCount = ref.watch(totalUnreadChatCountProvider(userId)).valueOrNull ?? 0;
    final notesUnreadCount = ref.watch(unreadNotificationsCountProvider('notes')).valueOrNull ?? 0;

    return Scaffold(
      drawer: const AppDrawer(),
      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
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
                  child: const Icon(Icons.home_rounded),
                )
              : const Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: marketplaceUnreadCount > 0
              ? Badge(
                  label: Text(marketplaceUnreadCount > 9 ? '9+' : '$marketplaceUnreadCount'),
                  child: const Icon(Icons.storefront_outlined),
                )
              : const Icon(Icons.storefront_outlined),
            selectedIcon: marketplaceUnreadCount > 0
              ? Badge(
                  label: Text(marketplaceUnreadCount > 9 ? '9+' : '$marketplaceUnreadCount'),
                  child: const Icon(Icons.storefront_rounded),
                )
              : const Icon(Icons.storefront_rounded),
            label: 'Marketplace',
          ),
          NavigationDestination(
            icon: housingUnreadCount > 0
              ? Badge(
                  label: Text(housingUnreadCount > 9 ? '9+' : '$housingUnreadCount'),
                  child: const Icon(Icons.home_work_outlined),
                )
              : const Icon(Icons.home_work_outlined),
            selectedIcon: housingUnreadCount > 0
              ? Badge(
                  label: Text(housingUnreadCount > 9 ? '9+' : '$housingUnreadCount'),
                  child: const Icon(Icons.home_work_rounded),
                )
              : const Icon(Icons.home_work_rounded),
            label: 'Housing',
          ),
          NavigationDestination(
            icon: chatUnreadCount > 0
              ? Badge(
                  label: Text(chatUnreadCount > 9 ? '9+' : '$chatUnreadCount'),
                  child: const Icon(Icons.chat_bubble_outline_rounded),
                )
              : const Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: chatUnreadCount > 0
              ? Badge(
                  label: Text(chatUnreadCount > 9 ? '9+' : '$chatUnreadCount'),
                  child: const Icon(Icons.chat_bubble_rounded),
                )
              : const Icon(Icons.chat_bubble_rounded),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: notesUnreadCount > 0
              ? Badge(
                  label: Text(notesUnreadCount > 9 ? '9+' : '$notesUnreadCount'),
                  child: const Icon(Icons.menu_book_outlined),
                )
              : const Icon(Icons.menu_book_outlined),
            selectedIcon: notesUnreadCount > 0
              ? Badge(
                  label: Text(notesUnreadCount > 9 ? '9+' : '$notesUnreadCount'),
                  child: const Icon(Icons.menu_book_rounded),
                )
              : const Icon(Icons.menu_book_rounded),
            label: 'Notes',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
