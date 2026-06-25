import 'package:cloud_firestore/cloud_firestore.dart';

class HousingReview {
  final String id;
  final String listingId;
  final String userId;
  final String userName;
  final String userImage;
  final String comment;
  final double rating;
  final double securityRating;
  final double waterRating;
  final double wifiRating;
  final double landlordRating;
  final DateTime createdAt;
  final bool isVerifiedTenant;

  HousingReview({
    required this.id,
    required this.listingId,
    required this.userId,
    required this.userName,
    this.userImage = '',
    required this.comment,
    required this.rating,
    this.securityRating = 0,
    this.waterRating = 0,
    this.wifiRating = 0,
    this.landlordRating = 0,
    required this.createdAt,
    this.isVerifiedTenant = false,
  });

  factory HousingReview.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HousingReview(
      id: doc.id,
      listingId: data['listingId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userImage: data['userImage'] ?? '',
      comment: data['comment'] ?? '',
      rating: (data['rating'] ?? 0).toDouble(),
      securityRating: (data['securityRating'] ?? 0).toDouble(),
      waterRating: (data['waterRating'] ?? 0).toDouble(),
      wifiRating: (data['wifiRating'] ?? 0).toDouble(),
      landlordRating: (data['landlordRating'] ?? 0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isVerifiedTenant: data['isVerifiedTenant'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'listingId': listingId,
      'userId': userId,
      'userName': userName,
      'userImage': userImage,
      'comment': comment,
      'rating': rating,
      'securityRating': securityRating,
      'waterRating': waterRating,
      'wifiRating': wifiRating,
      'landlordRating': landlordRating,
      'createdAt': Timestamp.fromDate(createdAt),
      'isVerifiedTenant': isVerifiedTenant,
    };
  }
}
