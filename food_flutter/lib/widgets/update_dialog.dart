import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../theme/app_colors.dart';

class UpdateDialog extends StatelessWidget {
  final AppUpdateInfo updateInfo;
  final UpdateService updateService;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    required this.updateService,
  });

  static Future<void> show(BuildContext context, AppUpdateInfo info, UpdateService service) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => UpdateDialog(updateInfo: info, updateService: service),
    );
  }

  void _onDownload(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    final url = updateInfo.apkDownloadUrl.isNotEmpty
        ? updateInfo.apkDownloadUrl
        : updateInfo.releasePageUrl;

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Загрузка myfooddiary.apk запущена... 🚀'),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 3),
      ),
    );

    final ok = await updateService.downloadAndInstallApk(url);
    if (!ok) {
      final fallbackOk = await updateService.openInBrowser(updateInfo.releasePageUrl);
      if (!fallbackOk) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Не удалось открыть браузер для скачивания обновления.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B);
    final boxBg = isDark ? AppColors.darkInput : const Color(0xFFF8FAFC);
    final boxBorder = isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0);
    final boxTextColor = isDark ? AppColors.darkTextPrimary : const Color(0xFF334155);

    return AlertDialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.rocket_launch_rounded, color: Color(0xFF10B981), size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Доступно обновление!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                Text(
                  'Версия: v${updateInfo.latestVersion} (текущая: v${updateInfo.currentVersion})',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (updateInfo.releaseNotes.isNotEmpty) ...[
              Text('Что нового:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: boxBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: boxBorder),
                ),
                child: Text(
                  updateInfo.releaseNotes,
                  style: TextStyle(fontSize: 12, color: boxTextColor, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'Нажмите «Обновить», чтобы скачать свежий APK-файл и установить обновление.',
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Позже', style: TextStyle(color: textSecondary)),
        ),
        OutlinedButton(
          onPressed: () {
            Navigator.of(context).pop();
            updateService.openInBrowser(updateInfo.releasePageUrl);
          },
          child: const Text('В браузере'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
          ),
          onPressed: () => _onDownload(context),
          child: const Text('Обновить'),
        ),
      ],
    );
  }
}
