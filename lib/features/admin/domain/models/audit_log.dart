import 'package:cloud_firestore/cloud_firestore.dart';

enum AdminActionType {
  verificationApproval,
  verificationRejection,
  userBan,
  userRestore,
  userSuspension,
  userRoleUpdate,
  contentRemoval,
  contentRestore,
  reportResolution,
  reportDismissal,
  trustScoreAdjustment,
  bulkAction,
}

class AdminAuditLog {
  final String id;
  final String adminId;
  final String adminName;
  final AdminActionType actionType;
  final String targetId; // ID of the user, listing, or report
  final String targetType; // 'user', 'listing', 'report', etc.
  final DateTime timestamp;
  final String? reason;
  final Map<String, dynamic>? metadata;

  AdminAuditLog({
    required this.id,
    required this.adminId,
    required this.adminName,
    required this.actionType,
    required this.targetId,
    required this.targetType,
    required this.timestamp,
    this.reason,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'adminId': adminId,
      'adminName': adminName,
      'actionType': actionType.name,
      'targetId': targetId,
      'targetType': targetType,
      'timestamp': Timestamp.fromDate(timestamp),
      'reason': reason,
      'metadata': metadata,
    };
  }

  factory AdminAuditLog.fromJson(String id, Map<String, dynamic> json) {
    return AdminAuditLog(
      id: id,
      adminId: json['adminId'] ?? '',
      adminName: json['adminName'] ?? 'Admin',
      actionType: AdminActionType.values.firstWhere(
        (e) => e.name == json['actionType'],
        orElse: () => AdminActionType.bulkAction,
      ),
      targetId: json['targetId'] ?? '',
      targetType: json['targetType'] ?? '',
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reason: json['reason'],
      metadata: json['metadata'],
    );
  }
}
