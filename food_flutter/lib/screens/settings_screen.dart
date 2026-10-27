import 'package:flutter/material.dart';
import '../models/meal_models.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsService settingsService;
  final ApiService apiService;

  const SettingsScreen({
    super.key,
    required this.settingsService,
    required this.apiService,
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

  bool _isTesting = false;
  bool _showApiKey = false;
  HealthCheckResult? _healthResult;

  @override
  void initState() {
    super.initState();
    _loadSettings();
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

    // Синхронизация с сервером: если на бэкенде уже сохранены цели, подтягиваем их
    try {
      final remoteGoals = await widget.apiService.getGoals();
      if (mounted) {
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
        );
      }
    } catch (_) {
      // Сервер пока оффлайн или не настроен — используем локальные настройки
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
    final cal = double.tryParse(_calController.text.replaceAll(',', '.')) ?? 2000;
    final p = double.tryParse(_proteinController.text.replaceAll(',', '.')) ?? 90;
    final f = double.tryParse(_fatController.text.replaceAll(',', '.')) ?? 65;
    final c = double.tryParse(_carbsController.text.replaceAll(',', '.')) ?? 250;

    // Сначала сохраняем локально
    await widget.settingsService.saveLocalGoals(cal, p, f, c);

    // Затем сохраняем в базу данных на сервере
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
      // Сервер оффлайн — настройки сохранены локально
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(syncedWithServer
              ? 'Суточные цели КБЖУ сохранены на сервере в базе! ☁️✅'
              : 'Суточные цели КБЖУ сохранены локально! 📱✅'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Настройки',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Server Connection Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.dns_outlined, color: Color(0xFF10B981)),
                    SizedBox(width: 8),
                    Text(
                      'Подключение к бэкенду',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Укажите адрес вашего сервера FastAPI. Это может быть локальный IP компьютера в сети Wi-Fi или облачный адрес Google Cloud.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    labelText: 'URL бэкенда',
                    hintText: 'http://192.168.1.172:8000',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.link, color: Color(0xFF64748B)),
                  ),
                  onChanged: (_) => _saveUrl(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _apiKeyController,
                  obscureText: !_showApiKey,
                  decoration: InputDecoration(
                    labelText: 'Секретный API-ключ (для облака)',
                    hintText: 'Оставьте пустым для локального сервера',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.key, color: Color(0xFF64748B)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showApiKey ? Icons.visibility_off : Icons.visibility,
                        color: const Color(0xFF64748B),
                      ),
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering, color: Color(0xFF10B981)),
                    label: Text(
                      _isTesting ? 'Проверка связи...' : 'Проверить подключение',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                    ),
                    onPressed: _isTesting ? null : _testConnection,
                  ),
                ),
                if (_healthResult != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _healthResult!.isHealthy ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _healthResult!.isHealthy ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _healthResult!.isHealthy ? Icons.check_circle : Icons.error,
                          color: _healthResult!.isHealthy ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _healthResult!.message,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _healthResult!.isHealthy ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                ),
                              ),
                              if (_healthResult!.isHealthy)
                                Text(
                                  'Задержка: ${_healthResult!.latencyMs} мс',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF047857)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Daily Goals Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.flag_outlined, color: Color(0xFF10B981)),
                    SizedBox(width: 8),
                    Text(
                      'Суточные нормы КБЖУ',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _calController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Цель калорий (ккал)',
                    suffixText: 'ккал',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _proteinController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Белки',
                          suffixText: 'г',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _fatController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Жиры',
                          suffixText: 'г',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _carbsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Углеводы',
                          suffixText: 'г',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _saveGoals,
                    child: const Text('Сохранить цели КБЖУ', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // About App Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF10B981)),
                    SizedBox(width: 8),
                    Text(
                      'О приложении',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  'MyFoodDiary — мобильный клиент персональной системы распознавания блюд на базе ИИ Google Gemini Flash и SQLite дневника питания.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
                ),
                SizedBox(height: 8),
                Text(
                  'Архитектура: «Один бэкенд (FastAPI) — три клиента (Telegram, PWA, Flutter)».',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                ),
                SizedBox(height: 8),
                Text(
                  'Версия: 1.0.5 (Release APK)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
