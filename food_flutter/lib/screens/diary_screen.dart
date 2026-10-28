import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/meal_models.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';
import '../widgets/daily_summary_card.dart';
import '../widgets/macro_pill.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';

class DiaryScreen extends StatefulWidget {
  final ApiService apiService;
  final SettingsService settingsService;
  final VoidCallback onNavigateToScan;

  const DiaryScreen({
    super.key,
    required this.apiService,
    required this.settingsService,
    required this.onNavigateToScan,
  });

  @override
  State<DiaryScreen> createState() => DiaryScreenState();
}

class DiaryScreenState extends State<DiaryScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _errorMessage;
  DailySummary? _summary;

  double _targetCalories = 2000;
  double _targetProtein = 90;
  double _targetFat = 65;
  double _targetCarbs = 250;

  @override
  void initState() {
    super.initState();
    _targetCalories = widget.settingsService.targetCalories;
    _targetProtein = widget.settingsService.targetProtein;
    _targetFat = widget.settingsService.targetFat;
    _targetCarbs = widget.settingsService.targetCarbs;
    widget.settingsService.addListener(_onSettingsChanged);
    _loadSettingsAndData();
    _checkUpdateSilently();
  }

  @override
  void dispose() {
    widget.settingsService.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {
        _targetCalories = widget.settingsService.targetCalories;
        _targetProtein = widget.settingsService.targetProtein;
        _targetFat = widget.settingsService.targetFat;
        _targetCarbs = widget.settingsService.targetCarbs;
      });
    }
  }

  /// Публичный метод для полного обновления целей и сводки
  Future<void> reloadGoalsAndData() async {
    await _loadSettingsAndData();
  }

  Future<void> _checkUpdateSilently() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    try {
      final service = UpdateService();
      final info = await service.checkForUpdate();
      if (mounted && info != null && info.hasUpdate) {
        UpdateDialog.show(context, info, service);
      }
    } catch (_) {}
  }

  Future<void> _loadSettingsAndData() async {
    final cal = await widget.settingsService.getTargetCalories();
    final p = await widget.settingsService.getTargetProtein();
    final f = await widget.settingsService.getTargetFat();
    final c = await widget.settingsService.getTargetCarbs();

    if (mounted) {
      setState(() {
        _targetCalories = cal;
        _targetProtein = p;
        _targetFat = f;
        _targetCarbs = c;
      });
    }

    // Фоновая синхронизация целей КБЖУ с сервера
    widget.apiService.getGoals().then((remoteGoals) {
      if (mounted) {
        setState(() {
          _targetCalories = remoteGoals.calories;
          _targetProtein = remoteGoals.protein;
          _targetFat = remoteGoals.fat;
          _targetCarbs = remoteGoals.carbs;
        });
        widget.settingsService.saveLocalGoals(
          remoteGoals.calories,
          remoteGoals.protein,
          remoteGoals.fat,
          remoteGoals.carbs,
        );
      }
    }).catchError((_) {});

    await _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final summary = await widget.apiService.getDailySummary(_selectedDate);
      if (mounted) {
        setState(() {
          _summary = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _changeDate(int offsetDays) async {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: offsetDays));
    });
    await _loadSummary();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF10B981),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadSummary();
    }
  }

  Future<void> _confirmDeleteMeal(MealRecord meal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Удалить прием пищи?'),
        content: Text('Вы действительно хотите удалить «${meal.dishName}» из дневника?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.apiService.deleteMeal(meal.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Прием пищи удален'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        await _loadSummary();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Сегодня';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Вчера';
    }
    final tomorrow = now.add(const Duration(days: 1));
    if (date.year == tomorrow.year && date.month == tomorrow.month && date.day == tomorrow.day) {
      return 'Завтра';
    }

    try {
      return DateFormat('d MMMM yyyy', 'ru').format(date);
    } catch (_) {
      const months = [
        '', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
        'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
      ];
      final monthName = (date.month >= 1 && date.month <= 12) ? months[date.month] : '';
      return '${date.day} $monthName ${date.year}'.trim();
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final isSelectedToday = _isToday(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Дневник питания',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: _pickDate,
            tooltip: 'Выбрать дату',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: reloadGoalsAndData,
        color: const Color(0xFF10B981),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Date Switcher Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Color(0xFF0F172A)),
                    onPressed: () => _changeDate(-1),
                    tooltip: 'Предыдущий день',
                  ),
                  InkWell(
                    onTap: _pickDate,
                    child: Column(
                      children: [
                        Text(
                          _formatDateHeader(_selectedDate),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          DateFormat('yyyy-MM-dd').format(_selectedDate),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Color(0xFF0F172A)),
                    onPressed: () => _changeDate(1),
                    tooltip: 'Следующий день',
                  ),
                ],
              ),
            ),

            // Quick button to return to today if different date selected
            if (!isSelectedToday) ...[
              const SizedBox(height: 6),
              Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  icon: const Icon(Icons.today, size: 16),
                  label: const Text(
                    'Вернуться к Сегодня',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedDate = DateTime.now();
                    });
                    _loadSummary();
                  },
                ),
              ),
            ],

            const SizedBox(height: 10),

            if (_isLoading && _summary == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF10B981)),
                ),
              )
            else if (_errorMessage != null)
              Card(
                color: const Color(0xFFFEF2F2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFFECACA)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_off, size: 40, color: Color(0xFFEF4444)),
                      const SizedBox(height: 10),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Повторить попытку'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _loadSummary,
                      ),
                    ],
                  ),
                ),
              )
            else if (_summary != null) ...[
              // Summary card
              DailySummaryCard(
                summary: _summary!,
                targetCalories: _targetCalories,
                targetProtein: _targetProtein,
                targetFat: _targetFat,
                targetCarbs: _targetCarbs,
              ),
              const SizedBox(height: 20),

              // Meals list header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Приемы пищи (${_summary!.meals.length})',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16, color: Color(0xFF10B981)),
                    label: const Text('Добавить', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                    onPressed: widget.onNavigateToScan,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_summary!.meals.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.restaurant_outlined, size: 48, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 12),
                      const Text(
                        'Записей за этот день еще нет',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Сфотографируйте ваше блюдо, чтобы Gemini распознал ингредиенты и рассчитал КБЖУ',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Сфотографировать блюдо'),
                        onPressed: widget.onNavigateToScan,
                      ),
                    ],
                  ),
                )
              else
                ..._summary!.meals.map((meal) => _buildMealCard(meal)),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMealCard(MealRecord meal) {
    String timeStr = '';
    if (meal.createdAt.contains(' ')) {
      final parts = meal.createdAt.split(' ');
      if (parts.length > 1) {
        timeStr = parts[1].substring(0, 5); // HH:MM
      }
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: const Border(),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              _getMealEmoji(meal.mealType),
              style: const TextStyle(fontSize: 22),
            ),
          ),
        ),
        title: Text(
          meal.dishName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Text(
                '${meal.totalCalories.toStringAsFixed(0)} ккал • ${meal.totalWeightG.toStringAsFixed(0)} г',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
              ),
              if (timeStr.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text('($timeStr)', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              ],
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 4),
          // Total dish macros
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              MacroPill(label: 'Белки', value: '${meal.totalProtein.toStringAsFixed(1)}г', type: MacroType.protein),
              MacroPill(label: 'Жиры', value: '${meal.totalFat.toStringAsFixed(1)}г', type: MacroType.fat),
              MacroPill(label: 'Углеводы', value: '${meal.totalCarbs.toStringAsFixed(1)}г', type: MacroType.carbs),
            ],
          ),
          const SizedBox(height: 12),
          // Ingredient items
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Состав (${meal.items.length}):',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
            ),
          ),
          const SizedBox(height: 6),
          ...meal.items.map((it) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '• ${it.name}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                      ),
                    ),
                    Text(
                      '${it.weightG.toStringAsFixed(0)} г  (${it.calories.toStringAsFixed(0)} ккал)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              )),
          if (meal.comment != null && meal.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      meal.comment!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
              label: const Text('Удалить блюдо', style: TextStyle(color: Color(0xFFEF4444))),
              onPressed: () => _confirmDeleteMeal(meal),
            ),
          ),
        ],
      ),
    );
  }

  String _getMealEmoji(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return '🍳';
      case MealType.lunch:
        return '🍲';
      case MealType.dinner:
        return '🥗';
      case MealType.snack:
        return '🍎';
    }
  }
}
