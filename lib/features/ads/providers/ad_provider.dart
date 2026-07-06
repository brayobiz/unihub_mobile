import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ad_service.dart';

final adServiceProvider = Provider<AdService>((ref) {
  return AdService();
});

/// A provider that handles the initialization of the AdService.
/// This can be watched at the root of the app or in specific features.
final adInitializationProvider = FutureProvider<void>((ref) async {
  final adService = ref.watch(adServiceProvider);
  // We use ref.listen to auth state if we want to defer initialization
  // but for now we'll keep it manual or feature-triggered.
  await adService.initialize();
});
