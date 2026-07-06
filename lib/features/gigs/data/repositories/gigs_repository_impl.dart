import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:unihub_mobile/features/chat/domain/models/conversation.dart';
import 'package:unihub_mobile/features/chat/domain/models/message.dart';
import 'package:unihub_mobile/features/chat/domain/models/chat_context.dart';
import 'package:unihub_mobile/services/notification_service.dart';
import 'package:unihub_mobile/core/services/notification_sender.dart';
import 'package:unihub_mobile/features/gigs/domain/models/gig_application.dart';
import 'package:unihub_mobile/features/gigs/domain/repositories/gigs_repository.dart';
import 'package:unihub_mobile/features/shared/notification_repository.dart';

class GigsRepositoryImpl implements GigsRepository {
  final FirebaseFirestore _firestore;
  final NotificationSender _notificationSender;

  GigsRepositoryImpl(this._firestore, this._notificationSender);

  @override
  Future<void> submitApplication(GigApplication application) async {
    // SECURITY: Ensure IDs are present to avoid Firestore path errors
    if (application.freelancerId.isEmpty) throw Exception('Your User ID is missing. Please log out and log back in.');
    if (application.employerId.isEmpty) throw Exception('This gig listing is invalid (missing owner ID). It may have been created in an older version of the app. Please try applying for a newer gig.');

    final batch = _firestore.batch();
    
    // 1. Determine conversation ID
    String conversationId = '';
    
    // Check if conversation already exists for this gig between these two
    final existing = await _firestore
        .collection('conversations')
        .where('participants', arrayContains: application.freelancerId)
        .where('context.id', isEqualTo: application.gigId)
        .where('context.type', isEqualTo: 'gig')
        .get();

    for (var doc in existing.docs) {
      final participants = List<String>.from(doc.data()['participants'] ?? []);
      if (participants.contains(application.freelancerId) && 
          participants.contains(application.employerId)) {
        conversationId = doc.id;
        break;
      }
    }

    if (conversationId.isEmpty) {
      final newConvRef = _firestore.collection('conversations').doc();
      conversationId = newConvRef.id;
      
      final Map<String, int> unreadCounts = {
        application.freelancerId: 0,
        application.employerId: 1,
      };

      final conversation = Conversation(
        id: conversationId,
        participants: [application.freelancerId, application.employerId],
        context: ChatContext(
          type: 'gig',
          id: application.gigId,
          title: application.gigTitle,
        ),
        lastMessageTime: DateTime.now(),
        unreadCounts: unreadCounts,
        lastMessage: 'New gig application from ${application.fullName}',
      );
      
      batch.set(newConvRef, conversation.toJson());
      
      // Send automated first message
      final msgRef = newConvRef.collection('messages').doc(const Uuid().v4());
      final message = Message(
        id: msgRef.id,
        senderId: application.freelancerId,
        content: "Hi, I've just applied for your gig: ${application.gigTitle}. Looking forward to discussing this with you!",
        timestamp: DateTime.now(),
      );
      batch.set(msgRef, message.toJson());
    }

    // 2. Save the application (with conversationId)
    final appRef = _firestore.collection('gig_applications').doc(application.id);
    final applicationData = application.toJson();
    applicationData['conversationId'] = conversationId;
    batch.set(appRef, applicationData);
    
    await batch.commit();
    
    // 3. Send in-app notification to employer
    await _notificationSender.sendNotification(
      recipientId: application.employerId,
      title: 'New Gig Application!',
      body: '${application.fullName} applied for "${application.gigTitle}"',
      type: NotificationType.gig,
      targetId: application.gigId,
      targetType: 'gig',
    );

    // 4. Send email (mock)
    await _firestore.collection('mail').add({
      'to': application.email,
      'message': {
        'subject': 'New Application for ${application.gigTitle}',
        'text': 'Applicant: ${application.fullName}\nGig: ${application.gigTitle}\nView details in UniHub app.',
      },
    });
  }

  @override
  Stream<List<GigApplication>> watchApplicationsForGig(String gigId) {
    return _firestore
        .collection('gig_applications')
        .where('gigId', isEqualTo: gigId)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => GigApplication.fromJson(doc.data()))
          .toList();
      // Sort in memory to avoid Firestore Composite Index requirements
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  @override
  Stream<List<GigApplication>> watchApplicationsForEmployer(String employerId) {
    return _firestore
        .collection('gig_applications')
        .where('employerId', isEqualTo: employerId)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => GigApplication.fromJson(doc.data()))
          .toList();
      // Sort in memory to avoid Firestore Composite Index requirements
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  @override
  Stream<List<GigApplication>> watchApplicationsForFreelancer(String freelancerId) {
    return _firestore
        .collection('gig_applications')
        .where('freelancerId', isEqualTo: freelancerId)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => GigApplication.fromJson(doc.data()))
          .toList();
      // Sort in memory to avoid Firestore Composite Index requirements
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  @override
  Future<void> updateApplicationStatus(String applicationId, ApplicationStatus status) async {
    await _firestore
        .collection('gig_applications')
        .doc(applicationId)
        .update({'status': status.name});

    // Send Notification to Applicant
    final appDoc = await _firestore.collection('gig_applications').doc(applicationId).get();
    if (appDoc.exists) {
      final freelancerId = appDoc.data()?['freelancerId'];
      final gigTitle = appDoc.data()?['gigTitle'];
      
      if (freelancerId != null) {
        await _notificationSender.sendNotification(
          recipientId: freelancerId,
          title: 'Application Update',
          body: 'Your application for "$gigTitle" was ${status.name}.',
          type: NotificationType.gig,
          targetId: applicationId,
          targetType: 'gig',
        );
      }
    }
  }

  @override
  Future<void> createGigPosting({
    required String gigId,
    required String employerId,
    required String title,
    required String description,
    required double budget,
    required DateTime deadline,
    required List<String> skillsRequired,
  }) async {
    await _firestore.collection('gigs').doc(gigId).set({
      'gigId': gigId,
      'employerId': employerId,
      'title': title,
      'description': description,
      'budget': budget,
      'deadline': deadline,
      'skillsRequired': skillsRequired,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'active',
    });

    await _notificationSender.sendNotification(
      recipientId: employerId,
      title: 'Gig Posted Successfully! 🎉',
      body: 'Your gig "$title" is now live.',
      type: NotificationType.gig,
      targetId: gigId,
      targetType: 'gig',
    );
  }

  @override
  Future<void> closeGigPosting(String gigId) async {
    final gigDoc = await _firestore.collection('gigs').doc(gigId).get();
    if (!gigDoc.exists) return;

    await _firestore.collection('gigs').doc(gigId).update({
      'status': 'closed',
      'closedAt': FieldValue.serverTimestamp(),
    });

    final employerId = gigDoc.data()?['employerId'];
    if (employerId != null) {
      await _notificationSender.sendNotification(
        recipientId: employerId,
        title: 'Gig Closed',
        body: 'Your gig "${gigDoc.data()?['title']}" has been closed.',
        type: NotificationType.gig,
        targetId: gigId,
        targetType: 'gig',
      );
    }
  }

  @override
  Future<void> rateFreelancer({
    required String freelancerId,
    required String gigId,
    required double rating,
    required String comment,
  }) async {
    await _firestore.collection('users').doc(freelancerId).collection('reviews').add({
      'gigId': gigId,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'freelancer',
    });

    final userDoc = await _firestore.collection('users').doc(freelancerId).get();
    if (userDoc.exists) {
      final data = userDoc.data() as Map<String, dynamic>;
      final currentAvg = (data['averageRating'] ?? 0.0).toDouble();
      final currentCount = (data['ratingsCount'] ?? 0).toInt();
      final newCount = currentCount + 1;
      final newAvg = ((currentAvg * currentCount) + rating) / newCount;

      await _firestore.collection('users').doc(freelancerId).update({
        'averageRating': newAvg,
        'ratingsCount': newCount,
      });
    }

    await _notificationSender.sendNotification(
      recipientId: freelancerId,
      title: 'You Have a New Review! ⭐',
      body: 'You received a $rating-star review on a gig.',
      type: NotificationType.gig,
      targetId: gigId,
      targetType: 'gig',
    );
  }

  @override
  Future<void> rateEmployer({
    required String employerId,
    required String gigId,
    required double rating,
    required String comment,
  }) async {
    await _firestore.collection('users').doc(employerId).collection('reviews').add({
      'gigId': gigId,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'employer',
    });

    final userDoc = await _firestore.collection('users').doc(employerId).get();
    if (userDoc.exists) {
      final data = userDoc.data() as Map<String, dynamic>;
      final currentAvg = (data['averageRating'] ?? 0.0).toDouble();
      final currentCount = (data['ratingsCount'] ?? 0).toInt();
      final newCount = currentCount + 1;
      final newAvg = ((currentAvg * currentCount) + rating) / newCount;

      await _firestore.collection('users').doc(employerId).update({
        'averageRating': newAvg,
        'ratingsCount': newCount,
      });
    }

    await _notificationSender.sendNotification(
      recipientId: employerId,
      title: 'You Have a New Review! ⭐',
      body: 'You received a $rating-star review on a gig.',
      type: NotificationType.gig,
      targetId: gigId,
      targetType: 'gig',
    );
  }

  @override
  Future<void> submitDispute({
    required String gigId,
    required String reporterId,
    required String reason,
    required String description,
  }) async {
    final disputeRef = _firestore.collection('gig_disputes').doc();
    await disputeRef.set({
      'disputeId': disputeRef.id,
      'gigId': gigId,
      'reporterId': reporterId,
      'reason': reason,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });

    await _notificationSender.notifyAdmins(
      title: 'New Gig Dispute 🚨',
      body: 'A dispute has been submitted for a gig.',
      route: '/admin/disputes',
    );
  }

  @override
  Stream<List<Map<String, dynamic>>> watchGigDisputes(String adminId) {
    return _firestore
        .collection('gig_disputes')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  @override
  Future<void> resolveDispute({
    required String disputeId,
    required String adminId,
    required String resolution,
  }) async {
    await _firestore.collection('gig_disputes').doc(disputeId).update({
      'status': 'resolved',
      'resolution': resolution,
      'resolvedBy': adminId,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> flagGig({
    required String gigId,
    required String reason,
    String? adminNotes,
  }) async {
    await _firestore.collection('gigs').doc(gigId).update({
      'flagged': true,
      'flagReason': reason,
      'flagAdminNotes': adminNotes,
      'flaggedAt': FieldValue.serverTimestamp(),
    });

    final gigDoc = await _firestore.collection('gigs').doc(gigId).get();
    if (gigDoc.exists) {
      await _notificationSender.notifyAdmins(
        title: 'Gig Flagged 🚩',
        body: 'Reason: $reason',
        route: '/admin/flags/gigs',
      );
    }
  }

  @override
  Future<void> removeGig({
    required String gigId,
    required String reason,
    required String adminId,
  }) async {
    final gigDoc = await _firestore.collection('gigs').doc(gigId).get();
    if (!gigDoc.exists) return;

    await _firestore.collection('gigs').doc(gigId).update({
      'status': 'removed',
      'removedReason': reason,
      'removedBy': adminId,
      'removedAt': FieldValue.serverTimestamp(),
    });

    final employerId = gigDoc.data()?['employerId'];
    if (employerId != null) {
      await _notificationSender.sendNotification(
        recipientId: employerId,
        title: 'Gig Removed',
        body: 'Your gig has been removed. Reason: $reason',
        type: NotificationType.gig,
        targetId: gigId,
        targetType: 'gig',
      );
    }
  }

  @override
  Future<void> suspendFreelancer({
    required String freelancerId,
    required String reason,
    required String adminId,
  }) async {
    await _firestore.collection('users').doc(freelancerId).update({
      'isSuspended': true,
      'suspensionReason': reason,
      'suspendedBy': adminId,
      'suspendedAt': FieldValue.serverTimestamp(),
    });

    await _notificationSender.sendNotification(
      recipientId: freelancerId,
      title: 'Account Suspended',
      body: 'Your account has been suspended. Reason: $reason',
      type: NotificationType.system,
      targetId: freelancerId,
      targetType: 'account',
    );
  }

  @override
  Stream<List<Map<String, dynamic>>> watchFlaggedGigs(String campusId) {
    return _firestore
        .collection('gigs')
        .where('flagged', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
