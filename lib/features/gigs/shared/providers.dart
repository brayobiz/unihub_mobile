import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/shared/providers.dart';
import '../../shared/notification_repository.dart';
import '../data/repositories/gigs_repository_impl.dart';
import '../domain/repositories/gigs_repository.dart';
import '../../shared/feed_repository.dart';
import '../../../models/feed_type.dart';

import 'package:unihub_mobile/services/notification_service.dart';

final gigsRepositoryProvider = Provider<GigsRepository>((ref) {
  return GigsRepositoryImpl(
    ref.watch(firestoreProvider),
    ref.watch(notificationServiceProvider),
  );
});

final gigsFeedProvider = StreamProvider.autoDispose<List<FeedItem>>((ref) {
  final blockedUids = ref.watch(appUserProvider.select((user) => user.valueOrNull?.blockedUids)) ?? const [];
  return ref.watch(feedRepositoryProvider).watchFeed(FeedType.gig).map((items) {
    if (blockedUids.isEmpty) return items;
    return items.where((item) => !blockedUids.contains(item.authorId)).toList();
  });
});
