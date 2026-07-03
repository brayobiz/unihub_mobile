class SellerStats {
  final int activeListingsCount;
  final int totalViews;
  final int totalSaves;
  final int totalChatsStarted;
  final int soldCount;
  final double averageListingQuality;
  final List<ListingEngagement> topPerformingListings;

  SellerStats({
    this.activeListingsCount = 0,
    this.totalViews = 0,
    this.totalSaves = 0,
    this.totalChatsStarted = 0,
    this.soldCount = 0,
    this.averageListingQuality = 0.0,
    this.topPerformingListings = const [],
  });

  SellerStats copyWith({
    int? activeListingsCount,
    int? totalViews,
    int? totalSaves,
    int? totalChatsStarted,
    int? soldCount,
    double? averageListingQuality,
    List<ListingEngagement>? topPerformingListings,
  }) {
    return SellerStats(
      activeListingsCount: activeListingsCount ?? this.activeListingsCount,
      totalViews: totalViews ?? this.totalViews,
      totalSaves: totalSaves ?? this.totalSaves,
      totalChatsStarted: totalChatsStarted ?? this.totalChatsStarted,
      soldCount: soldCount ?? this.soldCount,
      averageListingQuality: averageListingQuality ?? this.averageListingQuality,
      topPerformingListings: topPerformingListings ?? this.topPerformingListings,
    );
  }
}

class ListingEngagement {
  final String listingId;
  final String title;
  final int views;
  final int saves;
  final int chats;
  final String status;
  final DateTime createdAt;

  ListingEngagement({
    required this.listingId,
    required this.title,
    required this.views,
    required this.saves,
    required this.chats,
    required this.status,
    required this.createdAt,
  });
}
