import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/shared/providers.dart';
import '../data/repositories/housing_repository_impl.dart';
import '../domain/models/housing_listing.dart';
import '../domain/models/housing_review.dart';
import '../domain/models/roommate_profile.dart';
import '../domain/models/vacancy_request.dart';
import '../domain/models/viewing_request.dart';
import '../domain/repositories/housing_repository.dart';

import 'package:unihub_mobile/features/shared/notification_repository.dart';
import '../../../services/notification_service.dart';
import '../../../core/location/services/location_service.dart';
import '../../campus_filter/shared/providers.dart';

final housingRepositoryProvider = Provider<HousingRepository>((ref) {
  final campus = ref.watch(effectiveCampusFilterProvider);
  return HousingRepositoryImpl(
    ref.watch(firestoreProvider),
    campus,
    ref.watch(notificationServiceProvider),
    ref.watch(userActivityRepositoryProvider),
  );
});

// Filters
final housingLocationFilterProvider = StateProvider<String?>((ref) => null);
final housingTypeFilterProvider = StateProvider<HousingType?>((ref) => null);
final housingMinRentFilterProvider = StateProvider<double?>((ref) => null);
final housingMaxRentFilterProvider = StateProvider<double?>((ref) => null);
final housingGenderFilterProvider = StateProvider<GenderRestriction?>((ref) => null);
final housingFurnishedFilterProvider = StateProvider<bool?>((ref) => null);

class SpatialSearchContext {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final bool isCampus;

  SpatialSearchContext({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.isCampus = false,
  });
}

final housingSpatialSearchProvider = StateProvider<SpatialSearchContext?>((ref) => null);

// Housing Listings Stream
final housingListingsProvider = StreamProvider.autoDispose.family<List<HousingListing>, int>((ref, limit) {
  final location = ref.watch(housingLocationFilterProvider);
  final spatialContext = ref.watch(housingSpatialSearchProvider);
  final type = ref.watch(housingTypeFilterProvider);
  final minRent = ref.watch(housingMinRentFilterProvider);
  final maxRent = ref.watch(housingMaxRentFilterProvider);
  final gender = ref.watch(housingGenderFilterProvider);
  final furnished = ref.watch(housingFurnishedFilterProvider);
  
  // Optimization: only watch relevant user data to avoid presence-triggered reloads
  final userAsync = ref.watch(appUserProvider.select((u) => u.valueOrNull));
  final blockedUids = userAsync?.blockedUids ?? const [];

  // Ensure listeners are cleaned up when the user leaves the housing module
  ref.onDispose(() {});

  // If spatial search is active, we might want to relax the campus restriction 
  // to show results "around" the requested area even if they belong to a different administrative campus
  final targetUniversity = spatialContext?.isCampus == true 
      ? spatialContext!.id
      : null; 
  
  return ref.watch(housingRepositoryProvider).watchListings(
    universityId: targetUniversity,
    location: spatialContext != null ? null : location, // Use spatial instead of text if available
    type: type,
    minRent: minRent,
    maxRent: maxRent,
    genderRestriction: gender,
    isFurnished: furnished,
    limit: limit,
  ).map((listings) {
    var results = listings;
    
    if (blockedUids.isNotEmpty) {
      results = results.where((l) => !blockedUids.contains(l.plugId)).toList();
    }

    if (spatialContext != null) {
      final locService = ref.read(locationServiceProvider);
      
      // Calculate distances and sort
      results = results.where((l) => l.latitude != null && l.longitude != null).toList();
      
      // Sort by distance to spatial context
      results.sort((a, b) {
        final distA = locService.calculateDistance(
          spatialContext.latitude, 
          spatialContext.longitude, 
          a.latitude!, 
          a.longitude!
        );
        final distB = locService.calculateDistance(
          spatialContext.latitude, 
          spatialContext.longitude, 
          b.latitude!, 
          b.longitude!
        );
        return distA.compareTo(distB);
      });
    }

    return results;
  });
});

final topHousingProvider = StreamProvider.autoDispose<List<HousingListing>>((ref) {
  return ref.watch(housingListingsProvider(50).stream);
});

// Featured listings (could be based on verification or a 'featured' flag, or just most viewed)
final featuredHousingProvider = StreamProvider.autoDispose<List<HousingListing>>((ref) {
  final blockedUids = ref.watch(appUserProvider.select((user) => user.valueOrNull?.blockedUids)) ?? const [];
  return ref.watch(housingRepositoryProvider).watchListings(
    limit: 10,
    // Add logic for featured here if needed
  ).map((listings) {
    if (blockedUids.isEmpty) return listings;
    return listings.where((l) => !blockedUids.contains(l.plugId)).toList();
  });
});

final plugListingsProvider = StreamProvider.autoDispose.family<List<HousingListing>, String>((ref, plugId) {
  final blockedUids = ref.watch(appUserProvider.select((user) => user.valueOrNull?.blockedUids)) ?? const [];
  return ref.watch(housingRepositoryProvider).watchPlugListings(plugId).map((listings) {
    if (blockedUids.contains(plugId)) return [];
    return listings;
  });
});

final housingListingProvider = StreamProvider.autoDispose.family<HousingListing?, String>((ref, id) {
  return ref.watch(housingRepositoryProvider).watchListingById(id);
});

final plugReviewsProvider = StreamProvider.autoDispose.family<List<HousingReview>, String>((ref, plugId) {
  return ref.watch(housingRepositoryProvider).watchPlugReviews(plugId);
});

final housingListingReviewsProvider = StreamProvider.autoDispose.family<List<HousingReview>, String>((ref, listingId) {
  return ref.watch(housingRepositoryProvider).watchListingReviews(listingId);
});

final savedHousingProvider = StreamProvider.autoDispose<List<HousingListing>>((ref) {
  final uid = ref.watch(appUserProvider.select((user) => user.valueOrNull?.uid));
  final blockedUids = ref.watch(appUserProvider.select((user) => user.valueOrNull?.blockedUids)) ?? const [];
  
  if (uid == null || uid.isEmpty) return Stream.value([]);
  return ref.watch(housingRepositoryProvider).watchSavedListings(uid).map((listings) {
    if (blockedUids.isEmpty) return listings;
    return listings.where((l) => !blockedUids.contains(l.plugId)).toList();
  });
});

final roommateProfilesProvider = StreamProvider.autoDispose<List<RoommateProfile>>((ref) {
  final blockedUids = ref.watch(appUserProvider.select((user) => user.valueOrNull?.blockedUids)) ?? const [];
  return ref.watch(housingRepositoryProvider).watchRoommates().map((profiles) {
    if (blockedUids.isEmpty) return profiles;
    return profiles.where((p) => !blockedUids.contains(p.userId)).toList();
  });
});

final vacancyOpportunitiesProvider = StreamProvider.autoDispose<List<VacancyRequest>>((ref) {
  return ref.watch(housingRepositoryProvider).watchVacancyOpportunities();
});

// Comparison Engine
final housingComparisonProvider = StateProvider<List<HousingListing>>((ref) => []);

final plugViewingRequestsProvider = StreamProvider.autoDispose.family<List<ViewingRequest>, String>((ref, plugId) {
  return ref.watch(housingRepositoryProvider).watchViewingRequests(userId: plugId, asPlug: true);
});

final studentViewingRequestsProvider = StreamProvider.autoDispose.family<List<ViewingRequest>, String>((ref, userId) {
  return ref.watch(housingRepositoryProvider).watchViewingRequests(userId: userId, asPlug: false);
});

final housingUniqueLocationsProvider = Provider<List<String>>((ref) {
  final listings = ref.watch(topHousingProvider).valueOrNull ?? [];
  final locations = listings.map((l) => l.location).where((loc) => loc.isNotEmpty).toSet().toList();
  locations.sort();
  return locations;
});
