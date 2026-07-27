import 'package:flutter/material.dart';

class CommunityCategories {
  CommunityCategories._();

  static const List<String> all = [
    'General',
    'Questions',
    'Academic',
    'Events',
    'Sports',
    'Lost & Found',
  ];

  static IconData getIcon(String category) {
    switch (category) {
      case 'Questions':
        return Icons.help_outline_rounded;
      case 'Academic':
        return Icons.book_rounded;
      case 'Events':
        return Icons.celebration_rounded;
      case 'Sports':
        return Icons.sports_soccer_rounded;
      case 'Lost & Found':
        return Icons.search_rounded;
      default:
        return Icons.chat_bubble_outline_rounded;
    }
  }
}
