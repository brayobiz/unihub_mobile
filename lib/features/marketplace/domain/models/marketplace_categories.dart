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

  // Helper to get icon for category
  static String getIcon(String category) {
    switch (category) {
      case 'All': return '✨';
      case electronics: return '🔌';
      case phones: return '📱';
      case computers: return '💻';
      case furniture: return '🪑';
      case homeEssentials: return '🏠';
      case kitchen: return '🍳';
      case fashion: return '👕';
      case shoes: return '👟';
      case bags: return '👜';
      case beauty: return '💄';
      case sports: return '⚽';
      case gaming: return '🎮';
      case books: return '📚';
      case instruments: return '🎸';
      case photography: return '📷';
      case watches: return '⌚';
      case vehicles: return '🚗';
      default: return '📦';
    }
  }
}
