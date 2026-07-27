import 'package:flutter/material.dart';

class ConfessionCategories {
  ConfessionCategories._();

  static const List<String> all = [
    'Relationships',
    'Campus Life',
    'Funny',
    'Academic',
    'Random',
  ];

  static IconData getIcon(String category) {
    switch (category) {
      case 'Relationships':
        return Icons.favorite_rounded;
      case 'Campus Life':
        return Icons.school_rounded;
      case 'Funny':
        return Icons.emoji_emotions_rounded;
      case 'Academic':
        return Icons.book_rounded;
      case 'Random':
        return Icons.bubble_chart_rounded;
      default:
        return Icons.face_rounded;
    }
  }

  static Color getColor(String category) {
    switch (category) {
      case 'Relationships':
        return Colors.purple;
      case 'Campus Life':
        return Colors.blue;
      case 'Funny':
        return Colors.amber;
      case 'Academic':
        return Colors.green;
      case 'Random':
        return Colors.blueGrey;
      default:
        return const Color(0xFF14B8A6); // AppColors.primary
    }
  }
}
