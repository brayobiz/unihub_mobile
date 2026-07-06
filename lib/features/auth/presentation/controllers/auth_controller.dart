import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../services/notification_service.dart';
import '../../../../core/utils/app_logger.dart';

import '../../../../core/constants/campus_constants.dart';

class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _authRepository;
  final Ref _ref;

  AuthController({required AuthRepository authRepository, required Ref ref})
      : _authRepository = authRepository,
        _ref = ref,
        super(const AsyncValue.data(null));

  void resetState() {
    state = const AsyncValue.data(null);
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authRepository.signInWithEmailAndPassword(email, password);
      await _ref.read(notificationServiceProvider).init(); // Refresh token/permission
    });
    if (!state.hasError) {
      resetState();
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authRepository.signInWithGoogle();
      await _ref.read(notificationServiceProvider).init(); // Refresh token/permission
    });
    if (!state.hasError) {
      resetState();
    }
  }

  Future<void> signUp({
    required String email, 
    required String password, 
    required String fullName,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authRepository.signUpWithEmailAndPassword(
        email: email,
        password: password,
        fullName: fullName,
      );
      await _ref.read(notificationServiceProvider).init(); // Refresh token/permission
    });
    // Reset state after a short delay or upon completion to prevent "sticky" loading states on next screen
    if (!state.hasError) {
      resetState();
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      // 1. Attempt token cleanup
      // We do this before sign-out while the user is still authenticated
      await _ref.read(notificationServiceProvider).deleteToken();
    } catch (e) {
      AppLogger.warning('SignOut: Notification token cleanup failed: $e', 'AUTH');
    }

    // 2. Perform actual sign out from repositories
    final result = await AsyncValue.guard(() async {
      await _authRepository.signOut();
    });

    if (mounted) {
      state = result;
      // Note: RouterNotifier will pick up the auth state change and redirect.
      // We don't need a manual delay or resetState here if the router is robust.
      if (!result.hasError) {
        resetState();
      }
    }
  }

  Future<void> resetPassword(String email) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _authRepository.resetPassword(email));
  }

  Future<void> sendEmailVerification() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _authRepository.sendEmailVerification());
    if (!state.hasError) {
      resetState();
    }
  }

  Future<void> checkVerificationStatus() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = _ref.read(firebaseAuthProvider).currentUser;
      if (user != null) {
        await user.reload();
        // Force refresh the auth state provider to ensure the new verified status is propagated
        _ref.invalidate(authStateProvider);
      }
    });
    if (!state.hasError) {
      resetState();
    }
  }

  Future<void> updateProfile({
    String? university,
    String? campus,
    String? course,
    String? yearOfStudy,
    String? fullName,
    String? whatsappNumber,
    String? photoUrl,
  }) async {
    final user = _ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    // Resolve university to canonical ID if possible
    final String? resolvedUniversity = CampusConstants.resolveToId(university) ?? university;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _authRepository.updateProfile(
      uid: user.uid,
      university: resolvedUniversity,
      campus: campus,
      course: course,
      yearOfStudy: yearOfStudy,
      fullName: fullName,
      whatsappNumber: whatsappNumber,
      photoUrl: photoUrl,
    ));
    if (!state.hasError) {
      resetState();
    }
  }

  Future<void> completeOnboarding() async {
    final user = _ref.read(firebaseAuthProvider).currentUser;
    if (user == null) {
      final prefs = _ref.read(sharedPreferencesProvider);
      await prefs.setBool('device_onboarding_completed', true);
      _ref.read(deviceOnboardingCompletedProvider.notifier).state = true;
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _authRepository.updateOnboardingStatus(user.uid, true));
    if (!state.hasError) {
      resetState();
    }
  }

  Future<void> deleteAccount() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _ref.read(notificationServiceProvider).deleteToken();
      await _authRepository.deleteAccount();
    });
    if (!state.hasError) {
      _ref.read(accountDeletedProvider.notifier).state = true;
      resetState();
    }
  }

  Future<void> updatePrivacySettings(Map<String, String> settings) async {
    final user = _ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _authRepository.updateProfile(
      uid: user.uid,
      privacySettings: settings,
    ));
    if (!state.hasError) {
      resetState();
    }
  }

  Future<void> updateNotificationSettings(Map<String, bool> settings) async {
    final user = _ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _authRepository.updateProfile(
      uid: user.uid,
      notificationSettings: settings,
    ));
    if (!state.hasError) {
      resetState();
    }
  }

  Future<void> blockUser(String blockedUid) async {
    final user = _ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _authRepository.blockUser(user.uid, blockedUid));
    if (!state.hasError) {
      resetState();
    }
  }

  Future<void> unblockUser(String blockedUid) async {
    final user = _ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _authRepository.unblockUser(user.uid, blockedUid));
    if (!state.hasError) {
      resetState();
    }
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(
    authRepository: ref.watch(authRepositoryProvider),
    ref: ref,
  );
});
