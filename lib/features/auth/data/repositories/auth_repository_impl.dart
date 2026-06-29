import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:unihub_mobile/features/auth/domain/models/app_user.dart';
import 'package:unihub_mobile/features/auth/domain/repositories/auth_repository.dart';

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
      debugPrint('🔑 Auth: Attempting sign in for $email');
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('✅ Auth: Sign in successful');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Auth: FirebaseAuthException: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ Auth: General Exception: $e');
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
        throw Exception('Google Sign-In canceled by user.');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          final appUser = AppUser(
            uid: user.uid,
            email: user.email ?? '',
            fullName: user.displayName ?? 'UniHub User',
            photoUrl: user.photoURL,
            createdAt: DateTime.now(),
          );
          await _firestore.collection('users').doc(user.uid).set(appUser.toJson());
        }
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e.toString().contains('7000') || e.toString().contains('developer_error')) {
        throw Exception('Google Sign-In configuration error: Please verify that you have added your SHA-1 fingerprint to the Firebase Console and enabled Google Auth.');
      }
      throw Exception('Failed to sign in with Google: $e');
    }
  }

  @override
  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        final appUser = AppUser(
          uid: credential.user!.uid,
          email: email,
          fullName: fullName,
          createdAt: DateTime.now(),
        );

        await _firestore.collection('users').doc(appUser.uid).set(appUser.toJson());
        await credential.user!.updateDisplayName(fullName);
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  @override
  Stream<AppUser?> watchUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final user = AppUser.fromJson(snapshot.data()!);
        debugPrint('Fetched AppUser: ${user.fullName} (${user.uid})');
        return user;
      }
      debugPrint('AppUser document does not exist for UID: $uid');
      return null;
    }).handleError((error) {
      debugPrint('Firestore User Watch Error: $error');
    });
  }

  @override
  Future<AppUser?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return AppUser.fromJson(doc.data()!);
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
      final Map<String, dynamic> data = {};
      if (fullName != null) data['fullName'] = fullName;
      if (username != null) data['username'] = username;
      if (bio != null) data['bio'] = bio;
      if (photoUrl != null) {
        data['photoUrl'] = photoUrl;
        debugPrint('📝 Firestore: Updating photoUrl to $photoUrl');
      }
      if (coverPhotoUrl != null) {
        data['coverPhotoUrl'] = coverPhotoUrl;
        debugPrint('📝 Firestore: Updating coverPhotoUrl to $coverPhotoUrl');
      }
      if (university != null) data['university'] = university;
      if (campus != null) data['campus'] = campus;
      if (course != null) data['course'] = course;
      if (yearOfStudy != null) data['yearOfStudy'] = yearOfStudy;
      if (housingStatus != null) data['housingStatus'] = housingStatus;
      if (whatsappNumber != null) data['whatsappNumber'] = whatsappNumber;
      if (phoneNumber != null) data['phoneNumber'] = phoneNumber;
      if (skills != null) data['skills'] = skills;
      if (interests != null) data['interests'] = interests;
      if (socialLinks != null) data['socialLinks'] = socialLinks;
      if (privacySettings != null) data['privacySettings'] = privacySettings;
      if (notificationSettings != null) data['notificationSettings'] = notificationSettings;

      if (data.isNotEmpty) {
        debugPrint('Updating Firestore profile for UID: $uid');
        
        // Use a batch or direct update to ensure nested maps are handled correctly
        final docRef = _firestore.collection('users').doc(uid);
        
        // If we have privacySettings, we want to update nested keys to avoid overwriting the whole map
        if (privacySettings != null) {
          final Map<String, dynamic> nestedData = {};
          privacySettings.forEach((k, v) => nestedData['privacySettings.$k'] = v);
          // Remove privacySettings from main data and use dot notation
          data.remove('privacySettings');
          await docRef.update(nestedData);
        }

        if (notificationSettings != null) {
           final Map<String, dynamic> nestedData = {};
           notificationSettings.forEach((k, v) => nestedData['notificationSettings.$k'] = v);
           data.remove('notificationSettings');
           await docRef.update(nestedData);
        }

        if (data.isNotEmpty) {
          await docRef.set(data, SetOptions(merge: true));
        }
        
        final currentUser = _firebaseAuth.currentUser;
        if (currentUser != null && fullName != null && currentUser.displayName != fullName) {
          debugPrint('Updating Firebase Auth displayName to: $fullName');
          await currentUser.updateDisplayName(fullName);
        }
      }
    } catch (e) {
      debugPrint('Firestore Update Profile Error: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateOnboardingStatus(String uid, bool completed) async {
    await _firestore.collection('users').doc(uid).update({
      'isOnboardingCompleted': completed,
    });
  }

  @override
  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      // 1. Delete user data from Firestore
      await _firestore.collection('users').doc(user.uid).delete();
      
      // 2. Delete the user from Firebase Auth
      await user.delete();
    }
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
    
    // 1. Add review doc
    final reviewRef = _firestore.collection('users').doc(targetUid).collection('reviews').doc();
    batch.set(reviewRef, {
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'rating': rating,
      'comment': comment,
      'listingId': listingId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // 2. Update target user stats
    final userRef = _firestore.collection('users').doc(targetUid);
    final userDoc = await userRef.get();
    final currentAvg = (userDoc.data()?['averageRating'] ?? 0.0).toDouble();
    final currentCount = (userDoc.data()?['ratingsCount'] ?? 0).toInt();
    
    final newCount = currentCount + 1;
    final newAvg = ((currentAvg * currentCount) + rating) / newCount;
    
    batch.update(userRef, {
      'averageRating': newAvg,
      'ratingsCount': newCount,
      // Increase trust score for getting a review
      'trustScore': FieldValue.increment(rating >= 4 ? 2.0 : -1.0),
    });

    await batch.commit();
  }

  Exception _handleAuthException(FirebaseAuthException e) {
    debugPrint('🛑 Auth Error Code: ${e.code}');
    switch (e.code) {
      case 'user-not-found': return Exception('No user found with this email.');
      case 'wrong-password': return Exception('Incorrect password.');
      case 'network-request-failed': return Exception('Network error: Please check your internet connection or DNS settings.');
      case 'too-many-requests': return Exception('Too many attempts. Please try again later.');
      default: return Exception(e.message ?? 'An unknown authentication error occurred.');
    }
  }
}
