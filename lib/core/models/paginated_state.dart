import 'package:flutter_riverpod/flutter_riverpod.dart';

class PaginatedState<T> {
  final List<T> items;
  final bool isLoading;
  final bool isFetchingMore;
  final bool hasMore;
  final dynamic lastCursor; // Usually Listing, HousingListing, or DocumentSnapshot
  final Object? error;

  PaginatedState({
    required this.items,
    this.isLoading = false,
    this.isFetchingMore = false,
    this.hasMore = true,
    this.lastCursor,
    this.error,
  });

  PaginatedState<T> copyWith({
    List<T>? items,
    bool? isLoading,
    bool? isFetchingMore,
    bool? hasMore,
    dynamic lastCursor,
    Object? error,
  }) {
    return PaginatedState<T>(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isFetchingMore: isFetchingMore ?? this.isFetchingMore,
      hasMore: hasMore ?? this.hasMore,
      lastCursor: lastCursor ?? this.lastCursor,
      error: error,
    );
  }

  bool get hasError => error != null;
}
