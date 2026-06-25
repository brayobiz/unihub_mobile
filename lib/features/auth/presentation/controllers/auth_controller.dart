import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers.dart';
import '../../domain/repositories/auth_repository.dart';

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
    state = await AsyncValue.guard(() => _authRepository.signInWithEmailAndPassword(email, password));
    if (!state.hasError) {
      resetState();
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _authRepository.signInWithGoogle());
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
    state = await AsyncValue.guard(() => _authRepository.signUpWithEmailAndPassword(
      email: email,
      password: password,
      fullName: fullName,
    ));
    // Reset state after a short delay or upon completion to prevent "sticky" loading states on next screen
    if (!state.hasError) {
      resetState();
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authRepository.signOut();
      // Additional cleanup if needed
    });
    if (!state.hasError) {
      resetState();
    }
  }

  Future<void> resetPassword(String email) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _authRepository.resetPassword(email));
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

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _authRepository.updateProfile(
      uid: user.uid,
      university: university,
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
}

final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(
    authRepository: ref.watch(authRepositoryProvider),
    ref: ref,
  );
});
