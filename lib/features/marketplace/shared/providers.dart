import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/shared/providers.dart';
import 'package:unihub_mobile/features/auth/domain/models/app_user.dart';
import '../data/repositories/marketplace_repository_impl.dart';
import '../domain/models/listing.dart';
import '../domain/repositories/marketplace_repository.dart';
import '../../../../services/notification_service.dart';

import '../domain/models/listing_filter.dart';

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  return MarketplaceRepositoryImpl(
    ref.watch(firestoreProvider),
    ref.watch(notificationServiceProvider),
  );
});

final listingsProvider = StreamProvider.family<List<Listing>, ListingFilter>((ref, filter) {
  final repo = ref.watch(marketplaceRepositoryProvider);

  return repo.watchListings(
    limit: filter.itemsLimit,
    category: filter.selectedCategory,
    conditions: filter.selectedConditions,
    minPrice: filter.priceRange?.start,
    maxPrice: filter.priceRange?.end,
    isFeatured: filter.isFeaturedOnly,
    searchQuery: filter.searchQuery,
    sortBy: filter.sortBy,
    status: filter.status,
  );
});

final recentlyViewedProvider = StreamProvider<List<Listing>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(marketplaceRepositoryProvider).watchRecentlyViewed(user.uid);
});

final trendingListingsProvider = StreamProvider.family<List<Listing>, String?>((ref, university) {
  return ref.watch(marketplaceRepositoryProvider).watchTrendingListings(university: university);
});

final recommendedListingsProvider = StreamProvider<List<Listing>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  // If no user, show general trending
  if (user == null) {
    return ref.watch(marketplaceRepositoryProvider).watchTrendingListings();
  }
  return ref.watch(marketplaceRepositoryProvider).watchRecommendedListings(user.uid);
});

final collectionNamesProvider = StreamProvider<List<String>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(marketplaceRepositoryProvider).watchCollectionNames(user.uid);
});

final collectionListingsProvider = StreamProvider.family<List<Listing>, String>((ref, collectionName) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(marketplaceRepositoryProvider).watchCollectionListings(user.uid, collectionName);
});

final recentSearchesProvider = StreamProvider<List<String>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(marketplaceRepositoryProvider).watchRecentSearches(user.uid);
});

final sellerListingsProvider = StreamProvider.family<List<Listing>, String>((ref, sellerId) {
  return ref.watch(marketplaceRepositoryProvider).watchSellerListings(sellerId);
});

final topListingsProvider = StreamProvider<List<Listing>>((ref) {
  return ref.watch(listingsProvider(ListingFilter()).stream);
});

final savedListingsProvider = StreamProvider<List<Listing>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(marketplaceRepositoryProvider).watchSavedListings(user.uid);
});

final sellerReviewsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, sellerId) {
  if (sellerId.isEmpty) return Stream.value([]);
  
  return FirebaseFirestore.instance
      .collection('users')
      .doc(sellerId)
      .collection('reviews')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
});

final similarListingsProvider = StreamProvider.family<List<Listing>, Listing>((ref, currentListing) {
  return ref.watch(marketplaceRepositoryProvider).watchSimilarListings(currentListing);
});

final otherUserProvider = StreamProvider.family<AppUser, String>((ref, userId) {
  if (userId.isEmpty) {
    return Stream.error('Invalid User ID');
  }

  // Watch current user but don't fail if null
  final currentUser = ref.watch(appUserProvider).valueOrNull;

  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((doc) {
        if (!doc.exists) {
          throw Exception('User not found');
        }
        
        final data = doc.data();
        if (data == null) {
          throw Exception('User data is empty');
        }

        final targetUser = AppUser.fromJson(data);
        
        // --- REAL-TIME PRIVACY LOGIC ---
        final Map<String, String> privacy = {};
        targetUser.privacySettings.forEach((k, v) => privacy[k] = v.toString());
        
        final visibility = privacy['profile_visibility'] ?? 'university';
        final showUni = privacy['show_university'] != 'private';
        final showSocials = privacy['show_socials'] != 'private';

        final String? currentUni = currentUser?.university;
        final String? targetUni = targetUser.university;

        bool isSameUni = currentUni != null && 
                         targetUni != null && 
                         currentUni.isNotEmpty &&
                         targetUni.isNotEmpty &&
                         currentUni == targetUni;

        bool isOwner = currentUser?.uid == targetUser.uid;
        bool canViewDetails = visibility == 'public' || (visibility == 'university' && isSameUni) || isOwner;
        
        if (visibility == 'private' && !isOwner) {
          return AppUser(
            uid: targetUser.uid,
            email: 'hidden@unihub.student',
            fullName: targetUser.fullName,
            photoUrl: targetUser.photoUrl,
            trustScore: targetUser.trustScore,
            averageRating: targetUser.averageRating,
            ratingsCount: targetUser.ratingsCount,
            university: 'Private Profile',
            course: 'Student',
            isOnboardingCompleted: true,
          );
        }

        if (!canViewDetails) {
           return targetUser.copyWith(
             email: 'hidden@unihub.student',
             bio: 'This profile is set to University-only visibility.',
             course: 'Student',
             phoneNumber: null,
             whatsappNumber: null,
             socialLinks: const <String, String>{},
             university: showUni ? targetUni : 'Hidden Campus',
           );
        }

        // Apply secondary flags
        return targetUser.copyWith(
          university: (showUni || isSameUni || isOwner) 
              ? targetUni 
              : 'Hidden Campus',
          socialLinks: (showSocials || isSameUni || isOwner)
              ? targetUser.socialLinks
              : const <String, String>{},
        );
      });
});
