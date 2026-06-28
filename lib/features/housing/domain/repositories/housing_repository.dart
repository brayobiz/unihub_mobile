import '../models/housing_listing.dart';
import '../models/housing_review.dart';
import '../models/roommate_profile.dart';
import '../models/vacancy_request.dart';

abstract class HousingRepository {
  Stream<List<HousingListing>> watchListings({
    String? campus,
    String? location,
    HousingType? type,
    double? minRent,
    double? maxRent,
    GenderRestriction? genderRestriction,
    bool? isFurnished,
    bool onlyAvailable = true,
    int limit = 50,
  });

  Stream<List<HousingListing>> watchPlugListings(String plugId);

  Stream<List<HousingReview>> watchPlugReviews(String plugId);

  Stream<List<RoommateProfile>> watchRoommates({String? campus, int limit = 30});

  Future<HousingListing?> getListingById(String id);

  Future<void> createListing(HousingListing listing);

  Future<void> updateListing(HousingListing listing);

  Future<void> deleteListing(String id);

  Future<void> updateListingStatus(String id, HousingStatus status);

  Future<void> incrementViews(String id);

  Future<void> submitReview(HousingReview review);

  Future<void> createRoommateProfile(RoommateProfile profile);

  Future<void> reportListing({
    required String listingId,
    required String reporterId,
    required String reason,
    required String category,
  });

  Future<void> moderateListing({
    required String listingId,
    required HousingStatus status,
    String? moderatorNotes,
  });

  Future<bool> checkPossibleDuplicate({
    required String location,
    required double rent,
    required HousingType type,
  });
  
  Future<void> saveListing(String userId, String listingId);
  
  Future<void> unsaveListing(String userId, String listingId);
  
  Stream<List<HousingListing>> watchSavedListings(String userId);

  // Vacancy Requests
  Future<void> submitVacancyRequest(VacancyRequest request);
  
  Stream<List<VacancyRequest>> watchVacancyOpportunities({String? campus});
  
  Future<void> claimVacancyRequest(String requestId, String plugId, String plugName);
}
