import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:unihub_mobile/core/error/error_handler.dart';
import 'package:unihub_mobile/core/utils/app_logger.dart';
import '../../domain/models/listing.dart';
import '../../domain/models/offer.dart';
import '../../domain/models/price_history.dart';
import '../../domain/models/seller_stats.dart';
import '../../domain/models/saved_search.dart';
import '../../domain/repositories/marketplace_repository.dart';
import 'package:unihub_mobile/core/services/notification_sender.dart';
import '../../../../services/notification_service.dart';
import '../../../shared/domain/models/uni_notification.dart';
import '../../../shared/domain/repositories/user_activity_repository.dart';

class MarketplaceRepositoryImpl implements MarketplaceRepository {
  final FirebaseFirestore _firestore;
  final String? _browsingCampus;
  final NotificationSender? _notificationSender;
  final UserActivityRepository? _userActivityRepository;

  MarketplaceRepositoryImpl(this._firestore, this._browsingCampus, [this._notificationSender, this._userActivityRepository]);

  Query _buildListingsQuery({
    String? category,
    ListingSortType? sortBy,
    ListingStatus? status,
    double? minPrice,
    double? maxPrice,
    bool? isFeatured,
  }) {
    Query query = _firestore.collection('listings')
        .where('status', isEqualTo: (status ?? ListingStatus.active).name);

    if (category != null && category != 'All' && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }

    if (_browsingCampus != null && _browsingCampus.isNotEmpty) {
      query = query.where('sellerUniversity', isEqualTo: _browsingCampus);
    }

    if (isFeatured == true) {
      query = query.where('isFeatured', isEqualTo: true);
      // Fallback: If filtering by campus AND featured, we need a composite index.
      // If we suspect it's missing, we could remove the campus filter for featured items 
      // but let's keep it strict for now and ensure indexes are documented.
    }

    if (minPrice != null) {
      query = query.where('price', isGreaterThanOrEqualTo: minPrice);
    }
    if (maxPrice != null) {
      query = query.where('price', isLessThanOrEqualTo: maxPrice);
    }

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
        query = query.orderBy('createdAt', descending: true);
        break;
    }

    return query;
  }

  List<Listing> _applyClientFilters(
    List<Listing> items, {
    List<String>? conditions,
    Map<String, dynamic>? categoryAttributes,
    String? searchQuery,
  }) {
    var filtered = items;

    if (conditions != null && conditions.isNotEmpty) {
      filtered = filtered.where((l) => conditions.contains(l.condition.name)).toList();
    }

    if (categoryAttributes != null && categoryAttributes.isNotEmpty) {
      filtered = filtered.where((l) {
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
             if (!['brand', 'storage', 'color'].contains(key)) {
                return false;
             }
          }
        }
        return true;
      }).toList();
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final queryTerms = searchQuery.toLowerCase().split(' ').where((s) => s.isNotEmpty).toList();
      filtered = filtered.where((l) {
        final title = l.title.toLowerCase();
        final desc = l.description.toLowerCase();
        // Also check if any keyword matches exactly (improves relevance slightly)
        return queryTerms.any((term) => title.contains(term) || desc.contains(term));
      }).toList();
    }

    return filtered;
  }

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
    Listing? startAfter,
  }) async* {
    Query query = _buildListingsQuery(
      category: category,
      sortBy: sortBy,
      status: status,
      minPrice: minPrice,
      maxPrice: maxPrice,
      isFeatured: isFeatured,
    );

    if (startAfter != null) {
      final doc = await _firestore.collection('listings').doc(startAfter.id).get();
      if (doc.exists) {
        query = query.startAfterDocument(doc);
      }
    }

    final fetchLimit = limit ?? 20;
    
    yield* query.limit(fetchLimit).snapshots().map((snapshot) {
      var items = snapshot.docs
          .map((doc) => Listing.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      return _applyClientFilters(
        items,
        conditions: conditions,
        categoryAttributes: categoryAttributes,
        searchQuery: searchQuery,
      );
    });
  }

  @override
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
  }) async {
    Query query = _buildListingsQuery(
      category: category,
      sortBy: sortBy,
      status: status,
      minPrice: minPrice,
      maxPrice: maxPrice,
      isFeatured: isFeatured,
    );

    if (startAfter != null) {
      final doc = await _firestore.collection('listings').doc(startAfter.id).get();
      if (doc.exists) {
        query = query.startAfterDocument(doc);
      }
    }

    final fetchLimit = searchQuery != null && searchQuery.isNotEmpty ? limit * 3 : limit;

    final snapshot = await query.limit(fetchLimit).get(const GetOptions(source: Source.serverAndCache));
    
    var items = snapshot.docs
        .map((doc) => Listing.fromJson(doc.data() as Map<String, dynamic>))
        .toList();

    items = _applyClientFilters(
      items,
      conditions: conditions,
      categoryAttributes: categoryAttributes,
      searchQuery: searchQuery,
    );

    return items.take(limit).toList();
  }

  @override
  Stream<List<Listing>> watchRecentlyViewed(String userId) {
    if (userId.isEmpty || _userActivityRepository == null) return Stream.value([]);
    
    return _userActivityRepository.watchActivityIds(
      userId: userId, 
      activityType: ActivityType.recentlyViewed, 
      contentType: ContentType.marketplace,
      limit: 100, // Scaled for RC-3
    ).asyncMap((ids) async {
      if (ids.isEmpty) return [];
      
      final List<Listing> allListings = [];
      const int chunkSize = 30;
      
      for (var i = 0; i < ids.length; i += chunkSize) {
        final end = (i + chunkSize < ids.length) ? i + chunkSize : ids.length;
        final chunk = ids.sublist(i, end);

        final listingsSnapshot = await _firestore
            .collection('listings')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        allListings.addAll(listingsSnapshot.docs
            .map((doc) => Listing.fromJson(doc.data() as Map<String, dynamic>))
            .where((l) => l.status == ListingStatus.active));
      }
          
      allListings.sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));
      return allListings;
    });
  }

  @override
  Future<void> clearRecentlyViewed(String userId) async {
    if (userId.isEmpty || _userActivityRepository == null) return;
    await _userActivityRepository.clearActivity(
      userId: userId, 
      activityType: ActivityType.recentlyViewed, 
      contentType: ContentType.marketplace,
    );
  }

  double _calculateListingScore(Listing l) {
    double score = 0;

    // 1. Premium Weights (Monetization)
    if (l.isSponsored) score += 150.0;
    if (l.isFeatured) score += 100.0;
    
    // Boost Handling (2 points per hour remaining in 24h window)
    if (l.lastBoostedAt != null) {
      final hoursSinceBoost = DateTime.now().difference(l.lastBoostedAt!).inHours;
      if (hoursSinceBoost < 24) {
        score += (24 - hoursSinceBoost) * 2.0;
      }
    }

    // 2. Engagement Weights (Social Proof)
    score += (l.viewsCount * 1.0);
    score += (l.savesCount * 5.0);
    
    // Stability bonus for trust
    if (l.sellerTrustScore >= 90.0) {
      score += 10.0;
    }

    // 3. Freshness Decay
    final ageHours = DateTime.now().difference(l.createdAt).inHours;
    if (ageHours < 48) {
      score += 40.0; // Early bird bonus
    }
    
    // Penalty: -2 points per day
    final ageDays = ageHours / 24;
    score -= (ageDays * 2.0);

    return score;
  }

  @override
  Stream<List<Listing>> watchTrendingListings({int limit = 10}) {
    Query query = _firestore.collection('listings')
        .where('status', isEqualTo: ListingStatus.active.name);

    // CAMPUS SYNC: Ensure we filter by campus at the DB level for trending items
    if (_browsingCampus != null && _browsingCampus.isNotEmpty) {
      query = query.where('sellerUniversity', isEqualTo: _browsingCampus);
    }

    return query
        .orderBy('viewsCount', descending: true) // Primary filter
        .limit(limit * 5) // Get a healthy candidate set for weighted sorting
        .snapshots()
        .map((snapshot) {
          var items = snapshot.docs
              .map((doc) => Listing.fromJson(doc.data() as Map<String, dynamic>))
              .toList();

          // Sort by the Weighted Multi-Factor Algorithm (Premium + Engagement)
          items.sort((a, b) => _calculateListingScore(b).compareTo(_calculateListingScore(a)));
          
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

      // Get last 5 recently viewed categories for session affinity
      final recentSnapshot = await _firestore.collection('users').doc(userId)
          .collection('recently_viewed').orderBy('viewedAt', descending: true).limit(5).get();
      
      final recentCategories = <String>{};
      if (recentSnapshot.docs.isNotEmpty) {
        final recentIds = recentSnapshot.docs.map((d) => d.id).toList();
        final listingsSnapshot = await _firestore.collection('listings')
            .where(FieldPath.documentId, whereIn: chunkIds(recentIds)).get();
        
        for (var doc in listingsSnapshot.docs) {
          final cat = doc.data()['category'] as String?;
          if (cat != null) recentCategories.add(cat);
        }
      }

      Query query = _firestore.collection('listings')
          .where('status', isEqualTo: ListingStatus.active.name)
          .orderBy('createdAt', descending: true);

      if (_browsingCampus != null && _browsingCampus.isNotEmpty) {
        query = query.where('sellerUniversity', isEqualTo: _browsingCampus);
      }

      final snapshot = await query.limit(limit * 5).get();

      var listings = snapshot.docs
          .map((doc) => Listing.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      listings.sort((a, b) {
        // Base score from weighted algorithm
        double aScore = _calculateListingScore(a);
        double bScore = _calculateListingScore(b);

        // Personalized Affinity Boosts
        if (interests.contains(a.category)) aScore += 50; // High match for user interests
        if (interests.contains(b.category)) bScore += 50;
        
        if (recentCategories.contains(a.category)) aScore += 30; // session match
        if (recentCategories.contains(b.category)) bScore += 30;

        if (university != null && a.sellerUniversity == university) aScore += 10;
        if (university != null && b.sellerUniversity == university) bScore += 10;

        return bScore.compareTo(aScore);
      });
      
      return listings.take(limit).toList();
    });
  }

  List<String> chunkIds(List<String> ids) => ids.take(30).toList(); // Simple helper for whereIn limit

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
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('collections')
          .doc(name)
          .set({'createdAt': FieldValue.serverTimestamp()});
    } catch (e) {
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  @override
  Future<void> deleteCollection(String userId, String name) async {
    if (userId.isEmpty || name.isEmpty) return;
    
    try {
      final batch = _firestore.batch();
      final collectionRef = _firestore.collection('users').doc(userId).collection('collections').doc(name);
      
      final items = await collectionRef.collection('listings').get();
      for (var doc in items.docs) {
        batch.delete(doc.reference);
      }
      
      batch.delete(collectionRef);
      await batch.commit();
    } catch (e) {
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  @override
  Future<void> addToCollection(String userId, String collectionName, String listingId) async {
    if (userId.isEmpty || collectionName.isEmpty || listingId.isEmpty) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('collections')
          .doc(collectionName)
          .collection('listings')
          .doc(listingId)
          .set({'addedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  @override
  Future<void> removeFromCollection(String userId, String collectionName, String listingId) async {
    if (userId.isEmpty || collectionName.isEmpty || listingId.isEmpty) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('collections')
          .doc(collectionName)
          .collection('listings')
          .doc(listingId)
          .delete();
    } catch (e) {
      throw Exception(AppErrorHandler.mapError(e));
    }
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
          
          final List<Listing> allListings = [];
          const int chunkSize = 30;
          
          for (var i = 0; i < ids.length; i += chunkSize) {
            final end = (i + chunkSize < ids.length) ? i + chunkSize : ids.length;
            final chunk = ids.sublist(i, end);

            final listingsSnapshot = await _firestore
                .collection('listings')
                .where(FieldPath.documentId, whereIn: chunk)
                .get();

            allListings.addAll(listingsSnapshot.docs
                .map((doc) => Listing.fromJson(doc.data() as Map<String, dynamic>)));
          }
              
          allListings.sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));
          return allListings;
        });
  }

  @override
  Future<void> makeOffer(Offer offer) async {
    try {
      await _firestore.collection('offers').doc(offer.id).set(offer.toJson());
      
      if (_notificationSender != null) {
        final listing = await getListingById(offer.listingId);
        await _notificationSender.sendNotification(
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
      AppLogger.info('Offer ${offer.id} created for listing ${offer.listingId}', 'MARKETPLACE');
    } catch (e, st) {
      AppLogger.error('Failed to make offer', e, st, 'MARKETPLACE');
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  @override
  Future<void> respondToOffer(String offerId, OfferStatus status, {double? counterAmount, String? sellerMessage}) async {
    try {
      final offerDoc = await _firestore.collection('offers').doc(offerId).get();
      if (!offerDoc.exists) return;
      
      final offer = Offer.fromJson(offerDoc.data() as Map<String, dynamic>);
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

      if (_notificationSender != null) {
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
          await _notificationSender.sendNotification(
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
    } catch (e) {
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  @override
  Stream<List<Offer>> watchListingOffers(String listingId) {
    return _firestore
        .collection('offers')
        .where('listingId', isEqualTo: listingId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Offer.fromJson(d.data() as Map<String, dynamic>)).toList());
  }

  @override
  Stream<List<Offer>> watchUserOffers(String userId) {
    return _firestore
        .collection('offers')
        .where('buyerId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Offer.fromJson(d.data() as Map<String, dynamic>)).toList());
  }

  @override
  Stream<List<Offer>> watchReceivedOffers(String sellerId) {
    return _firestore
        .collection('offers')
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Offer.fromJson(d.data() as Map<String, dynamic>)).toList());
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
      
      if (statusStr == ListingStatus.sold.name) {
        soldCount++;
      } else if (statusStr == ListingStatus.active.name) {
        activeCount++;
      }
      
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
        .map((s) => s.docs.map((d) => Listing.fromJson(d.data() as Map<String, dynamic>)).toList());
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
    if (userId.isEmpty || query.isEmpty || _userActivityRepository == null) return;
    
    await _userActivityRepository.recordActivity(
      userId: userId, 
      contentId: query.toLowerCase().trim(), 
      activityType: ActivityType.searched, 
      contentType: ContentType.marketplace,
    );
  }

  @override
  Stream<List<String>> watchRecentSearches(String userId) {
    if (userId.isEmpty || _userActivityRepository == null) return Stream.value([]);
    
    return _userActivityRepository.watchActivityIds(
      userId: userId, 
      activityType: ActivityType.searched, 
      contentType: ContentType.marketplace,
    );
  }

  @override
  Future<void> clearRecentSearches(String userId) async {
    if (userId.isEmpty || _userActivityRepository == null) return;
    await _userActivityRepository.clearActivity(
      userId: userId, 
      activityType: ActivityType.searched, 
      contentType: ContentType.marketplace,
    );
  }

  @override
  Future<List<String>> getPopularSearches() async {
    return ['iPhone', 'Laptop', 'Nike', 'Table', 'Textbook', 'Bicycle'];
  }

  @override
  Future<void> saveSearch(SavedSearch search) async {
    try {
      await _firestore
          .collection('users')
          .doc(search.userId)
          .collection('saved_searches')
          .doc(search.id)
          .set(search.toJson());
    } catch (e) {
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  @override
  Future<void> deleteSavedSearch(String userId, String searchId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('saved_searches')
          .doc(searchId)
          .delete();
    } catch (e) {
      throw Exception(AppErrorHandler.mapError(e));
    }
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
            .map((doc) => SavedSearch.fromJson(doc.data() as Map<String, dynamic>))
            .toList());
  }

  @override
  Future<void> updateSavedSearchNotification(String userId, String searchId, bool enabled) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('saved_searches')
          .doc(searchId)
          .update({'notificationsEnabled': enabled});
    } catch (e) {
      throw Exception(AppErrorHandler.mapError(e));
    }
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
    if (userId.isEmpty || _userActivityRepository == null) return Stream.value([]);
    
    return _userActivityRepository.watchActivityIds(
      userId: userId, 
      activityType: ActivityType.saved, 
      contentType: ContentType.marketplace,
      limit: 100, // Scaled for RC-3
    ).asyncMap((ids) async {
      if (ids.isEmpty) return [];
      
      // Scalable fetch: Chunk ids to overcome Firestore whereIn limit (30)
      final List<Listing> allListings = [];
      const int chunkSize = 30;
      
      for (var i = 0; i < ids.length; i += chunkSize) {
        final end = (i + chunkSize < ids.length) ? i + chunkSize : ids.length;
        final chunk = ids.sublist(i, end);
        
        final listingsSnapshot = await _firestore
            .collection('listings')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        allListings.addAll(listingsSnapshot.docs
            .map((doc) => Listing.fromJson(doc.data() as Map<String, dynamic>)));
      }
              
      // Maintain original sort order from savedAt
      allListings.sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));
      return allListings;
    });
  }

  @override
  Future<void> createListing(Listing listing) async {
    try {
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
    } catch (e) {
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  @override
  Future<void> updateListing(Listing listing) async {
    if (listing.id.isEmpty) return;
    
    try {
      final listingRef = _firestore.collection('listings').doc(listing.id);
      final doc = await listingRef.get();
      if (!doc.exists) throw Exception('Listing not found');
      
      final currentSellerId = doc.data()?['sellerId'];
      if (currentSellerId != listing.sellerId) {
        throw Exception('Unauthorized: You do not own this listing');
      }

      final data = listing.toJson();
      // SECURITY: Never allow changing sellerId via update
      data['sellerId'] = currentSellerId;
      
      await listingRef.update(data);
      AppLogger.info('Listing ${listing.id} updated', 'MARKETPLACE');
    } catch (e) {
      AppLogger.error('Failed to update listing ${listing.id}', e, null, 'MARKETPLACE');
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  @override
  Future<void> deleteListing(String id, String userId) async {
    if (id.isEmpty || userId.isEmpty) return;
    
    try {
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
      AppLogger.info('Listing $id deleted by user $userId', 'MARKETPLACE');
    } catch (e) {
      AppLogger.error('Failed to delete listing $id', e, null, 'MARKETPLACE');
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  @override
  Future<void> toggleSaveListing(String userId, String listingId) async {
    if (userId.isEmpty || listingId.isEmpty || _userActivityRepository == null) return;
    
    try {
      final doc = await _firestore.collection('users').doc(userId).collection('saved_listings').doc(listingId).get();
      final isSaved = doc.exists;
      
      if (isSaved) {
        await _userActivityRepository.removeActivity(
          userId: userId, 
          contentId: listingId, 
          activityType: ActivityType.saved, 
          contentType: ContentType.marketplace,
        );
        await recordSave(listingId, false);
      } else {
        await _userActivityRepository.recordActivity(
          userId: userId, 
          contentId: listingId, 
          activityType: ActivityType.saved, 
          contentType: ContentType.marketplace,
        );
        await recordSave(listingId, true);
        
        final listing = await getListingById(listingId);
        if (listing != null && listing.sellerId.isNotEmpty && _notificationSender != null) {
          await _notificationSender.sendNotification(
            recipientId: listing.sellerId,
            title: 'Item Saved! 💖',
            body: 'Someone saved your listing: ${listing.title}',
            type: NotificationType.marketplace,
            targetId: listingId,
            targetType: 'marketplace',
          );
        }
      }
    } catch (e) {
      AppLogger.error('Failed to toggle save for listing $listingId', e, null, 'MARKETPLACE');
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  @override
  Future<void> recordSave(String listingId, bool isSaved) async {
    if (listingId.isEmpty) return;
    try {
      await _firestore.collection('listings').doc(listingId).update({
        'savesCount': FieldValue.increment(isSaved ? 1 : -1),
      });
    } catch (e) {
      AppLogger.error('Failed to record save for listing $listingId', e, null, 'MARKETPLACE');
    }
  }

  @override
  Future<void> recordChatStarted(String listingId) async {
    if (listingId.isEmpty) return;
    try {
      await _firestore.collection('listings').doc(listingId).update({
        'chatsStartedCount': FieldValue.increment(1),
      });
    } catch (e) {
      AppLogger.error('Failed to record chat started for listing $listingId', e, null, 'MARKETPLACE');
    }
  }

  @override
  Future<void> boostListing(String listingId) async {
    if (listingId.isEmpty) return;
    
    try {
      // Growth Phase: Allow verified users to boost for free
      // In the future, this will be handled by the MonetizationRepository/Service
      final doc = await _firestore.collection('listings').doc(listingId).get();
      if (!doc.exists) return;
      
      final sellerId = doc.data()?['sellerId'];
      if (sellerId == null) return;

      // Check if user is verified (Optional: can be enforced here too)
      
      await _firestore.collection('listings').doc(listingId).update({
        'lastBoostedAt': FieldValue.serverTimestamp(),
        'boostCount': FieldValue.increment(1),
      });
      
      AppLogger.info('Listing $listingId boosted (Free Growth Phase)', 'MARKETPLACE');
    } catch (e) {
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  @override
  Future<void> featureListing(String listingId, String packageId, Duration duration) async {
    if (listingId.isEmpty) return;
    try {
      final now = DateTime.now();
      
      // Growth Phase: Free for verified
      await _firestore.collection('listings').doc(listingId).update({
        'isFeatured': true,
        'featuredAt': FieldValue.serverTimestamp(),
        'featuredUntil': Timestamp.fromDate(now.add(duration)),
        'featuredPackage': packageId,
      });
      
      AppLogger.info('Listing $listingId featured for ${duration.inDays} days', 'MARKETPLACE');
    } catch (e) {
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  @override
  Future<void> setSponsored(String listingId, Duration duration) async {
    if (listingId.isEmpty) return;
    try {
      final now = DateTime.now();
      
      await _firestore.collection('listings').doc(listingId).update({
        'isSponsored': true,
        'sponsoredUntil': Timestamp.fromDate(now.add(duration)),
      });
      
      AppLogger.info('Listing $listingId set as sponsored for ${duration.inDays} days', 'MARKETPLACE');
    } catch (e) {
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  // In-memory throttle for the current app session to prevent "running rising" views bug
  final Set<String> _sessionViewedIds = {};

  @override
  Future<void> recordView(String listingId, {String? userId}) async {
    if (listingId.isEmpty) return;
    
    // 1. Session-level de-duplication (fast check)
    if (_sessionViewedIds.contains(listingId)) return;
    _sessionViewedIds.add(listingId);

    // 2. Anonymous View Handling
    if (userId == null || userId.isEmpty || _userActivityRepository == null) {
      // Check Firestore document for throttle even for anonymous users if we want 
      // but session-level is usually enough for a single app instance.
      // We limit update frequency to avoid loop costs.
      await _firestore.collection('listings').doc(listingId).update({
        'viewsCount': FieldValue.increment(1),
      }).timeout(const Duration(seconds: 5)).catchError((_) => null);
      return;
    }

    try {
      // 3. Authenticated View Handling with 12h throttle
      final collection = _firestore.collection('users').doc(userId).collection('recently_viewed');
      final doc = await collection.doc(listingId).get().timeout(const Duration(seconds: 5));
      bool shouldIncrement = true;

      if (doc.exists) {
        final lastViewed = (doc.data()?['timestamp'] as Timestamp?)?.toDate();
        if (lastViewed != null) {
          final difference = DateTime.now().difference(lastViewed);
          if (difference.inHours < 12) {
            shouldIncrement = false;
          }
        }
      }

      // Security: Fetch listing to check if viewer is seller
      final listingDoc = await _firestore.collection('listings').doc(listingId).get();
      if (listingDoc.exists && listingDoc.data()?['sellerId'] == userId) {
        shouldIncrement = false;
      }

      if (shouldIncrement) {
        await _firestore.collection('listings').doc(listingId).update({
          'viewsCount': FieldValue.increment(1),
        }).timeout(const Duration(seconds: 5)).catchError((e) {
          AppLogger.warning('Failed to increment viewsCount for $listingId: $e');
          return null;
        });
      }

      // Always update "recently viewed" time even if we don't increment total view count
      await _userActivityRepository.recordActivity(
        userId: userId, 
        contentId: listingId, 
        activityType: ActivityType.recentlyViewed, 
        contentType: ContentType.marketplace,
      ).timeout(const Duration(seconds: 5)).catchError((e) {
         AppLogger.warning('Failed to record activity for $listingId: $e');
         return null;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error recording view: $e');
      }
    }
  }

  @override
  Future<void> recordShare(String listingId) async {
    if (listingId.isEmpty) return;
    try {
      await _firestore.collection('listings').doc(listingId).update({
        'sharesCount': FieldValue.increment(1),
      });
    } catch (e) {
      AppLogger.error('Failed to record share for listing $listingId', e, null, 'MARKETPLACE');
    }
  }

  @override
  Future<void> updateListingStatus(String listingId, ListingStatus status, String userId) async {
    if (listingId.isEmpty) return;
    
    try {
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
    } catch (e) {
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  @override
  Future<void> updateListingPrice(String listingId, double newPrice, String userId) async {
    try {
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
    } catch (e) {
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  @override
  Future<void> reportListing({
    required String listingId,
    required String reporterId,
    required String reason,
  }) async {
    if (listingId.isEmpty) return;
    try {
      await _firestore.collection('reports').add({
        'type': 'listing',
        'targetId': listingId,
        'reporterId': reporterId,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      if (_notificationSender != null) {
        await _notificationSender.notifyAdmins(
          title: 'Marketplace Report 📦',
          body: 'A listing has been reported for: $reason',
          route: '/admin/reports',
        );
      }
    } catch (e) {
      throw Exception(AppErrorHandler.mapError(e));
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
    try {
      final buyerDoc = await _firestore.collection('users').doc(buyerId).get();
      final buyerName = buyerDoc.data()?['fullName'] ?? 'A Student';

      await _firestore.runTransaction((transaction) async {
        final reviewRef = _firestore.collection('users').doc(sellerId).collection('reviews').doc(listingId);
        final userRef = _firestore.collection('users').doc(sellerId);

        final userDoc = await transaction.get(userRef);
        final reviewDoc = await transaction.get(reviewRef);

        final reviewData = {
          'id': listingId,
          'reviewerId': buyerId,
          'reviewerName': buyerName,
          'targetUserId': sellerId,
          'listingId': listingId,
          'rating': rating,
          'comment': comment,
          'createdAt': FieldValue.serverTimestamp(),
        };

        transaction.set(reviewRef, reviewData);
        
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          final currentAvg = (data['averageRating'] ?? 0.0).toDouble();
          final currentCount = (data['ratingsCount'] ?? 0).toInt();
          
          double newAvg;
          int newCount;

          if (reviewDoc.exists) {
            final reviewDataMap = reviewDoc.data() as Map<String, dynamic>;
            final oldRating = (reviewDataMap['rating'] ?? 0.0).toDouble();
            newCount = currentCount;
            newAvg = currentCount > 0 
                ? ((currentAvg * currentCount) - oldRating + rating) / newCount
                : rating;
          } else {
            newCount = currentCount + 1;
            newAvg = ((currentAvg * currentCount) + rating) / newCount;
          }
          
          transaction.update(userRef, {
            'averageRating': newAvg,
            'ratingsCount': newCount,
            'trustScore': FieldValue.increment(rating >= 4 ? 2.0 : -1.0),
          });
        }
      });

      if (_notificationSender != null) {
        await _notificationSender.sendNotification(
          recipientId: sellerId,
          title: 'New Review! ⭐',
          body: '$buyerName left you a $rating-star review.',
          type: NotificationType.review,
          targetId: listingId,
          targetType: 'marketplace',
        );
      }
      AppLogger.info('Review submitted for seller $sellerId on listing $listingId', 'MARKETPLACE');
    } catch (e, st) {
      AppLogger.error('Failed to submit review', e, st, 'MARKETPLACE');
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  @override
  Future<void> flagListing({
    required String listingId,
    required String reason,
    String? adminNotes,
  }) async {
    try {
      await _firestore.collection('listings').doc(listingId).update({
        'flagged': true,
        'flagReason': reason,
        'flagAdminNotes': adminNotes,
        'flaggedAt': FieldValue.serverTimestamp(),
      });

      final listingDoc = await _firestore.collection('listings').doc(listingId).get();
      if (listingDoc.exists && _notificationSender != null) {
        await _notificationSender.notifyAdmins(
          title: 'Marketplace Listing Flagged 🚩',
          body: 'Reason: $reason',
          route: '/admin/flags/marketplace',
        );
      }
    } catch (e) {
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  @override
  Future<void> approveListing(String listingId) async {
    try {
      final listingDoc = await _firestore.collection('listings').doc(listingId).get();
      if (!listingDoc.exists) return;

      await _firestore.collection('listings').doc(listingId).update({
        'status': ListingStatus.active.name,
        'flagged': false,
        'approvedAt': FieldValue.serverTimestamp(),
      });

      final sellerId = listingDoc.data()?['sellerId'];
      if (sellerId != null && _notificationSender != null) {
        await _notificationSender.sendNotification(
          recipientId: sellerId,
          title: 'Listing Approved! ✅',
          body: 'Your listing "${listingDoc.data()?['title']}" has been approved and is now live.',
          type: NotificationType.marketplace,
          targetId: listingId,
          targetType: 'marketplace',
        );
      }
    } catch (e) {
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  @override
  Future<void> suspendListing({
    required String listingId,
    required String reason,
    required String adminId,
  }) async {
    try {
      final listingDoc = await _firestore.collection('listings').doc(listingId).get();
      if (!listingDoc.exists) return;

      await _firestore.collection('listings').doc(listingId).update({
        'status': ListingStatus.archived.name,
        'suspensionReason': reason,
        'suspendedBy': adminId,
        'suspendedAt': FieldValue.serverTimestamp(),
      });

      final sellerId = listingDoc.data()?['sellerId'];
      if (sellerId != null && _notificationSender != null) {
        await _notificationSender.sendNotification(
          recipientId: sellerId,
          title: 'Listing Suspended',
          body: 'Your listing "${listingDoc.data()?['title']}" has been suspended. Reason: $reason',
          type: NotificationType.marketplace,
          targetId: listingId,
          targetType: 'marketplace',
        );
      }
    } catch (e) {
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  @override
  Future<void> removeListing({
    required String listingId,
    required String reason,
    required String adminId,
  }) async {
    try {
      final listingDoc = await _firestore.collection('listings').doc(listingId).get();
      if (!listingDoc.exists) return;

      final sellerId = listingDoc.data()?['sellerId'];
      final batch = _firestore.batch();

      batch.delete(_firestore.collection('listings').doc(listingId));
      
      if (sellerId != null && (sellerId as String).isNotEmpty) {
        batch.update(_firestore.collection('users').doc(sellerId), {
          'activeListingsCount': FieldValue.increment(-1),
        });

        if (_notificationSender != null) {
          await _notificationSender.sendNotification(
            recipientId: sellerId,
            title: 'Listing Removed',
            body: 'Your listing "${listingDoc.data()?['title']}" has been removed. Reason: $reason',
            type: NotificationType.marketplace,
            targetId: listingId,
            targetType: 'marketplace',
          );
        }
      }

      await batch.commit();
    } catch (e) {
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  @override
  Stream<List<Listing>> watchFlaggedListings(String campusId) {
    return _firestore
        .collection('listings')
        .where('flagged', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Listing.fromJson(doc.data() as Map<String, dynamic>))
            .toList());
  }
}
