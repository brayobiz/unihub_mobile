import 'package:cloud_firestore/cloud_firestore.dart';

class PriceHistory {
  final double price;
  final DateTime timestamp;

  PriceHistory({required this.price, required this.timestamp});

  Map<String, dynamic> toJson() => {
    'price': price,
    'timestamp': Timestamp.fromDate(timestamp),
  };

  factory PriceHistory.fromJson(Map<String, dynamic> json) => PriceHistory(
    price: (json['price'] as num).toDouble(),
    timestamp: (json['timestamp'] as Timestamp).toDate(),
  );
}
