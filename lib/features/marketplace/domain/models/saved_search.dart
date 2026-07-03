import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'listing_filter.dart';
import '../repositories/marketplace_repository.dart';
import 'listing.dart';

class SavedSearch {
  final String id;
  final String userId;
  final String name;
  final ListingFilter filter;
  final String? campusId;
  final bool notificationsEnabled;
  final DateTime createdAt;
  final DateTime? lastNotificationSent;

  SavedSearch({
    required this.id,
    required this.userId,
    required this.name,
    required this.filter,
    this.campusId,
    this.notificationsEnabled = true,
    required this.createdAt,
    this.lastNotificationSent,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'searchQuery': filter.searchQuery,
      'category': filter.selectedCategory,
      'conditions': filter.selectedConditions,
      'minPrice': filter.priceRange?.start,
      'maxPrice': filter.priceRange?.end,
      'sortBy': filter.sortBy.name,
      'status': filter.status.name,
      'categoryAttributes': filter.categoryAttributes,
      'campusId': campusId,
      'notificationsEnabled': notificationsEnabled,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastNotificationSent': lastNotificationSent != null ? Timestamp.fromDate(lastNotificationSent!) : null,
    };
  }

  factory SavedSearch.fromJson(Map<String, dynamic> json) {
    return SavedSearch(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      name: json['name'] ?? 'Saved Search',
      filter: ListingFilter(
        searchQuery: json['searchQuery'] ?? '',
        selectedCategory: json['category'],
        selectedConditions: List<String>.from(json['conditions'] ?? []),
        priceRange: (json['minPrice'] != null && json['maxPrice'] != null)
            ? RangeValues((json['minPrice'] as num).toDouble(), (json['maxPrice'] as num).toDouble())
            : null,
        sortBy: ListingSortType.values.firstWhere(
          (e) => e.name == json['sortBy'],
          orElse: () => ListingSortType.newest,
        ),
        status: ListingStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => ListingStatus.active,
        ),
        categoryAttributes: Map<String, dynamic>.from(json['categoryAttributes'] ?? {}),
      ),
      campusId: json['campusId'],
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastNotificationSent: (json['lastNotificationSent'] as Timestamp?)?.toDate(),
    );
  }
}
