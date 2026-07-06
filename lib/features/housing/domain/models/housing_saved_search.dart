import 'package:cloud_firestore/cloud_firestore.dart';
import 'housing_listing.dart';

class HousingSavedSearch {
  final String id;
  final String userId;
  final String name;
  final String? location;
  final HousingType? type;
  final double? maxRent;
  final GenderRestriction? genderRestriction;
  final bool notificationsEnabled;
  final DateTime createdAt;

  HousingSavedSearch({
    required this.id,
    required this.userId,
    required this.name,
    this.location,
    this.type,
    this.maxRent,
    this.genderRestriction,
    this.notificationsEnabled = true,
    required this.createdAt,
  });

  factory HousingSavedSearch.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HousingSavedSearch(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      location: data['location'],
      type: data['type'] != null ? HousingType.values.byName(data['type']) : null,
      maxRent: (data['maxRent'] as num?)?.toDouble(),
      genderRestriction: data['genderRestriction'] != null 
          ? GenderRestriction.values.byName(data['genderRestriction']) 
          : null,
      notificationsEnabled: data['notificationsEnabled'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'location': location,
      'type': type?.name,
      'maxRent': maxRent,
      'genderRestriction': genderRestriction?.name,
      'notificationsEnabled': notificationsEnabled,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
