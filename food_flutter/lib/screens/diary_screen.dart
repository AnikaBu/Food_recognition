import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/meal_models.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';
import '../widgets/daily_summary_card.dart';
import '../widgets/macro_pill.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import '../widgets/manual_meal_sheet.dart';
import '../widgets/weekly_macro_sheet.dart';
import '../widgets/meal_edit_sheet.dart';
import '../widgets/meal_category_detail_sheet.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/theme_palette.dart';

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
  double _horizontalDragDistance = 0.0;
  int _slideDirection = 1;
  final Map<String, DailySummary> _summaryCache = {};

  String _formatDateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  double _targetCalories = 2000;
  double _targetProtein = 90;
  double _targetFat = 65;
  double _targetCarbs = 250;

  // Track expanded category cards
  final Set<MealType> _expandedCategories = {
    MealType.breakfast,
    MealType.lunch,
    MealType.dinner,
    MealType.snack,
  };

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
    _summaryCache.clear();
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

    if (!widget.settingsService.hasCustomGoals) {
      widget.apiService.getGoals().then((remoteGoals) {
        if (mounted && !widget.settingsService.hasCustomGoals && remoteGoals.calories > 0) {
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
            isExplicitUserAction: false,
          );
        }
      }).catchError((_) {});
    }

    await _loadSummary();
  }

  Future<void> _loadSummary() async {
    final key = _formatDateKey(_selectedDate);
    final cached = _summaryCache[key];

    setState(() {
      _summary = cached;
      _isLoading = (cached == null);
      _errorMessage = null;
    });

    try {
      final summary = await widget.apiService.getDailySummary(_selectedDate);
      if (mounted) {
        _summaryCache[key] = summary;
        if (_formatDateKey(_selectedDate) == key) {
          setState(() {
            _summary = summary;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted && _formatDateKey(_selectedDate) == key) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
          child: child!,
        );
      },
    );
    if (picked != null && !_isSameDay(picked, _selectedDate)) {
      final delta = picked.difference(_selectedDate).inDays;
      setState(() {
        _slideDirection = delta >= 0 ? 1 : -1;
        _selectedDate = picked;
      });
      await _loadSummary();
    }
  }

  void _changeDay(int delta) {
    final newDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day + delta,
    );
    setState(() {
      _slideDirection = delta > 0 ? 1 : -1;
      _selectedDate = newDate;
    });
    _loadSummary();
  }

  void _showManualAddMealModal({MealType? mealType}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ManualMealSheet(
        date: _selectedDate,
        apiService: widget.apiService,
        initialMealType: mealType,
        onMealSaved: () {
          _summaryCache.remove(_formatDateKey(_selectedDate));
          _loadSummary();
        },
      ),
    );
  }

  Future<void> _confirmDeleteMeal(MealRecord meal) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Удалить прием пищи?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        content: Text(
          'Вы действительно хотите удалить «${meal.dishName}» из дневника?',
          style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Отмена', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Прием пищи удален ✅'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
        _summaryCache.remove(_formatDateKey(_selectedDate));
        await _loadSummary();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка удаления: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  List<DateTime> _getWeekDates(DateTime centerDate) {
    final monday = DateTime(centerDate.year, centerDate.month, centerDate.day - (centerDate.weekday - 1));
    return List.generate(7, (i) => DateTime(monday.year, monday.month, monday.day + i));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'Сегодня';
    final yesterday = now.subtract(const Duration(days: 1));
    if (_isSameDay(date, yesterday)) return 'Вчера';
    final tomorrow = now.add(const Duration(days: 1));
    if (_isSameDay(date, tomorrow)) return 'Завтра';

    const days = ['', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
    const months = ['', 'янв.', 'февр.', 'марта', 'апр.', 'мая', 'июня', 'июля', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.'];
    return '${days[date.weekday]}, ${date.day} ${months[date.month]}';
  }

  void _openWeeklyMacroReview() {
    WeeklyMacroSheet.show(
      context,
      selectedDate: _selectedDate,
      apiService: widget.apiService,
      settingsService: widget.settingsService,
      onGoalsChanged: () {
        reloadGoalsAndData();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final weekDates = _getWeekDates(_selectedDate);
    final isSelectedToday = _isSameDay(_selectedDate, DateTime.now());

    final weekDayNames = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];

    return Scaffold(
      backgroundColor: isDark ? Colors.transparent : AppColors.lightScaffold,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (_) {
            _horizontalDragDistance = 0.0;
          },
          onHorizontalDragUpdate: (details) {
            _horizontalDragDistance += details.delta.dx;
          },
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0.0;
            if (_horizontalDragDistance < -50 || velocity < -250) {
              if (velocity <= 150) {
                _changeDay(1);
              }
            } else if (_horizontalDragDistance > 50 || velocity > 250) {
              if (velocity >= -150) {
                _changeDay(-1);
              }
            }
            _horizontalDragDistance = 0.0;
          },
          child: RefreshIndicator(
            onRefresh: reloadGoalsAndData,
            color: tokens.primary,
            child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // 1. Top Header (Centered MyFoodDiary + Date Picker & Actions)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: isDark ? tokens.cardBg : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? tokens.cardBorder : AppColors.lightBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 15,
                            color: tokens.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatDateHeader(_selectedDate),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? tokens.textPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: isDark ? tokens.textSecondary : AppColors.lightTextSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    'MyFoodDiary',
                    style: TextStyle(
                      fontSize: 17.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                      color: isDark ? tokens.textPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: _openWeeklyMacroReview,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark ? tokens.cardBg : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? tokens.cardBorder : AppColors.lightBorder),
                          ),
                          child: Icon(
                            Icons.insights_rounded,
                            size: 18,
                            color: tokens.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: reloadGoalsAndData,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark ? tokens.cardBg : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? tokens.cardBorder : AppColors.lightBorder),
                          ),
                          child: Icon(
                            Icons.refresh_rounded,
                            size: 18,
                            color: tokens.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 2. Horizontal Week Strip (Concept 1: glowing theme border on selected day)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (idx) {
                  final dayDate = weekDates[idx];
                  final isSelected = _isSameDay(dayDate, _selectedDate);

                  return GestureDetector(
                    onTap: () {
                      if (!_isSameDay(dayDate, _selectedDate)) {
                        final delta = dayDate.difference(_selectedDate).inDays;
                        setState(() {
                          _slideDirection = delta >= 0 ? 1 : -1;
                          _selectedDate = dayDate;
                        });
                        _loadSummary();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isDark ? tokens.cardBg : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? tokens.primary : (isDark ? tokens.cardBorder : AppColors.lightBorder),
                          width: isSelected ? 2.0 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: tokens.primary.withOpacity(isDark ? 0.35 : 0.20),
                                  blurRadius: 10,
                                  spreadRadius: 0.5,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            weekDayNames[idx],
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? tokens.primary
                                  : (isDark ? tokens.textSecondary : AppColors.lightTextSecondary),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dayDate.day.toString(),
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                              color: isSelected
                                  ? tokens.primary
                                  : (isDark ? tokens.textPrimary : AppColors.lightTextPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 14),

              // 3. Daily Content with Soft Directional Slide Transition
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: <Widget>[
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                transitionBuilder: (child, animation) {
                  final isIncoming = (child.key as ValueKey?)?.value == _formatDateKey(_selectedDate);
                  final beginOffset = isIncoming
                      ? Offset(_slideDirection * 0.28, 0.0)
                      : Offset(-_slideDirection * 0.28, 0.0);

                  final slideAnim = Tween<Offset>(
                    begin: beginOffset,
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: isIncoming ? Curves.easeOutCubic : Curves.easeInCubic,
                  ));

                  final fadeAnim = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOut,
                  );

                  return SlideTransition(
                    position: slideAnim,
                    child: FadeTransition(
                      opacity: fadeAnim,
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_formatDateKey(_selectedDate)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_isLoading && _summary == null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                        )
                      else if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2D1515) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.error.withOpacity(0.4)),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.cloud_off, size: 36, color: AppColors.error),
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.error, fontSize: 13),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                onPressed: _loadSummary,
                                child: const Text('Повторить', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        )
                      else if (_summary != null) ...[
                        DailySummaryCard(
                          summary: _summary!,
                          targetCalories: _targetCalories,
                          targetProtein: _targetProtein,
                          targetFat: _targetFat,
                          targetCarbs: _targetCarbs,
                        ),

                        const SizedBox(height: 18),

                        // 4. Meal Sections Accordion
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ПРИЕМЫ ПИЩИ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                            Text(
                              '${_summary!.meals.length} ${_getPluralMeals(_summary!.meals.length)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        _buildMealCategoryCard(
                          type: MealType.breakfast,
                          title: 'Завтрак',
                        ),
                        const SizedBox(height: 10),
                        _buildMealCategoryCard(
                          type: MealType.lunch,
                          title: 'Обед',
                        ),
                        const SizedBox(height: 10),
                        _buildMealCategoryCard(
                          type: MealType.dinner,
                          title: 'Ужин',
                        ),
                        const SizedBox(height: 10),
                        _buildMealCategoryCard(
                          type: MealType.snack,
                          title: 'Перекус',
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    ),
    );
  }

  String _getPluralMeals(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'прием';
    if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) return 'приема';
    return 'приемов';
  }

  Widget _buildMealCategoryCard({
    required MealType type,
    required String title,
  }) {
    final tokens = AppThemeTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final meals = _summary?.meals.where((m) => m.mealType == type).toList() ?? [];
    final categoryCals = meals.fold<double>(0.0, (acc, m) => acc + m.totalCalories);
    final isExpanded = _expandedCategories.contains(type);

    final cardBg = isDark ? tokens.cardBg : AppColors.lightCard;
    final cardBorder = isDark ? tokens.cardBorder : AppColors.lightBorder;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        children: [
          // Header click to toggle
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCategories.remove(type);
                } else {
                  _expandedCategories.add(type);
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? tokens.textPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${categoryCals.toStringAsFixed(0)} ккал',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      MealCategoryDetailSheet.show(
                        context,
                        mealType: type,
                        title: title,
                        emoji: '',
                        meals: meals,
                        selectedDate: _selectedDate,
                        dailyTargetCalories: _targetCalories,
                        dailyTargetProtein: _targetProtein,
                        dailyTargetFat: _targetFat,
                        dailyTargetCarbs: _targetCarbs,
                        apiService: widget.apiService,
                        onDataChanged: reloadGoalsAndData,
                        onAddMeal: () => _showManualAddMealModal(mealType: type),
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.open_in_new_rounded,
                        size: 16,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),

          // Expanded items list + quick add
          if (isExpanded) ...[
            Divider(color: cardBorder, height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (meals.isNotEmpty) ...[
                    ...meals.map((meal) => _buildDishRow(meal)),
                    const SizedBox(height: 4),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Нет добавленных блюд',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? tokens.textSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                  // Quick Add to category button
                  InkWell(
                    onTap: () => _showManualAddMealModal(mealType: type),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? tokens.surfaceBg : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? tokens.cardBorder : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, size: 16, color: tokens.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Добавить блюдо',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? tokens.textPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDishRow(MealRecord meal) {
    final tokens = AppThemeTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rowBorder = isDark ? tokens.cardBorder.withOpacity(0.5) : AppColors.lightBorderSubtle;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? tokens.surfaceBg : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: rowBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => MealEditSheet.show(
            context,
            meal: meal,
            apiService: widget.apiService,
            onMealUpdated: reloadGoalsAndData,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Dish Name (Left) + Calories (Right)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      meal.dishName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? tokens.textPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${meal.totalCalories.toStringAsFixed(0)} ккал',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: tokens.macroCalorie,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Bottom Row: Weight + Unified Macro Chip (Left) + Edit/Delete Icons (Right)
              Row(
                children: [
                  Text(
                    '${meal.totalWeightG.toStringAsFixed(0)}г',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? tokens.textSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Unified Macro Chip matching Mockup 1: P 12g • C 55g • F 6g
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEDF2F7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        width: 0.6,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Б ',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: tokens.macroProtein,
                          ),
                        ),
                        Text(
                          '${meal.totalProtein.toStringAsFixed(0)}г',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        Text(
                          '  •  ',
                          style: TextStyle(
                            fontSize: 8.5,
                            color: isDark ? Colors.white30 : Colors.black26,
                          ),
                        ),
                        Text(
                          'У ',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: tokens.macroCarb,
                          ),
                        ),
                        Text(
                          '${meal.totalCarbs.toStringAsFixed(0)}г',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        Text(
                          '  •  ',
                          style: TextStyle(
                            fontSize: 8.5,
                            color: isDark ? Colors.white30 : Colors.black26,
                          ),
                        ),
                        Text(
                          'Ж ',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: tokens.macroFat,
                          ),
                        ),
                        Text(
                          '${meal.totalFat.toStringAsFixed(0)}г',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Edit and Delete buttons
                  InkWell(
                    onTap: () => MealEditSheet.show(
                      context,
                      meal: meal,
                      apiService: widget.apiService,
                      onMealUpdated: reloadGoalsAndData,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _confirmDeleteMeal(meal),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
