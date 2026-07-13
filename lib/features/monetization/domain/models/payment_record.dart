import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentStatus { pending, completed, failed, cancelled, refunded }
enum PaymentType { boost, feature, subscription, sponsoredSearch }
enum PaymentGateway { mpesa, intasend, pesapal, manual }

class PaymentRecord {
  final String id;
  final String userId;
  final String? itemId; // ID of the listing being boosted/featured
  final double amount;
  final String currency;
  final PaymentStatus status;
  final PaymentType type;
  final PaymentGateway gateway;
  final String? transactionReference; // M-Pesa Receipt Number, etc.
  final String? phoneNumber; // Phone used for STK Push
  final String? errorMessage;
  
  // Metadata for the purchase
  final Map<String, dynamic> metadata;
  
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  PaymentRecord({
    required this.id,
    required this.userId,
    this.itemId,
    required this.amount,
    this.currency = 'KES',
    this.status = PaymentStatus.pending,
    required this.type,
    required this.gateway,
    this.transactionReference,
    this.phoneNumber,
    this.errorMessage,
    this.metadata = const {},
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'itemId': itemId,
      'amount': amount,
      'currency': currency,
      'status': status.name,
      'type': type.name,
      'gateway': gateway.name,
      'transactionReference': transactionReference,
      'phoneNumber': phoneNumber,
      'errorMessage': errorMessage,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      itemId: json['itemId'],
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'KES',
      status: PaymentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PaymentStatus.pending,
      ),
      type: PaymentType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PaymentType.boost,
      ),
      gateway: PaymentGateway.values.firstWhere(
        (e) => e.name == json['gateway'],
        orElse: () => PaymentGateway.mpesa,
      ),
      transactionReference: json['transactionReference'],
      phoneNumber: json['phoneNumber'],
      errorMessage: json['errorMessage'],
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: json['updatedAt'] != null ? (json['updatedAt'] as Timestamp).toDate() : null,
      completedAt: json['completedAt'] != null ? (json['completedAt'] as Timestamp).toDate() : null,
    );
  }
}
