import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
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
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: const Color(0xFF1A1C1E),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          item.subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: const Color(0xFF64748B),
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
                style: GoogleFonts.plusJakartaSans(
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
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
