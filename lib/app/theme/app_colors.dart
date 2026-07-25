import 'package:flutter/material.dart';

/// Centralized color palette for Ulify.
/// Modern Teal/Turquoise Brand Identity.
class AppColors {
  AppColors._();

  // Primary Palette (Modern Teal)
  static const Color primary = Color(0xFF14B8A6);    // Teal 500
  static const Color primaryDark = Color(0xFF0F766E); // Teal 700
  
  // Secondary & Accents
  static const Color secondary = Color(0xFF0F766E);  // Dark Teal
  static const Color secondaryDark = Color(0xFF042F2E); // Teal 900
  static const Color accent = Color(0xFFF59E0B);     // Amber 500 (Highlights)
  
  // Backgrounds
  static const Color backgroundLight = Color(0xFFF8FAFC); // Off-white
  static const Color backgroundDark = Color(0xFF0F172A);  // Slate 900
  static const Color scaffoldLight = Color(0xFFF8FAFC);
  
  // Surface Colors
  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF1E293B); // Slate 800
  
  // Neutral Colors (Charcoal/Slate)
  static const Color white = Colors.white;
  static const Color black = Color(0xFF1F2937); // Charcoal
  static const Color textMain = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF4B5563); // Gray 600
  
  static const Color grey = Color(0xFF94A3B8); // Slate 400
  static const Color grey50 = Color(0xFFF8FAFC);
  static const Color grey100 = Color(0xFFF1F5F9);
  static const Color grey200 = Color(0xFFE2E8F0);
  static const Color grey300 = Color(0xFFCBD5E1);
  static const Color grey400 = Color(0xFF94A3B8);
  static const Color grey500 = Color(0xFF64748B);
  static const Color grey600 = Color(0xFF475569);
  
  // Status Colors (Matching Tailwind/Modern standards)
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF0EA5E9);

  // Business Branding
  static const Color business = Color(0xFF0F766E);    // Dark Teal
  static const Color businessGold = Color(0xFFF59E0B); // Amber/Gold

  // Category & Brand Shades (Tuned to Teal palette)
  static const Color notes = Color(0xFF0D9488);       // Teal 600
  static const Color marketplace = Color(0xFFF59E0B); // Amber (Accent)
  static const Color housing = Color(0xFF14B8A6);     // Primary Teal
  static const Color gigs = Color(0xFF0F766E);        // Dark Teal
  static const Color community = Color(0xFF2DD4BF);   // Teal 400

  // Highlight Colors
  static const Color highlightAmberBg = Color(0xFFFFFBEB); // Amber 50
  static const Color highlightAmberBorder = Color(0xFFFEF3C7); // Amber 100
  static const Color highlightTealBg = Color(0xFFF0FDFA); // Teal 50
  static const Color highlightTealBorder = Color(0xFFCCFBF1); // Teal 100

  // Marketplace Specific
  static const Color marketplaceAccent = Color(0xFFF59E0B);
  static const Color negotiableBg = Color(0xFFF0FDFA);
  static const Color verifiedSellerBg = Color(0xFFF0FDF4);
  static const Color verifiedSellerIcon = Color(0xFF22C55E);
  static const Color safetyBannerBg = Color(0xFFF8FAFC);
}
