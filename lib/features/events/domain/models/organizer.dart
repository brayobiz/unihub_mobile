import 'package:cloud_firestore/cloud_firestore.dart';

enum OrganizerType { student, officialClub, department, externalPartner }
enum OrganizerVerificationStatus { draft, submitted, underReview, verified, official, rejected, suspended, withdrawn }

class Organizer {
  final String id;
  final String ownerId;
  final String name;
  final String bio;
  final String? logoUrl;
  final String? bannerUrl;
  final String? contactEmail;
  final String? contactPhone;
  final String campusId;
  final OrganizerType type;
  final OrganizerVerificationStatus verificationStatus;
  final double trustScore;
  
  final Map<String, String> socialLinks;
  final int followerCount;
  final int eventCount;
  final int sharesCount;
  
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;

  Organizer({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.bio,
    this.logoUrl,
    this.bannerUrl,
    this.contactEmail,
    this.contactPhone,
    required this.campusId,
    this.type = OrganizerType.student,
    this.verificationStatus = OrganizerVerificationStatus.draft,
    this.trustScore = 100.0,
    this.socialLinks = const {},
    this.followerCount = 0,
    this.eventCount = 0,
    this.sharesCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'name': name,
      'bio': bio,
      'logoUrl': logoUrl,
      'bannerUrl': bannerUrl,
      'contactEmail': contactEmail,
      'contactPhone': contactPhone,
      'campusId': campusId,
      'type': type.name,
      'verificationStatus': verificationStatus.name,
      'trustScore': trustScore,
      'socialLinks': socialLinks,
      'followerCount': followerCount,
      'eventCount': eventCount,
      'sharesCount': sharesCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'isDeleted': isDeleted,
      'searchKeywords': name.toLowerCase().split(' '),
    };
  }

  factory Organizer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Organizer(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      name: data['name'] ?? '',
      bio: data['bio'] ?? '',
      logoUrl: data['logoUrl'],
      bannerUrl: data['bannerUrl'],
      contactEmail: data['contactEmail'],
      contactPhone: data['contactPhone'],
      campusId: data['campusId'] ?? '',
      type: OrganizerType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => OrganizerType.student,
      ),
      verificationStatus: OrganizerVerificationStatus.values.firstWhere(
        (e) => e.name == data['verificationStatus'],
        orElse: () => OrganizerVerificationStatus.draft,
      ),
      trustScore: (data['trustScore'] ?? 100.0).toDouble(),
      socialLinks: Map<String, String>.from(data['socialLinks'] ?? {}),
      followerCount: data['followerCount'] ?? 0,
      eventCount: data['eventCount'] ?? 0,
      sharesCount: data['sharesCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      isDeleted: data['isDeleted'] ?? false,
    );
  }

  Organizer copyWith({
    String? name,
    String? bio,
    String? logoUrl,
    String? bannerUrl,
    String? contactEmail,
    String? contactPhone,
    OrganizerType? type,
    OrganizerVerificationStatus? verificationStatus,
    double? trustScore,
    Map<String, String>? socialLinks,
    int? followerCount,
    int? eventCount,
    int? sharesCount,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return Organizer(
      id: id,
      ownerId: ownerId,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      logoUrl: logoUrl ?? this.logoUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      campusId: campusId,
      type: type ?? this.type,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      trustScore: trustScore ?? this.trustScore,
      socialLinks: socialLinks ?? this.socialLinks,
      followerCount: followerCount ?? this.followerCount,
      eventCount: eventCount ?? this.eventCount,
      sharesCount: sharesCount ?? this.sharesCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
