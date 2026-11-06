import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/meal_models.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'category_selector.dart';
import 'barcode_scanner_dialog.dart';
import 'recipe_picker_sheet.dart';

class ManualMealSheet extends StatefulWidget {
  final DateTime date;
  final ApiService apiService;
  final VoidCallback onMealSaved;
  final MealType? initialMealType;

  const ManualMealSheet({
    super.key,
    required this.date,
    required this.apiService,
    required this.onMealSaved,
    this.initialMealType,
  });

  @override
  State<ManualMealSheet> createState() => _ManualMealSheetState();
}

class _ManualMealSheetState extends State<ManualMealSheet> {
  final _formKey = GlobalKey<FormState>();

  late MealType _selectedMealType;
  final _dishNameController = TextEditingController();
  final _weightController = TextEditingController(text: '100');
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController(text: '0');
  final _fatController = TextEditingController(text: '0');
  final _carbsController = TextEditingController(text: '0');
  final _commentController = TextEditingController();
  final _dishNameFocusNode = FocusNode();

  bool _isSaving = false;
  bool _isEstimatingAi = false;
  bool _isLookingUpBarcode = false;
  bool _isAutoUpdating = false;
  String? _errorMessage;
  String? _noticeMessage;
  bool _isNoticeSuccess = false;

  // Базовые показатели КБЖУ на 100 г для динамического масштабирования
  double? _cal100;
  double? _prot100;
  double? _fat100;
  double? _carb100;

  Timer? _searchDebounceTimer;
  List<SavedProduct> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _selectedMealType = widget.initialMealType ?? _guessMealType();
    _dishNameController.addListener(_onDishNameChanged);
    _weightController.addListener(_onWeightChanged);
    _caloriesController.addListener(_onMacroChanged);
    _proteinController.addListener(_onMacroChanged);
    _fatController.addListener(_onMacroChanged);
    _carbsController.addListener(_onMacroChanged);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _dishNameController.removeListener(_onDishNameChanged);
    _weightController.removeListener(_onWeightChanged);
    _caloriesController.removeListener(_onMacroChanged);
    _proteinController.removeListener(_onMacroChanged);
    _fatController.removeListener(_onMacroChanged);
    _carbsController.removeListener(_onMacroChanged);
    _dishNameController.dispose();
    _dishNameFocusNode.dispose();
    _weightController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _carbsController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _onDishNameChanged() {
    if (_isAutoUpdating) return;
    if (_noticeMessage != null && !_isNoticeSuccess) {
      setState(() => _noticeMessage = null);
    }
    final text = _dishNameController.text.trim();
    _searchDebounceTimer?.cancel();
    if (text.length < 2) {
      if (_suggestions.isNotEmpty) {
        setState(() => _suggestions = []);
      }
      return;
    }
    _searchDebounceTimer = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;
      final results = await widget.apiService.searchProducts(text, limit: 5);
      if (mounted) {
        if (_dishNameController.text.trim() == text) {
          setState(() {
            _suggestions = results;
          });
        }
      }
    });
  }

  void _selectSuggestion(SavedProduct item) {
    setState(() {
      _isAutoUpdating = true;
      _dishNameController.text = item.fullName;
      _cal100 = item.calories100g;
      _prot100 = item.protein100g;
      _fat100 = item.fat100g;
      _carb100 = item.carbs100g;

      final w = double.tryParse(_weightController.text.replaceAll(',', '.')) ?? 100.0;
      final factor = (w > 0 ? w : 100.0) / 100.0;
      _caloriesController.text = (item.calories100g * factor).toStringAsFixed(0);
      _proteinController.text = (item.protein100g * factor).toStringAsFixed(1);
      _fatController.text = (item.fat100g * factor).toStringAsFixed(1);
      _carbsController.text = (item.carbs100g * factor).toStringAsFixed(1);

      if (item.barcode != null && item.barcode!.isNotEmpty) {
        _commentController.text = 'Штрихкод: ${item.barcode}';
      }

      _suggestions = [];
      _isAutoUpdating = false;
    });
  }

  void _onWeightChanged() {
    if (_isAutoUpdating || _cal100 == null) return;
    final text = _weightController.text.replaceAll(',', '.');
    final w = double.tryParse(text);
    if (w == null || w <= 0) return;
    final factor = w / 100.0;
    _isAutoUpdating = true;
    _caloriesController.text = (_cal100! * factor).toStringAsFixed(0);
    _proteinController.text = (_prot100! * factor).toStringAsFixed(1);
    _fatController.text = (_fat100! * factor).toStringAsFixed(1);
    _carbsController.text = (_carb100! * factor).toStringAsFixed(1);
    _isAutoUpdating = false;
  }

  void _onMacroChanged() {
    if (_isAutoUpdating) return;
    final text = _weightController.text.replaceAll(',', '.');
    final w = double.tryParse(text) ?? 100.0;
    if (w <= 0) return;
    final factor = w / 100.0;

    final calText = _caloriesController.text.replaceAll(',', '.');
    final c = double.tryParse(calText);
    if (c != null) _cal100 = c / factor;

    final protText = _proteinController.text.replaceAll(',', '.');
    final p = double.tryParse(protText);
    if (p != null) _prot100 = p / factor;

    final fatText = _fatController.text.replaceAll(',', '.');
    final f = double.tryParse(fatText);
    if (f != null) _fat100 = f / factor;

    final carbText = _carbsController.text.replaceAll(',', '.');
    final cb = double.tryParse(carbText);
    if (cb != null) _carb100 = cb / factor;
  }

  MealType _guessMealType() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) return MealType.breakfast;
    if (hour >= 11 && hour < 16) return MealType.lunch;
    if (hour >= 16 && hour < 22) return MealType.dinner;
    return MealType.snack;
  }

  String _formatDateString(DateTime date) {
    try {
      return DateFormat('d MMMM yyyy', 'ru').format(date);
    } catch (_) {
      return DateFormat('yyyy-MM-dd').format(date);
    }
  }

  Future<void> _estimateWithAi() async {
    final query = _dishNameController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _noticeMessage = 'Введите название блюда или продукта для расчета (например: «хлеб зерновой 30г» или «яблоко»)';
        _isNoticeSuccess = false;
      });
      _dishNameFocusNode.requestFocus();
      return;
    }

    setState(() {
      _isEstimatingAi = true;
      _errorMessage = null;
      _noticeMessage = null;
    });

    try {
      final weightVal = double.tryParse(_weightController.text.replaceAll(',', '.'));
      final result = await widget.apiService.estimateNutrition(
        query,
        weightG: (weightVal != null && weightVal > 0) ? weightVal : null,
      );

      if (mounted) {
        setState(() {
          _isAutoUpdating = true;
          _dishNameController.text = result.name;
          _weightController.text = result.weightG.toStringAsFixed(0);
          _caloriesController.text = result.calories.toStringAsFixed(0);
          _proteinController.text = result.protein.toStringAsFixed(1);
          _fatController.text = result.fat.toStringAsFixed(1);
          _carbsController.text = result.carbs.toStringAsFixed(1);
          if (result.comment != null && result.comment!.isNotEmpty) {
            _commentController.text = result.comment!;
          }

          // Рассчитываем базовые коэффициенты на 100 г для живого масштабирования
          if (result.weightG > 0) {
            final f = 100.0 / result.weightG;
            _cal100 = result.calories * f;
            _prot100 = result.protein * f;
            _fat100 = result.fat * f;
            _carb100 = result.carbs * f;
          }

          _isEstimatingAi = false;
          _isAutoUpdating = false;
          _noticeMessage = '✨ Рассчитано через Gemini: ${result.calories.toStringAsFixed(0)} ккал (${result.weightG.toStringAsFixed(0)} г)';
          _isNoticeSuccess = true;
        });

        Future.delayed(const Duration(seconds: 4), () {
          if (mounted && _isNoticeSuccess) {
            setState(() => _noticeMessage = null);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isEstimatingAi = false;
        });
      }
    }
  }

  Future<void> _scanBarcode() async {
    final barcode = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BarcodeScannerDialog(),
    );

    if (barcode == null || barcode.trim().isEmpty) return;

    setState(() {
      _isLookingUpBarcode = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.apiService.lookupBarcode(barcode);

      if (mounted) {
        final fullName = result.brand.isNotEmpty
            ? '${result.name} (${result.brand})'
            : result.name;

        final hasZeroNutrition = result.calories100g == 0 &&
            result.protein100g == 0 &&
            result.fat100g == 0 &&
            result.carbs100g == 0;

        setState(() {
          _isAutoUpdating = true;
          _dishNameController.text = fullName;
          _cal100 = result.calories100g;
          _prot100 = result.protein100g;
          _fat100 = result.fat100g;
          _carb100 = result.carbs100g;

          final servingWeight = result.weightG > 0 ? result.weightG : 100.0;
          _weightController.text = servingWeight.toStringAsFixed(0);

          _caloriesController.text = result.calories.toStringAsFixed(0);
          _proteinController.text = result.protein.toStringAsFixed(1);
          _fatController.text = result.fat.toStringAsFixed(1);
          _carbsController.text = result.carbs.toStringAsFixed(1);
          _commentController.text = 'Штрихкод: ${result.barcode}';
          _isLookingUpBarcode = false;
          _isAutoUpdating = false;
        });

        if (hasZeroNutrition) {
          // Если КБЖУ в Open Food Facts отсутствовало и бэкенд вернул нули,
          // запускаем автоматическую оценку через Gemini AI
          setState(() {
            _noticeMessage = '📦 Найден: $fullName. Рассчитываем КБЖУ через ИИ...';
            _isNoticeSuccess = true;
          });
          await _estimateWithAi();
        } else {
          setState(() {
            _noticeMessage = '📦 Найден: $fullName (Open Food Facts)';
            _isNoticeSuccess = true;
          });
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted && _isNoticeSuccess) {
              setState(() => _noticeMessage = null);
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLookingUpBarcode = false;
        });
      }
    }
  }

  void _openRecipePicker() {
    Navigator.of(context).pop();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RecipePickerSheet(
        apiService: widget.apiService,
        date: widget.date,
        initialMealType: _selectedMealType,
        onPortionLogged: widget.onMealSaved,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final dishName = _dishNameController.text.trim();
      final weight = double.tryParse(_weightController.text.replaceAll(',', '.')) ?? 100.0;
      final calories = double.tryParse(_caloriesController.text.replaceAll(',', '.')) ?? 0.0;
      final protein = double.tryParse(_proteinController.text.replaceAll(',', '.')) ?? 0.0;
      final fat = double.tryParse(_fatController.text.replaceAll(',', '.')) ?? 0.0;
      final carbs = double.tryParse(_carbsController.text.replaceAll(',', '.')) ?? 0.0;
      final comment = _commentController.text.trim();

      // Формируем точную дату и время с учетом выбранного в календаре дня
      final now = DateTime.now();
      final isToday = widget.date.year == now.year &&
          widget.date.month == now.month &&
          widget.date.day == now.day;

      final fullDate = isToday
          ? now
          : DateTime(
              widget.date.year,
              widget.date.month,
              widget.date.day,
              now.hour,
              now.minute,
              now.second,
            );

      final createdAtStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(fullDate);

      final item = IngredientItem(
        name: dishName,
        weightG: weight > 0 ? weight : 100.0,
        calories: calories,
        protein: protein,
        fat: fat,
        carbs: carbs,
      );

      await widget.apiService.saveMeal(
        dishName: dishName,
        mealType: _selectedMealType,
        comment: comment.isNotEmpty ? comment : null,
        items: [item],
        createdAt: createdAtStr,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onMealSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Блюдо «$dishName» добавлено в дневник'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.edit_note,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Внести блюдо вручную',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            Text(
                              'Запись на ${_formatDateString(widget.date)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Category selector
                Text(
                  'Прием пищи',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                CategorySelector(
                  selected: _selectedMealType,
                  onSelected: (type) => setState(() => _selectedMealType = type),
                ),
                const SizedBox(height: 14),

                // Dish Name
                TextFormField(
                  controller: _dishNameController,
                  focusNode: _dishNameFocusNode,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Название блюда или продукта *',
                    hintText: 'например: хлеб зерновой 30г или яблоко',
                    prefixIcon: Icon(Icons.restaurant, color: AppColors.primary, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Введите название блюда';
                    }
                    return null;
                  },
                ),
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.35),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _suggestions.map((item) {
                          return InkWell(
                            onTap: () => _selectSuggestion(item),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: isDark ? AppColors.darkBorder.withOpacity(0.5) : const Color(0xFFE2E8F0),
                                    width: 0.8,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.history, color: AppColors.primary, size: 16),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.fullName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${item.calories100g.toStringAsFixed(0)} ккал/100г • Б: ${item.protein100g.toStringAsFixed(1)} • Ж: ${item.fat100g.toStringAsFixed(1)} • У: ${item.carbs100g.toStringAsFixed(1)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.north_west, color: AppColors.primary, size: 14),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),

                // Быстрые кнопки: Рецепты, Штрихкод и ИИ-расчет
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openRecipePicker,
                        icon: Icon(Icons.menu_book, size: 14, color: AppColors.primary),
                        label: Text(
                          'Рецепты',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.emerald400 : AppColors.primaryDark,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                          backgroundColor: isDark ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
                          side: BorderSide(color: isDark ? AppColors.primary.withOpacity(0.5) : AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (_isLookingUpBarcode || _isEstimatingAi) ? null : _scanBarcode,
                        icon: _isLookingUpBarcode
                            ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                            : Icon(Icons.qr_code_scanner, size: 14, color: AppColors.primary),
                        label: Text(
                          _isLookingUpBarcode ? 'Поиск...' : 'Штрихкод',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.emerald400 : AppColors.primaryDark,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                          backgroundColor: isDark ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
                          side: BorderSide(color: isDark ? AppColors.primary.withOpacity(0.5) : AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (_isLookingUpBarcode || _isEstimatingAi) ? null : _estimateWithAi,
                        icon: _isEstimatingAi
                            ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                            : Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                        label: Text(
                          _isEstimatingAi ? 'Считаем...' : 'ИИ-расчет',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.emerald400 : AppColors.primaryDark,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                          backgroundColor: isDark ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
                          side: BorderSide(color: isDark ? AppColors.primary.withOpacity(0.5) : AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_noticeMessage != null) ...[
                  const SizedBox(height: 10),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _isNoticeSuccess
                          ? (isDark ? AppColors.success.withOpacity(0.18) : const Color(0xFFECFDF5))
                          : (isDark ? const Color(0xFFF59E0B).withOpacity(0.18) : const Color(0xFFFEF3C7)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isNoticeSuccess
                            ? (isDark ? AppColors.success.withOpacity(0.5) : const Color(0xFFA7F3D0))
                            : (isDark ? const Color(0xFFF59E0B).withOpacity(0.5) : const Color(0xFFFDE68A)),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _isNoticeSuccess ? Icons.check_circle_outline : Icons.info_outline,
                          size: 18,
                          color: _isNoticeSuccess
                              ? (isDark ? AppColors.emerald400 : const Color(0xFF059669))
                              : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _noticeMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                              color: _isNoticeSuccess
                                  ? (isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46))
                                  : (isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => setState(() => _noticeMessage = null),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: _isNoticeSuccess
                                  ? (isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46))
                                  : (isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Weight
                TextFormField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Вес порции (г)',
                    hintText: '100',
                    suffixText: 'г',
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),

                // Macros Section
                Text(
                  'КБЖУ порции',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    // Calories (Primary)
                    Expanded(
                      child: TextFormField(
                        controller: _caloriesController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Калории (ккал) *',
                          hintText: '0',
                          suffixText: 'ккал',
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Обязательно';
                          }
                          final parsed = double.tryParse(val.replaceAll(',', '.'));
                          if (parsed == null || parsed < 0) {
                            return 'Неверно';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Protein
                    Expanded(
                      child: TextFormField(
                        controller: _proteinController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Белки (г)',
                          hintText: '0',
                          suffixText: 'г',
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    // Fat
                    Expanded(
                      child: TextFormField(
                        controller: _fatController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Жиры (г)',
                          hintText: '0',
                          suffixText: 'г',
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Carbs
                    Expanded(
                      child: TextFormField(
                        controller: _carbsController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Углеводы (г)',
                          hintText: '0',
                          suffixText: 'г',
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Comment
                TextFormField(
                  controller: _commentController,
                  style: TextStyle(color: textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Заметка (необязательно)',
                    hintText: 'например: рецепт мамы, без сахара',
                    prefixIcon: Icon(Icons.notes, color: Color(0xFF94A3B8), size: 20),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.error.withOpacity(0.15) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? AppColors.error.withOpacity(0.4) : const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 18, color: AppColors.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Submit button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save_outlined, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Сохранить в дневник',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
