import 'package:cloud_firestore/cloud_firestore.dart';
import 'housing_listing.dart';

enum VacancyRequestStatus {
  open,
  claimed,
  completed,
  cancelled
}

class VacancyRequest {
  final String id;
  final String providerId;
  final String providerName;
  final String providerPhone;
  final HousingType type;
  final String location;
  final String campus;
  final String university;
  final double expectedRent;
  final String description;
  final VacancyRequestStatus status;
  final DateTime createdAt;
  final String? claimedByPlugId;
  final String? claimedByPlugName;

  VacancyRequest({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.providerPhone,
    required this.type,
    required this.location,
    required this.campus,
    required this.university,
    required this.expectedRent,
    required this.description,
    this.status = VacancyRequestStatus.open,
    required this.createdAt,
    this.claimedByPlugId,
    this.claimedByPlugName,
  });

  factory VacancyRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VacancyRequest(
      id: doc.id,
      providerId: data['providerId'] ?? '',
      providerName: data['providerName'] ?? '',
      providerPhone: data['providerPhone'] ?? '',
      type: HousingType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => HousingType.hostel,
      ),
      location: data['location'] ?? '',
      campus: data['campus'] ?? '',
      university: data['university'] ?? '',
      expectedRent: (data['expectedRent'] ?? 0).toDouble(),
      description: data['description'] ?? '',
      status: VacancyRequestStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => VacancyRequestStatus.open,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      claimedByPlugId: data['claimedByPlugId'],
      claimedByPlugName: data['claimedByPlugName'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'providerId': providerId,
      'providerName': providerName,
      'providerPhone': providerPhone,
      'type': type.name,
      'location': location,
      'campus': campus,
      'university': university,
      'expectedRent': expectedRent,
      'description': description,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'claimedByPlugId': claimedByPlugId,
      'claimedByPlugName': claimedByPlugName,
    };
  }
}
