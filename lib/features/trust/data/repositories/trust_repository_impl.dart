import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/verification_application.dart';
import '../../domain/models/professional_role.dart';
import '../../domain/models/student_verification.dart';
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
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
        
    if (snapshot.docs.isEmpty) return null;
    return VerificationApplication.fromFirestore(snapshot.docs.first);
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
  Future<void> updateReputation(String userId, Map<String, dynamic> delta) async {
    await _firestore.collection('users').doc(userId).update(delta);
  }
}
