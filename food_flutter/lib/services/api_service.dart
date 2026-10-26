import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
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

  Future<HealthCheckResult> checkHealth() async {
    final stopwatch = Stopwatch()..start();
    try {
      final baseUrl = await _getBaseUrl();
      final uri = Uri.parse('$baseUrl/api/health');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      stopwatch.stop();

      if (res.statusCode == 200) {
        final body = json.decode(utf8.decode(res.bodyBytes));
        final app = body['app'] ?? 'Food Recognition API';
        return HealthCheckResult(
          isHealthy: true,
          message: '$app доступен',
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
    final bytes = await imageFile.readAsBytes();
    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: imageFile.name.isNotEmpty ? imageFile.name : 'photo.jpg',
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

    final payload = {
      'meal_type': mealType.value,
      'dish_name': dishName,
      'comment': comment ?? '',
      'items': items.map((it) => it.toJson()).toList(),
      if (createdAt != null) 'created_at': createdAt,
    };

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: json.encode(payload),
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200 || res.statusCode == 201) {
      final decoded = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return MealRecord.fromJson(decoded);
    } else {
      throw Exception('Не удалось сохранить блюдо: ${res.statusCode}');
    }
  }

  Future<DailySummary> getDailySummary(DateTime date) async {
    final baseUrl = await _getBaseUrl();
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final uri = Uri.parse('$baseUrl/api/diary?date=$dateStr');

    final res = await http.get(uri).timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final decoded = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return DailySummary.fromJson(decoded);
    } else {
      throw Exception('Не удалось загрузить сводку: ${res.statusCode}');
    }
  }

  Future<void> deleteMeal(int mealId) async {
    final baseUrl = await _getBaseUrl();
    final uri = Uri.parse('$baseUrl/api/meals/$mealId');

    final res = await http.delete(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('Ошибка при удалении блюда: ${res.statusCode}');
    }
  }

  Future<IngredientItem> updateItemWeight(int itemId, double newWeightG) async {
    final baseUrl = await _getBaseUrl();
    final uri = Uri.parse('$baseUrl/api/items/$itemId/weight');

    final res = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'weight_g': newWeightG}),
    ).timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final decoded = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return IngredientItem.fromJson(decoded);
    } else {
      throw Exception('Ошибка обновления веса: ${res.statusCode}');
    }
  }
}
