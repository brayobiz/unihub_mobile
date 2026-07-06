import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/trust/domain/models/identity_verification.dart';
import 'package:unihub_mobile/features/trust/domain/models/student_verification.dart';
import 'package:unihub_mobile/features/trust/domain/models/verification_application.dart';
import 'package:unihub_mobile/features/trust/domain/models/professional_role.dart';
import 'package:unihub_mobile/features/trust/domain/repositories/trust_repository.dart';
import 'package:unihub_mobile/features/trust/data/repositories/trust_repository_impl.dart';

import 'package:unihub_mobile/services/notification_service.dart';

final trustRepositoryProvider = Provider<TrustRepository>((ref) {
  return TrustRepositoryImpl(
    ref.watch(firestoreProvider),
    ref.watch(notificationServiceProvider),
  );
});

final userApplicationsProvider = StreamProvider.autoDispose<List<VerificationApplication>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  // Defensive: guard against null or empty UID to avoid invalid Firestore document paths
  if (user == null || user.uid.isEmpty) return Stream.value([]);
  return ref.watch(trustRepositoryProvider).watchUserApplications(user.uid);
});

final applicationByRoleProvider = Provider.autoDispose.family<AsyncValue<VerificationApplication?>, ProfessionalRole>((ref, role) {
  final appsAsync = ref.watch(userApplicationsProvider);
  return appsAsync.when(
    data: (applications) {
      try {
        final found = applications.firstWhere((app) => app.role == role);
        return AsyncValue.data(found);
      } catch (_) {
        return const AsyncValue.data(null);
      }
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

final userApplicationByRoleProvider = FutureProvider.autoDispose.family<VerificationApplication?, ({String userId, ProfessionalRole role})>((ref, arg) {
  return ref.watch(trustRepositoryProvider).getLatestApplication(arg.userId, arg.role);
});

final studentVerificationProvider = StreamProvider.autoDispose<StudentVerification?>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  // Defensive: ensure UID is present and non-empty
  if (user == null || user.uid.isEmpty) return Stream.value(null);
  return ref.watch(trustRepositoryProvider).watchStudentVerification(user.uid);
});

final identityVerificationProvider = StreamProvider.autoDispose<IdentityVerification?>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  // Defensive: ensure UID is present and non-empty
  if (user == null || user.uid.isEmpty) return Stream.value(null);
  return ref.watch(trustRepositoryProvider).watchIdentityVerification(user.uid);
});

// Helper to check if user has a verified role
final isRoleVerifiedProvider = Provider.autoDispose.family<bool, ProfessionalRole>((ref, role) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return false;
  return user.verifiedRoles.contains(role.name);
});
