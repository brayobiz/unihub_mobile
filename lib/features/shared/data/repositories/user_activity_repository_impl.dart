import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unihub_mobile/core/error/error_handler.dart';
import '../../domain/repositories/user_activity_repository.dart';

class UserActivityRepositoryImpl implements UserActivityRepository {
  final FirebaseFirestore _firestore;

  UserActivityRepositoryImpl(this._firestore);

  CollectionReference _getCollection(String userId, ActivityType activityType, ContentType contentType) {
    String subCollectionName;
    switch (activityType) {
      case ActivityType.recentlyViewed:
        subCollectionName = contentType == ContentType.marketplace ? 'recently_viewed' : 'recently_viewed_${contentType.name}';
        break;
      case ActivityType.saved:
        if (contentType == ContentType.marketplace) subCollectionName = 'saved_listings';
        else if (contentType == ContentType.housing) subCollectionName = 'saved_housing';
        else subCollectionName = 'saved_${contentType.name}';
        break;
      case ActivityType.searched:
        subCollectionName = contentType == ContentType.marketplace ? 'recent_searches' : 'recent_searches_${contentType.name}';
        break;
    }
    
    return _firestore.collection('users').doc(userId).collection(subCollectionName);
  }

  @override
  Future<void> recordActivity({
    required String userId,
    required String contentId,
    required ActivityType activityType,
    required ContentType contentType,
    Map<String, dynamic>? metadata,
  }) async {
    if (userId.isEmpty || contentId.isEmpty) return;

    try {
      final docRef = _getCollection(userId, activityType, contentType).doc(contentId);
      
      await docRef.set({
        'contentId': contentId,
        'timestamp': FieldValue.serverTimestamp(),
        if (metadata != null) ...metadata,
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  @override
  Future<void> removeActivity({
    required String userId,
    required String contentId,
    required ActivityType activityType,
    required ContentType contentType,
  }) async {
    if (userId.isEmpty || contentId.isEmpty) return;
    try {
      await _getCollection(userId, activityType, contentType).doc(contentId).delete();
    } catch (e) {
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  @override
  Stream<List<String>> watchActivityIds({
    required String userId,
    required ActivityType activityType,
    required ContentType contentType,
    int limit = 30,
  }) {
    if (userId.isEmpty) return Stream.value([]);

    return _getCollection(userId, activityType, contentType)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  @override
  Future<void> clearActivity({
    required String userId,
    required ActivityType activityType,
    required ContentType contentType,
  }) async {
    if (userId.isEmpty) return;

    try {
      final snapshot = await _getCollection(userId, activityType, contentType).get();
      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      throw Exception(AppErrorHandler.mapError(e));
    }
  }
}
