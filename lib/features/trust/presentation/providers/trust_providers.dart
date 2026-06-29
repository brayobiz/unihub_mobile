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
  return ref.watch(userApplicationsProvider.stream).map((applications) {
    try {
      return applications.firstWhere((app) => app.role == role);
    } catch (_) {
      return null;
    }
  });
});

final userApplicationByRoleProvider = FutureProvider.family<VerificationApplication?, ({String userId, ProfessionalRole role})>((ref, arg) {
  return ref.watch(trustRepositoryProvider).getLatestApplication(arg.userId, arg.role);
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
