import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Centralized typography definitions for Ulify.
/// Optimized for Plus Jakarta Sans.
class AppTypography {
  AppTypography._();

  static String get fontFamily => GoogleFonts.plusJakartaSans().fontFamily!;

  // Cache TextTheme instances to avoid expensive font resolution on every rebuild
  static final TextTheme lightTextTheme = _buildTextTheme(Brightness.light);
  static final TextTheme darkTextTheme = _buildTextTheme(Brightness.dark);

  static TextTheme _buildTextTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    
    // Using Brand Charcoal for Light Mode text
    final Color primaryColor = isDark ? Colors.white : AppColors.black;
    final Color secondaryColor = isDark ? Colors.white70 : AppColors.textSecondary;

    return GoogleFonts.plusJakartaSansTextTheme(
      TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: primaryColor, letterSpacing: -1.0),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: primaryColor, letterSpacing: -0.5),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: primaryColor, letterSpacing: -0.5),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: primaryColor, letterSpacing: -0.2),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: primaryColor),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: primaryColor),
        bodyLarge: TextStyle(fontSize: 16, color: primaryColor, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, color: secondaryColor, height: 1.5),
        bodySmall: TextStyle(fontSize: 12, color: secondaryColor, height: 1.4),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: primaryColor),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primaryColor),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: secondaryColor),
      ),
    );
  }
}
