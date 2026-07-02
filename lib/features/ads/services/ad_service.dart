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

    // AdMob only supports Android and iOS
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      _log('Initialization skipped: Unsupported platform.');
      return;
    }

    try {
      // 1. Request Consent Information (UMP readiness)
      // This is a placeholder for full UMP implementation.
      final params = ConsentRequestParameters();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          if (await ConsentInformation.instance.isConsentFormAvailable()) {
            _loadConsentForm();
          }
        },
        (error) => _log('Consent update failed: ${error.message}'),
      );

      // 2. Initialize the SDK
      final status = await MobileAds.instance.initialize();
      _isInitialized = true;
      _log('Mobile Ads SDK initialized successfully.');
      
      if (kDebugMode) {
        final adapterStatuses = status.adapterStatuses;
        adapterStatuses.forEach((key, value) {
          _log('Adapter: $key, Status: ${value.state}, Latency: ${value.latency}');
        });
        _log('Environment: ${kReleaseMode ? "Production" : "Test"}');
        _log('Platform: ${Platform.isAndroid ? "Android" : "iOS"}');
      }
    } catch (e) {
      _log('Failed to initialize Mobile Ads SDK: $e');
      // Do not rethrow, we want the app to continue functioning
    }
  }

  /// Future implementation for UMP Consent Management.
  Future<void> requestConsentUpdate() async {
    // TODO: Implement User Messaging Platform (UMP) for GDPR/CCPA
    _log('UMP Consent check requested (Stub)');
  }

  void _loadConsentForm() {
    ConsentForm.loadConsentForm(
      (consentForm) async {
        final status = await ConsentInformation.instance.getConsentStatus();
        if (status == ConsentStatus.required) {
          consentForm.show((formError) {
            _loadConsentForm(); // Reload if needed
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
