enum AdminVerificationType { identity, student, professional }

enum AdminVerificationStatus { pending, underReview, approved, rejected, resubmissionRequested }

class AdminVerificationRequest {
  final String id;
  final String userId;
  final AdminVerificationType type;
  final AdminVerificationStatus status;
  final DateTime submittedAt;
  final String? rejectionReason;
  final String? adminNotes;
  
  // Details
  final String? fullName;
  final String? phoneNumber;
  final String? idDocumentUrl;
  final String? selfieUrl;
  final String? studentIdUrl;
  final String? role; // For professional
  final Map<String, dynamic> metadata;

  AdminVerificationRequest({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    required this.submittedAt,
    this.rejectionReason,
    this.adminNotes,
    this.fullName,
    this.phoneNumber,
    this.idDocumentUrl,
    this.selfieUrl,
    this.studentIdUrl,
    this.role,
    this.metadata = const {},
  });
}
