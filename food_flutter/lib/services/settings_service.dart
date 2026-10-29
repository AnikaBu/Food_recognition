import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static const String _keyServerUrl = 'server_url';
  static const String _keyApiKey = 'api_key';
  static const String _keyTargetCalories = 'target_calories';
  static const String _keyTargetProtein = 'target_protein';
  static const String _keyTargetFat = 'target_fat';
  static const String _keyTargetCarbs = 'target_carbs';
  static const String _keyHasCustomGoals = 'has_user_custom_goals';

  static const String defaultServerUrl = 'http://192.168.1.100:8000';
  static const double defaultTargetCalories = 2000.0;
  static const double defaultTargetProtein = 90.0;
  static const double defaultTargetFat = 65.0;
  static const double defaultTargetCarbs = 250.0;

  double _cachedCalories = defaultTargetCalories;
  double _cachedProtein = defaultTargetProtein;
  double _cachedFat = defaultTargetFat;
  double _cachedCarbs = defaultTargetCarbs;
  bool _hasCustomGoals = false;
  bool _initialized = false;

  double get targetCalories => _cachedCalories;
  double get targetProtein => _cachedProtein;
  double get targetFat => _cachedFat;
  double get targetCarbs => _cachedCarbs;
  bool get hasCustomGoals => _hasCustomGoals;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _hasCustomGoals = prefs.getBool(_keyHasCustomGoals) ?? false;
    _cachedCalories = prefs.getDouble(_keyTargetCalories) ?? defaultTargetCalories;
    _cachedProtein = prefs.getDouble(_keyTargetProtein) ?? defaultTargetProtein;
    _cachedFat = prefs.getDouble(_keyTargetFat) ?? defaultTargetFat;
    _cachedCarbs = prefs.getDouble(_keyTargetCarbs) ?? defaultTargetCarbs;
    _initialized = true;
    notifyListeners();
  }

  Future<String> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_keyServerUrl);
    if (url == null || url.trim().isEmpty) {
      return defaultServerUrl;
    }
    return url.trim();
  }

  Future<void> setServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    // Normalize: strip trailing slash
    var clean = url.trim();
    if (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    await prefs.setString(_keyServerUrl, clean);
  }

  Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyApiKey) ?? '';
  }

  Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiKey, key.trim());
  }

  Future<double> getTargetCalories() async {
    if (!_initialized) await init();
    return _cachedCalories;
  }

  Future<void> setTargetCalories(double val) async {
    final changed = _cachedCalories != val;
    _cachedCalories = val;
    if (changed) notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTargetCalories, val);
  }

  Future<double> getTargetProtein() async {
    if (!_initialized) await init();
    return _cachedProtein;
  }

  Future<void> setTargetProtein(double val) async {
    final changed = _cachedProtein != val;
    _cachedProtein = val;
    if (changed) notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTargetProtein, val);
  }

  Future<double> getTargetFat() async {
    if (!_initialized) await init();
    return _cachedFat;
  }

  Future<void> setTargetFat(double val) async {
    final changed = _cachedFat != val;
    _cachedFat = val;
    if (changed) notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTargetFat, val);
  }

  Future<double> getTargetCarbs() async {
    if (!_initialized) await init();
    return _cachedCarbs;
  }

  Future<void> setTargetCarbs(double val) async {
    final changed = _cachedCarbs != val;
    _cachedCarbs = val;
    if (changed) notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTargetCarbs, val);
  }

  Future<void> saveLocalGoals(
    double cal,
    double protein,
    double fat,
    double carbs, {
    bool isExplicitUserAction = false,
  }) async {
    final changed = _cachedCalories != cal ||
        _cachedProtein != protein ||
        _cachedFat != fat ||
        _cachedCarbs != carbs;

    _cachedCalories = cal;
    _cachedProtein = protein;
    _cachedFat = fat;
    _cachedCarbs = carbs;
    _initialized = true;
    if (isExplicitUserAction) {
      _hasCustomGoals = true;
    }

    if (changed) {
      notifyListeners();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTargetCalories, cal);
    await prefs.setDouble(_keyTargetProtein, protein);
    await prefs.setDouble(_keyTargetFat, fat);
    await prefs.setDouble(_keyTargetCarbs, carbs);
    if (isExplicitUserAction) {
      await prefs.setBool(_keyHasCustomGoals, true);
    }
  }
}

