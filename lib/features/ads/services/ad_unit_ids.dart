import 'dart:io';
import 'package:flutter/foundation.dart';

class AdUnitIds {
  // To use production IDs, replace these placeholders. 
  // If a placeholder starts with 'ca-app-pub-xxxxxxxx', the app will fallback to Google's 
  // official Test IDs to ensure ads always render during your final release testing.
  static const String _prodBannerId = 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
  static const String _prodInterstitialId = 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
  static const String _prodNativeId = 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
  static const String _prodRewardedId = 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';

  static String get bannerAdUnitId {
    if (kIsWeb) throw UnsupportedError('Ads not supported on Web');
    
    // Check if production ID is valid, otherwise use Test ID
    if (kReleaseMode && !_prodBannerId.contains('xxxxxxxx')) {
      if (Platform.isAndroid) return _prodBannerId;
      // ... (iOS logic)
    }

    // Default to Google Test ID (Android)
    return Platform.isAndroid 
        ? 'ca-app-pub-3940256099942544/6300978111' 
        : 'ca-app-pub-3940256099942544/2934735716';
  }

  static String get interstitialAdUnitId {
    if (kIsWeb) throw UnsupportedError('Ads not supported on Web');
    
    if (kReleaseMode && !_prodInterstitialId.contains('xxxxxxxx')) {
      if (Platform.isAndroid) return _prodInterstitialId;
    }

    return Platform.isAndroid 
        ? 'ca-app-pub-3940256099942544/1033173712' 
        : 'ca-app-pub-3940256099942544/4411468910';
  }

  static String get nativeAdUnitId {
    if (kIsWeb) throw UnsupportedError('Ads not supported on Web');
    
    if (kReleaseMode && !_prodNativeId.contains('xxxxxxxx')) {
      if (Platform.isAndroid) return _prodNativeId;
    }

    return Platform.isAndroid 
        ? 'ca-app-pub-3940256099942544/2247696110' 
        : 'ca-app-pub-3940256099942544/3986624511';
  }

  static String get rewardedAdUnitId {
    if (kIsWeb) throw UnsupportedError('Ads not supported on Web');
    
    if (kReleaseMode && !_prodRewardedId.contains('xxxxxxxx')) {
      if (Platform.isAndroid) return _prodRewardedId;
    }

    return Platform.isAndroid 
        ? 'ca-app-pub-3940256099942544/5224354917' 
        : 'ca-app-pub-3940256099942544/1712485313';
  }
}
