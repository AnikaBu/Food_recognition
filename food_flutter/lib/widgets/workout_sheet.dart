import 'package:flutter/material.dart';
import '../models/meal_models.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class WorkoutSheet extends StatefulWidget {
  final DateTime date;
  final ApiService apiService;
  final VoidCallback onWorkoutSaved;

  const WorkoutSheet({
    super.key,
    required this.date,
    required this.apiService,
    required this.onWorkoutSaved,
  });

  @override
  State<WorkoutSheet> createState() => _WorkoutSheetState();
}

class _WorkoutSheetState extends State<WorkoutSheet> {
  final _formKey = GlobalKey<FormState>();

  String _selectedWorkoutType = 'run';
  final _durationController = TextEditingController(text: '45');
  final _caloriesController = TextEditingController();
  final _titleController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;

  static const List<Map<String, String>> _workoutTypes = [
    {'type': 'run', 'title': 'Бег', 'emoji': '🏃'},
    {'type': 'gym', 'title': 'Силовая', 'emoji': '🏋️'},
    {'type': 'bike', 'title': 'Велосипед', 'emoji': '🚴'},
    {'type': 'elliptical', 'title': 'Эллипс', 'emoji': '🎿'},
    {'type': 'walk', 'title': 'Ходьба', 'emoji': '🚶'},
    {'type': 'yoga', 'title': 'Растяжка', 'emoji': '🧘'},
    {'type': 'other', 'title': 'Другое', 'emoji': '⚡'},
  ];

  @override
  void dispose() {
    _durationController.dispose();
    _caloriesController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _saveWorkout() async {
    if (!_formKey.currentState!.validate()) return;

    final duration = int.tryParse(_durationController.text.trim()) ?? 0;
    if (duration <= 0) {
      setState(() => _errorMessage = 'Длительность должна быть больше 0 мин');
      return;
    }

    final calories = double.tryParse(_caloriesController.text.trim().replaceAll(',', '.')) ?? 0.0;
    final customName = _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : null;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.apiService.addWorkout(
        workoutType: _selectedWorkoutType,
        customName: customName,
        durationMinutes: duration,
        caloriesBurned: calories,
        date: widget.date,
      );

      if (mounted) {
        widget.onWorkoutSaved();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🏃 Тренировка успешно сохранена!'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tokens = AppColors.tokens(context);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? tokens.cardBg : AppColors.lightCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Индикатор для свайпа вниз
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Заголовок
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tokens.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.fitness_center_rounded,
                        color: tokens.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Внести тренировку',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: isDark ? tokens.textPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          Text(
                            'Данные активности для контекста дня (не меняют цель КБЖУ)',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? tokens.textSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? tokens.textSecondary : AppColors.lightTextSecondary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Ошибка при наличии
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: AppColors.error, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // 1. Выбор вида активности (чипы)
                Text(
                  'ВИД АКТИВНОСТИ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: isDark ? tokens.textSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _workoutTypes.map((item) {
                    final type = item['type']!;
                    final isSelected = _selectedWorkoutType == type;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          _selectedWorkoutType = type;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? tokens.primary.withOpacity(isDark ? 0.25 : 0.15)
                              : (isDark ? tokens.cardBg : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? tokens.primary
                                : (isDark ? tokens.cardBorder : const Color(0xFFE2E8F0)),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(item['emoji']!, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text(
                              item['title']!,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected
                                    ? tokens.primary
                                    : (isDark ? tokens.textPrimary : AppColors.lightTextPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // 2. Длительность и Калории в 2 колонки
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ДЛИТЕЛЬНОСТЬ (МИН)*',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: isDark ? tokens.textSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _durationController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? tokens.textPrimary : AppColors.lightTextPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: '45',
                              prefixIcon: Icon(Icons.timer_rounded, size: 18, color: tokens.primary),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Введите минуты';
                              final n = int.tryParse(val.trim());
                              if (n == null || n <= 0) return '> 0 мин';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'СОЖЖЕНО ККАЛ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: isDark ? tokens.textSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _caloriesController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? tokens.textPrimary : AppColors.lightTextPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: '350',
                              prefixIcon: const Icon(Icons.local_fire_department_rounded, size: 18, color: Color(0xFFF97316)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. Пользовательское название / заметка
                Text(
                  'НАЗВАНИЕ / ЗАМЕТКА (ОПЦИОНАЛЬНО)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: isDark ? tokens.textSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? tokens.textPrimary : AppColors.lightTextPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Например: Интервалы или день ног',
                    prefixIcon: Icon(Icons.edit_note_rounded, size: 20, color: tokens.primary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 22),

                // 4. Кнопка сохранения
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveWorkout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Сохранить тренировку',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
