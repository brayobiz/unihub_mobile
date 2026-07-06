enum LandmarkCategory {
  academic,
  administration,
  food,
  accommodation,
  health,
  banking,
  transport,
  recreation,
  security,
  religious,
  services,
  other
}

class Landmark {
  final String id;
  final String campusId;
  final String name;
  final LandmarkCategory category;
  final String description;
  final double latitude;
  final double longitude;
  final List<String> photos;
  final String? openingHours;
  final String? phone;
  final String? website;
  final bool isAccessible;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  Landmark({
    required this.id,
    required this.campusId,
    required this.name,
    required this.category,
    required this.description,
    required this.latitude,
    required this.longitude,
    this.photos = const [],
    this.openingHours,
    this.phone,
    this.website,
    this.isAccessible = true,
    this.isVerified = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Landmark.fromJson(Map<String, dynamic> json) {
    return Landmark(
      id: json['id'] as String,
      campusId: json['campusId'] as String,
      name: json['name'] as String,
      category: LandmarkCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => LandmarkCategory.other,
      ),
      description: json['description'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      photos: (json['photos'] as List?)?.map((e) => e.toString()).toList() ?? [],
      openingHours: json['openingHours'] as String?,
      phone: json['phone'] as String?,
      website: json['website'] as String?,
      isAccessible: json['isAccessible'] as bool? ?? true,
      isVerified: json['isVerified'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campusId': campusId,
      'name': name,
      'category': category.name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'photos': photos,
      'openingHours': openingHours,
      'phone': phone,
      'website': website,
      'isAccessible': isAccessible,
      'isVerified': isVerified,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
