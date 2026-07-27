import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/campus_constants.dart';

enum HousingType { 
  hostel, 
  bedsitter, 
  singleRoom, 
  oneBedroom, 
  twoBedroom, 
  airbnb, 
  shortStay 
}

enum HousingStatus { 
  draft,
  published,
  available, 
  taken,
  pendingReview,
  reported,
  archived,
  removed
}

enum PropertySource {
  plugDiscovery,
  landlord,
  caretaker,
  hostelManagement,
  studentMovingOut,
  other
}

enum GenderRestriction { 
  mixed, 
  maleOnly, 
  femaleOnly 
}

class HousingListing {
  final String id;
  final String title;
  final String description;
  final double rent;
  final double? previousRent;
  final double deposit;
  final HousingType type;
  final String university;
  final String campus;
  final String location;
  final String distance; // e.g., "5 mins walk", "2km"
  final List<String> images;
  final String? videoUrl;
  final List<String> amenities;
  final DateTime createdAt;
  final DateTime updatedAt;
  final HousingStatus status;
  final PropertySource source;
  
  // Plug Info
  final String plugId;
  final String plugName;
  final String? plugPhotoUrl;

  final bool isFurnished;
  final GenderRestriction genderRestriction;
  
  final double? latitude;
  final double? longitude;
  final DateTime lastVerifiedAt;
  
  // Analytics
  final int views;
  final int saves;
  final int chatCount;
  final int callCount;

  HousingListing({
    required this.id,
    required this.title,
    required this.description,
    required this.rent,
    this.previousRent,
    required this.deposit,
    required this.type,
    required this.university,
    required this.campus,
    required this.location,
    required this.distance,
    required this.images,
    this.videoUrl,
    required this.amenities,
    required this.createdAt,
    DateTime? updatedAt,
    DateTime? lastVerifiedAt,
    this.status = HousingStatus.available,
    this.source = PropertySource.plugDiscovery,
    required this.plugId,
    required this.plugName,
    this.plugPhotoUrl,
    this.isFurnished = false,
    this.genderRestriction = GenderRestriction.mixed,
    this.latitude,
    this.longitude,
    this.views = 0,
    this.saves = 0,
    this.chatCount = 0,
    this.callCount = 0,
  }) : updatedAt = updatedAt ?? createdAt,
       lastVerifiedAt = lastVerifiedAt ?? updatedAt ?? createdAt;

  factory HousingListing.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Audit Phase 4.9: Robust Parsing
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

    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return HousingListing(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      rent: safeDouble(data['rent'], 0.0),
      previousRent: data['previousRent'] != null ? safeDouble(data['previousRent'], 0.0) : null,
      deposit: safeDouble(data['deposit'], 0.0),
      type: HousingType.values.firstWhere(
        (e) => e.name == data['type']?.toString(),
        orElse: () => HousingType.hostel,
      ),
      university: CampusConstants.resolveToId(data['university']?.toString()) ?? (data['university'] ?? '').toString(),
      campus: CampusConstants.resolveToId(data['campus']?.toString()) ?? (data['campus'] ?? '').toString(),
      location: (data['location'] ?? '').toString(),
      distance: (data['distance'] ?? '').toString(),
      images: List<String>.from((data['images'] as List?)?.map((e) => e.toString()) ?? <String>[]),
      videoUrl: data['videoUrl']?.toString(),
      amenities: List<String>.from((data['amenities'] as List?)?.map((e) => e.toString()) ?? <String>[]),
      createdAt: parseDate(data['createdAt']),
      updatedAt: data['updatedAt'] != null ? parseDate(data['updatedAt']) : null,
      lastVerifiedAt: data['lastVerifiedAt'] != null ? parseDate(data['lastVerifiedAt']) : null,
      status: HousingStatus.values.firstWhere(
        (e) => e.name == data['status']?.toString(),
        orElse: () => HousingStatus.available,
      ),
      source: PropertySource.values.firstWhere(
        (e) => e.name == data['source']?.toString(),
        orElse: () => PropertySource.plugDiscovery,
      ),
      plugId: (data['plugId'] ?? '').toString(),
      plugName: (data['plugName'] ?? '').toString(),
      plugPhotoUrl: data['plugPhotoUrl']?.toString(),
      isFurnished: data['isFurnished'] == true,
      genderRestriction: GenderRestriction.values.firstWhere(
        (e) => e.name == data['genderRestriction']?.toString(),
        orElse: () => GenderRestriction.mixed,
      ),
      latitude: data['latitude'] != null ? safeDouble(data['latitude'], 0.0) : null,
      longitude: data['longitude'] != null ? safeDouble(data['longitude'], 0.0) : null,
      views: safeInt(data['views'], 0),
      saves: safeInt(data['saves'], 0),
      chatCount: safeInt(data['chatCount'], 0),
      callCount: safeInt(data['callCount'], 0),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'rent': rent,
      'previousRent': previousRent,
      'deposit': deposit,
      'type': type.name,
      'university': university,
      'campus': campus,
      'location': location,
      'distance': distance,
      'images': images,
      'videoUrl': videoUrl,
      'amenities': amenities,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastVerifiedAt': Timestamp.fromDate(lastVerifiedAt),
      'status': status.name,
      'source': source.name,
      'plugId': plugId,
      'plugName': plugName,
      'plugPhotoUrl': plugPhotoUrl,
      'isFurnished': isFurnished,
      'genderRestriction': genderRestriction.name,
      'latitude': latitude,
      'longitude': longitude,
      'views': views,
      'saves': saves,
      'chatCount': chatCount,
      'callCount': callCount,
    };
  }

  HousingListing copyWith({
    String? title,
    String? description,
    double? rent,
    double? previousRent,
    double? deposit,
    HousingType? type,
    String? university,
    String? campus,
    String? location,
    String? distance,
    List<String>? images,
    String? videoUrl,
    List<String>? amenities,
    HousingStatus? status,
    PropertySource? source,
    bool? isFurnished,
    GenderRestriction? genderRestriction,
    double? latitude,
    double? longitude,
    int? views,
    int? saves,
    int? chatCount,
    int? callCount,
    DateTime? updatedAt,
    DateTime? lastVerifiedAt,
  }) {
    return HousingListing(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      rent: rent ?? this.rent,
      previousRent: previousRent ?? this.previousRent,
      deposit: deposit ?? this.deposit,
      type: type ?? this.type,
      university: university ?? this.university,
      campus: campus ?? this.campus,
      location: location ?? this.location,
      distance: distance ?? this.distance,
      images: images ?? this.images,
      videoUrl: videoUrl ?? this.videoUrl,
      amenities: amenities ?? this.amenities,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      status: status ?? this.status,
      source: source ?? this.source,
      plugId: plugId,
      plugName: plugName,
      plugPhotoUrl: plugPhotoUrl,
      isFurnished: isFurnished ?? this.isFurnished,
      genderRestriction: genderRestriction ?? this.genderRestriction,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      views: views ?? this.views,
      saves: saves ?? this.saves,
      chatCount: chatCount ?? this.chatCount,
      callCount: callCount ?? this.callCount,
    );
  }
}
