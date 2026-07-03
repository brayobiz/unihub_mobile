import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/shared/providers.dart';
import 'package:unihub_mobile/features/auth/domain/models/app_user.dart';
import '../data/repositories/marketplace_repository_impl.dart';
import '../domain/models/listing.dart';
import '../domain/repositories/marketplace_repository.dart';
import '../../../../services/notification_service.dart';
import '../domain/models/listing_filter.dart';
import '../../campus_filter/shared/providers.dart';

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  final campus = ref.watch(effectiveCampusFilterProvider);
  return MarketplaceRepositoryImpl(
    ref.watch(firestoreProvider),
    campus,
    ref.watch(notificationServiceProvider),
  );
});

final listingsProvider = StreamProvider.family<List<Listing>, ListingFilter>((ref, filter) {
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

final recentlyViewedProvider = StreamProvider<List<Listing>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(marketplaceRepositoryProvider).watchRecentlyViewed(user.uid);
});

final trendingListingsProvider = StreamProvider<List<Listing>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  return ref.watch(marketplaceRepositoryProvider).watchTrendingListings().map((listings) {
    if (user == null || user.blockedUids.isEmpty) return listings;
    return listings.where((l) => !user.blockedUids.contains(l.sellerId)).toList();
  });
});

final recommendedListingsProvider = StreamProvider<List<Listing>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) {
    return ref.watch(marketplaceRepositoryProvider).watchTrendingListings();
  }
  
  return ref.watch(marketplaceRepositoryProvider).watchRecommendedListings(user.uid).map((listings) {
    if (user.blockedUids.isEmpty) return listings;
    return listings.where((l) => !user.blockedUids.contains(l.sellerId)).toList();
  });
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

final listingProvider = StreamProvider.family<Listing?, String>((ref, id) {
  return ref.watch(marketplaceRepositoryProvider).watchListingById(id);
});

final topListingsProvider = StreamProvider<List<Listing>>((ref) {
  return ref.watch(listingsProvider(ListingFilter()).stream);
});

final savedListingsProvider = StreamProvider<List<Listing>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(marketplaceRepositoryProvider).watchSavedListings(user.uid);
});

class MarketplaceDiscoveryData {
  final List<Listing> recentlyViewed;
  final List<Listing> recommended;
  final List<Listing> trending;
  final List<Listing> recentlyPosted;
  final List<Listing> mostSaved;
  final List<Listing> popular;

  MarketplaceDiscoveryData({
    required this.recentlyViewed,
    required this.recommended,
    required this.trending,
    required this.recentlyPosted,
    required this.mostSaved,
    required this.popular,
  });
}

final marketplaceDiscoveryProvider = Provider<AsyncValue<MarketplaceDiscoveryData>>((ref) {
  final recentlyViewedAsync = ref.watch(recentlyViewedProvider);
  final recommendedAsync = ref.watch(recommendedListingsProvider);
  final trendingAsync = ref.watch(trendingListingsProvider);
  
  final recentlyPostedAsync = ref.watch(listingsProvider(ListingFilter(sortBy: ListingSortType.newest, itemsLimit: 10)));
  final mostSavedAsync = ref.watch(listingsProvider(ListingFilter(sortBy: ListingSortType.mostSaved, itemsLimit: 10)));
  final popularAsync = ref.watch(listingsProvider(ListingFilter(sortBy: ListingSortType.mostViewed, itemsLimit: 10)));

  if (recentlyViewedAsync.isLoading || recommendedAsync.isLoading || trendingAsync.isLoading || 
      recentlyPostedAsync.isLoading || mostSavedAsync.isLoading || popularAsync.isLoading) {
    return const AsyncValue.loading();
  }

  if (recentlyViewedAsync.hasError) return AsyncValue.error(recentlyViewedAsync.error!, recentlyViewedAsync.stackTrace!);
  if (recommendedAsync.hasError) return AsyncValue.error(recommendedAsync.error!, recommendedAsync.stackTrace!);
  if (trendingAsync.hasError) return AsyncValue.error(trendingAsync.error!, trendingAsync.stackTrace!);
  if (recentlyPostedAsync.hasError) return AsyncValue.error(recentlyPostedAsync.error!, recentlyPostedAsync.stackTrace!);
  if (mostSavedAsync.hasError) return AsyncValue.error(mostSavedAsync.error!, mostSavedAsync.stackTrace!);
  if (popularAsync.hasError) return AsyncValue.error(popularAsync.error!, popularAsync.stackTrace!);

  final seenIds = <String>{};
  
  final recentlyViewed = (recentlyViewedAsync.value ?? []).where((l) => seenIds.add(l.id)).toList();
  final recommended = (recommendedAsync.value ?? []).where((l) => seenIds.add(l.id)).toList();
  final recentlyPosted = (recentlyPostedAsync.value ?? []).where((l) => seenIds.add(l.id)).toList();
  final mostSaved = (mostSavedAsync.value ?? []).where((l) => seenIds.add(l.id)).toList();
  final popular = (popularAsync.value ?? []).where((l) => seenIds.add(l.id)).toList();
  final trending = (trendingAsync.value ?? []).where((l) => seenIds.add(l.id)).toList();

  return AsyncValue.data(MarketplaceDiscoveryData(
    recentlyViewed: recentlyViewed,
    recommended: recommended,
    trending: trending,
    recentlyPosted: recentlyPosted,
    mostSaved: mostSaved,
    popular: popular,
  ));
});

final sellerReviewsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, sellerId) {
  if (sellerId.isEmpty) return Stream.value([]);
  
  return ref.watch(firestoreProvider)
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

final moreFromSellerProvider = StreamProvider.family<List<Listing>, String>((ref, sellerId) {
  return ref.watch(marketplaceRepositoryProvider).watchSellerListingsByStatus(sellerId, ListingStatus.active);
});

final otherUserProvider = StreamProvider.family<AppUser, String>((ref, userId) {
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
