import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../repositories/marketplace_repository.dart';
import 'listing.dart';

class ListingFilter {
  final String searchQuery;
  final String? selectedCategory;
  final List<String> selectedConditions;
  final RangeValues? priceRange;
  final bool isFeaturedOnly;
  final int itemsLimit;
  final ListingSortType sortBy;
  final ListingStatus status;
  final String? university;

  ListingFilter({
    this.searchQuery = '',
    this.selectedCategory,
    this.selectedConditions = const [],
    this.priceRange,
    this.isFeaturedOnly = false,
    this.itemsLimit = 50,
    ListingSortType? sortBy,
    ListingStatus? status,
    this.university,
  })  : sortBy = sortBy ?? ListingSortType.newest,
        status = status ?? ListingStatus.active;

  ListingFilter copyWith({
    String? searchQuery,
    ValueGetter<String?>? selectedCategory,
    List<String>? selectedConditions,
    RangeValues? priceRange,
    bool? isFeaturedOnly,
    int? itemsLimit,
    ListingSortType? sortBy,
    ListingStatus? status,
    ValueGetter<String?>? university,
  }) {
    return ListingFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory != null ? selectedCategory() : this.selectedCategory,
      selectedConditions: selectedConditions ?? this.selectedConditions,
      priceRange: priceRange ?? this.priceRange,
      isFeaturedOnly: isFeaturedOnly ?? this.isFeaturedOnly,
      itemsLimit: itemsLimit ?? this.itemsLimit,
      sortBy: sortBy ?? this.sortBy,
      status: status ?? this.status,
      university: university != null ? university() : this.university,
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
          itemsLimit == other.itemsLimit &&
          sortBy == other.sortBy &&
          status == other.status &&
          university == other.university;

  @override
  int get hashCode => Object.hash(
        searchQuery,
        selectedCategory,
        Object.hashAll(selectedConditions),
        priceRange,
        isFeaturedOnly,
        itemsLimit,
        sortBy,
        status,
        university,
      );
}
