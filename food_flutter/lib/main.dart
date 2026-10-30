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
                  const Icon(Icons.info_outline, size: 44, color: AppColors.primary),
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
        return MaterialApp(
          title: 'MyFoodDiary',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

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
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt, color: AppColors.primary, size: 24),
                ),
                title: Text(
                  'Сделать снимок (Камера)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 15),
                ),
                subtitle: Text(
                  'Открыть камеру устройства',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppColors.primary),
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
                    color: AppColors.emerald500.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: AppColors.emerald500, size: 24),
                ),
                title: Text(
                  'Выбрать из галереи',
                  style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 15),
                ),
                subtitle: Text(
                  'Загрузить фото из памяти телефона',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppColors.emerald500),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
      backgroundColor: isDark ? AppColors.darkBgBottom : AppColors.lightScaffold,
      body: AppScreenBackground(
        child: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBgBottom : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabSelected,
          backgroundColor: isDark ? AppColors.darkBgBottom : Colors.white,
          elevation: 0,
          indicatorColor: AppColors.primary.withOpacity(0.18),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today, color: AppColors.primary),
              label: 'Дневник',
            ),
            NavigationDestination(
              icon: Icon(Icons.camera_alt_outlined),
              selectedIcon: Icon(Icons.camera_alt, color: AppColors.primary),
              label: 'Фото',
            ),
            NavigationDestination(
              icon: Icon(Icons.restaurant_menu_outlined),
              selectedIcon: Icon(Icons.restaurant_menu, color: AppColors.primary),
              label: 'Рецепты',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppColors.primary),
              label: 'Профиль',
            ),
          ],
        ),
      ),
    );
  }
}
