import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/listing.dart';
import '../../domain/models/offer.dart';
import '../../domain/models/price_history.dart';
import '../../domain/repositories/marketplace_repository.dart';
import '../../../../services/notification_service.dart';
import '../../../shared/domain/models/uni_notification.dart';

class MarketplaceRepositoryImpl implements MarketplaceRepository {
  final FirebaseFirestore _firestore;
  final NotificationService? _notificationService;

  MarketplaceRepositoryImpl(this._firestore, [this._notificationService]);

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
    ListingSortType? sortBy,
    ListingStatus? status,
  }) {
    // START WITH A BASE QUERY
    // To avoid complex composite index requirements (equality + inequality/orderBy),
    // we use a strategy of server-side sorting + broad fetching + client-side filtering.
    Query query = _firestore.collection('listings');

    // SERVER-SIDE SORTING (Must be the first orderBy field)
    switch (sortBy ?? ListingSortType.newest) {
      case ListingSortType.oldest:
        query = query.orderBy('createdAt', descending: false);
        break;
      case ListingSortType.lowestPrice:
        query = query.orderBy('price', descending: false);
        break;
      case ListingSortType.highestPrice:
        query = query.orderBy('price', descending: true);
        break;
      case ListingSortType.mostViewed:
        query = query.orderBy('viewsCount', descending: true);
        break;
      case ListingSortType.mostSaved:
        query = query.orderBy('savesCount', descending: true);
        break;
      case ListingSortType.newest:
      default:
        query = query.orderBy('createdAt', descending: true);
        break;
    }

    // BROAD FETCHING: Fetch more than requested to allow for client-side filtering
    // without losing data.
    final fetchLimit = (limit ?? 50) * 4;
    query = query.limit(fetchLimit);

    return query.snapshots().map((snapshot) {
      debugPrint('📖 Firestore: watchListings emitting ${snapshot.docs.length} raw docs');
      
      var items = snapshot.docs
          .map((doc) => Listing.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      // CLIENT-SIDE FILTERING (Bulletproof against index errors)
      
      // 1. Status Filter (Default to active)
      final targetStatus = status ?? ListingStatus.active;
      items = items.where((l) => l.status == targetStatus).toList();

      // 2. Category Filter
      if (category != null && category != 'All' && category.isNotEmpty) {
        items = items.where((l) => l.category == category).toList();
      }

      // 3. Featured Filter
      if (isFeatured == true) {
        items = items.where((l) => l.isFeatured == true).toList();
      }

      // 4. University Filter
      if (university != null && university.isNotEmpty) {
        items = items.where((l) => l.sellerUniversity == university).toList();
      }

      // 5. Price Filters
      if (minPrice != null) {
        items = items.where((l) => l.price >= minPrice).toList();
      }
      if (maxPrice != null) {
        items = items.where((l) => l.price <= maxPrice).toList();
      }

      // 6. Conditions Filter
      if (conditions != null && conditions.isNotEmpty) {
        items = items.where((l) => conditions.contains(l.condition.name)).toList();
      }

      // 7. Search Query Filter (Keyword matching)
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final queryTerms = searchQuery.toLowerCase().split(' ').where((s) => s.isNotEmpty).toList();
        
        // STRICT MODULE SEPARATION: Filter out non-marketplace intent
        final excludedTerms = {
          'house', 'hostel', 'rent', 'roommate', 'bedsit', 'apartment',
          'note', 'exam', 'paper', 'tutorial', 'document', 'study',
          'job', 'gig', 'freelance', 'work', 'internship', 'hire'
        };

        if (queryTerms.any((term) => excludedTerms.contains(term))) {
          return <Listing>[];
        }

        items = items.where((l) {
          final title = l.title.toLowerCase();
          final desc = l.description.toLowerCase();
          return queryTerms.any((term) => title.contains(term) || desc.contains(term));
        }).toList();
      }

      // Finally, take only the requested limit
      return limit != null ? items.take(limit).toList() : items;
    }).handleError((error) {
      debugPrint('❌ Firestore Error in watchListings: $error');
      return <Listing>[];
    });
  }

  @override
  Stream<List<Listing>> watchRecentlyViewed(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('recently_viewed')
        .orderBy('viewedAt', descending: true)
        .limit(20)
        .snapshots()
        .asyncMap((snapshot) async {
          final ids = snapshot.docs.map((doc) => doc.id).where((id) => id.isNotEmpty).toList();
          if (ids.isEmpty) return [];
          
          final listingsSnapshot = await _firestore
              .collection('listings')
              .where(FieldPath.documentId, whereIn: ids)
              .get();

          final listings = listingsSnapshot.docs
              .map((doc) => Listing.fromJson(doc.data() as Map<String, dynamic>))
              .toList();
              
          listings.sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));
          return listings;
        });
  }

  @override
  Stream<List<Listing>> watchTrendingListings({String? university, int limit = 10}) {
    // Fetch by view count descending
    Query query = _firestore.collection('listings')
        .orderBy('viewsCount', descending: true)
        .limit(limit * 5);
    
    return query.snapshots().map((snapshot) {
      var items = snapshot.docs
          .map((doc) => Listing.fromJson(doc.data() as Map<String, dynamic>))
          .where((l) => l.status == ListingStatus.active)
          .toList();
          
      if (university != null && university.isNotEmpty) {
        items = items.where((l) => l.sellerUniversity == university).toList();
      }
      
      return items.take(limit).toList();
    });
  }

  @override
  Stream<List<Listing>> watchRecommendedListings(String userId, {int limit = 10}) {
    if (userId.isEmpty) {
      return watchTrendingListings(limit: limit);
    }

    return _firestore.collection('users').doc(userId).snapshots().asyncMap((userDoc) async {
      if (!userDoc.exists) return [];
      
      final interests = List<String>.from(userDoc.data()?['interests'] ?? []);
      final university = userDoc.data()?['university'] as String?;

      // Fetch broad latest active listings
      Query query = _firestore.collection('listings')
          .orderBy('createdAt', descending: true)
          .limit(100);
      
      final snapshot = await query.get();
      var listings = snapshot.docs
          .map((doc) => Listing.fromJson(doc.data() as Map<String, dynamic>))
          .where((l) => l.status == ListingStatus.active)
          .toList();

      // Filter by interests client-side
      if (interests.isNotEmpty) {
        listings.sort((a, b) {
          final aMatch = interests.contains(a.category) ? 1 : 0;
          final bMatch = interests.contains(b.category) ? 1 : 0;
          return bMatch.compareTo(aMatch);
        });
      }
      
      if (university != null) {
        listings.sort((a, b) {
          if (a.sellerUniversity == university && b.sellerUniversity != university) return -1;
          if (a.sellerUniversity != university && b.sellerUniversity == university) return 1;
          return 0;
        });
      }
      
      return listings.take(limit).toList();
    });
  }

  @override
  Stream<List<Listing>> watchSimilarListings(Listing listing, {int limit = 6}) {
    return _firestore.collection('listings')
        .where('category', isEqualTo: listing.category)
        .limit(20)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Listing.fromJson(doc.data() as Map<String, dynamic>))
              .where((l) => l.id != listing.id && l.status == ListingStatus.active)
              .take(limit)
              .toList();
        });
  }

  @override
  Stream<List<String>> watchCollectionNames(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('collections')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  @override
  Future<void> createCollection(String userId, String name) async {
    if (userId.isEmpty || name.isEmpty) return;
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('collections')
        .doc(name)
        .set({'createdAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> deleteCollection(String userId, String name) async {
    if (userId.isEmpty || name.isEmpty) return;
    
    final batch = _firestore.batch();
    final collectionRef = _firestore.collection('users').doc(userId).collection('collections').doc(name);
    
    final items = await collectionRef.collection('listings').get();
    for (var doc in items.docs) {
      batch.delete(doc.reference);
    }
    
    batch.delete(collectionRef);
    await batch.commit();
  }

  @override
  Future<void> addToCollection(String userId, String collectionName, String listingId) async {
    if (userId.isEmpty || collectionName.isEmpty || listingId.isEmpty) return;
    
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('collections')
        .doc(collectionName)
        .collection('listings')
        .doc(listingId)
        .set({'addedAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> removeFromCollection(String userId, String collectionName, String listingId) async {
    if (userId.isEmpty || collectionName.isEmpty || listingId.isEmpty) return;
    
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('collections')
        .doc(collectionName)
        .collection('listings')
        .doc(listingId)
        .delete();
  }

  @override
  Stream<List<Listing>> watchCollectionListings(String userId, String collectionName) {
    if (userId.isEmpty || collectionName.isEmpty) return Stream.value([]);
    
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('collections')
        .doc(collectionName)
        .collection('listings')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final ids = snapshot.docs.map((doc) => doc.id).toList();
          if (ids.isEmpty) return [];
          
          final listingsSnapshot = await _firestore
              .collection('listings')
              .where(FieldPath.documentId, whereIn: ids.take(30).toList())
              .get();

          final listings = listingsSnapshot.docs
              .map((doc) => Listing.fromJson(doc.data() as Map<String, dynamic>))
              .toList();
              
          listings.sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));
          return listings;
        });
  }

  @override
  Future<void> makeOffer(Offer offer) async {
    await _firestore.collection('offers').doc(offer.id).set(offer.toJson());
    
    if (_notificationService != null) {
      await _notificationService!.sendNotification(
        recipientId: offer.sellerId,
        title: 'New Offer!',
        body: 'Someone offered KES ${offer.amount} for your item.',
        type: NotificationType.marketplace,
        targetId: offer.listingId,
        targetType: 'marketplace_offer',
      );
    }
  }

  @override
  Future<void> respondToOffer(String offerId, OfferStatus status, {double? counterAmount}) async {
    final offerDoc = await _firestore.collection('offers').doc(offerId).get();
    if (!offerDoc.exists) return;
    
    final offer = Offer.fromJson(offerDoc.data()!);
    final batch = _firestore.batch();
    
    batch.update(_firestore.collection('offers').doc(offerId), {
      'status': status.name,
      if (counterAmount != null) 'counterAmount': counterAmount,
    });
    
    await batch.commit();

    if (_notificationService != null) {
      String title = '';
      String body = '';
      
      switch (status) {
        case OfferStatus.accepted:
          title = 'Offer Accepted!';
          body = 'Your offer for "${offer.listingId}" was accepted.';
          break;
        case OfferStatus.rejected:
          title = 'Offer Rejected';
          body = 'Your offer for "${offer.listingId}" was declined.';
          break;
        case OfferStatus.countered:
          title = 'Counter-Offer Received';
          body = 'The seller countered your offer with KES $counterAmount.';
          break;
        default: break;
      }
      
      if (title.isNotEmpty) {
        await _notificationService!.sendNotification(
          recipientId: offer.buyerId,
          title: title,
          body: body,
          type: NotificationType.marketplace,
          targetId: offer.listingId,
          targetType: 'marketplace_offer',
        );
      }
    }
  }

  @override
  Stream<List<Offer>> watchListingOffers(String listingId) {
    return _firestore
        .collection('offers')
        .where('listingId', isEqualTo: listingId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Offer.fromJson(d.data())).toList());
  }

  @override
  Stream<List<Offer>> watchUserOffers(String userId) {
    return _firestore
        .collection('offers')
        .where('buyerId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Offer.fromJson(d.data())).toList());
  }

  @override
  Future<Map<String, dynamic>> getSellerStats(String userId) async {
    final listings = await _firestore.collection('listings')
        .where('sellerId', isEqualTo: userId)
        .get();
        
    int totalViews = 0;
    int totalSaves = 0;
    int soldCount = 0;
    int activeCount = 0;
    
    for (var doc in listings.docs) {
      final data = doc.data();
      totalViews += (data['viewsCount'] ?? 0) as int;
      totalSaves += (data['savesCount'] ?? 0) as int;
      if (data['status'] == ListingStatus.sold.name) soldCount++;
      if (data['status'] == ListingStatus.active.name) activeCount++;
    }
    
    return {
      'totalViews': totalViews,
      'totalSaves': totalSaves,
      'soldCount': soldCount,
      'activeCount': activeCount,
      'totalListings': listings.docs.length,
    };
  }

  @override
  Stream<List<Listing>> watchSellerListingsByStatus(String sellerId, ListingStatus status) {
    return _firestore.collection('listings')
        .where('sellerId', isEqualTo: sellerId)
        .where('status', isEqualTo: status.name)
        .snapshots()
        .map((s) => s.docs.map((d) => Listing.fromJson(d.data())).toList());
  }

  @override
  Future<List<String>> getSearchSuggestions(String query) async {
    if (query.isEmpty) return [];
    
    final snapshot = await _firestore.collection('listings')
        .where('title', isGreaterThanOrEqualTo: query)
        .where('title', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .get();
        
    return snapshot.docs
        .where((doc) => (doc.data()['status'] ?? 'active') == 'active')
        .map((doc) => doc.data()['title'] as String)
        .take(5)
        .toList();
  }

  @override
  Future<void> saveSearchQuery(String userId, String query) async {
    if (userId.isEmpty || query.isEmpty) return;
    
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('recent_searches')
        .doc(query.toLowerCase().trim())
        .set({'timestamp': FieldValue.serverTimestamp()});
  }

  @override
  Stream<List<String>> watchRecentSearches(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('recent_searches')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  @override
  Future<List<Listing>> getListings({int limit = 20, Listing? startAfter}) async {
    Query query = _firestore.collection('listings')
        .orderBy('createdAt', descending: true)
        .limit(limit * 2);

    if (startAfter != null) {
      final doc = await _firestore.collection('listings').doc(startAfter.id).get();
      if (doc.exists) {
        query = query.startAfterDocument(doc);
      }
    }

    final snapshot = await query.get(const GetOptions(source: Source.serverAndCache));
    return snapshot.docs
        .map((doc) => Listing.fromJson(doc.data() as Map<String, dynamic>))
        .where((l) => l.status == ListingStatus.active)
        .take(limit)
        .toList();
  }

  @override
  Future<Listing?> getListingById(String id) async {
    if (id.isEmpty) return null;
    final doc = await _firestore.collection('listings').doc(id).get();
    if (!doc.exists) return null;
    return Listing.fromJson(doc.data() as Map<String, dynamic>);
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
          
          final limitedIds = ids.take(30).toList();
          
          final listingsSnapshot = await _firestore
              .collection('listings')
              .where(FieldPath.documentId, whereIn: limitedIds)
              .get();

          final listings = listingsSnapshot.docs
              .map((doc) => Listing.fromJson(doc.data() as Map<String, dynamic>))
              .toList();
              
          listings.sort((a, b) => limitedIds.indexOf(a.id).compareTo(limitedIds.indexOf(b.id)));
          return listings;
        });
  }

  @override
  Future<void> createListing(Listing listing) async {
    if (listing.id.isEmpty) throw Exception('Listing ID cannot be empty');
    
    final listingRef = _firestore.collection('listings').doc(listing.id);
    final doc = await listingRef.get();
    final isNew = !doc.exists;

    final batch = _firestore.batch();
    batch.set(listingRef, listing.toJson(), SetOptions(merge: true));
    
    if (isNew && listing.sellerId.isNotEmpty) {
      final userRef = _firestore.collection('users').doc(listing.sellerId);
      batch.update(userRef, {
        'activeListingsCount': FieldValue.increment(1),
        'trustScore': FieldValue.increment(2.0),
      });
    }

    await batch.commit();
  }

  @override
  Future<void> updateListing(Listing listing) async {
    await _firestore.collection('listings').doc(listing.id).update(listing.toJson());
  }

  @override
  Future<void> deleteListing(String id) async {
    if (id.isEmpty) return;
    
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
      
      final listing = await getListingById(listingId);
      if (listing != null && listing.sellerId.isNotEmpty && _notificationService != null) {
        await _notificationService!.sendNotification(
          recipientId: listing.sellerId,
          title: 'Item Saved!',
          body: 'Someone saved your listing: ${listing.title}',
          type: NotificationType.marketplace,
          targetId: listingId,
          targetType: 'marketplace',
        );
      }
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
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> recordView(String listingId, {String? userId}) async {
    if (listingId.isEmpty) return;
    
    final batch = _firestore.batch();
    batch.update(_firestore.collection('listings').doc(listingId), {
      'viewsCount': FieldValue.increment(1),
    });
    
    if (userId != null && userId.isNotEmpty) {
      final historyRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('recently_viewed')
          .doc(listingId);
          
      batch.set(historyRef, {
        'viewedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
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

    if (status == ListingStatus.sold && currentStatus != ListingStatus.sold.name) {
      if (sellerId != null && (sellerId as String).isNotEmpty) {
        batch.update(_firestore.collection('users').doc(sellerId), {
          'completedSalesCount': FieldValue.increment(1),
          'activeListingsCount': FieldValue.increment(-1),
          'trustScore': FieldValue.increment(5.0),
        });
      }
    } else if (status == ListingStatus.active && currentStatus == ListingStatus.sold.name) {
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
  Future<void> updateListingPrice(String listingId, double newPrice) async {
    final doc = await _firestore.collection('listings').doc(listingId).get();
    if (!doc.exists) return;
    
    final oldPrice = (doc.data()?['price'] as num).toDouble();
    if (oldPrice == newPrice) return;
    
    final history = PriceHistory(price: oldPrice, timestamp: DateTime.now());
    
    await _firestore.collection('listings').doc(listingId).update({
      'price': newPrice,
      'priceHistory': FieldValue.arrayUnion([history.toJson()]),
    });

    // Notify savers about price reduction
    if (newPrice < oldPrice) {
      // Logic to fetch users who saved this listing and notify them
      // This would ideally be a cloud function for scalability
    }
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
    // Only allow review if listing is sold and user is the buyer (would need order/transaction record)

    final batch = _firestore.batch();
    
    final reviewRef = _firestore.collection('users').doc(sellerId).collection('reviews').doc(listingId);
    batch.set(reviewRef, {
      'buyerId': buyerId,
      'listingId': listingId,
      'rating': rating,
      'comment': comment,
      'timestamp': FieldValue.serverTimestamp(),
    });
    
    final userRef = _firestore.collection('users').doc(sellerId);
    final userDoc = await userRef.get();
    
    if (userDoc.exists) {
      final currentAvg = (userDoc.data()?['averageRating'] ?? 0.0).toDouble();
      final currentCount = (userDoc.data()?['ratingsCount'] ?? 0).toInt();
      
      final newCount = currentCount + 1;
      final newAvg = ((currentAvg * currentCount) + rating) / newCount;
      
      batch.update(userRef, {
        'averageRating': newAvg,
        'ratingsCount': newCount,
        'trustScore': FieldValue.increment(rating >= 4 ? 2.0 : -1.0),
      });
    }

    await batch.commit();

    if (_notificationService != null) {
      await _notificationService!.sendNotification(
        recipientId: sellerId,
        title: 'New Review!',
        body: 'A buyer left you a $rating-star review.',
        type: NotificationType.review,
        targetId: listingId,
        targetType: 'marketplace',
      );
    }
  }
}
