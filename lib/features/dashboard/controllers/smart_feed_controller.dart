import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unihub_mobile/features/marketplace/domain/models/listing_filter.dart';
import '../../marketplace/shared/providers.dart';
import '../../housing/shared/providers.dart';
import '../../notes/shared/providers.dart';
import '../../gigs/shared/providers.dart';
import '../../community/shared/providers.dart';
import '../../../widgets/feed/feed_item_model.dart';
import '../../../models/feed_type.dart' as widgets;
import '../../auth/shared/providers.dart';
import '../../../services/history_service.dart';
import '../../campus_filter/shared/providers.dart';
import '../../../../core/constants/campus_constants.dart';

enum SmartFeedSource { personalized, trending, fresh, sponsored }

class SmartFeedItem {
  final FeedItemModel model;
  final SmartFeedSource source;
  final dynamic originalData;

  SmartFeedItem({
    required this.model,
    required this.source,
    required this.originalData,
  });
}

final smartFeedProvider = Provider<AsyncValue<List<SmartFeedItem>>>((ref) {
  final marketplaceAsync = ref.watch(listingsProvider(ListingFilter(itemsLimit: 10)));
  final housingAsync = ref.watch(housingListingsProvider(10));
  final notesAsync = ref.watch(notesListingsProvider(10));
  final gigsAsync = ref.watch(gigsFeedProvider);
  final communityAsync = ref.watch(communityFeedProvider);

  if (marketplaceAsync.isLoading || housingAsync.isLoading || notesAsync.isLoading || 
      gigsAsync.isLoading || communityAsync.isLoading) {
    return const AsyncValue.loading();
  }

  final listings = marketplaceAsync.valueOrNull ?? [];
  final housing = housingAsync.valueOrNull ?? [];
  final notes = notesAsync.valueOrNull ?? [];
  final gigs = gigsAsync.valueOrNull ?? [];
  final community = communityAsync.valueOrNull ?? [];

  final List<SmartFeedItem> allItems = [];

  // Add items from all sources
  for (var l in listings) {
    allItems.add(SmartFeedItem(
      source: SmartFeedSource.fresh,
      originalData: l,
      model: FeedItemModel(
        type: widgets.FeedType.marketplace,
        title: l.title,
        subtitle: 'KES ${l.price.toInt()} • ${l.campusLocation}',
        time: 'Marketplace',
      ),
    ));
  }

  for (var c in community) {
    allItems.add(SmartFeedItem(
      source: SmartFeedSource.fresh,
      originalData: c,
      model: FeedItemModel(
        type: widgets.FeedType.community,
        title: c.title.isEmpty ? c.authorName : c.title,
        subtitle: c.subtitle,
        time: 'Community',
      ),
    ));
  }

  for (var h in housing) {
    allItems.add(SmartFeedItem(
      source: SmartFeedSource.fresh,
      originalData: h,
      model: FeedItemModel(
        type: widgets.FeedType.housing,
        title: h.title,
        subtitle: 'KES ${h.rent.toInt()}/mo • ${h.type.name}',
        time: h.university,
      ),
    ));
  }

  for (var n in notes) {
    allItems.add(SmartFeedItem(
      source: SmartFeedSource.fresh,
      originalData: n,
      model: FeedItemModel(
        type: widgets.FeedType.notes,
        title: n.title,
        subtitle: '${n.unitCode} • ${n.university}',
        time: 'Notes',
      ),
    ));
  }

  for (var g in gigs) {
    allItems.add(SmartFeedItem(
      source: SmartFeedSource.fresh,
      originalData: g,
      model: FeedItemModel(
        type: widgets.FeedType.gig,
        title: g.title,
        subtitle: '${g.price ?? 'Negotiable'} • ${g.authorName}',
        time: 'Gigs',
      ),
    ));
  }

  // Stable sorting by timestamp instead of shuffle for better UI reliability
  allItems.sort((a, b) {
    final dateA = a.originalData?.createdAt as DateTime? ?? DateTime(2000);
    final dateB = b.originalData?.createdAt as DateTime? ?? DateTime(2000);
    return dateB.compareTo(dateA);
  });

  return AsyncValue.data(allItems);
});

final campusPulseProvider = Provider<AsyncValue<Map<String, int>>>((ref) {
  final marketplaceAsync = ref.watch(listingsProvider(ListingFilter(itemsLimit: 20)));
  final housingAsync = ref.watch(housingListingsProvider(20));
  final notesAsync = ref.watch(notesListingsProvider(20));
  final gigsAsync = ref.watch(gigsFeedProvider);

  if (marketplaceAsync.isLoading || housingAsync.isLoading || notesAsync.isLoading || gigsAsync.isLoading) {
    return const AsyncValue.loading();
  }

  return AsyncValue.data({
    'listings': marketplaceAsync.valueOrNull?.length ?? 0,
    'housing': housingAsync.valueOrNull?.length ?? 0,
    'notes': notesAsync.valueOrNull?.length ?? 0,
    'gigs': gigsAsync.valueOrNull?.length ?? 0,
  });
});

final personalizedRecommendationsProvider = Provider<AsyncValue<List<SmartFeedItem>>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  final allFeedAsync = ref.watch(smartFeedProvider);
  final browsingCampus = ref.watch(effectiveCampusFilterProvider);

  return allFeedAsync.whenData((items) {
    if (user == null) return items;

    // Use browsing campus if set, otherwise fallback to user's university for personalization
    // Normalize both to IDs
    final targetUniversity = browsingCampus ?? CampusConstants.resolveToId(user.university) ?? user.university;
    final userCampus = CampusConstants.resolveToId(user.campus) ?? user.campus;

    // Filter items based on target campus or university
    final personalizedItems = items.where((item) {
      final data = item.originalData;
      if (data == null) return true;

      // Check if it's housing and near campus
      if (item.model.type == widgets.FeedType.housing) {
        final itemUni = CampusConstants.resolveToId(data.university) ?? data.university;
        return itemUni == targetUniversity || (userCampus != null && data.location.contains(userCampus));
      }

      // Check if it's notes and same course/uni
      if (item.model.type == widgets.FeedType.notes) {
        final itemUni = CampusConstants.resolveToId(data.university) ?? data.university;
        return itemUni == targetUniversity || data.course == user.course;
      }

      // Check if it's marketplace and same uni
      if (item.model.type == widgets.FeedType.marketplace) {
        final itemUni = CampusConstants.resolveToId(data.sellerUniversity) ?? data.sellerUniversity;
        return itemUni == targetUniversity;
      }

      return true;
    }).toList();

    // If we have personalized items, return them, otherwise fallback to general items
    return personalizedItems.isNotEmpty ? personalizedItems : items;
  });
});

final trendingFeedProvider = Provider<AsyncValue<List<SmartFeedItem>>>((ref) {
  final allFeedAsync = ref.watch(smartFeedProvider);

  return allFeedAsync.whenData((items) {
    // Ranking logic: combination of source and engagement signals if available
    // For now, let's sort by some mock popularity signals
    final sorted = List<SmartFeedItem>.from(items);
    sorted.sort((a, b) {
      int getScore(SmartFeedItem item) {
        final data = item.originalData;
        int score = 0;
        if (data == null) return 0;
        
        // Use available signals from models
        try {
          if (item.model.type == widgets.FeedType.marketplace) {
            score = (data.viewsCount ?? 0) + (data.savesCount ?? 0) * 2;
          } else if (item.model.type == widgets.FeedType.housing) {
            score = (data.views ?? 0) + (data.saves ?? 0) * 2;
          } else if (item.model.type == widgets.FeedType.notes) {
            score = (data.downloadsCount ?? 0) * 3;
          } else if (item.model.type == widgets.FeedType.gig) {
            score = (data.likesCount ?? 0) * 2;
          }
        } catch (_) {}
        
        return score;
      }
      return getScore(b).compareTo(getScore(a));
    });
    return sorted.take(10).toList();
  });
});

final newItemsSummaryProvider = Provider<AsyncValue<Map<String, int>>>((ref) {
  final lastVisit = ref.watch(lastVisitProvider);
  if (lastVisit == null) return const AsyncValue.data({});

  final marketplaceAsync = ref.watch(listingsProvider(ListingFilter(itemsLimit: 50)));
  final housingAsync = ref.watch(housingListingsProvider(50));
  final notesAsync = ref.watch(notesListingsProvider(50));
  final gigsAsync = ref.watch(gigsFeedProvider);

  if (marketplaceAsync.isLoading || housingAsync.isLoading || notesAsync.isLoading || gigsAsync.isLoading) {
    return const AsyncValue.loading();
  }

  int countNew(List<dynamic> items) {
    return items.where((item) {
      final createdAt = item.createdAt as DateTime;
      return createdAt.isAfter(lastVisit);
    }).length;
  }

  final summary = {
    'Marketplace': countNew(marketplaceAsync.valueOrNull ?? []),
    'Housing': countNew(housingAsync.valueOrNull ?? []),
    'Notes': countNew(notesAsync.valueOrNull ?? []),
    'Gigs': countNew(gigsAsync.valueOrNull ?? []),
  };

  summary.removeWhere((key, value) => value == 0);
  return AsyncValue.data(summary);
});

final recentActivityProvider = Provider<AsyncValue<List<SmartFeedItem>>>((ref) {
  final allFeedAsync = ref.watch(smartFeedProvider);
  
  return allFeedAsync.whenData((items) {
    final sorted = List<SmartFeedItem>.from(items);
    sorted.sort((a, b) {
      final dateA = a.originalData?.createdAt as DateTime? ?? DateTime(2000);
      final dateB = b.originalData?.createdAt as DateTime? ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });
    return sorted.take(10).toList();
  });
});



