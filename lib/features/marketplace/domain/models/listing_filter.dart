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
  final Map<String, dynamic> categoryAttributes;

  ListingFilter({
    this.searchQuery = '',
    this.selectedCategory,
    this.selectedConditions = const [],
    this.priceRange,
    this.isFeaturedOnly = false,
    this.itemsLimit = 50,
    ListingSortType? sortBy,
    ListingStatus? status,
    this.categoryAttributes = const {},
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
    Map<String, dynamic>? categoryAttributes,
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
      categoryAttributes: categoryAttributes ?? this.categoryAttributes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'searchQuery': searchQuery,
      'selectedCategory': selectedCategory,
      'selectedConditions': selectedConditions,
      'priceRangeStart': priceRange?.start,
      'priceRangeEnd': priceRange?.end,
      'isFeaturedOnly': isFeaturedOnly,
      'itemsLimit': itemsLimit,
      'sortBy': sortBy.name,
      'status': status.name,
      'categoryAttributes': categoryAttributes,
    };
  }

  factory ListingFilter.fromJson(Map<String, dynamic> json) {
    return ListingFilter(
      searchQuery: json['searchQuery'] ?? '',
      selectedCategory: json['selectedCategory'],
      selectedConditions: List<String>.from(json['selectedConditions'] ?? []),
      priceRange: (json['priceRangeStart'] != null && json['priceRangeEnd'] != null)
          ? RangeValues(json['priceRangeStart'], json['priceRangeEnd'])
          : null,
      isFeaturedOnly: json['isFeaturedOnly'] ?? false,
      itemsLimit: json['itemsLimit'] ?? 50,
      sortBy: ListingSortType.values.firstWhere((e) => e.name == json['sortBy'], orElse: () => ListingSortType.newest),
      status: ListingStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => ListingStatus.active),
      categoryAttributes: Map<String, dynamic>.from(json['categoryAttributes'] ?? {}),
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
          mapEquals(categoryAttributes, other.categoryAttributes);

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
        categoryAttributes,
      );
}
