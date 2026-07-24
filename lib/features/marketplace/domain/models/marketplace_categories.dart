import 'package:flutter/material.dart';

class MarketplaceCategories {
  static const String electronics = 'Electronics';
  static const String phones = 'Phones & Accessories';
  static const String computers = 'Computers & Laptops';
  static const String furniture = 'Furniture';
  static const String homeEssentials = 'Home Essentials';
  static const String kitchen = 'Kitchen Items';
  static const String fashion = 'Fashion';
  static const String shoes = 'Shoes';
  static const String bags = 'Bags';
  static const String beauty = 'Beauty & Personal Care';
  static const String sports = 'Sports & Fitness';
  static const String gaming = 'Gaming';
  static const String books = 'Books';
  static const String instruments = 'Musical Instruments';
  static const String photography = 'Photography';
  static const String watches = 'Watches & Accessories';
  static const String vehicles = 'Vehicle Accessories';
  static const String other = 'Other Items';

  static const List<String> all = [
    electronics,
    phones,
    computers,
    furniture,
    homeEssentials,
    kitchen,
    fashion,
    shoes,
    bags,
    beauty,
    sports,
    gaming,
    books,
    instruments,
    photography,
    watches,
    vehicles,
    other,
  ];

  static const List<String> mainFilters = ['All', ...all];

  // Helper to get official icon for category (dynamic to allow emoji for shoe)
  static dynamic getIcon(String category) {
    switch (category) {
      case 'All': return Icons.auto_awesome_rounded;
      case electronics: return Icons.power_rounded;
      case phones: return Icons.smartphone_rounded;
      case computers: return Icons.laptop_mac_rounded;
      case furniture: return Icons.chair_rounded;
      case homeEssentials: return Icons.home_rounded;
      case kitchen: return Icons.kitchen_rounded;
      case fashion: return Icons.checkroom_rounded;
      case shoes: return '👟'; // Using emoji for shoe as requested
      case bags: return Icons.shopping_bag_rounded;
      case beauty: return Icons.face_retouching_natural_rounded;
      case sports: return Icons.sports_soccer_rounded;
      case gaming: return Icons.sports_esports_rounded;
      case books: return Icons.menu_book_rounded;
      case instruments: return Icons.music_note_rounded;
      case photography: return Icons.camera_alt_rounded;
      case watches: return Icons.watch_rounded;
      case vehicles: return Icons.directions_car_rounded;
      default: return Icons.inventory_2_rounded;
    }
  }
}
