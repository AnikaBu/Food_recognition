import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'theme_palette.dart';

class AppTheme {
  static ThemeData get lightTheme => lightThemeFor(AppThemePalette.cyberSapphire);

  static ThemeData get darkTheme => darkThemeFor(AppThemePalette.cyberSapphire);

  static ThemeData lightThemeFor(AppThemePalette palette) {
    final tokens = AppThemeTokens.forPalette(palette, isDark: false);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: tokens.primaryRoyal,
      scaffoldBackgroundColor: AppColors.lightScaffold,
      extensions: [tokens],
      colorScheme: ColorScheme.light(
        primary: tokens.primaryRoyal,
        secondary: tokens.primaryDark,
        surface: AppColors.lightCard,
        onSurface: AppColors.lightTextPrimary,
        onSurfaceVariant: AppColors.lightTextSecondary,
        outline: AppColors.lightBorder,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.lightTextPrimary),
        bodyMedium: TextStyle(color: AppColors.lightTextPrimary),
        bodySmall: TextStyle(color: AppColors.lightTextSecondary),
        titleLarge: TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: AppColors.lightTextSecondary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.lightBorder),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.primaryRoyal,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.lightBorder),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.lightTextSecondary,
          fontSize: 14,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.lightCard,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppColors.lightScaffold,
        headerForegroundColor: AppColors.lightTextPrimary,
        dividerColor: AppColors.lightBorder,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.lightBorder),
        ),
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: tokens.primaryRoyal),
        confirmButtonStyle: TextButton.styleFrom(foregroundColor: tokens.primaryRoyal),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightInput,
        selectedColor: tokens.primaryRoyal,
        labelStyle: const TextStyle(color: AppColors.lightTextSecondary),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        side: const BorderSide(color: AppColors.lightBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightInput,
        hintStyle: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 13),
        labelStyle: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 13),
        helperStyle: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.primaryRoyal, width: 1.5),
        ),
      ),
    );
  }

  static ThemeData darkThemeFor(AppThemePalette palette) {
    final tokens = AppThemeTokens.forPalette(palette, isDark: true);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: tokens.primary,
      scaffoldBackgroundColor: tokens.bgBottom,
      extensions: [tokens],
      colorScheme: ColorScheme.dark(
        primary: tokens.primary,
        secondary: tokens.primaryLight,
        surface: tokens.cardBg,
        onSurface: tokens.textPrimary,
        onSurfaceVariant: tokens.textSecondary,
        outline: tokens.cardBorder,
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: tokens.textPrimary),
        bodyMedium: TextStyle(color: tokens.textPrimary),
        bodySmall: TextStyle(color: tokens.textSecondary),
        titleLarge: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: tokens.textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: tokens.textPrimary),
        titleTextStyle: TextStyle(
          color: tokens.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: tokens.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: tokens.cardBorder),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: tokens.cardBorder),
        ),
        titleTextStyle: TextStyle(
          color: tokens.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: tokens.textSecondary,
          fontSize: 14,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.cardBg,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: tokens.cardBg,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: tokens.bgTop,
        headerForegroundColor: tokens.textPrimary,
        dividerColor: tokens.cardBorder,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: tokens.cardBorder),
        ),
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: tokens.primary),
        confirmButtonStyle: TextButton.styleFrom(foregroundColor: tokens.primary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.inputBg,
        selectedColor: tokens.primary,
        labelStyle: TextStyle(color: tokens.textSecondary),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        side: BorderSide(color: tokens.cardBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.inputBg,
        hintStyle: TextStyle(color: tokens.textSecondary, fontSize: 13),
        labelStyle: TextStyle(color: tokens.textSecondary, fontSize: 13),
        helperStyle: TextStyle(color: tokens.textSecondary, fontSize: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.primary, width: 1.5),
        ),
      ),
    );
  }
}
