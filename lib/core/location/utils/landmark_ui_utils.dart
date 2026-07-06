import 'package:flutter/material.dart';
import '../models/landmark.dart';

class LandmarkUIUtils {
  static IconData getIcon(LandmarkCategory category) {
    switch (category) {
      case LandmarkCategory.academic:
        return Icons.school_rounded;
      case LandmarkCategory.administration:
        return Icons.business_rounded;
      case LandmarkCategory.food:
        return Icons.restaurant_rounded;
      case LandmarkCategory.health:
        return Icons.local_hospital_rounded;
      case LandmarkCategory.transport:
        return Icons.directions_bus_rounded;
      case LandmarkCategory.recreation:
        return Icons.sports_basketball_rounded;
      case LandmarkCategory.services:
        return Icons.construction_rounded;
      case LandmarkCategory.accommodation:
        return Icons.hotel_rounded;
      case LandmarkCategory.security:
        return Icons.security_rounded;
      case LandmarkCategory.banking:
        return Icons.account_balance_rounded;
      case LandmarkCategory.religious:
        return Icons.place_rounded;
      case LandmarkCategory.other:
        return Icons.location_on_rounded;
    }
  }

  static Color getColor(LandmarkCategory category) {
    switch (category) {
      case LandmarkCategory.academic:
        return Colors.blue;
      case LandmarkCategory.administration:
        return Colors.indigo;
      case LandmarkCategory.food:
        return Colors.orange;
      case LandmarkCategory.health:
        return Colors.red;
      case LandmarkCategory.transport:
        return Colors.green;
      case LandmarkCategory.recreation:
        return Colors.purple;
      case LandmarkCategory.services:
        return Colors.teal;
      case LandmarkCategory.accommodation:
        return Colors.brown;
      case LandmarkCategory.security:
        return Colors.blueGrey;
      case LandmarkCategory.banking:
        return Colors.amber;
      case LandmarkCategory.religious:
        return Colors.cyan;
      case LandmarkCategory.other:
        return Colors.grey;
    }
  }

  static String getLabel(LandmarkCategory category) {
    return category.name.substring(0, 1).toUpperCase() + category.name.substring(1);
  }
}
