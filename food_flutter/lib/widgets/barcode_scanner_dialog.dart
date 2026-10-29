import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerDialog extends StatefulWidget {
  const BarcodeScannerDialog({super.key});

  @override
  State<BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<BarcodeScannerDialog> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  final TextEditingController _manualCodeController = TextEditingController();
  bool _hasDetected = false;
  bool _isTorchOn = false;

  @override
  void dispose() {
    _manualCodeController.dispose();
    _controller.dispose();
    super.dispose();
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

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Заголовок и кнопки управления
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.qr_code_scanner, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Сканер штрихкодов',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Фонарик
                IconButton(
                  icon: Icon(
                    _isTorchOn ? Icons.flash_on : Icons.flash_off,
                    color: _isTorchOn ? Colors.amber : Colors.grey,
                  ),
                  tooltip: 'Фонарик',
                  onPressed: () async {
                    await _controller.toggleTorch();
                    setState(() {
                      _isTorchOn = !_isTorchOn;
                    });
                  },
                ),
                // Закрыть
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Закрыть',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Область видоискателя камеры
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
                // Затемнение и прицельная рамка сканирования
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF10B981),
                      width: 2.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  width: 260,
                  height: 180,
                ),
                // Подсказка поверх камеры
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
            ),
          ),

          // Нижняя панель: ручной ввод штрихкода (для эмуляторов или поврежденных этикеток)
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Или введите цифры штрихкода вручную:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualCodeController,
                        keyboardType: TextInputType.number,
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
                        backgroundColor: const Color(0xFF10B981),
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
}
