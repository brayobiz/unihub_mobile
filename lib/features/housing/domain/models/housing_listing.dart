import 'package:cloud_firestore/cloud_firestore.dart';

enum HousingType { hostel, rental, tenantReplacement }
enum GenderRestriction { mixed, maleOnly, femaleOnly }

class HousingListing {
  final String id;
  final String title;
  final String description;
  final double price;
  final HousingType type;
  final String university;
  final String campus;
  final String location;
  final String distance; // e.g., "5 mins walk", "2km"
  final List<String> images;
  final List<String> amenities;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final String landlordId;
  final String landlordName;
  final DateTime createdAt;
  final double deposit;
  final bool isFurnished;
  final GenderRestriction genderRestriction;
  final Map<String, dynamic> contactInfo;
  final bool hasWater;
  final bool hasWifi;
  final bool hasSecurity;

  HousingListing({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.type,
    required this.university,
    required this.campus,
    required this.location,
    required this.distance,
    required this.images,
    required this.amenities,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.isVerified = false,
    required this.landlordId,
    required this.landlordName,
    required this.createdAt,
    this.deposit = 0.0,
    this.isFurnished = false,
    this.genderRestriction = GenderRestriction.mixed,
    required this.contactInfo,
    this.hasWater = true,
    this.hasWifi = false,
    this.hasSecurity = true,
  });

  factory HousingListing.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HousingListing(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      type: HousingType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => HousingType.hostel,
      ),
      university: data['university'] ?? '',
      campus: data['campus'] ?? '',
      location: data['location'] ?? '',
      distance: data['distance'] ?? '',
      images: List<String>.from(data['images'] ?? []),
      amenities: List<String>.from(data['amenities'] ?? []),
      rating: (data['rating'] ?? 0).toDouble(),
      reviewCount: data['reviewCount'] ?? 0,
      isVerified: data['isVerified'] ?? false,
      landlordId: data['landlordId'] ?? '',
      landlordName: data['landlordName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      deposit: (data['deposit'] ?? 0).toDouble(),
      isFurnished: data['isFurnished'] ?? false,
      genderRestriction: GenderRestriction.values.firstWhere(
        (e) => e.name == data['genderRestriction'],
        orElse: () => GenderRestriction.mixed,
      ),
      contactInfo: data['contactInfo'] ?? {},
      hasWater: data['hasWater'] ?? true,
      hasWifi: data['hasWifi'] ?? false,
      hasSecurity: data['hasSecurity'] ?? true,
    );
  }

  String? get ownerId => null;

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'price': price,
      'type': type.name,
      'university': university,
      'campus': campus,
      'location': location,
      'distance': distance,
      'images': images,
      'amenities': amenities,
      'rating': rating,
      'reviewCount': reviewCount,
      'isVerified': isVerified,
      'landlordId': landlordId,
      'landlordName': landlordName,
      'createdAt': Timestamp.fromDate(createdAt),
      'deposit': deposit,
      'isFurnished': isFurnished,
      'genderRestriction': genderRestriction.name,
      'contactInfo': contactInfo,
      'hasWater': hasWater,
      'hasWifi': hasWifi,
      'hasSecurity': hasSecurity,
    };
  }
}
