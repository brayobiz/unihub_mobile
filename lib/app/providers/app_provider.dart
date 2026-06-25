import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App initialization state
final appInitializedProvider = StateProvider<bool>(
      (ref) => false,
);

/// Theme mode state
final darkModeProvider = StateProvider<bool>(
      (ref) => false,
);