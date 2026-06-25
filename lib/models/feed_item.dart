import 'feed_type.dart';

class FeedItem {
  final String title;
  final String subtitle;
  final String price;
  final FeedType type;

  const FeedItem({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.type,
  });
}