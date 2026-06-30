import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

/// The entry point for the UniHub Theming System.
/// 
/// This class provides the light and dark [ThemeData] and acts as the
/// single source of truth for the application's appearance.
class AppTheme {
  AppTheme._();

  // Legacy constants kept for internal backward compatibility within this file
  static const Color primaryColor = AppColors.primary;
  static const Color secondaryColor = AppColors.secondary;
  static const Color backgroundColor = AppColors.scaffoldLight;
  static const Color cardColor = AppColors.white;

  /// Returns the Light Theme for UniHub.
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Colors
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: backgroundColor,
        surfaceContainerHighest: AppColors.grey100,
        outlineVariant: AppColors.grey200,
        onSurface: AppColors.black,
        onSurfaceVariant: AppColors.grey600,
        error: AppColors.error,
      ),

      // Typography
      textTheme: AppTypography.lightTextTheme,

      // Component Themes
      appBarTheme: _appBarThemeLight,
      cardTheme: _cardThemeLight,
      elevatedButtonTheme: _elevatedButtonTheme,
      inputDecorationTheme: _inputDecorationTheme,
      iconTheme: _iconThemeLight,
      dividerTheme: const DividerThemeData(color: AppColors.grey200),
    );
  }

  /// Returns the Dark Theme for UniHub.
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Colors
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: AppColors.backgroundDark,
        surfaceContainerHighest: AppColors.cardDark,
        outlineVariant: AppColors.grey.withValues(alpha: 0.2),
        onSurface: Colors.white,
        onSurfaceVariant: Colors.white70,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,

      // Typography
      textTheme: AppTypography.darkTextTheme,

      // Component Themes
      appBarTheme: _appBarThemeDark,
      cardTheme: _cardThemeDark,
      dividerTheme: DividerThemeData(color: AppColors.grey.withValues(alpha: 0.2)),
    );
  }

  // --- COMPONENT THEME DEFINITIONS ---

  static AppBarTheme get _appBarThemeLight => AppBarTheme(
    backgroundColor: AppColors.white,
    elevation: 0,
    centerTitle: true,
    iconTheme: const IconThemeData(color: AppColors.black),
    titleTextStyle: TextStyle(
      color: AppColors.black,
      fontSize: 18,
      fontWeight: FontWeight.bold,
      fontFamily: AppTypography.fontFamily,
    ),
  );

  static AppBarTheme get _appBarThemeDark => const AppBarTheme(
    backgroundColor: AppColors.backgroundDark,
    elevation: 0,
    centerTitle: true,
  );

  static CardThemeData get _cardThemeLight => CardThemeData(
    color: cardColor,
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  );

  static CardThemeData get _cardThemeDark => const CardThemeData(
    color: AppColors.cardDark,
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
  );

  static ElevatedButtonThemeData get _elevatedButtonTheme => ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      foregroundColor: AppColors.white,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  static InputDecorationTheme get _inputDecorationTheme => InputDecorationTheme(
    filled: true,
    fillColor: AppColors.white,
    contentPadding: const EdgeInsets.all(16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.grey200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: primaryColor, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    hintStyle: const TextStyle(color: AppColors.grey400, fontSize: 14),
  );

  static IconThemeData get _iconThemeLight => const IconThemeData(
    color: AppColors.black,
    size: 24,
  );
}
