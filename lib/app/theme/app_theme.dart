import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

/// The entry point for the Ulify Theming System.
/// Modern Teal/Turquoise Identity.
class AppTheme {
  AppTheme._();

  static const Color primaryColor = AppColors.primary;
  static const Color secondaryColor = AppColors.secondary;
  static const Color backgroundColor = AppColors.scaffoldLight;
  static const Color cardColor = AppColors.white;

  // Cache theme instances to prevent expensive recalculations during rebuilds
  static final ThemeData lightTheme = _buildLightTheme();
  static final ThemeData darkTheme = _buildDarkTheme();

  static ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      splashFactory: InkRipple.splashFactory,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: secondaryColor,
        onSecondary: Colors.white,
        surface: AppColors.white,
        onSurface: AppColors.black,
        surfaceContainerHighest: AppColors.grey100,
        outline: AppColors.grey200,
        outlineVariant: AppColors.grey100,
        onSurfaceVariant: AppColors.grey600,
        error: AppColors.error,
        tertiary: AppColors.accent, // Using Amber as tertiary
      ),
      textTheme: AppTypography.lightTextTheme,
      appBarTheme: _appBarThemeLight,
      cardTheme: _cardThemeLight,
      elevatedButtonTheme: _elevatedButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      inputDecorationTheme: _inputDecorationTheme,
      snackBarTheme: _snackBarTheme,
      iconTheme: _iconThemeLight,
      dividerTheme: const DividerThemeData(color: AppColors.grey100, thickness: 1),
      chipTheme: _chipTheme,
    );
  }

  static ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      splashFactory: InkRipple.splashFactory,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: secondaryColor,
        onSecondary: Colors.white,
        surface: AppColors.backgroundDark,
        onSurface: Colors.white,
        surfaceContainerHighest: AppColors.cardDark,
        outline: AppColors.grey.withOpacity(0.2),
        outlineVariant: AppColors.grey.withOpacity(0.1),
        onSurfaceVariant: Colors.white70,
        error: AppColors.error,
        tertiary: AppColors.accent,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,
      textTheme: AppTypography.darkTextTheme,
      appBarTheme: _appBarThemeDark,
      cardTheme: _cardThemeDark,
      elevatedButtonTheme: _elevatedButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      inputDecorationTheme: _inputDecorationThemeDark,
      snackBarTheme: _snackBarTheme,
      dividerTheme: DividerThemeData(color: AppColors.grey.withOpacity(0.2)),
    );
  }

  static SnackBarThemeData get _snackBarTheme => SnackBarThemeData(
    backgroundColor: AppColors.black,
    contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 4,
  );

  static AppBarTheme get _appBarThemeLight => AppBarTheme(
    backgroundColor: AppColors.white,
    elevation: 0,
    scrolledUnderElevation: 0, // Clean flat look even when scrolled
    centerTitle: true,
    iconTheme: const IconThemeData(color: AppColors.black, size: 22),
    actionsIconTheme: const IconThemeData(color: AppColors.black, size: 22),
    titleTextStyle: TextStyle(
      color: AppColors.black,
      fontSize: 18,
      fontWeight: FontWeight.w800, // Slightly bolder for premium feel
      fontFamily: AppTypography.fontFamily,
      letterSpacing: -0.5,
    ),
  );

  static AppBarTheme get _appBarThemeDark => AppBarTheme(
    backgroundColor: AppColors.backgroundDark,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    iconTheme: const IconThemeData(color: Colors.white, size: 22),
    actionsIconTheme: const IconThemeData(color: Colors.white, size: 22),
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.w800,
      fontFamily: AppTypography.fontFamily,
      letterSpacing: -0.5,
    ),
  );

  static CardThemeData get _cardThemeLight => CardThemeData(
    color: AppColors.white,
    elevation: 0, // M3 uses tonal surface or very subtle shadows
    shadowColor: Colors.black.withOpacity(0.1),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20), // More rounded for modern look
      side: const BorderSide(color: AppColors.grey100, width: 1), // Subtle border
    ),
  );

  static CardThemeData get _cardThemeDark => CardThemeData(
    color: AppColors.cardDark,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
    ),
  );

  static ElevatedButtonThemeData get _elevatedButtonTheme => ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      tapTargetSize: MaterialTapTargetSize.padded,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),
  );

  static OutlinedButtonThemeData get _outlinedButtonTheme => OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: primaryColor,
      side: const BorderSide(color: primaryColor, width: 1.5),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  static InputDecorationTheme get _inputDecorationTheme => InputDecorationTheme(
    filled: true,
    fillColor: AppColors.grey50, // Slightly off-white for inputs
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.grey200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: primaryColor, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    hintStyle: const TextStyle(color: AppColors.grey400, fontSize: 14, fontWeight: FontWeight.w500),
    prefixIconColor: AppColors.grey500,
    suffixIconColor: AppColors.grey500,
  );

  static InputDecorationTheme get _inputDecorationThemeDark => InputDecorationTheme(
    filled: true,
    fillColor: AppColors.cardDark,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: primaryColor, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    hintStyle: const TextStyle(color: AppColors.grey600, fontSize: 14),
  );

  static ChipThemeData get _chipTheme => ChipThemeData(
    backgroundColor: AppColors.grey100,
    labelStyle: const TextStyle(color: AppColors.black, fontSize: 13, fontWeight: FontWeight.w600),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    side: BorderSide.none,
    secondarySelectedColor: AppColors.primary,
    secondaryLabelStyle: const TextStyle(color: Colors.white),
  );

  static IconThemeData get _iconThemeLight => const IconThemeData(
    color: AppColors.black,
    size: 24,
  );
}
