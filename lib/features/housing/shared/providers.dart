import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/shared/providers.dart';
import '../data/repositories/housing_repository_impl.dart';
import '../domain/models/housing_listing.dart';
import '../domain/models/housing_review.dart';
import '../domain/models/roommate_profile.dart';
import '../domain/models/vacancy_request.dart';
import '../domain/repositories/housing_repository.dart';

import '../../../services/notification_service.dart';

final housingRepositoryProvider = Provider<HousingRepository>((ref) {
  return HousingRepositoryImpl(
    ref.watch(firestoreProvider),
    ref.watch(notificationServiceProvider),
  );
});

// Filters
final housingCampusFilterProvider = StateProvider<String?>((ref) => null);
final housingLocationFilterProvider = StateProvider<String?>((ref) => null);
final housingTypeFilterProvider = StateProvider<HousingType?>((ref) => null);
final housingMinRentFilterProvider = StateProvider<double?>((ref) => null);
final housingMaxRentFilterProvider = StateProvider<double?>((ref) => null);
final housingGenderFilterProvider = StateProvider<GenderRestriction?>((ref) => null);
final housingFurnishedFilterProvider = StateProvider<bool?>((ref) => null);

// Housing Listings Stream
final housingListingsProvider = StreamProvider.family<List<HousingListing>, int>((ref, limit) {
  final campus = ref.watch(housingCampusFilterProvider);
  final location = ref.watch(housingLocationFilterProvider);
  final type = ref.watch(housingTypeFilterProvider);
  final minRent = ref.watch(housingMinRentFilterProvider);
  final maxRent = ref.watch(housingMaxRentFilterProvider);
  final gender = ref.watch(housingGenderFilterProvider);
  final furnished = ref.watch(housingFurnishedFilterProvider);

  return ref.watch(housingRepositoryProvider).watchListings(
    campus: campus,
    location: location,
    type: type,
    minRent: minRent,
    maxRent: maxRent,
    genderRestriction: gender,
    isFurnished: furnished,
    limit: limit,
  );
});

final topHousingProvider = StreamProvider<List<HousingListing>>((ref) {
  return ref.watch(housingListingsProvider(50).stream);
});

// Featured listings (could be based on verification or a 'featured' flag, or just most viewed)
final featuredHousingProvider = StreamProvider<List<HousingListing>>((ref) {
  return ref.watch(housingRepositoryProvider).watchListings(
    limit: 10,
    // Add logic for featured here if needed
  );
});

final plugListingsProvider = StreamProvider.family<List<HousingListing>, String>((ref, plugId) {
  return ref.watch(housingRepositoryProvider).watchPlugListings(plugId);
});

final plugReviewsProvider = StreamProvider.family<List<HousingReview>, String>((ref, plugId) {
  return ref.watch(housingRepositoryProvider).watchPlugReviews(plugId);
});

final savedHousingProvider = StreamProvider<List<HousingListing>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(housingRepositoryProvider).watchSavedListings(user.uid);
});

final roommateProfilesProvider = StreamProvider<List<RoommateProfile>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  return ref.watch(housingRepositoryProvider).watchRoommates(
    campus: user?.campus,
  );
});

final vacancyOpportunitiesProvider = StreamProvider<List<VacancyRequest>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  return ref.watch(housingRepositoryProvider).watchVacancyOpportunities(
    campus: user?.university,
  );
});
