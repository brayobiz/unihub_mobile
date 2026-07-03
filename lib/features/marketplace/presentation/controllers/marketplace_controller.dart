import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/listing.dart';
import '../../domain/repositories/marketplace_repository.dart';
import '../../shared/providers.dart';
import '../../domain/models/listing_filter.dart';

class MarketplaceController extends StateNotifier<ListingFilter> {
  final Ref _ref;
  
  MarketplaceController(this._ref) : super(ListingFilter());

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    
    // Auto-save search if user is logged in
    final user = _ref.read(appUserProvider).valueOrNull;
    if (user != null && query.isNotEmpty) {
      _ref.read(marketplaceRepositoryProvider).saveSearchQuery(user.uid, query);
    }
  }
  
  Future<void> clearRecentSearches() async {
    final user = _ref.read(appUserProvider).valueOrNull;
    if (user != null) {
      await _ref.read(marketplaceRepositoryProvider).clearRecentSearches(user.uid);
    }
  }

  Future<void> clearRecentlyViewed() async {
    final user = _ref.read(appUserProvider).valueOrNull;
    if (user != null) {
      await _ref.read(marketplaceRepositoryProvider).clearRecentlyViewed(user.uid);
    }
  }

  void setCategory(String? category) {
    state = state.copyWith(
      selectedCategory: () => category == 'All' ? null : category,
    );
  }

  void toggleCondition(String condition) {
    final current = List<String>.from(state.selectedConditions);
    if (current.contains(condition)) {
      current.remove(condition);
    } else {
      current.add(condition);
    }
    state = state.copyWith(selectedConditions: current);
  }

  void setPriceRange(RangeValues range) {
    state = state.copyWith(priceRange: range);
  }

  void setSortBy(ListingSortType sortBy) {
    state = state.copyWith(sortBy: sortBy);
  }

  void setStatus(ListingStatus status) {
    state = state.copyWith(status: status);
  }

  void updateAttribute(String key, dynamic value) {
    final current = Map<String, dynamic>.from(state.categoryAttributes);
    if (value == null) {
      current.remove(key);
    } else {
      current[key] = value;
    }
    state = state.copyWith(categoryAttributes: current);
  }

  void applyFilter(ListingFilter filter) {
    state = filter;
  }

  void resetFilters() {
    state = ListingFilter();
  }
}

final marketplaceControllerProvider = 
    StateNotifierProvider<MarketplaceController, ListingFilter>((ref) {
  return MarketplaceController(ref);
});

final scoredListingsProvider = Provider<AsyncValue<List<Listing>>>((ref) {
  final filter = ref.watch(marketplaceControllerProvider);
  final listingsAsync = ref.watch(listingsProvider(filter));
  final user = ref.watch(appUserProvider).valueOrNull;

  if (user == null || user.blockedUids.isEmpty) return listingsAsync;

  return listingsAsync.whenData((listings) {
    return listings.where((l) => !user.blockedUids.contains(l.sellerId)).toList();
  });
});
