import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/api_service.dart';
import 'services/settings_service.dart';
import 'screens/diary_screen.dart';
import 'screens/recognize_screen.dart';
import 'screens/recipes_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

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
    return Material(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 44, color: AppColors.primary),
              const SizedBox(height: 12),
              const Text(
                'Не удалось отобразить данные',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Text(
                details.exception.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
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

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
    if (index == 0) {
      _diaryKey.currentState?.reloadGoalsAndData();
    } else if (index == 2) {
      _recipesKey.currentState?.loadRecipes();
    }
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
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
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
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
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
              label: 'Сканер',
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
