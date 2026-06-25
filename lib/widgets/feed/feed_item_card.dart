import 'package:flutter/material.dart';

import 'feed_item_model.dart';
import 'feed_type.dart';

class FeedItemCard extends StatelessWidget {
  final FeedItemModel item;
  final VoidCallback? onTap;

  const FeedItemCard({
    super.key,
    required this.item,
    this.onTap,
  });

  IconData get icon {
    switch (item.type) {
      case FeedType.marketplace:
        return Icons.storefront_outlined;

      case FeedType.housing:
        return Icons.home_work_outlined;

      case FeedType.notes:
        return Icons.menu_book_outlined;

      case FeedType.community:
        return Icons.groups_outlined;

      case FeedType.confession:
        return Icons.favorite_outline;

      case FeedType.gig:
        return Icons.work_outline;
    }
  }

  Color get color {
    switch (item.type) {
      case FeedType.marketplace:
        return Colors.green;

      case FeedType.housing:
        return Colors.blue;

      case FeedType.notes:
        return Colors.orange;

      case FeedType.community:
        return Colors.purple;

      case FeedType.confession:
        return Colors.red;

      case FeedType.gig:
        return Colors.indigo;
    }
  }

  String get label {
    switch (item.type) {
      case FeedType.marketplace:
        return "Marketplace";

      case FeedType.housing:
        return "Housing";

      case FeedType.notes:
        return "Notes";

      case FeedType.community:
        return "Community";

      case FeedType.confession:
        return "Confession";

      case FeedType.gig:
        return "Gigs";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(
            icon,
            color: color,
          ),
        ),
        title: Text(
          item.title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(item.subtitle),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.time,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
