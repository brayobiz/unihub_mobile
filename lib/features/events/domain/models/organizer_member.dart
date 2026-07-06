import 'package:cloud_firestore/cloud_firestore.dart';

enum OrganizerRole { owner, administrator, editor }

class OrganizerMember {
  final String id; // usually organizerId_userId
  final String organizerId;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final OrganizerRole role;
  final DateTime joinedAt;

  OrganizerMember({
    required this.id,
    required this.organizerId,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.role,
    required this.joinedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'organizerId': organizerId,
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'role': role.name,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }

  factory OrganizerMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrganizerMember(
      id: doc.id,
      organizerId: data['organizerId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userPhotoUrl: data['userPhotoUrl'],
      role: OrganizerRole.values.firstWhere(
        (e) => e.name == data['role'],
        orElse: () => OrganizerRole.editor,
      ),
      joinedAt: (data['joinedAt'] as Timestamp).toDate(),
    );
  }
}
