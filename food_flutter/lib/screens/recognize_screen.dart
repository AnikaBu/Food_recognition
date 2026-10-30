import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/meal_models.dart';
import '../services/api_service.dart';
import '../widgets/ingredient_tile.dart';
import '../widgets/manual_meal_sheet.dart';
import '../theme/app_colors.dart';
import '../widgets/app_screen_background.dart';

class RecognizeScreen extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onSavedSuccess;

  const RecognizeScreen({
    super.key,
    required this.apiService,
    required this.onSavedSuccess,
  });

  @override
  State<RecognizeScreen> createState() => RecognizeScreenState();
}

class RecognizeScreenState extends State<RecognizeScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isAnalyzing = false;
  bool _isSaving = false;
  String? _errorMessage;

  // Analysis result & edit state
  FoodAnalysisResult? _analysisResult;
  MealType _selectedMealType = MealType.lunch;
  final TextEditingController _dishNameController = TextEditingController();

  @override
  void dispose() {
    _dishNameController.dispose();
    super.dispose();
  }

  Future<void> pickImage(ImageSource source) async {
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

  void _showAddIngredientDialog() {
    final nameCtrl = TextEditingController();
    final weightCtrl = TextEditingController(text: '100');
    final calCtrl = TextEditingController(text: '100');
    final protCtrl = TextEditingController(text: '5');
    final fatCtrl = TextEditingController(text: '5');
    final carbCtrl = TextEditingController(text: '10');

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Добавить ингредиент',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Название продукта'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: weightCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Вес (г)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: calCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Калории (ккал)'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: protCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Б (г)'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: fatCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Ж (г)'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: carbCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'У (г)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Отмена', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty && _analysisResult != null) {
                final w = double.tryParse(weightCtrl.text) ?? 100;
                final c = double.tryParse(calCtrl.text) ?? 100;
                final p = double.tryParse(protCtrl.text) ?? 0;
                final f = double.tryParse(fatCtrl.text) ?? 0;
                final cr = double.tryParse(carbCtrl.text) ?? 0;

                final newItem = IngredientItem(
                  name: name,
                  weightG: w,
                  calories: c,
                  protein: p,
                  fat: f,
                  carbs: cr,
                );

                setState(() {
                  _analysisResult = _analysisResult!.copyWith(
                    items: [..._analysisResult!.items, newItem],
                  );
                });
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Добавить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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

    setState(() => _isSaving = true);

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
            content: Text('Блюдо успешно сохранено в дневник! 🍽️✅'),
            backgroundColor: AppColors.primary,
          ),
        );

        widget.onSavedSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _resetScanner() {
    setState(() {
      _selectedImage = null;
      _analysisResult = null;
      _errorMessage = null;
      _isAnalyzing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isAnalyzing) {
      return _buildProcessingScreen();
    }

    if (_analysisResult != null) {
      return _buildResultSheet();
    }

    return _buildIdleScreen();
  }

  // 1. PHOTO RECOGNITION IDLE SCREEN
  Widget _buildIdleScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final cardBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Фото блюда'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, color: AppColors.primary, size: 14),
                SizedBox(width: 4),
                Text(
                  'Gemini Vision',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.error, fontSize: 13),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16, color: AppColors.error),
                        onPressed: () => setState(() => _errorMessage = null),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Main Action Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Camera Illustration / Icon container
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.2),
                            AppColors.primaryDark.withOpacity(0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: AppColors.primary.withOpacity(0.35), width: 2),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.camera_alt_rounded,
                          size: 44,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Сфотографируйте блюдо',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Искусственный интеллект автоматически распознает ингредиенты, оценит их вес и рассчитает калории, белки, жиры и углеводы.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Primary Button: Open Camera
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt, color: Colors.white, size: 22),
                        label: const Text(
                          'Сделать снимок (Камера)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Secondary Button: Pick from Gallery
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () => pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined, color: AppColors.primary, size: 20),
                        label: Text(
                          'Выбрать из галереи',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: cardBorder, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Alternative: Manual entry option
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cardBorder),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
                  ),
                  title: Text(
                    'Ввести блюдо вручную',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Записать калории и БЖУ без фото',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                  trailing: Icon(Icons.chevron_right, color: textSecondary, size: 20),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => ManualMealSheet(
                        date: DateTime.now(),
                        apiService: widget.apiService,
                        onMealSaved: widget.onSavedSuccess,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Tips Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkSurface : Colors.white).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cardBorder.withOpacity(0.6)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lightbulb_outline, color: AppColors.warning, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Совет для точного распознавания',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Фотографируйте блюдо сверху при хорошем освещении, чтобы все компоненты тарелки были четко видны нейросети.',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // 2. AI PROCESSING OVERLAY SCREEN
  Widget _buildProcessingScreen() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppScreenBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.emerald400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.5),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.psychology, color: Colors.white, size: 44),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Нейросеть распознает блюдо...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Сегментация ингредиентов, оценка веса порции и расчет КБЖУ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 3. SCANNER RESULT SHEET
  Widget _buildResultSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final cardBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final categories = [
      {'type': MealType.breakfast, 'label': 'Завтрак'},
      {'type': MealType.lunch, 'label': 'Обед'},
      {'type': MealType.dinner, 'label': 'Ужин'},
      {'type': MealType.snack, 'label': 'Перекус'},
    ];

    return Scaffold(
      backgroundColor: isDark ? Colors.transparent : AppColors.lightScaffold,
      appBar: AppBar(
        title: const Text('Результат анализа', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _resetScanner,
        ),
      ),
      body: AppScreenBackground(
        child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // AI Confidence Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, color: AppColors.primary, size: 13),
                    SizedBox(width: 5),
                    Text(
                      'Точность AI: 96%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => pickImage(ImageSource.camera),
                icon: const Icon(Icons.refresh, size: 16, color: AppColors.primary),
                label: const Text('Переснять', style: TextStyle(fontSize: 12, color: AppColors.primary)),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Editable Dish Title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
            ),
            child: TextField(
              controller: _dishNameController,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                suffixIcon: Icon(Icons.edit, size: 16, color: textSecondary),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 4-Column Macro Summary Box
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMacroCol('Калории', '${_analysisResult!.totalCalories.toStringAsFixed(0)}', 'ккал', AppColors.macroCalorie),
                _buildMacroCol('Белки', '${_analysisResult!.totalProtein.toStringAsFixed(0)} г', '', AppColors.macroProtein),
                _buildMacroCol('Жиры', '${_analysisResult!.totalFat.toStringAsFixed(0)} г', '', AppColors.macroFat),
                _buildMacroCol('Углеводы', '${_analysisResult!.totalCarbs.toStringAsFixed(0)} г', '', AppColors.macroCarb),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Interactive Ingredients List Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ингредиенты порции (${_analysisResult!.totalWeightG.toStringAsFixed(0)}г)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: textSecondary,
                ),
              ),
              InkWell(
                onTap: _showAddIngredientDialog,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 15, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text(
                        'Добавить',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // List of Ingredient Tiles
          ...List.generate(_analysisResult!.items.length, (idx) {
            final item = _analysisResult!.items[idx];
            return IngredientTile(
              item: item,
              onWeightChanged: (newWeight) => _onIngredientWeightChanged(idx, newWeight),
              onDelete: () => _onDeleteIngredient(idx),
            );
          }),

          const SizedBox(height: 14),

          // Category Selector Chips
          Text(
            'Назначить прием пищи',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: categories.map((cat) {
              final type = cat['type'] as MealType;
              final label = cat['label'] as String;
              final isSel = _selectedMealType == type;

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedMealType = type),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: isSel ? AppColors.primary : cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSel ? AppColors.primary : cardBorder,
                      ),
                      boxShadow: isSel
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSel ? Colors.white : textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Big Save CTA
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            onPressed: _isSaving ? null : _saveMeal,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Сохранить в дневник',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    ),
  );
  }

  Widget _buildMacroCol(String title, String val, String unit, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          val,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        if (unit.isNotEmpty)
          Text(
            unit,
            style: TextStyle(
              fontSize: 9,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
      ],
    );
  }
}
