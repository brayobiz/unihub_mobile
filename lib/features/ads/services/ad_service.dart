import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:unihub_mobile/core/utils/app_logger.dart';
import 'ad_unit_ids.dart';
import 'ad_config.dart';

class AdService {
  bool _isInitialized = false;
  bool _isInitializing = false;

  bool get isInitialized => _isInitialized;

  InterstitialAd? _preloadedInterstitialAd;
  bool _isPreloadingInterstitial = false;

  /// Initializes the Mobile Ads SDK and requests consent if necessary.
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    if (_isInitializing) {
      _log('Initialization already in progress.');
      return;
    }

    if (!AdConfig.enabled) {
      _log('Ads are disabled in AdConfig.');
      return;
    }

    // AdMob only supports Android and iOS
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      _log('Initialization skipped: Unsupported platform.');
      return;
    }

    _isInitializing = true;

    try {
      // 1. Initialize the SDK first (non-blocking for UMP)
      final status = await MobileAds.instance.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _log('Mobile Ads initialization timed out.', isError: true);
          return InitializationStatus({});
        },
      );
      
      _isInitialized = true;
      _log('Mobile Ads SDK initialized successfully.');

      // 2. Request Consent Information (UMP readiness) in background
      final params = ConsentRequestParameters();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          try {
            if (await ConsentInformation.instance.isConsentFormAvailable()) {
              _log('Consent form available.');
            }
          } catch (e) {
            _log('Error checking consent form availability: $e', isError: true);
          }
        },
        (error) => _log('Consent update failed: ${error.message}', isError: true),
      );
      
      // 3. Start pre-loading ads in the background to avoid interfering with user journey
      preloadInterstitialAd();

      if (kDebugMode) {
        final adapterStatuses = status.adapterStatuses;
        adapterStatuses.forEach((key, value) {
          _log('Adapter: $key, Status: ${value.state}, Latency: ${value.latency}');
        });
      }
    } catch (e, stack) {
      _log('Failed to initialize Mobile Ads SDK: $e', isError: true, error: e, stackTrace: stack);
    } finally {
      _isInitializing = false;
    }
  }

  /// Pre-loads an interstitial ad to be ready when needed.
  Future<void> preloadInterstitialAd() async {
    if (!AdConfig.enabled || _isPreloadingInterstitial || _preloadedInterstitialAd != null) return;
    
    _isPreloadingInterstitial = true;
    _log('Pre-loading InterstitialAd in background...');

    await InterstitialAd.load(
      adUnitId: AdUnitIds.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _log('Pre-loaded InterstitialAd ready.');
          _preloadedInterstitialAd = ad;
          _isPreloadingInterstitial = false;
        },
        onAdFailedToLoad: (error) {
          _log('Failed to pre-load InterstitialAd: $error', isError: true);
          _isPreloadingInterstitial = false;
        },
      ),
    );
  }

  /// Loads an interstitial ad or uses a pre-loaded one.
  Future<void> loadInterstitialAd({
    required Function(InterstitialAd ad) onAdLoaded,
    Function(LoadAdError error)? onAdFailedToLoad,
    Duration timeout = const Duration(seconds: 2), // Short timeout to avoid blocking user
  }) async {
    if (!AdConfig.enabled) {
      onAdFailedToLoad?.call(LoadAdError(0, 'Ads disabled', 'AdConfig', null));
      return;
    }

    // Use pre-loaded ad if available
    if (_preloadedInterstitialAd != null) {
      _log('Using pre-loaded InterstitialAd.');
      final ad = _preloadedInterstitialAd!;
      _preloadedInterstitialAd = null;
      onAdLoaded(ad);
      preloadInterstitialAd(); // Start pre-loading the next one
      return;
    }

    // If not ready, attempt to load with a strict timeout
    bool callbackTriggered = false;

    Future.delayed(timeout).then((_) {
      if (!callbackTriggered) {
        _log('InterstitialAd load timed out. Continuing without ad.', isError: true);
        callbackTriggered = true;
        onAdFailedToLoad?.call(LoadAdError(0, 'Load Timeout', 'AdService', null));
      }
    });

    await InterstitialAd.load(
      adUnitId: AdUnitIds.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (!callbackTriggered) {
            callbackTriggered = true;
            _log('InterstitialAd loaded: ${ad.adUnitId}');
            onAdLoaded(ad);
          } else {
            // Ad loaded after timeout, store it for next time
            _log('InterstitialAd loaded after timeout, storing for next use.');
            _preloadedInterstitialAd = ad;
          }
        },
        onAdFailedToLoad: (error) {
          if (!callbackTriggered) {
            callbackTriggered = true;
            _log('InterstitialAd failed to load: $error', isError: true);
            onAdFailedToLoad?.call(error);
          }
        },
      ),
    );
  }

  /// Shows a pre-loaded interstitial ad.
  void showInterstitialAd(InterstitialAd ad, {VoidCallback? onAdDismissed}) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _log('InterstitialAd dismissed');
        ad.dispose();
        onAdDismissed?.call();
        preloadInterstitialAd(); // Load next one after use
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _log('InterstitialAd failed to show: $error', isError: true);
        ad.dispose();
        onAdDismissed?.call();
        preloadInterstitialAd();
      },
    );
    ad.show();
  }

  void _log(String message, {bool isError = false, Object? error, StackTrace? stackTrace}) {
    if (!AdConfig.enableLogging) return;

    if (isError) {
      AppLogger.error(message, error, stackTrace, 'AdService');
    } else {
      AppLogger.info(message, 'AdService');
    }
  }
}
