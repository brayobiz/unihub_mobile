import 'package:cloud_firestore/cloud_firestore.dart';

class PriceHistory {
  final double price;
  final DateTime timestamp;

  PriceHistory({required this.price, required this.timestamp});

  Map<String, dynamic> toJson() => {
    'price': price,
    'timestamp': Timestamp.fromDate(timestamp),
  };

  factory PriceHistory.fromJson(Map<String, dynamic> json) {
    // Audit Phase 4.9: Robust Parsing
    double parseDouble(dynamic value) {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      return double.tryParse(value?.toString() ?? '0.0') ?? 0.0;
    }

    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return DateTime.now();
    }

    return PriceHistory(
      price: parseDouble(json['price']),
      timestamp: parseDate(json['timestamp']),
    );
  }
}
