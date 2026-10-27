import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
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
      barrierDismissible: false,
      builder: (ctx) => UpdateDialog(updateInfo: info, updateService: service),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  String _progressText = '0%';
  double _progressValue = 0.0;
  String? _errorMessage;
  StreamSubscription<OtaEvent>? _otaSubscription;

  @override
  void dispose() {
    _otaSubscription?.cancel();
    super.dispose();
  }

  void _startOtaDownload() {
    if (widget.updateInfo.apkDownloadUrl.isEmpty) {
      widget.updateService.openInBrowser(widget.updateInfo.releasePageUrl);
      return;
    }

    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progressText = 'Подготовка к загрузке...';
      _progressValue = 0.0;
    });

    try {
      _otaSubscription = widget.updateService
          .startOtaUpdate(widget.updateInfo.apkDownloadUrl)
          .listen((OtaEvent event) {
        if (!mounted) return;

        setState(() {
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              final percent = int.tryParse(event.value ?? '0') ?? 0;
              _progressValue = (percent / 100.0).clamp(0.0, 1.0);
              _progressText = 'Загрузка: $percent%';
              break;
            case OtaStatus.INSTALLING:
              _progressText = 'Запуск установщика Android...';
              _progressValue = 1.0;
              break;
            case OtaStatus.ALREADY_RUNNING_ERROR:
              _errorMessage = 'Загрузка уже выполняется.';
              _isDownloading = false;
              break;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              _errorMessage = 'Необходимо разрешить установку приложений из этого источника в настройках телефона.';
              _isDownloading = false;
              break;
            case OtaStatus.INTERNAL_ERROR:
            default:
              _errorMessage = 'Ошибка загрузки (${event.value ?? "сбой"}). Вы можете скачать файл через браузер.';
              _isDownloading = false;
              break;
          }
        });
      }, onError: (err) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _errorMessage = 'Не удалось загрузить обновление: $err';
          });
        }
      });
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _errorMessage = 'Ошибка запуска загрузки: $e';
      });
    }
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
                  'Версия: v${widget.updateInfo.latestVersion} (текущая: v${widget.updateInfo.currentVersion})',
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
            if (widget.updateInfo.releaseNotes.isNotEmpty) ...[
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
                  widget.updateInfo.releaseNotes,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.4),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_isDownloading) ...[
              LinearProgressIndicator(
                value: _progressValue > 0 ? _progressValue : null,
                backgroundColor: const Color(0xFF10B981).withOpacity(0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                minHeight: 8,
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _progressText,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isDownloading) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Позже', style: TextStyle(color: Color(0xFF64748B))),
          ),
          OutlinedButton(
            onPressed: () {
              widget.updateService.openInBrowser(widget.updateInfo.releasePageUrl);
            },
            child: const Text('В браузере'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            onPressed: _startOtaDownload,
            child: const Text('Обновить'),
          ),
        ] else ...[
          TextButton(
            onPressed: () {
              _otaSubscription?.cancel();
              setState(() => _isDownloading = false);
              Navigator.of(context).pop();
            },
            child: const Text('Отмена', style: TextStyle(color: Colors.red)),
          ),
        ],
      ],
    );
  }
}
