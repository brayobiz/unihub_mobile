import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ListingFilter {
  final String searchQuery;
  final String? selectedCategory;
  final List<String> selectedConditions;
  final RangeValues? priceRange;
  final bool isFeaturedOnly;
  final int itemsLimit;

  ListingFilter({
    this.searchQuery = '',
    this.selectedCategory,
    this.selectedConditions = const [],
    this.priceRange,
    this.isFeaturedOnly = false,
    this.itemsLimit = 20,
  });

  ListingFilter copyWith({
    String? searchQuery,
    String? Function()? selectedCategory,
    List<String>? selectedConditions,
    RangeValues? priceRange,
    bool? isFeaturedOnly,
    int? itemsLimit,
  }) {
    return ListingFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory != null ? selectedCategory() : this.selectedCategory,
      selectedConditions: selectedConditions ?? this.selectedConditions,
      priceRange: priceRange ?? this.priceRange,
      isFeaturedOnly: isFeaturedOnly ?? this.isFeaturedOnly,
      itemsLimit: itemsLimit ?? this.itemsLimit,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListingFilter &&
          runtimeType == other.runtimeType &&
          searchQuery == other.searchQuery &&
          selectedCategory == other.selectedCategory &&
          listEquals(selectedConditions, other.selectedConditions) &&
          priceRange == other.priceRange &&
          isFeaturedOnly == other.isFeaturedOnly &&
          itemsLimit == other.itemsLimit;

  @override
  int get hashCode =>
      searchQuery.hashCode ^
      selectedCategory.hashCode ^
      Object.hashAll(selectedConditions) ^
      priceRange.hashCode ^
      isFeaturedOnly.hashCode ^
      itemsLimit.hashCode;
}
