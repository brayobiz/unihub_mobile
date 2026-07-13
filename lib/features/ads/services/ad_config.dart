class AdConfig {
  /// Global toggle for all advertising functionality.
  /// Set to false to completely disable ad initialization and widgets.
  static const bool enabled = false;

  /// How often to insert a banner in the Marketplace grid (every X items).
  static const int marketplaceAdInterval = 8;
  
  /// How often to insert a banner in the Housing list (every X items).
  static const int housingAdInterval = 8;
  
  /// How often to insert a banner in the Notes feed (every X items).
  static const int notesAdInterval = 6;

  /// How often to insert a banner in the Community feed (every X items).
  static const int communityAdInterval = 8;

  /// How often to insert a banner in the Gigs feed (every X items).
  static const int gigsAdInterval = 8;

  /// Vertical padding applied to banners within lists.
  static const double bannerVerticalPadding = 24.0;

  /// Whether to show ad-related logs in the console.
  /// Set to false for cleaner logs, but true is recommended for development.
  static const bool enableLogging = true;

  /// Future: Frequency for interstitial ads (e.g., show after 5 screen transitions).
  static const int interstitialFrequency = 5;
}
