import '../../models/feed_type.dart';

class FeedItemModel {
  final FeedType type;
  final String title;
  final String subtitle;
  final String time;
  final bool boosted;

  const FeedItemModel({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.time,
    this.boosted = false,
  });
}