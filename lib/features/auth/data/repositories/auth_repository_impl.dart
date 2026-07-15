import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unihub_mobile/features/auth/domain/models/app_user.dart';
import 'package:unihub_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:unihub_mobile/core/utils/app_logger.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  
  // RC-Investigate: Explicitly providing the serverClientId (Web Client ID from google-services.json)
  // is required for Firebase to successfully exchange the Google ID token for a credential,
  // especially in release builds where the default client resolution may fail.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '709843516792-ih005los2kr2ne5c58gbfmb0elm2hjqa.apps.googleusercontent.com',
  );

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
      
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await _updateSearchFields(user.uid);
      }

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
        // Self-healing: Ensure search fields exist for the logged-in user
        await _updateSearchFields(user.uid);
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
          fullName: user.displayName ?? 'Ulify User',
          photoUrl: user.photoURL,
          createdAt: DateTime.now(),
          roles: ['student'], // Set explicitly for clarity
        );

        // Security Hardening: Strip restricted fields for initial creation
        final userData = appUser.toJson();
        userData.remove('roles');
        userData.remove('isAdmin');
        userData.remove('isBanned');
        userData.remove('suspendedUntil');
        userData.remove('isDeleted');
        userData.remove('identityStatus');
        userData.remove('studentStatus');
        userData.remove('isIdentityVerified');
        userData.remove('isStudentVerified');
        userData.remove('isEmailVerified');
        userData.remove('isPhoneVerified');
        
        await docRef.set(userData);
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

  Future<void> _updateSearchFields(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return;
      
      final data = doc.data() as Map<String, dynamic>;
      final fullName = data['fullName'] ?? '';
      final username = data['username'];
      
      final Map<String, dynamic> updates = {};
      if (data['fullNameLower'] == null && fullName.isNotEmpty) {
        updates['fullNameLower'] = fullName.toLowerCase();
      }
      if (data['usernameLower'] == null && username != null) {
        updates['usernameLower'] = username.toLowerCase();
      }
      
      if (updates.isNotEmpty) {
        await doc.reference.update(updates);
        AppLogger.info('Auth: Migrated search fields for user $uid', 'AUTH');
      }
    } catch (e) {
      AppLogger.warning('Auth: Failed to update search fields: $e', 'AUTH');
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
          roles: ['student'], // Set explicitly for clarity
        );

        // Security Hardening: Strip restricted fields before initial creation
        // The security rules prohibit sending sensitive flags during creation.
        // AppUser.toJson() includes these with defaults, so we remove them here.
        final userData = appUser.toJson();
        userData.remove('roles');
        userData.remove('isAdmin');
        userData.remove('isBanned');
        userData.remove('suspendedUntil');
        userData.remove('isDeleted');
        userData.remove('identityStatus');
        userData.remove('studentStatus');
        userData.remove('isIdentityVerified');
        userData.remove('isStudentVerified');
        userData.remove('isEmailVerified');
        userData.remove('isPhoneVerified');

        await _firestore.collection('users').doc(appUser.uid).set(userData);
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
      if (fullName != null) {
        data['fullName'] = fullName;
        data['fullNameLower'] = fullName.toLowerCase();
      }
      if (username != null) {
        data['username'] = username;
        data['usernameLower'] = username.toLowerCase();
      }
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

      // Self-healing: If the document doesn't exist, ensure email and createdAt are set
      final doc = await docRef.get();
      if (!doc.exists) {
        final currentUser = _firebaseAuth.currentUser;
        if (currentUser != null) {
          data['email'] = currentUser.email ?? '';
          data['createdAt'] = FieldValue.serverTimestamp();
        }
      }

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
  Future<void> checkAndRestoreRestrictedContent(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) return;
      
      final data = userDoc.data() as Map<String, dynamic>;
      final isBanned = data['isBanned'] == true;
      final suspendedUntil = (data['suspendedUntil'] as Timestamp?)?.toDate();
      final isCurrentlySuspended = suspendedUntil != null && suspendedUntil.isAfter(DateTime.now());

      if (!isBanned && !isCurrentlySuspended && (suspendedUntil != null || data['isDeleted'] == true)) {
        AppLogger.info('Self-Healing: User $uid restriction expired. Restoring content...', 'AUTH');
        
        final batch = _firestore.batch();
        
        // 1. Clean up user doc flags
        batch.update(userDoc.reference, {
          'suspendedUntil': FieldValue.delete(),
          'isDeleted': false, // Self-heal if they managed to log in
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 2. Restore Marketplace
        final listings = await _firestore.collection('listings')
            .where('sellerId', isEqualTo: uid)
            .where('status', isEqualTo: 'userSuspended')
            .get();
        
        for (var doc in listings.docs) {
          batch.update(doc.reference, {
            'status': doc.data()['originalStatus'] ?? 'active',
            'originalStatus': FieldValue.delete(),
          });
        }

        // 3. Restore Housing
        final housing = await _firestore.collection('housing_listings')
            .where('plugId', isEqualTo: uid)
            .where('status', isEqualTo: 'userSuspended')
            .get();
            
        for (var doc in housing.docs) {
          batch.update(doc.reference, {
            'status': doc.data()['originalStatus'] ?? 'available',
            'originalStatus': FieldValue.delete(),
          });
        }

        await batch.commit();
        AppLogger.info('Self-Healing: Restoration complete for $uid', 'AUTH');
      }
    } catch (e) {
      AppLogger.warning('Self-Healing: Failed to check/restore content: $e', 'AUTH');
    }
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

      // 1. Proceed with Firestore cleanup while STILL authenticated
      // This is critical because client-side deletion requires active auth session.
      await _performCleanup(uid);
      
      // 2. Delete Auth user last
      // If this fails with 'requires-recent-login', the data is already gone,
      // and the user must sign in again to finalize the deletion of their Auth record.
      await user.delete();
      AppLogger.info('Auth: Firebase Auth user deleted successfully', 'AUTH');
      
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        AppLogger.warning('Auth: Delete account failed: Requires recent login', 'AUTH');
        throw Exception('This operation is sensitive and requires recent authentication. Please sign in again to complete the deletion.');
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
      // 0. Reset local device onboarding so the next user starts fresh
      // This helps with the "brand new user" requirement
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('device_onboarding_completed');
      } catch (e) {
        AppLogger.warning('Cleanup: Failed to reset local onboarding flag: $e');
      }

      // We process collections sequentially to avoid massive memory spikes
      // Audited list of all user-related content across the platform
      final collections = [
        'listings', 'housing_listings', 'notes', 'feed', 'gigs', 'gig_applications', 
        'gig_disputes', 'verification_applications', 'student_verifications', 
        'identity_verifications', 'events', 'organizers', 'offers', 'reports',
        'housing_reports', 'housing_vacancy_requests', 'housing_saved_searches',
        'housing_viewing_requests', 'event_attendance', 'payments', 'subscriptions',
        'roommates'
      ];

      for (var coll in collections) {
        String queryField = 'authorId';
        if (coll == 'listings') queryField = 'sellerId';
        if (coll == 'housing_listings') queryField = 'plugId';
        if (coll == 'gig_applications') queryField = 'freelancerId';
        if (coll == 'verification_applications') queryField = 'userId';
        if (coll == 'events') queryField = 'createdBy';
        if (coll == 'organizers') queryField = 'ownerId';
        if (coll == 'gigs') queryField = 'employerId';
        if (coll == 'gig_disputes') queryField = 'reporterId';
        if (coll == 'offers') queryField = 'buyerId'; 
        if (coll == 'reports' || coll == 'housing_reports') queryField = 'reporterId';
        if (coll == 'housing_vacancy_requests') queryField = 'userId';
        if (coll == 'housing_saved_searches') queryField = 'userId';
        if (coll == 'housing_viewing_requests') queryField = 'studentId';
        if (coll == 'event_attendance') queryField = 'userId';
        if (coll == 'payments') queryField = 'userId';
        if (coll == 'roommates') queryField = 'userId';
        
        if (coll == 'student_verifications' || coll == 'identity_verifications' || coll == 'subscriptions') {
          await _firestore.collection(coll).doc(uid).delete().catchError((_) => null);
          continue;
        }

        final snapshots = await _firestore.collection(coll)
            .where(queryField, isEqualTo: uid)
            .limit(100) 
            .get();

        if (snapshots.docs.isNotEmpty) {
          final batch = _firestore.batch();
          for (var doc in snapshots.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit().catchError((_) => null);
        }
      }

      // Delete user subcollections and the user document itself
      final subcollections = [
        'notifications', 'tokens', 'saved_listings', 'saved_housing', 
        'saved_searches', 'recent_searches', 'followed_organizers',
        'saved_events', 'saved_notes', 'study_progress', 'collections', 'reviews'
      ];
      for (var sub in subcollections) {
        final snap = await _firestore.collection('users').doc(uid).collection(sub).limit(100).get();
        if (snap.docs.isNotEmpty) {
          final batch = _firestore.batch();
          for (var doc in snap.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit().catchError((_) => null);
        }
      }

      // Explicitly check for organizer memberships (where user ID is in document ID)
      // This is harder to query, so we rely on the Cloud Function for deep cleanup
      // but we try to delete the primary user doc last.
      await _firestore.collection('users').doc(uid).delete().catchError((_) => null);

      AppLogger.info('Auth: Best-effort Firestore cleanup completed for $uid', 'AUTH');
    } catch (e) {
      AppLogger.warning('Auth: Firestore cleanup encountered errors: $e', 'AUTH');
    }
  }

  @override
  Future<List<AppUser>> searchUsers(String query) async {
    try {
      if (query.isEmpty) return [];
      final q = query.toLowerCase().trim();
      
      // Perform multiple searches to avoid complex composite index requirements
      // and merge results in-memory. This makes searching highly resilient.
      final results = await Future.wait([
        _firestore.collection('users')
            .where('fullNameLower', isGreaterThanOrEqualTo: q)
            .where('fullNameLower', isLessThanOrEqualTo: '$q\uf8ff')
            .limit(10)
            .get(),
        _firestore.collection('users')
            .where('usernameLower', isGreaterThanOrEqualTo: q)
            .where('usernameLower', isLessThanOrEqualTo: '$q\uf8ff')
            .limit(10)
            .get(),
        _firestore.collection('users')
            .where('email', isGreaterThanOrEqualTo: q)
            .where('email', isLessThanOrEqualTo: '$q\uf8ff')
            .limit(10)
            .get(),
      ]);
      
      final Map<String, AppUser> uniqueUsers = {};
      for (var snap in results) {
        for (var doc in snap.docs) {
          final data = doc.data();
          // Filter out deleted or banned users from search results
          if (data['isDeleted'] == true || data['isBanned'] == true) continue;
          
          final user = AppUser.fromJson(data);
          // Security: strip sensitive PII from search results before they reach UI
          uniqueUsers[user.uid] = user.stripSensitiveInfo();
        }
      }
      
      return uniqueUsers.values.toList();
    } catch (e) {
      AppLogger.error('Auth: Error searching users', e, null, 'AUTH');
      return [];
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

