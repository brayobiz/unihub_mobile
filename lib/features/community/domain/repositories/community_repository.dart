import '../models/community_post.dart';

abstract class CommunityRepository {
  // Posts
  Future<void> createPost(CommunityPost post);
  Future<void> updatePost(CommunityPost post);
  Future<void> deletePost(String postId, String userId);

  Stream<List<CommunityPost>> watchCampusPosts({
    String? campusId,
    List<String>? tags,
    int limit = 50,
    CommunityPost? startAfter,
  });

  Future<CommunityPost?> getPostById(String postId);
  Stream<List<CommunityPost>> watchUserPosts(String userId);

  // Voting
  Future<void> upvotePost(String postId, String userId);
  Future<void> downvotePost(String postId, String userId);
  Future<void> removeVoteFromPost(String postId, String userId);

  // Comments & Threading
  Future<void> addComment(CommunityComment comment);
  Future<void> updateComment(CommunityComment comment);
  Future<void> deleteComment(String commentId, String userId);

  Stream<List<CommunityComment>> watchPostComments({
    required String postId,
    String? parentCommentId,  // For threaded replies
    int limit = 50,
  });

  Future<void> upvoteComment(String commentId, String userId);
  Future<void> removeVoteFromComment(String commentId, String userId);

  // Search & Discovery
  Stream<List<CommunityPost>> searchPosts({
    required String query,
    required String campusId,
    int limit = 30,
  });

  Stream<List<CommunityPost>> watchTrendingPosts(String campusId, {int limit = 10});

  // Reporting & Moderation
  Future<void> reportPost({
    required String postId,
    required String reporterId,
    required String reason,
    String? description,
  });

  Future<void> reportComment({
    required String commentId,
    required String reporterId,
    required String reason,
    String? description,
  });

  Stream<List<CommunityPost>> watchFlaggedPosts(String campusId);

  // Admin Actions
  Future<void> flagPost({
    required String postId,
    required String reason,
    String? adminNotes,
  });

  Future<void> suspendPost(String postId);

  Future<void> removePost({
    required String postId,
    required String reason,
    required String adminId,
  });

  Future<void> pinPost(String postId);
  Future<void> unpinPost(String postId);

  // User Management
  Future<void> blockUser(String blockerId, String blockedUserId);
  Future<void> unblockUser(String blockerId, String blockedUserId);
  Stream<List<String>> watchBlockedUsers(String userId);

  // Moderator System
  Future<void> assignModerator({
    required String userId,
    required String campusId,
    required String adminId,
  });

  Future<void> removeModerator({
    required String userId,
    required String campusId,
    required String adminId,
  });

  Stream<List<Map<String, dynamic>>> watchModeratorsForCampus(String campusId);
}

