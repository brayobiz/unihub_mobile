import 'package:cloud_firestore/cloud_firestore.dart';

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
  archived
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
  
  // Analytics
  final int views;
  final int saves;

  HousingListing({
    required this.id,
    required this.title,
    required this.description,
    required this.rent,
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
    this.status = HousingStatus.available,
    this.source = PropertySource.plugDiscovery,
    required this.plugId,
    required this.plugName,
    this.plugPhotoUrl,
    this.isFurnished = false,
    this.genderRestriction = GenderRestriction.mixed,
    this.views = 0,
    this.saves = 0,
  }) : updatedAt = updatedAt ?? createdAt;

  factory HousingListing.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return HousingListing(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      rent: (data['rent'] ?? 0).toDouble(),
      deposit: (data['deposit'] ?? 0).toDouble(),
      type: HousingType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => HousingType.hostel,
      ),
      university: (data['university'] ?? '').toString(),
      campus: (data['campus'] ?? '').toString(),
      location: (data['location'] ?? '').toString(),
      distance: (data['distance'] ?? '').toString(),
      images: List<String>.from(data['images'] ?? <String>[]),
      videoUrl: data['videoUrl']?.toString(),
      amenities: List<String>.from(data['amenities'] ?? <String>[]),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      status: HousingStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => HousingStatus.available,
      ),
      source: PropertySource.values.firstWhere(
        (e) => e.name == (data['source'] ?? ''),
        orElse: () => PropertySource.plugDiscovery,
      ),
      plugId: (data['plugId'] ?? '').toString(),
      plugName: (data['plugName'] ?? '').toString(),
      plugPhotoUrl: data['plugPhotoUrl']?.toString(),
      isFurnished: data['isFurnished'] ?? false,
      genderRestriction: GenderRestriction.values.firstWhere(
        (e) => e.name == data['genderRestriction'],
        orElse: () => GenderRestriction.mixed,
      ),
      views: data['views'] ?? 0,
      saves: data['saves'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'rent': rent,
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
      'status': status.name,
      'source': source.name,
      'plugId': plugId,
      'plugName': plugName,
      'plugPhotoUrl': plugPhotoUrl,
      'isFurnished': isFurnished,
      'genderRestriction': genderRestriction.name,
      'views': views,
      'saves': saves,
    };
  }

  HousingListing copyWith({
    String? title,
    String? description,
    double? rent,
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
    int? views,
    int? saves,
    DateTime? updatedAt,
  }) {
    return HousingListing(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      rent: rent ?? this.rent,
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
      status: status ?? this.status,
      source: source ?? this.source,
      plugId: plugId,
      plugName: plugName,
      plugPhotoUrl: plugPhotoUrl,
      isFurnished: isFurnished ?? this.isFurnished,
      genderRestriction: genderRestriction ?? this.genderRestriction,
      views: views ?? this.views,
      saves: saves ?? this.saves,
    );
  }
}
