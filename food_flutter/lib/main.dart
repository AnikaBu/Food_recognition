import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/api_service.dart';
import 'services/settings_service.dart';
import 'screens/diary_screen.dart';
import 'screens/recognize_screen.dart';
import 'screens/recipes_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'theme/theme_palette.dart';
import 'widgets/app_screen_background.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeDateFormatting('ru', null);
  } catch (_) {}

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Material(
          color: isDark ? AppColors.darkSurface : AppColors.lightScaffold,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 44, color: AppColors.primary),
                  const SizedBox(height: 12),
                  Text(
                    'Не удалось отобразить данные',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    details.exception.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  };

  final settingsService = SettingsService();
  await settingsService.init();
  final apiService = ApiService(settingsService: settingsService);

  runApp(FoodRecognitionApp(
    settingsService: settingsService,
    apiService: apiService,
  ));
}

class FoodRecognitionApp extends StatelessWidget {
  final SettingsService settingsService;
  final ApiService apiService;

  const FoodRecognitionApp({
    super.key,
    required this.settingsService,
    required this.apiService,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsService,
      builder: (context, _) {
        AppThemeTokens.setActive(
          settingsService.themePaletteEnum,
          settingsService.isDarkMode,
        );
        return MaterialApp(
          title: 'MyFoodDiary',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightThemeFor(settingsService.themePaletteEnum),
          darkTheme: AppTheme.darkThemeFor(settingsService.themePaletteEnum),
          themeMode: settingsService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: MainNavigationScreen(
            settingsService: settingsService,
            apiService: apiService,
          ),
        );
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final SettingsService settingsService;
  final ApiService apiService;

  const MainNavigationScreen({
    super.key,
    required this.settingsService,
    required this.apiService,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final GlobalKey<DiaryScreenState> _diaryKey = GlobalKey<DiaryScreenState>();
  final GlobalKey<RecipesScreenState> _recipesKey = GlobalKey<RecipesScreenState>();
  final GlobalKey<RecognizeScreenState> _recognizeKey = GlobalKey<RecognizeScreenState>();

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
    if (index == 0) {
      _diaryKey.currentState?.reloadGoalsAndData();
    } else if (index == 1) {
      _showPhotoSourceBottomSheet();
    } else if (index == 2) {
      _recipesKey.currentState?.loadRecipes();
    }
  }

  void _showPhotoSourceBottomSheet() {
    final tokens = AppThemeTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? tokens.cardBg : AppColors.lightCard;
    final border = isDark ? tokens.cardBorder : AppColors.lightBorder;
    final textPrimary = isDark ? tokens.textPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? tokens.textSecondary : AppColors.lightTextSecondary;

    final accentColor = isDark ? tokens.primary : tokens.primaryRoyal;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: border)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Добавить фото блюда',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Сделайте фото или выберите готовый снимок',
                style: TextStyle(fontSize: 13, color: textSecondary),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: border),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.camera_alt, color: accentColor, size: 24),
                ),
                title: Text(
                  'Сделать снимок (Камера)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 15),
                ),
                subtitle: Text(
                  'Открыть камеру устройства',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
                trailing: Icon(Icons.chevron_right, color: accentColor),
                onTap: () {
                  Navigator.pop(ctx);
                  _recognizeKey.currentState?.pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: border),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.photo_library_outlined, color: accentColor, size: 24),
                ),
                title: Text(
                  'Выбрать из галереи',
                  style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 15),
                ),
                subtitle: Text(
                  'Загрузить фото из памяти телефона',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
                trailing: Icon(Icons.chevron_right, color: accentColor),
                onTap: () {
                  Navigator.pop(ctx);
                  _recognizeKey.currentState?.pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccent = isDark ? tokens.primary : tokens.primaryRoyal;

    final screens = [
      DiaryScreen(
        key: _diaryKey,
        apiService: widget.apiService,
        settingsService: widget.settingsService,
        onNavigateToScan: () => _onTabSelected(1),
      ),
      RecognizeScreen(
        key: _recognizeKey,
        apiService: widget.apiService,
        onSavedSuccess: () => _onTabSelected(0),
      ),
      RecipesScreen(
        key: _recipesKey,
        apiService: widget.apiService,
        onMealLogged: () => _onTabSelected(0),
      ),
      SettingsScreen(
        settingsService: widget.settingsService,
        apiService: widget.apiService,
        onGoalsSaved: () => _diaryKey.currentState?.reloadGoalsAndData(),
      ),
    ];

    return Scaffold(
      backgroundColor: isDark ? tokens.bgBottom : AppColors.lightScaffold,
      body: AppScreenBackground(
        child: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? tokens.bgBottom : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? tokens.cardBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabSelected,
          backgroundColor: isDark ? tokens.bgBottom : Colors.white,
          elevation: 0,
          indicatorColor: primaryAccent.withOpacity(0.18),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today, color: primaryAccent),
              label: 'Дневник',
            ),
            NavigationDestination(
              icon: const Icon(Icons.camera_alt_outlined),
              selectedIcon: Icon(Icons.camera_alt, color: primaryAccent),
              label: 'Фото',
            ),
            NavigationDestination(
              icon: const Icon(Icons.restaurant_menu_outlined),
              selectedIcon: Icon(Icons.restaurant_menu, color: primaryAccent),
              label: 'Рецепты',
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: primaryAccent),
              label: 'Профиль',
            ),
          ],
        ),
      ),
    );
  }
}
