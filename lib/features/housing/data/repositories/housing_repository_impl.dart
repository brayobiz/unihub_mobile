import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/housing_saved_search.dart';
import '../../domain/models/housing_listing.dart';
import '../../domain/models/housing_review.dart';
import '../../domain/models/roommate_profile.dart';
import '../../domain/models/vacancy_request.dart';
import '../../domain/models/viewing_request.dart';
import '../../domain/repositories/housing_repository.dart';
import 'package:unihub_mobile/core/services/notification_sender.dart';
import 'package:unihub_mobile/core/utils/app_logger.dart';
import '../../../../services/notification_service.dart';
import '../../../shared/domain/models/uni_notification.dart';
import '../../../shared/domain/repositories/user_activity_repository.dart';

class HousingRepositoryImpl implements HousingRepository {
  final FirebaseFirestore _firestore;
  final String? _browsingCampus;
  final NotificationSender? _notificationSender;
  final UserActivityRepository? _userActivityRepository;

  HousingRepositoryImpl(this._firestore, this._browsingCampus, [this._notificationSender, this._userActivityRepository]);

  @override
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
  }) {
    final query = _buildListingsQuery(
      universityId: universityId,
      type: type,
      minRent: minRent,
      maxRent: maxRent,
      genderRestriction: genderRestriction,
      isFurnished: isFurnished,
      onlyAvailable: onlyAvailable,
      sortBy: sortBy,
    );

    return _watchHousingWithListingCursor(query, limit, location, startAfter);
  }

  @override
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
  }) async {
    var query = _buildListingsQuery(
      universityId: universityId,
      type: type,
      minRent: minRent,
      maxRent: maxRent,
      genderRestriction: genderRestriction,
      isFurnished: isFurnished,
      onlyAvailable: onlyAvailable,
      sortBy: sortBy,
    );

    if (startAfter != null) {
      final doc = await _firestore.collection('housing_listings').doc(startAfter.id).get();
      if (doc.exists) {
        query = query.startAfterDocument(doc);
      }
    }

    final snapshot = await query.limit(limit).get();
    var listings = snapshot.docs.map((doc) => HousingListing.fromFirestore(doc)).toList();
    
    // Substring location filter remains client-side as Firestore doesn't support it
    if (location != null && location.isNotEmpty) {
      listings = listings.where((l) => 
        l.location.toLowerCase().contains(location.toLowerCase()) ||
        l.title.toLowerCase().contains(location.toLowerCase())
      ).toList();
    }

    return listings;
  }

  Query _buildListingsQuery({
    String? universityId,
    HousingType? type,
    double? minRent,
    double? maxRent,
    GenderRestriction? genderRestriction,
    bool? isFurnished,
    bool onlyAvailable = true,
    HousingSortBy sortBy = HousingSortBy.newest,
  }) {
    Query query = _firestore.collection('housing_listings');

    if (onlyAvailable) {
      query = query.where('status', isEqualTo: HousingStatus.available.name);
    }

    final effectiveUniversity = universityId ?? _browsingCampus;
    if (effectiveUniversity != null && effectiveUniversity.isNotEmpty) {
      query = query.where('university', isEqualTo: effectiveUniversity);
    }

    if (type != null) {
      query = query.where('type', isEqualTo: type.name);
    }
    
    if (genderRestriction != null) {
      query = query.where('genderRestriction', isEqualTo: genderRestriction.name);
    }
    
    if (isFurnished != null) {
      query = query.where('isFurnished', isEqualTo: isFurnished);
    }

    // SERVER-SIDE RANGE FILTERING
    // Note: This requires composite indexes in Firestore
    if (minRent != null) {
      query = query.where('rent', isGreaterThanOrEqualTo: minRent);
    }
    if (maxRent != null) {
      query = query.where('rent', isLessThanOrEqualTo: maxRent);
    }

    // Server-side ordering
    switch (sortBy) {
      case HousingSortBy.newest:
        query = query.orderBy('lastVerifiedAt', descending: true);
        break;
      case HousingSortBy.priceLowToHigh:
        query = query.orderBy('rent', descending: false);
        break;
      case HousingSortBy.priceHighToLow:
        query = query.orderBy('rent', descending: true);
        break;
      case HousingSortBy.mostViewed:
        query = query.orderBy('views', descending: true);
        break;
      case HousingSortBy.distance:
        // Distance is usually calculated client-side unless using GeoFirestore
        query = query.orderBy('lastVerifiedAt', descending: true);
        break;
    }

    return query;
  }

  Stream<List<HousingListing>> _watchHousingWithListingCursor(
    Query query,
    int limit,
    String? location,
    HousingListing? startAfter,
  ) async* {
    if (startAfter != null) {
      final doc = await _firestore.collection('housing_listings').doc(startAfter.id).get();
      if (doc.exists) {
        query = query.startAfterDocument(doc);
      }
    }

    yield* query.limit(limit).snapshots().map((snapshot) {
      var listings = snapshot.docs.map((doc) => HousingListing.fromFirestore(doc)).toList();
      
      // Client-side filtering for location (substring match)
      if (location != null && location.isNotEmpty) {
        listings = listings.where((l) => 
          l.location.toLowerCase().contains(location.toLowerCase()) ||
          l.title.toLowerCase().contains(location.toLowerCase())
        ).toList();
      }
      
      return listings;
    });
  }

  @override
  Stream<List<HousingListing>> watchPlugListings(String plugId) {
    if (plugId.isEmpty) return Stream.value([]);
    return _firestore.collection('housing_listings')
        .where('plugId', isEqualTo: plugId)
        .snapshots()
        .map((snapshot) {
          var items = snapshot.docs.map((doc) => HousingListing.fromFirestore(doc)).toList();
          items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return items;
        });
  }

  @override
  Stream<List<RoommateProfile>> watchRoommates({int limit = 30}) {
    // In-memory campus filtering to avoid composite index requirement for createdAt
    final fetchLimit = (_browsingCampus != null && _browsingCampus!.isNotEmpty) 
        ? limit * 3 
        : limit;

    Query query = _firestore.collection('roommates')
        .orderBy('createdAt', descending: true)
        .limit(fetchLimit);

    return query.snapshots().map((snapshot) {
      var profiles = snapshot.docs.map((doc) => RoommateProfile.fromFirestore(doc)).toList();
      if (_browsingCampus != null && _browsingCampus!.isNotEmpty) {
        profiles = profiles.where((p) => p.campus == _browsingCampus).toList();
      }
      return profiles.take(limit).toList();
    });
  }

  @override
  Stream<List<HousingReview>> watchPlugReviews(String plugId) {
    if (plugId.isEmpty) return Stream.value([]);
    return _firestore.collection('housing_reviews')
        .where('plugId', isEqualTo: plugId)
        .snapshots()
        .map((snapshot) {
          var items = snapshot.docs.map((doc) => HousingReview.fromFirestore(doc)).toList();
          items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return items;
        });
  }

  @override
  Stream<List<HousingReview>> watchListingReviews(String listingId) {
    if (listingId.isEmpty) return Stream.value([]);
    return _firestore.collection('housing_reviews')
        .where('listingId', isEqualTo: listingId)
        .snapshots()
        .map((snapshot) {
          var items = snapshot.docs.map((doc) => HousingReview.fromFirestore(doc)).toList();
          items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return items;
        });
  }

  @override
  Future<HousingListing?> getListingById(String id) async {
    if (id.isEmpty) return null;
    final doc = await _firestore.collection('housing_listings').doc(id).get();
    if (!doc.exists) return null;
    return HousingListing.fromFirestore(doc);
  }

  @override
  Stream<HousingListing?> watchListingById(String id) {
    if (id.isEmpty) return Stream.value(null);
    return _firestore.collection('housing_listings').doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return HousingListing.fromFirestore(doc);
    });
  }

  @override
  Future<void> createListing(HousingListing listing) async {
    final batch = _firestore.batch();
    
    // Aligned with Marketplace: Use the ID provided in the listing object
    final listingRef = _firestore.collection('housing_listings').doc(listing.id);
    batch.set(listingRef, listing.toFirestore());
    
    // Update user stats
    final userRef = _firestore.collection('users').doc(listing.plugId);
    batch.update(userRef, {
      'housingListingsCount': FieldValue.increment(1),
    });

    await batch.commit();
    await _logHistory(listing.id, 'created', listing.toFirestore());
  }

  @override
  Future<void> updateListing(HousingListing listing) async {
    final oldDoc = await _firestore.collection('housing_listings').doc(listing.id).get();
    final oldRent = oldDoc.data()?['rent'] as num?;
    
    await _firestore.collection('housing_listings').doc(listing.id).update(listing.toFirestore());
    await _logHistory(listing.id, 'edited', listing.toFirestore());

    // Price Drop Notification
    if (oldRent != null && listing.rent < oldRent.toDouble() && _notificationSender != null) {
      final savedBySnapshot = await _firestore.collectionGroup('saved_housing')
          .where(FieldPath.documentId, isEqualTo: listing.id)
          .get();
      
      for (var doc in savedBySnapshot.docs) {
        final userId = doc.reference.parent.parent?.id;
        if (userId != null) {
          await _notificationSender!.sendNotification(
            recipientId: userId,
            title: 'Price Drop Alert! 📉',
            body: 'The price for "${listing.title}" has dropped to KES ${listing.rent.toInt()}!',
            type: NotificationType.housing,
            targetId: listing.id,
            targetType: 'housing',
            deepLink: '/housing-detail',
          );
        }
      }
    }
  }

  @override
  Future<void> deleteListing(String id) async {
    final doc = await _firestore.collection('housing_listings').doc(id).get();
    if (!doc.exists) return;
    
    final plugId = doc.data()?['plugId'];
    
    // SECURITY HARDENING: Ownership check if we have a current user context
    // Though usually enforced by Firestore Rules, adding it here for defense-in-depth
    // and to prevent unnecessary operations if we had the context available.
    
    final batch = _firestore.batch();
    batch.delete(_firestore.collection('housing_listings').doc(id));
    
    if (plugId != null) {
      batch.update(_firestore.collection('users').doc(plugId), {
        'housingListingsCount': FieldValue.increment(-1),
      });
    }
    
    try {
      await batch.commit();
      AppLogger.info('Housing: Listing $id deleted successfully', 'HOUSING');
    } catch (e) {
      AppLogger.error('Housing: Failed to delete listing $id', e, null, 'HOUSING');
      rethrow;
    }
  }

  @override
  Future<void> updateListingStatus(String id, HousingStatus status) async {
    final doc = await _firestore.collection('housing_listings').doc(id).get();
    if (!doc.exists) return;

    final currentStatus = doc.data()?['status'];
    final plugId = doc.data()?['plugId'];
    final batch = _firestore.batch();

    batch.update(_firestore.collection('housing_listings').doc(id), {
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // If marked as taken, increment completed deals and trust score
    if (status == HousingStatus.taken && currentStatus != HousingStatus.taken.name) {
      if (plugId != null) {
        batch.update(_firestore.collection('users').doc(plugId), {
          'completedSalesCount': FieldValue.increment(1),
          'trustScore': FieldValue.increment(5.0), // Consistent with Marketplace
        });
      }
    } else if (status == HousingStatus.available && currentStatus == HousingStatus.taken.name) {
      // Reverting from taken back to available
      if (plugId != null) {
        batch.update(_firestore.collection('users').doc(plugId), {
          'completedSalesCount': FieldValue.increment(-1),
          'trustScore': FieldValue.increment(-5.0),
        });
      }
    }

    await batch.commit();
    await _logHistory(id, 'status_change', {'new_status': status.name});
  }

  @override
  Future<void> moderateListing({
    required String listingId,
    required HousingStatus status,
    String? moderatorNotes,
  }) async {
    await _firestore.collection('housing_listings').doc(listingId).update({
      'status': status.name,
      'moderatorNotes': moderatorNotes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    await _logHistory(listingId, 'moderated', {
      'new_status': status.name,
      'notes': moderatorNotes,
    });

    // Notify plug
    final doc = await _firestore.collection('housing_listings').doc(listingId).get();
    final plugId = doc.data()?['plugId'];
    if (plugId != null && _notificationSender != null) {
      await _notificationSender!.sendNotification(
        recipientId: plugId,
        title: 'Moderation Update',
        body: 'Your listing status has been updated to ${status.name} by a moderator.',
        type: NotificationType.system,
        targetId: listingId,
        targetType: 'housing',
        deepLink: '/plug-dashboard',
      );
    }
  }

  @override
  Future<bool> checkPossibleDuplicate({
    required String location,
    required double rent,
    required HousingType type,
  }) async {
    final snapshot = await _firestore.collection('housing_listings')
        .where('status', isEqualTo: HousingStatus.available.name)
        .where('type', isEqualTo: type.name)
        .where('rent', isEqualTo: rent)
        .get();
    
    final duplicates = snapshot.docs.where((doc) {
      final existingLoc = (doc.data()['location'] ?? '').toString().toLowerCase();
      final newLoc = location.toLowerCase();
      return existingLoc.contains(newLoc) || newLoc.contains(existingLoc);
    }).toList();

    return duplicates.isNotEmpty;
  }

  Future<void> _logHistory(String listingId, String action, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('housing_listings').doc(listingId).collection('history').add({
        'action': action,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Housing History Log Error: $e');
    }
  }

  @override
  Future<void> incrementViews(String id) async {
    if (id.isEmpty) return;
    await _firestore.collection('housing_listings').doc(id).update({
      'views': FieldValue.increment(1),
    }).timeout(const Duration(seconds: 5)).catchError((_) => null);
  }

  @override
  Future<void> refreshListingStatus(String id) async {
    if (id.isEmpty) return;
    await _firestore.collection('housing_listings').doc(id).update({
      'lastVerifiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> incrementChatCount(String id) async {
    if (id.isEmpty) return;
    await _firestore.collection('housing_listings').doc(id).update({
      'chatCount': FieldValue.increment(1),
    });
  }

  @override
  Future<void> incrementCallCount(String id) async {
    if (id.isEmpty) return;
    await _firestore.collection('housing_listings').doc(id).update({
      'callCount': FieldValue.increment(1),
    });
  }

  @override
  Future<void> incrementShareCount(String id) async {
    if (id.isEmpty) return;
    await _firestore.collection('housing_listings').doc(id).update({
      'sharesCount': FieldValue.increment(1),
    });
  }

  @override
  Future<void> submitReview(HousingReview review) async {
    await _firestore.runTransaction((transaction) async {
      final reviewRef = _firestore.collection('housing_reviews').doc(review.id);
      final userRef = _firestore.collection('users').doc(review.plugId);

      // 1. All Reads
      final userDoc = await transaction.get(userRef);
      final reviewDoc = await transaction.get(reviewRef);

      // 2. All Writes
      transaction.set(reviewRef, review.toFirestore());

      if (userDoc.exists) {
        final data = userDoc.data()!;
        final currentRating = (data['averageRating'] ?? 0.0).toDouble();
        final currentCount = (data['ratingsCount'] ?? 0).toInt();
        
        double newRating;
        int newCount;

        if (reviewDoc.exists) {
          final oldRating = (reviewDoc.data()?['rating'] ?? 0.0).toDouble();
          newCount = currentCount;
          newRating = currentCount > 0 
              ? ((currentRating * currentCount) - oldRating + review.rating) / newCount
              : review.rating;
        } else {
          newCount = currentCount + 1;
          newRating = ((currentRating * currentCount) + review.rating) / newCount;
        }

        transaction.update(userRef, {
          'averageRating': newRating,
          'ratingsCount': newCount,
          'trustScore': FieldValue.increment(review.rating >= 4 ? 2.0 : -1.0),
        });
      }
    });
  }

  @override
  Future<void> createRoommateProfile(RoommateProfile profile) async {
    await _firestore.collection('roommates').doc(profile.id).set(profile.toFirestore());
  }

  @override
  Future<void> reportListing({
    required String listingId,
    required String reporterId,
    required String reason,
    required String category,
  }) async {
    await _firestore.collection('housing_reports').add({
      'listingId': listingId,
      'reporterId': reporterId,
      'reason': reason,
      'category': category,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });

    if (_notificationSender != null) {
      await _notificationSender!.notifyAdmins(
        title: 'Housing Report 🏠',
        body: 'A property has been reported for: $reason',
        route: '/admin/reports',
      );
    }

    // Notify plug that their listing is under review
    final listingDoc = await _firestore.collection('housing_listings').doc(listingId).get();
    if (listingDoc.exists) {
      final plugId = listingDoc.data()?['plugId'];
      if (plugId != null && _notificationSender != null) {
        await _notificationSender!.sendNotification(
          recipientId: plugId,
          title: 'Listing Reported',
          body: 'One of your listings has been reported and is under moderation.',
          type: NotificationType.system,
          targetId: listingId,
          targetType: 'housing',
          deepLink: '/plug-dashboard',
        );
      }
    }
  }

  @override
  Future<void> saveListing(String userId, String listingId) async {
    if (userId.isEmpty || listingId.isEmpty || _userActivityRepository == null) return;
    
    await _userActivityRepository!.recordActivity(
      userId: userId, 
      contentId: listingId, 
      activityType: ActivityType.saved, 
      contentType: ContentType.housing,
    );
    
    final listingDoc = await _firestore.collection('housing_listings').doc(listingId).get();
    if (listingDoc.exists) {
      final plugId = listingDoc.data()?['plugId'];
      final title = listingDoc.data()?['title'];
      
      await _firestore.collection('housing_listings').doc(listingId).update({
        'saves': FieldValue.increment(1),
      });

      if (plugId != null && _notificationSender != null) {
        await _notificationSender!.sendNotification(
          recipientId: plugId,
          title: 'New Save!',
          body: 'Someone saved your listing: $title',
          type: NotificationType.housing,
          targetId: listingId,
          targetType: 'housing',
          deepLink: '/plug-dashboard',
        );
      }
    }
  }

  @override
  Future<void> unsaveListing(String userId, String listingId) async {
    if (userId.isEmpty || listingId.isEmpty || _userActivityRepository == null) return;
    
    await _userActivityRepository!.removeActivity(
      userId: userId, 
      contentId: listingId, 
      activityType: ActivityType.saved, 
      contentType: ContentType.housing,
    );
    
    await _firestore.collection('housing_listings').doc(listingId).update({
      'saves': FieldValue.increment(-1),
    });
  }

  @override
  Stream<List<HousingListing>> watchSavedListings(String userId) {
    if (userId.isEmpty || _userActivityRepository == null) return Stream.value([]);
    
    return _userActivityRepository!.watchActivityIds(
      userId: userId, 
      activityType: ActivityType.saved, 
      contentType: ContentType.housing,
      limit: 100, // Scaled for RC-3
    ).asyncMap((listingIds) async {
      if (listingIds.isEmpty) return [];
      
      final List<HousingListing> allListings = [];
      const int chunkSize = 30;
      
      for (var i = 0; i < listingIds.length; i += chunkSize) {
        final end = (i + chunkSize < listingIds.length) ? i + chunkSize : listingIds.length;
        final chunk = listingIds.sublist(i, end);

        final listingsSnapshot = await _firestore
            .collection('housing_listings')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        allListings.addAll(listingsSnapshot.docs
            .map((doc) => HousingListing.fromFirestore(doc)));
      }
          
      allListings.sort((a, b) => listingIds.indexOf(a.id).compareTo(listingIds.indexOf(b.id)));
      return allListings;
    });
  }

  @override
  Stream<List<HousingListing>> watchRecentlyViewed(String userId) {
    if (userId.isEmpty || _userActivityRepository == null) return Stream.value([]);
    
    return _userActivityRepository!.watchActivityIds(
      userId: userId, 
      activityType: ActivityType.recentlyViewed, 
      contentType: ContentType.housing,
      limit: 100, // Scaled for RC-3
    ).asyncMap((ids) async {
      if (ids.isEmpty) return [];
      
      final List<HousingListing> allListings = [];
      const int chunkSize = 30;
      
      for (var i = 0; i < ids.length; i += chunkSize) {
        final end = (i + chunkSize < ids.length) ? i + chunkSize : ids.length;
        final chunk = ids.sublist(i, end);

        final listingsSnapshot = await _firestore
            .collection('housing_listings')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        allListings.addAll(listingsSnapshot.docs
            .map((doc) => HousingListing.fromFirestore(doc))
            .where((l) => l.status == HousingStatus.available));
      }
          
      allListings.sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));
      return allListings;
    });
  }

  @override
  Future<void> clearRecentlyViewed(String userId) async {
    if (userId.isEmpty || _userActivityRepository == null) return;
    await _userActivityRepository!.clearActivity(
      userId: userId, 
      activityType: ActivityType.recentlyViewed, 
      contentType: ContentType.housing,
    );
  }

  @override
  Future<void> submitVacancyRequest(VacancyRequest request) async {
    await _firestore.collection('housing_vacancy_requests').add(request.toFirestore());
  }

  @override
  Stream<List<VacancyRequest>> watchVacancyOpportunities() {
    Query query = _firestore.collection('housing_vacancy_requests')
        .where('status', isEqualTo: VacancyRequestStatus.open.name);
    
    if (_browsingCampus != null && _browsingCampus!.isNotEmpty) {
      query = query.where('university', isEqualTo: _browsingCampus);
    }

    return query.snapshots().map((snapshot) {
      final requests = snapshot.docs.map((doc) => VacancyRequest.fromFirestore(doc)).toList();
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    });
  }

  @override
  Future<void> claimVacancyRequest(String requestId, String plugId, String plugName) async {
    await _firestore.collection('housing_vacancy_requests').doc(requestId).update({
      'status': VacancyRequestStatus.claimed.name,
      'claimedByPlugId': plugId,
      'claimedByPlugName': plugName,
    });
  }

  @override
  Future<void> saveHousingSearch(HousingSavedSearch search) async {
    await _firestore.collection('housing_saved_searches').add(search.toFirestore());
  }

  @override
  Stream<List<HousingSavedSearch>> watchSavedHousingSearches(String userId) {
    return _firestore.collection('housing_saved_searches')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs.map((doc) => HousingSavedSearch.fromFirestore(doc)).toList();
          items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return items;
        });
  }

  @override
  Future<void> deleteHousingSearch(String searchId) async {
    await _firestore.collection('housing_saved_searches').doc(searchId).delete();
  }

  @override
  Future<void> toggleHousingSearchNotifications(String searchId, bool enabled) async {
    await _firestore.collection('housing_saved_searches').doc(searchId).update({
      'notificationsEnabled': enabled,
    });
  }

  @override
  Future<void> submitViewingRequest(ViewingRequest request) async {
    final ref = _firestore.collection('housing_viewing_requests').doc();
    await ref.set(request.toFirestore());

    if (_notificationSender != null) {
      await _notificationSender!.sendNotification(
        recipientId: request.plugId,
        title: 'New Viewing Request 🏠',
        body: '${request.studentName} wants to view ${request.listingTitle}',
        type: NotificationType.housing,
        targetId: ref.id,
        targetType: 'viewing_request',
        deepLink: '/viewing-requests',
      );
    }
  }

  @override
  Stream<List<ViewingRequest>> watchViewingRequests({required String userId, bool asPlug = false}) {
    return _firestore.collection('housing_viewing_requests')
        .where(asPlug ? 'plugId' : 'studentId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs.map((doc) => ViewingRequest.fromFirestore(doc)).toList();
          items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return items;
        });
  }

  @override
  Future<void> updateViewingRequestStatus(String requestId, ViewingRequestStatus status) async {
    await _firestore.collection('housing_viewing_requests').doc(requestId).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Notify the student
    final doc = await _firestore.collection('housing_viewing_requests').doc(requestId).get();
    if (doc.exists) {
      final data = doc.data()!;
      final studentId = data['studentId'];
      final title = data['listingTitle'];
      
      if (_notificationSender != null) {
        await _notificationSender!.sendNotification(
          recipientId: studentId,
          title: 'Viewing Request Update',
          body: 'Your request for $title has been ${status.name}.',
          type: NotificationType.housing,
          targetId: requestId,
          targetType: 'viewing_request',
          deepLink: '/viewing-requests',
        );
      }
    }
  }
}
