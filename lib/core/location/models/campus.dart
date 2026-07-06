class Campus {
  final String id;
  final String name;
  final String shortName;
  final List<String> aliases;
  final double latitude;
  final double longitude;
  final double defaultZoom;
  final String country;
  final String city;
  final Map<String, dynamic> metadata;

  Campus({
    required this.id,
    required this.name,
    required this.shortName,
    this.aliases = const [],
    required this.latitude,
    required this.longitude,
    required this.defaultZoom,
    required this.country,
    required this.city,
    this.metadata = const {},
  });

  factory Campus.fromJson(Map<String, dynamic> json) {
    return Campus(
      id: json['id'] as String? ?? json['campusId'] as String? ?? '',
      name: json['name'] as String? ?? json['officialName'] as String? ?? '',
      shortName: json['shortName'] as String? ?? '',
      aliases: (json['aliases'] as List?)?.map((e) => e.toString()).toList() ?? [],
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      defaultZoom: (json['defaultZoom'] as num?)?.toDouble() ?? 15.0,
      country: json['country'] as String? ?? 'Kenya',
      city: json['city'] as String? ?? '',
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'shortName': shortName,
      'aliases': aliases,
      'latitude': latitude,
      'longitude': longitude,
      'defaultZoom': defaultZoom,
      'country': country,
      'city': city,
      'metadata': metadata,
    };
  }
}
