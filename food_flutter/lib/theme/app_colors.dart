import 'package:flutter/material.dart';
import 'theme_palette.dart';

/// Design tokens extracted directly from myfooddiary_prototype.html (Single Source of Truth)
class AppColors {
  // Dynamic primary brand colors (resolves automatically from active theme palette)
  static Color get primary => AppThemeTokens.active.primary;
  static Color get primaryDark => AppThemeTokens.active.primaryDark;
  static Color get primaryLight => AppThemeTokens.active.primaryLight;
  static Color get primaryRoyal => AppThemeTokens.active.primaryRoyal;
  static Color get sapphire300 => AppThemeTokens.active.primaryLight;
  static Color get sapphire400 => AppThemeTokens.active.primary;
  static Color get sapphire500 => AppThemeTokens.active.primary;
  static Color get sapphire600 => AppThemeTokens.active.primaryRoyal;

  // Backward-compatible aliases for legacy token references
  static Color get emerald400 => AppThemeTokens.active.primary;
  static Color get emerald500 => AppThemeTokens.active.primary;
  static const Color amber500 = Color(0xFFF59E0B);

  /// Returns the optimal primary variant based on active theme
  static Color primaryColor(bool isDark) => isDark ? primary : primaryRoyal;

  /// Returns active dynamic palette tokens for the given BuildContext
  static AppThemeTokens tokens(BuildContext context) => AppThemeTokens.of(context);

  // Macro Nutrients (Harmonized with active theme palette)
  static Color get macroCalorie => AppThemeTokens.active.macroCalorie;
  static Color get macroCalorieLight => AppThemeTokens.active.macroCalorieLight;
  static Color get macroCalorieDark => AppThemeTokens.active.macroCalorieDark;

  static Color get macroProtein => AppThemeTokens.active.macroProtein;
  static const Color macroProteinLight = Color(0xFF818CF8);

  static Color get macroFat => AppThemeTokens.active.macroFat;
  static const Color macroFatLight = Color(0xFFFBBF24);

  static Color get macroCarb => AppThemeTokens.active.macroCarb;
  static const Color macroCarbLight = Color(0xFF2DD4BF);

  // Light Mode Surfaces & Text
  static const Color lightScaffold = Color(0xFFF8FAFC);
  static const Color lightCard = Colors.white;
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderSubtle = Color(0xFFF1F5F9);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightInput = Color(0xFFF1F5F9);

  // Dark Mode Background Gradient (dynamically resolved from active theme)
  static Color get darkBgTop => AppThemeTokens.active.bgTop;
  static Color get darkBgMiddle => AppThemeTokens.active.bgMiddle;
  static Color get darkBgBottom => AppThemeTokens.active.bgBottom;

  static LinearGradient get darkBackgroundGradient => AppThemeTokens.active.backgroundGradient;

  // Dark Mode Surfaces & Text (dynamically resolved from active theme)
  static Color get darkCanvas => AppThemeTokens.active.canvasBg;
  static Color get darkSurface => AppThemeTokens.active.surfaceBg;
  static Color get darkCard => AppThemeTokens.active.cardBg;
  static Color get darkBorder => AppThemeTokens.active.cardBorder;
  static Color get darkInput => AppThemeTokens.active.inputBg;
  static Color get darkTextPrimary => AppThemeTokens.active.textPrimary;
  static Color get darkTextSecondary => AppThemeTokens.active.textSecondary;

  // Category Icon Accents
  static const Color catBreakfastBg = Color(0xFFFEF3C7);
  static const Color catBreakfastText = Color(0xFFD97706);
  static const Color catLunchBg = Color(0xFFD1FAE5);
  static const Color catLunchText = Color(0xFF059669);
  static const Color catDinnerBg = Color(0xFFE0E7FF);
  static const Color catDinnerText = Color(0xFF4F46E5);
  static const Color catSnackBg = Color(0xFFCCFBF1);
  static const Color catSnackText = Color(0xFF0D9488);

  // Accents & Badges
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
}
