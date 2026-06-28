import 'package:cloud_firestore/cloud_firestore.dart';

enum StudentVerificationStatus { pending, approved, rejected, expired }

class StudentVerification {
  final String id;
  final String userId;
  final StudentVerificationStatus status;
  final String studentIdUrl;
  final String? rejectionReason;
  final DateTime submittedAt;
  final DateTime? verifiedAt;

  StudentVerification({
    required this.id,
    required this.userId,
    required this.status,
    required this.studentIdUrl,
    this.rejectionReason,
    required this.submittedAt,
    this.verifiedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'status': status.name,
      'studentIdUrl': studentIdUrl,
      'rejectionReason': rejectionReason,
      'submittedAt': submittedAt,
      'verifiedAt': verifiedAt,
    };
  }

  factory StudentVerification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudentVerification(
      id: doc.id,
      userId: data['userId'] ?? '',
      status: StudentVerificationStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => StudentVerificationStatus.pending,
      ),
      studentIdUrl: data['studentIdUrl'] ?? '',
      rejectionReason: data['rejectionReason'],
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      verifiedAt: (data['verifiedAt'] as Timestamp?)?.toDate(),
    );
  }
}
