import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../trust/domain/models/badge.dart';
import '../../../trust/domain/models/professional_role.dart';
import '../../../../core/constants/campus_constants.dart';

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
  final double _reputationPoints; // Maps to 'trustScore' in Firestore
  double get reputationPoints => _reputationPoints;
  final int ratingsCount;
  final double averageRating;
  final double sellerRating;
  final double buyerRating;
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final bool isStudentVerified;
  final String studentStatus; // 'none' | 'pending' | 'approved' | 'rejected'
  
  // Business & Monetization
  final String accountType; // 'student' | 'business'
  final String? businessName;
  final String? businessCategory;
  final String? businessSubscriptionStatus;
  final DateTime? subscriptionExpiry;

  final bool isIdentityVerified;
  final String identityStatus; // 'none' | 'pending' | 'approved' | 'rejected'
  final List<String> verifiedRoles; // List of ProfessionalRole names
  
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
  final bool _isAdmin; // Maps to 'isAdmin' in Firestore
  bool get isAdmin => _isAdmin || roles.contains('admin');
  
  final Map<String, String> privacySettings;
  final Map<String, bool> notificationSettings;
  final List<String> blockedUids;
  final String? fcmToken;

  final bool isOnboardingCompleted;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime? createdAt;

  // Moderation & Status
  final bool isBanned;
  final String? banReason;
  final DateTime? suspendedUntil;
  final bool hasActiveWarning;
  final String? warningReason;
  final DateTime? lastWarningAt;
  final bool isDeleted;

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
    double? reputationPoints,
    this.ratingsCount = 0,
    this.averageRating = 0.0,
    this.sellerRating = 0.0,
    this.buyerRating = 0.0,
    this.isEmailVerified = false,
    this.isPhoneVerified = false,
    this.isStudentVerified = false,
    this.studentStatus = 'none',
    this.accountType = 'student',
    this.businessName,
    this.businessCategory,
    this.businessSubscriptionStatus,
    this.subscriptionExpiry,
    this.isIdentityVerified = false,
    this.identityStatus = 'none',
    this.verifiedRoles = const [],
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
    bool isAdmin = false,
    this.privacySettings = const {
      'profile_visibility': 'university', // 'public', 'university', 'private'
      'show_socials': 'university',
      'show_listings': 'public',
    },
    this.notificationSettings = const {
      'new_messages': true,
      'marketplace': true,
      'housing': true,
      'notes': true,
      'plug': true,
      'reviews': true,
      'followers': true,
      'system': true,
      'events': true,
      'community_activity': true,
    },
    this.blockedUids = const [],
    this.fcmToken,
    this.isOnboardingCompleted = false,
    this.isOnline = false,
    this.lastSeen,
    this.createdAt,
    this.isBanned = false,
    this.banReason,
    this.suspendedUntil,
    this.hasActiveWarning = false,
    this.warningReason,
    this.lastWarningAt,
    this.isDeleted = false,
  }) : _reputationPoints = reputationPoints ?? 0.0,
       _isAdmin = isAdmin;

  bool get isHousingPlug => roles.contains('housing_plug');
  bool get isVerifiedPlug => verifiedRoles.contains('housePlug');
  bool get isVerifiedSeller => verifiedRoles.contains('seller');
  bool get isAnyRoleVerified => verifiedRoles.isNotEmpty;
  
  /// Determines if the user gets the primary "Verification Tick" (Primary Identity).
  /// Per design recommendation: This is reserved for Government/Official Identity verification only.
  bool get isVerified => isIdentityVerified == true;
  
  bool get isCurrentlySuspended {
    if (suspendedUntil == null) return false;
    return suspendedUntil!.isAfter(DateTime.now());
  }

  bool get isRestricted => isBanned || isCurrentlySuspended;

  /// Calculates a reality-based trust score based on verified milestones and activity.
  /// This ensures the score is a deterministic reflection of the user's standing.
  double get calculatedTrustScore {
    double score = 0.0;

    // 1. Foundational Verifications (50% of total)
    if (isIdentityVerified) score += 30.0; // Government ID is the strongest signal
    if (isStudentVerified) score += 20.0;  // Campus enrollment confirmation

    // 2. Professional Standing (15% of total)
    // +5 for each unique professional role (max 3 roles counted)
    score += (verifiedRoles.length.clamp(0, 3) * 5.0);

    // 3. Platform Activity & Reputation (25% of total)
    // Scale profile completion (0.0 to 1.0) to 10 points
    score += (profileCompletion * 10.0);
    
    // Reward successful deals (+2 per deal, max 10 points)
    score += (completedSalesCount.clamp(0, 5) * 2.0);
    
    // Reward community contribution (+1 per resource, max 5 points)
    score += (resourcesSharedCount.clamp(0, 5) * 1.0);

    // 4. Community Feedback (10% of total)
    // Requires at least 3 ratings to be statistically significant
    if (ratingsCount >= 3) {
      if (averageRating >= 4.5) {
        score += 10.0;
      } else if (averageRating >= 4.0) {
        score += 7.0;
      } else if (averageRating >= 3.0) {
        score += 3.0;
      }
    }

    // 5. Moderation Penalties
    if (hasActiveWarning) score -= 15.0; // Significant penalty for warnings
    
    // 6. Bonus Reputation (Optional Activity Boosts from legacy system)
    // This allows repositories to still provide manual boosts if needed.
    // We cap the influence of legacy points to 20% to avoid score inflation.
    score += (reputationPoints.clamp(0, 20));

    return score.clamp(0.0, 100.0);
  }

  double get displayTrustScore => calculatedTrustScore;
  
  /// Compatibility getter for legacy field access.
  /// Points to displayTrustScore to ensure all UI components see the unified score.
  double get trustScore => displayTrustScore;

  List<AppBadge> get activeBadges {
    final List<AppBadge> badges = [];
    
    // 1. Verification Badges
    // NOTE: Identity and Student verifications are handled by primary UI indicators 
    // (Ticks and Info Pills) to avoid badge clutter.
    // We only add them to the badges list if they are unique professional milestones.

    // 2. Professional Role Badges
    for (final roleName in verifiedRoles) {
      try {
        final role = ProfessionalRole.values.firstWhere((e) => e.name == roleName);
        badges.add(AppBadge(
          id: 'role_${role.name}',
          label: role.label,
          description: 'Verified professional status on UniHub',
          icon: Icons.verified_user_rounded,
          color: const Color(0xFF1677F2),
          type: BadgeType.professional,
        ));
      } catch (_) {
        // Skip unknown roles
      }
    }

    // 3. Activity Badges (Simple logic for now)
    if (completedSalesCount >= 10) {
      badges.add(const AppBadge(
        id: 'top_seller',
        label: 'Top Seller',
        description: 'Completed 10+ successful sales',
        icon: Icons.auto_awesome_rounded,
        color: Colors.orange,
        type: BadgeType.achievement,
      ));
    }

    return badges;
  }

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

  AppUser stripSensitiveInfo() {
    return copyWith(
      email: 'hidden@unihub.student',
      fcmToken: '',
      blockedUids: [],
      phoneNumber: null,
      whatsappNumber: null,
      businessSubscriptionStatus: null,
      subscriptionExpiry: null,
    );
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
    double? reputationPoints,
    int? ratingsCount,
    double? averageRating,
    double? sellerRating,
    double? buyerRating,
    bool? isEmailVerified,
    bool? isPhoneVerified,
    bool? isStudentVerified,
    String? studentStatus,
    String? accountType,
    String? businessName,
    String? businessCategory,
    String? businessSubscriptionStatus,
    DateTime? subscriptionExpiry,
    bool? isIdentityVerified,
    String? identityStatus,
    List<String>? verifiedRoles,
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
    bool? isAdmin,
    Map<String, String>? privacySettings,
    Map<String, bool>? notificationSettings,
    List<String>? blockedUids,
    String? fcmToken,
    bool? isOnboardingCompleted,
    bool? isOnline,
    DateTime? lastSeen,
    DateTime? createdAt,
    bool? isBanned,
    String? banReason,
    DateTime? suspendedUntil,
    bool? hasActiveWarning,
    String? warningReason,
    DateTime? lastWarningAt,
    bool? isDeleted,
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
      reputationPoints: reputationPoints ?? this.reputationPoints,
      ratingsCount: ratingsCount ?? this.ratingsCount,
      averageRating: averageRating ?? this.averageRating,
      sellerRating: sellerRating ?? this.sellerRating,
      buyerRating: buyerRating ?? this.buyerRating,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      isStudentVerified: isStudentVerified ?? this.isStudentVerified,
      studentStatus: studentStatus ?? this.studentStatus,
      accountType: accountType ?? this.accountType,
      businessName: businessName ?? this.businessName,
      businessCategory: businessCategory ?? this.businessCategory,
      businessSubscriptionStatus: businessSubscriptionStatus ?? this.businessSubscriptionStatus,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      isIdentityVerified: isIdentityVerified ?? this.isIdentityVerified,
      identityStatus: identityStatus ?? this.identityStatus,
      verifiedRoles: verifiedRoles ?? this.verifiedRoles,
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
      isAdmin: isAdmin ?? _isAdmin,
      privacySettings: privacySettings ?? this.privacySettings,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      blockedUids: blockedUids ?? this.blockedUids,
      fcmToken: fcmToken ?? this.fcmToken,
      isOnboardingCompleted: isOnboardingCompleted ?? this.isOnboardingCompleted,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
      isBanned: isBanned ?? this.isBanned,
      banReason: banReason ?? this.banReason,
      suspendedUntil: suspendedUntil ?? this.suspendedUntil,
      hasActiveWarning: hasActiveWarning ?? this.hasActiveWarning,
      warningReason: warningReason ?? this.warningReason,
      lastWarningAt: lastWarningAt ?? this.lastWarningAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'fullNameLower': fullName.toLowerCase(),
      'username': username,
      'usernameLower': username?.toLowerCase(),
      'bio': bio,
      'photoUrl': photoUrl,
      'coverPhotoUrl': coverPhotoUrl,
      'university': university,
      'campus': campus,
      'course': course,
      'yearOfStudy': yearOfStudy,
      'housingStatus': housingStatus,
      'trustScore': reputationPoints,
      'ratingsCount': ratingsCount,
      'averageRating': averageRating,
      'sellerRating': sellerRating,
      'buyerRating': buyerRating,
      'isEmailVerified': isEmailVerified,
      'isPhoneVerified': isPhoneVerified,
      'isStudentVerified': isStudentVerified,
      'studentStatus': studentStatus,
      'accountType': accountType,
      'businessName': businessName,
      'businessCategory': businessCategory,
      'businessSubscriptionStatus': businessSubscriptionStatus,
      'subscriptionExpiry': subscriptionExpiry != null ? Timestamp.fromDate(subscriptionExpiry!) : null,
      'isIdentityVerified': isIdentityVerified,
      'identityStatus': identityStatus,
      'verifiedRoles': verifiedRoles,
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
      'isAdmin': _isAdmin,
      'privacySettings': privacySettings,
      'notificationSettings': notificationSettings,
      'blockedUids': blockedUids,
      'fcmToken': fcmToken,
      'isOnboardingCompleted': isOnboardingCompleted,
      'isOnline': isOnline,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'isBanned': isBanned,
      'banReason': banReason,
      'suspendedUntil': suspendedUntil != null ? Timestamp.fromDate(suspendedUntil!) : null,
      'hasActiveWarning': hasActiveWarning,
      'warningReason': warningReason,
      'lastWarningAt': lastWarningAt != null ? Timestamp.fromDate(lastWarningAt!) : null,
      'isDeleted': isDeleted,
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json, [String? id]) {
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

    bool safeBool(dynamic value, bool defaultValue) {
      if (value == null) return defaultValue;
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      if (value is int) return value != 0;
      return defaultValue;
    }

    return AppUser(
      uid: id ?? safeString(json['uid'], ''),
      email: safeString(json['email'], ''),
      fullName: safeString(json['fullName'] ?? json['full_name'], 'Ulify User'),
      username: json['username']?.toString(),
      bio: json['bio']?.toString(),
      photoUrl: json['photoUrl']?.toString(),
      coverPhotoUrl: json['coverPhotoUrl']?.toString(),
      university: CampusConstants.resolveToId(json['university']?.toString()) ?? json['university']?.toString(),
      campus: CampusConstants.resolveToId(json['campus']?.toString()) ?? json['campus']?.toString(),
      course: json['course']?.toString(),
      yearOfStudy: json['yearOfStudy']?.toString(),
      housingStatus: json['housingStatus']?.toString(),
      reputationPoints: safeDouble(json['trustScore'], 0.0),
      ratingsCount: safeInt(json['ratingsCount'], 0),
      averageRating: safeDouble(json['averageRating'], 0.0),
      sellerRating: safeDouble(json['sellerRating'], 0.0),
      buyerRating: safeDouble(json['buyerRating'], 0.0),
      isEmailVerified: safeBool(json['isEmailVerified'], false),
      isPhoneVerified: safeBool(json['isPhoneVerified'], false),
      isStudentVerified: safeBool(json['isStudentVerified'], false),
      studentStatus: json['studentStatus']?.toString() ?? 'none',
      accountType: json['accountType']?.toString() ?? 'student',
      businessName: json['businessName']?.toString(),
      businessCategory: json['businessCategory']?.toString(),
      businessSubscriptionStatus: json['businessSubscriptionStatus']?.toString(),
      subscriptionExpiry: json['subscriptionExpiry'] != null 
          ? (json['subscriptionExpiry'] as Timestamp).toDate() 
          : null,
      isIdentityVerified: safeBool(json['isIdentityVerified'], false),
      identityStatus: json['identityStatus']?.toString() ?? 'none',
      verifiedRoles: (json['verifiedRoles'] as List?)?.map((e) => e.toString()).toList() ?? <String>[],
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
      isAdmin: safeBool(json['isAdmin'], false),
      privacySettings: Map<String, String>.from(
        (json['privacySettings'] as Map?)?.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')) ?? <String, String>{
          'profile_visibility': 'university', // 'public', 'university', 'private'
          'show_socials': 'university',
          'show_listings': 'public',
        }
      ),
      notificationSettings: Map<String, bool>.from(
        (json['notificationSettings'] as Map?)?.map((k, v) => MapEntry(k.toString(), v is bool ? v : true)) ?? <String, bool>{
          'new_messages': true,
          'marketplace': true,
          'housing': true,
          'notes': true,
          'plug': true,
          'reviews': true,
          'followers': true,
          'system': true,
          'community_activity': true,
        }
      ),
      blockedUids: (json['blockedUids'] as List?)?.map((e) => e.toString()).toList() ?? <String>[],
      fcmToken: json['fcmToken']?.toString(),
      isOnboardingCompleted: safeBool(json['isOnboardingCompleted'], false),
      isOnline: safeBool(json['isOnline'], false),
      lastSeen: json['lastSeen'] != null 
          ? (json['lastSeen'] as Timestamp).toDate() 
          : null,
      createdAt: json['createdAt'] != null 
          ? (json['createdAt'] as Timestamp).toDate() 
          : null,
      isBanned: safeBool(json['isBanned'], false),
      banReason: json['banReason']?.toString(),
      suspendedUntil: json['suspendedUntil'] != null 
          ? (json['suspendedUntil'] as Timestamp).toDate()
          : null,
      hasActiveWarning: safeBool(json['hasActiveWarning'], false),
      warningReason: json['warningReason']?.toString(),
      lastWarningAt: (json['lastWarningAt'] is Timestamp)
          ? (json['lastWarningAt'] as Timestamp).toDate()
          : null,
      isDeleted: safeBool(json['isDeleted'], false),
    );
  }
}
