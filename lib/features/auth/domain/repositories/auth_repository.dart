import 'package:firebase_auth/firebase_auth.dart';
import 'package:unihub_mobile/features/auth/domain/models/app_user.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  User? get currentUser;
  Future<void> signInWithEmailAndPassword(String email, String password);
  Future<void> signInWithGoogle();
  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
  });
  Future<void> signOut();
  Future<void> resetPassword(String email);
  Stream<AppUser?> watchUser(String uid);
  Future<AppUser?> getUser(String uid);
  Future<void> updateProfile({
    required String uid,
    String? fullName,
    String? username,
    String? bio,
    String? photoUrl,
    String? coverPhotoUrl,
    String? university,
    String? campus,
    String? course,
    String? yearOfStudy,
    String? housingStatus,
    String? whatsappNumber,
    String? phoneNumber,
    List<String>? skills,
    List<String>? interests,
    Map<String, String>? socialLinks,
    Map<String, String>? privacySettings,
    Map<String, bool>? notificationSettings,
  });
  Future<void> updateOnboardingStatus(String uid, bool completed);
  Future<void> deleteAccount();
  
  // Reputation & Trust
  Future<void> updateTrustScore(String uid, double delta);
  Future<void> addReview({
    required String targetUid,
    required double rating,
    required String comment,
    required String reviewerId,
    required String reviewerName,
    required String listingId,
  });
}
