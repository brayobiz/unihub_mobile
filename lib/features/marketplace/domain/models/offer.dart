import 'package:cloud_firestore/cloud_firestore.dart';

enum OfferStatus { pending, accepted, rejected, withdrawn, countered }

class Offer {
  final String id;
  final String listingId;
  final String buyerId;
  final String sellerId;
  final double amount;
  final String? message;
  final OfferStatus status;
  final DateTime timestamp;
  final double? counterAmount;

  Offer({
    required this.id,
    required this.listingId,
    required this.buyerId,
    required this.sellerId,
    required this.amount,
    this.message,
    this.status = OfferStatus.pending,
    required this.timestamp,
    this.counterAmount,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'listingId': listingId,
    'buyerId': buyerId,
    'sellerId': sellerId,
    'amount': amount,
    'message': message,
    'status': status.name,
    'timestamp': Timestamp.fromDate(timestamp),
    'counterAmount': counterAmount,
  };

  factory Offer.fromJson(Map<String, dynamic> json) => Offer(
    id: json['id'] as String,
    listingId: json['listingId'] as String,
    buyerId: json['buyerId'] as String,
    sellerId: json['sellerId'] as String,
    amount: (json['amount'] as num).toDouble(),
    message: json['message'] as String?,
    status: OfferStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => OfferStatus.pending),
    timestamp: (json['timestamp'] as Timestamp).toDate(),
    counterAmount: json['counterAmount'] != null ? (json['counterAmount'] as num).toDouble() : null,
  );

  Offer copyWith({
    OfferStatus? status,
    double? counterAmount,
  }) {
    return Offer(
      id: id,
      listingId: listingId,
      buyerId: buyerId,
      sellerId: sellerId,
      amount: amount,
      message: message,
      status: status ?? this.status,
      timestamp: timestamp,
      counterAmount: counterAmount ?? this.counterAmount,
    );
  }
}
