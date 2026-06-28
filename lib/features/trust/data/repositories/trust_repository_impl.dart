import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/verification_application.dart';
import '../../domain/models/professional_role.dart';
import '../../domain/models/student_verification.dart';
import '../../domain/models/identity_verification.dart';
import '../../domain/repositories/trust_repository.dart';

class TrustRepositoryImpl implements TrustRepository {
  final FirebaseFirestore _firestore;

  TrustRepositoryImpl(this._firestore);

  @override
  Future<void> submitProfessionalApplication(VerificationApplication application) async {
    await _firestore.collection('verification_applications').doc(application.id).set(
      application.toFirestore(),
    );
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
    await _firestore.collection('student_verifications').doc(userId).set({
      'userId': userId,
      'studentIdUrl': studentIdUrl,
      'status': StudentVerificationStatus.pending.name,
      'submittedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<StudentVerification?> getStudentVerification(String userId) async {
    final doc = await _firestore.collection('student_verifications').doc(userId).get();
    if (!doc.exists) return null;
    return StudentVerification.fromFirestore(doc);
  }

  @override
  Stream<StudentVerification?> watchStudentVerification(String userId) {
    return _firestore.collection('student_verifications')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? StudentVerification.fromFirestore(doc) : null);
  }

  @override
  Future<void> submitIdentityVerification(String userId, String idUrl, String selfieUrl) async {
    await _firestore.collection('identity_verifications').doc(userId).set({
      'userId': userId,
      'idDocumentUrl': idUrl,
      'selfieUrl': selfieUrl,
      'status': IdentityVerificationStatus.pending.name,
      'submittedAt': FieldValue.serverTimestamp(),
    });
    
    // Also update the user document status for immediate UI feedback if needed
    await _firestore.collection('users').doc(userId).update({
      'identityStatus': 'pending',
    });
  }

  @override
  Future<IdentityVerification?> getIdentityVerification(String userId) async {
    final doc = await _firestore.collection('identity_verifications').doc(userId).get();
    if (!doc.exists) return null;
    return IdentityVerification.fromFirestore(doc);
  }

  @override
  Stream<IdentityVerification?> watchIdentityVerification(String userId) {
    return _firestore.collection('identity_verifications')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? IdentityVerification.fromFirestore(doc) : null);
  }

  @override
  Future<void> updateReputation(String userId, Map<String, dynamic> delta) async {
    await _firestore.collection('users').doc(userId).update(delta);
  }
}
