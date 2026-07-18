import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/verification_request.dart';
import '../models/report.dart';
import '../models/moderation_content.dart';
import '../models/audit_log.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/system_settings_repository.dart';
import '../models/system_settings.dart';
import '../../../announcements/domain/models/announcement.dart';
import '../../../announcements/data/repositories/announcement_repository.dart';
import '../../../shared/data/services/platform_event_service.dart';
import '../../../shared/domain/models/platform_event.dart';
import '../../../trust/domain/services/trust_engine.dart';

class AdminService {
  final AdminRepository _repository;
  final SystemSettingsRepository _settingsRepository;
  final AnnouncementRepository _announcementRepository;
  final PlatformEventService _eventService;
  final FirebaseFirestore _firestore;

  AdminService(this._repository, this._settingsRepository, this._announcementRepository, this._eventService, this._firestore);

  Future<void> processVerification({
    required AdminVerificationRequest request,
    required AdminVerificationStatus newStatus,
    required String adminId,
    required String adminName,
    String? reason,
    String? adminNotes,
  }) async {
    // 1. Authorization check (Enforced in Repository too, but good to have here)
    await _verifyAdmin(adminId);

    // 2. Business Logic: Trust Boost Calculation
    final trustBoost = TrustEngine.getTrustBoost(request.type, newStatus);

    // 3. Persist changes
    await _repository.processVerification(
      request: request,
      newStatus: newStatus,
      adminId: adminId,
      adminName: adminName,
      reason: reason,
      adminNotes: adminNotes,
      trustBoost: trustBoost,
    );

    // 4. Publish Platform Event (Decoupled Notification)
    await _publishVerificationEvent(request, newStatus, reason);
  }

  Future<void> resolveReport({
    required AdminReport report,
    required String action,
    required String adminId,
    required String adminName,
    String? notes,
    int? suspensionDays,
  }) async {
    await _verifyAdmin(adminId);

    await _repository.resolveReport(
      report: report,
      action: action,
      adminId: adminId,
      adminName: adminName,
      notes: notes,
      suspensionDays: suspensionDays,
    );

    // Publish Event
    if (action != 'dismiss') {
       PlatformEventType type = PlatformEventType.reportResolved;
       String title = 'Moderation Update';
       String body = 'A report against your account/content has been resolved.';

       if (action == 'ban') {
         type = PlatformEventType.userBanned;
         title = 'Account Banned ⛔';
         body = 'Your account has been permanently banned for community violations.';
       } else if (action == 'suspend') {
         type = PlatformEventType.userSuspended;
         title = 'Account Suspended ⚠️';
         body = 'Your account has been temporarily suspended.';
       } else if (action == 'remove') {
         type = PlatformEventType.contentRemoved;
         title = 'Content Removed 🗑️';
         body = 'One of your posts was removed for violating our guidelines.';
       }

       await _eventService.publishEvent(PlatformEvent(
        id: '',
        type: type,
        recipientId: report.reportedUserId ?? '',
        title: title,
        body: body,
        targetId: report.id,
        targetType: 'report',
        timestamp: DateTime.now(),
        metadata: {'action': action},
      ));
    }
  }

  Future<void> toggleUserBan(String userId, bool isBanned, {required String adminId, required String adminName, String? reason}) async {
    await _verifyAdmin(adminId);
    await _repository.toggleUserBan(userId, isBanned, adminId: adminId, adminName: adminName, reason: reason);

    await _eventService.publishEvent(PlatformEvent(
      id: '',
      type: isBanned ? PlatformEventType.userBanned : PlatformEventType.userRestored,
      recipientId: userId,
      title: isBanned ? 'Account Banned ⛔' : 'Account Reinstated ✅',
      body: isBanned 
          ? 'Your account has been permanently banned from Ulify.'
          : 'Your account access has been restored. Welcome back!',
      timestamp: DateTime.now(),
      metadata: {'reason': reason},
    ));
  }

  Future<void> suspendUser(String userId, DateTime until, String reason, {required String adminId, required String adminName}) async {
    await _verifyAdmin(adminId);
    await _repository.suspendUser(userId, until, reason, adminId: adminId, adminName: adminName);

    await _eventService.publishEvent(PlatformEvent(
      id: '',
      type: PlatformEventType.userSuspended,
      recipientId: userId,
      title: 'Account Suspended ⚠️',
      body: 'Your account has been suspended until ${until.toString().split(' ').first}. Reason: $reason',
      timestamp: DateTime.now(),
      metadata: {'until': until.toIso8601String(), 'reason': reason},
    ));
  }

  Future<void> updateContentStatus(
    ContentType type, 
    String contentId, 
    String newStatus, 
    {required String adminId, required String adminName, String? reason}
  ) async {
    await _verifyAdmin(adminId);
    await _repository.updateContentStatus(type, contentId, newStatus, adminId: adminId, adminName: adminName, reason: reason);

    // Fetch content to find authorId (simplified)
  }

  Future<void> marketplacePromotionAction({
    required String listingId,
    required String action,
    required String adminId,
    required String adminName,
    Map<String, dynamic>? metadata,
  }) async {
    await _verifyAdmin(adminId);
    await _repository.marketplacePromotionAction(
      listingId: listingId,
      action: action,
      adminId: adminId,
      adminName: adminName,
      metadata: metadata,
    );
  }

  Future<void> updateUserTrustScore(String userId, double score, {required String adminId, required String adminName}) async {
    await _verifyAdmin(adminId);
    await _repository.updateUserTrustScore(userId, score, adminId: adminId, adminName: adminName);

    await _eventService.publishEvent(PlatformEvent(
      id: '',
      type: PlatformEventType.reportResolved, // Reusing generic moderation type
      recipientId: userId,
      title: 'Trust Score Updated ⭐',
      body: 'Your platform trust score has been manually adjusted by an administrator to ${score.toInt()}%.',
      timestamp: DateTime.now(),
      metadata: {'newScore': score},
    ));
  }

  Future<void> publishAnnouncement(Announcement announcement, {required String adminId, required String adminName}) async {
    await _verifyAdmin(adminId);
    
    if (announcement.createdAt == announcement.updatedAt) {
      await _announcementRepository.createAnnouncement(announcement);
    } else {
      await _announcementRepository.updateAnnouncement(announcement);
    }

    if (announcement.status == AnnouncementStatus.published && announcement.publishAt.isBefore(DateTime.now().add(const Duration(minutes: 1)))) {
       // Only log if actually published
       await _repository.logAction(AdminAuditLog(
        id: '',
        adminId: adminId,
        adminName: adminName,
        actionType: AdminActionType.bulkAction, // Using generic for now
        targetId: announcement.id,
        targetType: 'announcement',
        timestamp: DateTime.now(),
        reason: 'Announcement Published: ${announcement.title}',
      ));
    }
  }

  Future<void> updateSettings(SystemSettings settings, {required String adminId, required String adminName}) async {
    await _verifyAdmin(adminId);
    await _settingsRepository.updateSettings(settings);

    await _repository.logAction(AdminAuditLog(
      id: '',
      adminId: adminId,
      adminName: adminName,
      actionType: AdminActionType.bulkAction,
      targetId: 'system_settings',
      targetType: 'config',
      timestamp: DateTime.now(),
      reason: 'System settings updated',
    ));
  }

  Future<void> bulkProcessVerifications({
    required List<AdminVerificationRequest> requests,
    required AdminVerificationStatus status,
    required String adminId,
    required String adminName,
    String? reason,
  }) async {
    await _verifyAdmin(adminId);
    
    // Calculate boosts for all approved requests
    final List<({AdminVerificationRequest request, double boost})> processed = requests.map((r) => (
      request: r,
      boost: TrustEngine.getTrustBoost(r.type, status),
    )).toList();

    await _repository.bulkProcessVerifications(
      requests: requests,
      status: status,
      adminId: adminId,
      adminName: adminName,
      reason: reason,
      // We'll update AdminRepository to handle boosts in bulk too
    );

    // Notify all users (could be throttled or batch notified in real system)
    for (var r in requests) {
      await _publishVerificationEvent(r, status, reason);
    }
  }

  Future<void> bulkResolveReports({
    required List<AdminReport> reports,
    required String action,
    required String adminId,
    required String adminName,
  }) async {
    await _verifyAdmin(adminId);
    await _repository.bulkResolveReports(
      reports: reports,
      action: action,
      adminId: adminId,
      adminName: adminName,
    );

    for (var report in reports) {
      if (action != 'dismiss') {
        await _eventService.publishEvent(PlatformEvent(
          id: '',
          type: PlatformEventType.reportResolved,
          recipientId: report.reportedUserId ?? '',
          title: 'Moderation Update',
          body: 'A report against your account/content has been resolved.',
          targetId: report.id,
          targetType: 'report',
          timestamp: DateTime.now(),
          metadata: {'action': action},
        ));
      }
    }
  }

  Future<void> bulkUpdateContentStatus({
    required List<String> contentIds,
    required ContentType type,
    required String newStatus,
    required String adminId,
    required String adminName,
  }) async {
    await _verifyAdmin(adminId);
    await _repository.bulkUpdateContentStatus(
      contentIds: contentIds,
      type: type,
      newStatus: newStatus,
      adminId: adminId,
      adminName: adminName,
    );
  }

  Future<void> bulkUpdateUserStatus({
    required List<String> userIds,
    required bool isBanned,
    required String adminId,
    required String adminName,
  }) async {
    await _verifyAdmin(adminId);
    await _repository.bulkUpdateUserStatus(
      userIds: userIds,
      isBanned: isBanned,
      adminId: adminId,
      adminName: adminName,
    );

    for (var userId in userIds) {
      await _eventService.publishEvent(PlatformEvent(
        id: '',
        type: isBanned ? PlatformEventType.userBanned : PlatformEventType.userRestored,
        recipientId: userId,
        title: isBanned ? 'Account Banned ⛔' : 'Account Reinstated ✅',
        body: isBanned 
            ? 'Your account has been permanently banned from Ulify.'
            : 'Your account access has been restored. Welcome back!',
        timestamp: DateTime.now(),
      ));
    }
  }

  Future<void> _verifyAdmin(String adminId) async {
    final adminDoc = await _firestore.collection('users').doc(adminId).get();
    if (!adminDoc.exists) throw Exception('Unauthorized: User not found.');
    
    final data = adminDoc.data() as Map<String, dynamic>;
    final isAdminField = data['isAdmin'] ?? false;
    final roles = List<String>.from(data['roles'] ?? []);
    
    if (!isAdminField && !roles.contains('admin')) {
      throw Exception('Unauthorized: Administrative privileges required.');
    }
  }

  Future<void> _publishVerificationEvent(
    AdminVerificationRequest request, 
    AdminVerificationStatus status,
    String? reason,
  ) async {
    PlatformEventType type;
    String title = '';
    String body = '';
    String deepLink = '/trust-center';

    if (status == AdminVerificationStatus.approved) {
      type = PlatformEventType.verificationApproved;
      title = 'Verification Approved! ✅';
      body = 'Your ${request.type.name} verification has been approved.';
    } else {
      type = PlatformEventType.verificationRejected;
      title = 'Verification Update ⚠️';
      body = 'Your ${request.type.name} verification was not approved. Reason: ${reason ?? "Please review your details"}';
    }

    if (request.type == AdminVerificationType.organizer) {
      deepLink = '/organizers/${request.metadata['organizerId']}/dashboard';
    }

    await _eventService.publishEvent(PlatformEvent(
      id: '',
      type: type,
      recipientId: request.userId,
      title: title,
      body: body,
      targetId: request.id,
      targetType: 'verification',
      deepLink: deepLink,
      timestamp: DateTime.now(),
    ));
  }
}
