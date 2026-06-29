import '../models/listing.dart';

abstract class MarketplaceRepository {
  Stream<List<Listing>> watchListings({
    int? limit, 
    String? category,
    List<String>? conditions,
    double? minPrice,
    double? maxPrice,
    bool? isFeatured,
    String? university,
    String? searchQuery,
  });
  Stream<List<Listing>> watchSellerListings(String sellerId);
  Stream<List<Listing>> watchSavedListings(String userId);
  Future<List<Listing>> getListings({int limit = 20, Listing? startAfter});
  Future<Listing?> getListingById(String id);

  Future<void> createListing(Listing listing);
  Future<void> deleteListing(String id);
  Future<void> toggleSaveListing(String userId, String listingId);
  Future<void> boostListing(String listingId);
  Future<void> recordView(String listingId);
  Future<void> recordSave(String listingId, bool isSaved);
  Future<void> recordChatStarted(String listingId);
  Future<void> updateListingStatus(String listingId, ListingStatus status);
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
}
