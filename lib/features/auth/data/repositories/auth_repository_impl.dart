import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:unihub_mobile/features/auth/domain/models/app_user.dart';
import 'package:unihub_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:unihub_mobile/core/utils/app_logger.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AuthRepositoryImpl(this._firebaseAuth, this._firestore);

  @override
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  @override
  User? get currentUser => _firebaseAuth.currentUser;

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      AppLogger.info('Auth: Attempting sign in for ${email.split('@').first}@...', 'AUTH');
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      AppLogger.info('Auth: Sign in successful', 'AUTH');
    } on FirebaseAuthException catch (e) {
      AppLogger.warning('Auth: FirebaseAuthException: ${e.code}', 'AUTH');
      throw _handleAuthException(e);
    } catch (e) {
      AppLogger.error('Auth: General Exception', e, StackTrace.current, 'AUTH');
      if (e.toString().contains('Connection reset by peer')) {
        throw Exception('Network error: Connection reset by peer. Please check your internet connection or VPN.');
      }
      throw Exception('Authentication failed: $e');
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return; // User canceled the sign-in flow
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Use a more robust check and creation logic
        await _ensureUserDocumentExists(user);
      }
    } on FirebaseAuthException catch (e) {
      AppLogger.warning('Auth: Google Sign-in Firebase Error: ${e.code}', 'AUTH');
      throw _handleAuthException(e);
    } catch (e) {
      AppLogger.error('Auth: Google Sign-in General Error', e, StackTrace.current, 'AUTH');
      if (e.toString().contains('7000') || e.toString().contains('developer_error')) {
        throw Exception('Google Sign-In configuration error: Please verify that you have added your SHA-1 fingerprint to the Firebase Console and enabled Google Auth.');
      }
      throw Exception('Failed to sign in with Google: $e');
    }
  }

  Future<void> _ensureUserDocumentExists(User user) async {
    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        AppLogger.info('Auth: Creating new user document for ${user.uid}', 'AUTH');
        final appUser = AppUser(
          uid: user.uid,
          email: user.email ?? '',
          fullName: user.displayName ?? 'UniHub User',
          photoUrl: user.photoURL,
          createdAt: DateTime.now(),
        );
        await docRef.set(appUser.toJson());
      } else {
        // Optional: Update last seen or FCM token if needed
        await docRef.update({
          'lastSeen': FieldValue.serverTimestamp(),
        }).catchError((_) => null);
      }
    } catch (e) {
      AppLogger.error('Auth: Error ensuring user document exists', e, null, 'AUTH');
      // We don't throw here to avoid failing sign-in if just the document creation fails,
      // though the app might be limited until the doc is created.
      // In a production app, we might want to retry or handle this in a splash screen.
    }
  }

  @override
  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final normalizedEmail = email.toLowerCase().trim();
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      if (credential.user != null) {
        final appUser = AppUser(
          uid: credential.user!.uid,
          email: normalizedEmail,
          fullName: fullName,
          createdAt: DateTime.now(),
        );

        await _firestore.collection('users').doc(appUser.uid).set(appUser.toJson());
        await credential.user!.updateDisplayName(fullName);
        
        try {
          await credential.user!.sendEmailVerification();
          AppLogger.info('Auth: New user registered and verification sent: ${appUser.uid}', 'AUTH');
        } catch (e) {
          AppLogger.warning('Auth: User registered but verification email failed: $e', 'AUTH');
        }
      }
    } on FirebaseAuthException catch (e) {
      AppLogger.warning('Auth: Sign-up error: ${e.code}', 'AUTH');
      throw _handleAuthException(e);
    } catch (e) {
      AppLogger.error('Auth: Sign-up general error', e, null, 'AUTH');
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      AppLogger.info('Auth: Signing out...', 'AUTH');
      
      // 1. Sign out from Google (with timeout to prevent hanging)
      try {
        await _googleSignIn.signOut().timeout(const Duration(seconds: 3));
      } catch (e) {
        AppLogger.warning('Auth: Google SignOut error or timeout: $e', 'AUTH');
      }

      // 2. Sign out from Firebase
      await _firebaseAuth.signOut();
      
      AppLogger.info('Auth: Sign out successful', 'AUTH');
    } catch (e) {
      AppLogger.error('Auth: Error during sign out', e, null, 'AUTH');
      // Final attempt to sign out from Firebase regardless of previous errors
      try {
        await _firebaseAuth.signOut();
      } catch (_) {}
      rethrow;
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      AppLogger.info('Auth: Password reset email sent to $email', 'AUTH');
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        AppLogger.info('Auth: Email verification sent to ${user.email}', 'AUTH');
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  @override
  Future<void> reauthenticate(String email, String password) async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      AppLogger.info('Auth: Re-authenticating user...', 'AUTH');
      final credential = EmailAuthProvider.credential(email: email, password: password);
      await user.reauthenticateWithCredential(credential);
    }
  }

  @override
  Stream<AppUser?> watchUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return AppUser.fromJson(snapshot.data()!);
      }
      return null;
    }).handleError((error) {
      AppLogger.error('Auth: Firestore User Watch Error', error, null, 'AUTH');
    });
  }

  @override
  Future<AppUser?> getUser(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return AppUser.fromJson(doc.data()!);
      }
    } catch (e) {
      AppLogger.error('Auth: Error getting user', e, null, 'AUTH');
    }
    return null;
  }

  @override
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
  }) async {
    try {
      AppLogger.info('Auth: Updating profile for $uid', 'AUTH');
      final Map<String, dynamic> data = {};
      if (fullName != null) data['fullName'] = fullName;
      if (username != null) data['username'] = username;
      if (bio != null) data['bio'] = bio;
      if (photoUrl != null) data['photoUrl'] = photoUrl;
      if (coverPhotoUrl != null) data['coverPhotoUrl'] = coverPhotoUrl;
      if (university != null) data['university'] = university;
      if (campus != null) data['campus'] = campus;
      if (course != null) data['course'] = course;
      if (yearOfStudy != null) data['yearOfStudy'] = yearOfStudy;
      if (housingStatus != null) data['housingStatus'] = housingStatus;
      if (whatsappNumber != null) data['whatsappNumber'] = whatsappNumber;
      if (phoneNumber != null) data['phoneNumber'] = phoneNumber;
      if (skills != null) data['skills'] = skills;
      if (interests != null) data['interests'] = interests;
      
      final docRef = _firestore.collection('users').doc(uid);
      final batch = _firestore.batch();

      if (privacySettings != null) {
        privacySettings.forEach((k, v) => data['privacySettings.$k'] = v);
      }

      if (notificationSettings != null) {
        notificationSettings.forEach((k, v) => data['notificationSettings.$k'] = v);
      }

      if (data.isNotEmpty) {
        batch.set(docRef, data, SetOptions(merge: true));
        
        final currentUser = _firebaseAuth.currentUser;
        if (currentUser != null && fullName != null && currentUser.displayName != fullName) {
          await currentUser.updateDisplayName(fullName);
        }
      }
      
      await batch.commit();
    } catch (e) {
      AppLogger.error('Auth: Firestore Update Profile Error', e, null, 'AUTH');
      rethrow;
    }
  }

  @override
  Future<void> updateOnboardingStatus(String uid, bool completed) async {
    await _firestore.collection('users').doc(uid).set({
      'isOnboardingCompleted': completed,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;
    
    final uid = user.uid;
    AppLogger.warning('Auth: PERMANENTLY DELETING ACCOUNT: $uid', 'AUTH');

    try {
      // 0. Mark user document as deleted first (while we still have Auth)
      // This ensures that even if Auth deletion fails, we know this account is "gone"
      await _firestore.collection('users').doc(uid).update({
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      }).catchError((_) => null);

      // 1. Try to delete Auth user first to catch 'requires-recent-login'
      await user.delete();
      AppLogger.info('Auth: Firebase Auth user deleted successfully', 'AUTH');
      
      // 2. Proceed with Firestore cleanup (Best effort on client)
      await _performCleanup(uid);
      
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        AppLogger.warning('Auth: Delete account failed: Requires recent login', 'AUTH');
        throw Exception('This operation is sensitive and requires recent authentication. Please sign in again.');
      }
      AppLogger.error('Auth: Delete account FirebaseAuthException', e, null, 'AUTH');
      throw _handleAuthException(e);
    } catch (e) {
      AppLogger.error('Auth: General error during account deletion', e, null, 'AUTH');
      rethrow;
    }
  }

  Future<void> _performCleanup(String uid) async {
    try {
      // We process collections sequentially to avoid massive memory spikes
      final collections = [
        'listings', 'housing_listings', 'notes', 'feed', 'gig_applications', 
        'verification_applications', 'student_verifications', 'identity_verifications',
        'events', 'organizers'
      ];

      for (var coll in collections) {
        String queryField = 'authorId';
        if (coll == 'listings') queryField = 'sellerId';
        if (coll == 'housing_listings') queryField = 'plugId';
        if (coll == 'gig_applications') queryField = 'freelancerId';
        if (coll == 'verification_applications') queryField = 'userId';
        if (coll == 'events') queryField = 'createdBy';
        if (coll == 'organizers') queryField = 'ownerId';
        
        if (coll == 'student_verifications' || coll == 'identity_verifications') {
          await _firestore.collection(coll).doc(uid).delete().catchError((_) => null);
          continue;
        }

        final snapshots = await _firestore.collection(coll)
            .where(queryField, isEqualTo: uid)
            .limit(100) // Process in chunks to avoid batch limits
            .get();

        if (snapshots.docs.isNotEmpty) {
          final batch = _firestore.batch();
          for (var doc in snapshots.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit().catchError((_) => null);
        }
      }

      // Delete user notifications subcollection and user document
      final notifications = await _firestore.collection('users').doc(uid).collection('notifications').limit(50).get();
      if (notifications.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in notifications.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit().catchError((_) => null);
      }

      await _firestore.collection('users').doc(uid).delete().catchError((_) => null);
      AppLogger.info('Auth: Best-effort Firestore cleanup completed for $uid', 'AUTH');
    } catch (e) {
      AppLogger.warning('Auth: Firestore cleanup encountered errors: $e', 'AUTH');
    }
  }

  @override
  Future<void> blockUser(String uid, String blockedUid) async {
    await _firestore.collection('users').doc(uid).update({
      'blockedUids': FieldValue.arrayUnion([blockedUid]),
    });
  }

  @override
  Future<void> unblockUser(String uid, String blockedUid) async {
    await _firestore.collection('users').doc(uid).update({
      'blockedUids': FieldValue.arrayRemove([blockedUid]),
    });
  }

  @override
  Future<void> updateTrustScore(String uid, double delta) async {
    await _firestore.collection('users').doc(uid).update({
      'trustScore': FieldValue.increment(delta),
    });
  }

  @override
  Future<void> addReview({
    required String targetUid,
    required double rating,
    required String comment,
    required String reviewerId,
    required String reviewerName,
    required String listingId,
  }) async {
    final batch = _firestore.batch();
    
    final reviewRef = _firestore.collection('users').doc(targetUid).collection('reviews').doc();
    batch.set(reviewRef, {
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'rating': rating,
      'comment': comment,
      'listingId': listingId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    final userRef = _firestore.collection('users').doc(targetUid);
    final userDoc = await userRef.get();
    final currentAvg = (userDoc.data()?['averageRating'] ?? 0.0).toDouble();
    final currentCount = (userDoc.data()?['ratingsCount'] ?? 0).toInt();
    
    final newCount = currentCount + 1;
    final newAvg = ((currentAvg * currentCount) + rating) / newCount;
    
    batch.update(userRef, {
      'averageRating': newAvg,
      'ratingsCount': newCount,
      'trustScore': FieldValue.increment(rating >= 4 ? 2.0 : -1.0),
    });

    await batch.commit();
  }

  Exception _handleAuthException(FirebaseAuthException e) {
    AppLogger.warning('🛑 Auth Error Code: ${e.code}', 'AUTH');
    switch (e.code) {
      case 'user-not-found':
      case 'user-disabled':
      case 'invalid-email':
      case 'wrong-password':
      case 'invalid-credential':
        return Exception('Invalid email or password. Please try again.');
      case 'email-already-in-use':
        return Exception('This email is already registered. Please sign in instead.');
      case 'operation-not-allowed':
        return Exception('This authentication method is currently disabled.');
      case 'weak-password':
        return Exception('The password provided is too weak.');
      case 'network-request-failed':
        return Exception('No internet connection. Please check your network and try again.');
      case 'too-many-requests':
        return Exception('Too many attempts. Please try again in a few minutes.');
      default:
        return Exception(e.message ?? 'An unexpected authentication error occurred. Please try again.');
    }
  }
}

