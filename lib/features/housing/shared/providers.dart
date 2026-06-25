import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/shared/providers.dart';
import '../data/repositories/housing_repository_impl.dart';
import '../domain/models/housing_listing.dart';
import '../domain/models/roommate_profile.dart';
import '../domain/models/housing_review.dart';

import '../domain/repositories/housing_repository.dart';

final housingRepositoryProvider = Provider<HousingRepository>((ref) {
  return HousingRepositoryImpl(ref.watch(firestoreProvider));
});

// Filters
final housingCampusFilterProvider = StateProvider<String?>((ref) => null);
final housingTypeFilterProvider = StateProvider<HousingType?>((ref) => null);
final housingBudgetFilterProvider = StateProvider<double?>((ref) => null);

// Housing Listings Stream
final housingListingsProvider = StreamProvider.family<List<HousingListing>, int>((ref, limit) {
  final campus = ref.watch(housingCampusFilterProvider);
  final type = ref.watch(housingTypeFilterProvider);
  final maxBudget = ref.watch(housingBudgetFilterProvider);

  return ref.watch(housingRepositoryProvider).watchListings(
    campus: campus,
    type: type,
    maxBudget: maxBudget,
    limit: limit,
  );
});

final topHousingProvider = StreamProvider<List<HousingListing>>((ref) {
  return ref.watch(housingListingsProvider(30).stream);
});

// Roommate Profiles Stream
final roommateProfilesProvider = StreamProvider<List<RoommateProfile>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  return ref.read(housingRepositoryProvider).watchRoommates(
    campus: user?.campus,
  );
});

final housingReviewsProvider = StreamProvider.family<List<HousingReview>, String>((ref, listingId) {
  return ref.read(housingRepositoryProvider).watchReviews(listingId);
});
