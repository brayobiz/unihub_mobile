import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/trust/domain/models/identity_verification.dart';
import 'package:unihub_mobile/features/trust/domain/models/student_verification.dart';
import 'package:unihub_mobile/features/trust/domain/models/verification_application.dart';
import 'package:unihub_mobile/features/trust/domain/models/professional_role.dart';
import 'package:unihub_mobile/features/trust/domain/repositories/trust_repository.dart';
import 'package:unihub_mobile/features/trust/data/repositories/trust_repository_impl.dart';

final trustRepositoryProvider = Provider<TrustRepository>((ref) {
  return TrustRepositoryImpl(ref.watch(firestoreProvider));
});

final userApplicationsProvider = StreamProvider<List<VerificationApplication>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(trustRepositoryProvider).watchUserApplications(user.uid);
});

final applicationByRoleProvider = StreamProvider.family<VerificationApplication?, ProfessionalRole>((ref, role) {
  final applicationsAsync = ref.watch(userApplicationsProvider);
  
  return applicationsAsync.when(
    data: (applications) {
      try {
        final app = applications.firstWhere((app) => app.role == role);
        return Stream.value(app);
      } catch (_) {
        return Stream.value(null);
      }
    },
    loading: () => const Stream.empty(),
    error: (_, __) => Stream.value(null),
  );
});

final studentVerificationProvider = StreamProvider<StudentVerification?>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value(null);
  return ref.watch(trustRepositoryProvider).watchStudentVerification(user.uid);
});

final identityVerificationProvider = StreamProvider<IdentityVerification?>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value(null);
  return ref.watch(trustRepositoryProvider).watchIdentityVerification(user.uid);
});

// Helper to check if user has a verified role
final isRoleVerifiedProvider = Provider.family<bool, ProfessionalRole>((ref, role) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return false;
  return user.verifiedRoles.contains(role.name);
});
