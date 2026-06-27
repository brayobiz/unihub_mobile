import 'package:cloud_firestore/cloud_firestore.dart';

enum PlugApplicationStatus { pending, approved, rejected }

class HousingPlugApplication {
  final String id;
  final String userId;
  final String fullName;
  final String phoneNumber;
  final String campus;
  final String bio;
  final List<String> areasServed;
  final String? experience;
  final String? idDocumentUrl;
  final String? profilePhotoUrl;
  final PlugApplicationStatus status;
  final DateTime createdAt;

  HousingPlugApplication({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.phoneNumber,
    required this.campus,
    required this.bio,
    required this.areasServed,
    this.experience,
    this.idDocumentUrl,
    this.profilePhotoUrl,
    this.status = PlugApplicationStatus.pending,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'campus': campus,
      'bio': bio,
      'areasServed': areasServed,
      'experience': experience,
      'idDocumentUrl': idDocumentUrl,
      'profilePhotoUrl': profilePhotoUrl,
      'status': status.name,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory HousingPlugApplication.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HousingPlugApplication(
      id: doc.id,
      userId: data['userId'] ?? '',
      fullName: data['fullName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      campus: data['campus'] ?? '',
      bio: data['bio'] ?? '',
      areasServed: List<String>.from(data['areasServed'] ?? []),
      experience: data['experience'],
      idDocumentUrl: data['idDocumentUrl'],
      profilePhotoUrl: data['profilePhotoUrl'],
      status: PlugApplicationStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => PlugApplicationStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
