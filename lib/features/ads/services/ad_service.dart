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

  /// Explicitly show the consent form if required.
  Future<void> showConsentFormIfRequired() async {
    if (!AdConfig.enabled) return;
    
    ConsentForm.loadConsentForm(
      (consentForm) async {
        final status = await ConsentInformation.instance.getConsentStatus();
        if (status == ConsentStatus.required) {
          consentForm.show((formError) {
            if (formError != null) {
              _log('Consent form show error: ${formError.message}', isError: true);
            }
          });
        }
      },
      (formError) => _log('Form load failed: ${formError.message}', isError: true),
    );
  }

  void _log(String message, {bool isError = false, Object? error, StackTrace? stackTrace}) {
    if (!AdConfig.enableLogging) return;

    if (isError) {
      AppLogger.error(message, error, stackTrace, 'AdService');
    } else {
      AppLogger.info(message, 'AdService');
    }
  }

  // Future expansion points for different ad types
  // These will be implemented in future phases
  
  /// Loads an interstitial ad.
  Future<void> loadInterstitialAd({
    required Function(InterstitialAd ad) onAdLoaded,
    Function(LoadAdError error)? onAdFailedToLoad,
  }) async {
    if (!AdConfig.enabled) return;

    await InterstitialAd.load(
      adUnitId: AdUnitIds.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _log('InterstitialAd loaded: ${ad.adUnitId}');
          onAdLoaded(ad);
        },
        onAdFailedToLoad: (error) {
          _log('InterstitialAd failed to load: $error', isError: true);
          onAdFailedToLoad?.call(error);
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
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _log('InterstitialAd failed to show: $error', isError: true);
        ad.dispose();
        onAdDismissed?.call();
      },
    );
    ad.show();
  }
}
