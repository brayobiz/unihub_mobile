import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/campus_constants.dart';
import 'price_history.dart';

enum ListingCondition { newCondition, likeNew, good, fair }
enum ListingStatus { active, sold, paused, expired, reserved, archived, removed }
enum ModerationStatus { active, flagged, suspended, removed }

class Listing {
  final String id;
  final String sellerId;
  final String sellerName;
  final String sellerUniversity;
  final double sellerTrustScore;
  
  final String title;
  final String description;
  final double price;
  final String category;
  final List<String> imageUrls;
  final String campusLocation;
  
  final ListingCondition condition;
  final ListingStatus status;
  final String contactPreference; 
  
  // Specs captured from detail view requirements
  final String? brand;
  final String? storage;
  final String? color;
  final bool isNegotiable;
  final int quantity;
  final List<String> tags;
  
  // Category-specific flexible attributes
  final Map<String, dynamic> attributes;
  
  // Algorithmic & Engagement Data
  final bool isFeatured;
  final bool isPromoted;
  final int viewsCount;
  final int savesCount;
  final int sharesCount;
  final int chatsStartedCount;
  
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime expiresAt;
  final List<PriceHistory> priceHistory;

  Listing({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.sellerUniversity,
    this.sellerTrustScore = 100.0,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.imageUrls,
    required this.campusLocation,
    required this.condition,
    this.status = ListingStatus.active,
    this.contactPreference = 'chat',
    this.brand,
    this.storage,
    this.color,
    this.isNegotiable = true,
    this.quantity = 1,
    this.tags = const [],
    this.attributes = const {},
    this.isFeatured = false,
    this.isPromoted = false,
    this.viewsCount = 0,
    this.savesCount = 0,
    this.sharesCount = 0,
    this.chatsStartedCount = 0,
    required this.createdAt,
    this.updatedAt,
    required this.expiresAt,
    this.priceHistory = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'sellerUniversity': sellerUniversity,
      'sellerTrustScore': sellerTrustScore,
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'imageUrls': imageUrls,
      'campusLocation': campusLocation,
      'condition': condition.name,
      'status': status.name,
      'contactPreference': contactPreference,
      'brand': brand,
      'storage': storage,
      'color': color,
      'isNegotiable': isNegotiable,
      'quantity': quantity,
      'tags': tags,
      'attributes': attributes,
      'isFeatured': isFeatured,
      'isPromoted': isPromoted,
      'viewsCount': viewsCount,
      'savesCount': savesCount,
      'sharesCount': sharesCount,
      'chatsStartedCount': chatsStartedCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'priceHistory': priceHistory.map((e) => e.toJson()).toList(),
      'searchKeywords': title.toLowerCase().split(' '),
    };
  }

  factory Listing.fromJson(Map<String, dynamic> json) {
    String safeString(dynamic value, String defaultValue) {
      if (value == null) return defaultValue;
      return value.toString();
    }

    double safeDouble(dynamic value, double defaultValue) {
      if (value == null) return defaultValue;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      return double.tryParse(value.toString()) ?? defaultValue;
    }

    int safeInt(dynamic value, int defaultValue) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is double) return value.toInt();
      return int.tryParse(value.toString()) ?? defaultValue;
    }

    bool safeBool(dynamic value, bool defaultValue) {
      if (value == null) return defaultValue;
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      if (value is num) return value != 0;
      return defaultValue;
    }

    return Listing(
      id: safeString(json['id'], ''),
      sellerId: safeString(json['sellerId'] ?? json['seller_id'], ''),
      sellerName: safeString(json['sellerName'] ?? json['seller_name'], 'Student'),
      sellerUniversity: CampusConstants.resolveToId(safeString(json['sellerUniversity'] ?? json['seller_university'], '')) ?? safeString(json['sellerUniversity'] ?? json['seller_university'], ''),
      sellerTrustScore: safeDouble(json['sellerTrustScore'] ?? json['trust_score'], 100.0),
      title: safeString(json['title'], ''),
      description: safeString(json['description'], ''),
      price: safeDouble(json['price'], 0.0),
      category: safeString(json['category'], 'Other'),
      imageUrls: (json['imageUrls'] as List?)?.map((e) => e.toString()).toList() ?? <String>[],
      campusLocation: safeString(json['campusLocation'] ?? json['location'], ''),
      condition: ListingCondition.values.firstWhere(
        (e) => e.name == safeString(json['condition'], 'good'), 
        orElse: () => ListingCondition.good
      ),
      status: ListingStatus.values.firstWhere(
        (e) => e.name == safeString(json['status'], 'active'), 
        orElse: () => ListingStatus.active
      ),
      contactPreference: safeString(json['contactPreference'], 'chat'),
      brand: json['brand']?.toString(),
      storage: json['storage']?.toString(),
      color: json['color']?.toString(),
      isNegotiable: safeBool(json['isNegotiable'], true),
      quantity: safeInt(json['quantity'], 1),
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? <String>[],
      attributes: Map<String, dynamic>.from(json['attributes'] ?? {}),
      isFeatured: safeBool(json['isFeatured'], false),
      isPromoted: safeBool(json['isPromoted'], false),
      viewsCount: safeInt(json['viewsCount'], 0),
      savesCount: safeInt(json['savesCount'], 0),
      sharesCount: safeInt(json['sharesCount'], 0),
      chatsStartedCount: safeInt(json['chatsStartedCount'], 0),
      createdAt: (json['createdAt'] is Timestamp) 
          ? (json['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      updatedAt: (json['updatedAt'] is Timestamp)
          ? (json['updatedAt'] as Timestamp).toDate()
          : null,
      expiresAt: (json['expiresAt'] is Timestamp) 
          ? (json['expiresAt'] as Timestamp).toDate() 
          : DateTime.now().add(const Duration(days: 30)),
      priceHistory: (json['priceHistory'] as List?)
              ?.map((e) => PriceHistory.fromJson(e as Map<String, dynamic>))
              .toList() ?? <PriceHistory>[],
    );
  }
}
