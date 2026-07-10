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
      // 1. Initialize the SDK (Reduced timeout and handled asynchronously)
      // We don't await this if we want to be truly non-blocking, but we want 
      // to know when it's done. 
      _log('Starting Mobile Ads SDK initialization...');
      
      // We use unawaited to let it run in background without blocking the initialize() call
      // if we decide to call initialize from a place that awaits it.
      // However, we'll keep the await here but ensure the caller doesn't wait.
      final status = await MobileAds.instance.initialize().timeout(
        const Duration(seconds: 3), // Reduced from 5s
        onTimeout: () {
          _log('Mobile Ads initialization timed out after 3s. Continuing in background.', isError: true);
          return InitializationStatus({});
        },
      );
      
      _isInitialized = true;
      _log('Mobile Ads SDK initialization call completed.');

      // 2. Request Consent Information (UMP readiness) in background - NEVER await this
      _log('Requesting Consent Information update...');
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
      
      // 3. Start pre-loading ads in the background
      // Note: We don't await this either
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

    // Note: InterstitialAd.load returns a Future, but we DON'T await it here
    // as we want to handle the results in the callback and not block the service.
    InterstitialAd.load(
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
    ).catchError((e) {
       _log('Error starting InterstitialAd load: $e', isError: true);
       _isPreloadingInterstitial = false;
    });
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

    // We don't await InterstitialAd.load to ensure we don't block the caller.
    // The strict timeout logic below will handle the UI state.
    InterstitialAd.load(
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
    ).catchError((e) {
      if (!callbackTriggered) {
        callbackTriggered = true;
        _log('Error starting InterstitialAd load: $e', isError: true);
        onAdFailedToLoad?.call(LoadAdError(0, e.toString(), 'AdService', null));
      }
    });
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
