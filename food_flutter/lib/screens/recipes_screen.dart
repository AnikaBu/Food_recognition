import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/meal_models.dart';
import '../services/api_service.dart';
import '../widgets/category_selector.dart';
import '../theme/app_colors.dart';
import 'recipe_editor_screen.dart';

class RecipesScreen extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback? onMealLogged;

  const RecipesScreen({
    super.key,
    required this.apiService,
    this.onMealLogged,
  });

  @override
  State<RecipesScreen> createState() => RecipesScreenState();
}

class RecipesScreenState extends State<RecipesScreen> {
  List<RecipeRecord> _recipes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    loadRecipes();
  }

  Future<void> loadRecipes() async {
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
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openCreateRecipe() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecipeEditorScreen(apiService: widget.apiService),
      ),
    );
    if (result == true) {
      loadRecipes();
    }
  }

  Future<void> _openEditRecipe(RecipeRecord recipe) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecipeEditorScreen(
          apiService: widget.apiService,
          initialRecipe: recipe,
        ),
      ),
    );
    if (result == true) {
      loadRecipes();
    }
  }

  Future<void> _deleteRecipe(RecipeRecord recipe) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        title: Text(
          'Удалить рецепт?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        content: Text(
          'Вы действительно хотите удалить «${recipe.title}»?',
          style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await widget.apiService.deleteRecipe(recipe.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🗑️ Рецепт удален')),
      );
      loadRecipes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showLogPortionSheet(RecipeRecord recipe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LogRecipePortionSheet(
        recipe: recipe,
        apiService: widget.apiService,
        onSuccess: () {
          widget.onMealLogged?.call();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.transparent : AppColors.lightScaffold,
      appBar: AppBar(
        title: const Text('Мои рецепты'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadRecipes,
            tooltip: 'Обновить список',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Создать рецепт'),
        onPressed: _openCreateRecipe,
      ),
      body: RefreshIndicator(
        onRefresh: loadRecipes,
        color: AppColors.primary,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 48, color: textSecondary),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: loadRecipes,
                child: const Text('Повторить попытку'),
              ),
            ],
          ),
        ),
      );
    }

    if (_recipes.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(isDark ? 0.15 : 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.restaurant_menu, size: 52, color: AppColors.primary),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Нет сохраненных рецептов',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Создавайте сложные блюда (борщ, запеканку, рагу) с сырыми ингредиентами и точным расчетом уварки/ужарки.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: textSecondary),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Создать первый рецепт'),
                    onPressed: _openCreateRecipe,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: _recipes.length,
      itemBuilder: (ctx, idx) {
        final r = _recipes[idx];
        return _RecipeCard(
          recipe: r,
          onLogPortion: () => _showLogPortionSheet(r),
          onEdit: () => _openEditRecipe(r),
          onDelete: () => _deleteRecipe(r),
        );
      },
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final RecipeRecord recipe;
  final VoidCallback onLogPortion;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RecipeCard({
    required this.recipe,
    required this.onLogPortion,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final cardBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final weightStr = recipe.cookedWeightG != null
        ? 'Готовый вес: ${recipe.cookedWeightG!.toStringAsFixed(0)}г (сырой: ${recipe.totalRawWeightG.toStringAsFixed(0)}г)'
        : 'Вес: ${recipe.totalRawWeightG.toStringAsFixed(0)}г';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок и меню действий
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.title,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textPrimary),
                      ),
                      if (recipe.description != null && recipe.description!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          recipe.description!,
                          style: TextStyle(fontSize: 13, color: textSecondary),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        weightStr,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.emerald400 : AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 20, color: textSecondary),
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: cardBorder),
                  ),
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: textPrimary),
                          const SizedBox(width: 8),
                          Text('Редактировать', style: TextStyle(color: textPrimary)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                          const SizedBox(width: 8),
                          const Text('Удалить', style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // КБЖУ на 100 г готового блюда
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MacroMini(label: 'ккал / 100г', value: recipe.calories100g.toStringAsFixed(0), color: AppColors.macroCalorie),
                  _MacroMini(label: 'белки', value: '${recipe.protein100g.toStringAsFixed(1)}г', color: AppColors.macroProtein),
                  _MacroMini(label: 'жиры', value: '${recipe.fat100g.toStringAsFixed(1)}г', color: AppColors.macroFat),
                  _MacroMini(label: 'углеводы', value: '${recipe.carbs100g.toStringAsFixed(1)}г', color: AppColors.macroCarb),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Превью ингредиентов
            if (recipe.items.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: recipe.items.take(4).map((it) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkInput : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? AppColors.darkBorder : Colors.transparent),
                    ),
                    child: Text(
                      '${it.name} ${it.weightG.toInt()}г',
                      style: TextStyle(fontSize: 11, color: textSecondary),
                    ),
                  );
                }).toList()
                  ..addAll(recipe.items.length > 4
                      ? [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '+${recipe.items.length - 4}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary),
                            ),
                          )
                        ]
                      : []),
              ),
            const SizedBox(height: 12),

            // Кнопка Внести в дневник
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Внести порцию в дневник'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: onLogPortion,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroMini extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroMini({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF94A3B8)),
        ),
      ],
    );
  }
}

class _LogRecipePortionSheet extends StatefulWidget {
  final RecipeRecord recipe;
  final ApiService apiService;
  final VoidCallback onSuccess;

  const _LogRecipePortionSheet({
    required this.recipe,
    required this.apiService,
    required this.onSuccess,
  });

  @override
  State<_LogRecipePortionSheet> createState() => _LogRecipePortionSheetState();
}

class _LogRecipePortionSheetState extends State<_LogRecipePortionSheet> {
  MealType _selectedMealType = MealType.lunch;
  final TextEditingController _weightController = TextEditingController(text: '300');
  bool _isLogging = false;

  @override
  void initState() {
    super.initState();
    _weightController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  double get _portionWeight => double.tryParse(_weightController.text.trim()) ?? 0.0;
  double get _factor => _portionWeight / 100.0;

  double get _portCalories => widget.recipe.calories100g * _factor;
  double get _portProtein => widget.recipe.protein100g * _factor;
  double get _portFat => widget.recipe.fat100g * _factor;
  double get _portCarbs => widget.recipe.carbs100g * _factor;

  Future<void> _submitPortion() async {
    if (_portionWeight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Укажите вес порции'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLogging = true);

    try {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

      await widget.apiService.logRecipePortion(
        recipeId: widget.recipe.id,
        portionWeightG: _portionWeight,
        mealType: _selectedMealType,
        createdAt: dateStr,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Порция «${widget.recipe.title}» добавлена в дневник!'),
          backgroundColor: AppColors.primary,
        ),
      );
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '➕ Внести: ${widget.recipe.title}',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textPrimary),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text('Прием пищи', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary)),
          const SizedBox(height: 6),
          CategorySelector(
            selected: _selectedMealType,
            onSelected: (type) => setState(() => _selectedMealType = type),
          ),
          const SizedBox(height: 16),

          Text('Вес вашей порции (граммы)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style: TextStyle(color: textPrimary),
            decoration: const InputDecoration(
              suffixText: 'г',
              hintText: '300',
            ),
          ),
          const SizedBox(height: 16),

          // Карточка рассчитанного КБЖУ для этой порции
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MacroMini(label: 'ккал порции', value: _portCalories.toStringAsFixed(0), color: AppColors.macroCalorie),
                _MacroMini(label: 'белки', value: '${_portProtein.toStringAsFixed(1)}г', color: AppColors.macroProtein),
                _MacroMini(label: 'жиры', value: '${_portFat.toStringAsFixed(1)}г', color: AppColors.macroFat),
                _MacroMini(label: 'углеводы', value: '${_portCarbs.toStringAsFixed(1)}г', color: AppColors.macroCarb),
              ],
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _isLogging
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: Text(_isLogging ? 'Добавление...' : 'Добавить в дневник'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: _isLogging ? null : _submitPortion,
            ),
          ),
        ],
      ),
    );
  }
}
