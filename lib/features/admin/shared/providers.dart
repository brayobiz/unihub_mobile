import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/shared/providers.dart';
import '../data/repositories/admin_repository.dart';
import '../domain/models/admin_stats.dart';
import '../domain/models/verification_request.dart';
import '../domain/models/report.dart';
import '../domain/models/moderation_content.dart';
import '../../../../services/notification_service.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  return AdminRepository(firestore, notificationService);
});

final adminStatsProvider = StreamProvider<AdminStats>((ref) {
  final repository = ref.watch(adminRepositoryProvider);
  return repository.watchStats();
});

final verificationRequestsProvider = StreamProvider.family<List<AdminVerificationRequest>, ({AdminVerificationStatus? status, AdminVerificationType? type})>((ref, filters) {
  final repository = ref.watch(adminRepositoryProvider);
  return repository.watchVerificationRequests(status: filters.status, type: filters.type);
});

final adminReportsProvider = StreamProvider.family<List<AdminReport>, ({ReportStatus? status, ReportType? type})>((ref, filters) {
  final repository = ref.watch(adminRepositoryProvider);
  return repository.watchReports(status: filters.status, type: filters.type);
});

final moderatedContentProvider = StreamProvider.family<List<ModeratedContent>, ({ContentType type, String? status})>((ref, filters) {
  final repository = ref.watch(adminRepositoryProvider);
  return repository.watchContent(filters.type, status: filters.status);
});
