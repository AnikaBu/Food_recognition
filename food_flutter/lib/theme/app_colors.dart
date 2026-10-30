import 'package:flutter/material.dart';

/// Design tokens extracted directly from myfooddiary_prototype.html (Single Source of Truth)
class AppColors {
  // Brand Emerald
  static const Color primary = Color(0xFF10B981);
  static const Color primaryDark = Color(0xFF059669);
  static const Color primaryLight = Color(0xFFECFDF5);
  static const Color emerald400 = Color(0xFF34D399);

  // Macro Nutrients (Exact prototype mapping)
  static const Color macroCalorie = Color(0xFFF97316); // Coral-orange
  static const Color macroCalorieLight = Color(0xFFFB923C);
  static const Color macroCalorieDark = Color(0xFFEA580C);

  static const Color macroProtein = Color(0xFF6366F1); // Indigo-blue
  static const Color macroProteinLight = Color(0xFF818CF8);

  static const Color macroFat = Color(0xFFF59E0B); // Warm amber
  static const Color macroFatLight = Color(0xFFFBBF24);

  static const Color macroCarb = Color(0xFF14B8A6); // Mint-teal
  static const Color macroCarbLight = Color(0xFF2DD4BF);

  // Light Mode Surfaces & Text
  static const Color lightScaffold = Color(0xFFF8FAFC);
  static const Color lightCard = Colors.white;
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderSubtle = Color(0xFFF1F5F9);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightInput = Color(0xFFF1F5F9);

  // Dark Mode Background Gradient (from lighter steel-navy at top to deep midnight-navy at bottom)
  static const Color darkBgTop = Color(0xFF22354A);     // Мягкий стальной темно-синий (#22354A)
  static const Color darkBgMiddle = Color(0xFF182232);  // Глубокий синий переходный (#182232)
  static const Color darkBgBottom = Color(0xFF0F131D);  // Глубокая темно-синяя ночь (#0F131D)

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [darkBgTop, darkBgMiddle, darkBgBottom],
    stops: [0.0, 0.45, 1.0],
  );

  // Dark Mode Surfaces & Text (Harmonized with the steel-navy gradient)
  static const Color darkCanvas = Color(0xFF0F131D);
  static const Color darkSurface = Color(0xFF141A26);
  static const Color darkCard = Color(0xFF1E2638);
  static const Color darkBorder = Color(0xFF2D374D);
  static const Color darkInput = Color(0xFF182030);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

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
