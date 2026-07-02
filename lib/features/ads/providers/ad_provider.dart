import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ad_service.dart';

final adServiceProvider = Provider<AdService>((ref) {
  return AdService();
});

/// A provider that handles the initialization of the AdService.
/// This can be watched at the root of the app to ensure Ads are initialized.
final adInitializationProvider = FutureProvider<void>((ref) async {
  final adService = ref.watch(adServiceProvider);
  await adService.initialize();
});
