enum MarkerType {
  housing,
  marketplace,
  event,
  campus,
  generic,
}

class MapMarker {
  final String id;
  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;
  final MarkerType markerType;
  final dynamic payload;

  MapMarker({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
    required this.markerType,
    this.payload,
  });
}
