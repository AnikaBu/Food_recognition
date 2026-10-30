import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/meal_models.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'category_selector.dart';

class RecipePickerSheet extends StatefulWidget {
  final ApiService apiService;
  final DateTime date;
  final MealType initialMealType;
  final VoidCallback onPortionLogged;

  const RecipePickerSheet({
    super.key,
    required this.apiService,
    required this.date,
    required this.initialMealType,
    required this.onPortionLogged,
  });

  @override
  State<RecipePickerSheet> createState() => _RecipePickerSheetState();
}

class _RecipePickerSheetState extends State<RecipePickerSheet> {
  List<RecipeRecord> _recipes = [];
  bool _isLoading = true;
  String? _errorMessage;

  RecipeRecord? _selectedRecipe;
  late MealType _mealType;
  final TextEditingController _weightController = TextEditingController(text: '250');
  bool _isSubmitting = false;

  double get _portionWeight => double.tryParse(_weightController.text.replaceAll(',', '.')) ?? 0.0;

  double get _portCalories => _selectedRecipe == null ? 0 : (_selectedRecipe!.calories100g * _portionWeight / 100.0);
  double get _portProtein => _selectedRecipe == null ? 0 : (_selectedRecipe!.protein100g * _portionWeight / 100.0);
  double get _portFat => _selectedRecipe == null ? 0 : (_selectedRecipe!.fat100g * _portionWeight / 100.0);
  double get _portCarbs => _selectedRecipe == null ? 0 : (_selectedRecipe!.carbs100g * _portionWeight / 100.0);

  @override
  void initState() {
    super.initState();
    _mealType = widget.initialMealType;
    _weightController.addListener(() => setState(() {}));
    _loadRecipes();
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await widget.apiService.getRecipes();
      if (!mounted) return;
      setState(() {
        _recipes = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _submitPortion() async {
    if (_selectedRecipe == null) return;
    if (_portionWeight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Укажите вес порции в граммах')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final now = DateTime.now();
      final fullDate = DateTime(
        widget.date.year,
        widget.date.month,
        widget.date.day,
        now.hour,
        now.minute,
        now.second,
      );
      final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(fullDate);

      await widget.apiService.logRecipePortion(
        recipeId: _selectedRecipe!.id,
        portionWeightG: _portionWeight,
        mealType: _mealType,
        createdAt: dateStr,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onPortionLogged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Порция «${_selectedRecipe!.title}» добавлена в дневник!'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: border)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (_selectedRecipe != null)
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        color: textPrimary,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => setState(() => _selectedRecipe = null),
                      ),
                    if (_selectedRecipe != null) const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.menu_book,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedRecipe == null ? 'Ваши рецепты' : 'Внести порцию',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          _selectedRecipe == null
                              ? 'Выберите готовое блюдо'
                              : _selectedRecipe!.title,
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

            // Body
            Flexible(
              child: _selectedRecipe == null
                  ? _buildRecipesList(textPrimary, textSecondary, border, isDark)
                  : _buildPortionForm(textPrimary, textSecondary, border, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipesList(Color textPrimary, Color textSecondary, Color border, bool isDark) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadRecipes,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_recipes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant_outlined, size: 48, color: textSecondary.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(
              'У вас пока нет сохраненных рецептов',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Создайте сложное блюдо во вкладке «Рецепты», чтобы учитывать уварку и быстро добавлять порции в дневник.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: _recipes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final r = _recipes[index];
        return InkWell(
          onTap: () => setState(() => _selectedRecipe = r),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _MiniBadge(label: '${r.calories100g.round()} ккал', color: AppColors.macroCalorie),
                          _MiniBadge(label: '${r.protein100g.toStringAsFixed(1)}г Б', color: AppColors.macroProtein),
                          _MiniBadge(label: '${r.fat100g.toStringAsFixed(1)}г Ж', color: AppColors.macroFat),
                          _MiniBadge(label: '${r.carbs100g.toStringAsFixed(1)}г У', color: AppColors.macroCarb),
                          Text(
                            'на 100 г',
                            style: TextStyle(fontSize: 11, color: textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Выбрать',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPortionForm(Color textPrimary, Color textSecondary, Color border, bool isDark) {
    final r = _selectedRecipe!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Прием пищи',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textSecondary),
          ),
          const SizedBox(height: 6),
          CategorySelector(
            selected: _mealType,
            onSelected: (t) => setState(() => _mealType = t),
          ),
          const SizedBox(height: 16),

          Text(
            'Вес вашей порции (граммы)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textSecondary),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              suffixText: 'г',
              hintText: '250',
              prefixIcon: Icon(Icons.scale, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),

          // Карточка рассчитанного КБЖУ для этой порции
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.25)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'КБЖУ порции (${_portionWeight.toStringAsFixed(0)} г):',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'из «${r.title}»',
                      style: TextStyle(fontSize: 11, color: textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _MacroTile(label: 'ккал', value: _portCalories.toStringAsFixed(0), color: AppColors.macroCalorie),
                    _MacroTile(label: 'белки', value: '${_portProtein.toStringAsFixed(1)}г', color: AppColors.macroProtein),
                    _MacroTile(label: 'жиры', value: '${_portFat.toStringAsFixed(1)}г', color: AppColors.macroFat),
                    _MacroTile(label: 'углеводы', value: '${_portCarbs.toStringAsFixed(1)}г', color: AppColors.macroCarb),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Кнопка Готово
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitPortion,
              icon: _isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, color: Colors.white),
              label: Text(
                _isSubmitting ? 'Добавление...' : 'Готово (Добавить в дневник)',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _MacroTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.darkTextSecondary),
        ),
      ],
    );
  }
}
