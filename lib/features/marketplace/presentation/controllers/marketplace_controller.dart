import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/listing.dart';
import '../../domain/repositories/marketplace_repository.dart';
import '../../shared/providers.dart';

import '../../domain/models/listing_filter.dart';

class MarketplaceController extends StateNotifier<ListingFilter> {
  MarketplaceController() : super(ListingFilter());

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
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

  void resetFilters() {
    state = ListingFilter();
  }
}

final marketplaceControllerProvider = 
    StateNotifierProvider<MarketplaceController, ListingFilter>((ref) {
  return MarketplaceController();
});

final scoredListingsProvider = Provider<AsyncValue<List<Listing>>>((ref) {
  final filter = ref.watch(marketplaceControllerProvider);
  return ref.watch(listingsProvider(filter));
});
