import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/housing_saved_search.dart';
import '../models/housing_listing.dart';
import '../models/housing_review.dart';
import '../models/roommate_profile.dart';
import '../models/vacancy_request.dart';
import '../models/viewing_request.dart';

enum HousingSortBy {
  newest,
  priceLowToHigh,
  priceHighToLow,
  mostViewed,
  distance,
}

abstract class HousingRepository {
  Stream<List<HousingListing>> watchListings({
    String? universityId,
    String? location,
    HousingType? type,
    double? minRent,
    double? maxRent,
    GenderRestriction? genderRestriction,
    bool? isFurnished,
    bool onlyAvailable = true,
    int limit = 50,
    HousingListing? startAfter,
    HousingSortBy sortBy = HousingSortBy.newest,
  });

  Future<List<HousingListing>> fetchListings({
    String? universityId,
    String? location,
    HousingType? type,
    double? minRent,
    double? maxRent,
    GenderRestriction? genderRestriction,
    bool? isFurnished,
    bool onlyAvailable = true,
    int limit = 50,
    HousingListing? startAfter,
    HousingSortBy sortBy = HousingSortBy.newest,
  });

  Stream<List<HousingListing>> watchPlugListings(String plugId);

  Stream<List<HousingReview>> watchPlugReviews(String plugId);

  Stream<List<HousingReview>> watchListingReviews(String listingId);

  Stream<List<RoommateProfile>> watchRoommates({int limit = 30});

  Future<HousingListing?> getListingById(String id);

  Stream<HousingListing?> watchListingById(String id);

  Future<void> createListing(HousingListing listing);

  Future<void> updateListing(HousingListing listing);

  Future<void> deleteListing(String id);

  Future<void> updateListingStatus(String id, HousingStatus status);

  Future<void> incrementViews(String id);

  Future<void> refreshListingStatus(String id);

  Future<void> incrementChatCount(String id);

  Future<void> incrementCallCount(String id);

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

  Stream<List<HousingListing>> watchRecentlyViewed(String userId);
  Future<void> clearRecentlyViewed(String userId);

  // Vacancy Requests
  Future<void> submitVacancyRequest(VacancyRequest request);
  
  Stream<List<VacancyRequest>> watchVacancyOpportunities();
  
  Future<void> claimVacancyRequest(String requestId, String plugId, String plugName);

  // Saved Searches / Alerts
  Future<void> saveHousingSearch(HousingSavedSearch search);
  
  Stream<List<HousingSavedSearch>> watchSavedHousingSearches(String userId);
  
  Future<void> deleteHousingSearch(String searchId);
  
  Future<void> toggleHousingSearchNotifications(String searchId, bool enabled);

  // Viewing Requests
  Future<void> submitViewingRequest(ViewingRequest request);
  Stream<List<ViewingRequest>> watchViewingRequests({required String userId, bool asPlug = false});
  Future<void> updateViewingRequestStatus(String requestId, ViewingRequestStatus status);
}
