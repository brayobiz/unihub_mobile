import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/auth/presentation/screens/complete_profile_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/auth/shared/providers.dart';
import '../../features/navigation/main_navigation_screen.dart';

import '../../features/marketplace/presentation/screens/add_listing_screen.dart';
import '../../features/marketplace/presentation/screens/listing_detail_screen.dart';
import '../../features/marketplace/presentation/screens/my_listings_screen.dart';
import '../../features/marketplace/presentation/screens/seller_dashboard_screen.dart';
import '../../features/marketplace/presentation/screens/seller_profile_screen.dart';
import '../../features/marketplace/domain/models/listing.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/chat/presentation/screens/conversations_list_screen.dart';
import '../../features/chat/domain/models/chat_context.dart';
import '../../features/housing/presentation/screens/add_housing_screen.dart';
import '../../features/housing/presentation/screens/housing_details_screen.dart';
import '../../features/housing/presentation/screens/housing_screen.dart';
import '../../features/housing/presentation/screens/add_roommate_screen.dart';
import '../../features/housing/presentation/screens/plug_dashboard_screen.dart';
import '../../features/housing/presentation/screens/plug_profile_screen.dart';
import '../../features/housing/presentation/screens/saved_housing_screen.dart';
import '../../features/housing/presentation/screens/become_plug_screen.dart';
import '../../features/housing/presentation/screens/submit_vacancy_screen.dart';
import '../../features/housing/presentation/screens/opportunity_feed_screen.dart';
import '../../features/housing/domain/models/housing_listing.dart';
import '../../features/housing/domain/models/vacancy_request.dart';
import '../../features/notes/presentation/screens/add_note_screen.dart';
import '../../features/notes/presentation/screens/note_detail_screen.dart';
import '../../features/notes/presentation/screens/note_reader_screen.dart';
import '../../features/notes/domain/models/note.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/profile/settings_screen.dart';
import '../../features/profile/activity_history_screen.dart';
import '../../features/profile/achievements_screen.dart';
import '../../features/marketplace/presentation/screens/saved_listings_screen.dart';
import '../../features/marketplace/presentation/screens/saved_searches_screen.dart';
import '../../features/marketplace/presentation/screens/category_discovery_screen.dart';
import '../../features/shared/help_centre_screen.dart';
import '../../features/shared/notifications_screen.dart';
import '../../features/shared/feed_item_detail_screen.dart';
import '../../features/shared/global_search_screen.dart';
import '../../features/shared/campus_pulse_screen.dart';
import '../../features/shared/banned_screen.dart';
import '../../features/shared/maintenance_screen.dart';
import '../../features/community/community_screen.dart';
import '../../features/gigs/gigs_screen.dart';
import '../../features/confessions/confessions_screen.dart';
import '../../features/shared/feed_repository.dart';

import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/verification_queue_screen.dart';
import '../../features/admin/presentation/screens/verification_detail_screen.dart';
import '../../features/admin/presentation/screens/report_queue_screen.dart';
import '../../features/admin/presentation/screens/report_detail_screen.dart';
import '../../features/admin/presentation/screens/feature_moderation_screen.dart';
import '../../features/admin/presentation/screens/user_management_screen.dart';
import '../../features/admin/presentation/screens/user_detail_admin_screen.dart';
import '../../features/admin/presentation/screens/audit_log_screen.dart';
import '../../features/admin/presentation/screens/support_center_screen.dart';
import '../../features/admin/presentation/screens/support_conversation_admin_screen.dart';
import '../../features/admin/presentation/screens/announcement_management_screen.dart';
import '../../features/admin/presentation/screens/system_settings_screen.dart';
import '../../features/admin/shared/providers.dart';
import '../../features/admin/domain/models/verification_request.dart';
import '../../features/admin/domain/models/report.dart';
import '../../features/admin/domain/models/moderation_content.dart';
import '../../features/chat/domain/models/conversation.dart';
import '../../features/auth/domain/models/app_user.dart';

import '../../features/gigs/presentation/screens/gig_details_screen.dart';
import '../../features/gigs/presentation/screens/apply_gig_screen.dart';
import '../../features/gigs/presentation/screens/employer_dashboard_screen.dart';
import '../../features/gigs/presentation/screens/freelancer_applications_screen.dart';

import '../../features/trust/presentation/screens/trust_center_screen.dart';
import '../../features/trust/presentation/screens/student_verification_screen.dart';
import '../../features/trust/presentation/screens/identity_verification_screen.dart';
import '../../features/trust/presentation/screens/professional_verification_screen.dart';
import '../../features/trust/domain/models/professional_role.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(appUserProvider, (_, __) => notifyListeners());
    _ref.listen(systemSettingsProvider, (_, __) => notifyListeners());
    _ref.listen(deviceOnboardingCompletedProvider, (_, __) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authStateProvider);
    final appUserAsync = _ref.read(appUserProvider);
    final isDeviceOnboardingDone = _ref.read(deviceOnboardingCompletedProvider);
    final settingsAsync = _ref.read(systemSettingsProvider);

    final isSplash = state.matchedLocation == '/splash';

    if (authState.isLoading || authState.isRefreshing) {
      return isSplash ? null : '/splash';
    }

    final appUser = appUserAsync.valueOrNull;
    final isAdmin = appUser?.isAdmin ?? false;
    final settings = settingsAsync.valueOrNull;

    // Maintenance Mode Check
    if (settings?.maintenanceMode == true && !isAdmin) {
      if (state.matchedLocation != '/maintenance') return '/maintenance';
      return null;
    }

    final isLoggedIn = authState.valueOrNull != null;

    if (!isLoggedIn) {
      if (!isDeviceOnboardingDone) {
        if (state.matchedLocation != '/onboarding') return '/onboarding';
        return null;
      }

      final isAuthRoute = state.matchedLocation == '/login' || 
                         state.matchedLocation == '/register' || 
                         state.matchedLocation == '/welcome' ||
                         state.matchedLocation == '/forgot-password';

      if (isSplash || !isAuthRoute) return '/welcome';
      return null;
    }

    if (appUserAsync.isLoading || appUserAsync.isRefreshing) {
      return isSplash ? null : '/splash';
    }

    if (appUser == null) {
      if (state.matchedLocation != '/complete-profile') return '/complete-profile';
      return null;
    }

    // Restriction check
    if (appUser.isRestricted) {
      if (state.matchedLocation != '/banned') return '/banned';
      return null;
    }

    final isProfileIncomplete = appUser.university == null || appUser.course == null;
    if (isProfileIncomplete) {
      if (state.matchedLocation != '/complete-profile') return '/complete-profile';
      return null;
    }

    if (!appUser.isOnboardingCompleted) {
      if (state.matchedLocation != '/onboarding') return '/onboarding';
      return null;
    }

    final isAuthRoute = state.matchedLocation == '/login' || 
                       state.matchedLocation == '/register' || 
                       state.matchedLocation == '/welcome' ||
                       state.matchedLocation == '/complete-profile' ||
                       state.matchedLocation == '/onboarding' ||
                       isSplash;

    if (isAuthRoute) {
      return '/main';
    }

    // Admin route protection
    if (state.matchedLocation.startsWith('/admin')) {
      if (appUser == null || !appUser.isAdmin) {
        return '/main';
      }
    }

    return null;
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    debugLogDiagnostics: true,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: '/complete-profile',
        builder: (context, state) => const CompleteProfileScreen(),
      ),
      GoRoute(
        path: '/banned',
        builder: (context, state) => const BannedScreen(),
      ),
      GoRoute(
        path: '/maintenance',
        builder: (context, state) => const MaintenanceScreen(),
      ),
      GoRoute(
        path: '/global-search',
        name: 'global-search',
        builder: (context, state) => const GlobalSearchScreen(),
      ),
      GoRoute(
        path: '/campus-pulse',
        builder: (context, state) => const CampusPulseScreen(),
      ),
      GoRoute(
        path: '/main',
        builder: (context, state) => const MainNavigationScreen(),
      ),
      GoRoute(
        path: '/add-listing',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Listing) {
            return AddListingScreen(listing: extra);
          }
          if (extra is Map<String, dynamic>) {
            return AddListingScreen(listing: Listing.fromJson(extra));
          }
          return const AddListingScreen();
        },
      ),
      GoRoute(
        path: '/my-listings',
        builder: (context, state) => const MyListingsScreen(),
      ),
      GoRoute(
        path: '/seller-dashboard',
        builder: (context, state) => const SellerDashboardScreen(),
      ),
      GoRoute(
        path: '/listing-detail',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Listing) {
            return ListingDetailScreen(listing: extra);
          }
          if (extra is Map<String, dynamic>) {
            if (extra.containsKey('listing') && extra['listing'] is Listing) {
              return ListingDetailScreen(
                listing: extra['listing'] as Listing,
                heroTag: extra['heroTag'] as String?,
              );
            }
            try {
              return ListingDetailScreen(listing: Listing.fromJson(extra));
            } catch (_) {}
          }
          return const Scaffold(
            body: Center(child: Text('Invalid listing data')),
          );
        },
      ),
      GoRoute(
        path: '/seller-profile',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is String) {
            return SellerProfileScreen(userId: extra);
          }
          return const Scaffold(
            body: Center(child: Text('Invalid user profile data')),
          );
        },
      ),
      GoRoute(
        path: '/conversations',
        builder: (context, state) => const ConversationsListScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) {
          final Object? extra = state.extra;
          
          if (extra is! Map) {
            debugPrint('GoRouter: /chat route extra is not a Map: $extra');
            return const Scaffold(
              body: Center(child: Text('Invalid chat navigation data')),
            );
          }
          
          final extras = extra;
          final dynamic chatContextData = extras['context'];
          
          ChatContext? chatContext;
          try {
            if (chatContextData is ChatContext) {
              chatContext = chatContextData;
            } else if (chatContextData is Map) {
              chatContext = ChatContext.fromJson(Map<String, dynamic>.from(chatContextData));
            }
          } catch (e) {
            debugPrint('GoRouter: Error parsing ChatContext in /chat route: $e');
          }

          final String convId = (extras['conversationId'] ?? '').toString();
          final String otherName = (extras['otherUserName'] ?? 'Chat').toString();

          if (convId.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('Conversation ID missing')),
            );
          }

          return ChatScreen(
            conversationId: convId,
            otherUserName: otherName,
            chatContext: chatContext,
          );
        },
      ),
      GoRoute(
        path: '/add-housing',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is HousingListing) {
            return AddHousingScreen(listing: extra);
          } else if (extra is VacancyRequest) {
            return AddHousingScreen(opportunity: extra);
          }
          return const AddHousingScreen();
        },
      ),
      GoRoute(
        path: '/housing',
        builder: (context, state) => const HousingScreen(),
      ),
      GoRoute(
        path: '/housing-detail',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is HousingListing) {
            return HousingDetailsScreen(listing: extra);
          }
          return const Scaffold(
            body: Center(child: Text('Invalid housing data')),
          );
        },
      ),
      GoRoute(
        path: '/plug-dashboard',
        builder: (context, state) => const PlugDashboardScreen(),
      ),
      GoRoute(
        path: '/plug-profile/:plugId',
        builder: (context, state) {
          final plugId = state.pathParameters['plugId']!;
          return PlugProfileScreen(plugId: plugId);
        },
      ),
      GoRoute(
        path: '/become-plug',
        builder: (context, state) => const BecomePlugScreen(),
      ),
      GoRoute(
        path: '/submit-vacancy',
        builder: (context, state) => const SubmitVacancyScreen(),
      ),
      GoRoute(
        path: '/opportunities',
        builder: (context, state) => const OpportunityFeedScreen(),
      ),
      GoRoute(
        path: '/saved-housing',
        builder: (context, state) => const SavedHousingScreen(),
      ),
      GoRoute(
        path: '/add-roommate',
        builder: (context, state) => const AddRoommateScreen(),
      ),
      GoRoute(
        path: '/add-note',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is NoteListing) {
            return AddNoteScreen(note: extra);
          }
          if (extra is Map<String, dynamic>) {
            return AddNoteScreen(note: NoteListing.fromJson(extra));
          }
          return const AddNoteScreen();
        },
      ),
      GoRoute(
        path: '/note-detail',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is NoteListing) {
            return NoteDetailScreen(note: extra);
          }
          if (extra is Map<String, dynamic>) {
            return NoteDetailScreen(note: NoteListing.fromJson(extra));
          }
          return const Scaffold(
            body: Center(child: Text('Invalid note data')),
          );
        },
      ),
      GoRoute(
        path: '/note-reader',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! Map) {
            return const Scaffold(body: Center(child: Text('Invalid data passed to reader')));
          }
          final noteData = extra['note'];
          NoteListing? note;
          if (noteData is NoteListing) {
            note = noteData;
          } else if (noteData is Map<String, dynamic>) {
            note = NoteListing.fromJson(noteData);
          }

          if (note == null) {
            return const Scaffold(body: Center(child: Text('Note data missing')));
          }
          return NoteReaderScreen(
            note: note,
            filePath: extra['filePath'] as String?,
            initialPage: extra['initialPage'] as int? ?? 0,
          );
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/activity-history',
        builder: (context, state) => const ActivityHistoryScreen(),
      ),
      GoRoute(
        path: '/achievements',
        builder: (context, state) => const AchievementsScreen(),
      ),
      GoRoute(
        path: '/saved',
        builder: (context, state) => const SavedListingsScreen(),
      ),
      GoRoute(
        path: '/saved-searches',
        builder: (context, state) => const SavedSearchesScreen(),
      ),
      GoRoute(
        path: '/category-discovery/:category',
        builder: (context, state) {
          final category = state.pathParameters['category']!;
          return CategoryDiscoveryScreen(category: category);
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) {
          final module = state.extra as String?;
          return NotificationsScreen(module: module);
        },
      ),
      GoRoute(
        path: '/help',
        builder: (context, state) => const HelpCentreScreen(),
      ),
      GoRoute(
        path: '/feed-detail',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is FeedItem) {
            return FeedItemDetailScreen(item: extra);
          }
          if (extra is Map<String, dynamic>) {
            return FeedItemDetailScreen(item: FeedItem.fromJson(extra));
          }
          return const Scaffold(
            body: Center(child: Text('Invalid feed item data')),
          );
        },
      ),
      GoRoute(
        path: '/community',
        builder: (context, state) => const CommunityScreen(),
      ),
      GoRoute(
        path: '/gigs',
        builder: (context, state) => const GigsScreen(),
      ),
      GoRoute(
        path: '/confessions',
        builder: (context, state) => const ConfessionsScreen(),
      ),
      GoRoute(
        path: '/gig-detail',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is FeedItem) {
            return GigDetailsScreen(gig: extra);
          }
          if (extra is Map<String, dynamic>) {
            return GigDetailsScreen(gig: FeedItem.fromJson(extra));
          }
          return const Scaffold(
            body: Center(child: Text('Invalid gig data')),
          );
        },
      ),
      GoRoute(
        path: '/apply-gig',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is FeedItem) {
            return ApplyGigScreen(gig: extra);
          }
          if (extra is Map<String, dynamic>) {
            return ApplyGigScreen(gig: FeedItem.fromJson(extra));
          }
          return const Scaffold(
            body: Center(child: Text('Invalid gig data')),
          );
        },
      ),
      GoRoute(
        path: '/employer-dashboard',
        builder: (context, state) => const EmployerDashboardScreen(),
      ),
      GoRoute(
        path: '/my-gig-applications',
        builder: (context, state) => const FreelancerApplicationsScreen(),
      ),
      GoRoute(
        path: '/trust-center',
        builder: (context, state) => const TrustCenterScreen(),
      ),
      GoRoute(
        path: '/verify-student',
        builder: (context, state) => const StudentVerificationScreen(),
      ),
      GoRoute(
        path: '/verify-identity',
        builder: (context, state) => const IdentityVerificationScreen(),
      ),
      GoRoute(
        path: '/verify-professional/:role',
        builder: (context, state) {
          final roleName = state.pathParameters['role']!;
          final role = ProfessionalRole.values.firstWhere(
            (e) => e.name == roleName,
            orElse: () => ProfessionalRole.seller,
          );
          return ProfessionalVerificationScreen(role: role);
        },
      ),
      // Admin Routes
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/verifications',
        builder: (context, state) => const VerificationQueueScreen(),
      ),
      GoRoute(
        path: '/admin/verifications/:id',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is AdminVerificationRequest) {
            return VerificationDetailScreen(request: extra);
          }
          return const Scaffold(
            body: Center(child: Text('Invalid verification data')),
          );
        },
      ),
      GoRoute(
        path: '/admin/reports',
        builder: (context, state) => const ReportQueueScreen(),
      ),
      GoRoute(
        path: '/admin/reports/:id',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is AdminReport) {
            return ReportDetailScreen(report: extra);
          }
          return const Scaffold(
            body: Center(child: Text('Invalid report data')),
          );
        },
      ),
      GoRoute(
        path: '/admin/marketplace',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return FeatureModerationScreen(
            contentType: ContentType.marketplace,
            initialUserId: extra?['userId'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/admin/housing',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return FeatureModerationScreen(
            contentType: ContentType.housing,
            initialUserId: extra?['userId'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/admin/notes',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return FeatureModerationScreen(
            contentType: ContentType.notes,
            initialUserId: extra?['userId'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const UserManagementScreen(),
      ),
      GoRoute(
        path: '/admin/audit-logs',
        builder: (context, state) => const AuditLogScreen(),
      ),
      GoRoute(
        path: '/admin/announcements',
        builder: (context, state) => const AnnouncementManagementScreen(),
      ),
      GoRoute(
        path: '/admin/settings',
        builder: (context, state) => const SystemSettingsScreen(),
      ),
      GoRoute(
        path: '/admin/support',
        builder: (context, state) => const SupportCenterScreen(),
      ),
      GoRoute(
        path: '/admin/support/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra;
          return SupportConversationAdminScreen(
            conversationId: id,
            initialConversation: extra is Conversation ? extra : null,
          );
        },
      ),
      GoRoute(
        path: '/admin/users/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra;
          return UserDetailAdminScreen(
            userId: id,
            initialUser: extra is AppUser ? extra : null,
          );
        },
      ),
    ],
  );
});
