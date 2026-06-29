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
import '../../features/marketplace/presentation/screens/seller_profile_screen.dart';
import '../../features/marketplace/domain/models/listing.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
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
import '../../features/shared/help_centre_screen.dart';
import '../../features/shared/notifications_screen.dart';
import '../../features/shared/feed_item_detail_screen.dart';
import '../../features/shared/global_search_screen.dart';
import '../../features/shared/campus_pulse_screen.dart';
import '../../features/community/community_screen.dart';
import '../../features/gigs/gigs_screen.dart';
import '../../features/confessions/confessions_screen.dart';
import '../../features/shared/feed_repository.dart';

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
    _ref.listen(deviceOnboardingCompletedProvider, (_, __) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authStateProvider);
    final appUserAsync = _ref.read(appUserProvider);
    final isDeviceOnboardingDone = _ref.read(deviceOnboardingCompletedProvider);

    final isSplash = state.matchedLocation == '/splash';

    if (authState.isLoading || authState.isRefreshing) {
      return isSplash ? null : '/splash';
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

    final appUser = appUserAsync.valueOrNull;
    
    if (appUser == null) {
      if (state.matchedLocation != '/complete-profile') return '/complete-profile';
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
          final listing = state.extra as Listing?;
          return AddListingScreen(listing: listing);
        },
      ),
      GoRoute(
        path: '/my-listings',
        builder: (context, state) => const MyListingsScreen(),
      ),
      GoRoute(
        path: '/listing-detail',
        builder: (context, state) {
          final listing = state.extra as Listing;
          return ListingDetailScreen(listing: listing);
        },
      ),
      GoRoute(
        path: '/seller-profile',
        builder: (context, state) {
          final userId = state.extra as String;
          return SellerProfileScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) {
          final extras = state.extra as Map<String, dynamic>;
          return ChatScreen(
            conversationId: extras['conversationId'],
            otherUserName: extras['otherUserName'],
            listing: extras['listing'] as Listing?,
          );
        },
      ),
      GoRoute(
        path: '/add-housing',
        builder: (context, state) {
          if (state.extra is HousingListing) {
            return AddHousingScreen(listing: state.extra as HousingListing);
          } else if (state.extra is VacancyRequest) {
            return AddHousingScreen(opportunity: state.extra as VacancyRequest);
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
          final housing = state.extra as HousingListing;
          return HousingDetailsScreen(listing: housing);
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
          final note = state.extra as NoteListing?;
          return AddNoteScreen(note: note);
        },
      ),
      GoRoute(
        path: '/note-detail',
        builder: (context, state) {
          final note = state.extra as NoteListing;
          return NoteDetailScreen(note: note);
        },
      ),
      GoRoute(
        path: '/note-reader',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! Map) {
            return const Scaffold(body: Center(child: Text('Invalid data passed to reader')));
          }
          final note = extra['note'] as NoteListing?;
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
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/help',
        builder: (context, state) => const HelpCentreScreen(),
      ),
      GoRoute(
        path: '/feed-detail',
        builder: (context, state) {
          final item = state.extra as FeedItem;
          return FeedItemDetailScreen(item: item);
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
          final gig = state.extra as FeedItem;
          return GigDetailsScreen(gig: gig);
        },
      ),
      GoRoute(
        path: '/apply-gig',
        builder: (context, state) {
          final gig = state.extra as FeedItem;
          return ApplyGigScreen(gig: gig);
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
    ],
  );
});
