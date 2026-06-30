import 'package:flutter/material.dart';

/// Centralized color palette for UniHub.
/// 
/// These colors are used to build the [ColorScheme] and can be accessed
/// directly for specific cases, though theme-based access is preferred.
class AppColors {
  AppColors._();

  // Primary Palette
  static const Color primary = Color(0xFF3B82F6);    // Blue
  static const Color primaryGradientStart = Color(0xFF283593); // Indigo 800
  static const Color primaryGradientEnd = Color(0xFF3F51B5);   // Indigo 500
  static const Color secondary = Color(0xFF6366F1);  // Indigo
  static const Color secondaryDark = Color(0xFF312E81); // Indigo 900
  static const Color accent = Color(0xFF1677F2);     // Brand Blue
  
  // Backgrounds
  static const Color backgroundLight = Color(0xFFF7F8FC);
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color scaffoldLight = Color(0xFFF8F9FB);
  
  // Surface Colors
  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF1E293B);
  
  // Neutral Colors
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color grey = Color(0xFF9E9E9E);
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  
  // Status Colors
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Category & Brand Shades
  static const Color notes = Color(0xFF388E3C);       // Green 700
  static const Color marketplace = Color(0xFFF57C00); // Orange 700
  static const Color housing = Color(0xFF1976D2);     // Blue 700
  static const Color gigs = Color(0xFF7B1FA2);        // Purple 700
  static const Color community = Color(0xFFE91E63);   // Pink

  // Highlight Colors
  static const Color highlightOrangeBg = Color(0xFFFFF3E0); // Orange 50
  static const Color highlightOrangeBorder = Color(0xFFFFE0B2); // Orange 100
  static const Color highlightIndigoBg = Color(0xFFE8EAF6); // Indigo 50
  static const Color highlightIndigoBorder = Color(0xFFC5CAE9); // Indigo 100

  // Marketplace Specific
  static const Color marketplaceBlue = Color(0xFF007BFF);
  static const Color negotiableBg = Color(0xFFE8F1FF);
  static const Color verifiedSellerBg = Color(0xFFE8F5E9);
  static const Color verifiedSellerIcon = Color(0xFF4CAF50);
  static const Color safetyBannerBg = Color(0xFFF1F7FF);
}
