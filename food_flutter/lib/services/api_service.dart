import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/meal_models.dart';
import 'settings_service.dart';

class ApiResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  ApiResult.success(this.data)
      : error = null,
        isSuccess = true;

  ApiResult.failure(this.error)
      : data = null,
        isSuccess = false;
}

class HealthCheckResult {
  final bool isHealthy;
  final String message;
  final int latencyMs;

  HealthCheckResult({
    required this.isHealthy,
    required this.message,
    required this.latencyMs,
  });
}

class ApiService {
  final SettingsService _settingsService;

  ApiService({SettingsService? settingsService})
      : _settingsService = settingsService ?? SettingsService();

  Future<String> _getBaseUrl() async {
    return await _settingsService.getServerUrl();
  }

  Future<Map<String, String>> _getHeaders({bool isJson = true}) async {
    final apiKey = await _settingsService.getApiKey();
    final headers = <String, String>{};
    if (isJson) {
      headers['Content-Type'] = 'application/json; charset=utf-8';
    }
    if (apiKey.isNotEmpty) {
      headers['X-API-Key'] = apiKey;
    }
    return headers;
  }

  Future<HealthCheckResult> checkHealth() async {
    final stopwatch = Stopwatch()..start();
    try {
      final baseUrl = await _getBaseUrl();
      final uri = Uri.parse('$baseUrl/api/health');
      final headers = await _getHeaders(isJson: false);
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 6));
      stopwatch.stop();

      if (res.statusCode == 200) {
        final body = json.decode(utf8.decode(res.bodyBytes));
        final app = body['app'] ?? 'MyFoodDiary API';
        final authRequired = body['auth_required'] == true;
        final authValid = body['auth_valid'] == true;

        if (authRequired && !authValid) {
          return HealthCheckResult(
            isHealthy: false,
            message: 'Сервер доступен, но требуется верный API-ключ в настройках',
            latencyMs: stopwatch.elapsedMilliseconds,
          );
        }

        return HealthCheckResult(
          isHealthy: true,
          message: '$app доступен${authRequired ? " (ключ подтвержден)" : ""}',
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      } else {
        return HealthCheckResult(
          isHealthy: false,
          message: 'Сервер вернул код ${res.statusCode}',
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      }
    } catch (e) {
      stopwatch.stop();
      return HealthCheckResult(
        isHealthy: false,
        message: 'Ошибка подключения: ${e.toString()}',
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  Future<FoodAnalysisResult> analyzePhoto(XFile imageFile) async {
    final baseUrl = await _getBaseUrl();
    final uri = Uri.parse('$baseUrl/api/analyze-photo');

    final request = http.MultipartRequest('POST', uri);
    final apiKey = await _settingsService.getApiKey();
    if (apiKey.isNotEmpty) {
      request.headers['X-API-Key'] = apiKey;
    }

    final bytes = await imageFile.readAsBytes();
    final filename = imageFile.name.isNotEmpty ? imageFile.name : 'photo.jpg';
    final lower = filename.toLowerCase();
    String subtype = 'jpeg';
    if (lower.endsWith('.png')) {
      subtype = 'png';
    } else if (lower.endsWith('.webp')) {
      subtype = 'webp';
    }

    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: MediaType('image', subtype),
    );
    request.files.add(multipartFile);

    final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final decoded = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return FoodAnalysisResult.fromJson(decoded);
    } else {
      String err = 'Ошибка анализа (${response.statusCode})';
      try {
        final body = json.decode(utf8.decode(response.bodyBytes));
        if (body['detail'] != null) {
          err = body['detail'].toString();
        }
      } catch (_) {}
      throw Exception(err);
    }
  }

  Future<MealRecord> saveMeal({
    required String dishName,
    required MealType mealType,
    String? comment,
    required List<IngredientItem> items,
    String? createdAt,
  }) async {
    final baseUrl = await _getBaseUrl();
    final uri = Uri.parse('$baseUrl/api/meals');
    final headers = await _getHeaders(isJson: true);

    final payload = {
      'meal_type': mealType.value,
      'dish_name': dishName,
      'comment': comment ?? '',
      'items': items.map((it) => it.toJson()).toList(),
      if (createdAt != null) 'created_at': createdAt,
    };

    final res = await http.post(
      uri,
      headers: headers,
      body: json.encode(payload),
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200 || res.statusCode == 201) {
      final decoded = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return MealRecord.fromJson(decoded);
    } else {
      String err = 'Не удалось сохранить блюдо: ${res.statusCode}';
      try {
        final body = json.decode(utf8.decode(res.bodyBytes));
        if (body['detail'] != null) err = body['detail'].toString();
      } catch (_) {}
      throw Exception(err);
    }
  }

  Future<DailySummary> getDailySummary(DateTime date) async {
    final baseUrl = await _getBaseUrl();
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final uri = Uri.parse('$baseUrl/api/diary?date=$dateStr');
    final headers = await _getHeaders(isJson: false);

    final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final decoded = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return DailySummary.fromJson(decoded);
    } else {
      String err = 'Не удалось загрузить сводку: ${res.statusCode}';
      try {
        final body = json.decode(utf8.decode(res.bodyBytes));
        if (body['detail'] != null) err = body['detail'].toString();
      } catch (_) {}
      throw Exception(err);
    }
  }

  Future<void> deleteMeal(int mealId) async {
    final baseUrl = await _getBaseUrl();
    final uri = Uri.parse('$baseUrl/api/meals/$mealId');
    final headers = await _getHeaders(isJson: false);

    final res = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      String err = 'Ошибка при удалении блюда: ${res.statusCode}';
      try {
        final body = json.decode(utf8.decode(res.bodyBytes));
        if (body['detail'] != null) err = body['detail'].toString();
      } catch (_) {}
      throw Exception(err);
    }
  }

  Future<IngredientItem> updateItemWeight(int itemId, double newWeightG) async {
    final baseUrl = await _getBaseUrl();
    final uri = Uri.parse('$baseUrl/api/items/$itemId/weight');
    final headers = await _getHeaders(isJson: true);

    final res = await http.put(
      uri,
      headers: headers,
      body: json.encode({'weight_g': newWeightG}),
    ).timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final decoded = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return IngredientItem.fromJson(decoded);
    } else {
      String err = 'Ошибка обновления веса: ${res.statusCode}';
      try {
        final body = json.decode(utf8.decode(res.bodyBytes));
        if (body['detail'] != null) err = body['detail'].toString();
      } catch (_) {}
      throw Exception(err);
    }
  }

  Future<NutritionGoals> getGoals() async {
    final baseUrl = await _getBaseUrl();
    final uri = Uri.parse('$baseUrl/api/goals');
    final headers = await _getHeaders(isJson: true);

    final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      final decoded = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return NutritionGoals.fromJson(decoded);
    } else {
      String err = 'Ошибка получения целей КБЖУ: ${res.statusCode}';
      try {
        final body = json.decode(utf8.decode(res.bodyBytes));
        if (body['detail'] != null) err = body['detail'].toString();
      } catch (_) {}
      throw Exception(err);
    }
  }

  Future<NutritionGoals> updateGoals(NutritionGoals goals) async {
    final baseUrl = await _getBaseUrl();
    final uri = Uri.parse('$baseUrl/api/goals');
    final headers = await _getHeaders(isJson: true);

    final res = await http.put(
      uri,
      headers: headers,
      body: json.encode(goals.toJson()),
    ).timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final decoded = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return NutritionGoals.fromJson(decoded);
    } else {
      String err = 'Ошибка обновления целей КБЖУ: ${res.statusCode}';
      try {
        final body = json.decode(utf8.decode(res.bodyBytes));
        if (body['detail'] != null) err = body['detail'].toString();
      } catch (_) {}
      throw Exception(err);
    }
  }
}

