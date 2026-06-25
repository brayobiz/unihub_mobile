import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/listing.dart';
import '../../shared/providers.dart';

import '../../domain/models/listing_filter.dart';

class MarketplaceController extends StateNotifier<ListingFilter> {
  MarketplaceController() : super(ListingFilter());

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query, itemsLimit: 20); // Reset limit on search
  }

  void setCategory(String? category) {
    state = state.copyWith(
      selectedCategory: () => category == 'All' ? null : category,
      itemsLimit: 20, // Reset limit on category change
    );
  }

  void toggleCondition(String condition) {
    final current = List<String>.from(state.selectedConditions);
    if (current.contains(condition)) {
      current.remove(condition);
    } else {
      current.add(condition);
    }
    state = state.copyWith(selectedConditions: current, itemsLimit: 20);
  }

  void setPriceRange(RangeValues range) {
    state = state.copyWith(priceRange: range, itemsLimit: 20);
  }

  void loadMore() {
    state = state.copyWith(itemsLimit: state.itemsLimit + 20);
  }
}

final marketplaceControllerProvider = 
    StateNotifierProvider<MarketplaceController, ListingFilter>((ref) {
  return MarketplaceController();
});

final scoredListingsProvider = Provider<AsyncValue<List<Listing>>>((ref) {
  final filter = ref.watch(marketplaceControllerProvider);
  final listingsAsync = ref.watch(listingsProvider(filter));
  final user = ref.watch(appUserProvider).valueOrNull;

  return listingsAsync.whenData((listings) {
    // 1. Refine filtering (for those that Firestore couldn't handle perfectly)
    final filtered = listings.where((l) {
      // If we have a search query, do a deep check (Firestore only did basic keyword match)
      final matchesSearch = filter.searchQuery.isEmpty || 
          l.title.toLowerCase().contains(filter.searchQuery.toLowerCase()) ||
          l.description.toLowerCase().contains(filter.searchQuery.toLowerCase());
      
      return matchesSearch;
    }).toList();

    // 2. Score & Sort
    filtered.sort((a, b) {
      double scoreA = _calculateScore(a, user?.university);
      double scoreB = _calculateScore(b, user?.university);
      return scoreB.compareTo(scoreA); // Higher score first
    });

    return filtered;
  });
});

double _calculateScore(Listing listing, String? userUniversity) {
  double score = 1.0;

  // Freshness boost (Exponential decay - simplified)
  final hoursOld = DateTime.now().difference(listing.createdAt).inHours;
  score += (100 / (hoursOld + 1));

  // Trust score boost
  score *= (listing.sellerTrustScore / 100);

  // Featured boost
  if (listing.isFeatured) score *= 3.0;

  // Proximity (University) boost
  if (userUniversity != null && listing.sellerUniversity == userUniversity) {
    score *= 1.5;
  }

  // Popularity boost
  score += (listing.viewsCount * 0.1) + (listing.savesCount * 0.5);

  return score;
}
