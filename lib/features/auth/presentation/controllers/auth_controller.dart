import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../services/notification_service.dart';
import '../../../../services/presence_service.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../app/providers/app_restart_provider.dart';

import '../../../../core/constants/campus_constants.dart';

enum AuthOperation {
  none,
  emailSignIn,
  googleSignIn,
  emailSignUp,
  signOut,
  resetPassword,
  deleteAccount,
  updateProfile,
  completeOnboarding,
}

class AuthControllerState {
  final AsyncValue<void> status;
  final AuthOperation operation;

  AuthControllerState({
    this.status = const AsyncValue.data(null),
    this.operation = AuthOperation.none,
  });

  bool get isLoading => status.isLoading;
  bool get hasError => status.hasError;
  Object? get error => status.error;

  AuthControllerState copyWith({
    AsyncValue<void>? status,
    AuthOperation? operation,
  }) {
    return AuthControllerState(
      status: status ?? this.status,
      operation: operation ?? this.operation,
    );
  }
}

class AuthController extends StateNotifier<AuthControllerState> {
  final AuthRepository _authRepository;
  final Ref _ref;

  AuthController({required AuthRepository authRepository, required Ref ref})
      : _authRepository = authRepository,
        _ref = ref,
        super(AuthControllerState());

  void resetState() {
    state = AuthControllerState();
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(
      status: const AsyncValue.loading(),
      operation: AuthOperation.emailSignIn,
    );
    final result = await AsyncValue.guard(() async {
      await _authRepository.signInWithEmailAndPassword(email, password);
      await _ref.read(notificationServiceProvider).init(); // Refresh token/permission
    });
    
    if (mounted) {
      state = state.copyWith(status: result);
      if (!result.hasError) {
        resetState();
      }
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(
      status: const AsyncValue.loading(),
      operation: AuthOperation.googleSignIn,
    );
    final result = await AsyncValue.guard(() async {
      await _authRepository.signInWithGoogle();
      await _ref.read(notificationServiceProvider).init(); // Refresh token/permission
    });
    
    if (mounted) {
      state = state.copyWith(status: result);
      if (!result.hasError) {
        resetState();
      }
    }
  }

  Future<void> signUp({
    required String email, 
    required String password, 
    required String fullName,
  }) async {
    state = state.copyWith(
      status: const AsyncValue.loading(),
      operation: AuthOperation.emailSignUp,
    );
    final result = await AsyncValue.guard(() async {
      await _authRepository.signUpWithEmailAndPassword(
        email: email,
        password: password,
        fullName: fullName,
      );
      await _ref.read(notificationServiceProvider).init(); // Refresh token/permission
    });
    
    if (mounted) {
      state = state.copyWith(status: result);
      if (!result.hasError) {
        resetState();
      }
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(
      status: const AsyncValue.loading(),
      operation: AuthOperation.signOut,
    );
    try {
      // 1. Audit Phase 3.3: Immediate Background Cleanup
      // Stop presence tracking before auth is gone
      _ref.read(presenceServiceProvider).dispose();
      
      // 2. Notification Cleanup (Revoke token & unsubscribe while still authorized)
      await _ref.read(notificationServiceProvider).deleteToken();
    } catch (e) {
      AppLogger.warning('SignOut Cleanup: Partial failure during background cleanup: $e', 'AUTH');
    }

    // 3. Perform actual sign out from repositories
    final result = await AsyncValue.guard(() async {
      await _authRepository.signOut();
      
      // 4. Reset AI context if exists
      // (Future check: does AI service need explicit reset?)
      
      // 5. Trigger full app state reset to clear in-memory caches
      _ref.read(appRestartProvider.notifier).state++;
    });

    if (mounted) {
      state = state.copyWith(status: result);
      if (!result.hasError) {
        resetState();
      }
    }
  }

  Future<void> resetPassword(String email) async {
    state = state.copyWith(
      status: const AsyncValue.loading(),
      operation: AuthOperation.resetPassword,
    );
    final result = await AsyncValue.guard(() => _authRepository.resetPassword(email));
    if (mounted) {
      state = state.copyWith(status: result);
    }
  }

  Future<void> sendEmailVerification() async {
    state = state.copyWith(
      status: const AsyncValue.loading(),
      operation: AuthOperation.none, // Generic operation
    );
    final result = await AsyncValue.guard(() => _authRepository.sendEmailVerification());
    if (mounted) {
      state = state.copyWith(status: result);
      if (!result.hasError) {
        resetState();
      }
    }
  }

  Future<void> checkVerificationStatus() async {
    final user = _ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    // Use a lighter operation if we're polling
    await AsyncValue.guard(() async {
      await user.reload();
      final updatedUser = _ref.read(firebaseAuthProvider).currentUser;
      
      if (updatedUser?.emailVerified == true) {
        // Sync to Firestore for security rules and global state
        await _authRepository.updateVerificationStatus(updatedUser!.uid, emailVerified: true);
        
        // Audit Fix: Force invalidation of user providers to ensure UI updates immediately
        _ref.invalidate(authStateProvider);
        _ref.invalidate(appUserProvider);
      }
    });
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

    state = state.copyWith(
      status: const AsyncValue.loading(),
      operation: AuthOperation.updateProfile,
    );
    final result = await AsyncValue.guard(() => _authRepository.updateProfile(
      uid: user.uid,
      university: resolvedUniversity,
      campus: campus,
      course: course,
      yearOfStudy: yearOfStudy,
      fullName: fullName,
      whatsappNumber: whatsappNumber,
      photoUrl: photoUrl,
    ));
    
    if (mounted) {
      state = state.copyWith(status: result);
      if (!result.hasError) {
        resetState();
      }
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

    state = state.copyWith(
      status: const AsyncValue.loading(),
      operation: AuthOperation.completeOnboarding,
    );
    final result = await AsyncValue.guard(() => _authRepository.updateOnboardingStatus(user.uid, true));
    
    if (mounted) {
      state = state.copyWith(status: result);
      if (!result.hasError) {
        resetState();
      }
    }
  }

  Future<void> deleteAccount() async {
    state = state.copyWith(
      status: const AsyncValue.loading(),
      operation: AuthOperation.deleteAccount,
    );
    final result = await AsyncValue.guard(() async {
      await _ref.read(notificationServiceProvider).deleteToken();
      await _authRepository.deleteAccount();
    });
    
    if (mounted) {
      state = state.copyWith(status: result);
      if (!result.hasError) {
        _ref.read(accountDeletedProvider.notifier).state = true;
        resetState();
      }
    }
  }

  Future<void> updatePrivacySettings(Map<String, String> settings) async {
    final user = _ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    state = state.copyWith(
      status: const AsyncValue.loading(),
      operation: AuthOperation.updateProfile,
    );
    final result = await AsyncValue.guard(() => _authRepository.updateProfile(
      uid: user.uid,
      privacySettings: settings,
    ));
    
    if (mounted) {
      state = state.copyWith(status: result);
      if (!result.hasError) {
        resetState();
      }
    }
  }

  Future<void> updateNotificationSettings(Map<String, bool> settings) async {
    final user = _ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    state = state.copyWith(
      status: const AsyncValue.loading(),
      operation: AuthOperation.updateProfile,
    );
    final result = await AsyncValue.guard(() => _authRepository.updateProfile(
      uid: user.uid,
      notificationSettings: settings,
    ));
    
    if (mounted) {
      state = state.copyWith(status: result);
      if (!result.hasError) {
        resetState();
      }
    }
  }

  Future<void> blockUser(String blockedUid) async {
    final user = _ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    
    state = state.copyWith(
      status: const AsyncValue.loading(),
      operation: AuthOperation.none,
    );
    final result = await AsyncValue.guard(() => _authRepository.blockUser(user.uid, blockedUid));
    
    if (mounted) {
      state = state.copyWith(status: result);
      if (!result.hasError) {
        resetState();
      }
    }
  }

  Future<void> unblockUser(String blockedUid) async {
    final user = _ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    
    state = state.copyWith(
      status: const AsyncValue.loading(),
      operation: AuthOperation.none,
    );
    final result = await AsyncValue.guard(() => _authRepository.unblockUser(user.uid, blockedUid));
    
    if (mounted) {
      state = state.copyWith(status: result);
      if (!result.hasError) {
        resetState();
      }
    }
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthControllerState>((ref) {
  return AuthController(
    authRepository: ref.watch(authRepositoryProvider),
    ref: ref,
  );
});

