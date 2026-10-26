import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _keyServerUrl = 'server_url';
  static const String _keyApiKey = 'api_key';
  static const String _keyTargetCalories = 'target_calories';
  static const String _keyTargetProtein = 'target_protein';
  static const String _keyTargetFat = 'target_fat';
  static const String _keyTargetCarbs = 'target_carbs';

  static const String defaultServerUrl = 'http://192.168.1.172:8000';
  static const double defaultTargetCalories = 2000.0;
  static const double defaultTargetProtein = 90.0;
  static const double defaultTargetFat = 65.0;
  static const double defaultTargetCarbs = 250.0;

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
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyTargetCalories) ?? defaultTargetCalories;
  }

  Future<void> setTargetCalories(double val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTargetCalories, val);
  }

  Future<double> getTargetProtein() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyTargetProtein) ?? defaultTargetProtein;
  }

  Future<void> setTargetProtein(double val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTargetProtein, val);
  }

  Future<double> getTargetFat() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyTargetFat) ?? defaultTargetFat;
  }

  Future<void> setTargetFat(double val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTargetFat, val);
  }

  Future<double> getTargetCarbs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyTargetCarbs) ?? defaultTargetCarbs;
  }

  Future<void> setTargetCarbs(double val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTargetCarbs, val);
  }
}
