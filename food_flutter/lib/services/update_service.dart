import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class AppUpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String releaseName;
  final String releaseNotes;
  final String apkDownloadUrl;
  final String releasePageUrl;
  final bool hasUpdate;

  AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseName,
    required this.releaseNotes,
    required this.apkDownloadUrl,
    required this.releasePageUrl,
    required this.hasUpdate,
  });
}

class UpdateService {
  static const String currentVersion = '1.0.18';
  static const String repoOwner = 'AnikaBu';
  static const String repoName = 'Food_recognition';

  /// Проверяет наличие новой версии на GitHub Releases
  Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final url = Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest');
      final res = await http.get(
        url,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'MyFoodDiary-App',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        return null;
      }

      final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final rawTag = (data['tag_name'] as String? ?? '').trim();
      final releaseName = (data['name'] as String? ?? rawTag).trim();
      final releaseNotes = (data['body'] as String? ?? '').trim();
      final htmlUrl = (data['html_url'] as String? ?? 'https://github.com/$repoOwner/$repoName/releases').trim();

      // Очищаем тег от префикса 'v' (например, 'v1.0.6' -> '1.0.6')
      final cleanVersion = rawTag.startsWith('v') ? rawTag.substring(1).split('-')[0] : rawTag.split('-')[0];

      // Ищем ссылку на .apk среди вложений релиза
      String apkUrl = '';
      final assets = data['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String? ?? '';
          break;
        }
      }

      final hasUpdate = _isVersionGreater(cleanVersion, currentVersion);

      return AppUpdateInfo(
        currentVersion: currentVersion,
        latestVersion: cleanVersion.isNotEmpty ? cleanVersion : currentVersion,
        releaseName: releaseName,
        releaseNotes: releaseNotes,
        apkDownloadUrl: apkUrl,
        releasePageUrl: htmlUrl,
        hasUpdate: hasUpdate,
      );
    } catch (_) {
      return null;
    }
  }

  /// Сравнивает две версии в формате x.y.z (возвращает true, если remote > current)
  bool _isVersionGreater(String remote, String current) {
    if (remote.isEmpty) return false;
    try {
      final rParts = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final cParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        final r = i < rParts.length ? rParts[i] : 0;
        final c = i < cParts.length ? cParts[i] : 0;
        if (r > c) return true;
        if (r < c) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Запускает загрузку и установку APK через системный загрузчик
  Future<bool> downloadAndInstallApk(String apkUrl) async {
    final uri = Uri.parse(apkUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) return true;
    } catch (_) {}

    try {
      return await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {}

    return false;
  }

  /// Открывает страницу релиза в системном браузере
  Future<bool> openInBrowser(String url) async {
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) return true;
    } catch (_) {}

    try {
      return await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {}

    return false;
  }
}
