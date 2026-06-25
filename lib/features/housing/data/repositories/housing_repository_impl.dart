import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/housing_listing.dart';
import '../../domain/models/roommate_profile.dart';
import '../../domain/models/housing_review.dart';

import '../../domain/repositories/housing_repository.dart';

class HousingRepositoryImpl implements HousingRepository {
  final FirebaseFirestore _firestore;

  HousingRepositoryImpl(this._firestore);

  @override
  Stream<List<HousingListing>> watchListings({
    String? campus,
    HousingType? type,
    double? maxBudget,
    int limit = 30,
  }) {
    // Ultimate Resilience: Remove orderBy from query
    return _firestore.collection('housing_listings')
        .limit(limit * 3)
        .snapshots()
        .map((snapshot) {
      var listings = snapshot.docs.map((doc) => HousingListing.fromFirestore(doc)).toList();
      
      // Sort by freshness in memory
      listings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Filter by campus
      if (campus != null) {
        listings = listings.where((l) => l.campus == campus).toList();
      }
      
      // Filter by type
      if (type != null) {
        listings = listings.where((l) => l.type == type).toList();
      }

      // Filter by budget
      if (maxBudget != null) {
        listings = listings.where((l) => l.price <= maxBudget).toList();
      }
      
      // Sort by freshness
      listings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return listings;
    });
  }

  @override
  Stream<List<RoommateProfile>> watchRoommates({String? campus, int limit = 30}) {
    // Optimization: Add server-side ordering and limit
    return _firestore.collection('roommates')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      var profiles = snapshot.docs.map((doc) => RoommateProfile.fromFirestore(doc)).toList();
      
      // Filter active only
      profiles = profiles.where((p) => p.isActive).toList();
      
      // Sort by freshness first
      profiles.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Boost relevance if campus is known (University-first sorting)
      if (campus != null) {
        profiles.sort((a, b) {
          if (a.campus == campus && b.campus != campus) return -1;
          if (a.campus != campus && b.campus == campus) return 1;
          return 0;
        });
      }
      return profiles;
    });
  }

  @override
  Stream<List<HousingReview>> watchReviews(String listingId) {
    return _firestore.collection('housing_reviews')
        .where('listingId', isEqualTo: listingId)
        .snapshots()
        .map((snapshot) {
          var reviews = snapshot.docs.map((doc) => HousingReview.fromFirestore(doc)).toList();
          // Sort client-side to avoid composite index requirement
          reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return reviews;
        });
  }

  @override
  Future<void> createListing(HousingListing listing) async {
    await _firestore.collection('housing_listings').doc(listing.id).set(listing.toFirestore());
  }

  @override
  Future<void> updateListing(HousingListing listing) async {
    await _firestore.collection('housing_listings').doc(listing.id).update(listing.toFirestore());
  }

  @override
  Future<void> createRoommateProfile(RoommateProfile profile) async {
    await _firestore.collection('roommates').doc(profile.id).set(profile.toFirestore());
  }

  @override
  Future<void> submitReview(HousingReview review) async {
    await _firestore.runTransaction((transaction) async {
      final reviewRef = _firestore.collection('housing_reviews').doc();
      final listingRef = _firestore.collection('housing_listings').doc(review.listingId);

      transaction.set(reviewRef, review.toFirestore());

      // Update listing average rating
      final listingDoc = await transaction.get(listingRef);
      if (listingDoc.exists) {
        final data = listingDoc.data()!;
        final currentRating = (data['rating'] ?? 0.0) as double;
        final currentCount = (data['reviewCount'] ?? 0) as int;
        
        final newCount = currentCount + 1;
        final newRating = ((currentRating * currentCount) + review.rating) / newCount;

        transaction.update(listingRef, {
          'rating': newRating,
          'reviewCount': newCount,
        });
      }
    });
  }

  @override
  Future<void> reportListing(String listingId, String userId, String reason) async {
    await _firestore.collection('housing_reports').add({
      'listingId': listingId,
      'reportedBy': userId,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }
}
