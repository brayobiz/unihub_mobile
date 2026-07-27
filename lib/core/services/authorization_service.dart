import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/models/app_user.dart';
import '../../features/auth/shared/providers.dart';

enum UlifyFeature {
  // Marketplace
  marketplaceBrowse,
  marketplacePost,
  marketplaceContact,
  
  // Housing
  housingBrowse,
  housingPost,
  housingContact,
  
  // Community
  communityRead,
  communityPost,
  
  // Confessions
  confessionsRead,
  confessionsPost,
  
  // Notes
  notesBrowse,
  notesUpload,
  notesDownload,
  
  // Events
  eventsBrowse,
  eventsRSVP,
  eventsOrganize,
  
  // Chat
  chatStart,
  
  // Profile
  profileView,
  profileEdit,
  
  // Admin
  adminDashboard,

  // Student Gigs
  gigsBrowse,
  gigsPost,
  gigsApply,
}

enum AccessStatus {
  granted,
  needsEmailVerification,
  needsRole,
  denied,
}

final authorizationServiceProvider = Provider((ref) {
  return AuthorizationService(ref);
});

class AuthorizationService {
  final Ref _ref;

  AuthorizationService(this._ref);

  /// Returns the required access level for a feature.
  /// This is the "Verification Access Matrix" in code form.
  AccessStatus checkAccess(UlifyFeature feature) {
    final user = _ref.read(appUserProvider).valueOrNull;
    
    // 1. If not logged in at all, most things are denied or limited by router anyway.
    // Assuming this is called within an authenticated session for most cases.
    if (user == null) return AccessStatus.denied;

    switch (feature) {
      // Available before verification (Level 1 & 2)
      case UlifyFeature.marketplaceBrowse:
      case UlifyFeature.housingBrowse:
      case UlifyFeature.communityRead:
      case UlifyFeature.confessionsRead:
      case UlifyFeature.notesBrowse:
      case UlifyFeature.eventsBrowse:
      case UlifyFeature.profileView:
      case UlifyFeature.profileEdit:
      case UlifyFeature.gigsBrowse:
        return AccessStatus.granted;

      // Requires Verified Email (Level 3)
      case UlifyFeature.marketplacePost:
      case UlifyFeature.marketplaceContact:
      case UlifyFeature.communityPost:
      case UlifyFeature.confessionsPost:
      case UlifyFeature.notesDownload:
      case UlifyFeature.eventsRSVP:
      case UlifyFeature.chatStart:
      case UlifyFeature.housingContact:
      case UlifyFeature.gigsPost:
      case UlifyFeature.gigsApply:
        return user.isEmailVerified ? AccessStatus.granted : AccessStatus.needsEmailVerification;

      // Requires Additional Permissions (Level 4)
      case UlifyFeature.notesUpload:
        if (user.isAdmin) return AccessStatus.granted;
        if (!user.isEmailVerified) return AccessStatus.needsEmailVerification;
        return user.roles.contains('class_rep') ? AccessStatus.granted : AccessStatus.needsRole;

      case UlifyFeature.housingPost:
        // Must be a verified plug OR a business
        if (user.isAdmin) return AccessStatus.granted;
        return (user.isVerifiedPlug || user.accountType == 'business') 
            ? AccessStatus.granted 
            : AccessStatus.needsRole;

      case UlifyFeature.eventsOrganize:
        // Must have an approved organizer profile (handled by logic elsewhere too, but here for consistency)
        if (user.isAdmin) return AccessStatus.granted;
        // This usually requires email verification + student status
        if (!user.isEmailVerified) return AccessStatus.needsEmailVerification;
        return user.roles.contains('organizer') ? AccessStatus.granted : AccessStatus.needsRole;

      case UlifyFeature.adminDashboard:
        return user.isAdmin ? AccessStatus.granted : AccessStatus.needsRole;
    }
  }

  /// Helper to check if a feature should show a reminder banner
  bool shouldShowReminder(UlifyFeature feature) {
    final user = _ref.read(appUserProvider).valueOrNull;
    if (user == null || user.isEmailVerified) return false;

    // Classification 2: Available with a verification reminder
    const reminderFeatures = [
      UlifyFeature.marketplaceBrowse,
      UlifyFeature.housingBrowse,
      UlifyFeature.communityRead,
      UlifyFeature.notesBrowse,
      UlifyFeature.gigsBrowse,
    ];

    return reminderFeatures.contains(feature);
  }
}
