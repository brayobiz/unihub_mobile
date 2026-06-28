import 'package:cloud_firestore/cloud_firestore.dart';

enum IdentityVerificationStatus { none, pending, approved, rejected }

class IdentityVerification {
  final String userId;
  final IdentityVerificationStatus status;
  final String idDocumentUrl;
  final String selfieUrl;
  final String? rejectionReason;
  final DateTime submittedAt;
  final DateTime? verifiedAt;

  IdentityVerification({
    required this.userId,
    required this.status,
    required this.idDocumentUrl,
    required this.selfieUrl,
    this.rejectionReason,
    required this.submittedAt,
    this.verifiedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'status': status.name,
      'idDocumentUrl': idDocumentUrl,
      'selfieUrl': selfieUrl,
      'rejectionReason': rejectionReason,
      'submittedAt': submittedAt,
      'verifiedAt': verifiedAt,
    };
  }

  factory IdentityVerification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return IdentityVerification(
      userId: data['userId'] ?? '',
      status: IdentityVerificationStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => IdentityVerificationStatus.none,
      ),
      idDocumentUrl: data['idDocumentUrl'] ?? '',
      selfieUrl: data['selfieUrl'] ?? '',
      rejectionReason: data['rejectionReason'],
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      verifiedAt: (data['verifiedAt'] as Timestamp?)?.toDate(),
    );
  }
}
