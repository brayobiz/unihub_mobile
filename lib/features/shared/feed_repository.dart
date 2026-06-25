import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/feed_type.dart';
import '../../features/auth/shared/providers.dart';
import 'package:unihub_mobile/core/services/cache_service.dart';

final feedRepositoryProvider = Provider((ref) => FeedRepository(
  ref.watch(firestoreProvider),
));

class FeedItem {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String title;
  final String subtitle;
  final String? price;
  final FeedType type;
  final String? university;
  final DateTime createdAt;
  final DateTime? deadline;
  final List<String> images;
  final int likesCount;
  final List<String> likedBy;
  final String? category;

  FeedItem({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.title,
    required this.subtitle,
    this.price,
    required this.type,
    this.university,
    required this.createdAt,
    this.deadline,
    this.images = const [],
    this.likesCount = 0,
    this.likedBy = const [],
    this.category,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic date) {
      if (date == null) return DateTime.now();
      if (date is Timestamp) return date.toDate();
      return DateTime.now();
    }

    return FeedItem(
      id: json['id'] ?? '',
      authorId: json['authorId'] ?? '',
      authorName: json['authorName'] ?? 'Anonymous',
      authorPhotoUrl: json['authorPhotoUrl'],
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      price: json['price'],
      type: FeedType.values.firstWhere((e) => e.name == json['type'], orElse: () => FeedType.community),
      university: json['university'],
      createdAt: parseDate(json['createdAt']),
      deadline: json['deadline'] != null ? parseDate(json['deadline']) : null,
      images: List<String>.from(json['images'] ?? []),
      likesCount: json['likesCount'] ?? 0,
      likedBy: List<String>.from(json['likedBy'] ?? []),
      category: json['category'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'authorId': authorId,
    'authorName': authorName,
    'authorPhotoUrl': authorPhotoUrl,
    'title': title,
    'subtitle': subtitle,
    'price': price,
    'type': type.name,
    'university': university,
    'createdAt': Timestamp.fromDate(createdAt),
    'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
    'images': images,
    'likesCount': likesCount,
    'likedBy': likedBy,
    'category': category,
  };
}

class FeedRepository {
  final FirebaseFirestore _firestore;

  FeedRepository(this._firestore);

  Stream<List<FeedItem>> watchFeed(FeedType type, {String? university, int limit = 20}) {
    Query query = _firestore.collection('feed')
        .where('type', isEqualTo: type.name)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    
    return query.snapshots().map((snapshot) {
      final items = snapshot.docs
          .map((doc) => FeedItem.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      
      var filteredItems = items;
      
      // Filter logic
      final bool shouldFilterByUniversity = 
          type != FeedType.community && 
          type != FeedType.gig && 
          type != FeedType.confession;

      if (shouldFilterByUniversity && university != null && university.isNotEmpty) {
        filteredItems = items.where((i) {
          if (i.university == null || i.university!.isEmpty) return true;
          return i.university == university;
        }).toList();
      }

      return filteredItems;
    });
  }

  /// Permanently deletes gigs older than 3 days from the database.
  /// This is optimized to avoid Firestore Composite Index requirements.
  Future<void> cleanupExpiredGigs() async {
    final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
    
    // Fetch only by type to avoid needing a composite index for createdAt
    final snapshot = await _firestore
        .collection('feed')
        .where('type', isEqualTo: FeedType.gig.name)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    int deleteCount = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp).toDate();
      
      if (createdAt.isBefore(threeDaysAgo)) {
        batch.delete(doc.reference);
        deleteCount++;
      }
    }

    if (deleteCount > 0) {
      await batch.commit();
    }
  }

  Future<void> postToFeed(FeedItem item) async {
    await _firestore.collection('feed').doc(item.id).set(item.toJson());
  }

  Future<void> deleteFeedItem(String id) async {
    await _firestore.collection('feed').doc(id).delete();
  }

  Future<void> toggleLike(String itemId, String userId) async {
    final docRef = _firestore.collection('feed').doc(itemId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final item = FeedItem.fromJson(doc.data() as Map<String, dynamic>);
    if (item.likedBy.contains(userId)) {
      await docRef.update({
        'likesCount': FieldValue.increment(-1),
        'likedBy': FieldValue.arrayRemove([userId]),
      });
    } else {
      await docRef.update({
        'likesCount': FieldValue.increment(1),
        'likedBy': FieldValue.arrayUnion([userId]),
      });
    }
  }

  Future<void> addComment({
    required String itemId,
    required String userId,
    required String userName,
    required String text,
  }) async {
    await _firestore.collection('feed').doc(itemId).collection('comments').add({
      'userId': userId,
      'userName': userName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> watchComments(String itemId) {
    return _firestore
        .collection('feed')
        .doc(itemId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> reportItem(String itemId, String userId, String reason) async {
    await _firestore.collection('reports').add({
      'itemId': itemId,
      'reporterId': userId,
      'reason': reason,
      'type': 'feed_item',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
