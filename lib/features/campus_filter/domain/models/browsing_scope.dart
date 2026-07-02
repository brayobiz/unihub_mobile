enum BrowsingScopeType { 
  all, 
  myCampus, 
  specific 
}

class BrowsingScope {
  final BrowsingScopeType type;
  final String? campusId;

  const BrowsingScope({
    required this.type,
    this.campusId,
  });

  factory BrowsingScope.all() => const BrowsingScope(type: BrowsingScopeType.all);
  
  factory BrowsingScope.myCampus() => const BrowsingScope(type: BrowsingScopeType.myCampus);
  
  factory BrowsingScope.specific(String campusId) => BrowsingScope(
        type: BrowsingScopeType.specific,
        campusId: campusId,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrowsingScope &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          campusId == other.campusId;

  @override
  int get hashCode => type.hashCode ^ campusId.hashCode;

  @override
  String toString() {
    if (type == BrowsingScopeType.specific) return 'BrowsingScope(specific: $campusId)';
    return 'BrowsingScope(${type.name})';
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'campusId': campusId,
    };
  }

  factory BrowsingScope.fromJson(Map<String, dynamic> json) {
    return BrowsingScope(
      type: BrowsingScopeType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => BrowsingScopeType.all,
      ),
      campusId: json['campusId'] ?? json['campusName'],
    );
  }
}
