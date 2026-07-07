import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unihub_mobile/core/utils/app_logger.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import '../services/ad_service.dart';
import '../services/ad_config.dart';

/// Provider for the [AdService] singleton.
final adServiceProvider = Provider<AdService>((ref) {
  return AdService();
});

/// A provider that handles the initialization of the AdService.
/// This can be watched at the root of the app or in specific features.
final adInitializationProvider = FutureProvider<void>((ref) async {
  if (!AdConfig.enabled) return;

  final adService = ref.watch(adServiceProvider);
  
  try {
    AppLogger.info('🎬 Initializing Ads Module...', 'Ads');
    await adService.initialize();
    AppLogger.info('🎬 Ads Module Initialized', 'Ads');
  } catch (e, stack) {
    AppLogger.error('Failed to initialize ads', e, stack, 'Ads');
    rethrow;
  }
});

/// Provider that determines if ads should be displayed.
/// Currently enabled for all users when AdConfig.enabled is true.
final adsEnabledProvider = Provider<bool>((ref) {
  return AdConfig.enabled;
});
