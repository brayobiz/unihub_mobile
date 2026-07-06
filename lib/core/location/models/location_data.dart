class LocationData {
  final double latitude;
  final double longitude;
  final String? address;
  final String? campusId;
  final String? campusName;

  LocationData({
    required this.latitude,
    required this.longitude,
    this.address,
    this.campusId,
    this.campusName,
  });

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      address: json['address'] as String?,
      campusId: json['campusId'] as String?,
      campusName: json['campusName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'campusId': campusId,
      'campusName': campusName,
    };
  }

  LocationData copyWith({
    double? latitude,
    double? longitude,
    String? address,
    String? campusId,
    String? campusName,
  }) {
    return LocationData(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      campusId: campusId ?? this.campusId,
      campusName: campusName ?? this.campusName,
    );
  }
}
