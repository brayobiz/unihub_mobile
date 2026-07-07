import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/paginated_state.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/housing_listing.dart';
import '../../domain/repositories/housing_repository.dart';
import '../../shared/providers.dart';

class HousingFilterState {
  final String? universityId;
  final String? location;
  final HousingType? type;
  final double? minRent;
  final double? maxRent;
  final GenderRestriction? genderRestriction;
  final bool? isFurnished;
  final HousingSortBy sortBy;

  HousingFilterState({
    this.universityId,
    this.location,
    this.type,
    this.minRent,
    this.maxRent,
    this.genderRestriction,
    this.isFurnished,
    this.sortBy = HousingSortBy.newest,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HousingFilterState &&
          runtimeType == other.runtimeType &&
          universityId == other.universityId &&
          location == other.location &&
          type == other.type &&
          minRent == other.minRent &&
          maxRent == other.maxRent &&
          genderRestriction == other.genderRestriction &&
          isFurnished == other.isFurnished &&
          sortBy == other.sortBy;

  @override
  int get hashCode =>
      universityId.hashCode ^
      location.hashCode ^
      type.hashCode ^
      minRent.hashCode ^
      maxRent.hashCode ^
      genderRestriction.hashCode ^
      isFurnished.hashCode ^
      sortBy.hashCode;
}

class PaginatedHousingController extends StateNotifier<PaginatedState<HousingListing>> {
  final Ref _ref;
  final HousingFilterState _filter;
  StreamSubscription? _subscription;
  static const int _pageSize = 20;

  PaginatedHousingController(this._ref, this._filter) : super(PaginatedState(items: [])) {
    _init();
  }

  List<HousingListing> _filterBlocked(List<HousingListing> items) {
    final user = _ref.read(appUserProvider).valueOrNull;
    if (user == null || user.blockedUids.isEmpty) return items;
    return items.where((l) => !user.blockedUids.contains(l.plugId)).toList();
  }

  void _init() {
    _subscription?.cancel();
    state = state.copyWith(isLoading: true, error: null);
    
    // We only use stream for the FIRST page to keep it fresh
    _subscription = _ref.read(housingRepositoryProvider).watchListings(
      limit: _pageSize,
      universityId: _filter.universityId,
      location: _filter.location,
      type: _filter.type,
      minRent: _filter.minRent,
      maxRent: _filter.maxRent,
      genderRestriction: _filter.genderRestriction,
      isFurnished: _filter.isFurnished,
      sortBy: _filter.sortBy,
    ).listen((items) {
      if (mounted) {
        final filteredItems = _filterBlocked(items);
        // Only update if we are on the first page or it's the initial load
        if (state.items.length <= _pageSize) {
          state = state.copyWith(
            items: filteredItems,
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
      final newItems = await _ref.read(housingRepositoryProvider).fetchListings(
        limit: _pageSize,
        startAfter: state.lastCursor as HousingListing,
        universityId: _filter.universityId,
        location: _filter.location,
        type: _filter.type,
        minRent: _filter.minRent,
        maxRent: _filter.maxRent,
        genderRestriction: _filter.genderRestriction,
        isFurnished: _filter.isFurnished,
        sortBy: _filter.sortBy,
      );
      
      if (mounted) {
        final filteredNewItems = _filterBlocked(newItems);
        // Avoid adding duplicates if the stream also pushed an item
        final existingIds = state.items.map((i) => i.id).toSet();
        final uniqueNewItems = filteredNewItems.where((i) => !existingIds.contains(i.id)).toList();

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

final paginatedHousingProvider = StateNotifierProvider.family<PaginatedHousingController, PaginatedState<HousingListing>, HousingFilterState>((ref, filter) {
  return PaginatedHousingController(ref, filter);
});
