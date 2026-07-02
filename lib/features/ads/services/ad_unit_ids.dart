import 'dart:io';
import 'package:flutter/foundation.dart';

class AdUnitIds {
  static String get bannerAdUnitId {
    if (kIsWeb) throw UnsupportedError('Ads not supported on Web');
    if (kReleaseMode) {
      // TODO: Replace with production IDs
      if (Platform.isAndroid) {
        return 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
      } else if (Platform.isIOS) {
        return 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
      }
      throw UnsupportedError('Unsupported platform');
    } else {
      // Official Google Test IDs
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/6300978111';
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/2934735716';
      }
      throw UnsupportedError('Unsupported platform');
    }
  }

  static String get interstitialAdUnitId {
    if (kIsWeb) throw UnsupportedError('Ads not supported on Web');
    if (kReleaseMode) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
      } else if (Platform.isIOS) {
        return 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
      }
      throw UnsupportedError('Unsupported platform');
    } else {
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/1033173712';
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/4411468910';
      }
      throw UnsupportedError('Unsupported platform');
    }
  }

  static String get nativeAdUnitId {
    if (kIsWeb) throw UnsupportedError('Ads not supported on Web');
    if (kReleaseMode) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
      } else if (Platform.isIOS) {
        return 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
      }
      throw UnsupportedError('Unsupported platform');
    } else {
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/2247696110';
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/3986624511';
      }
      throw UnsupportedError('Unsupported platform');
    }
  }

  static String get rewardedAdUnitId {
    if (kIsWeb) throw UnsupportedError('Ads not supported on Web');
    if (kReleaseMode) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
      } else if (Platform.isIOS) {
        return 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
      }
      throw UnsupportedError('Unsupported platform');
    } else {
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/5224354917';
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/1712485313';
      }
      throw UnsupportedError('Unsupported platform');
    }
  }
}
