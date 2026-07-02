import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/housing_listing.dart';
import '../../domain/models/housing_review.dart';
import '../../domain/models/roommate_profile.dart';
import '../../domain/models/vacancy_request.dart';
import '../../domain/repositories/housing_repository.dart';
import '../../../../services/notification_service.dart';
import '../../../shared/domain/models/uni_notification.dart';

class HousingRepositoryImpl implements HousingRepository {
  final FirebaseFirestore _firestore;
  final String? _browsingCampus;
  final NotificationService? _notificationService;

  HousingRepositoryImpl(this._firestore, this._browsingCampus, [this._notificationService]);

  @override
  Stream<List<HousingListing>> watchListings({
    String? location,
    HousingType? type,
    double? minRent,
    double? maxRent,
    GenderRestriction? genderRestriction,
    bool? isFurnished,
    bool onlyAvailable = true,
    int limit = 50,
  }) {
    Query query = _firestore.collection('housing_listings');

    if (onlyAvailable) {
      query = query.where('status', isEqualTo: HousingStatus.available.name);
    }

    if (_browsingCampus != null && _browsingCampus!.isNotEmpty) {
      query = query.where('university', isEqualTo: _browsingCampus);
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

    // Use snapshots() and sort in memory to avoid index requirements in Phase 1
    return query.limit(limit).snapshots().map((snapshot) {
      var listings = snapshot.docs.map((doc) => HousingListing.fromFirestore(doc)).toList();
      
      // Client-side filtering
      if (location != null && location.isNotEmpty) {
        listings = listings.where((l) => l.location.toLowerCase().contains(location.toLowerCase())).toList();
      }
      
      if (minRent != null) {
        listings = listings.where((l) => l.rent >= minRent).toList();
      }
      
      if (maxRent != null) {
        listings = listings.where((l) => l.rent <= maxRent).toList();
      }
      
      // Client-side sorting: prioritize available and then by freshness (updatedAt)
      listings.sort((a, b) {
        if (a.status == HousingStatus.available && b.status != HousingStatus.available) return -1;
        if (a.status != HousingStatus.available && b.status == HousingStatus.available) return 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      
      return listings;
    });
  }

  @override
  Stream<List<HousingListing>> watchPlugListings(String plugId) {
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
    Query query = _firestore.collection('roommates')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    return query.snapshots().map((snapshot) {
      var profiles = snapshot.docs.map((doc) => RoommateProfile.fromFirestore(doc)).toList();
      if (_browsingCampus != null && _browsingCampus!.isNotEmpty) {
        profiles = profiles.where((p) => p.campus == _browsingCampus).toList();
      }
      return profiles;
    });
  }

  @override
  Stream<List<HousingReview>> watchPlugReviews(String plugId) {
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
  Future<HousingListing?> getListingById(String id) async {
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
    
    final listingRef = _firestore.collection('housing_listings').doc();
    batch.set(listingRef, listing.toFirestore());
    
    // Update user stats
    final userRef = _firestore.collection('users').doc(listing.plugId);
    batch.update(userRef, {
      'housingListingsCount': FieldValue.increment(1),
    });

    await batch.commit();
    await _logHistory(listingRef.id, 'created', listing.toFirestore());
  }

  @override
  Future<void> updateListing(HousingListing listing) async {
    await _firestore.collection('housing_listings').doc(listing.id).update(listing.toFirestore());
    await _logHistory(listing.id, 'edited', listing.toFirestore());
  }

  @override
  Future<void> deleteListing(String id) async {
    final doc = await _firestore.collection('housing_listings').doc(id).get();
    if (!doc.exists) return;
    
    final plugId = doc.data()?['plugId'];
    
    final batch = _firestore.batch();
    batch.delete(_firestore.collection('housing_listings').doc(id));
    
    if (plugId != null) {
      batch.update(_firestore.collection('users').doc(plugId), {
        'housingListingsCount': FieldValue.increment(-1),
      });
    }
    
    await batch.commit();
    // Cannot log history to a deleted doc's subcollection easily, maybe a global log?
    // For now we just delete.
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
    if (plugId != null && _notificationService != null) {
      await _notificationService!.sendNotification(
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
      // Log error silently
    }
  }

  @override
  Future<void> incrementViews(String id) async {
    await _firestore.collection('housing_listings').doc(id).update({
      'views': FieldValue.increment(1),
    });
  }

  @override
  Future<void> submitReview(HousingReview review) async {
    await _firestore.runTransaction((transaction) async {
      final reviewRef = _firestore.collection('housing_reviews').doc();
      final userRef = _firestore.collection('users').doc(review.plugId);

      transaction.set(reviewRef, review.toFirestore());

      final userDoc = await transaction.get(userRef);
      if (userDoc.exists) {
        final data = userDoc.data()!;
        final currentRating = (data['averageRating'] ?? 0.0).toDouble();
        final currentCount = (data['ratingsCount'] ?? 0).toInt();
        
        final newCount = currentCount + 1;
        final newRating = ((currentRating * currentCount) + review.rating) / newCount;

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

    if (_notificationService != null) {
      await _notificationService!.notifyAdmins(
        title: 'Housing Report 🏠',
        body: 'A property has been reported for: $reason',
        route: '/admin/reports',
      );
    }

    // Notify plug that their listing is under review
    final listingDoc = await _firestore.collection('housing_listings').doc(listingId).get();
    if (listingDoc.exists) {
      final plugId = listingDoc.data()?['plugId'];
      if (plugId != null && _notificationService != null) {
        await _notificationService!.sendNotification(
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
    await _firestore.collection('users').doc(userId).collection('saved_housing').doc(listingId).set({
      'savedAt': FieldValue.serverTimestamp(),
    });
    
    final listingDoc = await _firestore.collection('housing_listings').doc(listingId).get();
    if (listingDoc.exists) {
      final plugId = listingDoc.data()?['plugId'];
      final title = listingDoc.data()?['title'];
      
      await _firestore.collection('housing_listings').doc(listingId).update({
        'saves': FieldValue.increment(1),
      });

      if (plugId != null && _notificationService != null) {
        await _notificationService!.sendNotification(
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
    await _firestore.collection('users').doc(userId).collection('saved_housing').doc(listingId).delete();
    
    await _firestore.collection('housing_listings').doc(listingId).update({
      'saves': FieldValue.increment(-1),
    });
  }

  @override
  Stream<List<HousingListing>> watchSavedListings(String userId) {
    return _firestore.collection('users').doc(userId).collection('saved_housing')
        .orderBy('savedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final listingIds = snapshot.docs.map((doc) => doc.id).toList();
          if (listingIds.isEmpty) return [];
          
          // Use whereIn for efficiency (limited to 30 items as per policy)
          final limitedIds = listingIds.take(30).toList();
          final listingsSnapshot = await _firestore
              .collection('housing_listings')
              .where(FieldPath.documentId, whereIn: limitedIds)
              .get();

          final listings = listingsSnapshot.docs
              .map((doc) => HousingListing.fromFirestore(doc))
              .toList();
          
          // Maintain original sort order from savedAt
          listings.sort((a, b) => limitedIds.indexOf(a.id).compareTo(limitedIds.indexOf(b.id)));
          return listings;
        });
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
}
