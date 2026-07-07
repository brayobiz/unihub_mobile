import 'package:flutter/material.dart';
import '../../models/feed_type.dart';
import '../../app/theme/app_colors.dart';

class CategoryUtils {
  static IconData getIcon(FeedType type) {
    switch (type) {
      case FeedType.marketplace:
        return Icons.shopping_bag_outlined;
      case FeedType.housing:
        return Icons.home_work_outlined;
      case FeedType.notes:
        return Icons.description_outlined;
      case FeedType.gig:
        return Icons.work_outline;
      case FeedType.community:
        return Icons.people_outline;
      case FeedType.confession:
        return Icons.favorite_border;
      case FeedType.event:
        return Icons.event_outlined;
      case FeedType.lostFound:
        return Icons.search_off_outlined;
      case FeedType.user:
        return Icons.person_outline;
    }
  }

  static Color getColor(FeedType type) {
    switch (type) {
      case FeedType.marketplace:
        return AppColors.marketplace;
      case FeedType.housing:
        return AppColors.housing;
      case FeedType.notes:
        return AppColors.notes;
      case FeedType.gig:
        return AppColors.gigs;
      case FeedType.community:
        return AppColors.community;
      case FeedType.confession:
        return AppColors.error;
      case FeedType.event:
        return Colors.teal;
      case FeedType.lostFound:
        return Colors.brown;
      case FeedType.user:
        return Colors.blue;
    }
  }

  static String getPlaceholder(FeedType type) {
    switch (type) {
      case FeedType.marketplace:
        return 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?q=80&w=1999&auto=format&fit=crop';
      case FeedType.housing:
        return 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?q=80&w=2070&auto=format&fit=crop';
      case FeedType.notes:
        return 'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?q=80&w=1973&auto=format&fit=crop';
      case FeedType.gig:
        return 'https://images.unsplash.com/photo-1515378791036-0648a3ef77b2?q=80&w=2070&auto=format&fit=crop';
      case FeedType.community:
        return 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?q=80&w=2070&auto=format&fit=crop';
      case FeedType.confession:
        return 'https://images.unsplash.com/photo-1518199266791-5375a83190b7?q=80&w=2070&auto=format&fit=crop';
      case FeedType.event:
        return 'https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?q=80&w=2070&auto=format&fit=crop';
      case FeedType.lostFound:
        return 'https://images.unsplash.com/photo-1506784983877-45594efa4cbe?q=80&w=2068&auto=format&fit=crop';
      case FeedType.user:
        return 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=2080&auto=format&fit=crop';
    }
  }
}
