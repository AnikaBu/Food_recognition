import 'package:flutter/material.dart';
import '../services/update_service.dart';

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
    Navigator.of(context).pop();
    final url = updateInfo.apkDownloadUrl.isNotEmpty
        ? updateInfo.apkDownloadUrl
        : updateInfo.releasePageUrl;
    await updateService.downloadAndInstallApk(url);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
                const Text('Доступно обновление!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  'Версия: v${updateInfo.latestVersion} (текущая: v${updateInfo.currentVersion})',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
              const Text('Что нового:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  updateInfo.releaseNotes,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              'Нажмите «Обновить», чтобы скачать свежий APK-файл и установить обновление.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Позже', style: TextStyle(color: Color(0xFF64748B))),
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
