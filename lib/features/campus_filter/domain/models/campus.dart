class Campus {
  final String campusId;
  final String officialName;
  final String shortName;
  final List<String> aliases;
  final Map<String, dynamic> metadata;

  const Campus({
    required this.campusId,
    required this.officialName,
    required this.shortName,
    this.aliases = const [],
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'campusId': campusId,
      'officialName': officialName,
      'shortName': shortName,
      'aliases': aliases,
      'metadata': metadata,
    };
  }

  factory Campus.fromJson(Map<String, dynamic> json) {
    return Campus(
      campusId: json['campusId'] ?? '',
      officialName: json['officialName'] ?? '',
      shortName: json['shortName'] ?? '',
      aliases: List<String>.from(json['aliases'] ?? []),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
}
