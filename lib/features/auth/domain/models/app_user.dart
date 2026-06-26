import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String fullName;
  final String? username;
  final String? bio;
  final String? photoUrl;
  final String? coverPhotoUrl;
  final String? university;
  final String? campus;
  final String? course;
  final String? yearOfStudy;
  final String? housingStatus;
  
  // Trust & Reputation
  final double trustScore; // 0 - 100
  final int ratingsCount;
  final double averageRating;
  final double sellerRating;
  final double buyerRating;
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final bool isVerified; // Official verification badge
  
  final String tier; // 'free' | 'pro'
  final String? whatsappNumber;
  final String? phoneNumber;
  final int activeListingsCount;
  final int resourcesSharedCount;
  final int housingListingsCount;
  final int gigsPostedCount;
  final int completedSalesCount;
  final String responseRate;
  final int listingsPostedToday; 
  final DateTime? lastPostDate;
  
  final List<String> skills;
  final List<String> interests;
  final List<String> achievements;
  final Map<String, String> socialLinks;
  
  final List<String> roles; // 'student', 'housing_plug', 'seller', etc.
  
  final Map<String, String> privacySettings;
  final Map<String, bool> notificationSettings;
  final String? fcmToken;

  final bool isOnboardingCompleted;
  final DateTime? createdAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.fullName,
    this.username,
    this.bio,
    this.photoUrl,
    this.coverPhotoUrl,
    this.university,
    this.campus,
    this.course,
    this.yearOfStudy,
    this.housingStatus,
    this.trustScore = 70.0,
    this.ratingsCount = 0,
    this.averageRating = 0.0,
    this.sellerRating = 0.0,
    this.buyerRating = 0.0,
    this.isEmailVerified = false,
    this.isPhoneVerified = false,
    this.isVerified = false,
    this.tier = 'free',
    this.whatsappNumber,
    this.phoneNumber,
    this.activeListingsCount = 0,
    this.resourcesSharedCount = 0,
    this.housingListingsCount = 0,
    this.gigsPostedCount = 0,
    this.completedSalesCount = 0,
    this.responseRate = '95%',
    this.listingsPostedToday = 0,
    this.lastPostDate,
    this.skills = const [],
    this.interests = const [],
    this.achievements = const [],
    this.socialLinks = const {},
    this.roles = const ['student'],
    this.privacySettings = const {
      'profile_visibility': 'university', // 'public', 'university', 'private'
      'show_socials': 'university',
      'show_listings': 'public',
    },
    this.notificationSettings = const {
      'new_messages': true,
      'listing_updates': true,
      'price_drops': true,
      'community_activity': true,
    },
    this.fcmToken,
    this.isOnboardingCompleted = false,
    this.createdAt,
  });

  bool get isHousingPlug => roles.contains('housing_plug');

  double get profileCompletion {
    int score = 0;
    int total = 10;
    if (photoUrl != null) score++;
    if (coverPhotoUrl != null) score++;
    if (bio != null && bio!.isNotEmpty) score++;
    if (username != null && username!.isNotEmpty) score++;
    if (university != null) score++;
    if (course != null) score++;
    if (yearOfStudy != null) score++;
    if (skills.isNotEmpty) score++;
    if (interests.isNotEmpty) score++;
    if (socialLinks.isNotEmpty) score++;
    return (score / total);
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? fullName,
    String? username,
    String? bio,
    String? photoUrl,
    String? coverPhotoUrl,
    String? university,
    String? campus,
    String? course,
    String? yearOfStudy,
    String? housingStatus,
    double? trustScore,
    int? ratingsCount,
    double? averageRating,
    double? sellerRating,
    double? buyerRating,
    bool? isEmailVerified,
    bool? isPhoneVerified,
    bool? isVerified,
    String? tier,
    String? whatsappNumber,
    String? phoneNumber,
    int? activeListingsCount,
    int? resourcesSharedCount,
    int? housingListingsCount,
    int? gigsPostedCount,
    int? completedSalesCount,
    String? responseRate,
    int? listingsPostedToday,
    DateTime? lastPostDate,
    List<String>? skills,
    List<String>? interests,
    List<String>? achievements,
    Map<String, String>? socialLinks,
    List<String>? roles,
    Map<String, String>? privacySettings,
    Map<String, bool>? notificationSettings,
    String? fcmToken,
    bool? isOnboardingCompleted,
    DateTime? createdAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      photoUrl: photoUrl ?? this.photoUrl,
      coverPhotoUrl: coverPhotoUrl ?? this.coverPhotoUrl,
      university: university ?? this.university,
      campus: campus ?? this.campus,
      course: course ?? this.course,
      yearOfStudy: yearOfStudy ?? this.yearOfStudy,
      housingStatus: housingStatus ?? this.housingStatus,
      trustScore: trustScore ?? this.trustScore,
      ratingsCount: ratingsCount ?? this.ratingsCount,
      averageRating: averageRating ?? this.averageRating,
      sellerRating: sellerRating ?? this.sellerRating,
      buyerRating: buyerRating ?? this.buyerRating,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      isVerified: isVerified ?? this.isVerified,
      tier: tier ?? this.tier,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      activeListingsCount: activeListingsCount ?? this.activeListingsCount,
      resourcesSharedCount: resourcesSharedCount ?? this.resourcesSharedCount,
      housingListingsCount: housingListingsCount ?? this.housingListingsCount,
      gigsPostedCount: gigsPostedCount ?? this.gigsPostedCount,
      completedSalesCount: completedSalesCount ?? this.completedSalesCount,
      responseRate: responseRate ?? this.responseRate,
      listingsPostedToday: listingsPostedToday ?? this.listingsPostedToday,
      lastPostDate: lastPostDate ?? this.lastPostDate,
      skills: skills ?? this.skills,
      interests: interests ?? this.interests,
      achievements: achievements ?? this.achievements,
      socialLinks: socialLinks ?? this.socialLinks,
      roles: roles ?? this.roles,
      privacySettings: privacySettings ?? this.privacySettings,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      fcmToken: fcmToken ?? this.fcmToken,
      isOnboardingCompleted: isOnboardingCompleted ?? this.isOnboardingCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'username': username,
      'bio': bio,
      'photoUrl': photoUrl,
      'coverPhotoUrl': coverPhotoUrl,
      'university': university,
      'campus': campus,
      'course': course,
      'yearOfStudy': yearOfStudy,
      'housingStatus': housingStatus,
      'trustScore': trustScore,
      'ratingsCount': ratingsCount,
      'averageRating': averageRating,
      'sellerRating': sellerRating,
      'buyerRating': buyerRating,
      'isEmailVerified': isEmailVerified,
      'isPhoneVerified': isPhoneVerified,
      'isVerified': isVerified,
      'tier': tier,
      'whatsappNumber': whatsappNumber,
      'phoneNumber': phoneNumber,
      'activeListingsCount': activeListingsCount,
      'resourcesSharedCount': resourcesSharedCount,
      'housingListingsCount': housingListingsCount,
      'gigsPostedCount': gigsPostedCount,
      'completedSalesCount': completedSalesCount,
      'responseRate': responseRate,
      'listingsPostedToday': listingsPostedToday,
      'lastPostDate': lastPostDate != null ? Timestamp.fromDate(lastPostDate!) : null,
      'skills': skills,
      'interests': interests,
      'achievements': achievements,
      'socialLinks': socialLinks,
      'roles': roles,
      'privacySettings': privacySettings,
      'notificationSettings': notificationSettings,
      'fcmToken': fcmToken,
      'isOnboardingCompleted': isOnboardingCompleted,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    // Extremely defensive parsing to prevent "Null is not subtype of String" errors
    String safeString(dynamic value, String defaultValue) {
      if (value == null) return defaultValue;
      return value.toString();
    }

    int safeInt(dynamic value, int defaultValue) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is double) return value.toInt();
      return int.tryParse(value.toString()) ?? defaultValue;
    }

    double safeDouble(dynamic value, double defaultValue) {
      if (value == null) return defaultValue;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      return double.tryParse(value.toString()) ?? defaultValue;
    }

    return AppUser(
      uid: safeString(json['uid'], ''),
      email: safeString(json['email'], ''),
      fullName: safeString(json['fullName'] ?? json['full_name'], 'UniHub User'),
      username: json['username']?.toString(),
      bio: json['bio']?.toString(),
      photoUrl: json['photoUrl']?.toString(),
      coverPhotoUrl: json['coverPhotoUrl']?.toString(),
      university: json['university']?.toString(),
      campus: json['campus']?.toString(),
      course: json['course']?.toString(),
      yearOfStudy: json['yearOfStudy']?.toString(),
      housingStatus: json['housingStatus']?.toString(),
      trustScore: safeDouble(json['trustScore'], 70.0),
      ratingsCount: safeInt(json['ratingsCount'], 0),
      averageRating: safeDouble(json['averageRating'], 0.0),
      sellerRating: safeDouble(json['sellerRating'], 0.0),
      buyerRating: safeDouble(json['buyerRating'], 0.0),
      isEmailVerified: json['isEmailVerified'] ?? false,
      isPhoneVerified: json['isPhoneVerified'] ?? false,
      isVerified: json['isVerified'] ?? false,
      tier: safeString(json['tier'], 'free'),
      whatsappNumber: json['whatsappNumber']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      activeListingsCount: safeInt(json['activeListingsCount'], 0),
      resourcesSharedCount: safeInt(json['resourcesSharedCount'], 0),
      housingListingsCount: safeInt(json['housingListingsCount'], 0),
      gigsPostedCount: safeInt(json['gigsPostedCount'], 0),
      completedSalesCount: safeInt(json['completedSalesCount'], 0),
      responseRate: safeString(json['responseRate'], '95%'),
      listingsPostedToday: safeInt(json['listingsPostedToday'], 0),
      lastPostDate: json['lastPostDate'] != null 
          ? (json['lastPostDate'] as Timestamp).toDate() 
          : null,
      skills: (json['skills'] as List?)?.map((e) => e.toString()).toList() ?? <String>[],
      interests: (json['interests'] as List?)?.map((e) => e.toString()).toList() ?? <String>[],
      achievements: (json['achievements'] as List?)?.map((e) => e.toString()).toList() ?? <String>[],
      socialLinks: Map<String, String>.from(
        (json['socialLinks'] as Map?)?.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')) ?? <String, String>{}
      ),
      roles: (json['roles'] as List?)?.map((e) => e.toString()).toList() ?? <String>['student'],
      privacySettings: Map<String, String>.from(
        (json['privacySettings'] as Map?)?.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')) ?? <String, String>{
          'profile_visibility': 'university',
          'show_socials': 'university',
          'show_listings': 'public',
        }
      ),
      notificationSettings: Map<String, bool>.from(
        (json['notificationSettings'] as Map?)?.map((k, v) => MapEntry(k.toString(), v is bool ? v : true)) ?? <String, bool>{
          'new_messages': true,
          'listing_updates': true,
          'price_drops': true,
          'community_activity': true,
        }
      ),
      fcmToken: json['fcmToken']?.toString(),
      isOnboardingCompleted: json['isOnboardingCompleted'] ?? false,
      createdAt: json['createdAt'] != null 
          ? (json['createdAt'] as Timestamp).toDate() 
          : null,
    );
  }
}
