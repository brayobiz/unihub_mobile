import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

class AdminRepository {
  final FirebaseFirestore _firestore;
  final NotificationService? _notificationService;

  AdminRepository(this._firestore, [this._notificationService]);

  Future<AdminStats> getStats() async {
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
      _firestore.collection('reports').count().get(), // Marketplace/Feed reports
      _firestore.collection('housing_reports').count().get(), // Housing reports
    ]);

    return AdminStats(
      totalUsers: results[0].count ?? 0,
      totalMarketplaceListings: results[1].count ?? 0,
      totalHousingListings: results[2].count ?? 0,
      totalNotes: results[3].count ?? 0,
      pendingVerifications: (results[4].count ?? 0) + (results[5].count ?? 0) + (results[6].count ?? 0),
      totalReports: (results[7].count ?? 0) + (results[8].count ?? 0),
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
  }) {
    // Combine multiple streams from different collections
    final identityStream = _firestore.collection('identity_verifications').snapshots();
    final studentStream = _firestore.collection('student_verifications').snapshots();
    final professionalStream = _firestore.collection('verification_applications').snapshots();

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
    String? reason,
    String? adminNotes,
  }) async {
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
  }

  String _getCollectionName(AdminVerificationType type) {
    switch (type) {
      case AdminVerificationType.identity: return 'identity_verifications';
      case AdminVerificationType.student: return 'student_verifications';
      case AdminVerificationType.professional: return 'verification_applications';
    }
  }

  // --- Feature Moderation Methods ---

  Stream<List<ModeratedContent>> watchContent(ContentType type, {String? status}) {
    switch (type) {
      case ContentType.marketplace:
        var query = _firestore.collection('listings').orderBy('createdAt', descending: true);
        if (status != null) query = query.where('status', isEqualTo: status);
        return query.snapshots().map((snap) => 
          snap.docs.map((doc) => ModeratedContent.fromMarketplace(Listing.fromJson(doc.data()))).toList());
      
      case ContentType.housing:
        var query = _firestore.collection('housing_listings').orderBy('createdAt', descending: true);
        if (status != null) query = query.where('status', isEqualTo: status);
        return query.snapshots().map((snap) => 
          snap.docs.map((doc) => ModeratedContent.fromHousing(HousingListing.fromFirestore(doc))).toList());

      case ContentType.notes:
        var query = _firestore.collection('notes').orderBy('createdAt', descending: true);
        // NoteListing doesn't have status yet, so we just return all
        return query.snapshots().map((snap) => 
          snap.docs.map((doc) => ModeratedContent.fromNote(NoteListing.fromJson(doc.data()))).toList());
    }
  }

  Future<void> updateContentStatus(ContentType type, String contentId, String newStatus, {String? reason}) async {
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
  }

  String _getCollectionForType(ContentType type) {
    switch (type) {
      case ContentType.marketplace: return 'listings';
      case ContentType.housing: return 'housing_listings';
      case ContentType.notes: return 'notes';
    }
  }

  // --- Moderation Methods ---

  Stream<List<AdminReport>> watchReports({ReportType? type, ReportStatus? status}) {
    final reportsStream = _firestore.collection('reports').snapshots();
    final housingReportsStream = _firestore.collection('housing_reports').snapshots();

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
    String? notes,
    int? suspensionDays,
  }) async {
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
}
