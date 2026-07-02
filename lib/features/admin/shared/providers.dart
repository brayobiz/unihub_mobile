import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/shared/providers.dart';
import '../data/repositories/admin_repository.dart';
import '../domain/models/admin_stats.dart';
import '../domain/models/verification_request.dart';
import '../domain/models/report.dart';
import '../domain/models/moderation_content.dart';
import '../domain/models/audit_log.dart';
import '../../chat/domain/models/conversation.dart';
import '../../chat/domain/models/message.dart';
import '../../auth/domain/models/app_user.dart';
import '../../../../services/notification_service.dart';
import '../data/repositories/system_settings_repository.dart';
import '../domain/models/system_settings.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  return AdminRepository(firestore, notificationService);
});

final systemSettingsRepositoryProvider = Provider<SystemSettingsRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return SystemSettingsRepository(firestore);
});

final systemSettingsProvider = StreamProvider<SystemSettings>((ref) {
  final repository = ref.watch(systemSettingsRepositoryProvider);
  return repository.watchSettings();
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

final adminUsersProvider = StreamProvider.family<List<AppUser>, ({String? search, bool? isBanned, bool? isSuspended, bool? isVerified, String? role, String? university, String? sortBy, bool descending, DateTime? startDate, DateTime? endDate})>((ref, filters) {
  final repository = ref.watch(adminRepositoryProvider);
  return repository.watchUsers(
    searchQuery: filters.search,
    isBanned: filters.isBanned,
    isSuspended: filters.isSuspended,
    isVerified: filters.isVerified,
    role: filters.role,
    university: filters.university,
    sortBy: filters.sortBy,
    descending: filters.descending,
    startDate: filters.startDate,
    endDate: filters.endDate,
  );
});

final adminAuditLogsProvider = StreamProvider.family<List<AdminAuditLog>, int>((ref, limit) {
  final repository = ref.watch(adminRepositoryProvider);
  return repository.watchAuditLogs(limit: limit);
});

final supportConversationsProvider = StreamProvider.family<List<Conversation>, ({String? status, String? priority, String? assignedAdminId, String? search})>((ref, filters) {
  final repository = ref.watch(adminRepositoryProvider);
  return repository.watchSupportConversations(
    status: filters.status,
    priority: filters.priority,
    assignedAdminId: filters.assignedAdminId,
    searchQuery: filters.search,
  );
});

final supportStatsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  final repository = ref.watch(adminRepositoryProvider);
  return repository.getSupportStats();
});
