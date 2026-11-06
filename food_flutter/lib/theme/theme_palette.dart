import 'package:flutter/material.dart';

/// Available visual theme palettes for MyFoodDiary
enum AppThemePalette {
  cyberSapphire(
    'cyber_sapphire',
    'Cyber Sapphire',
    '💎',
    'Королевский сапфир, неон и матовое стекло',
  ),
  bioForest(
    'bio_forest',
    'Bio-Forest',
    '🌿',
    'Хвойный сланец, золотая олива и шалфей',
  ),
  neoObsidian(
    'neo_obsidian',
    'Neo-Obsidian',
    '⚡',
    'OLED True Black и неоновая мята',
  ),
  sunsetAmethyst(
    'sunset_amethyst',
    'Sunset Amethyst',
    '🌅',
    'Аметистовый космос и коралловый закат',
  );

  final String id;
  final String title;
  final String emoji;
  final String description;

  const AppThemePalette(this.id, this.title, this.emoji, this.description);

  static AppThemePalette fromString(String? val) {
    if (val == null) return AppThemePalette.cyberSapphire;
    for (final p in AppThemePalette.values) {
      if (p.id == val) return p;
    }
    return AppThemePalette.cyberSapphire;
  }
}

/// Dynamic theme tokens provided via ThemeExtension for seamless reactive updates
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  final AppThemePalette palette;
  final bool isDark;

  final Color primary;
  final Color primaryRoyal;
  final Color primaryDark;
  final Color primaryLight;

  final Color bgTop;
  final Color bgMiddle;
  final Color bgBottom;

  final Color canvasBg;
  final Color surfaceBg;
  final Color cardBg;
  final Color cardBorder;
  final Color inputBg;

  final Color textPrimary;
  final Color textSecondary;

  final Color macroCalorie;
  final Color macroCalorieLight;
  final Color macroCalorieDark;

  final Color macroProtein;
  final Color macroFat;
  final Color macroCarb;

  final LinearGradient backgroundGradient;

  const AppThemeTokens({
    required this.palette,
    required this.isDark,
    required this.primary,
    required this.primaryRoyal,
    required this.primaryDark,
    required this.primaryLight,
    required this.bgTop,
    required this.bgMiddle,
    required this.bgBottom,
    required this.canvasBg,
    required this.surfaceBg,
    required this.cardBg,
    required this.cardBorder,
    required this.inputBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.macroCalorie,
    required this.macroCalorieLight,
    required this.macroCalorieDark,
    required this.macroProtein,
    required this.macroFat,
    required this.macroCarb,
    required this.backgroundGradient,
  });

  static AppThemeTokens _active = AppThemeTokens.forPalette(AppThemePalette.cyberSapphire, isDark: true);
  static AppThemeTokens get active => _active;

  static void setActive(AppThemePalette palette, bool isDark) {
    _active = AppThemeTokens.forPalette(palette, isDark: isDark);
  }

  static AppThemeTokens of(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeTokens>();
    if (ext != null) return ext;
    return _active;
  }

  static AppThemeTokens forPalette(AppThemePalette palette, {required bool isDark}) {
    if (!isDark) {
      // Light Mode (harmonized across all palettes with palette-specific primary accents)
      Color lightPrimary;
      Color lightPrimaryRoyal;
      Color lightPrimaryDark;
      Color lightPrimaryLight;

      switch (palette) {
        case AppThemePalette.bioForest:
          lightPrimary = const Color(0xFF65A30D); // Olive green
          lightPrimaryRoyal = const Color(0xFF4D7C0F);
          lightPrimaryDark = const Color(0xFF365314);
          lightPrimaryLight = const Color(0xFFF7FEE7);
          break;
        case AppThemePalette.neoObsidian:
          lightPrimary = const Color(0xFF059669); // Emerald
          lightPrimaryRoyal = const Color(0xFF047857);
          lightPrimaryDark = const Color(0xFF064E3B);
          lightPrimaryLight = const Color(0xFFECFDF5);
          break;
        case AppThemePalette.sunsetAmethyst:
          lightPrimary = const Color(0xFF9333EA); // Amethyst
          lightPrimaryRoyal = const Color(0xFF7E22CE);
          lightPrimaryDark = const Color(0xFF581C87);
          lightPrimaryLight = const Color(0xFFFAF5FF);
          break;
        case AppThemePalette.cyberSapphire:
        default:
          lightPrimary = const Color(0xFF2563EB); // Royal Sapphire
          lightPrimaryRoyal = const Color(0xFF1D4ED8);
          lightPrimaryDark = const Color(0xFF1E40AF);
          lightPrimaryLight = const Color(0xFFEFF6FF);
          break;
      }

      return AppThemeTokens(
        palette: palette,
        isDark: false,
        primary: lightPrimary,
        primaryRoyal: lightPrimaryRoyal,
        primaryDark: lightPrimaryDark,
        primaryLight: lightPrimaryLight,
        bgTop: const Color(0xFFF8FAFC),
        bgMiddle: const Color(0xFFF1F5F9),
        bgBottom: const Color(0xFFF8FAFC),
        canvasBg: const Color(0xFFF8FAFC),
        surfaceBg: Colors.white,
        cardBg: Colors.white,
        cardBorder: const Color(0xFFE2E8F0),
        inputBg: const Color(0xFFF1F5F9),
        textPrimary: const Color(0xFF0F172A),
        textSecondary: const Color(0xFF64748B),
        macroCalorie: const Color(0xFFF97316),
        macroCalorieLight: const Color(0xFFFB923C),
        macroCalorieDark: const Color(0xFFEA580C),
        macroProtein: const Color(0xFF6366F1),
        macroFat: const Color(0xFFF59E0B),
        macroCarb: const Color(0xFF14B8A6),
        backgroundGradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
        ),
      );
    }

    // Dark Mode definitions for each palette
    switch (palette) {
      case AppThemePalette.bioForest:
        // Концепт 3: Organic Wellness & Golden Olive
        const bgTop = Color(0xFF1B2E21);     // Темный хвойно-моховой сланец
        const bgMiddle = Color(0xFF122017);  // Глубокий лесной полутон
        const bgBottom = Color(0xFF0A120D);  // Глубокая полуночная хвоя
        return const AppThemeTokens(
          palette: AppThemePalette.bioForest,
          isDark: true,
          primary: Color(0xFF84CC16),         // Теплый лайм / золотистая олива (#84CC16)
          primaryRoyal: Color(0xFF65A30D),    // Насыщенная олива
          primaryDark: Color(0xFF4D7C0F),     // Хвойный темно-зеленый
          primaryLight: Color(0xFFF7FEE7),
          bgTop: bgTop,
          bgMiddle: bgMiddle,
          bgBottom: bgBottom,
          canvasBg: Color(0xFF0A120D),
          surfaceBg: Color(0xFF0F1A13),
          cardBg: Color(0xFF15241B),          // Темно-моховой сланец
          cardBorder: Color(0xFF243B2D),      // Приглушенная хвоя
          inputBg: Color(0xFF101B14),
          textPrimary: Color(0xFFF4FBF5),
          textSecondary: Color(0xFF98AA9D),
          macroCalorie: Color(0xFF84CC16),    // Золотая олива
          macroCalorieLight: Color(0xFFA3E635),
          macroCalorieDark: Color(0xFF65A30D),
          macroProtein: Color(0xFF4ADE80),    // Фисташково-мятный
          macroFat: Color(0xFFEAB308),        // Теплый янтарный орех
          macroCarb: Color(0xFF2DD4BF),       // Травяной шалфей / бирюза
          backgroundGradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgTop, bgMiddle, bgBottom],
            stops: [0.0, 0.45, 1.0],
          ),
        );

      case AppThemePalette.neoObsidian:
        // Концепт 1: OLED Minimal & Neon Mint
        const bgTop = Color(0xFF080D0A);
        const bgMiddle = Color(0xFF040605);
        const bgBottom = Color(0xFF000000);   // True OLED Black
        return const AppThemeTokens(
          palette: AppThemePalette.neoObsidian,
          isDark: true,
          primary: Color(0xFF10B981),         // Неоновый изумруд / мята (#10B981)
          primaryRoyal: Color(0xFF059669),
          primaryDark: Color(0xFF047857),
          primaryLight: Color(0xFFECFDF5),
          bgTop: bgTop,
          bgMiddle: bgMiddle,
          bgBottom: bgBottom,
          canvasBg: Color(0xFF000000),
          surfaceBg: Color(0xFF070B09),
          cardBg: Color(0xFF0D1411),          // Обсидиан
          cardBorder: Color(0xFF1A2A22),      // Мятно-зеленый контур
          inputBg: Color(0xFF090E0C),
          textPrimary: Color(0xFFF9FAFB),
          textSecondary: Color(0xFF9CA3AF),
          macroCalorie: Color(0xFF10B981),
          macroCalorieLight: Color(0xFF34D399),
          macroCalorieDark: Color(0xFF059669),
          macroProtein: Color(0xFF38BDF8),
          macroFat: Color(0xFFFBBF24),
          macroCarb: Color(0xFF2DD4BF),
          backgroundGradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgTop, bgMiddle, bgBottom],
            stops: [0.0, 0.45, 1.0],
          ),
        );

      case AppThemePalette.sunsetAmethyst:
        // Концепт 4: Dynamic Athletic & Sunset Amethyst
        const bgTop = Color(0xFF241634);     // Космический темный аметист
        const bgMiddle = Color(0xFF170E22);
        const bgBottom = Color(0xFF0D0715);
        return const AppThemeTokens(
          palette: AppThemePalette.sunsetAmethyst,
          isDark: true,
          primary: Color(0xFFA855F7),         // Электрический аметист (#A855F7)
          primaryRoyal: Color(0xFF9333EA),
          primaryDark: Color(0xFF7E22CE),
          primaryLight: Color(0xFFFAF5FF),
          bgTop: bgTop,
          bgMiddle: bgMiddle,
          bgBottom: bgBottom,
          canvasBg: Color(0xFF0D0715),
          surfaceBg: Color(0xFF130B1E),
          cardBg: Color(0xFF1E132D),          // Обсидиановый аметист
          cardBorder: Color(0xFF36224E),      // Неоновый пурпурный кант
          inputBg: Color(0xFF150C22),
          textPrimary: Color(0xFFFDF4FF),
          textSecondary: Color(0xFFA89BB9),
          macroCalorie: Color(0xFFFF5E62),    // Коралловый фламинго
          macroCalorieLight: Color(0xFFFF7E82),
          macroCalorieDark: Color(0xFF9333EA),
          macroProtein: Color(0xFF818CF8),
          macroFat: Color(0xFFFB7185),
          macroCarb: Color(0xFF38BDF8),
          backgroundGradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgTop, bgMiddle, bgBottom],
            stops: [0.0, 0.45, 1.0],
          ),
        );

      case AppThemePalette.cyberSapphire:
      default:
        // Концепт 2: Флагманский Cyber Sapphire & Glass
        const bgTop = Color(0xFF22354A);     // Мягкий стальной темно-синий
        const bgMiddle = Color(0xFF182232);  // Глубокий синий переходный
        const bgBottom = Color(0xFF0F131D);  // Глубокая темно-синяя ночь
        return const AppThemeTokens(
          palette: AppThemePalette.cyberSapphire,
          isDark: true,
          primary: Color(0xFF3B82F6),         // Vibrant Sapphire (#3B82F6)
          primaryRoyal: Color(0xFF2563EB),    // Rich Royal Blue (#2563EB)
          primaryDark: Color(0xFF1D4ED8),
          primaryLight: Color(0xFFEFF6FF),
          bgTop: bgTop,
          bgMiddle: bgMiddle,
          bgBottom: bgBottom,
          canvasBg: Color(0xFF0F131D),
          surfaceBg: Color(0xFF141A26),
          cardBg: Color(0xFF1E2638),          // Стальной сапфир
          cardBorder: Color(0xFF2D374D),
          inputBg: Color(0xFF182030),
          textPrimary: Color(0xFFF8FAFC),
          textSecondary: Color(0xFF94A3B8),
          macroCalorie: Color(0xFFF97316),    // Кораллово-оранжевый
          macroCalorieLight: Color(0xFFFB923C),
          macroCalorieDark: Color(0xFFEA580C),
          macroProtein: Color(0xFF6366F1),    // Индиго-синий
          macroFat: Color(0xFFF59E0B),        // Теплый янтарь
          macroCarb: Color(0xFF14B8A6),       // Бирюзовый
          backgroundGradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgTop, bgMiddle, bgBottom],
            stops: [0.0, 0.45, 1.0],
          ),
        );
    }
  }

  @override
  AppThemeTokens copyWith({
    AppThemePalette? palette,
    bool? isDark,
    Color? primary,
    Color? primaryRoyal,
    Color? primaryDark,
    Color? primaryLight,
    Color? bgTop,
    Color? bgMiddle,
    Color? bgBottom,
    Color? canvasBg,
    Color? surfaceBg,
    Color? cardBg,
    Color? cardBorder,
    Color? inputBg,
    Color? textPrimary,
    Color? textSecondary,
    Color? macroCalorie,
    Color? macroCalorieLight,
    Color? macroCalorieDark,
    Color? macroProtein,
    Color? macroFat,
    Color? macroCarb,
    LinearGradient? backgroundGradient,
  }) {
    return AppThemeTokens(
      palette: palette ?? this.palette,
      isDark: isDark ?? this.isDark,
      primary: primary ?? this.primary,
      primaryRoyal: primaryRoyal ?? this.primaryRoyal,
      primaryDark: primaryDark ?? this.primaryDark,
      primaryLight: primaryLight ?? this.primaryLight,
      bgTop: bgTop ?? this.bgTop,
      bgMiddle: bgMiddle ?? this.bgMiddle,
      bgBottom: bgBottom ?? this.bgBottom,
      canvasBg: canvasBg ?? this.canvasBg,
      surfaceBg: surfaceBg ?? this.surfaceBg,
      cardBg: cardBg ?? this.cardBg,
      cardBorder: cardBorder ?? this.cardBorder,
      inputBg: inputBg ?? this.inputBg,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      macroCalorie: macroCalorie ?? this.macroCalorie,
      macroCalorieLight: macroCalorieLight ?? this.macroCalorieLight,
      macroCalorieDark: macroCalorieDark ?? this.macroCalorieDark,
      macroProtein: macroProtein ?? this.macroProtein,
      macroFat: macroFat ?? this.macroFat,
      macroCarb: macroCarb ?? this.macroCarb,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
    );
  }

  @override
  AppThemeTokens lerp(ThemeExtension<AppThemeTokens>? other, double t) {
    if (other is! AppThemeTokens) return this;
    return AppThemeTokens(
      palette: t < 0.5 ? palette : other.palette,
      isDark: t < 0.5 ? isDark : other.isDark,
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      primaryRoyal: Color.lerp(primaryRoyal, other.primaryRoyal, t) ?? primaryRoyal,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t) ?? primaryDark,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t) ?? primaryLight,
      bgTop: Color.lerp(bgTop, other.bgTop, t) ?? bgTop,
      bgMiddle: Color.lerp(bgMiddle, other.bgMiddle, t) ?? bgMiddle,
      bgBottom: Color.lerp(bgBottom, other.bgBottom, t) ?? bgBottom,
      canvasBg: Color.lerp(canvasBg, other.canvasBg, t) ?? canvasBg,
      surfaceBg: Color.lerp(surfaceBg, other.surfaceBg, t) ?? surfaceBg,
      cardBg: Color.lerp(cardBg, other.cardBg, t) ?? cardBg,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t) ?? cardBorder,
      inputBg: Color.lerp(inputBg, other.inputBg, t) ?? inputBg,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      macroCalorie: Color.lerp(macroCalorie, other.macroCalorie, t) ?? macroCalorie,
      macroCalorieLight: Color.lerp(macroCalorieLight, other.macroCalorieLight, t) ?? macroCalorieLight,
      macroCalorieDark: Color.lerp(macroCalorieDark, other.macroCalorieDark, t) ?? macroCalorieDark,
      macroProtein: Color.lerp(macroProtein, other.macroProtein, t) ?? macroProtein,
      macroFat: Color.lerp(macroFat, other.macroFat, t) ?? macroFat,
      macroCarb: Color.lerp(macroCarb, other.macroCarb, t) ?? macroCarb,
      backgroundGradient: t < 0.5 ? backgroundGradient : other.backgroundGradient,
    );
  }
}
