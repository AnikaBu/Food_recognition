import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/meal_models.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class MealEditSheet extends StatefulWidget {
  final MealRecord meal;
  final ApiService apiService;
  final VoidCallback onMealUpdated;

  const MealEditSheet({
    super.key,
    required this.meal,
    required this.apiService,
    required this.onMealUpdated,
  });

  static Future<bool?> show(
    BuildContext context, {
    required MealRecord meal,
    required ApiService apiService,
    required VoidCallback onMealUpdated,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MealEditSheet(
        meal: meal,
        apiService: apiService,
        onMealUpdated: onMealUpdated,
      ),
    );
  }

  @override
  State<MealEditSheet> createState() => _MealEditSheetState();
}

class _MealEditSheetState extends State<MealEditSheet> {
  late final TextEditingController _dishNameController;
  late final TextEditingController _weightController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _fatController;
  late final TextEditingController _carbsController;
  late final TextEditingController _commentController;

  late MealType _selectedMealType;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isAutoUpdating = false;

  late double _cal100;
  late double _prot100;
  late double _fat100;
  late double _carb100;

  @override
  void initState() {
    super.initState();
    final m = widget.meal;
    _selectedMealType = m.mealType;

    _dishNameController = TextEditingController(text: m.dishName);
    _weightController = TextEditingController(
      text: m.totalWeightG > 0 ? m.totalWeightG.toStringAsFixed(0) : '100',
    );
    _caloriesController = TextEditingController(text: m.totalCalories.toStringAsFixed(0));
    _proteinController = TextEditingController(text: m.totalProtein.toStringAsFixed(1));
    _fatController = TextEditingController(text: m.totalFat.toStringAsFixed(1));
    _carbsController = TextEditingController(text: m.totalCarbs.toStringAsFixed(1));
    _commentController = TextEditingController(text: m.comment ?? '');

    // Расчет базиса на 100г
    final origWeight = m.totalWeightG > 0 ? m.totalWeightG : 100.0;
    final f100 = 100.0 / origWeight;
    _cal100 = m.totalCalories * f100;
    _prot100 = m.totalProtein * f100;
    _fat100 = m.totalFat * f100;
    _carb100 = m.totalCarbs * f100;

    _weightController.addListener(_onWeightChanged);
    _caloriesController.addListener(_onMacroChanged);
    _proteinController.addListener(_onMacroChanged);
    _fatController.addListener(_onMacroChanged);
    _carbsController.addListener(_onMacroChanged);
  }

  @override
  void dispose() {
    _weightController.removeListener(_onWeightChanged);
    _caloriesController.removeListener(_onMacroChanged);
    _proteinController.removeListener(_onMacroChanged);
    _fatController.removeListener(_onMacroChanged);
    _carbsController.removeListener(_onMacroChanged);

    _dishNameController.dispose();
    _weightController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _carbsController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _onWeightChanged() {
    if (_isAutoUpdating) return;
    final text = _weightController.text.replaceAll(',', '.');
    final w = double.tryParse(text);
    if (w != null && w > 0) {
      _isAutoUpdating = true;
      final factor = w / 100.0;
      _caloriesController.text = (_cal100 * factor).toStringAsFixed(0);
      _proteinController.text = (_prot100 * factor).toStringAsFixed(1);
      _fatController.text = (_fat100 * factor).toStringAsFixed(1);
      _carbsController.text = (_carb100 * factor).toStringAsFixed(1);
      _isAutoUpdating = false;
    }
  }

  void _onMacroChanged() {
    if (_isAutoUpdating) return;
    final w = double.tryParse(_weightController.text.replaceAll(',', '.')) ?? 100.0;
    if (w > 0) {
      final f100 = 100.0 / w;
      final c = double.tryParse(_caloriesController.text.replaceAll(',', '.')) ?? 0.0;
      final p = double.tryParse(_proteinController.text.replaceAll(',', '.')) ?? 0.0;
      final f = double.tryParse(_fatController.text.replaceAll(',', '.')) ?? 0.0;
      final cb = double.tryParse(_carbsController.text.replaceAll(',', '.')) ?? 0.0;
      _cal100 = c * f100;
      _prot100 = p * f100;
      _fat100 = f * f100;
      _carb100 = cb * f100;
    }
  }

  void _adjustWeight(double delta) {
    final current = double.tryParse(_weightController.text.replaceAll(',', '.')) ?? 100.0;
    final next = (current + delta).clamp(5.0, 3000.0);
    _weightController.text = next.toStringAsFixed(0);
  }

  Future<void> _saveChanges() async {
    final name = _dishNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите название блюда'), backgroundColor: AppColors.error),
      );
      return;
    }

    final weight = double.tryParse(_weightController.text.replaceAll(',', '.')) ?? widget.meal.totalWeightG;
    final calories = double.tryParse(_caloriesController.text.replaceAll(',', '.')) ?? widget.meal.totalCalories;
    final protein = double.tryParse(_proteinController.text.replaceAll(',', '.')) ?? widget.meal.totalProtein;
    final fat = double.tryParse(_fatController.text.replaceAll(',', '.')) ?? widget.meal.totalFat;
    final carbs = double.tryParse(_carbsController.text.replaceAll(',', '.')) ?? widget.meal.totalCarbs;
    final comment = _commentController.text.trim();

    setState(() => _isSaving = true);

    try {
      // Подготовка ингредиентов для обновления
      List<IngredientItem> updatedItems = [];
      if (widget.meal.items.length <= 1) {
        // Одиночный продукт/блюдо
        final firstId = widget.meal.items.isNotEmpty ? widget.meal.items.first.id : null;
        updatedItems = [
          IngredientItem(
            id: firstId,
            name: name,
            weightG: weight,
            calories: calories,
            protein: protein,
            fat: fat,
            carbs: carbs,
          )
        ];
      } else {
        // Составное блюдо (несколько ингредиентов): масштабируем ингредиенты по весу
        final origWeight = widget.meal.totalWeightG > 0 ? widget.meal.totalWeightG : weight;
        final factor = weight / origWeight;
        updatedItems = widget.meal.items.map((it) {
          return IngredientItem(
            id: it.id,
            name: it.name,
            weightG: roundDouble(it.weightG * factor, 1),
            calories: roundDouble(it.calories * factor, 1),
            protein: roundDouble(it.protein * factor, 1),
            fat: roundDouble(it.fat * factor, 1),
            carbs: roundDouble(it.carbs * factor, 1),
          );
        }).toList();
      }

      await widget.apiService.updateMeal(
        widget.meal.id,
        dishName: name,
        mealType: _selectedMealType,
        comment: comment,
        items: updatedItems,
      );

      if (mounted) {
        widget.onMealUpdated();
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Блюдо успешно обновлено ✅'),
            backgroundColor: AppColors.primary,
          ),
        );
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

  double roundDouble(double val, int places) {
    return double.parse(val.toStringAsFixed(places));
  }

  Future<void> _deleteMeal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Удалить блюдо?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          content: Text(
            '«${widget.meal.dishName}» будет удалено из дневника питания.',
            style: TextStyle(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      setState(() => _isDeleting = true);
      try {
        await widget.apiService.deleteMeal(widget.meal.id);
        if (mounted) {
          widget.onMealUpdated();
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Блюдо удалено ✅'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isDeleting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка удаления: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final bgInput = isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9);

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    String timeStr = '';
    if (widget.meal.createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(widget.meal.createdAt);
        timeStr = DateFormat('HH:mm').format(dt);
      } catch (_) {}
    }

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.90),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.5 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Полоска перетаскивания (Drag Handle)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Шапка карточки
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _selectedMealType.emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Карточка блюда',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        if (timeStr.isNotEmpty)
                          Text(
                            'Время внесения: $timeStr',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: textSecondary),
                    tooltip: 'Закрыть',
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Тело со скроллом
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  // 1. Название блюда
                  Text(
                    'НАЗВАНИЕ БЛЮДА',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _dishNameController,
                    style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: bgInput,
                      prefixIcon: Icon(Icons.restaurant_rounded, size: 20, color: AppColors.primary),
                      hintText: 'Название блюда или продукта',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Селектор категории приема пищи
                  Text(
                    'КАТЕГОРИЯ ПРИЕМА ПИЩИ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildMealTypeSelector(isDark),

                  const SizedBox(height: 16),

                  // 3. Вес порции со степперами
                  Text(
                    'ВЕС ПОРЦИИ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStepperButton(
                        label: '-10г',
                        icon: Icons.remove,
                        onTap: () => _adjustWeight(-10),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: bgInput,
                            suffixText: 'г',
                            suffixStyle: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: textSecondary,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: AppColors.primary, width: 2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStepperButton(
                        label: '+10г',
                        icon: Icons.add,
                        onTap: () => _adjustWeight(10),
                        isDark: isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 4. Сетка КБЖУ (4 карточки с интерактивным вводом)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'КБЖУ ПОРЦИИ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: textSecondary,
                        ),
                      ),
                      Text(
                        'Автопересчет по весу',
                        style: TextStyle(fontSize: 11, color: textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMacroField(
                          label: 'Калории',
                          unit: 'ккал',
                          controller: _caloriesController,
                          color: AppColors.macroCalorie,
                          icon: Icons.local_fire_department_rounded,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMacroField(
                          label: 'Белки',
                          unit: 'г',
                          controller: _proteinController,
                          color: AppColors.macroProtein,
                          icon: Icons.fitness_center_rounded,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMacroField(
                          label: 'Жиры',
                          unit: 'г',
                          controller: _fatController,
                          color: AppColors.macroFat,
                          icon: Icons.opacity_rounded,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMacroField(
                          label: 'Углеводы',
                          unit: 'г',
                          controller: _carbsController,
                          color: AppColors.macroCarb,
                          icon: Icons.grain_rounded,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),

                  // 5. Ингредиенты (если блюдо составное)
                  if (widget.meal.items.length > 1) ...[
                    const SizedBox(height: 18),
                    Text(
                      'СОСТАВ БЛЮДА (${widget.meal.items.length})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: bgInput,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Column(
                        children: widget.meal.items.map((it) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    it.name,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${it.weightG.toStringAsFixed(0)}г • ${it.calories.toStringAsFixed(0)} ккал',
                                  style: TextStyle(fontSize: 12, color: textSecondary),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  // 6. Заметка
                  const SizedBox(height: 16),
                  Text(
                    'ЗАМЕТКА / КОММЕНТАРИЙ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _commentController,
                    style: TextStyle(fontSize: 13, color: textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: bgInput,
                      hintText: 'Например: штрихкод, бренд или заметка',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 7. Кнопки сохранения и удаления
                  Row(
                    children: [
                      // Кнопка удаления
                      InkWell(
                        onTap: (_isSaving || _isDeleting) ? null : _deleteMeal,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2D1515) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.error.withOpacity(0.4)),
                          ),
                          alignment: Alignment.center,
                          child: _isDeleting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
                                )
                              : const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Кнопка сохранения
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (_isSaving || _isDeleting) ? null : _saveChanges,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Сохранить изменения',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealTypeSelector(bool isDark) {
    const types = [
      MealType.breakfast,
      MealType.lunch,
      MealType.dinner,
      MealType.snack,
    ];

    return Row(
      children: types.map((type) {
        final isSelected = _selectedMealType == type;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedMealType = type);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(type.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(
                    type.titleRu,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStepperButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroField({
    required String label,
    required String unit,
    required TextEditingController controller,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 4),
              border: InputBorder.none,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
