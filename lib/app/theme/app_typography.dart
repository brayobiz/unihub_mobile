import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized typography definitions for Ulify.
class AppTypography {
  AppTypography._();

  static String get fontFamily => GoogleFonts.plusJakartaSans().fontFamily!;

  // Cache TextTheme instances to avoid expensive font resolution on every rebuild
  static final TextTheme lightTextTheme = _buildTextTheme(Brightness.light);
  static final TextTheme darkTextTheme = _buildTextTheme(Brightness.dark);

  static TextTheme _buildTextTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final Color primaryColor = isDark ? Colors.white : Colors.black;
    final Color secondaryColor = isDark ? Colors.white70 : Colors.black87;

    return GoogleFonts.plusJakartaSansTextTheme(
      TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: primaryColor),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: primaryColor),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryColor),
        bodyLarge: TextStyle(fontSize: 16, color: primaryColor),
        bodyMedium: TextStyle(fontSize: 14, color: secondaryColor),
        bodySmall: TextStyle(fontSize: 12, color: secondaryColor),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: secondaryColor),
      ),
    );
  }
}
