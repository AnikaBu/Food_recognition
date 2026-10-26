import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/meal_models.dart';
import '../services/api_service.dart';
import '../widgets/category_selector.dart';
import '../widgets/ingredient_tile.dart';
import '../widgets/macro_pill.dart';

class RecognizeScreen extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onSavedSuccess;

  const RecognizeScreen({
    super.key,
    required this.apiService,
    required this.onSavedSuccess,
  });

  @override
  State<RecognizeScreen> createState() => _RecognizeScreenState();
}

class _RecognizeScreenState extends State<RecognizeScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isAnalyzing = false;
  bool _isSaving = false;
  String? _errorMessage;

  // Analysis result & edit state
  FoodAnalysisResult? _analysisResult;
  MealType _selectedMealType = MealType.lunch;
  final TextEditingController _dishNameController = TextEditingController();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = image;
          _analysisResult = null;
          _errorMessage = null;
        });
        await _runAnalysis();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Не удалось получить фото: $e';
      });
    }
  }

  Future<void> _runAnalysis() async {
    if (_selectedImage == null) return;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.apiService.analyzePhoto(_selectedImage!);
      setState(() {
        _analysisResult = result;
        _dishNameController.text = result.dishName;
        _selectedMealType = _guessMealType();
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка анализа: $e';
        _isAnalyzing = false;
      });
    }
  }

  MealType _guessMealType() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) return MealType.breakfast;
    if (hour >= 11 && hour < 16) return MealType.lunch;
    if (hour >= 16 && hour < 22) return MealType.dinner;
    return MealType.snack;
  }

  void _onIngredientWeightChanged(int index, double newWeight) {
    if (_analysisResult == null) return;
    final items = List<IngredientItem>.from(_analysisResult!.items);
    final oldItem = items[index];
    items[index] = oldItem.copyWithWeight(newWeight);

    setState(() {
      _analysisResult = _analysisResult!.copyWith(items: items);
    });
  }

  void _onDeleteIngredient(int index) {
    if (_analysisResult == null) return;
    final items = List<IngredientItem>.from(_analysisResult!.items);
    items.removeAt(index);

    setState(() {
      _analysisResult = _analysisResult!.copyWith(items: items);
    });
  }

  Future<void> _saveMeal() async {
    if (_analysisResult == null) return;

    final dishName = _dishNameController.text.trim();
    if (dishName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, введите название блюда')),
      );
      return;
    }

    if (_analysisResult!.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('В блюде должен быть хотя бы один ингредиент')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.apiService.saveMeal(
        dishName: dishName,
        mealType: _selectedMealType,
        comment: _analysisResult!.comment,
        items: _analysisResult!.items,
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
          _selectedImage = null;
          _analysisResult = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Блюдо успешно сохранено в дневник! 🥗'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 3),
          ),
        );

        widget.onSavedSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Распознавание еды',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Camera / Gallery Trigger Card
          if (_selectedImage == null) ...[
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, size: 36, color: Color(0xFF10B981)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Сделайте фото вашего блюда',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Искусственный интеллект Gemini распознает продукты, оценит их вес и посчитает точные КБЖУ порции.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.camera),
                          label: const Text('Камера', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => _pickImage(ImageSource.camera),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.photo_library, color: Color(0xFF334155)),
                          label: const Text('Галерея', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                          onPressed: () => _pickImage(ImageSource.gallery),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            // Photo Preview Bar
            Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    width: double.infinity,
                    height: 200,
                    child: kIsWeb
                        ? Image.network(_selectedImage!.path, fit: BoxFit.cover)
                        : Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.black.withOpacity(0.6),
                        child: IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                          tooltip: 'Сделать другое фото',
                          onPressed: () => _pickImage(ImageSource.camera),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: Colors.black.withOpacity(0.6),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 20),
                          tooltip: 'Сбросить',
                          onPressed: () {
                            setState(() {
                              _selectedImage = null;
                              _analysisResult = null;
                              _errorMessage = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // Loading Indicator
          if (_isAnalyzing)
            Container(
              padding: const EdgeInsets.all(28),
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 3),
                  SizedBox(height: 18),
                  Text(
                    'Gemini Vision анализирует блюдо...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Определяем ингредиенты, граммовки и считаем калории',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),

          // Error Message
          if (_errorMessage != null)
            Card(
              color: const Color(0xFFFEF2F2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFFECACA)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 36),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _runAnalysis,
                      child: const Text('Повторить анализ'),
                    ),
                  ],
                ),
              ),
            ),

          // Analysis Result Card & Controls
          if (_analysisResult != null && !_isAnalyzing) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meal Type Selector
                  const Text(
                    'Категория приема пищи:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 6),
                  CategorySelector(
                    selected: _selectedMealType,
                    onSelected: (type) => setState(() => _selectedMealType = type),
                  ),
                  const SizedBox(height: 14),

                  // Dish Name Field
                  TextField(
                    controller: _dishNameController,
                    decoration: InputDecoration(
                      labelText: 'Название блюда',
                      prefixIcon: const Icon(Icons.restaurant, color: Color(0xFF10B981)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 14),

                  // Total Dish KBJU Summary Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Итого в порции:',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              '${_analysisResult!.totalWeightG.toStringAsFixed(0)} г',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            MacroPill(
                              label: 'Калории',
                              value: '${_analysisResult!.totalCalories.toStringAsFixed(0)} ккал',
                              type: MacroType.calories,
                            ),
                            MacroPill(
                              label: 'Белки',
                              value: '${_analysisResult!.totalProtein.toStringAsFixed(1)}г',
                              type: MacroType.protein,
                            ),
                            MacroPill(
                              label: 'Жиры',
                              value: '${_analysisResult!.totalFat.toStringAsFixed(1)}г',
                              type: MacroType.fat,
                            ),
                            MacroPill(
                              label: 'Углеводы',
                              value: '${_analysisResult!.totalCarbs.toStringAsFixed(1)}г',
                              type: MacroType.carbs,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Ingredients Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ингредиенты (${_analysisResult!.items.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const Text(
                  'Нажмите на вес для правки',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Ingredient Tiles with live recalculation
            ..._analysisResult!.items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return IngredientTile(
                item: item,
                onWeightChanged: (newWeight) => _onIngredientWeightChanged(idx, newWeight),
                onDelete: () => _onDeleteIngredient(idx),
              );
            }),

            // Dietitian note if available
            if (_analysisResult!.comment.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.tips_and_updates_outlined, size: 20, color: Color(0xFF059669)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _analysisResult!.comment,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF065F46), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Save Meal Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                _isSaving ? 'Сохранение...' : 'Сохранить в дневник',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: _isSaving ? null : _saveMeal,
            ),
            const SizedBox(height: 40),
          ],
        ],
      ),
    );
  }
}
