import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unihub_mobile/core/utils/app_logger.dart';
import '../data/repositories/auth_repository_impl.dart';
import 'package:unihub_mobile/features/auth/domain/models/app_user.dart';
import '../domain/repositories/auth_repository.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseMessagingProvider = Provider<FirebaseMessaging>((ref) {
  return FirebaseMessaging.instance;
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize SharedPreferences in main.dart');
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  );
});

final authStateProvider = StreamProvider<User?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.userChanges.map((user) {
    // Audit Phase 3.1: If user exists but document doesn't, this might be handled by Router
    return user;
  }).handleError((error) {
    AppLogger.error('Auth State Error', error, null, 'AUTH');
    if (error is FirebaseAuthException) {
       // Force sign-out on critical auth errors
       if (error.code == 'user-disabled' || error.code == 'user-not-found') {
          repo.signOut();
       }
    }
  });
});

final appUserProvider = StreamProvider<AppUser?>((ref) {
  // Audit Phase 3.5: Optimize to only re-subscribe when UID changes.
  // Using .select prevents stream reconstruction on minor user property changes.
  final uid = ref.watch(authStateProvider.select((user) => user.valueOrNull?.uid));
  
  if (uid == null) return Stream.value(null);
  
  return ref.watch(authRepositoryProvider).watchUser(uid).map((user) {
    return user;
  });
});

final userByIdProvider = StreamProvider.autoDispose.family<AppUser?, String>((ref, uid) {
  return ref.watch(authRepositoryProvider).watchUser(uid);
});

/// A secure provider for fetching other users' profiles.
/// Audit Phase 3.5: Added cache duration to reduce Firestore reads on navigation.
final publicUserProvider = StreamProvider.autoDispose.family<AppUser, String>((ref, userId) {
  if (userId.isEmpty) return Stream.error('Invalid User ID');
  
  // keep profile in memory for 2 minutes after last usage
  final link = ref.keepAlive();
  Timer? timer;
  ref.onDispose(() => timer?.cancel());
  ref.onCancel(() {
    timer = Timer(const Duration(minutes: 2), () {
      link.close();
    });
  });
  ref.onResume(() => timer?.cancel());

  final currentUser = ref.watch(appUserProvider).valueOrNull;
  final authRepo = ref.watch(authRepositoryProvider);

  return authRepo.watchUser(userId).map((targetUser) {
    if (targetUser == null) throw Exception('User not found');
    
    final bool isOwner = currentUser?.uid == targetUser.uid;
    
    // Privacy Logic
    final visibility = targetUser.privacySettings['profile_visibility'] ?? 'university';
    final showUni = targetUser.privacySettings['show_university'] != 'private';
    final showSocials = targetUser.privacySettings['show_socials'] != 'private';

    final String? currentUni = currentUser?.university;
    final String? targetUni = targetUser.university;

    final bool isSameUni = currentUni != null && 
                           targetUni != null && 
                           currentUni.isNotEmpty &&
                           targetUni.isNotEmpty &&
                           currentUni == targetUni;

    final bool canViewDetails = visibility == 'public' || (visibility == 'university' && isSameUni) || isOwner;
    
    if (visibility == 'private' && !isOwner) {
      return targetUser.stripSensitiveInfo().copyWith(
        university: 'Private Profile',
        course: 'Student',
      );
    }

    if (!canViewDetails) {
       return targetUser.stripSensitiveInfo().copyWith(
         bio: 'This profile is set to University-only visibility.',
         course: 'Student',
         university: showUni ? targetUni : 'Hidden Campus',
       );
    }

    // Apply secondary flags and strip PII
    return targetUser.stripSensitiveInfo().copyWith(
      university: (showUni || isSameUni || isOwner) ? targetUni : 'Hidden Campus',
      socialLinks: (showSocials || isSameUni || isOwner)
          ? targetUser.socialLinks
          : const <String, String>{},
      // Only the owner sees their own private contact info through this provider
      email: isOwner ? targetUser.email : 'hidden@ulify.student',
      phoneNumber: isOwner ? targetUser.phoneNumber : null,
      whatsappNumber: isOwner ? targetUser.whatsappNumber : null,
    );
  });
});

// To track if account was just deleted to show farewell screen
final accountDeletedProvider = StateProvider<bool>((ref) => false);

// To track if the device has seen the initial introduction
final deviceOnboardingCompletedProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool('device_onboarding_completed') ?? false;
});
