import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/organizer.dart';
import '../models/organizer_member.dart';
import '../repositories/organizer_repository.dart';
import 'package:unihub_mobile/services/notification_service.dart';
import 'package:unihub_mobile/core/services/notification_sender.dart';
import 'package:unihub_mobile/features/shared/domain/models/uni_notification.dart';

class OrganizerService {
  final OrganizerRepository _repository;
  final FirebaseFirestore _firestore;
  final NotificationSender _notificationSender;

  OrganizerService(this._repository, this._firestore, this._notificationSender);

  // --- State Machine & Application Logic ---

  /// Strictly enforces one application per user identity at a time.
  Future<Organizer?> getActiveApplication(String userId) async {
    // We check organizers where the user is owner and it hasn't been fully verified or permanently closed.
    // Use timeout to prevent hanging if Firestore indexes are missing.
    try {
      final managed = await _repository.watchUserManagedOrganizers(userId).first.timeout(const Duration(seconds: 10));
      return managed.firstWhere((o) => 
        o.ownerId == userId && 
        (o.verificationStatus == OrganizerVerificationStatus.draft ||
         o.verificationStatus == OrganizerVerificationStatus.submitted ||
         o.verificationStatus == OrganizerVerificationStatus.underReview ||
         o.verificationStatus == OrganizerVerificationStatus.rejected)
      );
    } catch (e) {
      // If index is missing, Firestore might throw a specific exception. 
      // Catching all to ensure we don't hang the UI.
      return null;
    }
  }

  Future<void> createApplication(Organizer organizer, String userId) async {
    // 1. Enforce Identity Verification Requirement (Core Trust Rule)
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final isIdentityVerified = userDoc.data()?['isIdentityVerified'] ?? false;
    
    if (!isIdentityVerified) {
      throw Exception('Identity verification is required before applying as an organizer. Please complete it in the Trust Center.');
    }

    // 2. Prevent duplicate active applications
    final existing = await getActiveApplication(userId);
    if (existing != null) {
      if (existing.verificationStatus == OrganizerVerificationStatus.rejected) {
        throw Exception('You have a previously rejected application. Please update and resubmit it from your dashboard.');
      }
      throw Exception('You already have an active organizer application in progress.');
    }

    // 3. Initial state is always Submitted
    final application = organizer.copyWith(
      verificationStatus: OrganizerVerificationStatus.submitted,
      updatedAt: DateTime.now(),
    );

    // 4. Atomic Persistence using Batch
    final batch = _firestore.batch();
    
    // Create Organizer
    final organizerRef = _firestore.collection('organizers').doc(application.id);
    batch.set(organizerRef, application.toFirestore());
    
    // Add owner as a member
    final memberId = '${application.id}_$userId';
    final memberRef = organizerRef.collection('members').doc(memberId);
    batch.set(memberRef, {
      'organizerId': application.id,
      'userId': userId,
      'role': OrganizerRole.owner.name,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    
    // Add to verification queue
    final requestRef = _firestore.collection('organizer_verification_requests').doc();
    batch.set(requestRef, {
      'organizerId': application.id,
      'status': 'pending',
      'type': 'organizer',
      'name': application.name,
      'campusId': application.campusId,
      'ownerId': userId,
      'submittedAt': FieldValue.serverTimestamp(),
    });

    try {
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to submit application: $e');
    }
    
    // 5. Notify Admins (Background)
    _notificationSender.notifyAdmins(
      title: 'New Organizer Application 🏢',
      body: '${application.name} has applied to be an organizer on campus.',
      route: '/admin/verifications',
    ).catchError((e) => null); // Non-blocking
  }

  Future<void> resubmitApplication(String organizerId, String userId) async {
    final organizer = await _repository.getOrganizerById(organizerId);
    if (organizer == null) throw Exception('Application not found');
    if (organizer.ownerId != userId) throw Exception('Unauthorized');
    
    if (organizer.verificationStatus != OrganizerVerificationStatus.rejected && 
        organizer.verificationStatus != OrganizerVerificationStatus.draft) {
      throw Exception('Only rejected or draft applications can be resubmitted.');
    }

    await _firestore.collection('organizers').doc(organizerId).update({
      'verificationStatus': OrganizerVerificationStatus.submitted.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Notify moderation queue
    await _repository.requestVerification(organizerId, {
      'status': 'pending', // Reset verification request status for admin to see
      'resubmittedAt': FieldValue.serverTimestamp(),
      'ownerId': userId,
    });
  }

  // Membership Management
  Future<void> inviteMember(String organizerId, String emailOrUid, OrganizerRole role, String inviterId) async {
    // 1. Authorization check
    final inviter = await _getMember(organizerId, inviterId);
    if (inviter == null || (inviter.role != OrganizerRole.owner && inviter.role != OrganizerRole.administrator)) {
      throw Exception('Unauthorized: Only owners and administrators can invite members.');
    }

    // 2. Find User
    QuerySnapshot userSearch;
    if (emailOrUid.contains('@')) {
      userSearch = await _firestore.collection('users').where('email', isEqualTo: emailOrUid).limit(1).get();
    } else {
      userSearch = await _firestore.collection('users').where(FieldPath.documentId, isEqualTo: emailOrUid).get();
    }

    if (userSearch.docs.isEmpty) {
      throw Exception('User not found. Please ensure the email or ID is correct.');
    }

    final targetUserDoc = userSearch.docs.first;
    final targetUserId = targetUserDoc.id;
    final targetData = targetUserDoc.data() as Map<String, dynamic>;

    // 3. Check for existing membership
    final existingMembers = await _repository.getOrganizerMembers(organizerId);
    if (existingMembers.any((m) => m.userId == targetUserId)) {
      throw Exception('User is already a member of this organization.');
    }

    // 4. Create Membership
    final member = OrganizerMember(
      id: '${organizerId}_$targetUserId',
      organizerId: organizerId,
      userId: targetUserId,
      userName: targetData['fullName'] ?? 'UniHub User',
      userPhotoUrl: targetData['photoUrl'],
      role: role,
      joinedAt: DateTime.now(),
    );
    
    await _repository.addMember(member);

    // 5. Notify User
    final organizer = await _repository.getOrganizerById(organizerId);
    await _notificationSender.sendNotification(
      recipientId: targetUserId,
      title: 'New Team Invitation 👥',
      body: 'You have been added to "${organizer?.name ?? 'an organization'}" as an ${role.name}.',
      type: NotificationType.events,
      targetId: organizerId,
      targetType: 'organizer',
    );
  }

  Future<void> updateMemberRole(String organizerId, String actorId, String targetUserId, OrganizerRole newRole) async {
    // DEFENSIVE: Validate parameters
    if (organizerId.isEmpty || organizerId.trim().isEmpty) {
      throw Exception('Invalid organizerId: cannot be empty');
    }
    if (actorId.isEmpty || actorId.trim().isEmpty) {
      throw Exception('Invalid actorId: cannot be empty');
    }
    if (targetUserId.isEmpty || targetUserId.trim().isEmpty) {
      throw Exception('Invalid targetUserId: cannot be empty');
    }

    final actor = await _getMember(organizerId, actorId);
    if (actor == null || (actor.role != OrganizerRole.owner && actor.role != OrganizerRole.administrator)) {
      throw Exception('Unauthorized: Only owners and administrators can change roles');
    }
    
    if (newRole == OrganizerRole.owner && actor.role != OrganizerRole.owner) {
      throw Exception('Unauthorized: Only the owner can transfer ownership');
    }

    await _repository.updateMemberRole(organizerId, targetUserId, newRole);
  }

  Future<void> removeMember(String organizerId, String actorId, String targetUserId) async {
    // DEFENSIVE: Validate parameters
    if (organizerId.isEmpty || organizerId.trim().isEmpty) {
      throw Exception('Invalid organizerId: cannot be empty');
    }
    if (actorId.isEmpty || actorId.trim().isEmpty) {
      throw Exception('Invalid actorId: cannot be empty');
    }
    if (targetUserId.isEmpty || targetUserId.trim().isEmpty) {
      throw Exception('Invalid targetUserId: cannot be empty');
    }

    final actor = await _getMember(organizerId, actorId);
    final target = await _getMember(organizerId, targetUserId);
    
    if (actor == null) throw Exception('Actor not found');
    if (target == null) return; // Already removed

    bool canRemove = false;
    if (actor.role == OrganizerRole.owner) canRemove = true;
    if (actor.role == OrganizerRole.administrator && target.role == OrganizerRole.editor) canRemove = true;
    if (actor.userId == targetUserId) canRemove = true; // Self-remove

    if (!canRemove) throw Exception('Unauthorized to remove this member');
    if (target.role == OrganizerRole.owner && actorId != targetUserId) {
      throw Exception('Cannot remove the owner');
    }

    await _repository.removeMember(organizerId, targetUserId);
  }

  // Verification Workflow
  Future<void> submitForReview(String organizerId, String userId) async {
    // DEFENSIVE: Validate parameters
    if (organizerId.isEmpty || organizerId.trim().isEmpty) {
      throw Exception('Invalid organizerId: cannot be empty');
    }
    if (userId.isEmpty || userId.trim().isEmpty) {
      throw Exception('Invalid userId: cannot be empty');
    }

    final organizer = await _repository.getOrganizerById(organizerId);
    if (organizer == null) throw Exception('Organizer not found');
    
    final member = await _getMember(organizerId, userId);
    if (member == null || (member.role != OrganizerRole.owner && member.role != OrganizerRole.administrator)) {
      throw Exception('Unauthorized to submit for review');
    }

    // STATE MACHINE: Enforce valid transitions
    final currentStatus = organizer.verificationStatus;
    final allowedTransitions = {
      OrganizerVerificationStatus.draft,
      OrganizerVerificationStatus.rejected,
      OrganizerVerificationStatus.withdrawn,
    };

    if (!allowedTransitions.contains(currentStatus)) {
      throw Exception(
        'Cannot submit for review from status: ${currentStatus.name}. '
        'Only draft or rejected applications can be resubmitted.'
      );
    }

    await _firestore.collection('organizers').doc(organizerId).update({
      'verificationStatus': OrganizerVerificationStatus.underReview.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _repository.requestVerification(organizerId, {
      'type': 'organizer',
      'status': 'pending',
      'submittedAt': FieldValue.serverTimestamp(),
      'ownerId': userId,
    });

    // Log to audit trail
    await _logAudit(
      organizerId: organizerId,
      actorId: userId,
      oldStatus: currentStatus,
      newStatus: OrganizerVerificationStatus.underReview,
      reason: 'Submitted for verification',
    );
  }

  Future<void> withdrawApplication(String organizerId, String userId) async {
    final organizer = await _repository.getOrganizerById(organizerId);
    if (organizer == null) throw Exception('Organizer not found');
    if (organizer.ownerId != userId) throw Exception('Unauthorized');

    final currentStatus = organizer.verificationStatus;
    if (currentStatus != OrganizerVerificationStatus.submitted && 
        currentStatus != OrganizerVerificationStatus.underReview) {
      throw Exception('Only submitted or under-review applications can be withdrawn.');
    }

    await _firestore.collection('organizers').doc(organizerId).update({
      'verificationStatus': OrganizerVerificationStatus.withdrawn.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _logAudit(
      organizerId: organizerId,
      actorId: userId,
      oldStatus: currentStatus,
      newStatus: OrganizerVerificationStatus.withdrawn,
      reason: 'Application withdrawn by owner',
    );
  }

  Future<void> adminUpdateStatus({
    required String organizerId,
    required String adminId,
    required OrganizerVerificationStatus newStatus,
    String? reason,
  }) async {
    // Verify admin privileges
    final adminDoc = await _firestore.collection('users').doc(adminId).get();
    final adminData = adminDoc.data() as Map<String, dynamic>?;
    final isAdminFlag = adminData?['isAdmin'] ?? false;
    final roles = List<String>.from(adminData?['roles'] ?? []);
    if (!isAdminFlag && !roles.contains('admin')) {
      throw Exception('Unauthorized: Administrative privileges required.');
    }
    final organizer = await _repository.getOrganizerById(organizerId);
    if (organizer == null) throw Exception('Organizer not found');

    await _firestore.collection('organizers').doc(organizerId).update({
      'verificationStatus': newStatus.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _logAudit(
      organizerId: organizerId,
      actorId: adminId,
      oldStatus: organizer.verificationStatus,
      newStatus: newStatus,
      reason: reason,
    );

    // Notify owner and administrators
    final members = await _repository.getOrganizerMembers(organizerId);
    for (final member in members) {
      if (member.role == OrganizerRole.owner || member.role == OrganizerRole.administrator) {
        String title = '';
        String body = '';
        
        switch (newStatus) {
          case OrganizerVerificationStatus.verified:
            title = 'Organizer Verified! 🎊';
            body = 'Your organization "${organizer.name}" has been verified. You can now publish events to your campus.';
            break;
          case OrganizerVerificationStatus.official:
            title = 'Official Status Granted 👑';
            body = 'Congratulations! "${organizer.name}" is now an Official Organizer on UniHub.';
            break;
          case OrganizerVerificationStatus.rejected:
            title = 'Application Needs Attention ⚠️';
            body = 'Your organizer application for "${organizer.name}" was not approved. Reason: ${reason ?? "Please review your details"}.';
            break;
          case OrganizerVerificationStatus.suspended:
            title = 'Organization Suspended ⚠️';
            body = 'Your organization "${organizer.name}" has been suspended. Reason: ${reason ?? "Guideline violation"}.';
            break;
          default: break;
        }

        if (title.isNotEmpty) {
          await _notificationSender.sendNotification(
            recipientId: member.userId,
            title: title,
            body: body,
            type: NotificationType.events,
            targetId: organizerId,
            targetType: 'organizer',
          );
        }
      }
    }
  }

  // Permissions Engine
  Future<bool> canPublishEvents(String organizerId, String userId) async {
    final organizer = await _repository.getOrganizerById(organizerId);
    if (organizer == null) return false;

    // Check status
    if (organizer.verificationStatus == OrganizerVerificationStatus.suspended) return false;
    
    // Only Verified or Official can publish (MVP rule)
    // Pending can only create drafts (handled in UI/Controller)
    bool statusAllows = organizer.verificationStatus == OrganizerVerificationStatus.verified || 
                         organizer.verificationStatus == OrganizerVerificationStatus.official;
    
    if (!statusAllows) return false;

    // Check membership
    final member = await _getMember(organizerId, userId);
    return member != null; // Any member can publish if organizer is verified
  }

  // Helpers
  Future<OrganizerMember?> _getMember(String organizerId, String userId) async {
    return _repository.getMember(organizerId, userId);
  }

  Future<void> _logAudit({
    required String organizerId,
    required String actorId,
    required OrganizerVerificationStatus oldStatus,
    required OrganizerVerificationStatus newStatus,
    String? reason,
  }) async {
    await _firestore.collection('organizers').doc(organizerId).collection('audit_trail').add({
      'actorId': actorId,
      'oldStatus': oldStatus.name,
      'newStatus': newStatus.name,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
