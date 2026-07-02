import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../../domain/models/admin_stats.dart';
import '../../domain/models/verification_request.dart';
import '../../domain/models/report.dart';
import '../../domain/models/moderation_content.dart';
import '../../../../services/notification_service.dart';
import '../../../../features/shared/domain/models/uni_notification.dart';
import '../../../marketplace/domain/models/listing.dart';
import '../../../housing/domain/models/housing_listing.dart';
import '../../../notes/domain/models/note.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../domain/models/audit_log.dart';
import '../../../chat/domain/models/conversation.dart';
import '../../../chat/domain/models/message.dart';

class AdminRepository {
  final FirebaseFirestore _firestore;
  final NotificationService? _notificationService;

  AdminRepository(this._firestore, [this._notificationService]);

  Future<AdminStats> getStats() async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    final results = await Future.wait([
      _firestore.collection('users').count().get(),
      _firestore.collection('listings').count().get(),
      _firestore.collection('housing_listings').count().get(),
      _firestore.collection('notes').count().get(),
      
      // Pending verifications
      _firestore.collection('identity_verifications')
          .where('status', isEqualTo: 'pending').count().get(),
      _firestore.collection('student_verifications')
          .where('status', isEqualTo: 'pending').count().get(),
      _firestore.collection('verification_applications')
          .where('status', isEqualTo: 'pending').count().get(),
          
      // Reports
      _firestore.collection('reports').where('status', isEqualTo: 'pending').count().get(),
      _firestore.collection('housing_reports').where('status', isEqualTo: 'pending').count().get(),

      // New users today
      _firestore.collection('users')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
          .count().get(),

      // Resolved reports
      _firestore.collection('reports').where('status', isEqualTo: 'resolved').count().get(),

      // Open support tickets
      _firestore.collection('conversations')
          .where('isSupport', isEqualTo: true)
          .where('supportStatus', whereIn: ['waiting_admin', 'active'])
          .count().get(),

      // Active announcements - using simple query to avoid complex index requirements
      _firestore.collection('announcements')
          .where('status', whereIn: ['published', 'scheduled'])
          .get(),
    ]);

    final announcementsSnap = results[12] as QuerySnapshot;
    final activeAnnouncements = announcementsSnap.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final publishAt = (data['publishAt'] as Timestamp?)?.toDate();
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
      
      if (publishAt == null) return false;
      
      return publishAt.isBefore(now.add(const Duration(minutes: 5))) &&
             (expiresAt == null || expiresAt.isAfter(now));
    }).length;

    return AdminStats(
      totalUsers: (results[0] as AggregateQuerySnapshot).count ?? 0,
      totalMarketplaceListings: (results[1] as AggregateQuerySnapshot).count ?? 0,
      totalHousingListings: (results[2] as AggregateQuerySnapshot).count ?? 0,
      totalNotes: (results[3] as AggregateQuerySnapshot).count ?? 0,
      pendingVerifications: ((results[4] as AggregateQuerySnapshot).count ?? 0) + 
                           ((results[5] as AggregateQuerySnapshot).count ?? 0) + 
                           ((results[6] as AggregateQuerySnapshot).count ?? 0),
      totalReports: ((results[7] as AggregateQuerySnapshot).count ?? 0) + 
                    ((results[8] as AggregateQuerySnapshot).count ?? 0),
      newUsersToday: (results[9] as AggregateQuerySnapshot).count ?? 0,
      resolvedReports: (results[10] as AggregateQuerySnapshot).count ?? 0,
      openSupportTickets: (results[11] as AggregateQuerySnapshot).count ?? 0,
      activeAnnouncements: activeAnnouncements,
    );
  }

  Stream<AdminStats> watchStats() async* {
    yield await getStats();
    yield* Stream.periodic(const Duration(seconds: 30)).asyncMap((_) => getStats());
  }

  // --- Verification Methods ---
  
  Stream<List<AdminVerificationRequest>> watchVerificationRequests({
    AdminVerificationStatus? status,
    AdminVerificationType? type,
    int limit = 50,
  }) {
    // Combine multiple streams from different collections
    final identityStream = _firestore.collection('identity_verifications').orderBy('submittedAt', descending: true).limit(limit).snapshots();
    final studentStream = _firestore.collection('student_verifications').orderBy('submittedAt', descending: true).limit(limit).snapshots();
    final professionalStream = _firestore.collection('verification_applications').orderBy('createdAt', descending: true).limit(limit).snapshots();

    return Rx.combineLatest3<QuerySnapshot, QuerySnapshot, QuerySnapshot, List<AdminVerificationRequest>>(
      identityStream,
      studentStream,
      professionalStream,
      (identitySnap, studentSnap, professionalSnap) {
        final List<AdminVerificationRequest> requests = [];

        // Map Identity
        for (var doc in identitySnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          requests.add(AdminVerificationRequest(
            id: doc.id,
            userId: data['userId'] ?? '',
            type: AdminVerificationType.identity,
            status: _mapStatus(data['status']),
            submittedAt: (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            rejectionReason: data['rejectionReason'],
            adminNotes: data['adminNotes'],
            idDocumentUrl: data['idDocumentUrl'],
            selfieUrl: data['selfieUrl'],
          ));
        }

        // Map Student
        for (var doc in studentSnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          requests.add(AdminVerificationRequest(
            id: doc.id,
            userId: data['userId'] ?? '',
            type: AdminVerificationType.student,
            status: _mapStatus(data['status']),
            submittedAt: (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            rejectionReason: data['rejectionReason'],
            adminNotes: data['adminNotes'],
            studentIdUrl: data['studentIdUrl'],
          ));
        }

        // Map Professional
        for (var doc in professionalSnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          requests.add(AdminVerificationRequest(
            id: doc.id,
            userId: data['userId'] ?? '',
            type: AdminVerificationType.professional,
            status: _mapStatus(data['status']),
            submittedAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            rejectionReason: data['rejectionReason'],
            adminNotes: data['adminNotes'],
            fullName: data['fullName'],
            phoneNumber: data['phoneNumber'],
            idDocumentUrl: data['idDocumentUrl'],
            selfieUrl: data['selfieUrl'],
            role: data['role'],
            metadata: data['metadata'] ?? {},
          ));
        }

        // Filter in-memory
        var filtered = requests;
        if (status != null) {
          filtered = filtered.where((r) => r.status == status).toList();
        }
        
        if (type != null) {
          filtered = filtered.where((r) => r.type == type).toList();
        }

        // Sort by submission date (newest first)
        filtered.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
        
        return filtered;
      },
    );
  }

  AdminVerificationStatus _mapStatus(String? status) {
    switch (status) {
      case 'approved': return AdminVerificationStatus.approved;
      case 'rejected': return AdminVerificationStatus.rejected;
      case 'underReview':
      case 'under_review':
        return AdminVerificationStatus.underReview;
      case 'resubmissionRequested':
      case 'resubmission_requested': 
        return AdminVerificationStatus.resubmissionRequested;
      case 'pending':
      default:
        return AdminVerificationStatus.pending;
    }
  }

  String _statusToDb(AdminVerificationStatus status) {
    return status.name; // This will use 'resubmissionRequested' which matches the enum
  }

  Future<void> processVerification({
    required AdminVerificationRequest request,
    required AdminVerificationStatus newStatus,
    required String adminId,
    required String adminName,
    String? reason,
    String? adminNotes,
  }) async {
    // Defense-in-depth: Re-verify admin status for destructive actions
    final adminDoc = await _firestore.collection('users').doc(adminId).get();
    final isAdmin = (adminDoc.data() as Map<String, dynamic>?)?['isAdmin'] ?? false;
    if (!isAdmin) throw Exception('Unauthorized: Administrative privileges required.');

    final batch = _firestore.batch();
    final timestamp = FieldValue.serverTimestamp();

    // 1. Update the specific verification document
    final collectionName = _getCollectionName(request.type);
    final verifRef = _firestore.collection(collectionName).doc(request.id);
    
    final Map<String, dynamic> updateData = {
      'status': _statusToDb(newStatus),
      'updatedAt': timestamp,
      if (newStatus == AdminVerificationStatus.approved) 'verifiedAt': timestamp,
      if (reason != null && reason.isNotEmpty) 'rejectionReason': reason,
      if (adminNotes != null && adminNotes.isNotEmpty) 'adminNotes': adminNotes,
    };

    batch.update(verifRef, updateData);

    // 2. Update the User document
    final userRef = _firestore.collection('users').doc(request.userId);
    final Map<String, dynamic> userUpdate = {};

    if (request.type == AdminVerificationType.identity) {
      userUpdate['isIdentityVerified'] = newStatus == AdminVerificationStatus.approved;
      userUpdate['identityStatus'] = _statusToDb(newStatus);
    } else if (request.type == AdminVerificationType.student) {
      userUpdate['isStudentVerified'] = newStatus == AdminVerificationStatus.approved;
    } else if (request.type == AdminVerificationType.professional && newStatus == AdminVerificationStatus.approved) {
      // Add role to verifiedRoles
      if (request.role != null) {
        userUpdate['verifiedRoles'] = FieldValue.arrayUnion([request.role]);
      }
    }

    // Boost trust score on approval
    if (newStatus == AdminVerificationStatus.approved) {
      double boost = 0;
      if (request.type == AdminVerificationType.identity) boost = 30;
      if (request.type == AdminVerificationType.student) boost = 20;
      if (request.type == AdminVerificationType.professional) boost = 15;
      userUpdate['trustScore'] = FieldValue.increment(boost);
    }

    batch.update(userRef, userUpdate);

    // 3. Commit changes
    await batch.commit();

    // 4. Send Notification
    if (_notificationService != null) {
      String title = '';
      String body = '';
      String deepLink = '';

      final typeStr = request.type.name.replaceAll('_', ' ');

      switch (newStatus) {
        case AdminVerificationStatus.approved:
          title = 'Verification Approved! ✅';
          body = 'Your $typeStr verification has been approved. Your profile trust score has increased!';
          deepLink = '/trust-center';
          break;
        case AdminVerificationStatus.rejected:
          title = 'Verification Rejected ❌';
          body = 'Your $typeStr verification was rejected. Reason: ${reason ?? "Incomplete information"}.';
          deepLink = '/trust-center';
          break;
        case AdminVerificationStatus.resubmissionRequested:
          title = 'Action Required: Verification ⚠️';
          body = 'Please resubmit your $typeStr documents. Reason: ${reason ?? "Documents unclear"}.';
          deepLink = '/trust-center';
          break;
        case AdminVerificationStatus.underReview:
          title = 'Verification Under Review 🔍';
          body = 'An administrator is currently reviewing your $typeStr documents. We will notify you once a decision is made.';
          deepLink = '/trust-center';
          break;
        default: break;
      }

      if (title.isNotEmpty) {
        await _notificationService!.sendNotification(
          recipientId: request.userId,
          title: title,
          body: body,
          type: NotificationType.system,
          deepLink: deepLink,
          targetType: 'trust',
        );
      }
    }

    await logAction(AdminAuditLog(
      id: '',
      adminId: adminId,
      adminName: adminName,
      actionType: newStatus == AdminVerificationStatus.approved 
          ? AdminActionType.verificationApproval 
          : AdminActionType.verificationRejection,
      targetId: request.id,
      targetType: request.type.name,
      timestamp: DateTime.now(),
      reason: reason,
      metadata: {'userId': request.userId},
    ));
  }

  String _getCollectionName(AdminVerificationType type) {
    switch (type) {
      case AdminVerificationType.identity: return 'identity_verifications';
      case AdminVerificationType.student: return 'student_verifications';
      case AdminVerificationType.professional: return 'verification_applications';
    }
  }

  // --- Feature Moderation Methods ---

  Stream<List<ModeratedContent>> watchContent(ContentType type, {String? status, int limit = 100}) {
    final collection = _getCollectionForType(type);
    var query = _firestore.collection(collection).orderBy('createdAt', descending: true).limit(limit);
    
    if (status != null) query = query.where('status', isEqualTo: status);
    
    return query.snapshots().map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        switch (type) {
          case ContentType.marketplace:
            return ModeratedContent.fromMarketplace(Listing.fromJson(data));
          case ContentType.housing:
            return ModeratedContent.fromHousing(HousingListing.fromFirestore(doc));
          case ContentType.notes:
            return ModeratedContent.fromNote(NoteListing.fromJson(data));
        }
      }).toList();
    });
  }

  Future<void> updateContentStatus(
    ContentType type, 
    String contentId, 
    String newStatus, 
    {required String adminId, required String adminName, String? reason}
  ) async {
    final collection = _getCollectionForType(type);
    final docRef = _firestore.collection(collection).doc(contentId);
    
    await docRef.update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
      if (reason != null) 'moderationReason': reason,
    });

    // Notify Author
    final doc = await docRef.get();
    final data = doc.data() as Map<String, dynamic>;
    final authorId = type == ContentType.notes ? data['authorId'] : (type == ContentType.housing ? data['plugId'] : data['sellerId']);
    
    if (authorId != null && _notificationService != null) {
      String title = 'Content Update';
      String body = 'Your ${type.name} listing "${data['title']}" status has been updated to $newStatus.';
      
      if (newStatus == 'removed') {
        title = 'Content Removed ⚠️';
        body = 'Your ${type.name} listing "${data['title']}" was removed for violating community guidelines.';
      }

      await _notificationService!.sendNotification(
        recipientId: authorId,
        title: title,
        body: body,
        type: NotificationType.system,
      );
    }

    await logAction(AdminAuditLog(
      id: '',
      adminId: adminId,
      adminName: adminName,
      actionType: newStatus == 'removed' ? AdminActionType.contentRemoval : AdminActionType.contentRestore,
      targetId: contentId,
      targetType: type.name,
      timestamp: DateTime.now(),
      reason: reason,
      metadata: {'status': newStatus},
    ));
  }

  String _getCollectionForType(ContentType type) {
    switch (type) {
      case ContentType.marketplace: return 'listings';
      case ContentType.housing: return 'housing_listings';
      case ContentType.notes: return 'notes';
    }
  }

  // --- Moderation Methods ---

  Stream<List<AdminReport>> watchReports({ReportType? type, ReportStatus? status, int limit = 100}) {
    final reportsStream = _firestore.collection('reports').orderBy('createdAt', descending: true).limit(limit).snapshots();
    final housingReportsStream = _firestore.collection('housing_reports').orderBy('createdAt', descending: true).limit(limit).snapshots();

    return Rx.combineLatest2<QuerySnapshot, QuerySnapshot, List<AdminReport>>(
      reportsStream,
      housingReportsStream,
      (reportsSnap, housingSnap) {
        final List<AdminReport> reports = [];

        for (var doc in reportsSnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final typeStr = data['type']?.toString() ?? 'listing';
          
          ReportType rType = ReportType.marketplace;
          if (typeStr == 'feed_item') rType = ReportType.feedItem;
          if (typeStr == 'user') rType = ReportType.user;

          reports.add(AdminReport(
            id: doc.id,
            reporterId: data['reporterId'] ?? '',
            targetId: data['targetId'] ?? data['itemId'],
            reportedUserId: data['reportedUserId'],
            type: rType,
            reason: data['reason'] ?? 'No reason provided',
            status: _mapReportStatus(data['status']),
            createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            history: (data['history'] as List?)?.map((h) => ModerationHistoryItem.fromJson(h)).toList() ?? [],
          ));
        }

        for (var doc in housingSnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          reports.add(AdminReport(
            id: doc.id,
            reporterId: data['reporterId'] ?? '',
            targetId: data['listingId'],
            type: ReportType.housing,
            reason: data['reason'] ?? data['category'] ?? 'Housing Violation',
            status: _mapReportStatus(data['status']),
            createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            history: (data['history'] as List?)?.map((h) => ModerationHistoryItem.fromJson(h)).toList() ?? [],
          ));
        }

        var filtered = reports;
        if (type != null) filtered = filtered.where((r) => r.type == type).toList();
        if (status != null) filtered = filtered.where((r) => r.status == status).toList();

        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return filtered;
      },
    );
  }

  ReportStatus _mapReportStatus(String? status) {
    switch (status) {
      case 'under_review': return ReportStatus.underReview;
      case 'resolved': return ReportStatus.resolved;
      case 'dismissed': return ReportStatus.dismissed;
      case 'pending':
      default:
        return ReportStatus.pending;
    }
  }

  Future<void> resolveReport({
    required AdminReport report,
    required String action, // 'dismiss', 'warn', 'remove', 'suspend', 'ban'
    required String adminId,
    required String adminName,
    String? notes,
    int? suspensionDays,
  }) async {
    // Defense-in-depth: Re-verify admin status for destructive actions
    final adminDoc = await _firestore.collection('users').doc(adminId).get();
    final isAdmin = (adminDoc.data() as Map<String, dynamic>?)?['isAdmin'] ?? false;
    if (!isAdmin) throw Exception('Unauthorized: Administrative privileges required.');

    final batch = _firestore.batch();
    final timestamp = DateTime.now();
    final historyItem = ModerationHistoryItem(
      adminId: adminId,
      action: action,
      notes: notes,
      timestamp: timestamp,
    );

    // 1. Update Report Status & History
    final collection = report.type == ReportType.housing ? 'housing_reports' : 'reports';
    final reportRef = _firestore.collection(collection).doc(report.id);
    
    batch.update(reportRef, {
      'status': action == 'dismiss' ? 'dismissed' : 'resolved',
      'history': FieldValue.arrayUnion([historyItem.toJson()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Perform Content/User Actions
    if (action == 'remove' && report.targetId != null) {
      await _removeContent(batch, report.type, report.targetId!);
    } else if (action == 'warn' && report.reportedUserId != null) {
      await _warnUser(report.reportedUserId!, notes ?? report.reason);
    } else if (action == 'suspend' && report.reportedUserId != null) {
      final until = timestamp.add(Duration(days: suspensionDays ?? 7));
      batch.update(_firestore.collection('users').doc(report.reportedUserId), {
        'suspendedUntil': Timestamp.fromDate(until),
      });
      await _notifyModeration(report.reportedUserId!, 'Account Suspended', 
          'Your account has been suspended until ${until.toString().split(' ').first} due to community violations.');
    } else if (action == 'ban' && report.reportedUserId != null) {
      batch.update(_firestore.collection('users').doc(report.reportedUserId), {
        'isBanned': true,
        'banReason': notes ?? report.reason,
      });
      await _notifyModeration(report.reportedUserId!, 'Account Banned', 
          'Your account has been permanently banned from UniHub for violating our terms of service.');
    }

    await batch.commit();

    await logAction(AdminAuditLog(
      id: '',
      adminId: adminId,
      adminName: adminName,
      actionType: action == 'dismiss' ? AdminActionType.reportDismissal : AdminActionType.reportResolution,
      targetId: report.id,
      targetType: 'report',
      timestamp: DateTime.now(),
      reason: notes,
      metadata: {'action': action, 'targetId': report.targetId},
    ));
  }

  Future<void> _removeContent(WriteBatch batch, ReportType type, String targetId) async {
    if (type == ReportType.marketplace) {
      batch.update(_firestore.collection('listings').doc(targetId), {'status': 'removed'});
    } else if (type == ReportType.housing) {
      batch.update(_firestore.collection('housing_listings').doc(targetId), {'status': 'removed'});
    } else if (type == ReportType.feedItem) {
      batch.delete(_firestore.collection('feed').doc(targetId));
    }
    // TODO: Notify content owner if possible
  }

  Future<void> _warnUser(String userId, String reason) async {
    if (_notificationService != null) {
      await _notificationService!.sendNotification(
        recipientId: userId,
        title: 'Community Warning ⚠️',
        body: 'You have received a warning for: $reason. Repeated violations may lead to suspension.',
        type: NotificationType.system,
      );
    }
  }

  Future<void> _notifyModeration(String userId, String title, String body) async {
    if (_notificationService != null) {
      await _notificationService!.sendNotification(
        recipientId: userId,
        title: title,
        body: body,
        type: NotificationType.system,
      );
    }
  }

  // --- User Management Methods ---

  Stream<List<AppUser>> watchUsers({
    String? searchQuery,
    bool? isBanned,
    bool? isSuspended,
    bool? isVerified,
    String? role,
    String? university,
    String? sortBy, // 'name', 'date', 'trust', 'active'
    bool descending = true,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 200,
  }) {
    Query query = _firestore.collection('users').limit(limit);

    return query.snapshots().map((snapshot) {
      var users = snapshot.docs
          .map((doc) => AppUser.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      // Filter by Date Range
      if (startDate != null) {
        users = users.where((u) => u.createdAt != null && u.createdAt!.isAfter(startDate)).toList();
      }
      if (endDate != null) {
        users = users.where((u) => u.createdAt != null && u.createdAt!.isBefore(endDate.add(const Duration(days: 1)))).toList();
      }

      // Search (Name, Email, Username, Phone, ID)
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final searchLower = searchQuery.toLowerCase();
        users = users.where((u) => 
          u.fullName.toLowerCase().contains(searchLower) || 
          u.email.toLowerCase().contains(searchLower) ||
          (u.username?.toLowerCase().contains(searchLower) ?? false) ||
          (u.phoneNumber?.toLowerCase().contains(searchLower) ?? false) ||
          u.uid.toLowerCase().contains(searchLower)
        ).toList();
      }

      // Basic Filters
      if (isBanned != null) {
        users = users.where((u) => u.isBanned == isBanned).toList();
      }
      if (isSuspended != null) {
        users = users.where((u) => u.isCurrentlySuspended == isSuspended).toList();
      }
      if (isVerified != null) {
        users = users.where((u) => u.isVerified == isVerified).toList();
      }
      if (role != null) {
        users = users.where((u) => u.roles.contains(role)).toList();
      }
      if (university != null && university != 'All') {
        users = users.where((u) => u.university == university).toList();
      }

      // Sorting
      switch (sortBy) {
        case 'date':
          users.sort((a, b) => (a.createdAt ?? DateTime(2000)).compareTo(b.createdAt ?? DateTime(2000)));
          break;
        case 'trust':
          users.sort((a, b) => a.trustScore.compareTo(b.trustScore));
          break;
        case 'active':
          users.sort((a, b) => (a.lastSeen ?? DateTime(2000)).compareTo(b.lastSeen ?? DateTime(2000)));
          break;
        case 'name':
        default:
          users.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
          break;
      }

      if (descending) {
        users = users.reversed.toList();
      }
      
      return users;
    });
  }

  Future<void> updateUserRoles(String userId, List<String> roles, {required String adminId, required String adminName}) async {
    await _firestore.collection('users').doc(userId).update({
      'roles': roles,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await logAction(AdminAuditLog(
      id: '',
      adminId: adminId,
      adminName: adminName,
      actionType: AdminActionType.userRoleUpdate,
      targetId: userId,
      targetType: 'user',
      timestamp: DateTime.now(),
      metadata: {'roles': roles},
    ));
  }

  Future<void> toggleUserBan(String userId, bool isBanned, {required String adminId, required String adminName, String? reason}) async {
    // Defense-in-depth: Re-verify admin status for destructive actions
    final adminDoc = await _firestore.collection('users').doc(adminId).get();
    final isAdmin = (adminDoc.data() as Map<String, dynamic>?)?['isAdmin'] ?? false;
    if (!isAdmin) throw Exception('Unauthorized: Administrative privileges required.');

    await _firestore.collection('users').doc(userId).update({
      'isBanned': isBanned,
      'banReason': isBanned ? reason : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (isBanned) {
      await _notifyModeration(
        userId, 
        'Account Banned', 
        'Your account has been permanently banned from UniHub for violating our terms of service.'
      );
    } else {
       await _notifyModeration(
        userId, 
        'Account Reinstated', 
        'Your account ban has been lifted. You can now access UniHub services again.'
      );
    }

    await logAction(AdminAuditLog(
      id: '',
      adminId: adminId,
      adminName: adminName,
      actionType: isBanned ? AdminActionType.userBan : AdminActionType.userRestore,
      targetId: userId,
      targetType: 'user',
      timestamp: DateTime.now(),
      reason: reason,
    ));
  }

  Future<void> suspendUser(String userId, DateTime until, String reason, {required String adminId, required String adminName}) async {
    await _firestore.collection('users').doc(userId).update({
      'suspendedUntil': Timestamp.fromDate(until),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _notifyModeration(
      userId, 
      'Account Suspended', 
      'Your account has been suspended until ${until.toString().split(' ').first} due to community violations: $reason'
    );

    await logAction(AdminAuditLog(
      id: '',
      adminId: adminId,
      adminName: adminName,
      actionType: AdminActionType.userSuspension,
      targetId: userId,
      targetType: 'user',
      timestamp: DateTime.now(),
      reason: reason,
      metadata: {'until': until.toIso8601String()},
    ));
  }

  Future<void> updateUserTrustScore(String userId, double score, {required String adminId, required String adminName}) async {
    await _firestore.collection('users').doc(userId).update({
      'trustScore': score,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await logAction(AdminAuditLog(
      id: '',
      adminId: adminId,
      adminName: adminName,
      actionType: AdminActionType.trustScoreAdjustment,
      targetId: userId,
      targetType: 'user',
      timestamp: DateTime.now(),
      metadata: {'newScore': score},
    ));
  }

  Future<void> resetUserVerification(String userId, {required String adminId, required String adminName}) async {
    final batch = _firestore.batch();
    final userRef = _firestore.collection('users').doc(userId);
    
    batch.update(userRef, {
      'isIdentityVerified': false,
      'identityStatus': 'none',
      'isStudentVerified': false,
      'verifiedRoles': [],
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    await logAction(AdminAuditLog(
      id: '',
      adminId: adminId,
      adminName: adminName,
      actionType: AdminActionType.bulkAction, // Or add a specific one
      targetId: userId,
      targetType: 'user',
      timestamp: DateTime.now(),
      reason: 'Reset verification status',
    ));
  }

  Future<Map<String, dynamic>> getUserActivityStats(String userId) async {
    final results = await Future.wait([
      _firestore.collection('listings').where('sellerId', isEqualTo: userId).count().get(),
      _firestore.collection('housing_listings').where('plugId', isEqualTo: userId).count().get(),
      _firestore.collection('notes').where('authorId', isEqualTo: userId).count().get(),
      _firestore.collection('reports').where('reporterId', isEqualTo: userId).count().get(),
      _firestore.collection('reports').where('reportedUserId', isEqualTo: userId).count().get(),
      _firestore.collection('housing_reports').where('reporterId', isEqualTo: userId).count().get(),
    ]);

    return {
      'listingsCount': results[0].count ?? 0,
      'housingCount': results[1].count ?? 0,
      'notesCount': results[2].count ?? 0,
      'reportsSubmitted': (results[3].count ?? 0) + (results[5].count ?? 0),
      'reportsReceived': results[4].count ?? 0,
    };
  }

  Future<List<AdminVerificationRequest>> getUserVerificationHistory(String userId) async {
    // This is similar to watchVerificationRequests but filtered for a single user
    // and returns a Future list.
    
    final snapshots = await Future.wait([
      _firestore.collection('identity_verifications').where('userId', isEqualTo: userId).get(),
      _firestore.collection('student_verifications').where('userId', isEqualTo: userId).get(),
      _firestore.collection('verification_applications').where('userId', isEqualTo: userId).get(),
    ]);

    final List<AdminVerificationRequest> requests = [];

    // Map Identity
    for (var doc in snapshots[0].docs) {
      final data = doc.data();
      requests.add(AdminVerificationRequest(
        id: doc.id,
        userId: userId,
        type: AdminVerificationType.identity,
        status: _mapStatus(data['status']),
        submittedAt: (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        rejectionReason: data['rejectionReason'],
        adminNotes: data['adminNotes'],
        idDocumentUrl: data['idDocumentUrl'],
        selfieUrl: data['selfieUrl'],
      ));
    }

    // Map Student
    for (var doc in snapshots[1].docs) {
      final data = doc.data();
      requests.add(AdminVerificationRequest(
        id: doc.id,
        userId: userId,
        type: AdminVerificationType.student,
        status: _mapStatus(data['status']),
        submittedAt: (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        rejectionReason: data['rejectionReason'],
        adminNotes: data['adminNotes'],
        studentIdUrl: data['studentIdUrl'],
      ));
    }

    // Map Professional
    for (var doc in snapshots[2].docs) {
      final data = doc.data();
      requests.add(AdminVerificationRequest(
        id: doc.id,
        userId: userId,
        type: AdminVerificationType.professional,
        status: _mapStatus(data['status']),
        submittedAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        rejectionReason: data['rejectionReason'],
        adminNotes: data['adminNotes'],
        fullName: data['fullName'],
        phoneNumber: data['phoneNumber'],
        idDocumentUrl: data['idDocumentUrl'],
        selfieUrl: data['selfieUrl'],
        role: data['role'],
        metadata: data['metadata'] ?? {},
      ));
    }

    requests.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return requests;
  }

  Future<List<AdminReport>> getUserReports(String userId, {bool received = true}) async {
    final queryField = received ? 'reportedUserId' : 'reporterId';
    
    final snapshots = await Future.wait([
      _firestore.collection('reports').where(queryField, isEqualTo: userId).get(),
      if (!received) _firestore.collection('housing_reports').where('reporterId', isEqualTo: userId).get()
      else Future.value(null),
    ]);

    final List<AdminReport> reports = [];

    for (var doc in snapshots[0]!.docs) {
      final data = doc.data();
      final typeStr = data['type']?.toString() ?? 'listing';
      
      ReportType rType = ReportType.marketplace;
      if (typeStr == 'feed_item') rType = ReportType.feedItem;
      if (typeStr == 'user') rType = ReportType.user;

      reports.add(AdminReport(
        id: doc.id,
        reporterId: data['reporterId'] ?? '',
        targetId: data['targetId'] ?? data['itemId'],
        reportedUserId: data['reportedUserId'],
        type: rType,
        reason: data['reason'] ?? 'No reason provided',
        status: _mapReportStatus(data['status']),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        history: (data['history'] as List?)?.map((h) => ModerationHistoryItem.fromJson(h)).toList() ?? [],
      ));
    }

    if (snapshots[1] != null) {
      for (var doc in snapshots[1]!.docs) {
        final data = doc.data();
        reports.add(AdminReport(
          id: doc.id,
          reporterId: data['reporterId'] ?? '',
          targetId: data['listingId'],
          type: ReportType.housing,
          reason: data['reason'] ?? data['category'] ?? 'Housing Violation',
          status: _mapReportStatus(data['status']),
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          history: (data['history'] as List?)?.map((h) => ModerationHistoryItem.fromJson(h)).toList() ?? [],
        ));
      }
    }

    reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return reports;
  }

  Future<void> addAdminNote(String userId, String note, String adminId) async {
    final noteObj = {
      'adminId': adminId,
      'note': note,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('users').doc(userId).update({
      'adminNotes': FieldValue.arrayUnion([noteObj]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // --- Audit Logging ---

  Future<void> logAction(AdminAuditLog log) async {
    await _firestore.collection('admin_audit_logs').add(log.toJson());
  }

  // --- Bulk Operations ---

  Future<void> bulkProcessVerifications({
    required List<AdminVerificationRequest> requests,
    required AdminVerificationStatus status,
    required String adminId,
    required String adminName,
    String? reason,
  }) async {
    final batch = _firestore.batch();
    
    for (var request in requests) {
      final collectionName = _getCollectionName(request.type);
      batch.update(_firestore.collection(collectionName).doc(request.id), {
        'status': _statusToDb(status),
        'updatedAt': FieldValue.serverTimestamp(),
        if (reason != null) 'rejectionReason': reason,
      });

      // Update user
      final userRef = _firestore.collection('users').doc(request.userId);
      if (status == AdminVerificationStatus.approved) {
        if (request.type == AdminVerificationType.identity) {
          batch.update(userRef, {'isIdentityVerified': true, 'identityStatus': 'approved'});
        } else if (request.type == AdminVerificationType.student) {
          batch.update(userRef, {'isStudentVerified': true});
        }
      }
    }

    await batch.commit();

    await logAction(AdminAuditLog(
      id: '',
      adminId: adminId,
      adminName: adminName,
      actionType: AdminActionType.bulkAction,
      targetId: 'multiple',
      targetType: 'verification',
      timestamp: DateTime.now(),
      reason: 'Bulk ${status.name} of ${requests.length} requests',
    ));
  }

  Future<void> bulkResolveReports({
    required List<AdminReport> reports,
    required String action,
    required String adminId,
    required String adminName,
  }) async {
    final batch = _firestore.batch();
    
    for (var report in reports) {
      final collection = report.type == ReportType.housing ? 'housing_reports' : 'reports';
      batch.update(_firestore.collection(collection).doc(report.id), {
        'status': action == 'dismiss' ? 'dismissed' : 'resolved',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    await logAction(AdminAuditLog(
      id: '',
      adminId: adminId,
      adminName: adminName,
      actionType: AdminActionType.bulkAction,
      targetId: 'multiple',
      targetType: 'report',
      timestamp: DateTime.now(),
      reason: 'Bulk $action of ${reports.length} reports',
    ));
  }

  Future<void> bulkUpdateContentStatus({
    required List<String> contentIds,
    required ContentType type,
    required String newStatus,
    required String adminId,
    required String adminName,
  }) async {
    final batch = _firestore.batch();
    final collection = _getCollectionForType(type);
    
    for (var id in contentIds) {
      batch.update(_firestore.collection(collection).doc(id), {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    await logAction(AdminAuditLog(
      id: '',
      adminId: adminId,
      adminName: adminName,
      actionType: AdminActionType.bulkAction,
      targetId: 'multiple',
      targetType: type.name,
      timestamp: DateTime.now(),
      reason: 'Bulk $newStatus of ${contentIds.length} items',
    ));
  }

  Future<void> bulkUpdateUserStatus({
    required List<String> userIds,
    required bool isBanned,
    required String adminId,
    required String adminName,
  }) async {
    // Defense-in-depth: Re-verify admin status
    final adminDoc = await _firestore.collection('users').doc(adminId).get();
    final isAdmin = (adminDoc.data() as Map<String, dynamic>?)?['isAdmin'] ?? false;
    if (!isAdmin) throw Exception('Unauthorized: Administrative privileges required.');

    final batch = _firestore.batch();
    
    for (var id in userIds) {
      batch.update(_firestore.collection('users').doc(id), {
        'isBanned': isBanned,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    await logAction(AdminAuditLog(
      id: '',
      adminId: adminId,
      adminName: adminName,
      actionType: AdminActionType.bulkAction,
      targetId: 'multiple',
      targetType: 'user',
      timestamp: DateTime.now(),
      reason: 'Bulk ${isBanned ? "ban" : "restore"} of ${userIds.length} users',
    ));
  }

  Stream<List<AdminAuditLog>> watchAuditLogs({int limit = 50}) {
    return _firestore
        .collection('admin_audit_logs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AdminAuditLog.fromJson(doc.id, doc.data()))
            .toList());
  }

  // --- Support Methods ---

  Stream<List<Conversation>> watchSupportConversations({
    String? status,
    String? priority,
    String? assignedAdminId,
    String? searchQuery,
  }) {
    Query query = _firestore.collection('conversations').where('isSupport', isEqualTo: true);

    if (status != null && status != 'all') {
      query = query.where('supportStatus', isEqualTo: status);
    }
    if (priority != null && priority != 'all') {
      query = query.where('supportPriority', isEqualTo: priority);
    }
    if (assignedAdminId != null && assignedAdminId != 'all') {
      if (assignedAdminId == 'unassigned') {
        query = query.where('assignedAdminId', isNull: true);
      } else {
        query = query.where('assignedAdminId', isEqualTo: assignedAdminId);
      }
    }

    return query.snapshots().asyncMap((snapshot) async {
      var conversations = snapshot.docs
          .map((doc) => Conversation.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final searchLower = searchQuery.toLowerCase();
        // We need to fetch user details to search by name/email
        // For performance, we'll do it in a batch
        final userIds = conversations.map((c) => c.participants.firstWhere((p) => p != 'unihub_admin', orElse: () => '')).where((id) => id.isNotEmpty).toSet().toList();
        
        if (userIds.isNotEmpty) {
          final usersSnap = await _firestore.collection('users').where(FieldPath.documentId, whereIn: userIds).get();
          final userMap = {for (var doc in usersSnap.docs) doc.id: AppUser.fromJson(doc.data())};

          conversations = conversations.where((c) {
            final userId = c.participants.firstWhere((p) => p != 'unihub_admin', orElse: () => '');
            final user = userMap[userId];
            if (user == null) return false;
            return user.fullName.toLowerCase().contains(searchLower) ||
                   user.email.toLowerCase().contains(searchLower) ||
                   (user.username?.toLowerCase().contains(searchLower) ?? false) ||
                   c.id.toLowerCase().contains(searchLower);
          }).toList();
        }
      }

      conversations.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      return conversations;
    });
  }

  Future<void> updateSupportConversationStatus(String conversationId, String status, {required String adminId, required String adminName}) async {
    final doc = await _firestore.collection('conversations').doc(conversationId).get();
    final currentStatus = (doc.data() as Map<String, dynamic>?)?['supportStatus'];
    
    if (currentStatus == 'resolved' && status == 'resolved') {
      throw Exception('This session is already resolved.');
    }

    await _firestore.collection('conversations').doc(conversationId).update({
      'supportStatus': status,
      'updatedAt': FieldValue.serverTimestamp(),
      if (status == 'resolved') 'resolvedAt': FieldValue.serverTimestamp(),
      if (status == 'resolved') 'resolvedBy': adminId,
    });

    await logAction(AdminAuditLog(
      id: '',
      adminId: adminId,
      adminName: adminName,
      actionType: AdminActionType.reportResolution,
      targetId: conversationId,
      targetType: 'support_conversation',
      timestamp: DateTime.now(),
      reason: 'Status updated to $status',
    ));
    
    // Notify user if resolved
    if (status == 'resolved' && _notificationService != null) {
      final participants = List<String>.from(doc.data()?['participants'] ?? []);
      final userId = participants.firstWhere((p) => p != 'unihub_admin', orElse: () => '');
      if (userId.isNotEmpty) {
        await _notificationService!.sendNotification(
          recipientId: userId,
          title: 'Support Case Resolved ✅',
          body: 'Your support ticket has been marked as resolved. Thank you for using UniHub Support.',
          type: NotificationType.support,
          targetId: conversationId,
        );
      }
    }
  }

  Future<void> updateSupportConversationPriority(String conversationId, String priority, {required String adminId, required String adminName}) async {
    await _firestore.collection('conversations').doc(conversationId).update({
      'supportPriority': priority,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> assignSupportConversation(String conversationId, String? adminId, {required String adminName, required String performingAdminId}) async {
    final batch = _firestore.batch();
    final convRef = _firestore.collection('conversations').doc(conversationId);
    
    final Map<String, dynamic> updateData = {
      'assignedAdminId': adminId,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (adminId != null) {
      // Add the assigned admin to participants so they have read/write access if rules are participant-based
      updateData['participants'] = FieldValue.arrayUnion([adminId]);
    }

    batch.update(convRef, updateData);

    await batch.commit();

    await logAction(AdminAuditLog(
      id: '',
      adminId: performingAdminId,
      adminName: adminName,
      actionType: AdminActionType.bulkAction,
      targetId: conversationId,
      targetType: 'support_conversation',
      timestamp: DateTime.now(),
      reason: adminId == null ? 'Unassigned ticket' : 'Assigned ticket to $adminId',
    ));
  }

  Future<void> addSupportAdminNote(String conversationId, String note, String adminId) async {
    final noteObj = {
      'adminId': adminId,
      'note': note,
      'timestamp': Timestamp.now(),
    };
    await _firestore.collection('conversations').doc(conversationId).update({
      'supportAdminNotes': FieldValue.arrayUnion([noteObj]),
    });
  }

  Future<Map<String, dynamic>> getSupportStats() async {
    final results = await Future.wait([
      _firestore.collection('conversations').where('isSupport', isEqualTo: true).where('supportStatus', isEqualTo: 'waiting_admin').count().get(),
      _firestore.collection('conversations').where('isSupport', isEqualTo: true).where('supportStatus', isEqualTo: 'waiting_user').count().get(),
      _firestore.collection('conversations').where('isSupport', isEqualTo: true).where('supportStatus', isEqualTo: 'resolved').count().get(),
      _firestore.collection('conversations').where('isSupport', isEqualTo: true).count().get(),
    ]);

    return {
      'waitingAdmin': results[0].count ?? 0,
      'waitingUser': results[1].count ?? 0,
      'resolved': results[2].count ?? 0,
      'total': results[3].count ?? 0,
    };
  }
}
