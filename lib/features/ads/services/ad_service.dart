import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_unit_ids.dart';
import 'ad_config.dart';

class AdService {
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initializes the Mobile Ads SDK and requests consent if necessary.
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    if (!AdConfig.enabled) {
      _log('Ads are disabled in AdConfig.');
      return;
    }

    // AdMob only supports Android and iOS
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      _log('Initialization skipped: Unsupported platform.');
      return;
    }

    try {
      // 1. Initialize the SDK first (non-blocking for UMP)
      // Note: We use a timeout to ensure native SDK initialization doesn't hang the app
      final status = await MobileAds.instance.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _log('Mobile Ads initialization timed out.');
          return InitializationStatus({});
        },
      );
      _isInitialized = true;
      _log('Mobile Ads SDK initialized successfully.');

      // 2. Request Consent Information (UMP readiness) in background
      // This is a placeholder for full UMP implementation.
      final params = ConsentRequestParameters();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          if (await ConsentInformation.instance.isConsentFormAvailable()) {
            // We don't automatically show it here if it's interfering with app load.
            // Future enhancement: showConsentFormIfRequired()
            _log('Consent form available.');
          }
        },
        (error) => _log('Consent update failed: ${error.message}'),
      );
      
      if (kDebugMode) {
        final adapterStatuses = status.adapterStatuses;
        adapterStatuses.forEach((key, value) {
          _log('Adapter: $key, Status: ${value.state}, Latency: ${value.latency}');
        });
      }
    } catch (e) {
      _log('Failed to initialize Mobile Ads SDK: $e');
    }
  }

  /// Explicitly show the consent form if required.
  /// This should be called from a safe place in the UI, not during main().
  Future<void> showConsentFormIfRequired() async {
    if (!AdConfig.enabled) return;
    
    ConsentForm.loadConsentForm(
      (consentForm) async {
        final status = await ConsentInformation.instance.getConsentStatus();
        if (status == ConsentStatus.required) {
          consentForm.show((formError) {
            if (formError != null) {
              _log('Consent form show error: ${formError.message}');
            }
            // Do not automatically reload to avoid infinite loops
          });
        }
      },
      (formError) => _log('Form load failed: ${formError.message}'),
    );
  }

  void _log(String message) {
    if (kDebugMode && AdConfig.enableLogging) {
      // ignore: avoid_print
      print('[AdService] $message');
    }
  }

  // Future expansion points for different ad types
  // These will be implemented in future phases
  
  // Future<BannerAd?> loadBannerAd(...)
  // Future<InterstitialAd?> loadInterstitialAd(...)
  // Future<NativeAd?> loadNativeAd(...)
  // Future<RewardedAd?> loadRewardedAd(...)
}
