import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_colors.dart';

class BarcodeScannerDialog extends StatefulWidget {
  const BarcodeScannerDialog({super.key});

  @override
  State<BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<BarcodeScannerDialog> with WidgetsBindingObserver {
  late final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.qrCode,
    ],
  );

  final TextEditingController _manualCodeController = TextEditingController();
  bool _hasDetected = false;
  bool _isTorchOn = false;
  bool _isPermissionChecking = true;
  bool _hasPermission = false;
  bool _isPermanentlyDenied = false;
  bool _hasCameraError = false;
  String? _cameraErrorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndRequestPermission();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_hasPermission) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _controller.start();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _controller.stop();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _manualCodeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkAndRequestPermission() async {
    setState(() {
      _isPermissionChecking = true;
      _hasCameraError = false;
      _cameraErrorMessage = null;
    });

    try {
      final status = await Permission.camera.request();
      if (!mounted) return;

      final isGranted = status.isGranted;
      final isPermDenied = status.isPermanentlyDenied;

      setState(() {
        _isPermissionChecking = false;
        _hasPermission = isGranted;
        _isPermanentlyDenied = isPermDenied;
      });

      if (isGranted) {
        try {
          await _controller.start();
        } catch (e) {
          if (mounted) {
            setState(() {
              _hasCameraError = true;
              _cameraErrorMessage = e.toString();
            });
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPermissionChecking = false;
        _hasPermission = false;
        _hasCameraError = true;
        _cameraErrorMessage = e.toString();
      });
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasDetected) return;

    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue?.trim();
      if (code != null && code.isNotEmpty) {
        final digits = code.replaceAll(RegExp(r'[\s\-]'), '');
        if (digits.length >= 7 && digits.length <= 14) {
          _hasDetected = true;
          Navigator.of(context).pop(digits);
          break;
        }
      }
    }
  }

  void _submitManualCode() {
    final code = _manualCodeController.text.trim().replaceAll(RegExp(r'[\s\-]'), '');
    if (code.length >= 7 && code.length <= 14) {
      _hasDetected = true;
      Navigator.of(context).pop(code);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Штрихкод должен содержать от 7 до 14 цифр'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Заголовок и кнопки управления
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.qr_code_scanner, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Сканер штрихкодов',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                ),
                // Фонарик (доступен только если камера запущена)
                if (_hasPermission && !_hasCameraError)
                  IconButton(
                    icon: Icon(
                      _isTorchOn ? Icons.flash_on : Icons.flash_off,
                      color: _isTorchOn ? Colors.amber : textSecondary,
                    ),
                    tooltip: 'Фонарик',
                    onPressed: () async {
                      try {
                        await _controller.toggleTorch();
                        setState(() {
                          _isTorchOn = !_isTorchOn;
                        });
                      } catch (_) {}
                    },
                  ),
                // Закрыть
                IconButton(
                  icon: Icon(Icons.close, color: textSecondary),
                  tooltip: 'Закрыть',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),

          // Область видоискателя камеры или состояние ошибки/разрешения
          Expanded(
            child: Container(
              color: Colors.black,
              child: _buildCameraContent(),
            ),
          ),

          // Нижняя панель: ручной ввод штрихкода (для эмуляторов или поврежденных этикеток)
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Или введите цифры штрихкода вручную:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualCodeController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'например: 5449000000996',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _submitManualCode(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _submitManualCode,
                      icon: const Icon(Icons.search, size: 18),
                      label: const Text('Найти'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraContent() {
    if (_isPermissionChecking) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Подключение камеры...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (!_hasPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.videocam_off_outlined, color: Colors.amber, size: 44),
              ),
              const SizedBox(height: 16),
              const Text(
                'Требуется доступ к камере',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Для быстрого сканирования штрихкодов продуктов разрешите приложению использовать камеру или введите код вручную в поле ниже.',
                style: TextStyle(fontSize: 13, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(_isPermanentlyDenied ? Icons.settings : Icons.lock_open, size: 18),
                label: Text(_isPermanentlyDenied ? 'Открыть настройки устройства' : 'Предоставить доступ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  if (_isPermanentlyDenied) {
                    await openAppSettings();
                  } else {
                    _checkAndRequestPermission();
                  }
                },
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error, child) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_hasCameraError) {
                setState(() {
                  _hasCameraError = true;
                  _cameraErrorMessage = error.errorDetails?.message ?? error.errorCode.name;
                });
              }
            });
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Не удалось запустить камеру',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.errorDetails?.message != null
                          ? 'Код: ${error.errorDetails!.message}'
                          : 'Попробуйте повторить подключение или введите цифры штрихкода в поле ниже.',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Повторить подключение'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        setState(() {
                          _hasCameraError = false;
                        });
                        try {
                          await _controller.start();
                        } catch (_) {}
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // Затемнение и прицельная рамка сканирования (только если камера работает без ошибок)
        if (!_hasCameraError) ...[
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.primary,
                width: 2.5,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            width: 260,
            height: 180,
          ),
          Positioned(
            top: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Наведите рамку на штрихкод',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
