import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/shared/providers.dart';
import '../../shared/feed_repository.dart';
import '../../../models/feed_type.dart';

final communityFeedProvider = StreamProvider.autoDispose<List<FeedItem>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  return ref.watch(feedRepositoryProvider).watchFeed(FeedType.community).map((items) {
    if (user == null || user.blockedUids.isEmpty) return items;
    return items.where((item) => !user.blockedUids.contains(item.authorId)).toList();
  });
});
