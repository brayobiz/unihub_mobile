import 'package:flutter/material.dart';
import '../../models/feed_type.dart';
import '../../core/utils/category_utils.dart';
import 'feed_item_model.dart';

class FeedItemCard extends StatelessWidget {
  final FeedItemModel item;
  final VoidCallback? onTap;

  const FeedItemCard({
    super.key,
    required this.item,
    this.onTap,
  });

  IconData get icon => CategoryUtils.getIcon(item.type);

  Color get color => CategoryUtils.getColor(item.type);

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
      case FeedType.event:
        return "Events";
      case FeedType.lostFound:
        return "Lost & Found";
      case FeedType.user:
        return "Student";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5), width: 1),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        title: Text(
          item.title,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          item.subtitle,
          style: textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            color: colorScheme.onSurfaceVariant.withOpacity(0.8),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label.toUpperCase(),
                style: textTheme.labelSmall?.copyWith(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.time,
              style: textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
