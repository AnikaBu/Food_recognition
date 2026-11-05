import 'package:flutter/material.dart';
import '../models/meal_models.dart';
import '../theme/app_colors.dart';

enum IngredientMeasureMode {
  grams,
  pieces,
}

class RecipeIngredientEditSheet extends StatefulWidget {
  final RecipeIngredientItem initialItem;
  final bool isNew;
  final ValueChanged<RecipeIngredientItem> onSave;
  final VoidCallback? onDelete;

  const RecipeIngredientEditSheet({
    super.key,
    required this.initialItem,
    this.isNew = false,
    required this.onSave,
    this.onDelete,
  });

  static Future<RecipeIngredientItem?> show(
    BuildContext context, {
    required RecipeIngredientItem initialItem,
    bool isNew = false,
    VoidCallback? onDelete,
  }) {
    return showModalBottomSheet<RecipeIngredientItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RecipeIngredientEditSheet(
        initialItem: initialItem,
        isNew: isNew,
        onSave: (savedItem) {
          Navigator.of(ctx).pop(savedItem);
        },
        onDelete: onDelete != null
            ? () {
                Navigator.of(ctx).pop(null);
                onDelete();
              }
            : null,
      ),
    );
  }

  @override
  State<RecipeIngredientEditSheet> createState() => _RecipeIngredientEditSheetState();
}

class _RecipeIngredientEditSheetState extends State<RecipeIngredientEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _weightController;
  late final TextEditingController _piecesController;
  late final TextEditingController _unitWeightController;

  late final TextEditingController _calController;
  late final TextEditingController _proController;
  late final TextEditingController _fatController;
  late final TextEditingController _carbController;

  late IngredientMeasureMode _mode;
  int _piecesCount = 1;
  double _unitWeightG = 55.0;

  late double _cal100;
  late double _pro100;
  late double _fat100;
  late double _carb100;

  bool _isAutoCalculating = false;
  bool _showManualMacros = false;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;

    _nameController = TextEditingController(text: item.name);

    final w = item.weightG > 0 ? item.weightG : 100.0;
    _weightController = TextEditingController(text: w.toStringAsFixed(0));

    // Вычисляем базовые КБЖУ на 100г
    final f100 = 100.0 / w;
    _cal100 = item.calories * f100;
    _pro100 = item.protein * f100;
    _fat100 = item.fat * f100;
    _carb100 = item.carbs * f100;

    _calController = TextEditingController(text: item.calories.toStringAsFixed(1));
    _proController = TextEditingController(text: item.protein.toStringAsFixed(1));
    _fatController = TextEditingController(text: item.fat.toStringAsFixed(1));
    _carbController = TextEditingController(text: item.carbs.toStringAsFixed(1));

    // Автоопределение штучности по названию
    _detectPiecesInitial(item.name, w);

    _piecesController = TextEditingController(text: '$_piecesCount');
    _unitWeightController = TextEditingController(text: _unitWeightG.toStringAsFixed(0));

    _weightController.addListener(_onWeightInputChanged);
    _piecesController.addListener(_onPiecesInputChanged);
    _unitWeightController.addListener(_onUnitWeightInputChanged);

    _calController.addListener(_onMacroManualChanged);
    _proController.addListener(_onMacroManualChanged);
    _fatController.addListener(_onMacroManualChanged);
    _carbController.addListener(_onMacroManualChanged);
  }

  void _detectPiecesInitial(String name, double totalWeight) {
    final lower = name.toLowerCase();

    // 1. Поиск шаблона "(\d+)\s*шт"
    final match = RegExp(r'(\d+)\s*шт').firstMatch(lower);
    if (match != null) {
      final p = int.tryParse(match.group(1) ?? '1') ?? 1;
      _piecesCount = p > 0 ? p : 1;
      _unitWeightG = totalWeight / _piecesCount;
      _mode = IngredientMeasureMode.pieces;
      return;
    }

    // 2. Распознавание штучных продуктов по ключевым словам
    if (lower.contains('яйц') || lower.contains('яйцо')) {
      _unitWeightG = 55.0;
      _piecesCount = (totalWeight / 55.0).round().clamp(1, 99);
      _mode = IngredientMeasureMode.pieces;
    } else if (lower.contains('банан')) {
      _unitWeightG = 120.0;
      _piecesCount = (totalWeight / 120.0).round().clamp(1, 99);
      _mode = IngredientMeasureMode.pieces;
    } else if (lower.contains('яблок')) {
      _unitWeightG = 150.0;
      _piecesCount = (totalWeight / 150.0).round().clamp(1, 99);
      _mode = IngredientMeasureMode.pieces;
    } else {
      _unitWeightG = totalWeight > 0 ? totalWeight : 100.0;
      _piecesCount = 1;
      _mode = IngredientMeasureMode.grams;
    }
  }

  @override
  void dispose() {
    _weightController.removeListener(_onWeightInputChanged);
    _piecesController.removeListener(_onPiecesInputChanged);
    _unitWeightController.removeListener(_onUnitWeightInputChanged);

    _calController.removeListener(_onMacroManualChanged);
    _proController.removeListener(_onMacroManualChanged);
    _fatController.removeListener(_onMacroManualChanged);
    _carbController.removeListener(_onMacroManualChanged);

    _nameController.dispose();
    _weightController.dispose();
    _piecesController.dispose();
    _unitWeightController.dispose();
    _calController.dispose();
    _proController.dispose();
    _fatController.dispose();
    _carbController.dispose();
    super.dispose();
  }

  void _onWeightInputChanged() {
    if (_isAutoCalculating) return;
    final w = double.tryParse(_weightController.text.trim().replaceAll(',', '.'));
    if (w != null && w > 0) {
      _recalcMacrosFromWeight(w);
      if (_unitWeightG > 0) {
        _isAutoCalculating = true;
        _piecesCount = (w / _unitWeightG).round().clamp(1, 999);
        _piecesController.text = '$_piecesCount';
        _isAutoCalculating = false;
      }
    }
  }

  void _onPiecesInputChanged() {
    if (_isAutoCalculating) return;
    final p = int.tryParse(_piecesController.text.trim());
    if (p != null && p > 0) {
      _piecesCount = p;
      final newWeight = _piecesCount * _unitWeightG;
      _isAutoCalculating = true;
      _weightController.text = newWeight.toStringAsFixed(0);
      _isAutoCalculating = false;
      _recalcMacrosFromWeight(newWeight);
      _updateNameWithPiecesIfApplicable(_piecesCount);
    }
  }

  void _onUnitWeightInputChanged() {
    if (_isAutoCalculating) return;
    final uw = double.tryParse(_unitWeightController.text.trim().replaceAll(',', '.'));
    if (uw != null && uw > 0) {
      _unitWeightG = uw;
      final newWeight = _piecesCount * _unitWeightG;
      _isAutoCalculating = true;
      _weightController.text = newWeight.toStringAsFixed(0);
      _isAutoCalculating = false;
      _recalcMacrosFromWeight(newWeight);
    }
  }

  void _recalcMacrosFromWeight(double weightG) {
    final factor = weightG / 100.0;
    _isAutoCalculating = true;
    _calController.text = (_cal100 * factor).toStringAsFixed(1);
    _proController.text = (_pro100 * factor).toStringAsFixed(1);
    _fatController.text = (_fat100 * factor).toStringAsFixed(1);
    _carbController.text = (_carb100 * factor).toStringAsFixed(1);
    _isAutoCalculating = false;
    setState(() {});
  }

  void _onMacroManualChanged() {
    if (_isAutoCalculating) return;
    setState(() {});
  }

  void _adjustWeight(double delta) {
    final current = double.tryParse(_weightController.text.trim().replaceAll(',', '.')) ?? 100.0;
    final next = (current + delta).clamp(5.0, 5000.0);
    _weightController.text = next.toStringAsFixed(0);
  }

  void _adjustPieces(int delta) {
    final next = (_piecesCount + delta).clamp(1, 99);
    _piecesController.text = '$next';
  }

  void _updateNameWithPiecesIfApplicable(int count) {
    final name = _nameController.text;
    if (RegExp(r'\(\d+\s*шт\)').hasMatch(name)) {
      _nameController.text = name.replaceAll(RegExp(r'\(\d+\s*шт\)'), '($count шт)');
    } else if (RegExp(r'\d+\s*шт').hasMatch(name)) {
      _nameController.text = name.replaceAll(RegExp(r'\d+\s*шт'), '$count шт');
    }
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final weight = double.tryParse(_weightController.text.trim().replaceAll(',', '.')) ?? 100.0;
    final cal = double.tryParse(_calController.text.trim().replaceAll(',', '.')) ?? 0.0;
    final pro = double.tryParse(_proController.text.trim().replaceAll(',', '.')) ?? 0.0;
    final fat = double.tryParse(_fatController.text.trim().replaceAll(',', '.')) ?? 0.0;
    final carb = double.tryParse(_carbController.text.trim().replaceAll(',', '.')) ?? 0.0;

    final updated = RecipeIngredientItem(
      id: widget.initialItem.id,
      name: name,
      weightG: weight,
      calories: double.parse(cal.toStringAsFixed(1)),
      protein: double.parse(pro.toStringAsFixed(1)),
      fat: double.parse(fat.toStringAsFixed(1)),
      carbs: double.parse(carb.toStringAsFixed(1)),
    );

    widget.onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final cardBg = isDark ? AppColors.darkCard : const Color(0xFFF8FAFC);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final currentWeight = double.tryParse(_weightController.text.trim().replaceAll(',', '.')) ?? 0.0;
    final currentCal = double.tryParse(_calController.text.trim().replaceAll(',', '.')) ?? 0.0;
    final currentPro = double.tryParse(_proController.text.trim().replaceAll(',', '.')) ?? 0.0;
    final currentFat = double.tryParse(_fatController.text.trim().replaceAll(',', '.')) ?? 0.0;
    final currentCarb = double.tryParse(_carbController.text.trim().replaceAll(',', '.')) ?? 0.0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4)),
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
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.scale_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isNew ? 'Добавление в рецепт' : 'Редактирование ингредиента',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        'Настройте вес или количество штук',
                        style: TextStyle(fontSize: 11, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  color: textSecondary,
                ),
              ],
            ),
          ),

          Divider(color: borderColor, height: 1),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Название ингредиента
                  Text(
                    'Название продукта',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
                    decoration: InputDecoration(
                      hintText: 'например: Мука пшеничная',
                      prefixIcon: const Icon(Icons.restaurant, size: 18, color: AppColors.primary),
                      filled: true,
                      fillColor: cardBg,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Переключатель режима: Граммы / Штуки
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _mode = IngredientMeasureMode.grams),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _mode == IngredientMeasureMode.grams
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '⚖️ По весу (граммы)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _mode == IngredientMeasureMode.grams ? Colors.white : textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _mode = IngredientMeasureMode.pieces),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _mode == IngredientMeasureMode.pieces
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '🥚 По штукам (шт)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _mode == IngredientMeasureMode.pieces ? Colors.white : textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Блок управления в зависимости от режима
                  if (_mode == IngredientMeasureMode.pieces) ...[
                    // Режим штук
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Количество штук',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
                              ),
                              Text(
                                'Итого: ${currentWeight.toStringAsFixed(0)} г',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildStepBtn(
                                icon: Icons.remove,
                                onTap: () => _adjustPieces(-1),
                                isDark: isDark,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _piecesController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textPrimary),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: isDark ? AppColors.darkSurface : Colors.white,
                                    suffixText: 'шт',
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              _buildStepBtn(
                                icon: Icons.add,
                                onTap: () => _adjustPieces(1),
                                isDark: isDark,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Вес 1 штуки:',
                                style: TextStyle(fontSize: 11, color: textSecondary),
                              ),
                              SizedBox(
                                width: 90,
                                height: 36,
                                child: TextFormField(
                                  controller: _unitWeightController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: isDark ? AppColors.darkSurface : Colors.white,
                                    suffixText: 'г',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Режим граммов
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Вес ингредиента',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildStepBtn(
                                icon: Icons.remove,
                                onTap: () => _adjustWeight(-10),
                                isDark: isDark,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _weightController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textPrimary),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: isDark ? AppColors.darkSurface : Colors.white,
                                    suffixText: 'г',
                                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              _buildStepBtn(
                                icon: Icons.add,
                                onTap: () => _adjustWeight(10),
                                isDark: isDark,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Быстрые кнопки регулировки
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildQuickChip('-50г', () => _adjustWeight(-50), isDark),
                                const SizedBox(width: 6),
                                _buildQuickChip('-10г', () => _adjustWeight(-10), isDark),
                                const SizedBox(width: 6),
                                _buildQuickChip('+10г', () => _adjustWeight(10), isDark),
                                const SizedBox(width: 6),
                                _buildQuickChip('+50г', () => _adjustWeight(50), isDark),
                                const SizedBox(width: 6),
                                _buildQuickChip('+100г', () => _adjustWeight(100), isDark),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // КБЖУ превью карточка
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ИТОГО КБЖУ НА ПОРЦИЮ',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: textSecondary,
                              ),
                            ),
                            InkWell(
                              onTap: () => setState(() => _showManualMacros = !_showManualMacros),
                              child: Row(
                                children: [
                                  Text(
                                    _showManualMacros ? 'Скрыть поля' : 'Ручные правки',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Icon(
                                    _showManualMacros ? Icons.expand_less : Icons.expand_more,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // 4 плашки нутриентов
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricTile(
                                label: 'Калории',
                                value: currentCal.toStringAsFixed(0),
                                unit: 'ккал',
                                color: AppColors.macroCalorie,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildMetricTile(
                                label: 'Белки',
                                value: currentPro.toStringAsFixed(1),
                                unit: 'г',
                                color: AppColors.macroProtein,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildMetricTile(
                                label: 'Жиры',
                                value: currentFat.toStringAsFixed(1),
                                unit: 'г',
                                color: AppColors.macroFat,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildMetricTile(
                                label: 'Углеводы',
                                value: currentCarb.toStringAsFixed(1),
                                unit: 'г',
                                color: AppColors.macroCarb,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),

                        // Поля для тонкой ручной правки КБЖУ при необходимости
                        if (_showManualMacros) ...[
                          const SizedBox(height: 14),
                          Divider(color: borderColor, height: 1),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMiniField('Ккал', _calController, textPrimary, isDark),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _buildMiniField('Белки', _proController, textPrimary, isDark),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _buildMiniField('Жиры', _fatController, textPrimary, isDark),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _buildMiniField('Углеводы', _carbController, textPrimary, isDark),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Action Buttons
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(
              color: bg,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                if (!widget.isNew && widget.onDelete != null) ...[
                  IconButton.filledTonal(
                    onPressed: widget.onDelete,
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF3B1D22) : const Color(0xFFFEE2E2),
                      foregroundColor: const Color(0xFFEF4444),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      minimumSize: const Size(52, 52),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 22),
                    tooltip: 'Удалить из рецепта',
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: Icon(widget.isNew ? Icons.add_rounded : Icons.check_rounded, size: 20),
                      label: Text(
                        widget.isNew ? 'Добавить в рецепт' : 'Сохранить изменения',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBtn({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: AppColors.primary),
      ),
    );
  }

  Widget _buildQuickChip(String label, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorderSubtle,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String unit,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorderSubtle,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 9,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniField(
    String label,
    TextEditingController controller,
    Color textPrimary,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? AppColors.darkSurface : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          ),
        ),
      ],
    );
  }
}
