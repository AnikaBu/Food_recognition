import 'package:flutter/material.dart';
import '../models/meal_models.dart';
import '../services/api_service.dart';
import '../widgets/barcode_scanner_dialog.dart';

class RecipeEditorScreen extends StatefulWidget {
  final ApiService apiService;
  final RecipeRecord? initialRecipe;

  const RecipeEditorScreen({
    super.key,
    required this.apiService,
    this.initialRecipe,
  });

  @override
  State<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends State<RecipeEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _cookedWeightController;

  late List<RecipeIngredientItem> _items;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.initialRecipe;
    _titleController = TextEditingController(text: r?.title ?? '');
    _descController = TextEditingController(text: r?.description ?? '');
    _cookedWeightController = TextEditingController(
      text: r?.cookedWeightG != null ? r!.cookedWeightG!.toStringAsFixed(0) : '',
    );
    _items = r != null ? List<RecipeIngredientItem>.from(r.items) : [];

    _cookedWeightController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _cookedWeightController.dispose();
    super.dispose();
  }

  double get _rawWeight => _items.fold(0.0, (sum, it) => sum + it.weightG);
  double get _rawCalories => _items.fold(0.0, (sum, it) => sum + it.calories);
  double get _rawProtein => _items.fold(0.0, (sum, it) => sum + it.protein);
  double get _rawFat => _items.fold(0.0, (sum, it) => sum + it.fat);
  double get _rawCarbs => _items.fold(0.0, (sum, it) => sum + it.carbs);

  double get _finalCookedWeight {
    final parsed = double.tryParse(_cookedWeightController.text.trim());
    if (parsed != null && parsed > 0) return parsed;
    return _rawWeight;
  }

  double get _cal100g {
    if (_finalCookedWeight <= 0) return 0.0;
    return _rawCalories * (100.0 / _finalCookedWeight);
  }

  double get _pro100g {
    if (_finalCookedWeight <= 0) return 0.0;
    return _rawProtein * (100.0 / _finalCookedWeight);
  }

  double get _fat100g {
    if (_finalCookedWeight <= 0) return 0.0;
    return _rawFat * (100.0 / _finalCookedWeight);
  }

  double get _carb100g {
    if (_finalCookedWeight <= 0) return 0.0;
    return _rawCarbs * (100.0 / _finalCookedWeight);
  }

  // --- Добавление ингредиента по штрихкоду ---
  Future<void> _addViaBarcode() async {
    final barcode = await showDialog<String>(
      context: context,
      builder: (_) => const BarcodeScannerDialog(),
    );
    if (barcode == null || barcode.isEmpty || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🔍 Поиск товара в базе...'), duration: Duration(seconds: 1)),
    );

    try {
      final product = await widget.apiService.lookupBarcode(barcode);
      if (!mounted) return;

      final weightController = TextEditingController(text: product.weightG.toStringAsFixed(0));
      final confirmedWeight = await showDialog<double>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(product.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.brand.isNotEmpty)
                Text('Бренд: ${product.brand}', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 12),
              const Text('Укажите вес сырого ингредиента (г):', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 6),
              TextField(
                controller: weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  suffixText: 'г',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final w = double.tryParse(weightController.text.trim()) ?? product.weightG;
                Navigator.pop(ctx, w);
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      );

      if (confirmedWeight != null && confirmedWeight > 0) {
        final factor = confirmedWeight / 100.0;
        setState(() {
          _items.add(RecipeIngredientItem(
            name: product.brand.isNotEmpty ? '${product.name} (${product.brand})' : product.name,
            weightG: confirmedWeight,
            calories: double.parse((product.calories100g * factor).toStringAsFixed(1)),
            protein: double.parse((product.protein100g * factor).toStringAsFixed(1)),
            fat: double.parse((product.fat100g * factor).toStringAsFixed(1)),
            carbs: double.parse((product.carbs100g * factor).toStringAsFixed(1)),
          ));
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  // --- Добавление ингредиента через ИИ ---
  Future<void> _addViaAi() async {
    final queryController = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Color(0xFF10B981), size: 22),
            SizedBox(width: 8),
            Text('ИИ-расчет ингредиента', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Введите название и вес ингредиента, нейросеть определит КБЖУ:',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: queryController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'например: Куриное филе 350г',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, queryController.text.trim()),
            child: const Text('Рассчитать'),
          ),
        ],
      ),
    );

    if (query == null || query.isEmpty || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✨ ИИ рассчитывает КБЖУ...'), duration: Duration(seconds: 2)),
    );

    try {
      final res = await widget.apiService.estimateNutrition(query);
      if (!mounted) return;
      setState(() {
        _items.add(RecipeIngredientItem(
          name: res.name.isNotEmpty ? res.name : query,
          weightG: res.weightG,
          calories: res.calories,
          protein: res.protein,
          fat: res.fat,
          carbs: res.carbs,
        ));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  // --- Ручное добавление ингредиента ---
  Future<void> _addManual() async {
    final nameCtrl = TextEditingController();
    final weightCtrl = TextEditingController(text: '100');
    final calCtrl = TextEditingController(text: '50');
    final proCtrl = TextEditingController(text: '1.0');
    final fatCtrl = TextEditingController(text: '0.2');
    final carbCtrl = TextEditingController(text: '10.0');

    final result = await showDialog<RecipeIngredientItem>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Добавить ингредиент вручную', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Название продукта',
                  hintText: 'например: Морковь сырая',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Вес (граммы)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: calCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Ккал',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: proCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Белки',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: fatCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Жиры',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: carbCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Углеводы',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final w = double.tryParse(weightCtrl.text.trim()) ?? 100.0;
              final cal = double.tryParse(calCtrl.text.trim()) ?? 0.0;
              final p = double.tryParse(proCtrl.text.trim()) ?? 0.0;
              final f = double.tryParse(fatCtrl.text.trim()) ?? 0.0;
              final c = double.tryParse(carbCtrl.text.trim()) ?? 0.0;

              Navigator.pop(
                ctx,
                RecipeIngredientItem(
                  name: name,
                  weightG: w,
                  calories: cal,
                  protein: p,
                  fat: f,
                  carbs: c,
                ),
              );
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _items.add(result);
      });
    }
  }

  // --- Сохранение рецепта ---
  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Добавьте хотя бы один ингредиент!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final title = _titleController.text.trim();
      final desc = _descController.text.trim().isNotEmpty ? _descController.text.trim() : null;
      final cookedVal = double.tryParse(_cookedWeightController.text.trim());
      final cookedG = (cookedVal != null && cookedVal > 0) ? cookedVal : null;

      if (widget.initialRecipe != null) {
        await widget.apiService.updateRecipe(
          id: widget.initialRecipe!.id,
          title: title,
          description: desc,
          cookedWeightG: cookedG,
          items: _items,
        );
      } else {
        await widget.apiService.createRecipe(
          title: title,
          description: desc,
          cookedWeightG: cookedG,
          items: _items,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('💾 Рецепт успешно сохранен!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialRecipe != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Редактирование рецепта' : 'Конструктор рецепта'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check, color: Color(0xFF10B981)),
            onPressed: _isSaving ? null : _saveRecipe,
            tooltip: 'Сохранить рецепт',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Название блюда
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Название блюда / рецепта *',
                hintText: 'например: Борщ домашний или Сырники',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите название' : null,
            ),
            const SizedBox(height: 12),

            // Описание / Заметка
            TextFormField(
              controller: _descController,
              decoration: InputDecoration(
                labelText: 'Заметка (необязательно)',
                hintText: 'например: Варить 1 час на медленном огне',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Заголовок секции ингредиентов и кнопки добавления
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Сырые ингредиенты *',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  tooltip: 'По штрихкоду',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFE0E7FF),
                    foregroundColor: const Color(0xFF4338CA),
                  ),
                  onPressed: _addViaBarcode,
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  tooltip: 'Через ИИ',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFD1FAE5),
                    foregroundColor: const Color(0xFF059669),
                  ),
                  onPressed: _addViaAi,
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add, size: 18),
                  tooltip: 'Вручную',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: const Color(0xFF334155),
                  ),
                  onPressed: _addManual,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Список добавленных ингредиентов
            if (_items.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, color: Color(0xFF94A3B8), size: 36),
                    SizedBox(height: 8),
                    Text(
                      'Ингредиенты пока не добавлены.\nИспользуйте кнопки выше (штрихкод, ИИ или вручную).',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              )
            else
              Card(
                margin: EdgeInsets.zero,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (ctx, idx) {
                    final it = _items[idx];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(
                        '${it.weightG.toStringAsFixed(0)} г • ${it.calories.toStringAsFixed(0)} ккал '
                        '(Б:${it.protein.toStringAsFixed(1)} Ж:${it.fat.toStringAsFixed(1)} У:${it.carbs.toStringAsFixed(1)})',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Color(0xFFEF4444)),
                        onPressed: () {
                          setState(() {
                            _items.removeAt(idx);
                          });
                        },
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 12),

            // Сводка сырого веса
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Сырой вес: ${_rawWeight.toStringAsFixed(0)} г',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                  Text(
                    'Калории: ${_rawCalories.toStringAsFixed(0)} ккал',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Поле веса готового блюда (с учетом уварки)
            TextFormField(
              controller: _cookedWeightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Вес готового блюда (граммы, с учетом уварки/воды)',
                hintText: 'например: 1800',
                helperText: 'Фактический вес кастрюли/формы после варки или выпечки.\nЕсли не указан, равен сумме сырых ингредиентов.',
                helperMaxLines: 2,
                suffixText: 'г',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Карточка рассчитанного КБЖУ на 100 г готового блюда
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department, color: Color(0xFF059669), size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'КБЖУ готового блюда на 100 г:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF065F46),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _MacroPill(
                          label: 'Ккал',
                          value: _cal100g.toStringAsFixed(0),
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MacroPill(
                          label: 'Белки',
                          value: '${_pro100g.toStringAsFixed(1)}г',
                          color: const Color(0xFF3B82F6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MacroPill(
                          label: 'Жиры',
                          value: '${_fat100g.toStringAsFixed(1)}г',
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MacroPill(
                          label: 'Углев',
                          value: '${_carb100g.toStringAsFixed(1)}г',
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Кнопка Сохранить
            ElevatedButton.icon(
              icon: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Сохранение...' : 'Сохранить рецепт'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: _isSaving ? null : _saveRecipe,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
