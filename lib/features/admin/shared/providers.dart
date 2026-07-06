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

import 'package:unihub_mobile/features/shared/data/services/platform_event_service.dart';
import '../domain/services/admin_service.dart';
import '../../trust/domain/services/trust_engine.dart';
import '../../announcements/shared/providers.dart';
import '../../events/domain/models/event.dart';

final platformEventServiceProvider = Provider<PlatformEventService>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final notificationSender = ref.watch(notificationServiceProvider);
  return PlatformEventService(firestore, notificationSender);
});

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return AdminRepository(firestore);
});

final adminServiceProvider = Provider<AdminService>((ref) {
  final repository = ref.watch(adminRepositoryProvider);
  final settingsRepo = ref.watch(systemSettingsRepositoryProvider);
  final announcementRepo = ref.watch(announcementRepositoryProvider);
  final eventService = ref.watch(platformEventServiceProvider);
  final firestore = ref.watch(firestoreProvider);
  return AdminService(repository, settingsRepo, announcementRepo, eventService, firestore);
});

final systemSettingsRepositoryProvider = Provider<SystemSettingsRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return SystemSettingsRepository(firestore);
});

final systemSettingsProvider = StreamProvider.autoDispose<SystemSettings>((ref) {
  final repository = ref.watch(systemSettingsRepositoryProvider);
  return repository.watchSettings();
});

final adminStatsProvider = StreamProvider.autoDispose<AdminStats>((ref) {
  final repository = ref.watch(adminRepositoryProvider);
  return repository.watchStats();
});

final verificationRequestsProvider = StreamProvider.autoDispose.family<List<AdminVerificationRequest>, ({AdminVerificationStatus? status, AdminVerificationType? type})>((ref, filters) {
  final repository = ref.watch(adminRepositoryProvider);
  return repository.watchVerificationRequests(status: filters.status, type: filters.type);
});

final adminReportsProvider = StreamProvider.autoDispose.family<List<AdminReport>, ({ReportStatus? status, ReportType? type})>((ref, filters) {
  final repository = ref.watch(adminRepositoryProvider);
  return repository.watchReports(status: filters.status, type: filters.type);
});

final moderatedContentProvider = StreamProvider.autoDispose.family<List<ModeratedContent>, ({ContentType type, String? status})>((ref, filters) {
  final repository = ref.watch(adminRepositoryProvider);
  return repository.watchContent(filters.type, status: filters.status);
});

final adminUsersProvider = StreamProvider.autoDispose.family<List<AppUser>, ({String? search, bool? isBanned, bool? isSuspended, bool? isVerified, String? role, String? university, String? sortBy, bool descending, DateTime? startDate, DateTime? endDate})>((ref, filters) {
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

final adminAuditLogsProvider = StreamProvider.autoDispose.family<List<AdminAuditLog>, int>((ref, limit) {
  final repository = ref.watch(adminRepositoryProvider);
  return repository.watchAuditLogs(limit: limit);
});

final supportConversationsProvider = StreamProvider.autoDispose.family<List<Conversation>, ({String? status, String? priority, String? assignedAdminId, String? search})>((ref, filters) {
  final repository = ref.watch(adminRepositoryProvider);
  return repository.watchSupportConversations(
    status: filters.status,
    priority: filters.priority,
    assignedAdminId: filters.assignedAdminId,
    searchQuery: filters.search,
  );
});

final supportStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  final repository = ref.watch(adminRepositoryProvider);
  return repository.getSupportStats();
});

// Event Approval Providers
final pendingEventsProvider = StreamProvider.autoDispose.family<List<Event>, String?>((ref, campusId) {
  final repository = ref.watch(adminRepositoryProvider);
  return repository.watchSubmittedEvents(campusId: campusId);
});


