import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A global provider used to force a full state invalidation across the app.
/// Useful during logout to ensure no stale data remains in memory.
final appRestartProvider = StateProvider<int>((ref) => 0);

/// Extension to make invalidation easier
extension ProviderRefRestartX on Ref {
  void restartApp() {
    this.read(appRestartProvider.notifier).state++;
  }
}
