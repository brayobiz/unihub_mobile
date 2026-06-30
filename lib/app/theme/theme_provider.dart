import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/shared/providers.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final isDark = prefs.getBool('isDarkMode') ?? false;
  return isDark ? ThemeMode.dark : ThemeMode.light;
});
