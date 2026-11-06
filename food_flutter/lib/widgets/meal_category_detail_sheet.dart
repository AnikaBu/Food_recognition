import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/meal_models.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'meal_edit_sheet.dart';

class MealCategoryDetailSheet extends StatefulWidget {
  final MealType mealType;
  final String title;
  final String emoji;
  final List<MealRecord> meals;
  final DateTime selectedDate;
  final double dailyTargetCalories;
  final double dailyTargetProtein;
  final double dailyTargetFat;
  final double dailyTargetCarbs;
  final ApiService apiService;
  final VoidCallback onDataChanged;
  final VoidCallback onAddMeal;

  const MealCategoryDetailSheet({
    super.key,
    required this.mealType,
    required this.title,
    required this.emoji,
    required this.meals,
    required this.selectedDate,
    required this.dailyTargetCalories,
    required this.dailyTargetProtein,
    required this.dailyTargetFat,
    required this.dailyTargetCarbs,
    required this.apiService,
    required this.onDataChanged,
    required this.onAddMeal,
  });

  static Future<void> show(
    BuildContext context, {
    required MealType mealType,
    required String title,
    required String emoji,
    required List<MealRecord> meals,
    required DateTime selectedDate,
    required double dailyTargetCalories,
    required double dailyTargetProtein,
    required double dailyTargetFat,
    required double dailyTargetCarbs,
    required ApiService apiService,
    required VoidCallback onDataChanged,
    required VoidCallback onAddMeal,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MealCategoryDetailSheet(
        mealType: mealType,
        title: title,
        emoji: emoji,
        meals: meals,
        selectedDate: selectedDate,
        dailyTargetCalories: dailyTargetCalories,
        dailyTargetProtein: dailyTargetProtein,
        dailyTargetFat: dailyTargetFat,
        dailyTargetCarbs: dailyTargetCarbs,
        apiService: apiService,
        onDataChanged: onDataChanged,
        onAddMeal: onAddMeal,
      ),
    );
  }

  @override
  State<MealCategoryDetailSheet> createState() => _MealCategoryDetailSheetState();
}

class _MealCategoryDetailSheetState extends State<MealCategoryDetailSheet> {
  late List<MealRecord> _currentMeals;

  @override
  void initState() {
    super.initState();
    _currentMeals = List.from(widget.meals);
  }

  double get _totalCalories => _currentMeals.fold(0.0, (sum, m) => sum + m.totalCalories);
  double get _totalProtein => _currentMeals.fold(0.0, (sum, m) => sum + m.totalProtein);
  double get _totalFat => _currentMeals.fold(0.0, (sum, m) => sum + m.totalFat);
  double get _totalCarbs => _currentMeals.fold(0.0, (sum, m) => sum + m.totalCarbs);
  double get _totalWeight => _currentMeals.fold(0.0, (sum, m) => sum + m.totalWeightG);

  Future<void> _openEditMeal(MealRecord meal) async {
    final updated = await MealEditSheet.show(
      context,
      meal: meal,
      apiService: widget.apiService,
      onMealUpdated: () {
        widget.onDataChanged();
      },
    );

    if (updated == true && mounted) {
      // Re-fetch or trigger parent reload; close modal if needed or let parent update
      widget.onDataChanged();
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmDeleteMeal(MealRecord meal) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Удалить блюдо?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        content: Text(
          'Вы уверены, что хотите удалить «${meal.dishName}»?',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Отмена',
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await widget.apiService.deleteMeal(meal.id);
        widget.onDataChanged();
        if (mounted) {
          setState(() {
            _currentMeals.removeWhere((m) => m.id == meal.id);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('«${meal.dishName}» удалено'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка удаления: $e'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final cardBg = isDark ? AppColors.darkCard : const Color(0xFFF8FAFC);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final dateStr = DateFormat('d MMMM, EEEE', 'ru').format(widget.selectedDate);
    final calPercent = widget.dailyTargetCalories > 0
        ? (_totalCalories / widget.dailyTargetCalories * 100).round()
        : 0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.emoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  color: textSecondary,
                  tooltip: 'Закрыть',
                ),
              ],
            ),
          ),

          Divider(color: borderColor, height: 1),

          // Content body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category KBJU summary card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ИТОГО ЗА ${widget.title.toUpperCase()}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      _totalCalories.toStringAsFixed(0),
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.macroCalorie,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'ккал',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.macroCalorie.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.macroCalorie.withOpacity(0.3)),
                              ),
                              child: Text(
                                '$calPercent% от нормы',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.macroCalorie,
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (_totalWeight > 0) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Общий вес: ${_totalWeight.toStringAsFixed(0)} г',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: textSecondary,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Macros Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildMacroMiniCard(
                                label: 'Белки',
                                value: _totalProtein,
                                target: widget.dailyTargetProtein,
                                color: AppColors.macroProtein,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMacroMiniCard(
                                label: 'Жиры',
                                value: _totalFat,
                                target: widget.dailyTargetFat,
                                color: AppColors.macroFat,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMacroMiniCard(
                                label: 'Углеводы',
                                value: _totalCarbs,
                                target: widget.dailyTargetCarbs,
                                color: AppColors.macroCarb,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Section title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Блюда и продукты (${_currentMeals.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        'Нажмите для правки',
                        style: TextStyle(
                          fontSize: 11,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Dish cards list or Empty state
                  if (_currentMeals.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.restaurant_outlined,
                            size: 36,
                            color: textSecondary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'В этом приеме пищи пока ничего нет',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Добавьте блюдо вручную или сфотографируйте',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._currentMeals.map((meal) => _buildDishDetailCard(
                          meal: meal,
                          isDark: isDark,
                          borderColor: borderColor,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        )),
                ],
              ),
            ),
          ),

          // Bottom Action: Add Meal Button
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(
              color: bg,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onAddMeal();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.add, size: 20),
                label: Text(
                  'Добавить блюдо к «${widget.title}»',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroMiniCard({
    required String label,
    required double value,
    required double target,
    required Color color,
    required bool isDark,
  }) {
    final percent = target > 0 ? (value / target * 100).round() : 0;
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorderSubtle;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                'г',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDishDetailCard({
    required MealRecord meal,
    required bool isDark,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final itemBg = isDark ? AppColors.darkCard : const Color(0xFFF8FAFC);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: itemBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openEditMeal(meal),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meal.dishName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Вес порции: ${meal.totalWeightG.toStringAsFixed(0)} г',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${meal.totalCalories.toStringAsFixed(0)} ккал',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.macroCalorie,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              color: AppColors.primary,
                              tooltip: 'Редактировать',
                              onPressed: () => _openEditMeal(meal),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.delete_outline, size: 18),
                              color: const Color(0xFF94A3B8),
                              tooltip: 'Удалить',
                              onPressed: () => _confirmDeleteMeal(meal),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Macros row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorderSubtle,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniMacroText('Белки', meal.totalProtein, AppColors.macroProtein),
                      _buildMiniMacroText('Жиры', meal.totalFat, AppColors.macroFat),
                      _buildMiniMacroText('Углеводы', meal.totalCarbs, AppColors.macroCarb),
                    ],
                  ),
                ),

                // If items have breakdown (> 1 items)
                if (meal.items.length > 1) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Ингредиенты: ' +
                        meal.items
                            .map((it) => '${it.name} (${it.weightG.toStringAsFixed(0)}г)')
                            .join(', '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniMacroText(String name, double val, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$name: ${val.toStringAsFixed(1)}г',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
