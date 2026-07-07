import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/shared/providers.dart';
import '../../shared/feed_repository.dart';
import '../../../models/feed_type.dart';

final communityFeedProvider = StreamProvider.autoDispose<List<FeedItem>>((ref) {
  final blockedUids = ref.watch(appUserProvider.select((user) => user.valueOrNull?.blockedUids)) ?? const [];
  return ref.watch(feedRepositoryProvider).watchFeed(FeedType.community).map((items) {
    if (blockedUids.isEmpty) return items;
    return items.where((item) => !blockedUids.contains(item.authorId)).toList();
  });
});
