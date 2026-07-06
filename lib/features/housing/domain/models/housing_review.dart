import 'package:cloud_firestore/cloud_firestore.dart';

class HousingReview {
  final String id;
  final String plugId;
  final String? listingId;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String comment;
  final double rating;
  final DateTime createdAt;

  HousingReview({
    required this.id,
    required this.plugId,
    this.listingId,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.comment,
    required this.rating,
    required this.createdAt,
  });

  factory HousingReview.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HousingReview(
      id: doc.id,
      plugId: data['plugId'] ?? '',
      listingId: data['listingId'],
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userPhotoUrl: data['userPhotoUrl'],
      comment: data['comment'] ?? '',
      rating: (data['rating'] ?? 0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'plugId': plugId,
      'listingId': listingId,
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'comment': comment,
      'rating': rating,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
