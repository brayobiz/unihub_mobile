import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/listing.dart';
import '../../domain/repositories/marketplace_repository.dart';

class MarketplaceRepositoryImpl implements MarketplaceRepository {
  final FirebaseFirestore _firestore;

  MarketplaceRepositoryImpl(this._firestore);

  @override
  Stream<List<Listing>> watchListings({
    int? limit,
    String? category,
    List<String>? conditions,
    double? minPrice,
    double? maxPrice,
    bool? isFeatured,
    String? university,
    String? searchQuery,
  }) {
    Query query = _firestore.collection('listings');

    if (category != null && category != 'All') {
      query = query.where('category', isEqualTo: category);
    }

    if (isFeatured == true) {
      query = query.where('isFeatured', isEqualTo: true);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final keywords = searchQuery.toLowerCase().split(' ').where((s) => s.isNotEmpty).toList();
      if (keywords.isNotEmpty) {
        query = query.where('searchKeywords', arrayContains: keywords.first);
      }
    }

    // Default sorting
    query = query.orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      debugPrint('📖 Firestore: Received marketplace snapshot with ${snapshot.docs.length} docs');
      var items = snapshot.docs
          .map((doc) => Listing.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      // Fallback client-side filtering for complex fields (to avoid too many indexes)
      if (conditions != null && conditions.isNotEmpty) {
        items = items.where((l) => conditions.contains(l.condition.name)).toList();
      }

      if (minPrice != null) {
        items = items.where((l) => l.price >= minPrice).toList();
      }

      if (maxPrice != null) {
        items = items.where((l) => l.price <= maxPrice).toList();
      }

      if (university != null) {
        items = items.where((l) => l.sellerUniversity == university).toList();
      }

      return items;
    });
  }

  @override
  Future<List<Listing>> getListings({int limit = 20, Listing? startAfter}) async {
    Query query = _firestore.collection('listings')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      // In production, you'd use startAfterDocument(doc) but startAfter works if fields match
      final doc = await _firestore.collection('listings').doc(startAfter.id).get();
      if (doc.exists) {
        query = query.startAfterDocument(doc);
      }
    }

    final snapshot = await query.get(const GetOptions(source: Source.serverAndCache));
    return snapshot.docs.map((doc) => Listing.fromJson(doc.data() as Map<String, dynamic>)).toList();
  }

  @override
  Stream<List<Listing>> watchSellerListings(String sellerId) {
    if (sellerId.isEmpty) return Stream.value([]);
    
    return _firestore
        .collection('listings')
        .where('sellerId', isEqualTo: sellerId)
        .snapshots()
        .map((snapshot) {
          var items = snapshot.docs
              .map((doc) => Listing.fromJson(doc.data() as Map<String, dynamic>))
              .toList();
          
          // Sort in-memory to avoid needing a composite index for (sellerId + createdAt)
          items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return items;
        });
  }

  @override
  Stream<List<Listing>> watchSavedListings(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('saved_listings')
        .orderBy('savedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final ids = snapshot.docs.map((doc) => doc.id).where((id) => id.isNotEmpty).toList();
          if (ids.isEmpty) return [];
          
          // Use whereIn for bulk fetch - more efficient than individual fetches
          // Firestore whereIn supports up to 30 items
          final limitedIds = ids.take(30).toList();
          
          final listingsSnapshot = await _firestore
              .collection('listings')
              .where(FieldPath.documentId, whereIn: limitedIds)
              .get();

          final listings = listingsSnapshot.docs
              .map((doc) => Listing.fromJson(doc.data() as Map<String, dynamic>))
              .toList();
              
          // Maintain the order from saved_listings (descending savedAt)
          listings.sort((a, b) {
            final indexA = limitedIds.indexOf(a.id);
            final indexB = limitedIds.indexOf(b.id);
            return indexA.compareTo(indexB);
          });

          return listings;
        });
  }

  @override
  Future<void> createListing(Listing listing) async {
    if (listing.id.isEmpty) throw Exception('Listing ID cannot be empty');
    
    debugPrint('📝 Firestore: Processing listing ${listing.id}');

    final listingRef = _firestore.collection('listings').doc(listing.id);
    final doc = await listingRef.get();
    final isNew = !doc.exists;

    final batch = _firestore.batch();
    
    // 1. Create/Update the listing
    batch.set(listingRef, listing.toJson(), SetOptions(merge: true));
    
    // 2. Increment counters only for NEW listings
    if (isNew && listing.sellerId.isNotEmpty) {
      final userRef = _firestore.collection('users').doc(listing.sellerId);
      batch.update(userRef, {
        'activeListingsCount': FieldValue.increment(1),
        'trustScore': FieldValue.increment(2.0),
      });
    }

    try {
      await batch.commit();
      debugPrint('✅ Firestore: Listing ${isNew ? 'created' : 'updated'} successfully');
    } catch (e) {
      debugPrint('❌ Firestore: Failed to process listing: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteListing(String id) async {
    if (id.isEmpty) return;
    
    // We need the sellerId to decrement count, so fetch first
    final doc = await _firestore.collection('listings').doc(id).get();
    if (!doc.exists) return;
    
    final sellerId = doc.data()?['sellerId'];
    final batch = _firestore.batch();
    
    batch.delete(_firestore.collection('listings').doc(id));
    
    if (sellerId != null && (sellerId as String).isNotEmpty) {
      batch.update(_firestore.collection('users').doc(sellerId), {
        'activeListingsCount': FieldValue.increment(-1),
      });
    }

    await batch.commit();
  }

  @override
  Future<void> toggleSaveListing(String userId, String listingId) async {
    if (userId.isEmpty || listingId.isEmpty) return;
    
    final saveRef = _firestore.collection('users').doc(userId).collection('saved_listings').doc(listingId);
    final doc = await saveRef.get();
    if (doc.exists) {
      await saveRef.delete();
      await recordSave(listingId, false);
    } else {
      await saveRef.set({'savedAt': FieldValue.serverTimestamp()});
      await recordSave(listingId, true);
    }
  }

  @override
  Future<void> recordSave(String listingId, bool isSaved) async {
    if (listingId.isEmpty) return;
    await _firestore.collection('listings').doc(listingId).update({
      'savesCount': FieldValue.increment(isSaved ? 1 : -1),
    });
  }

  @override
  Future<void> recordChatStarted(String listingId) async {
    if (listingId.isEmpty) return;
    await _firestore.collection('listings').doc(listingId).update({
      'chatsStartedCount': FieldValue.increment(1),
    });
  }

  @override
  Future<void> boostListing(String listingId) async {
    if (listingId.isEmpty) return;
    await _firestore.collection('listings').doc(listingId).update({
      'isFeatured': true,
      'createdAt': FieldValue.serverTimestamp(), // Bring to top
    });
  }

  @override
  Future<void> recordView(String listingId) async {
    if (listingId.isEmpty) return;
    await _firestore.collection('listings').doc(listingId).update({
      'viewsCount': FieldValue.increment(1),
    });
  }

  @override
  Future<void> updateListingStatus(String listingId, ListingStatus status) async {
    if (listingId.isEmpty) return;
    
    final doc = await _firestore.collection('listings').doc(listingId).get();
    if (!doc.exists) return;
    
    final currentStatus = doc.data()?['status'];
    final sellerId = doc.data()?['sellerId'];

    final batch = _firestore.batch();
    batch.update(_firestore.collection('listings').doc(listingId), {
      'status': status.name,
    });

    // If item is marked as sold, increment sales and decrement active count
    if (status == ListingStatus.sold && currentStatus != ListingStatus.sold.name) {
      if (sellerId != null && (sellerId as String).isNotEmpty) {
        batch.update(_firestore.collection('users').doc(sellerId), {
          'completedSalesCount': FieldValue.increment(1),
          'activeListingsCount': FieldValue.increment(-1),
          'trustScore': FieldValue.increment(5.0), // Reward for successful sale
        });
      }
    } else if (status == ListingStatus.active && currentStatus == ListingStatus.sold.name) {
      // Reverting from sold back to active
       if (sellerId != null && (sellerId as String).isNotEmpty) {
        batch.update(_firestore.collection('users').doc(sellerId), {
          'completedSalesCount': FieldValue.increment(-1),
          'activeListingsCount': FieldValue.increment(1),
        });
      }
    }

    await batch.commit();
  }

  @override
  Future<void> reportListing({
    required String listingId,
    required String reporterId,
    required String reason,
  }) async {
    await _firestore.collection('reports').add({
      'type': 'listing',
      'targetId': listingId,
      'reporterId': reporterId,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> submitReview({
    required String sellerId,
    required String buyerId,
    required String listingId,
    required double rating,
    required String comment,
  }) async {
    final batch = _firestore.batch();
    
    // 1. Add review
    final reviewRef = _firestore.collection('users').doc(sellerId).collection('reviews').doc(listingId);
    batch.set(reviewRef, {
      'buyerId': buyerId,
      'listingId': listingId,
      'rating': rating,
      'comment': comment,
      'timestamp': FieldValue.serverTimestamp(),
    });
    
    // 2. Update seller average rating
    final userRef = _firestore.collection('users').doc(sellerId);
    batch.update(userRef, {
      'ratingsCount': FieldValue.increment(1),
    });

    await batch.commit();
  }
}
