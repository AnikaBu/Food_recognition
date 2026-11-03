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
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

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
            const SnackBar(
              content: Text('Прием пищи удален ✅'),
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
            color: AppColors.primary,
            child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // 1. Top Header (Date + Refresh Button)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _pickDate,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSelectedToday ? 'СЕГОДНЯ' : 'ДАТА',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              _formatDateHeader(_selectedDate),
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 20,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      InkWell(
                        onTap: _openWeeklyMacroReview,
                        borderRadius: BorderRadius.circular(16),
                        child: Tooltip(
                          message: 'Недельный обзор КБЖУ',
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCard : AppColors.lightCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.insights_rounded,
                              size: 20,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: reloadGoalsAndData,
                        borderRadius: BorderRadius.circular(16),
                        child: Tooltip(
                          message: 'Обновить дневник',
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCard : AppColors.lightCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                const Icon(Icons.refresh, size: 20, color: AppColors.primary),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 2. Horizontal Week Strip
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
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: isDark
                                    ? const [AppColors.primary, AppColors.primaryDark]
                                    : const [AppColors.primaryRoyal, AppColors.primaryDark],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              )
                            : null,
                        color: isSelected
                            ? null
                            : (isDark ? AppColors.darkCard : AppColors.lightCard),
                        borderRadius: BorderRadius.circular(16),
                        border: isSelected
                            ? null
                            : Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: (isDark ? AppColors.primary : AppColors.primaryRoyal).withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
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
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white.withOpacity(0.9)
                                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dayDate.day.toString(),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(height: 3),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
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
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
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
                              style: const TextStyle(
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
                          emoji: '🍳',
                          title: 'Завтрак',
                          badge: null,
                          bgColor: AppColors.catBreakfastBg,
                          textColor: AppColors.catBreakfastText,
                        ),
                        const SizedBox(height: 10),
                        _buildMealCategoryCard(
                          type: MealType.lunch,
                          emoji: '🥗',
                          title: 'Обед',
                          badge: 'Основной',
                          bgColor: AppColors.catLunchBg,
                          textColor: AppColors.catLunchText,
                        ),
                        const SizedBox(height: 10),
                        _buildMealCategoryCard(
                          type: MealType.dinner,
                          emoji: '🥑',
                          title: 'Ужин',
                          badge: null,
                          bgColor: AppColors.catDinnerBg,
                          textColor: AppColors.catDinnerText,
                        ),
                        const SizedBox(height: 10),
                        _buildMealCategoryCard(
                          type: MealType.snack,
                          emoji: '🍏',
                          title: 'Перекус',
                          badge: null,
                          bgColor: AppColors.catSnackBg,
                          textColor: AppColors.catSnackText,
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
    required String emoji,
    required String title,
    required String? badge,
    required Color bgColor,
    required Color textColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final meals = _summary?.meals.where((m) => m.mealType == type).toList() ?? [];
    final categoryCals = meals.fold<double>(0.0, (acc, m) => acc + m.totalCalories);
    final isExpanded = _expandedCategories.contains(type);

    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final cardBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final summaryText = meals.isEmpty
        ? 'Нет добавленных блюд'
        : meals.map((m) => m.dishName).join(', ');

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
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
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? bgColor.withOpacity(0.18) : bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? textColor.withOpacity(0.3) : Colors.transparent,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(emoji, style: const TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            if (badge != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                                ),
                                child: Text(
                                  badge,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summaryText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            categoryCals.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.macroCalorie,
                            ),
                          ),
                          Text(
                            'ккал',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 20,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ],
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
                    const SizedBox(height: 8),
                  ],
                  // Quick Add to category button
                  InkWell(
                    onTap: () => _showManualAddMealModal(mealType: type),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Добавить блюдо к «$title»',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rowBg = isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC);
    final rowBorder = isDark ? AppColors.darkBorder : AppColors.lightBorderSubtle;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rowBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.dishName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${meal.totalWeightG.toStringAsFixed(0)}г • Б: ${meal.totalProtein.toStringAsFixed(0)}г • Ж: ${meal.totalFat.toStringAsFixed(0)}г • У: ${meal.totalCarbs.toStringAsFixed(0)}г',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${meal.totalCalories.toStringAsFixed(0)} ккал',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.macroCalorie,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => _confirmDeleteMeal(meal),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.delete_outline, size: 16, color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }
}
