import 'package:cloud_firestore/cloud_firestore.dart';

enum ActivityType {
  recentlyViewed,
  saved,
  searched,
}

enum ContentType {
  marketplace,
  housing,
  notes,
  gig,
  community,
}

abstract class UserActivityRepository {
  Future<void> recordActivity({
    required String userId,
    required String contentId,
    required ActivityType activityType,
    required ContentType contentType,
    Map<String, dynamic>? metadata,
  });

  Future<void> removeActivity({
    required String userId,
    required String contentId,
    required ActivityType activityType,
    required ContentType contentType,
  });

  Stream<List<String>> watchActivityIds({
    required String userId,
    required ActivityType activityType,
    required ContentType contentType,
    int limit = 30,
  });

  Future<void> clearActivity({
    required String userId,
    required ActivityType activityType,
    required ContentType contentType,
  });
}
