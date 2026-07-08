import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unihub_mobile/core/services/notification_sender.dart';
import 'package:unihub_mobile/core/utils/app_logger.dart';
import '../../domain/models/verification_application.dart';
import '../../domain/models/professional_role.dart';
import '../../domain/models/student_verification.dart';
import '../../domain/models/identity_verification.dart';
import '../../domain/repositories/trust_repository.dart';

class TrustRepositoryImpl implements TrustRepository {
  final FirebaseFirestore _firestore;
  final NotificationSender? _notificationSender;

  TrustRepositoryImpl(this._firestore, [this._notificationSender]);

  @override
  Future<void> submitProfessionalApplication(VerificationApplication application) async {
    final batch = _firestore.batch();
    
    // 1. Create the professional application
    final appRef = _firestore.collection('verification_applications').doc(application.id);
    batch.set(appRef, application.toFirestore());

    // 2. If identity documents are provided, also create an identity verification record
    // this ensures the identity journey is also tracked.
    if (application.idDocumentUrl != null && application.selfieUrl != null) {
      final identityRef = _firestore.collection('identity_verifications').doc(application.userId);
      batch.set(identityRef, {
        'userId': application.userId,
        'idDocumentUrl': application.idDocumentUrl,
        'selfieUrl': application.selfieUrl,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'source': 'professional_application',
        'roleType': application.role.name,
      });

      // Update user status for immediate UI feedback
      batch.update(_firestore.collection('users').doc(application.userId), {
        'identityStatus': 'pending',
      });
    }

    await batch.commit();

    if (_notificationSender != null) {
      await _notificationSender!.notifyAdmins(
        title: 'New Professional Application 💼',
        body: 'A user has applied for the ${application.role.label} role.',
        route: '/admin/verifications',
      );
    }
  }

  @override
  Future<VerificationApplication?> getLatestApplication(String userId, ProfessionalRole role) async {
    final snapshot = await _firestore.collection('verification_applications')
        .where('userId', isEqualTo: userId)
        .where('role', isEqualTo: role.name)
        .get();
        
    if (snapshot.docs.isEmpty) return null;
    
    final apps = snapshot.docs
        .map((doc) => VerificationApplication.fromFirestore(doc))
        .toList();
        
    // Sort in memory to avoid requiring a composite index
    apps.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return apps.first;
  }

  @override
  Stream<List<VerificationApplication>> watchUserApplications(String userId) {
    return _firestore.collection('verification_applications')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final apps = snapshot.docs
            .map((doc) => VerificationApplication.fromFirestore(doc))
            .toList();
          // Sort in memory to avoid needing a composite index in Firestore
          apps.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return apps;
        });
  }

  @override
  Future<void> submitStudentVerification(String userId, String studentIdUrl) async {
    if (userId.isEmpty) {
      AppLogger.error('submitStudentVerification called with empty userId', null, null, 'TrustRepository');
      throw Exception('Invalid userId');
    }

    await _firestore.collection('student_verifications').doc(userId).set({
      'userId': userId,
      'studentIdUrl': studentIdUrl,
      'status': StudentVerificationStatus.pending.name,
      'submittedAt': FieldValue.serverTimestamp(),
    });

    // Also update the user document status for immediate UI feedback
    if (userId.isNotEmpty) {
      await _firestore.collection('users').doc(userId).update({
        'studentStatus': 'pending',
      });
    }

    if (_notificationSender != null) {
      await _notificationSender!.notifyAdmins(
        title: 'New Student Verification 🎓',
        body: 'A user has submitted their student ID for verification.',
        route: '/admin/verifications',
      );
    }
  }

  @override
  Future<StudentVerification?> getStudentVerification(String userId) async {
    if (userId.isEmpty) {
      AppLogger.warning('getStudentVerification called with empty userId', 'TrustRepository');
      return null;
    }

    try {
      final doc = await _firestore.collection('student_verifications').doc(userId).get();
      if (!doc.exists) return null;
      return StudentVerification.fromFirestore(doc);
    } catch (e, st) {
      AppLogger.error('Error getting StudentVerification for $userId', e, st, 'TrustRepository');
      return null;
    }
  }

  @override
  Stream<StudentVerification?> watchStudentVerification(String userId) {
    // Defensive: avoid calling .doc('') which causes Firestore exception
    if (userId.isEmpty) {
      AppLogger.warning('watchStudentVerification called with empty userId', 'TrustRepository');
      return Stream.value(null);
    }

    return _firestore.collection('student_verifications')
        .doc(userId)
        .snapshots()
        .map((doc) {
          try {
            if (!doc.exists) return null;
            return StudentVerification.fromFirestore(doc);
          } catch (e, st) {
            AppLogger.error('Error parsing StudentVerification for $userId', e, st, 'TrustRepository');
            return null;
          }
        });
  }

  @override
  Future<void> submitIdentityVerification(String userId, String idUrl, String selfieUrl) async {
    if (userId.isEmpty) {
      AppLogger.error('submitIdentityVerification called with empty userId', null, null, 'TrustRepository');
      throw Exception('Invalid userId');
    }

    await _firestore.collection('identity_verifications').doc(userId).set({
      'userId': userId,
      'idDocumentUrl': idUrl,
      'selfieUrl': selfieUrl,
      'status': IdentityVerificationStatus.pending.name,
      'submittedAt': FieldValue.serverTimestamp(),
    });
    
    // Also update the user document status for immediate UI feedback if needed
    if (userId.isNotEmpty) {
      await _firestore.collection('users').doc(userId).update({
        'identityStatus': 'pending',
      });
    } else {
      AppLogger.warning('Skipping users/{userId} update because userId is empty', 'TrustRepository');
    }

    if (_notificationSender != null) {
      await _notificationSender!.notifyAdmins(
        title: 'New Identity Verification 🛡️',
        body: 'A user has submitted identity documents and a selfie for review.',
        route: '/admin/verifications',
      );
    }
  }

  @override
  Future<IdentityVerification?> getIdentityVerification(String userId) async {
    if (userId.isEmpty) {
      AppLogger.warning('getIdentityVerification called with empty userId', 'TrustRepository');
      return null;
    }

    try {
      final doc = await _firestore.collection('identity_verifications').doc(userId).get();
      if (!doc.exists) return null;
      return IdentityVerification.fromFirestore(doc);
    } catch (e, st) {
      AppLogger.error('Error getting IdentityVerification for $userId', e, st, 'TrustRepository');
      return null;
    }
  }

  @override
  Stream<IdentityVerification?> watchIdentityVerification(String userId) {
    // Defensive: avoid calling .doc('') which causes Firestore exception
    if (userId.isEmpty) {
      AppLogger.warning('watchIdentityVerification called with empty userId', 'TrustRepository');
      return Stream.value(null);
    }

    return _firestore.collection('identity_verifications')
        .doc(userId)
        .snapshots()
        .map((doc) {
          try {
            if (!doc.exists) return null;
            return IdentityVerification.fromFirestore(doc);
          } catch (e, st) {
            AppLogger.error('Error parsing IdentityVerification for $userId', e, st, 'TrustRepository');
            return null;
          }
        });
  }

  @override
  Future<void> updateReputation(String userId, Map<String, dynamic> delta) async {
    if (userId.isEmpty) {
      AppLogger.error('updateReputation called with empty userId', null, null, 'TrustRepository');
      throw Exception('Invalid userId');
    }

    await _firestore.collection('users').doc(userId).update(delta);
  }
}
