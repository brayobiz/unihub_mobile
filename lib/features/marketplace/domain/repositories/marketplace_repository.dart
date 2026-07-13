import '../models/listing.dart';
import '../models/offer.dart';
import '../models/seller_stats.dart';
import '../models/saved_search.dart';

enum ListingSortType { newest, oldest, lowestPrice, highestPrice, mostViewed, mostSaved }

abstract class MarketplaceRepository {
  Stream<List<Listing>> watchListings({
    int? limit, 
    String? category,
    List<String>? conditions,
    double? minPrice,
    double? maxPrice,
    bool? isFeatured,
    String? searchQuery,
    ListingSortType? sortBy,
    ListingStatus? status,
    Map<String, dynamic>? categoryAttributes,
    Listing? startAfter,
  });
  
  Stream<List<Listing>> watchSellerListings(String sellerId);
  Stream<List<Listing>> watchSavedListings(String userId);
  
  // Discovery & Sections
  Stream<List<Listing>> watchRecentlyViewed(String userId);
  Future<void> clearRecentlyViewed(String userId);
  Stream<List<Listing>> watchTrendingListings({int limit = 10});
  Stream<List<Listing>> watchRecommendedListings(String userId, {int limit = 10});
  Stream<List<Listing>> watchSimilarListings(Listing listing, {int limit = 6});
  
  // Collections
  Stream<List<String>> watchCollectionNames(String userId);
  Future<void> createCollection(String userId, String name);
  Future<void> deleteCollection(String userId, String name);
  Future<void> addToCollection(String userId, String collectionName, String listingId);
  Future<void> removeFromCollection(String userId, String collectionName, String listingId);
  Stream<List<Listing>> watchCollectionListings(String userId, String collectionName);

  // Offers & Negotiation
  Future<void> makeOffer(Offer offer);
  Future<void> respondToOffer(String offerId, OfferStatus status, {double? counterAmount, String? sellerMessage});
  Stream<List<Offer>> watchListingOffers(String listingId);
  Stream<List<Offer>> watchUserOffers(String userId);
  Stream<List<Offer>> watchReceivedOffers(String sellerId);

  // Search enhancements
  Future<List<String>> getSearchSuggestions(String query);
  Future<void> saveSearchQuery(String userId, String query);
  Stream<List<String>> watchRecentSearches(String userId);
  Future<void> clearRecentSearches(String userId);
  Future<List<String>> getPopularSearches();

  // Saved Searches & Alerts
  Future<void> saveSearch(SavedSearch search);
  Future<void> deleteSavedSearch(String userId, String searchId);
  Stream<List<SavedSearch>> watchSavedSearches(String userId);
  Future<void> updateSavedSearchNotification(String userId, String searchId, bool enabled);

  // Seller Dashboard & Performance
  Future<SellerStats> getSellerStats(String userId);
  Stream<List<Listing>> watchSellerListingsByStatus(String sellerId, ListingStatus status);

  Future<List<Listing>> getListings({
    int limit = 20, 
    Listing? startAfter,
    String? category,
    List<String>? conditions,
    double? minPrice,
    double? maxPrice,
    bool? isFeatured,
    String? searchQuery,
    ListingSortType? sortBy,
    ListingStatus? status,
    Map<String, dynamic>? categoryAttributes,
  });
  Future<Listing?> getListingById(String id);
  Stream<Listing?> watchListingById(String id);

  Future<void> createListing(Listing listing);
  Future<void> updateListing(Listing listing);
  Future<void> deleteListing(String id, String userId);
  Future<void> toggleSaveListing(String userId, String listingId);
  Future<void> boostListing(String listingId);
  Future<void> featureListing(String listingId, String packageId, Duration duration);
  Future<void> setSponsored(String listingId, Duration duration);
  Future<void> recordView(String listingId, {String? userId});
  Future<void> recordSave(String listingId, bool isSaved);
  Future<void> recordChatStarted(String listingId);
  Future<void> recordShare(String listingId);
  Future<void> updateListingStatus(String listingId, ListingStatus status, String userId);
  Future<void> updateListingPrice(String listingId, double newPrice, String userId);
  
  Future<void> reportListing({
    required String listingId,
    required String reporterId,
    required String reason,
  });

  Future<void> submitReview({
    required String sellerId,
    required String buyerId,
    required String listingId,
    required double rating,
    required String comment,
  });

  // Moderation & Admin Methods
  Future<void> flagListing({
    required String listingId,
    required String reason,
    String? adminNotes,
  });

  Future<void> approveListing(String listingId);

  Future<void> suspendListing({
    required String listingId,
    required String reason,
    required String adminId,
  });

  Future<void> removeListing({
    required String listingId,
    required String reason,
    required String adminId,
  });

  Stream<List<Listing>> watchFlaggedListings(String campusId);
}
