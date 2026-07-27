import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/auth/presentation/screens/complete_profile_screen.dart';
import '../../features/auth/presentation/screens/account_deleted_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/auth/shared/providers.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../providers/app_restart_provider.dart';
import '../../features/navigation/main_navigation_screen.dart';

import '../../features/marketplace/presentation/screens/add_listing_screen.dart';
import '../../features/marketplace/presentation/screens/listing_detail_screen.dart';
import '../../features/marketplace/presentation/screens/my_listings_screen.dart';
import '../../features/marketplace/presentation/screens/seller_offers_screen.dart';
import '../../features/marketplace/presentation/screens/seller_dashboard_screen.dart';
import '../../features/marketplace/presentation/screens/seller_profile_screen.dart';
import '../../features/marketplace/domain/models/listing.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/chat/presentation/screens/conversations_list_screen.dart';
import '../../features/chat/presentation/screens/user_search_screen.dart';
import '../../features/chat/domain/models/chat_context.dart';
import '../../features/housing/presentation/screens/housing_comparison_screen.dart';
import '../../features/housing/presentation/screens/roommate_feed_screen.dart';
import '../../features/housing/presentation/screens/add_housing_screen.dart';
import '../../features/housing/presentation/screens/housing_details_screen.dart';
import '../../features/housing/presentation/screens/housing_video_screen.dart';
import '../../features/housing/presentation/screens/housing_screen.dart';
import '../../features/housing/presentation/screens/add_roommate_screen.dart';
import '../../features/housing/presentation/screens/plug_dashboard_screen.dart';
import '../../features/housing/presentation/screens/plug_profile_screen.dart';
import '../../features/housing/presentation/screens/saved_housing_screen.dart';
import '../../features/housing/presentation/screens/become_plug_screen.dart';
import '../../features/housing/presentation/screens/submit_vacancy_screen.dart';
import '../../features/housing/presentation/screens/opportunity_feed_screen.dart';
import '../../features/housing/presentation/screens/viewing_requests_screen.dart';
import '../../features/housing/domain/models/housing_listing.dart';
import '../../features/housing/domain/models/vacancy_request.dart';
import '../../features/notes/presentation/screens/add_note_screen.dart';
import '../../features/notes/presentation/screens/note_detail_screen.dart';
import '../../features/notes/presentation/screens/note_reader_screen.dart';
import '../../features/notes/notes_screen.dart';
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
import '../../features/shared/connection_error_screen.dart';
import '../../features/community/community_screen.dart';
import '../../features/gigs/gigs_screen.dart';
import '../../features/confessions/confessions_screen.dart';
import '../../features/campus_maps/presentation/screens/campus_maps_screen.dart';
import '../../features/shared/feed_repository.dart';

import '../../features/shared/add_feed_item_screen.dart';
import '../../features/shared/about_screen.dart';
import '../../models/feed_type.dart';

import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/admin_analytics_screen.dart';
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
import '../../features/admin/presentation/screens/event_approval_screen.dart';
import '../../features/admin/presentation/screens/system_settings_screen.dart';
import '../../features/admin/shared/providers.dart';
import '../../features/admin/domain/models/verification_request.dart';
import '../../features/admin/domain/models/report.dart';
import '../../features/admin/domain/models/moderation_content.dart';
import '../../features/chat/domain/models/conversation.dart';
import '../../features/chat/presentation/screens/share_to_chat_screen.dart';
import '../../features/auth/domain/models/app_user.dart';

import '../../features/monetization/presentation/screens/business_upgrade_screen.dart';
import '../../features/gigs/presentation/screens/gig_details_screen.dart';
import '../../features/gigs/presentation/screens/apply_gig_screen.dart';
import '../../features/gigs/presentation/screens/employer_dashboard_screen.dart';
import '../../features/gigs/presentation/screens/freelancer_applications_screen.dart';

import '../../features/trust/presentation/screens/trust_center_screen.dart';
import '../../features/trust/presentation/screens/student_verification_screen.dart';
import '../../features/trust/presentation/screens/identity_verification_screen.dart';
import '../../features/trust/presentation/screens/professional_verification_screen.dart';
import '../../features/trust/domain/models/professional_role.dart';

import '../../features/events/presentation/screens/events_browse_screen.dart';
import '../../features/events/presentation/screens/event_detail_screen.dart';
import '../../features/events/presentation/screens/organizer_profile_screen.dart';
import '../../features/events/presentation/screens/organizer_dashboard_screen.dart';
import '../../features/events/presentation/screens/create_organizer_screen.dart';
import '../../features/events/domain/models/organizer.dart';
import '../../features/events/domain/models/event.dart';

import '../../features/events/presentation/screens/manage_events_screen.dart';
import '../../features/events/presentation/screens/create_event_screen.dart';
import '../../features/events/presentation/screens/organizer_onboarding_screen.dart';

import '../../features/events/presentation/screens/my_events_screen.dart';
import '../../features/events/presentation/screens/events_list_screen.dart';

import '../../features/events/presentation/screens/event_attendees_screen.dart';

/// ULIFY AUTHENTICATION AUDIT - Phase 1.2 (Centralize Authentication Routing)
/// Refactored to ensure the RouterNotifier (acting as the brain of the Splash process)
/// is the Single Source of Truth for all authentication-based routing decisions.
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  bool _isDisposed = false;
  
  // Track entry to stabilize transitions
  DateTime? _splashEntryTime;

  RouterNotifier(this._ref) {
    // 1. Listen to Auth State (Session Restoration)
    _ref.listen(authStateProvider, (_, __) => _safeNotify());

    // 2. Listen to App User (Profile Data)
    // Audit Phase 4.10: Optimized selection to prevent redundant redirects on presence updates.
    // Presence updates (isOnline, lastSeen) change often but shouldn't trigger routing logic.
    _ref.listen(
      appUserProvider.select((asyncUser) {
        final user = asyncUser.valueOrNull;
        if (user == null) return null;
        return (
          uid: user.uid,
          university: user.university,
          course: user.course,
          isBanned: user.isBanned,
          suspendedUntil: user.suspendedUntil,
          isOnboardingCompleted: user.isOnboardingCompleted,
          isAdmin: user.isAdmin,
          isDeleted: user.isDeleted,
          fullName: user.fullName, // Included for profile incomplete check
          createdAt: user.createdAt, // Included for onboarding guard
        );
      }),
      (_, __) => _safeNotify(),
    );

    // 3. Listen to System/Security States
    _ref.listen(systemSettingsProvider, (_, __) => _safeNotify());
    _ref.listen(deviceOnboardingCompletedProvider, (_, __) => _safeNotify());
    _ref.listen(accountDeletedProvider, (_, __) => _safeNotify());
    _ref.listen(authControllerProvider, (_, __) => _safeNotify());
    _ref.listen(appRestartProvider, (_, __) => _safeNotify());
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  /// THE CENTRAL SOURCE OF TRUTH FOR ROUTING
  /// This implements the Startup sequence: Auth -> Profile -> Guard -> Destination
  /// 
  /// AUDIT Phase 1.3 Polish:
  /// - Eliminated redundant redirects.
  /// - Ensured single navigation event per state change.
  /// - Optimized transition stabilizer for "instant" feel.
  String? redirect(BuildContext context, GoRouterState state) {
    // Audit Phase 3.5: Use local caching for redirect state to avoid repeated provider reads
    final authState = _ref.read(authStateProvider);
    final appUserAsync = _ref.read(appUserProvider);
    final isDeviceOnboardingDone = _ref.read(deviceOnboardingCompletedProvider);
    final settingsAsync = _ref.read(systemSettingsProvider);
    final isAccountDeleted = _ref.read(accountDeletedProvider);

    final String matchedLocation = state.matchedLocation;
    final bool isSplash = matchedLocation == '/splash';
    
    // Stabilize Splash visibility
    if (isSplash && _splashEntryTime == null) {
      _splashEntryTime = DateTime.now();
    } else if (!isSplash) {
      _splashEntryTime = null;
    }

    final firebaseUser = authState.valueOrNull;
    final appUser = appUserAsync.valueOrNull;
    final isDeleted = appUser?.isDeleted ?? false;

    // A. PRIORITY 1: GLOBAL INTERRUPTS (Deletion/Banned)
    if (isAccountDeleted || isDeleted) {
      if (matchedLocation != '/account-deleted') return '/account-deleted';
      return null;
    }

    // B. PRIORITY 2: AUTHENTICATION STATE
    if (authState.hasError) {
       return isSplash ? '/welcome' : null;
    }

    if ((authState.isLoading || authState.isRefreshing) && !authState.hasValue) {
      return isSplash ? null : '/splash';
    }

    final isLoggedIn = firebaseUser != null;

    // C. PATHWAY: UNAUTHENTICATED
    if (!isLoggedIn) {
      _splashEntryTime = null;

      if (!isDeviceOnboardingDone) {
        if (matchedLocation != '/onboarding') return '/onboarding';
        return null;
      }

      final bool isPublicAuthRoute = 
          matchedLocation == '/login' ||
          matchedLocation == '/register' ||
          matchedLocation == '/welcome' ||
          matchedLocation == '/forgot-password' ||
          matchedLocation == '/account-deleted';

      if (isSplash || !isPublicAuthRoute) return '/welcome';
      return null;
    }

    // D. PATHWAY: AUTHENTICATED
    // 1. Transition Stabilizer
    final bool isProfileMissing = appUser == null;
    final bool isProfileFetching = appUserAsync.isLoading || appUserAsync.isRefreshing;
    
    if (isLoggedIn) {
      final isAuthRoute = matchedLocation == '/login' || matchedLocation == '/register' || matchedLocation == '/welcome';
      if (isAuthRoute && isProfileMissing) {
        return '/splash';
      }

      if (isSplash) {
        final elapsed = _splashEntryTime != null ? DateTime.now().difference(_splashEntryTime!).inMilliseconds : 0;
        if (isProfileFetching || isProfileMissing || elapsed < 300) {
          if (!isProfileFetching && !isProfileMissing && elapsed < 300) {
            Future.delayed(Duration(milliseconds: 305 - elapsed), () => _safeNotify());
          }
          return null;
        }
      }
    }

    // 2. Error Recovery
    if (appUserAsync.hasError) {
      if (matchedLocation != '/connection-error') return '/connection-error';
      return null;
    }

    // 3. System Constraints
    final isAdmin = appUser?.isAdmin ?? false;
    if (settingsAsync.valueOrNull?.maintenanceMode == true && !isAdmin) {
      if (matchedLocation != '/maintenance') return '/maintenance';
      return null;
    }

    // 4. Restriction Check
    if (appUser?.isRestricted == true) {
      if (matchedLocation != '/banned') return '/banned';
      return null;
    }

    // 5. Mandatory Profile Setup Guard
    final name = appUser?.fullName.trim().toLowerCase() ?? '';
    final bool isProfileIncomplete = appUser == null ||
        appUser.university == null || 
        appUser.course == null || 
        name == 'ulify user' || name == 'ulifyuser' || 
        name == 'unihub user' || name == 'unihubuser' ||
        name == 'a student' ||
        appUser.fullName.length < 3;

    if (isProfileIncomplete) {
      if (isProfileFetching) return isSplash ? null : '/splash';
      if (matchedLocation != '/complete-profile') return '/complete-profile';
      return null;
    }

    // 6. User Onboarding Guard
    final bool isReturningUser = appUser.createdAt == null || 
        DateTime.now().difference(appUser.createdAt!).inMinutes > 2;

    if (!appUser.isOnboardingCompleted && !isReturningUser) {
      if (matchedLocation != '/onboarding') return '/onboarding';
      return null;
    }

    // 7. FINAL DESTINATION
    final isAuthRoute = matchedLocation == '/login' || matchedLocation == '/register' || matchedLocation == '/welcome' || matchedLocation == '/complete-profile' || matchedLocation == '/onboarding' || isSplash;
    if (isAuthRoute) return '/main';

    if (matchedLocation.startsWith('/admin') && !isAdmin) return '/main';

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
    debugLogDiagnostics: kDebugMode,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SplashScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) => 
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const OnboardingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) => 
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: '/welcome',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const WelcomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) => 
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: '/login', 
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) => 
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const RegisterScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) => 
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ForgotPasswordScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) => 
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: '/verify-email',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const VerifyEmailScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) => 
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: '/complete-profile',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const CompleteProfileScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) => 
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: '/account-deleted',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const AccountDeletedScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) => 
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: '/banned',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const BannedScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) => 
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: '/maintenance',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const MaintenanceScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) => 
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: '/connection-error',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ConnectionErrorScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) => 
              FadeTransition(opacity: animation, child: child),
        ),
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
        path: '/campus-map',
        builder: (context, state) {
          final eventId = state.uri.queryParameters['eventId'];
          return CampusMapsScreen(initialEventId: eventId);
        },
      ),
      GoRoute(
        path: '/main',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const MainNavigationScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) => 
              FadeTransition(opacity: animation, child: child),
        ),
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
        path: '/seller-offers',
        builder: (context, state) => const SellerOffersScreen(),
      ),
      GoRoute(
        path: '/seller-dashboard',
        builder: (context, state) => const SellerDashboardScreen(),
      ),
      GoRoute(
        path: '/listing-detail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra;

          if (extra is Listing) {
            return ListingDetailScreen(listing: extra, listingId: id);
          }

          if (extra is Map<String, dynamic>) {
            if (extra.containsKey('listing') && extra['listing'] is Listing) {
              return ListingDetailScreen(
                listing: extra['listing'] as Listing,
                listingId: id,
                heroTag: extra['heroTag'] as String?,
              );
            }
            try {
              return ListingDetailScreen(
                listing: Listing.fromJson(extra),
                listingId: id,
              );
            } catch (_) {}
          }

          return ListingDetailScreen(listingId: id);
        },
      ),
      GoRoute(
        path: '/seller-profile/:userId',
        builder: (context, state) {
          final id = state.pathParameters['userId']!;
          return SellerProfileScreen(userId: id);
        },
      ),
      GoRoute(
        path: '/conversations',
        builder: (context, state) => const ConversationsListScreen(),
      ),
      GoRoute(
        path: '/user-search',
        builder: (context, state) => const UserSearchScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) {
          final Object? extra = state.extra;

          if (extra is! Map) {
            if (kDebugMode) {
              debugPrint('GoRouter: /chat route extra is not a Map');
            }
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
              chatContext = ChatContext.fromJson(
                Map<String, dynamic>.from(chatContextData),
              );
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('GoRouter: Error parsing ChatContext in /chat route');
            }
          }

          final String convId = (extras['conversationId'] ?? '').toString();
          final String otherName = (extras['otherUserName'] ?? 'Chat')
              .toString();

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
        path: '/share-to-chat',
        builder: (context, state) {
          final shareContext = state.extra as ChatContext;
          return ShareToChatScreen(shareContext: shareContext);
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
        path: '/housing-detail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra;

          if (extra is HousingListing) {
            return HousingDetailsScreen(listing: extra, listingId: id);
          }

          return HousingDetailsScreen(listingId: id);
        },
      ),
      GoRoute(
        path: '/housing-video',
        builder: (context, state) {
          final videoUrl = state.extra as String;
          return HousingVideoScreen(videoUrl: videoUrl);
        },
      ),
      GoRoute(
        path: '/housing-comparison',
        builder: (context, state) => const HousingComparisonScreen(),
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
        path: '/viewing-requests',
        builder: (context, state) => const ViewingRequestsScreen(),
      ),
      GoRoute(
        path: '/opportunities',
        builder: (context, state) => const OpportunityFeedScreen(),
      ),
      GoRoute(
        path: '/notes',
        builder: (context, state) {
          final tab =
              int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
          return NotesScreen(initialTabIndex: tab);
        },
      ),
      GoRoute(
        path: '/saved-housing',
        builder: (context, state) => const SavedHousingScreen(),
      ),
      GoRoute(
        path: '/roommates',
        builder: (context, state) => const RoommateFeedScreen(),
      ),
      GoRoute(
        path: '/add-roommate',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is HousingListing) {
            return AddRoommateScreen(targetListing: extra);
          }
          return const AddRoommateScreen();
        },
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
        path: '/note-detail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra;

          if (extra is NoteListing) {
            return NoteDetailScreen(note: extra, noteId: id);
          }

          if (extra is Map<String, dynamic>) {
            try {
              return NoteDetailScreen(
                note: NoteListing.fromJson(extra),
                noteId: id,
              );
            } catch (_) {}
          }

          return NoteDetailScreen(noteId: id);
        },
      ),
      GoRoute(
        path: '/note-reader',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! Map) {
            return const Scaffold(
              body: Center(child: Text('Invalid data passed to reader')),
            );
          }
          final noteData = extra['note'];
          NoteListing? note;
          if (noteData is NoteListing) {
            note = noteData;
          } else if (noteData is Map<String, dynamic>) {
            note = NoteListing.fromJson(noteData);
          }

          if (note == null) {
            return const Scaffold(
              body: Center(child: Text('Note data missing')),
            );
          }
          return NoteReaderScreen(
            note: note,
            filePath: extra['filePath'] as String?,
            initialPage: extra['initialPage'] as int? ?? 0,
          );
        },
      ),
      GoRoute(
        path: '/add-feed-item',
        builder: (context, state) {
          final type = state.extra as FeedType? ?? FeedType.community;
          return AddFeedItemScreen(type: type);
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
        path: '/business-upgrade',
        builder: (context, state) => const BusinessUpgradeScreen(),
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
      GoRoute(path: '/about', builder: (context, state) => const AboutScreen()),
      GoRoute(
        path: '/feed-detail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra;

          if (extra is FeedItem) {
            return FeedItemDetailScreen(item: extra, itemId: id);
          }
          if (extra is Map<String, dynamic>) {
            try {
              return FeedItemDetailScreen(
                item: FeedItem.fromJson(extra),
                itemId: id,
              );
            } catch (_) {}
          }

          return FeedItemDetailScreen(itemId: id);
        },
      ),
      GoRoute(
        path: '/community-detail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra;

          if (extra is FeedItem) {
            return FeedItemDetailScreen(item: extra, itemId: id);
          }
          if (extra is Map<String, dynamic>) {
            try {
              return FeedItemDetailScreen(
                item: FeedItem.fromJson(extra),
                itemId: id,
              );
            } catch (_) {}
          }

          return FeedItemDetailScreen(itemId: id);
        },
      ),
      GoRoute(
        path: '/community',
        builder: (context, state) => const CommunityScreen(),
      ),
      GoRoute(path: '/gigs', builder: (context, state) => const GigsScreen()),
      GoRoute(
        path: '/confessions',
        builder: (context, state) => const ConfessionsScreen(),
      ),
      // Events Routes
      GoRoute(
        path: '/events',
        builder: (context, state) => const EventsBrowseScreen(),
      ),
      GoRoute(
        path: '/events/list',
        builder: (context, state) {
          final title = state.uri.queryParameters['title'] ?? 'Events';
          final filterStr = state.uri.queryParameters['filter'] ?? 'today';
          final categoryId = state.uri.queryParameters['categoryId'];

          final filter = EventListFilter.values.firstWhere(
            (e) => e.name == filterStr,
            orElse: () => EventListFilter.today,
          );

          return EventsListScreen(
            title: title,
            filter: filter,
            categoryId: categoryId,
          );
        },
      ),
      GoRoute(
        path: '/events/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return EventDetailScreen(eventId: id);
        },
      ),
      GoRoute(
        path: '/my-events',
        builder: (context, state) => const MyEventsScreen(),
      ),
      GoRoute(
        path: '/organizers/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return OrganizerProfileScreen(organizerId: id);
        },
      ),
      GoRoute(
        path: '/organizers/:id/dashboard',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return OrganizerDashboardScreen(organizerId: id);
        },
      ),
      GoRoute(
        path: '/organizers/:id/events',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ManageEventsScreen(organizerId: id);
        },
      ),
      GoRoute(
        path: '/organizers/:id/events/create',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra as Map<String, dynamic>?;
          return CreateEventScreen(
            organizerId: id,
            campusId: extra?['campusId'] ?? 'uon_main',
            event: extra?['duplicateEvent'] as Event?,
            isDuplicating: extra?['duplicateEvent'] != null,
          );
        },
      ),
      GoRoute(
        path: '/organizers/:id/events/edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final event = state.extra as Event;
          return CreateEventScreen(
            organizerId: id,
            campusId: event.campusId,
            event: event,
          );
        },
      ),
      GoRoute(
        path: '/events/:id/attendees',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return EventAttendeesScreen(eventId: id);
        },
      ),
      GoRoute(
        path: '/organizers/:id/edit',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Organizer) {
            return CreateOrganizerScreen(organizer: extra);
          }
          return const CreateOrganizerScreen();
        },
      ),
      GoRoute(
        path: '/organizer-onboarding',
        name: 'organizer-onboarding',
        builder: (context, state) => const OrganizerOnboardingScreen(),
      ),
      GoRoute(
        path: '/become-organizer',
        name: 'become-organizer',
        builder: (context, state) {
          final organizer = state.extra as Organizer?;
          return CreateOrganizerScreen(organizer: organizer);
        },
      ),
      GoRoute(
        path: '/gig-detail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra;

          if (extra is FeedItem) {
            return GigDetailsScreen(gig: extra, gigId: id);
          }
          if (extra is Map<String, dynamic>) {
            try {
              return GigDetailsScreen(gig: FeedItem.fromJson(extra), gigId: id);
            } catch (_) {}
          }

          return GigDetailsScreen(gigId: id);
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
          return const Scaffold(body: Center(child: Text('Invalid gig data')));
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
        path: '/admin/analytics',
        builder: (context, state) => const AdminAnalyticsScreen(),
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
        path: '/admin/events/approvals',
        builder: (context, state) => const EventApprovalScreen(),
      ),
      GoRoute(
        path: '/admin/events',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return FeatureModerationScreen(
            contentType: ContentType.events,
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
