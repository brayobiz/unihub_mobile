import 'package:cloud_firestore/cloud_firestore.dart';

enum ListingCondition { newCondition, likeNew, good, fair }
enum ListingStatus { active, sold, paused, expired }

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
  
  // Algorithmic & Engagement Data
  final bool isFeatured;
  final bool isPromoted;
  final int viewsCount;
  final int savesCount;
  final int chatsStartedCount;
  
  final DateTime createdAt;
  final DateTime expiresAt;

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
    this.isFeatured = false,
    this.isPromoted = false,
    this.viewsCount = 0,
    this.savesCount = 0,
    this.chatsStartedCount = 0,
    required this.createdAt,
    required this.expiresAt,
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
      'isFeatured': isFeatured,
      'isPromoted': isPromoted,
      'viewsCount': viewsCount,
      'savesCount': savesCount,
      'chatsStartedCount': chatsStartedCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      // Search index for fuzzy matching
      'searchKeywords': title.toLowerCase().split(' '),
    };
  }

  factory Listing.fromJson(Map<String, dynamic> json) {
    // Extremely defensive parsing
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

    final sId = safeString(json['sellerId'] ?? json['seller_id'], '');
    
    return Listing(
      id: safeString(json['id'], ''),
      sellerId: sId,
      sellerName: safeString(json['sellerName'] ?? json['seller_name'], 'Student'),
      sellerUniversity: safeString(json['sellerUniversity'] ?? json['seller_university'], ''),
      sellerTrustScore: safeDouble(json['sellerTrustScore'] ?? json['trust_score'], 100.0),
      title: safeString(json['title'], ''),
      description: safeString(json['description'], ''),
      price: safeDouble(json['price'], 0.0),
      category: safeString(json['category'], 'Other'),
      imageUrls: (json['imageUrls'] as List?)?.map((e) => e.toString()).toList() ?? 
                 (json['images'] as List?)?.map((e) => e.toString()).toList() ?? [],
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
      isFeatured: json['isFeatured'] ?? json['is_featured'] ?? false,
      isPromoted: json['isPromoted'] ?? false,
      viewsCount: safeInt(json['viewsCount'] ?? json['views_count'], 0),
      savesCount: safeInt(json['savesCount'] ?? json['saves_count'], 0),
      chatsStartedCount: safeInt(json['chatsStartedCount'], 0),
      createdAt: json['createdAt'] != null 
          ? (json['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null 
          ? (json['expiresAt'] as Timestamp).toDate() 
          : DateTime.now().add(const Duration(days: 30)),
    );
  }
}
