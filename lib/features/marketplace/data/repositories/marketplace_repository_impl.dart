import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/listing.dart';
import '../../domain/models/offer.dart';
import '../../domain/models/price_history.dart';
import '../../domain/models/seller_stats.dart';
import '../../domain/models/saved_search.dart';
import '../../domain/repositories/marketplace_repository.dart';
import '../../../../services/notification_service.dart';
import '../../../shared/domain/models/uni_notification.dart';

class MarketplaceRepositoryImpl implements MarketplaceRepository {
  final FirebaseFirestore _firestore;
  final String? _browsingCampus;
  final NotificationService? _notificationService;

  MarketplaceRepositoryImpl(this._firestore, this._browsingCampus, [this._notificationService]);

  @override
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
  }) {
    // START WITH A BASE QUERY
    // Optimized: Apply server-side status filter first as it's the most common
    Query query = _firestore.collection('listings')
        .where('status', isEqualTo: (status ?? ListingStatus.active).name);

    // Apply category server-side if provided and not "All"
    if (category != null && category != 'All' && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }

    // Apply campus server-side if browsing context is set
    if (_browsingCampus != null && _browsingCampus!.isNotEmpty) {
      query = query.where('sellerUniversity', isEqualTo: _browsingCampus);
    }

    // Apply sorting server-side (Note: This requires composite indexes for the above filters)
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

    // Reduced fetch limit: Since we apply more filters server-side, 
    // we don't need a massive buffer.
    final fetchLimit = (limit ?? 40) + 10;
    query = query.limit(fetchLimit);

    return query.snapshots().map((snapshot) {
      var items = snapshot.docs
          .map((doc) => Listing.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      // Remaining client-side filters (complex types or less frequent)
      if (isFeatured == true) {
        items = items.where((l) => l.isFeatured == true).toList();
      }

      if (minPrice != null) {
        items = items.where((l) => l.price >= minPrice).toList();
      }
      if (maxPrice != null) {
        items = items.where((l) => l.price <= maxPrice).toList();
      }

      if (conditions != null && conditions.isNotEmpty) {
        items = items.where((l) => conditions.contains(l.condition.name)).toList();
      }

      if (categoryAttributes != null && categoryAttributes.isNotEmpty) {
        items = items.where((l) {
          for (var entry in categoryAttributes.entries) {
            final key = entry.key;
            final value = entry.value;
            if (value == null) continue;

            if (key == 'brand' && l.brand != value) return false;
            if (key == 'storage' && l.storage != value) return false;
            if (key == 'color' && l.color != value) return false;

            if (l.attributes.containsKey(key)) {
               if (l.attributes[key] != value) return false;
            } else {
               if (['brand', 'storage', 'color'].contains(key)) {
               } else {
                  return false;
               }
            }
          }
          return true;
        }).toList();
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final queryTerms = searchQuery.toLowerCase().split(' ').where((s) => s.isNotEmpty).toList();
        
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
        .limit(30)
        .snapshots()
        .asyncMap((snapshot) async {
          final ids = snapshot.docs.map((doc) => doc.id).where((id) => id.isNotEmpty).toList();
          if (ids.isEmpty) return [];
          
          final listingsSnapshot = await _firestore
              .collection('listings')
              .where(FieldPath.documentId, whereIn: ids.take(30).toList())
              .get();

          final listings = listingsSnapshot.docs
              .map((doc) => Listing.fromJson(doc.data() as Map<String, dynamic>))
              .where((l) => l.status == ListingStatus.active)
              .toList();
              
          listings.sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));
          return listings;
        });
  }

  @override
  Future<void> clearRecentlyViewed(String userId) async {
    if (userId.isEmpty) return;
    
    final batch = _firestore.batch();
    final collection = _firestore.collection('users').doc(userId).collection('recently_viewed');
    final snapshot = await collection.get();
    
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
  }

  @override
  Stream<List<Listing>> watchTrendingListings({int limit = 10}) {
    return _firestore.collection('listings')
        .where('status', isEqualTo: ListingStatus.active.name)
        .orderBy('viewsCount', descending: true)
        .limit(limit * 10)
        .snapshots()
        .map((snapshot) {
          var items = snapshot.docs
              .map((doc) => Listing.fromJson(doc.data() as Map<String, dynamic>))
              .toList();

          if (_browsingCampus != null && _browsingCampus!.isNotEmpty) {
            items = items.where((l) => l.sellerUniversity == _browsingCampus).toList();
          }

          items.sort((a, b) {
            double aScore = a.viewsCount.toDouble();
            aScore += a.savesCount * 2.0;
            if (a.isFeatured) aScore += 50.0;
            
            final aAgeDays = DateTime.now().difference(a.createdAt).inDays;
            if (aAgeDays <= 3) aScore += (3 - aAgeDays) * 10.0;

            double bScore = b.viewsCount.toDouble();
            bScore += b.savesCount * 2.0;
            if (b.isFeatured) bScore += 50.0;
            
            final bAgeDays = DateTime.now().difference(b.createdAt).inDays;
            if (bAgeDays <= 3) bScore += (3 - bAgeDays) * 10.0;

            return bScore.compareTo(aScore);
          });
          
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
      
      final data = userDoc.data() ?? {};
      final interests = List<String>.from(data['interests'] ?? []);
      final university = data['university'] as String?;

      final recentSnapshot = await _firestore.collection('users').doc(userId)
          .collection('recently_viewed').orderBy('viewedAt', descending: true).limit(5).get();
      
      final recentCategories = <String>{};
      if (recentSnapshot.docs.isNotEmpty) {
        final recentIds = recentSnapshot.docs.map((d) => d.id).toList();
        final listingsSnapshot = await _firestore.collection('listings')
            .where(FieldPath.documentId, whereIn: recentIds).get();
        
        for (var doc in listingsSnapshot.docs) {
          final cat = doc.data()['category'] as String?;
          if (cat != null) recentCategories.add(cat);
        }
      }

      Query query = _firestore.collection('listings')
          .where('status', isEqualTo: ListingStatus.active.name)
          .orderBy('createdAt', descending: true);

      if (_browsingCampus != null && _browsingCampus!.isNotEmpty) {
        query = query.where('sellerUniversity', isEqualTo: _browsingCampus);
      }

      final snapshot = await query.limit(limit * 4).get();

      var listings = snapshot.docs
          .map((doc) => Listing.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      listings.sort((a, b) {
        double aScore = 0;
        double bScore = 0;

        if (interests.contains(a.category)) aScore += 20;
        if (interests.contains(b.category)) bScore += 20;
        
        if (recentCategories.contains(a.category)) aScore += 15;
        if (recentCategories.contains(b.category)) bScore += 15;

        if (university != null && a.sellerUniversity == university) aScore += 12;
        if (university != null && b.sellerUniversity == university) bScore += 12;

        if (a.isFeatured) aScore += 10;
        if (b.isFeatured) bScore += 10;

        aScore += (a.viewsCount / 100).clamp(0.0, 5.0);
        bScore += (b.viewsCount / 100).clamp(0.0, 5.0);

        final aAgeHours = DateTime.now().difference(a.createdAt).inHours;
        if (aAgeHours < 48) aScore += (48 - aAgeHours) / 4.0;
        
        final bAgeHours = DateTime.now().difference(b.createdAt).inHours;
        if (bAgeHours < 48) bScore += (48 - bAgeHours) / 4.0;

        return bScore.compareTo(aScore);
      });
      
      return listings.take(limit).toList();
    });
  }

  @override
  Stream<List<Listing>> watchSimilarListings(Listing listing, {int limit = 6}) {
    return _firestore.collection('listings')
        .where('category', isEqualTo: listing.category)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          var items = snapshot.docs
              .map((doc) => Listing.fromJson(doc.data() as Map<String, dynamic>))
              .where((l) => l.id != listing.id && l.status == ListingStatus.active)
              .toList();

          items.sort((a, b) {
            int aScore = 0;
            int bScore = 0;

            if (a.campusLocation == listing.campusLocation) aScore += 5;
            if (b.campusLocation == listing.campusLocation) bScore += 5;

            final priceDiffA = (a.price - listing.price).abs();
            if (priceDiffA <= listing.price * 0.3) aScore += 3;
            
            final priceDiffB = (b.price - listing.price).abs();
            if (priceDiffB <= listing.price * 0.3) bScore += 3;

            if (listing.brand != null) {
              if (a.brand == listing.brand) aScore += 4;
              if (b.brand == listing.brand) bScore += 4;
            }

            return bScore.compareTo(aScore);
          });

          return items.take(limit).toList();
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
      final listing = await getListingById(offer.listingId);
      await _notificationService!.sendNotification(
        recipientId: offer.sellerId,
        actorId: offer.buyerId,
        title: 'New Offer!',
        body: 'Someone offered KES ${offer.amount} for "${listing?.title ?? 'your item'}".',
        type: NotificationType.marketplace,
        targetId: offer.listingId,
        targetType: 'marketplace_offer',
        metadata: {
          'offerId': offer.id,
          'amount': offer.amount,
          'buyerId': offer.buyerId,
        },
      );
    }
  }

  @override
  Future<void> respondToOffer(String offerId, OfferStatus status, {double? counterAmount, String? sellerMessage}) async {
    final offerDoc = await _firestore.collection('offers').doc(offerId).get();
    if (!offerDoc.exists) return;
    
    final offer = Offer.fromJson(offerDoc.data()!);
    final batch = _firestore.batch();
    
    batch.update(_firestore.collection('offers').doc(offerId), {
      'status': status.name,
      if (counterAmount != null) 'counterAmount': counterAmount,
      if (sellerMessage != null) 'sellerMessage': sellerMessage,
    });
    
    if (status == OfferStatus.accepted) {
      batch.update(_firestore.collection('listings').doc(offer.listingId), {
        'status': ListingStatus.sold.name,
      });
      
      final userRef = _firestore.collection('users').doc(offer.sellerId);
      batch.update(userRef, {
        'completedSalesCount': FieldValue.increment(1),
        'activeListingsCount': FieldValue.increment(-1),
        'trustScore': FieldValue.increment(10.0),
      });
    }
    
    await batch.commit();

    if (_notificationService != null) {
      String title = '';
      String body = '';
      final listing = await getListingById(offer.listingId);
      final listingTitle = listing?.title ?? 'your item';
      
      switch (status) {
        case OfferStatus.accepted:
          title = 'Offer Accepted! 🎉';
          body = sellerMessage != null && sellerMessage.isNotEmpty 
              ? '$sellerMessage. Tap to message the seller!'
              : 'Your offer for "$listingTitle" was accepted. Tap to message the seller!';
          break;
        case OfferStatus.rejected:
          title = 'Offer Rejected';
          body = sellerMessage != null && sellerMessage.isNotEmpty
              ? sellerMessage
              : 'Your offer for "$listingTitle" was declined.';
          break;
        case OfferStatus.countered:
          title = 'Counter-Offer Received';
          body = 'The seller countered your offer for "$listingTitle" with KES $counterAmount.';
          break;
        default: break;
      }
      
      if (title.isNotEmpty) {
        await _notificationService!.sendNotification(
          recipientId: offer.buyerId,
          actorId: offer.sellerId,
          title: title,
          body: body,
          type: NotificationType.marketplace,
          targetId: offer.listingId,
          targetType: 'marketplace',
          metadata: {
            'offerId': offer.id,
            'status': status.name,
            if (sellerMessage != null) 'sellerMessage': sellerMessage,
          },
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
  Future<SellerStats> getSellerStats(String userId) async {
    final listings = await _firestore.collection('listings')
        .where('sellerId', isEqualTo: userId)
        .get();
        
    int totalViews = 0;
    int totalSaves = 0;
    int totalChats = 0;
    int soldCount = 0;
    int activeCount = 0;
    
    final engagementList = <ListingEngagement>[];
    
    for (var doc in listings.docs) {
      final data = doc.data();
      final views = (data['viewsCount'] ?? 0) as int;
      final saves = (data['savesCount'] ?? 0) as int;
      final chats = (data['chatsStartedCount'] ?? 0) as int;
      final statusStr = data['status'] as String? ?? 'active';
      
      totalViews += views;
      totalSaves += saves;
      totalChats += chats;
      
      if (statusStr == ListingStatus.sold.name) soldCount++;
      else if (statusStr == ListingStatus.active.name) activeCount++;
      
      engagementList.add(ListingEngagement(
        listingId: doc.id,
        title: data['title'] as String? ?? 'Untitled',
        views: views,
        saves: saves,
        chats: chats,
        status: statusStr,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ));
    }
    
    // Sort by performance (views + saves*2 + chats*5)
    engagementList.sort((a, b) {
      final aScore = a.views + (a.saves * 2) + (a.chats * 5);
      final bScore = b.views + (b.saves * 2) + (b.chats * 5);
      return bScore.compareTo(aScore);
    });
    
    return SellerStats(
      activeListingsCount: activeCount,
      totalViews: totalViews,
      totalSaves: totalSaves,
      totalChatsStarted: totalChats,
      soldCount: soldCount,
      topPerformingListings: engagementList.take(5).toList(),
    );
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
  Future<void> clearRecentSearches(String userId) async {
    if (userId.isEmpty) return;
    
    final batch = _firestore.batch();
    final collection = _firestore.collection('users').doc(userId).collection('recent_searches');
    final snapshot = await collection.get();
    
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
  }

  @override
  Future<List<String>> getPopularSearches() async {
    return ['iPhone', 'Laptop', 'Nike', 'Table', 'Textbook', 'Bicycle'];
  }

  @override
  Future<void> saveSearch(SavedSearch search) async {
    await _firestore
        .collection('users')
        .doc(search.userId)
        .collection('saved_searches')
        .doc(search.id)
        .set(search.toJson());
  }

  @override
  Future<void> deleteSavedSearch(String userId, String searchId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('saved_searches')
        .doc(searchId)
        .delete();
  }

  @override
  Stream<List<SavedSearch>> watchSavedSearches(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('saved_searches')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SavedSearch.fromJson(doc.data()))
            .toList());
  }

  @override
  Future<void> updateSavedSearchNotification(String userId, String searchId, bool enabled) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('saved_searches')
        .doc(searchId)
        .update({'notificationsEnabled': enabled});
  }

  @override
  Future<List<Listing>> getListings({int limit = 20, Listing? startAfter}) async {
    Query query = _firestore.collection('listings')
        .where('status', isEqualTo: ListingStatus.active.name)
        .orderBy('createdAt', descending: true);

    if (_browsingCampus != null && _browsingCampus!.isNotEmpty) {
      query = query.where('sellerUniversity', isEqualTo: _browsingCampus);
    }

    if (startAfter != null) {
      final doc = await _firestore.collection('listings').doc(startAfter.id).get();
      if (doc.exists) {
        query = query.startAfterDocument(doc);
      }
    }

    final snapshot = await query.limit(limit).get(const GetOptions(source: Source.serverAndCache));
    return snapshot.docs
        .map((doc) => Listing.fromJson(doc.data() as Map<String, dynamic>))
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
  Stream<Listing?> watchListingById(String id) {
    if (id.isEmpty) return Stream.value(null);
    return _firestore.collection('listings').doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Listing.fromJson(doc.data() as Map<String, dynamic>);
    });
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
    // SECURITY FIX: Re-verify ownership before update
    final doc = await _firestore.collection('listings').doc(listing.id).get();
    if (!doc.exists) throw Exception('Listing not found');
    if (doc.data()?['sellerId'] != listing.sellerId) {
      throw Exception('Unauthorized: You do not own this listing');
    }
    await _firestore.collection('listings').doc(listing.id).update(listing.toJson());
  }

  @override
  Future<void> deleteListing(String id, String userId) async {
    if (id.isEmpty) return;
    
    final doc = await _firestore.collection('listings').doc(id).get();
    if (!doc.exists) return;
    
    final sellerId = doc.data()?['sellerId'];
    if (sellerId != userId) {
       throw Exception('Unauthorized: You do not own this listing');
    }

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
    
    if (userId == null || userId.isEmpty) {
      await _firestore.collection('listings').doc(listingId).update({
        'viewsCount': FieldValue.increment(1),
      });
      return;
    }

    try {
      final historyRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('recently_viewed')
          .doc(listingId);

      final doc = await historyRef.get();
      bool shouldIncrement = true;

      if (doc.exists) {
        final lastViewed = (doc.data()?['viewedAt'] as Timestamp?)?.toDate();
        if (lastViewed != null) {
          final difference = DateTime.now().difference(lastViewed);
          if (difference.inHours < 12) {
            shouldIncrement = false;
          }
        }
      }

      final batch = _firestore.batch();
      if (shouldIncrement) {
        batch.update(_firestore.collection('listings').doc(listingId), {
          'viewsCount': FieldValue.increment(1),
        });
      }
      batch.set(historyRef, {'viewedAt': FieldValue.serverTimestamp()});
      await batch.commit();
    } catch (e) {
      debugPrint('Error recording view: $e');
    }
  }

  @override
  Future<void> recordShare(String listingId) async {
    if (listingId.isEmpty) return;
    await _firestore.collection('listings').doc(listingId).update({
      'sharesCount': FieldValue.increment(1),
    });
  }

  @override
  Future<void> updateListingStatus(String listingId, ListingStatus status, String userId) async {
    if (listingId.isEmpty) return;
    
    final doc = await _firestore.collection('listings').doc(listingId).get();
    if (!doc.exists) return;
    
    final currentStatus = doc.data()?['status'];
    final sellerId = doc.data()?['sellerId'];
    
    if (sellerId != userId) {
       throw Exception('Unauthorized: You do not own this listing');
    }

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
  Future<void> updateListingPrice(String listingId, double newPrice, String userId) async {
    final doc = await _firestore.collection('listings').doc(listingId).get();
    if (!doc.exists) return;
    
    if (doc.data()?['sellerId'] != userId) {
      throw Exception('Unauthorized: You do not own this listing');
    }

    final oldPrice = (doc.data()?['price'] as num).toDouble();
    if (oldPrice == newPrice) return;
    
    final history = PriceHistory(price: oldPrice, timestamp: DateTime.now());
    
    await _firestore.collection('listings').doc(listingId).update({
      'price': newPrice,
      'priceHistory': FieldValue.arrayUnion([history.toJson()]),
    });
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
      'status': 'pending',
    });

    if (_notificationService != null) {
      await _notificationService!.notifyAdmins(
        title: 'Marketplace Report 📦',
        body: 'A listing has been reported for: $reason',
        route: '/admin/reports',
      );
    }
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
