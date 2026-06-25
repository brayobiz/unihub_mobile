import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unihub_mobile/features/marketplace/domain/models/listing_filter.dart';
import '../../marketplace/shared/providers.dart';
import '../../housing/shared/providers.dart';
import '../../notes/shared/providers.dart';
import '../../gigs/gigs_screen.dart'; // For gigsFeedProvider
import '../../community/community_screen.dart'; // For communityFeedProvider
import '../../../widgets/feed/feed_item_model.dart';
import '../../../widgets/feed/feed_type.dart' as widgets;
import '../../auth/shared/providers.dart';

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
  // Use limited fetches for the dashboard feed to ensure speed
  final marketplaceAsync = ref.watch(listingsProvider(ListingFilter(itemsLimit: 15)));
  final housingAsync = ref.watch(housingListingsProvider(15));
  final notesAsync = ref.watch(notesListingsProvider(15));
  final gigsAsync = ref.watch(gigsFeedProvider);
  final communityAsync = ref.watch(communityFeedProvider);
  final user = ref.watch(appUserProvider).valueOrNull;

  // Check if everything is still loading
  final isAnyLoading = marketplaceAsync.isLoading || 
                        housingAsync.isLoading || 
                        notesAsync.isLoading || 
                        gigsAsync.isLoading || 
                        communityAsync.isLoading;

  final listings = marketplaceAsync.valueOrNull ?? [];
  final housing = housingAsync.valueOrNull ?? [];
  final notes = notesAsync.valueOrNull ?? [];
  final gigs = gigsAsync.valueOrNull ?? [];
  final community = communityAsync.valueOrNull ?? [];

  // If we have no data at all and we are still loading, show loading
  // But if we have ANY data, show it immediately (Speed optimization)
  final hasAnyData = listings.isNotEmpty || housing.isNotEmpty || notes.isNotEmpty || gigs.isNotEmpty || community.isNotEmpty;
  
  if (marketplaceAsync.isLoading && !hasAnyData) {
    return const AsyncValue.loading();
  }

  final List<SmartFeedItem> allItems = [];

  // 1. Marketplace
  for (var l in listings) {
    allItems.add(SmartFeedItem(
      source: l.isFeatured ? SmartFeedSource.sponsored : (l.viewsCount > 50 ? SmartFeedSource.trending : SmartFeedSource.fresh),
      originalData: l,
      model: FeedItemModel(
        type: widgets.FeedType.marketplace,
        title: l.title,
        subtitle: 'KES ${l.price.toInt()} • ${l.campusLocation}',
        time: 'Marketplace',
      ),
    ));
  }

  // 2. Community
  for (var c in community) {
    allItems.add(SmartFeedItem(
      source: c.likesCount > 10 ? SmartFeedSource.trending : SmartFeedSource.fresh,
      originalData: c,
      model: FeedItemModel(
        type: widgets.FeedType.community,
        title: c.title.isEmpty ? c.authorName : c.title,
        subtitle: c.subtitle,
        time: 'Community',
      ),
    ));
  }

  // 3. Housing
  for (var h in housing) {
    allItems.add(SmartFeedItem(
      source: SmartFeedSource.fresh,
      originalData: h,
      model: FeedItemModel(
        type: widgets.FeedType.housing,
        title: h.title,
        subtitle: 'KES ${h.price.toInt()}/mo • ${h.type.name}',
        time: h.university,
      ),
    ));
  }

  // 4. Notes
  for (var n in notes) {
    allItems.add(SmartFeedItem(
      source: n.downloadsCount > 20 ? SmartFeedSource.trending : SmartFeedSource.fresh,
      originalData: n,
      model: FeedItemModel(
        type: widgets.FeedType.notes,
        title: n.title,
        subtitle: '${n.unitCode} • ${n.university}',
        time: 'Notes',
      ),
    ));
  }

  // 5. Gigs
  for (var g in gigs) {
    bool isPersonalized = false;
    if (user != null && user.skills.isNotEmpty) {
      final combined = (g.title + g.subtitle).toLowerCase();
      isPersonalized = user.skills.any((skill) => combined.contains(skill.toLowerCase()));
    }

    allItems.add(SmartFeedItem(
      source: isPersonalized ? SmartFeedSource.personalized : SmartFeedSource.fresh,
      originalData: g,
      model: FeedItemModel(
        type: widgets.FeedType.gig,
        title: g.title,
        subtitle: '${g.price ?? 'Negotiable'} • ${g.authorName}',
        time: 'Gigs',
      ),
    ));
  }

  // SHUFFLE & WEIGHTING
  final personalized = allItems.where((i) => i.source == SmartFeedSource.personalized).toList();
  final trending = allItems.where((i) => i.source == SmartFeedSource.trending).toList();
  final fresh = allItems.where((i) => i.source == SmartFeedSource.fresh).toList();
  final sponsored = allItems.where((i) => i.source == SmartFeedSource.sponsored).toList();

  final List<SmartFeedItem> weightedFeed = [];
  
  int maxItems = 40;
  for (int i = 0; i < maxItems; i++) {
    if (i % 8 == 0 && sponsored.isNotEmpty) {
      weightedFeed.add(sponsored.removeAt(0));
    } else if (i % 2 == 0 && personalized.isNotEmpty) {
      weightedFeed.add(personalized.removeAt(0));
    } else if (i % 3 == 0 && trending.isNotEmpty) {
      weightedFeed.add(trending.removeAt(0));
    } else if (fresh.isNotEmpty) {
      weightedFeed.add(fresh.removeAt(0));
    }
  }

  if (weightedFeed.isEmpty && allItems.isNotEmpty) {
    return AsyncValue.data(allItems);
  }

  return AsyncValue.data(weightedFeed);
});
