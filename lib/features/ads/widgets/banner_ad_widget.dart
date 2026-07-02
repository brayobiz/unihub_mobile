import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_unit_ids.dart';
import '../providers/ad_provider.dart';
import '../services/ad_config.dart';

class BannerAdWidget extends ConsumerStatefulWidget {
  const BannerAdWidget({super.key});

  @override
  ConsumerState<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends ConsumerState<BannerAdWidget> with AutomaticKeepAliveClientMixin {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _failed = false;
  AdSize? _adSize;
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bannerAd == null && !_failed && !_isLoading) {
      _prepareAndLoadAd();
    }
  }

  Future<void> _prepareAndLoadAd() async {
    if (_isLoading) return;
    
    // AdMob only supports Android and iOS
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      if (mounted) setState(() => _failed = true);
      return;
    }

    _isLoading = true;

    try {
      final double width = MediaQuery.of(context).size.width;
      // Pre-calculate adaptive size to reserve space and avoid layout jumps
      final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width.truncate());
      
      if (mounted) {
        setState(() {
          _adSize = size;
        });
        _loadAd();
      }
    } catch (e) {
      _log('Error calculating AdSize: $e');
      if (mounted) {
        setState(() {
          _failed = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAd() async {
    // Ensure AdService is initialized
    final adService = ref.read(adServiceProvider);
    if (!adService.isInitialized) {
      try {
        await ref.read(adInitializationProvider.future);
      } catch (e) {
        _log('Ad initialization failed: $e');
        if (mounted) {
          setState(() {
            _failed = true;
            _isLoading = false;
          });
        }
        return;
      }
    }

    if (!mounted || _adSize == null) return;

    _bannerAd = BannerAd(
      adUnitId: AdUnitIds.bannerAdUnitId,
      size: _adSize!,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _log('BannerAd loaded: ${ad.adUnitId}');
          if (mounted) {
            setState(() {
              _isLoaded = true;
              _isLoading = false;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          _log('BannerAd failed to load: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _failed = true;
              _isLoading = false;
            });
          }
        },
        onAdOpened: (ad) => _log('BannerAd opened'),
        onAdClosed: (ad) => _log('BannerAd closed'),
      ),
    );

    await _bannerAd!.load();
  }

  void _log(String message) {
    if (kDebugMode && AdConfig.enableLogging) {
      // ignore: avoid_print
      print('[BannerAdWidget] $message');
    }
  }

  @override
  void dispose() {
    _log('Disposing BannerAd');
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    if (_failed) {
      return const SizedBox.shrink();
    }

    if (_adSize == null) {
      return const SizedBox.shrink();
    }

    return Container(
      alignment: Alignment.center,
      width: _adSize!.width.toDouble(),
      height: _adSize!.height.toDouble(),
      child: _isLoaded && _bannerAd != null
          ? AdWidget(ad: _bannerAd!)
          : const SizedBox.shrink(),
    );
  }
}
