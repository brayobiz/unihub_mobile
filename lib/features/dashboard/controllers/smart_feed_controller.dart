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

  // Simple shuffle for variety
  allItems.shuffle();

  return AsyncValue.data(allItems);
});
