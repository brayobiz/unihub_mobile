import 'package:cloud_firestore/cloud_firestore.dart';
import 'professional_role.dart';

enum VerificationStatus { pending, underReview, approved, rejected, expired, resubmissionRequested }

class VerificationApplication {
  final String id;
  final String userId;
  final ProfessionalRole role;
  final VerificationStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? rejectionReason;
  
  // Generic fields for most applications
  final String fullName;
  final String phoneNumber;
  final String? idDocumentUrl;
  final String? selfieUrl;
  
  // Flexible metadata for role-specific requirements
  final Map<String, dynamic> metadata;

  VerificationApplication({
    required this.id,
    required this.userId,
    required this.role,
    this.status = VerificationStatus.pending,
    required this.createdAt,
    this.updatedAt,
    this.rejectionReason,
    required this.fullName,
    required this.phoneNumber,
    this.idDocumentUrl,
    this.selfieUrl,
    this.metadata = const {},
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'role': role.name,
      'status': status.name,
      'createdAt': createdAt,
      'updatedAt': FieldValue.serverTimestamp(),
      'rejectionReason': rejectionReason,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'idDocumentUrl': idDocumentUrl,
      'selfieUrl': selfieUrl,
      'metadata': metadata,
    };
  }

  factory VerificationApplication.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return VerificationApplication(
      id: doc.id,
      userId: (data['userId'] ?? '').toString(),
      role: ProfessionalRole.values.firstWhere(
        (e) => e.name == data['role'],
        orElse: () => ProfessionalRole.seller,
      ),
      status: VerificationStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => VerificationStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      rejectionReason: data['rejectionReason']?.toString(),
      fullName: (data['fullName'] ?? '').toString(),
      phoneNumber: (data['phoneNumber'] ?? '').toString(),
      idDocumentUrl: data['idDocumentUrl']?.toString(),
      selfieUrl: data['selfieUrl']?.toString(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }
}
