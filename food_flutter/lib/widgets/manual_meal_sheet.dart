import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/meal_models.dart';
import '../services/api_service.dart';
import 'category_selector.dart';

class ManualMealSheet extends StatefulWidget {
  final DateTime date;
  final ApiService apiService;
  final VoidCallback onMealSaved;

  const ManualMealSheet({
    super.key,
    required this.date,
    required this.apiService,
    required this.onMealSaved,
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

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedMealType = _guessMealType();
  }

  @override
  void dispose() {
    _dishNameController.dispose();
    _weightController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _carbsController.dispose();
    _commentController.dispose();
    super.dispose();
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                      color: const Color(0xFFE2E8F0),
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
                            color: const Color(0xFF10B981).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.edit_note,
                            color: Color(0xFF10B981),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Внести блюдо вручную',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Запись на ${_formatDateString(widget.date)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Category selector
                const Text(
                  'Прием пищи',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                CategorySelector(
                  selected: _selectedMealType,
                  onSelected: (type) => setState(() => _selectedMealType = type),
                ),
                const SizedBox(height: 16),

                // Dish Name
                TextFormField(
                  controller: _dishNameController,
                  decoration: InputDecoration(
                    labelText: 'Название блюда *',
                    hintText: 'например: Овсяная каша с ягодами',
                    prefixIcon: const Icon(Icons.restaurant, color: Color(0xFF10B981), size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Введите название блюда';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Weight
                TextFormField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Вес порции (г)',
                    hintText: '100',
                    suffixText: 'г',
                    prefixIcon: const Icon(Icons.scale_outlined, color: Color(0xFF10B981), size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),

                // Macros Section
                const Text(
                  'КБЖУ порции',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF475569),
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
                        decoration: InputDecoration(
                          labelText: 'Калории (ккал) *',
                          hintText: '0',
                          prefixIcon: const Icon(Icons.local_fire_department, color: Color(0xFFF97316), size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                        decoration: InputDecoration(
                          labelText: 'Белки (г)',
                          hintText: '0',
                          suffixText: 'г',
                          prefixIcon: const Icon(Icons.fitness_center, color: Color(0xFF3B82F6), size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                        decoration: InputDecoration(
                          labelText: 'Жиры (г)',
                          hintText: '0',
                          suffixText: 'г',
                          prefixIcon: const Icon(Icons.opacity, color: Color(0xFFF59E0B), size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Carbs
                    Expanded(
                      child: TextFormField(
                        controller: _carbsController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Углеводы (г)',
                          hintText: '0',
                          suffixText: 'г',
                          prefixIcon: const Icon(Icons.grain, color: Color(0xFF8B5CF6), size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Comment
                TextFormField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    labelText: 'Заметка (необязательно)',
                    hintText: 'например: рецепт мамы, без сахара',
                    prefixIcon: const Icon(Icons.notes, color: Color(0xFF94A3B8), size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 18, color: Color(0xFFEF4444)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
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
                    backgroundColor: const Color(0xFF10B981),
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
