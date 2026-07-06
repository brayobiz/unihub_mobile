import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/shared/providers.dart';
import 'package:unihub_mobile/features/auth/domain/models/app_user.dart';
import '../data/repositories/marketplace_repository_impl.dart';
import '../domain/models/listing.dart';
import '../domain/repositories/marketplace_repository.dart';
import 'package:unihub_mobile/services/notification_service.dart';
import 'package:unihub_mobile/features/shared/notification_repository.dart';
import '../domain/models/listing_filter.dart';
import '../../campus_filter/shared/providers.dart';

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  final campus = ref.watch(effectiveCampusFilterProvider);
  return MarketplaceRepositoryImpl(
    ref.watch(firestoreProvider),
    campus,
    ref.watch(notificationServiceProvider),
    ref.watch(userActivityRepositoryProvider),
  );
});

final listingsProvider = StreamProvider.autoDispose.family<List<Listing>, ListingFilter>((ref, filter) {
  final repo = ref.watch(marketplaceRepositoryProvider);
  final user = ref.watch(appUserProvider).valueOrNull;

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
    categoryAttributes: filter.categoryAttributes,
  ).map((listings) {
    if (user == null || user.blockedUids.isEmpty) return listings;
    return listings.where((l) => !user.blockedUids.contains(l.sellerId)).toList();
  });
});

final recentlyViewedProvider = StreamProvider.autoDispose<List<Listing>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(marketplaceRepositoryProvider).watchRecentlyViewed(user.uid);
});

final trendingListingsProvider = StreamProvider.autoDispose<List<Listing>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  return ref.watch(marketplaceRepositoryProvider).watchTrendingListings().map((listings) {
    if (user == null || user.blockedUids.isEmpty) return listings;
    return listings.where((l) => !user.blockedUids.contains(l.sellerId)).toList();
  });
});

final recommendedListingsProvider = StreamProvider.autoDispose<List<Listing>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) {
    return ref.watch(marketplaceRepositoryProvider).watchTrendingListings();
  }
  
  return ref.watch(marketplaceRepositoryProvider).watchRecommendedListings(user.uid).map((listings) {
    if (user.blockedUids.isEmpty) return listings;
    return listings.where((l) => !user.blockedUids.contains(l.sellerId)).toList();
  });
});

final collectionNamesProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(marketplaceRepositoryProvider).watchCollectionNames(user.uid);
});

final collectionListingsProvider = StreamProvider.autoDispose.family<List<Listing>, String>((ref, collectionName) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(marketplaceRepositoryProvider).watchCollectionListings(user.uid, collectionName);
});

final recentSearchesProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(marketplaceRepositoryProvider).watchRecentSearches(user.uid);
});

final sellerListingsProvider = StreamProvider.autoDispose.family<List<Listing>, String>((ref, sellerId) {
  return ref.watch(marketplaceRepositoryProvider).watchSellerListings(sellerId);
});

final listingProvider = StreamProvider.autoDispose.family<Listing?, String>((ref, id) {
  return ref.watch(marketplaceRepositoryProvider).watchListingById(id);
});

final topListingsProvider = StreamProvider.autoDispose<List<Listing>>((ref) {
  return ref.watch(listingsProvider(ListingFilter()).stream);
});

final savedListingsProvider = StreamProvider.autoDispose<List<Listing>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(marketplaceRepositoryProvider).watchSavedListings(user.uid);
});

final sellerReviewsProvider = StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, sellerId) {
  if (sellerId.isEmpty) return Stream.value([]);
  
  return ref.watch(firestoreProvider)
      .collection('users')
      .doc(sellerId)
      .collection('reviews')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
});

final similarListingsProvider = StreamProvider.autoDispose.family<List<Listing>, Listing>((ref, currentListing) {
  return ref.watch(marketplaceRepositoryProvider).watchSimilarListings(currentListing);
});

final moreFromSellerProvider = StreamProvider.autoDispose.family<List<Listing>, String>((ref, sellerId) {
  return ref.watch(marketplaceRepositoryProvider).watchSellerListingsByStatus(sellerId, ListingStatus.active);
});

final otherUserProvider = StreamProvider.autoDispose.family<AppUser, String>((ref, userId) {
  if (userId.isEmpty) return Stream.error('Invalid User ID');

  final currentUser = ref.watch(appUserProvider).valueOrNull;
  final firestore = ref.watch(firestoreProvider);

  return firestore
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((doc) {
        if (!doc.exists) throw Exception('User not found');
        
        final data = doc.data();
        if (data == null) throw Exception('User data is empty');

        final targetUser = AppUser.fromJson(data);
        
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
          return targetUser.stripSensitiveInfo().copyWith(
            university: 'Private Profile',
            course: 'Student',
          );
        }

        if (!canViewDetails) {
           return targetUser.stripSensitiveInfo().copyWith(
             bio: 'This profile is set to University-only visibility.',
             course: 'Student',
             university: showUni ? targetUni : 'Hidden Campus',
           );
        }

        // Apply secondary flags
        return targetUser.stripSensitiveInfo().copyWith(
          university: (showUni || isSameUni || isOwner) ? targetUni : 'Hidden Campus',
          socialLinks: (showSocials || isSameUni || isOwner)
              ? targetUser.socialLinks
              : const <String, String>{},
          // Keep some public fields if it's the owner
          email: isOwner ? targetUser.email : 'hidden@unihub.student',
          phoneNumber: isOwner ? targetUser.phoneNumber : null,
          whatsappNumber: isOwner ? targetUser.whatsappNumber : null,
        );
      });
});
