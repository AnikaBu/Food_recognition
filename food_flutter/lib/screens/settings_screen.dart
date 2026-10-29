import 'package:flutter/material.dart';
import '../models/meal_models.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsService settingsService;
  final ApiService apiService;
  final VoidCallback? onGoalsSaved;

  const SettingsScreen({
    super.key,
    required this.settingsService,
    required this.apiService,
    this.onGoalsSaved,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _calController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();

  final UpdateService _updateService = UpdateService();
  bool _isCheckingUpdate = false;
  bool _isTesting = false;
  bool _showApiKey = false;
  HealthCheckResult? _healthResult;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    _calController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _carbsController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final url = await widget.settingsService.getServerUrl();
    final apiKey = await widget.settingsService.getApiKey();
    final cal = await widget.settingsService.getTargetCalories();
    final p = await widget.settingsService.getTargetProtein();
    final f = await widget.settingsService.getTargetFat();
    final c = await widget.settingsService.getTargetCarbs();

    if (mounted) {
      setState(() {
        _urlController.text = url;
        _apiKeyController.text = apiKey;
        _calController.text = cal.toStringAsFixed(0);
        _proteinController.text = p.toStringAsFixed(0);
        _fatController.text = f.toStringAsFixed(0);
        _carbsController.text = c.toStringAsFixed(0);
      });
    }

    if (!widget.settingsService.hasCustomGoals) {
      try {
        final remoteGoals = await widget.apiService.getGoals();
        if (mounted && !widget.settingsService.hasCustomGoals && remoteGoals.calories > 0) {
          setState(() {
            _calController.text = remoteGoals.calories.toStringAsFixed(0);
            _proteinController.text = remoteGoals.protein.toStringAsFixed(0);
            _fatController.text = remoteGoals.fat.toStringAsFixed(0);
            _carbsController.text = remoteGoals.carbs.toStringAsFixed(0);
          });
          await widget.settingsService.saveLocalGoals(
            remoteGoals.calories,
            remoteGoals.protein,
            remoteGoals.fat,
            remoteGoals.carbs,
            isExplicitUserAction: false,
          );
        }
      } catch (_) {}
    }
  }

  Future<void> _saveUrl() async {
    final clean = _urlController.text.trim();
    if (clean.isEmpty) return;
    await widget.settingsService.setServerUrl(clean);
  }

  Future<void> _saveApiKey() async {
    await widget.settingsService.setApiKey(_apiKeyController.text.trim());
  }

  Future<void> _testConnection() async {
    await _saveUrl();
    await _saveApiKey();
    setState(() {
      _isTesting = true;
      _healthResult = null;
    });

    final res = await widget.apiService.checkHealth();
    if (mounted) {
      setState(() {
        _isTesting = false;
        _healthResult = res;
      });
    }
  }

  Future<void> _saveGoals() async {
    final cal = double.tryParse(_calController.text.replaceAll(',', '.')) ?? widget.settingsService.targetCalories;
    final p = double.tryParse(_proteinController.text.replaceAll(',', '.')) ?? widget.settingsService.targetProtein;
    final f = double.tryParse(_fatController.text.replaceAll(',', '.')) ?? widget.settingsService.targetFat;
    final c = double.tryParse(_carbsController.text.replaceAll(',', '.')) ?? widget.settingsService.targetCarbs;

    // 1. Фиксируем в локальном хранилище устройства с флагом isExplicitUserAction = true
    await widget.settingsService.saveLocalGoals(
      cal, p, f, c,
      isExplicitUserAction: true,
    );
    widget.onGoalsSaved?.call();

    // 2. Отправляем обновленные цели на сервер в SQLite базу
    bool syncedWithServer = false;
    try {
      await widget.apiService.updateGoals(NutritionGoals(
        calories: cal,
        protein: p,
        fat: f,
        carbs: c,
      ));
      syncedWithServer = true;
    } catch (_) {
      // Сервер оффлайн — настройки сохранены локально в приложении
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(syncedWithServer
              ? 'Ваши новые цели КБЖУ сохранены в приложении и в базе! ☁️✅'
              : 'Ваши новые цели КБЖУ зафиксированы в приложении! 📱✅'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() => _isCheckingUpdate = true);
    final info = await _updateService.checkForUpdate();
    if (!mounted) return;
    setState(() => _isCheckingUpdate = false);

    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось связаться с сервером обновлений. Проверьте интернет. ⚠️'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (info.hasUpdate) {
      UpdateDialog.show(context, info, _updateService);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('У вас установлена актуальная версия v${info.currentVersion}! ✅'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final cardBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightScaffold,
      appBar: AppBar(
        title: const Text(
          'Цели & Профиль',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // 1. User Profile Badge Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.emerald400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'ДП',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Дневник питания',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Персональные цели и баланс КБЖУ',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 2. Target Nutrients Form (Суточный целевой баланс)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'СУТОЧНЫЙ ЦЕЛЕВОЙ БАЛАНС',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: textSecondary,
                      ),
                    ),
                    const Icon(Icons.fitness_center, size: 16, color: AppColors.primary),
                  ],
                ),
                const SizedBox(height: 14),

                // Calories Input
                Text(
                  'Норма калорий (ккал)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _calController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.macroCalorie,
                  ),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.local_fire_department, color: AppColors.macroCalorie),
                    suffixText: 'ккал/день',
                  ),
                ),

                const SizedBox(height: 12),

                // 3-Column Macros Grid
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.macroProtein, shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              Text('Белки (г)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _proteinController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.macroProtein),
                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.macroFat, shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              Text('Жиры (г)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _fatController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.macroFat),
                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.macroCarb, shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              Text('Углеводы (г)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _carbsController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.macroCarb),
                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _saveGoals,
                    child: const Text('Сохранить цели КБЖУ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 3. Theme Mode Switch Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode,
                      color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDark ? 'Тёмная тема оформления' : 'Светлая тема оформления',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                        Text(
                          isDark ? 'Глубокий ночной фон #0D131F' : 'Чистый светлый фон #F8FAFC',
                          style: TextStyle(fontSize: 11, color: textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                Switch(
                  value: isDark,
                  activeColor: AppColors.primary,
                  onChanged: (val) => widget.settingsService.setDarkMode(val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 4. Server Connection Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.dns_outlined, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Подключение к серверу',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'URL бэкенда',
                    hintText: 'http://192.168.1.100:8000',
                    prefixIcon: Icon(Icons.link),
                  ),
                  onChanged: (_) => _saveUrl(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _apiKeyController,
                  obscureText: !_showApiKey,
                  decoration: InputDecoration(
                    labelText: 'API-ключ (для облака)',
                    hintText: 'Оставьте пустым для локального сервера',
                    prefixIcon: const Icon(Icons.key),
                    suffixIcon: IconButton(
                      icon: Icon(_showApiKey ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _showApiKey = !_showApiKey),
                    ),
                  ),
                  onChanged: (_) => _saveApiKey(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering, color: AppColors.primary),
                    label: Text(
                      _isTesting ? 'Проверка связи...' : 'Проверить подключение',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    onPressed: _isTesting ? null : _testConnection,
                  ),
                ),
                if (_healthResult != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _healthResult!.isHealthy
                          ? (isDark ? AppColors.primary.withOpacity(0.15) : AppColors.primaryLight)
                          : (isDark ? const Color(0xFF2D1515) : const Color(0xFFFEF2F2)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _healthResult!.isHealthy
                            ? AppColors.primary.withOpacity(0.4)
                            : AppColors.error.withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _healthResult!.isHealthy ? Icons.check_circle : Icons.error,
                          color: _healthResult!.isHealthy ? AppColors.primary : AppColors.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _healthResult!.message,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _healthResult!.isHealthy ? AppColors.primaryDark : AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 5. System & Update Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Версия приложения', style: TextStyle(fontSize: 12, color: textSecondary)),
                    Text(UpdateService.currentVersion, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Нейросеть FoodVision AI', style: TextStyle(fontSize: 12, color: textSecondary)),
                    const Text('Gemini Vision v4.2', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      foregroundColor: AppColors.primary,
                    ),
                    icon: _isCheckingUpdate
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                        : const Icon(Icons.system_update_alt, size: 18),
                    label: Text(
                      _isCheckingUpdate ? 'Проверка...' : 'Проверить обновления',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: _isCheckingUpdate ? null : _checkForUpdates,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
