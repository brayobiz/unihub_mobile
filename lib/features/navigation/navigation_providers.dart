import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/shared/providers.dart';

final mainNavigationIndexProvider = StateProvider<int>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  // Persist index so it survives process death/restarts
  final savedIndex = prefs.getInt('main_nav_index') ?? 0;
  
  // Clear index on logout
  ref.listenSelf((previous, next) {
    if (previous != next) {
      prefs.setInt('main_nav_index', next);
    }
  });

  return savedIndex;
});
