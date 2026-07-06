import 'package:cloud_firestore/cloud_firestore.dart';

enum CommunityPostStatus { active, flagged, suspended, removed }
enum CommunityUserRole { member, moderator, admin }

class CommunityPost {
  final String id;
  final String userId;
  final String userName;
  final String userPhotoUrl;
  final String campusId;

  final String title;
  final String content;
  final List<String> tags;
  final List<String> attachmentUrls;

  final CommunityPostStatus status;
  final int upvotes;
  final int downvotes;
  final int commentCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isPinned;

  CommunityPost({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhotoUrl,
    required this.campusId,
    required this.title,
    required this.content,
    this.tags = const [],
    this.attachmentUrls = const [],
    this.status = CommunityPostStatus.active,
    this.upvotes = 0,
    this.downvotes = 0,
    this.commentCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.isPinned = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'campusId': campusId,
      'title': title,
      'content': content,
      'tags': tags,
      'attachmentUrls': attachmentUrls,
      'status': status.name,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'commentCount': commentCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isPinned': isPinned,
      'searchKeywords': title.toLowerCase().split(' '),
    };
  }

  factory CommunityPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommunityPost(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      userPhotoUrl: data['userPhotoUrl'] ?? '',
      campusId: data['campusId'] ?? '',
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      attachmentUrls: List<String>.from(data['attachmentUrls'] ?? []),
      status: CommunityPostStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => CommunityPostStatus.active,
      ),
      upvotes: data['upvotes'] ?? 0,
      downvotes: data['downvotes'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      isPinned: data['isPinned'] ?? false,
    );
  }
}

class CommunityComment {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String userPhotoUrl;
  final String content;
  final String? parentCommentId;  // For nested/threaded replies

  final int upvotes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;

  CommunityComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.userPhotoUrl,
    required this.content,
    this.parentCommentId,
    this.upvotes = 0,
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'postId': postId,
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'content': content,
      'parentCommentId': parentCommentId,
      'upvotes': upvotes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isDeleted': isDeleted,
    };
  }

  factory CommunityComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommunityComment(
      id: doc.id,
      postId: data['postId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      userPhotoUrl: data['userPhotoUrl'] ?? '',
      content: data['content'] ?? '',
      parentCommentId: data['parentCommentId'],
      upvotes: data['upvotes'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      isDeleted: data['isDeleted'] ?? false,
    );
  }
}

