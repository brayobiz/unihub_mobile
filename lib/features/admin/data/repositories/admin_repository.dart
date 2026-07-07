import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../../domain/models/admin_stats.dart';
import '../../domain/models/verification_request.dart';
import '../../domain/models/report.dart';
import '../../domain/models/moderation_content.dart';
import '../../../../services/notification_service.dart';
import 'package:unihub_mobile/core/services/notification_sender.dart';
import '../../../../features/shared/domain/models/uni_notification.dart';
import '../../../marketplace/domain/models/listing.dart';
import '../../../housing/domain/models/housing_listing.dart';
import '../../../notes/domain/models/note.dart';
import '../../../events/domain/models/event.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../domain/models/audit_log.dart';
import '../../../chat/domain/models/conversation.dart';
import '../../../chat/domain/models/message.dart';
import '../../../trust/domain/services/trust_engine.dart';
import '../../../../core/utils/app_logger.dart';

class AdminRepository {
  final FirebaseFirestore _firestore;
  
  // Cache to reduce redundant fetches for support and verification screens
  final Map<String, AppUser> _userCache = {};

  AdminRepository(this._firestore);

  Future<bool> _isUserAdmin(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>;
      final isAdminField = data['isAdmin'] ?? false;
      final roles = List<String>.from(data['roles'] ?? []);
      return isAdminField || roles.contains('admin');
    } catch (e) {
      return false;
    }
  }

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
      _firestore.collection('organizer_verification_requests')
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

      // Events
      _firestore.collection('events').count().get(),
      _firestore.collection('events')
          .where('status', isEqualTo: 'submitted').count().get(),
    ]);

    final announcementsSnap = results[13] as QuerySnapshot;
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
                           ((results[6] as AggregateQuerySnapshot).count ?? 0) +
                           ((results[7] as AggregateQuerySnapshot).count ?? 0),
      totalReports: ((results[8] as AggregateQuerySnapshot).count ?? 0) + 
                    ((results[9] as AggregateQuerySnapshot).count ?? 0),
      newUsersToday: (results[10] as AggregateQuerySnapshot).count ?? 0,
      resolvedReports: (results[11] as AggregateQuerySnapshot).count ?? 0,
      openSupportTickets: (results[12] as AggregateQuerySnapshot).count ?? 0,
      activeAnnouncements: activeAnnouncements,
      totalEvents: (results[14] as AggregateQuerySnapshot).count ?? 0,
      pendingEventApprovals: (results[15] as AggregateQuerySnapshot).count ?? 0,
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
    int limit = 100,
  }) {
    // Combine multiple streams from different collections
    // Using a higher limit to ensure we find matching items after in-memory filtering if needed, 
    // though we try to filter at Firestore level for status.
    
    Query identityQuery = _firestore.collection('identity_verifications');
    Query studentQuery = _firestore.collection('student_verifications');
    Query professionalQuery = _firestore.collection('verification_applications');
    Query organizerQuery = _firestore.collection('organizer_verification_requests');

    if (status != null) {
      final statusStr = _statusToDb(status);
      identityQuery = identityQuery.where('status', isEqualTo: statusStr);
      studentQuery = studentQuery.where('status', isEqualTo: statusStr);
      professionalQuery = professionalQuery.where('status', isEqualTo: statusStr);
      organizerQuery = organizerQuery.where('status', isEqualTo: statusStr);
    }

    // We only use orderBy if status is NOT filtered, or if composite indexes are likely to exist.
    // To be safe for MVP and avoid "Query requires index" errors, we only orderBy on the 'All' view.
    if (status == null) {
      identityQuery = identityQuery.orderBy('submittedAt', descending: true);
      studentQuery = studentQuery.orderBy('submittedAt', descending: true);
      professionalQuery = professionalQuery.orderBy('createdAt', descending: true);
      organizerQuery = organizerQuery.orderBy('submittedAt', descending: true);
    }

    final identityStream = identityQuery.limit(limit).snapshots();
    final studentStream = studentQuery.limit(limit).snapshots();
    final professionalStream = professionalQuery.limit(limit).snapshots();
    final organizerStream = organizerQuery.limit(limit).snapshots();

    return Rx.combineLatest4<QuerySnapshot, QuerySnapshot, QuerySnapshot, QuerySnapshot, List<AdminVerificationRequest>>(
      identityStream,
      studentStream,
      professionalStream,
      organizerStream,
      (identitySnap, studentSnap, professionalSnap, organizerSnap) {
        final List<AdminVerificationRequest> requests = [];

         // Map Identity
         for (var doc in identitySnap.docs) {
           final data = doc.data() as Map<String, dynamic>;
           final userIdFromField = data['userId'];
           final userId = userIdFromField?.toString() ?? '';
           final docId = doc.id;
           
           AppLogger.info('🔍 Identity Verification Document Debug: docId: "$docId"', 'AdminRepository');
           
           // For identity verifications, the document ID should be the userId
           // Defensive: if userId field is missing, use doc.id, but validate it's not empty
           final finalUserId = userId.isNotEmpty ? userId : docId;
           
           if (docId.isEmpty || finalUserId.isEmpty) {
             AppLogger.warning('⚠️ Skipping identity verification with empty ID: docId="$docId", userId="$finalUserId"', 'AdminRepository');
             continue;
           }
           
           if (finalUserId == docId && userId.isEmpty) {
             AppLogger.warning('⚠️ ATTENTION: Identity verification using doc.id as userId! This is CORRUPTED DATA. docId="$docId"', 'AdminRepository');
           }
           
           requests.add(AdminVerificationRequest(
             id: docId,
             userId: finalUserId,
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
           final userIdFromField = data['userId'];
           final userId = userIdFromField?.toString() ?? '';
           final docId = doc.id;
           
           AppLogger.info('🔍 Student Verification Document Debug: docId: "$docId"', 'AdminRepository');
           
           // For student verifications, the document ID should be the userId
           // Defensive: if userId field is missing, use doc.id, but validate it's not empty
           final finalUserId = userId.isNotEmpty ? userId : docId;
           
           if (docId.isEmpty || finalUserId.isEmpty) {
             AppLogger.warning('⚠️ Skipping student verification with empty ID: docId="$docId", userId="$finalUserId"', 'AdminRepository');
             continue;
           }
           
           if (finalUserId == docId && userId.isEmpty) {
             AppLogger.warning('⚠️ ATTENTION: Student verification using doc.id as userId! This is CORRUPTED DATA. docId="$docId"', 'AdminRepository');
           }
           
           requests.add(AdminVerificationRequest(
             id: docId,
             userId: finalUserId,
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
          final userId = data['userId']?.toString() ?? '';
          
          if (userId.isEmpty) {
            AppLogger.warning('Professional application ${doc.id} missing userId', 'AdminRepository');
            continue;
          }

          requests.add(AdminVerificationRequest(
            id: doc.id,
            userId: userId,
            type: AdminVerificationType.professional,
            status: _mapStatus(data['status']),
            submittedAt: (data['createdAt'] as Timestamp?)?.toDate() ?? (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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

        // Map Organizer
        for (var doc in organizerSnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final ownerId = data['ownerId']?.toString() ?? '';
          
          if (ownerId.isEmpty) {
            AppLogger.warning('Organizer request ${doc.id} missing ownerId', 'AdminRepository');
            continue;
          }

          requests.add(AdminVerificationRequest(
            id: doc.id,
            userId: ownerId, 
            type: AdminVerificationType.organizer,
            status: _mapStatus(data['status']),
            submittedAt: (data['submittedAt'] as Timestamp?)?.toDate() ?? (data['resubmittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            rejectionReason: data['rejectionReason'],
            adminNotes: data['adminNotes'],
            fullName: data['name'], 
            metadata: {
              'organizerId': data['organizerId'],
              'campusId': data['campusId'],
              ...data,
            },
          ));
        }

        // Secondary Filter in-memory for safety and Type filtering
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
    double trustBoost = 0,
  }) async {
    // DEBUG: Log all inputs
    AppLogger.info('=== VERIFICATION APPROVAL DEBUG LOG === requestId: "${request.id}" newStatus: $newStatus', 'AdminRepository');
    
    // Defense-in-depth: Re-verify admin status for destructive actions
    if (!await _isUserAdmin(adminId)) {
      throw Exception('Unauthorized: Administrative privileges required.');
    }

    final timestamp = FieldValue.serverTimestamp();

    // ID Validation: Firestore doc() requires non-empty strings
    if (request.id.isEmpty || request.id.trim().isEmpty) {
      AppLogger.error('❌ Cannot process verification: EMPTY request.id', null, null, 'AdminRepository');
      throw Exception('Invalid Verification Request ID - value is empty');
    }
    
    final collectionName = _getCollectionName(request.type);
    if (collectionName.isEmpty) {
      AppLogger.error('❌ Cannot process verification with invalid type: ${request.type}', null, null, 'AdminRepository');
      throw Exception('Invalid Verification Type');
    }

    AppLogger.info('collectionName: "$collectionName"', 'AdminRepository');

    final batch = _firestore.batch();

    try {
      // 1. Update the specific verification document
      AppLogger.info('📝 About to update verification document at: $collectionName/$request.id', 'AdminRepository');
      final verifRef = _firestore.collection(collectionName).doc(request.id);
      
      final Map<String, dynamic> updateData = {
        'status': _statusToDb(newStatus),
        'updatedAt': timestamp,
        if (newStatus == AdminVerificationStatus.approved) 'verifiedAt': timestamp,
        if (reason != null && reason.isNotEmpty) 'rejectionReason': reason,
        if (adminNotes != null && adminNotes.isNotEmpty) 'adminNotes': adminNotes,
      };

      batch.update(verifRef, updateData);

       // 2. Handle specific type updates
       if (request.type == AdminVerificationType.organizer) {
         final organizerId = request.metadata['organizerId']?.toString();
         AppLogger.info('🏢 Processing ORGANIZER verification: $organizerId', 'AdminRepository');
         
         if (organizerId != null && organizerId.isNotEmpty && organizerId.trim().isNotEmpty) {
           final organizerRef = _firestore.collection('organizers').doc(organizerId);
           String organizerStatus = 'draft';
           
           switch (newStatus) {
             case AdminVerificationStatus.approved:
               organizerStatus = 'verified';
               break;
             case AdminVerificationStatus.rejected:
               organizerStatus = 'rejected';
               break;
             case AdminVerificationStatus.underReview:
               organizerStatus = 'underReview';
               break;
             case AdminVerificationStatus.resubmissionRequested:
               organizerStatus = 'rejected'; 
               break;
             case AdminVerificationStatus.pending:
               organizerStatus = 'submitted';
               break;
           }

           batch.update(organizerRef, {
             'verificationStatus': organizerStatus,
             'updatedAt': timestamp,
             if (newStatus == AdminVerificationStatus.approved) 'trustScore': FieldValue.increment(trustBoost),
           });

           // Also update owner's trust score if approved
           final ownerId = request.metadata['ownerId']?.toString();
           AppLogger.info('ownerId: "$ownerId"', 'AdminRepository');
           
           if (ownerId != null && ownerId.isNotEmpty && ownerId.trim().isNotEmpty && newStatus == AdminVerificationStatus.approved) {
             batch.update(_firestore.collection('users').doc(ownerId), {
               'trustScore': FieldValue.increment(10.0), // Bonus for owning a verified organizer
             });
           }

           // Add to audit trail
           final auditRef = organizerRef.collection('audit_trail').doc();
           batch.set(auditRef, {
             'actorId': adminId,
             'oldStatus': request.status.name,
             'newStatus': organizerStatus,
             'reason': reason,
             'timestamp': timestamp,
           });
         } else {
           AppLogger.warning('Skipping organizer update: organizerId is null or empty', 'AdminRepository');
         }
       } else {
         // Update the User document for user-level verifications (Identity, Student, Professional)
         if (request.userId == request.id) {
           AppLogger.warning('⚠️ CORRUPTION DETECTED: userId equals document id: ${request.id}', 'AdminRepository');
         }

         if (request.userId.isEmpty || request.userId.trim().isEmpty) {
           AppLogger.error('❌ Cannot process verification for user: EMPTY userId', null, null, 'AdminRepository');
           throw Exception('Invalid User ID for verification - userId is empty string. This verification document has corrupted data (missing userId field).');
         }
         
         final userRef = _firestore.collection('users').doc(request.userId);
         
         final Map<String, dynamic> userUpdate = {};

         if (request.type == AdminVerificationType.identity) {
           userUpdate['isIdentityVerified'] = newStatus == AdminVerificationStatus.approved;
           userUpdate['identityStatus'] = _statusToDb(newStatus);
         } else if (request.type == AdminVerificationType.student) {
           userUpdate['isStudentVerified'] = newStatus == AdminVerificationStatus.approved;
           userUpdate['studentStatus'] = _statusToDb(newStatus);
         } else if (request.type == AdminVerificationType.professional && newStatus == AdminVerificationStatus.approved) {
           // Add role to verifiedRoles
           if (request.role != null) {
             userUpdate['verifiedRoles'] = FieldValue.arrayUnion([request.role]);
           }
         }

         if (userUpdate.isNotEmpty) {
           batch.update(userRef, userUpdate);
         }
       }

       // 3. Commit changes
       await batch.commit();

       AppLogger.info('✅ Verification processed: ${request.type.name} for user ${request.userId} -> ${newStatus.name}', 'AdminRepository');

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
         metadata: {
           'userId': request.userId,
           'type': request.type.name,
           'newStatus': newStatus.name,
           'boost': trustBoost,
         },
       ));
     } catch (e, stack) {
       AppLogger.error('❌ Failed to process verification: $e', e, stack, 'AdminRepository');
       
       // Log failure to audit trail
       await logAction(AdminAuditLog(
         id: '',
         adminId: adminId,
         adminName: adminName,
         actionType: AdminActionType.bulkAction,
         targetId: request.id,
         targetType: 'verification_error',
         timestamp: DateTime.now(),
         reason: 'Verification processing failed: $e',
         metadata: {
           'userId': request.userId,
           'type': request.type.name,
           'error': e.toString(),
         },
       ));
       
       rethrow;
     }
  }

  String _getCollectionName(AdminVerificationType type) {
    switch (type) {
      case AdminVerificationType.identity: return 'identity_verifications';
      case AdminVerificationType.student: return 'student_verifications';
      case AdminVerificationType.professional: return 'verification_applications';
      case AdminVerificationType.organizer: return 'organizer_verification_requests';
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
          case ContentType.events:
            return ModeratedContent.fromEvent(Event.fromFirestore(doc));
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
    // Defense-in-depth: ensure caller is an admin
    if (!await _isUserAdmin(adminId)) {
      throw Exception('Unauthorized: Administrative privileges required.');
    }
    if (contentId.isEmpty) throw Exception('Invalid Content ID');
    final collection = _getCollectionForType(type);
    final docRef = _firestore.collection(collection).doc(contentId);
    
    await docRef.update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
      if (reason != null) 'moderationReason': reason,
    });

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
      case ContentType.events: return 'events';
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
          final reporterId = data['reporterId']?.toString() ?? '';
          
          if (reporterId.isEmpty) {
            AppLogger.warning('Report ${doc.id} missing reporterId', 'AdminRepository');
            continue;
          }

          ReportType rType = ReportType.marketplace;
          if (typeStr == 'feed_item') rType = ReportType.feedItem;
          if (typeStr == 'user') rType = ReportType.user;
          if (typeStr == 'note') rType = ReportType.note;
          if (typeStr == 'event') rType = ReportType.event;
          if (typeStr == 'chat') rType = ReportType.chat;

          reports.add(AdminReport(
            id: doc.id,
            reporterId: reporterId,
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
          final reporterId = data['reporterId']?.toString() ?? '';
          
          if (reporterId.isEmpty) {
            AppLogger.warning('Housing report ${doc.id} missing reporterId', 'AdminRepository');
            continue;
          }
          
          reports.add(AdminReport(
            id: doc.id,
            reporterId: reporterId,
            targetId: data['listingId'],
            reportedUserId: data['reportedUserId'],
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
      case 'under_review':
      case 'underReview':
        return ReportStatus.underReview;
      case 'resolved':
        return ReportStatus.resolved;
      case 'dismissed':
        return ReportStatus.dismissed;
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
    if (report.id.isEmpty) throw Exception('Invalid Report ID');
    
    // Defense-in-depth: Re-verify admin status for destructive actions
    if (!await _isUserAdmin(adminId)) {
      throw Exception('Unauthorized: Administrative privileges required.');
    }

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
      'lastAction': action,  // Track the specific action taken
      'history': FieldValue.arrayUnion([historyItem.toJson()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Perform Content/User Actions
    if (action == 'remove' && report.targetId != null && report.targetId!.isNotEmpty) {
      await _removeContent(batch, report.type, report.targetId!);
    } else if (action == 'warn' && report.reportedUserId != null && report.reportedUserId!.isNotEmpty) {
      // Notification handled in service
    } else if (action == 'suspend' && report.reportedUserId != null && report.reportedUserId!.isNotEmpty) {
      final until = timestamp.add(Duration(days: suspensionDays ?? 7));
      batch.update(_firestore.collection('users').doc(report.reportedUserId!), {
        'suspendedUntil': Timestamp.fromDate(until),
      });
    } else if (action == 'ban' && report.reportedUserId != null && report.reportedUserId!.isNotEmpty) {
      batch.update(_firestore.collection('users').doc(report.reportedUserId!), {
        'isBanned': true,
        'banReason': notes ?? report.reason,
      });
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
      metadata: {'action': action, 'targetId': report.targetId, 'reportedUserId': report.reportedUserId},
    ));
  }

  Future<void> _removeContent(WriteBatch batch, ReportType type, String targetId) async {
    if (type == ReportType.marketplace) {
      batch.update(_firestore.collection('listings').doc(targetId), {'status': 'removed'});
    } else if (type == ReportType.housing) {
      batch.update(_firestore.collection('housing_listings').doc(targetId), {'status': 'removed'});
    } else if (type == ReportType.feedItem) {
      batch.delete(_firestore.collection('feed').doc(targetId));
    } else if (type == ReportType.note) {
      batch.update(_firestore.collection('notes').doc(targetId), {'status': 'removed'});
    } else if (type == ReportType.event) {
      batch.update(_firestore.collection('events').doc(targetId), {'status': 'removed'});
    }
    // TODO: Notify content owner if possible
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
    if (userId.isEmpty) throw Exception('Invalid User ID');
    // Re-verify admin privileges
    if (!await _isUserAdmin(adminId)) {
      throw Exception('Unauthorized: Administrative privileges required.');
    }
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
    if (userId.isEmpty) throw Exception('Invalid User ID');
    
    // Defense-in-depth: Re-verify admin status for destructive actions
    if (!await _isUserAdmin(adminId)) {
      throw Exception('Unauthorized: Administrative privileges required.');
    }

    await _firestore.collection('users').doc(userId).update({
      'isBanned': isBanned,
      'banReason': isBanned ? reason : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

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
    if (userId.isEmpty) throw Exception('Invalid User ID');
    // Re-verify admin privileges
    if (!await _isUserAdmin(adminId)) {
      throw Exception('Unauthorized: Administrative privileges required.');
    }
    await _firestore.collection('users').doc(userId).update({
      'suspendedUntil': Timestamp.fromDate(until),
      'updatedAt': FieldValue.serverTimestamp(),
    });

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
    if (userId.isEmpty) throw Exception('Invalid User ID');
    // Re-verify admin privileges
    if (!await _isUserAdmin(adminId)) {
      throw Exception('Unauthorized: Administrative privileges required.');
    }
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
    if (userId.isEmpty) throw Exception('Invalid User ID');
    // Re-verify admin privileges
    if (!await _isUserAdmin(adminId)) {
      throw Exception('Unauthorized: Administrative privileges required.');
    }
    final batch = _firestore.batch();
    final userRef = _firestore.collection('users').doc(userId);
    
    batch.update(userRef, {
      'isIdentityVerified': false,
      'identityStatus': 'none',
      'isStudentVerified': false,
      'studentStatus': 'none',
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
    if (userId.isEmpty) throw Exception('Invalid User ID');
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
    if (userId.isEmpty) return [];
    
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
    if (userId.isEmpty) return [];
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
    if (userId.isEmpty) throw Exception('Invalid User ID');
    // Verify admin privileges
    if (!await _isUserAdmin(adminId)) {
      throw Exception('Unauthorized: Administrative privileges required.');
    }
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
     // Authorization check - defense in depth
     if (!await _isUserAdmin(adminId)) {
       throw Exception('Unauthorized: Administrative privileges required.');
     }

     AppLogger.info('=== BULK VERIFICATION PROCESSING === count: ${requests.length}', 'AdminRepository');

     final batch = _firestore.batch();
     final timestamp = FieldValue.serverTimestamp();
     double totalBoost = 0.0;
     int skipped = 0;
     int processed = 0;

     for (var request in requests) {
       if (request.id.isEmpty || request.id.trim().isEmpty) {
         AppLogger.warning('⚠️ Skipping verification with empty ID', 'AdminRepository');
         skipped++;
         continue;
       }
       
       if (request.userId.isEmpty || request.userId.trim().isEmpty) {
         AppLogger.warning('⚠️ Skipping verification with empty userId: id=${request.id}', 'AdminRepository');
         skipped++;
         continue;
       }
       
       final collectionName = _getCollectionName(request.type);
       if (collectionName.isEmpty) {
         AppLogger.warning('⚠️ Skipping verification with invalid type: ${request.type}', 'AdminRepository');
         skipped++;
         continue;
       }

       final boost = TrustEngine.getTrustBoost(request.type, status);
       totalBoost += boost;

       batch.update(_firestore.collection(collectionName).doc(request.id), {
         'status': _statusToDb(status),
         'updatedAt': timestamp,
         if (status == AdminVerificationStatus.approved) 'verifiedAt': timestamp,
         if (reason != null && reason.isNotEmpty) 'rejectionReason': reason,
       });

       // Update associated target (User or Organizer)
       if (request.type == AdminVerificationType.organizer) {
         final organizerId = request.metadata['organizerId']?.toString();
         if (organizerId != null && organizerId.isNotEmpty && organizerId.trim().isNotEmpty) {
           String organizerStatus = 'submitted';
           switch (status) {
             case AdminVerificationStatus.approved: organizerStatus = 'verified'; break;
             case AdminVerificationStatus.rejected: organizerStatus = 'rejected'; break;
             case AdminVerificationStatus.underReview: organizerStatus = 'underReview'; break;
             case AdminVerificationStatus.resubmissionRequested: organizerStatus = 'rejected'; break;
             case AdminVerificationStatus.pending: organizerStatus = 'submitted'; break;
           }
           
           batch.update(_firestore.collection('organizers').doc(organizerId), {
             'verificationStatus': organizerStatus,
             'updatedAt': timestamp,
             if (status == AdminVerificationStatus.approved) 'trustScore': FieldValue.increment(boost),
           });
           
           // Also update owner's trust score if approved
           final ownerId = request.metadata['ownerId']?.toString();
           if (ownerId != null && ownerId.isNotEmpty && ownerId.trim().isNotEmpty && status == AdminVerificationStatus.approved) {
             batch.update(_firestore.collection('users').doc(ownerId), {
               'trustScore': FieldValue.increment(boost),
             });
           }
         }
       } else {
         final userRef = _firestore.collection('users').doc(request.userId);
         
         if (request.type == AdminVerificationType.identity) {
           batch.update(userRef, {
             'isIdentityVerified': status == AdminVerificationStatus.approved,
             'identityStatus': _statusToDb(status),
           });
         } else if (request.type == AdminVerificationType.student) {
           batch.update(userRef, {
             'isStudentVerified': status == AdminVerificationStatus.approved,
             'studentStatus': _statusToDb(status),
           });
         } else if (request.type == AdminVerificationType.professional && status == AdminVerificationStatus.approved) {
            if (request.role != null) {
              batch.update(userRef, {
                'verifiedRoles': FieldValue.arrayUnion([request.role]),
              });
            }
         }
       }
       
       processed++;
     }

     AppLogger.info('📊 Bulk processing summary: $processed processed, $skipped skipped', 'AdminRepository');
     await batch.commit();

     await logAction(AdminAuditLog(
       id: '',
       adminId: adminId,
       adminName: adminName,
       actionType: AdminActionType.bulkAction,
       targetId: 'multiple',
       targetType: 'verification',
       timestamp: DateTime.now(),
       reason: 'Bulk ${status.name} of ${processed} verified requests (${skipped} skipped, Total Trust Boost: ${totalBoost.toStringAsFixed(1)})',
       metadata: {'count': processed, 'skipped': skipped, 'totalBoost': totalBoost, 'status': status.name},
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
    if (!await _isUserAdmin(adminId)) {
      throw Exception('Unauthorized: Administrative privileges required.');
    }

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
        // Optimization: Use cache and only fetch missing IDs
        final participantIds = conversations
            .map((c) => c.participants.firstWhere((p) => p != 'unihub_admin', orElse: () => ''))
            .where((id) => id.isNotEmpty)
            .toSet();
            
        final missingIds = participantIds.where((id) => !_userCache.containsKey(id)).toList();
        
        if (missingIds.isNotEmpty) {
          // Fetch in chunks of 30 due to whereIn limit
          const int chunkSize = 30;
          for (var i = 0; i < missingIds.length; i += chunkSize) {
            final end = (i + chunkSize < missingIds.length) ? i + chunkSize : missingIds.length;
            final chunk = missingIds.sublist(i, end);
            
            final usersSnap = await _firestore.collection('users').where(FieldPath.documentId, whereIn: chunk).get();
            for (var doc in usersSnap.docs) {
              _userCache[doc.id] = AppUser.fromJson(doc.data());
            }
          }
        }

        conversations = conversations.where((c) {
          final userId = c.participants.firstWhere((p) => p != 'unihub_admin', orElse: () => '');
          final user = _userCache[userId];
          if (user == null) return false;
          return user.fullName.toLowerCase().contains(searchLower) ||
                 user.email.toLowerCase().contains(searchLower) ||
                 (user.username?.toLowerCase().contains(searchLower) ?? false) ||
                 c.id.toLowerCase().contains(searchLower);
        }).toList();
      }

      conversations.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      return conversations;
    });
  }

  Future<void> updateSupportConversationStatus(String conversationId, String status, {required String adminId, required String adminName}) async {
    if (conversationId.isEmpty) throw Exception('Invalid Conversation ID');
    // Defense-in-depth: re-verify admin privileges
    if (!await _isUserAdmin(adminId)) {
      throw Exception('Unauthorized: Administrative privileges required.');
    }
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
  }

  Future<void> updateSupportConversationPriority(String conversationId, String priority, {required String adminId, required String adminName}) async {
    if (conversationId.isEmpty) throw Exception('Invalid Conversation ID');
    // Ensure caller is an admin
    if (!await _isUserAdmin(adminId)) {
      throw Exception('Unauthorized: Administrative privileges required.');
    }
    await _firestore.collection('conversations').doc(conversationId).update({
      'supportPriority': priority,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> assignSupportConversation(String conversationId, String? adminId, {required String adminName, required String performingAdminId}) async {
    if (conversationId.isEmpty) throw Exception('Invalid Conversation ID');
    // Verify the performing admin
    if (!await _isUserAdmin(performingAdminId)) {
      throw Exception('Unauthorized: Administrative privileges required.');
    }
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
    if (conversationId.isEmpty) throw Exception('Invalid Conversation ID');
    if (!await _isUserAdmin(adminId)) {
      throw Exception('Unauthorized: Administrative privileges required.');
    }
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

  // --- Event Approval Workflow ---

  Stream<List<Event>> watchSubmittedEvents({String? campusId, int limit = 50}) {
    Query query = _firestore.collection('events')
        .where('status', isEqualTo: 'submitted')
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (campusId != null && campusId.isNotEmpty) {
      query = query.where('campusId', isEqualTo: campusId);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList();
    });
  }

  Future<Event?> getSubmittedEvent(String eventId) async {
    final doc = await _firestore.collection('events').doc(eventId).get();
    if (!doc.exists) return null;
    return Event.fromFirestore(doc);
  }

  Future<void> approveEvent({
    required String eventId,
    required String adminId,
    String? reason,
  }) async {
    if (!await _isUserAdmin(adminId)) {
      throw Exception('Unauthorized: Administrative privileges required.');
    }

    final event = await getSubmittedEvent(eventId);
    if (event == null) throw Exception('Event not found');
    if (event.status != EventStatus.submitted) {
      throw Exception('Only submitted events can be approved');
    }

    // Update event status to approved
    await _firestore.collection('events').doc(eventId).update({
      'status': EventStatus.approved.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Notify organizer members
    final membersSnapshot = await _firestore
        .collection('organizers')
        .doc(event.organizerId)
        .collection('members')
        .get();

    for (final memberDoc in membersSnapshot.docs) {
      final memberData = memberDoc.data() as Map<String, dynamic>;
      final userId = memberData['userId'] as String?;
      if (userId != null) {
        // Queue notification (will be sent by Cloud Function or NotificationService)
        await _firestore.collection('notifications_queue').add({
          'recipientId': userId,
          'title': 'Event Approved! ✅',
          'body': 'Your event "${event.title}" has been approved and is now live on campus.',
          'type': 'events',
          'targetId': eventId,
          'targetType': 'event',
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
      }
    }

    // Log audit trail
    await logAction(AdminAuditLog(
      id: '',
      adminId: adminId,
      adminName: 'Admin',
      actionType: AdminActionType.eventApproval,
      targetId: eventId,
      targetType: 'event',
      timestamp: DateTime.now(),
      reason: reason ?? 'Event approved and published to campus',
    ));

    AppLogger.info('Event Approved: $eventId by Admin: $adminId', 'AdminRepository');
  }

  Future<void> rejectEvent({
    required String eventId,
    required String adminId,
    required String reason,
  }) async {
    if (!await _isUserAdmin(adminId)) {
      throw Exception('Unauthorized: Administrative privileges required.');
    }

    if (reason.trim().isEmpty) {
      throw Exception('Rejection reason is required');
    }

    final event = await getSubmittedEvent(eventId);
    if (event == null) throw Exception('Event not found');
    if (event.status != EventStatus.submitted) {
      throw Exception('Only submitted events can be rejected');
    }

    // Update event status to draft with rejection metadata
    await _firestore.collection('events').doc(eventId).update({
      'status': EventStatus.draft.name,
      'updatedAt': FieldValue.serverTimestamp(),
      'rejectionReason': reason,
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectedBy': adminId,
    });

    // Notify organizer members
    final membersSnapshot = await _firestore
        .collection('organizers')
        .doc(event.organizerId)
        .collection('members')
        .get();

    for (final memberDoc in membersSnapshot.docs) {
      final memberData = memberDoc.data() as Map<String, dynamic>;
      final userId = memberData['userId'] as String?;
      if (userId != null) {
        await _firestore.collection('notifications_queue').add({
          'recipientId': userId,
          'title': 'Event Needs Review ⚠️',
          'body': 'Your event "${event.title}" was not approved. Reason: $reason',
          'type': 'events',
          'targetId': eventId,
          'targetType': 'event',
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
      }
    }

    // Log audit trail
    await logAction(AdminAuditLog(
      id: '',
      adminId: adminId,
      adminName: 'Admin',
      actionType: AdminActionType.eventRejection,
      targetId: eventId,
      targetType: 'event',
      timestamp: DateTime.now(),
      reason: reason,
    ));

    AppLogger.info('Event Rejected: $eventId by Admin: $adminId. Reason: $reason', 'AdminRepository');
  }

  Future<void> bulkApproveEvents({
    required List<String> eventIds,
    required String adminId,
    String? reason,
  }) async {
    if (!await _isUserAdmin(adminId)) {
      throw Exception('Unauthorized: Administrative privileges required.');
    }

    for (final eventId in eventIds) {
      try {
        await approveEvent(eventId: eventId, adminId: adminId, reason: reason);
      } catch (e) {
        AppLogger.error('Failed to approve event $eventId', e, StackTrace.current, 'AdminRepository');
        rethrow;
      }
    }
  }

  Future<void> bulkRejectEvents({
    required List<String> eventIds,
    required String adminId,
    required String reason,
  }) async {
    if (!await _isUserAdmin(adminId)) {
      throw Exception('Unauthorized: Administrative privileges required.');
    }

    for (final eventId in eventIds) {
      try {
        await rejectEvent(eventId: eventId, adminId: adminId, reason: reason);
      } catch (e) {
        AppLogger.error('Failed to reject event $eventId', e, StackTrace.current, 'AdminRepository');
        rethrow;
      }
    }
  }
}
