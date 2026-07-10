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
    AppLogger.info('🎬 Starting Ads Module background initialization...', 'Ads');
    // We do NOT await here. This allows the provider to complete immediately,
    // ensuring no UI component (like a router or splash screen) blocks on it.
    // The AdService handles its own internal 'isInitialized' state.
    adService.initialize().catchError((e, stack) {
      AppLogger.error('Failed to initialize ads in background', e, stack, 'Ads');
    });
    AppLogger.info('🎬 Ads Module initialization triggered', 'Ads');
  } catch (e, stack) {
    AppLogger.error('Failed to trigger ads initialization', e, stack, 'Ads');
  }
});

/// Provider that determines if ads should be displayed.
/// Currently enabled for all users when AdConfig.enabled is true.
final adsEnabledProvider = Provider<bool>((ref) {
  return AdConfig.enabled;
});
