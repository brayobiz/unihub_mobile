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
  final double _reputationPoints; // Maps to 'trustScore' in Firestore
  
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
    double trustScore = 0.0,
    this.socialLinks = const {},
    this.followerCount = 0,
    this.eventCount = 0,
    this.sharesCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
  }) : _reputationPoints = trustScore;

  /// Calculates a realistic trust score based on verification milestones and platform activity.
  double get calculatedTrustScore {
    double score = 0.0;

    // 1. Verification Status (Foundational Trust)
    if (verificationStatus == OrganizerVerificationStatus.official) {
      score += 50.0;
    } else if (verificationStatus == OrganizerVerificationStatus.verified) {
      score += 35.0;
    } else if (verificationStatus == OrganizerVerificationStatus.underReview || 
               verificationStatus == OrganizerVerificationStatus.submitted) {
      score += 10.0;
    }

    // 2. Event Activity (Proven Reliability)
    // +3 points per successful event hosted (max 21 points)
    score += (eventCount.clamp(0, 7) * 3.0);

    // 3. Profile Integrity & Branding
    if (logoUrl != null && logoUrl!.isNotEmpty) score += 5.0;
    if (bannerUrl != null && bannerUrl!.isNotEmpty) score += 5.0;
    if (bio.length > 50) score += 5.0;
    if (contactEmail != null || contactPhone != null) score += 4.0;

    // 4. Community Reach
    // +2 per social link (max 6 points)
    score += (socialLinks.length.clamp(0, 3) * 2.0);
    // +1 per 100 followers (max 4 points)
    score += (followerCount / 100).clamp(0, 4);

    // 5. Admin Reputation Boost (Legacy/Manual Points)
    // Capped at 15 points to prevent inflation.
    score += (_reputationPoints.clamp(0, 15));

    return score.clamp(0.0, 100.0);
  }

  /// The unified trust score displayed in the UI.
  double get trustScore => calculatedTrustScore;

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
      'trustScore': _reputationPoints,
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
      trustScore: (data['trustScore'] ?? 0.0).toDouble(),
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
      trustScore: trustScore ?? this._reputationPoints,
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
