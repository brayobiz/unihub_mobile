import 'package:cloud_firestore/cloud_firestore.dart';

enum SubscriptionTier { free, studentPro, businessBasic, businessPremium }
enum SubscriptionStatus { active, expired, cancelled, pastDue }

class SubscriptionRecord {
  final String id;
  final String userId;
  final SubscriptionTier tier;
  final SubscriptionStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final bool autoRenew;
  final String? lastPaymentId;
  
  final DateTime createdAt;
  final DateTime updatedAt;

  SubscriptionRecord({
    required this.id,
    required this.userId,
    required this.tier,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.autoRenew = false,
    this.lastPaymentId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'tier': tier.name,
      'status': status.name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'autoRenew': autoRenew,
      'lastPaymentId': lastPaymentId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory SubscriptionRecord.fromJson(Map<String, dynamic> json) {
    return SubscriptionRecord(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      tier: SubscriptionTier.values.firstWhere(
        (e) => e.name == json['tier'],
        orElse: () => SubscriptionTier.free,
      ),
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SubscriptionStatus.active,
      ),
      startDate: (json['startDate'] as Timestamp).toDate(),
      endDate: (json['endDate'] as Timestamp).toDate(),
      autoRenew: json['autoRenew'] ?? false,
      lastPaymentId: json['lastPaymentId'],
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }
}
