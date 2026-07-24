import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unihub_mobile/features/shared/notification_repository.dart';
import 'package:unihub_mobile/features/navigation/navigation_providers.dart';
import '../../services/notification_service.dart';
import '../../services/presence_service.dart';

import '../dashboard/dashboard_screen.dart';
import '../housing/presentation/screens/housing_screen.dart';
import '../marketplace/marketplace_screen.dart';
import '../notes/notes_screen.dart';
import '../profile/profile_screen.dart';
import '../chat/domain/models/message.dart';
import '../chat/presentation/screens/conversations_list_screen.dart';
import '../chat/shared/providers.dart';
import '../auth/shared/providers.dart';
import '../auth/presentation/controllers/auth_controller.dart';
import '../../widgets/app_drawer.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider).requestPermission();
    });
  }

  final List<Widget> pages = const [
    DashboardScreen(),
    MarketplaceScreen(),
    HousingScreen(),
    NotesScreen(),
    ConversationsListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(mainNavigationIndexProvider);
    
    // Optimization: watch specific auth properties to prevent unnecessary rebuilds
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull;
    final userId = user?.uid;
    final isEmailVerified = user?.emailVerified ?? true;

    // GLOBAL DELIVERY TRACKER:
    if (userId != null) {
      ref.listen(conversationsProvider(userId), (previous, next) {
        if (next.hasValue) {
          for (final conv in next.value!) {
            if (conv.lastMessageSenderId != userId &&
                conv.lastMessageStatus == MessageStatus.sent) {
              ref.read(chatRepositoryProvider).markAsDelivered(conv.id, userId);
            }
          }
        }
      });
    }

    return Stack(
      children: [
        Scaffold(
          drawer: const AppDrawer(),
          body: Column(
            children: [
              if (user != null && !isEmailVerified)
                _buildVerificationBanner(context),
              Expanded(
                child: IndexedStack(
                  index: currentIndex,
                  children: pages,
                ),
              ),
            ],
          ),
          bottomNavigationBar: Consumer(
            builder: (context, ref, child) {
              final currentUserId = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
              final unreadCount = ref.watch(unreadNotificationsCountProvider(null)).valueOrNull ?? 0;
              final marketplaceUnreadCount = ref.watch(unreadNotificationsCountProvider('marketplace')).valueOrNull ?? 0;
              final housingUnreadCount = ref.watch(unreadNotificationsCountProvider('housing')).valueOrNull ?? 0;
              final chatUnreadCount = ref.watch(totalUnreadChatCountProvider(currentUserId)).valueOrNull ?? 0;
              final notesUnreadCount = ref.watch(unreadNotificationsCountProvider('notes')).valueOrNull ?? 0;

              return Semantics(
                label: 'Main Navigation Bar',
                container: true,
                child: NavigationBar(
                  selectedIndex: currentIndex,
                  onDestinationSelected: (index) {
                    ref.read(mainNavigationIndexProvider.notifier).state = index;
                  },
                  destinations: [
                    NavigationDestination(
                      icon: unreadCount > 0 
                        ? Badge(
                            label: Text(unreadCount > 9 ? '9+' : '$unreadCount'),
                            child: const Icon(Icons.home_outlined, semanticLabel: 'Home'),
                          )
                        : const Icon(Icons.home_outlined, semanticLabel: 'Home'),
                      selectedIcon: unreadCount > 0
                        ? Badge(
                            label: Text(unreadCount > 9 ? '9+' : '$unreadCount'),
                            child: const Icon(Icons.home_rounded, semanticLabel: 'Home'),
                          )
                        : const Icon(Icons.home_rounded, semanticLabel: 'Home'),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: marketplaceUnreadCount > 0
                        ? Badge(
                            label: Text(marketplaceUnreadCount > 9 ? '9+' : '$marketplaceUnreadCount'),
                            child: const Icon(Icons.storefront_outlined, semanticLabel: 'Marketplace'),
                          )
                        : const Icon(Icons.storefront_outlined, semanticLabel: 'Marketplace'),
                      selectedIcon: marketplaceUnreadCount > 0
                        ? Badge(
                            label: Text(marketplaceUnreadCount > 9 ? '9+' : '$marketplaceUnreadCount'),
                            child: const Icon(Icons.storefront_rounded, semanticLabel: 'Marketplace'),
                          )
                        : const Icon(Icons.storefront_rounded, semanticLabel: 'Marketplace'),
                      label: 'Market',
                    ),
                    NavigationDestination(
                      icon: housingUnreadCount > 0
                        ? Badge(
                            label: Text(housingUnreadCount > 9 ? '9+' : '$housingUnreadCount'),
                            child: const Icon(Icons.home_work_outlined, semanticLabel: 'Housing'),
                          )
                        : const Icon(Icons.home_work_outlined, semanticLabel: 'Housing'),
                      selectedIcon: housingUnreadCount > 0
                        ? Badge(
                            label: Text(housingUnreadCount > 9 ? '9+' : '$housingUnreadCount'),
                            child: const Icon(Icons.home_work_rounded, semanticLabel: 'Housing'),
                          )
                        : const Icon(Icons.home_work_rounded, semanticLabel: 'Housing'),
                      label: 'Housing',
                    ),
                    NavigationDestination(
                      icon: notesUnreadCount > 0
                        ? Badge(
                            label: Text(notesUnreadCount > 9 ? '9+' : '$notesUnreadCount'),
                            child: const Icon(Icons.menu_book_outlined, semanticLabel: 'Study Notes'),
                          )
                        : const Icon(Icons.menu_book_outlined, semanticLabel: 'Study Notes'),
                      selectedIcon: notesUnreadCount > 0
                        ? Badge(
                            label: Text(notesUnreadCount > 9 ? '9+' : '$notesUnreadCount'),
                            child: const Icon(Icons.menu_book_rounded, semanticLabel: 'Study Notes'),
                          )
                        : const Icon(Icons.menu_book_rounded, semanticLabel: 'Study Notes'),
                      label: 'Notes',
                    ),
                    NavigationDestination(
                      icon: chatUnreadCount > 0
                        ? Badge(
                            label: Text(chatUnreadCount > 9 ? '9+' : '$chatUnreadCount'),
                            child: const Icon(Icons.chat_bubble_outline_rounded, semanticLabel: 'Messages'),
                          )
                        : const Icon(Icons.chat_bubble_outline_rounded, semanticLabel: 'Messages'),
                      selectedIcon: chatUnreadCount > 0
                        ? Badge(
                            label: Text(chatUnreadCount > 9 ? '9+' : '$chatUnreadCount'),
                            child: const Icon(Icons.chat_bubble_rounded, semanticLabel: 'Messages'),
                          )
                        : const Icon(Icons.chat_bubble_rounded, semanticLabel: 'Messages'),
                      label: 'Chat',
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Consumer(
          builder: (context, ref, child) {
            final authControllerState = ref.watch(authControllerProvider);
            if (authControllerState.isLoading) {
              return Container(
                color: Colors.black45,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildVerificationBanner(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer,
      child: InkWell(
        onTap: () => context.push('/verify-email'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Icon(Icons.mark_email_unread_rounded, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Email Not Verified',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'Verify to enable posting and chatting.',
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: theme.colorScheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
