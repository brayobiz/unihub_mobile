import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../chat/domain/models/conversation.dart';
import '../../../chat/domain/models/message.dart';
import '../../../shared/notification_repository.dart';
import '../../domain/models/gig_application.dart';
import '../../domain/repositories/gigs_repository.dart';

class GigsRepositoryImpl implements GigsRepository {
  final FirebaseFirestore _firestore;
  final NotificationRepository _notificationRepository;

  GigsRepositoryImpl(this._firestore, this._notificationRepository);

  @override
  Future<void> submitApplication(GigApplication application) async {
    // SECURITY: Ensure IDs are present to avoid Firestore path errors
    if (application.freelancerId.isEmpty) throw Exception('Your User ID is missing. Please log out and log back in.');
    if (application.employerId.isEmpty) throw Exception('This gig listing is invalid (missing owner ID). It may have been created in an older version of the app. Please try applying for a newer gig.');

    final batch = _firestore.batch();
    
    // 1. Determine conversation ID
    String conversationId = '';
    
    // Check if conversation already exists for this gig between these two
    // Filter by gigId first, then filter by participant in memory to avoid index requirements
    final existing = await _firestore
        .collection('conversations')
        .where('gigId', isEqualTo: application.gigId)
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
      
      // Fix for unreadCounts keys: Firestore keys cannot be empty strings
      final Map<String, int> unreadCounts = {
        application.freelancerId: 0,
        application.employerId: 1,
      };

      final conversation = Conversation(
        id: conversationId,
        participants: [application.freelancerId, application.employerId],
        gigId: application.gigId,
        listingTitle: application.gigTitle,
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
    await _notificationRepository.sendNotification(
      userId: application.employerId,
      title: 'New Gig Application!',
      body: '${application.fullName} applied for "${application.gigTitle}"',
      type: 'gig',
      relatedId: application.gigId,
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
        await _notificationRepository.sendNotification(
          userId: freelancerId,
          title: 'Application Update',
          body: 'Your application for "$gigTitle" was ${status.name}.',
          type: 'gig',
          relatedId: applicationId,
        );
      }
    }
  }
}
