import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/paginated_state.dart';
import '../../domain/models/listing.dart';
import '../../domain/models/listing_filter.dart';
import '../../shared/providers.dart';

class PaginatedListingsController extends StateNotifier<PaginatedState<Listing>> {
  final Ref _ref;
  final ListingFilter _filter;
  StreamSubscription? _subscription;
  static const int _pageSize = 20;

  PaginatedListingsController(this._ref, this._filter) : super(PaginatedState(items: [])) {
    _init();
  }

  void _init() {
    _subscription?.cancel();
    state = state.copyWith(isLoading: true, error: null);
    
    // We only use stream for the FIRST page to keep it fresh
    _subscription = _ref.read(marketplaceRepositoryProvider).watchListings(
      limit: _pageSize,
      category: _filter.selectedCategory,
      conditions: _filter.selectedConditions,
      minPrice: _filter.priceRange?.start,
      maxPrice: _filter.priceRange?.end,
      searchQuery: _filter.searchQuery,
      sortBy: _filter.sortBy,
      status: _filter.status,
      categoryAttributes: _filter.categoryAttributes,
    ).listen((items) {
      if (mounted) {
        // Only update if we are on the first page or it's the initial load
        if (state.items.length <= _pageSize) {
          state = state.copyWith(
            items: items,
            isLoading: false,
            hasMore: items.length >= _pageSize,
            lastCursor: items.isNotEmpty ? items.last : null,
            error: null,
          );
        }
      }
    }, onError: (err) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: err);
      }
    });
  }

  void retry() {
    if (state.items.isEmpty) {
      _init();
    } else {
      fetchMore();
    }
  }

  Future<void> fetchMore() async {
    if (state.isFetchingMore || !state.hasMore || state.lastCursor == null) return;

    state = state.copyWith(isFetchingMore: true);
    try {
      final newItems = await _ref.read(marketplaceRepositoryProvider).getListings(
        limit: _pageSize,
        startAfter: state.lastCursor as Listing,
        category: _filter.selectedCategory,
        conditions: _filter.selectedConditions,
        minPrice: _filter.priceRange?.start,
        maxPrice: _filter.priceRange?.end,
        searchQuery: _filter.searchQuery,
        sortBy: _filter.sortBy,
        status: _filter.status,
        categoryAttributes: _filter.categoryAttributes,
      );
      
      if (mounted) {
        // Avoid adding duplicates if the stream also pushed an item
        final existingIds = state.items.map((i) => i.id).toSet();
        final uniqueNewItems = newItems.where((i) => !existingIds.contains(i.id)).toList();

        state = state.copyWith(
          items: [...state.items, ...uniqueNewItems],
          isFetchingMore: false,
          hasMore: newItems.length >= _pageSize,
          lastCursor: newItems.isNotEmpty ? newItems.last : state.lastCursor,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isFetchingMore: false, error: e);
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final paginatedListingsProvider = StateNotifierProvider.family<PaginatedListingsController, PaginatedState<Listing>, ListingFilter>((ref, filter) {
  return PaginatedListingsController(ref, filter);
});
