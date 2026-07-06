import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/shared/providers.dart';
import '../data/repositories/announcement_repository.dart';
import '../domain/models/announcement.dart';
import '../../campus_filter/shared/providers.dart';
import '../../../../core/constants/campus_constants.dart';

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  final campus = ref.watch(effectiveCampusFilterProvider);
  return AnnouncementRepository(ref.watch(firestoreProvider), campus);
});

final allAnnouncementsProvider = StreamProvider.autoDispose<List<Announcement>>((ref) {
  return ref.watch(announcementRepositoryProvider).watchAllAnnouncements();
});

final activeAnnouncementsProvider = StreamProvider.autoDispose<List<Announcement>>((ref) {
  return ref.watch(announcementRepositoryProvider).watchActiveAnnouncements();
});

/// Filtered announcements based on the current user's profile and the specified feature
final relevantAnnouncementsProvider = Provider.autoDispose.family<List<Announcement>, String?>((ref, feature) {
  final activeAsync = ref.watch(activeAnnouncementsProvider);
  final userAsync = ref.watch(appUserProvider);

  final announcements = activeAsync.valueOrNull ?? [];
  final user = userAsync.valueOrNull;

  return announcements.where((a) {
    // 1. Feature filtering: If feature-specific, must match the current feature context
    if (a.type == AnnouncementType.featureSpecific) {
      if (feature == null || !a.targetFeatures.contains(feature)) {
        return false;
      }
    }

    // 2. Audience filtering
    final audience = a.targetAudience;
    final targetRoles = List<String>.from(audience['roles'] ?? []);
    final verifiedOnly = audience['verifiedOnly'] as bool? ?? false;
    final targetUniversity = audience['university'] as String? ?? 'All';

    // If it's a truly global announcement with no specific audience constraints, show to everyone (even logged out)
    if (targetRoles.isEmpty && !verifiedOnly && targetUniversity == 'All') {
      return true;
    }

    // If there ARE audience constraints, we need a logged-in user to evaluate them
    if (user == null) return false;

    if (targetRoles.isNotEmpty) {
      final hasRole = user.roles.any((role) => targetRoles.contains(role));
      if (!hasRole) return false;
    }

    if (verifiedOnly && !user.isVerified) return false;

    // 3. Campus/University filtering: 
    // Normalize both to IDs for robust comparison
    if (targetUniversity != 'All') {
      final targetId = CampusConstants.resolveToId(targetUniversity) ?? targetUniversity;
      final userId = CampusConstants.resolveToId(user.university) ?? user.university;
      if (userId != targetId) return false;
    }

    return true;
  }).toList();
});
