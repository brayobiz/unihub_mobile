import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/professional_role.dart';
import '../../../admin/domain/models/verification_request.dart';

class TrustEngine {
  static const double identityBoost = 30.0;
  static const double studentBoost = 20.0;
  static const double professionalBoost = 15.0;
  static const double organizerApprovalBoost = 50.0;
  static const double organizerOwnerBonus = 10.0;

  /// Calculates the delta to be added to the trustScore based on verification type and status.
  static double getTrustBoost(AdminVerificationType type, AdminVerificationStatus status) {
    if (status != AdminVerificationStatus.approved) return 0.0;

    switch (type) {
      case AdminVerificationType.identity:
        return identityBoost;
      case AdminVerificationType.student:
        return studentBoost;
      case AdminVerificationType.professional:
        return professionalBoost;
      case AdminVerificationType.organizer:
        return organizerApprovalBoost;
    }
  }

  /// Maps AdminVerificationStatus to the corresponding database field value for users.
  static String mapVerificationStatusToDb(AdminVerificationStatus status) {
    return status.name;
  }
}
