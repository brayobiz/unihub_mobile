import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// Tracks which announcements have been dismissed as modals
final dismissedAnnouncementsProvider = StateNotifierProvider<DismissedAnnouncementsNotifier, Set<String>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DismissedAnnouncementsNotifier(prefs);
});

class DismissedAnnouncementsNotifier extends StateNotifier<Set<String>> {
  final SharedPreferences _prefs;
  static const _key = 'dismissed_announcements';

  DismissedAnnouncementsNotifier(this._prefs) : super({}) {
    final list = _prefs.getStringList(_key) ?? [];
    state = list.toSet();
  }

  void dismiss(String id) {
    if (state.contains(id)) return;
    state = {...state, id};
    _prefs.setStringList(_key, state.toList());
  }
}

/// Tracks which announcements have already been shown as a modal in the current app session
final sessionShownModalsProvider = StateProvider<Set<String>>((ref) => {});

/// Filtered announcements based on the current user's profile and the specified feature
final relevantAnnouncementsProvider = Provider.autoDispose.family<List<Announcement>, String?>((ref, feature) {
  final activeAsync = ref.watch(activeAnnouncementsProvider);
  
  // Optimization: only watch routing-relevant user properties to avoid reloads on presence updates
  final userData = ref.watch(appUserProvider.select((userAsync) {
    final user = userAsync.valueOrNull;
    if (user == null) return null;
    return (
      roles: user.roles,
      isVerified: user.isVerified,
      university: user.university,
    );
  }));

  final announcements = activeAsync.valueOrNull ?? [];

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
    if (userData == null) return false;

    if (targetRoles.isNotEmpty) {
      final hasRole = userData.roles.any((role) => targetRoles.contains(role));
      if (!hasRole) return false;
    }

    if (verifiedOnly && !userData.isVerified) return false;

    // 3. Campus/University filtering: 
    // Normalize both to IDs for robust comparison
    if (targetUniversity != 'All') {
      final targetId = CampusConstants.resolveToId(targetUniversity) ?? targetUniversity;
      final userUniId = CampusConstants.resolveToId(userData.university) ?? userData.university;
      if (userUniId != targetId) return false;
    }

    return true;
  }).toList();
});
