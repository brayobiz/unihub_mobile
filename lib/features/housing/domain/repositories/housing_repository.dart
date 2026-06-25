import '../models/housing_listing.dart';
import '../models/roommate_profile.dart';
import '../models/housing_review.dart';

abstract class HousingRepository {
  Stream<List<HousingListing>> watchListings({
    String? campus,
    HousingType? type,
    double? maxBudget,
    int limit = 30,
  });

  Stream<List<RoommateProfile>> watchRoommates({String? campus, int limit = 30});

  Stream<List<HousingReview>> watchReviews(String listingId);

  Future<void> createListing(HousingListing listing);

  Future<void> updateListing(HousingListing listing);

  Future<void> createRoommateProfile(RoommateProfile profile);

  Future<void> submitReview(HousingReview review);

  Future<void> reportListing(String listingId, String userId, String reason);
}
