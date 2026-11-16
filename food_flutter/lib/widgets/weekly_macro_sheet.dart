import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/meal_models.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';

class WeeklyMacroSheet extends StatefulWidget {
  final DateTime selectedDate;
  final ApiService apiService;
  final SettingsService settingsService;
  final VoidCallback? onGoalsChanged;

  const WeeklyMacroSheet({
    super.key,
    required this.selectedDate,
    required this.apiService,
    required this.settingsService,
    this.onGoalsChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required DateTime selectedDate,
    required ApiService apiService,
    required SettingsService settingsService,
    VoidCallback? onGoalsChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WeeklyMacroSheet(
        selectedDate: selectedDate,
        apiService: apiService,
        settingsService: settingsService,
        onGoalsChanged: onGoalsChanged,
      ),
    );
  }

  @override
  State<WeeklyMacroSheet> createState() => _WeeklyMacroSheetState();
}

class _WeeklyMacroSheetState extends State<WeeklyMacroSheet> {
  WeeklyMacroSummary? _summary;
  bool _isLoading = true;
  String? _errorMessage;
  String _mode = 'week'; // 'week' (ПН-ВС) или 'trailing' (последние 7 дней)
  late String _selectedDayDate;

  WeeklyReportResult? _aiReport;
  bool _isGeneratingReport = false;
  String? _aiReportError;

  @override
  void initState() {
    super.initState();
    _selectedDayDate = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    widget.settingsService.addListener(_onSettingsChanged);
    _loadSummary();
  }

  @override
  void dispose() {
    widget.settingsService.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _aiReport = null;
      _aiReportError = null;
    });

    try {
      final summary = await widget.apiService.getWeeklyMacroSummary(
        date: widget.selectedDate,
        mode: _mode,
      );
      if (mounted) {
        setState(() {
          _summary = summary;
          _isLoading = false;
          if (!summary.days.any((d) => d.date == _selectedDayDate) &&
              summary.days.isNotEmpty) {
            _selectedDayDate = summary.days.last.date;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  String _formatDateRange(String startStr, String endStr) {
    if (startStr.isEmpty || endStr.isEmpty) return '';
    try {
      final start = DateTime.parse(startStr);
      final end = DateTime.parse(endStr);
      const months = [
        '',
        'янв.',
        'февр.',
        'марта',
        'апр.',
        'мая',
        'июня',
        'июля',
        'авг.',
        'сент.',
        'окт.',
        'нояб.',
        'дек.'
      ];
      if (start.month == end.month) {
        return '${start.day} – ${end.day} ${months[start.month]}';
      } else {
        return '${start.day} ${months[start.month]} – ${end.day} ${months[end.month]}';
      }
    } catch (_) {
      return '$startStr – $endStr';
    }
  }

  String _formatShortDayLabel(WeeklyMacroDay day) {
    try {
      final dt = DateTime.parse(day.date);
      const months = [
        '',
        'янв.',
        'февр.',
        'мар.',
        'апр.',
        'мая',
        'июн.',
        'июл.',
        'авг.',
        'сен.',
        'окт.',
        'ноя.',
        'дек.'
      ];
      return '${day.dayName}, ${dt.day} ${months[dt.month]}';
    } catch (_) {
      return day.dayName;
    }
  }

  List<WeeklyMacroDay> _loggedDays(WeeklyMacroSummary s) {
    return s.days
        .where(
          (d) =>
              d.mealsCount > 0 ||
              d.calories > 0 ||
              d.protein > 0 ||
              d.fat > 0 ||
              d.carbs > 0,
        )
        .toList();
  }

  String _activeDaysText(int count) {
    if (count == 0) return 'нет записей';
    if (count == 1) return '1 активн. день';
    if (count >= 2 && count <= 4) return '$count активн. дня';
    return '$count активн. дней';
  }

  Future<void> _generateAiReport({
    required double targetCalories,
    required double targetProtein,
    required double targetFat,
    required double targetCarbs,
  }) async {
    setState(() {
      _isGeneratingReport = true;
      _aiReportError = null;
    });

    try {
      final report = await widget.apiService.generateWeeklyReport(
        date: widget.selectedDate,
        mode: _mode,
        targetCalories: targetCalories,
        targetProtein: targetProtein,
        targetFat: targetFat,
        targetCarbs: targetCarbs,
      );
      if (mounted) {
        setState(() {
          _aiReport = report;
          _isGeneratingReport = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiReportError = e.toString().replaceFirst('Exception: ', '');
          _isGeneratingReport = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    final int activeCount =
        _summary != null ? _loggedDays(_summary!).length : 0;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.92),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.5 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Верхняя полоска перетаскивания (Drag Handle)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Шапка диалога
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Динамика',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (_summary != null)
                          Text(
                            '${_formatDateRange(_summary!.startDate, _summary!.endDate)} • ${_activeDaysText(activeCount)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      // Переключатель режима (Неделя / 7 дней)
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface
                              : AppColors.lightBorderSubtle,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            _buildModeTab('ПН–ВС', 'week', isDark),
                            _buildModeTab('7 дней', 'trailing', isDark),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        tooltip: 'Закрыть',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Тело шторки
            Flexible(
              child: _isLoading
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error_outline_rounded,
                                    size: 42, color: Colors.red.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadSummary,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Повторить'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _buildMacroCards(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab(String label, String modeValue, bool isDark) {
    final isSelected = _mode == modeValue;
    return GestureDetector(
      onTap: () {
        if (_mode != modeValue) {
          setState(() {
            _mode = modeValue;
          });
          _loadSummary();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedDayBanner(WeeklyMacroSummary s, bool isDark) {
    final selectedDay = s.days.firstWhere(
      (d) => d.date == _selectedDayDate,
      orElse: () => s.days.last,
    );
    final hasData = selectedDay.mealsCount > 0 ||
        selectedDay.calories > 0 ||
        selectedDay.protein > 0 ||
        selectedDay.fat > 0 ||
        selectedDay.carbs > 0;

    final label = _formatShortDayLabel(selectedDay);
    final summaryText = hasData
        ? '${selectedDay.calories.toStringAsFixed(0)} ккал • Б ${selectedDay.protein.toStringAsFixed(0)} • Ж ${selectedDay.fat.toStringAsFixed(0)} • У ${selectedDay.carbs.toStringAsFixed(0)}'
        : 'записей за этот день нет';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.28),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.touch_app_rounded, size: 15, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: summaryText,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCards(bool isDark) {
    final s = _summary!;
    final logged = _loggedDays(s);
    final activeCount = logged.length;

    double avgOf(double Function(WeeklyMacroDay) getter) {
      if (activeCount == 0) return 0.0;
      final total = logged.fold<double>(0.0, (sum, d) => sum + getter(d));
      return total / activeCount;
    }

    // Цели берем из SettingsService (актуальные цели пользователя, отображаемые в дневнике),
    // чтобы показатели в статистике динамики были согласованы со сводкой дня
    final targetCalories = widget.settingsService.targetCalories > 0
        ? widget.settingsService.targetCalories
        : (s.targetCalories > 0
            ? s.targetCalories
            : SettingsService.defaultTargetCalories);
    final targetProtein = widget.settingsService.targetProtein > 0
        ? widget.settingsService.targetProtein
        : (s.targetProtein > 0
            ? s.targetProtein
            : SettingsService.defaultTargetProtein);
    final targetFat = widget.settingsService.targetFat > 0
        ? widget.settingsService.targetFat
        : (s.targetFat > 0 ? s.targetFat : SettingsService.defaultTargetFat);
    final targetCarbs = widget.settingsService.targetCarbs > 0
        ? widget.settingsService.targetCarbs
        : (s.targetCarbs > 0
            ? s.targetCarbs
            : SettingsService.defaultTargetCarbs);

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (s.days.isNotEmpty) ...[
          _buildSelectedDayBanner(s, isDark),
          const SizedBox(height: 12),
        ],

        // 1. Калории
        _buildMacroCard(
          title: 'Калории',
          unit: 'ккал',
          avgValue: avgOf((d) => d.calories),
          targetValue: targetCalories,
          macroColor: AppColors.macroCalorie,
          macroColorLight: AppColors.macroCalorieLight,
          days: s.days,
          getValue: (d) => d.calories,
          isDark: isDark,
        ),
        const SizedBox(height: 12),

        // 2. Белок
        _buildMacroCard(
          title: 'Белок',
          unit: 'г',
          avgValue: avgOf((d) => d.protein),
          targetValue: targetProtein,
          macroColor: AppColors.macroProtein,
          macroColorLight: AppColors.macroProteinLight,
          days: s.days,
          getValue: (d) => d.protein,
          isDark: isDark,
        ),
        const SizedBox(height: 12),

        // 3. Жиры
        _buildMacroCard(
          title: 'Жиры',
          unit: 'г',
          avgValue: avgOf((d) => d.fat),
          targetValue: targetFat,
          macroColor: AppColors.macroFat,
          macroColorLight: AppColors.macroFatLight,
          days: s.days,
          getValue: (d) => d.fat,
          isDark: isDark,
        ),
        const SizedBox(height: 12),

        // 4. Углеводы
        _buildMacroCard(
          title: 'Углев.',
          unit: 'г',
          avgValue: avgOf((d) => d.carbs),
          targetValue: targetCarbs,
          macroColor: AppColors.macroCarb,
          macroColorLight: AppColors.macroCarbLight,
          days: s.days,
          getValue: (d) => d.carbs,
          isDark: isDark,
        ),
        const SizedBox(height: 18),

        // 5. Анализ недели (локальный разбор КБЖУ + опциональный ИИ-отчет)
        _buildWeeklyAnalysisCard(
          summary: s,
          loggedDays: logged,
          avgCalories: avgOf((d) => d.calories),
          avgProtein: avgOf((d) => d.protein),
          avgFat: avgOf((d) => d.fat),
          avgCarbs: avgOf((d) => d.carbs),
          targetCalories: targetCalories,
          targetProtein: targetProtein,
          targetFat: targetFat,
          targetCarbs: targetCarbs,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildWeeklyAnalysisCard({
    required WeeklyMacroSummary summary,
    required List<WeeklyMacroDay> loggedDays,
    required double avgCalories,
    required double avgProtein,
    required double avgFat,
    required double avgCarbs,
    required double targetCalories,
    required double targetProtein,
    required double targetFat,
    required double targetCarbs,
    required bool isDark,
  }) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final activeCount = loggedDays.length;

    final List<({Color color, String label, String text})> insights = [];
    WeeklyMacroDay? bestDay;

    if (activeCount > 0) {
      // 1. Калории
      final calPct = targetCalories > 0 ? avgCalories / targetCalories : 1.0;
      final calDiff = avgCalories - targetCalories;
      if (calPct >= 0.90 && calPct <= 1.07) {
        insights.add((
          color: AppColors.success,
          label: 'Калории',
          text:
              'в коридоре нормы — в среднем ${avgCalories.round()} из ${targetCalories.round()} ккал/день.',
        ));
      } else if (calPct > 1.07) {
        insights.add((
          color: AppColors.error,
          label: 'Калории',
          text:
              'превышение в среднем на +${calDiff.round()} ккал/день (норма ${targetCalories.round()}).',
        ));
      } else {
        insights.add((
          color: AppColors.primary,
          label: 'Калории',
          text:
              'недобор ~${(-calDiff).round()} ккал/день до цели ${targetCalories.round()} ккал.',
        ));
      }

      // 2. Белок
      final pPct = targetProtein > 0 ? avgProtein / targetProtein : 1.0;
      final pDiff = avgProtein - targetProtein;
      if (pPct < 0.88) {
        insights.add((
          color: AppColors.warning,
          label: 'Белок',
          text:
              'не доедаете ~${(-pDiff).round()} г/день (${avgProtein.round()} из ${targetProtein.round()} г) — стоит добавить филе, рыбу, творог или яйца.',
        ));
      } else if (pPct > 1.15) {
        insights.add((
          color: AppColors.macroProtein,
          label: 'Белок',
          text: 'хороший запас (+${pDiff.round()} г/день сверх цели).',
        ));
      } else {
        insights.add((
          color: AppColors.success,
          label: 'Белок',
          text:
              'держится отлично — ${avgProtein.round()} из ${targetProtein.round()} г/день.',
        ));
      }

      // 3. Жиры
      final fPct = targetFat > 0 ? avgFat / targetFat : 1.0;
      final fDiff = avgFat - targetFat;
      if (fPct > 1.10) {
        insights.add((
          color: AppColors.error,
          label: 'Жиры',
          text:
              'перебор в среднем на +${fDiff.round()} г/день (норма ${targetFat.round()} г).',
        ));
      } else if (fPct < 0.75) {
        insights.add((
          color: AppColors.warning,
          label: 'Жиры',
          text:
              'маловато жиров (~−${(-fDiff).round()} г/день до ${targetFat.round()} г).',
        ));
      } else {
        insights.add((
          color: AppColors.success,
          label: 'Жиры',
          text:
              'в пределах нормы (${avgFat.round()} из ${targetFat.round()} г/день).',
        ));
      }

      // 4. Углеводы
      final cPct = targetCarbs > 0 ? avgCarbs / targetCarbs : 1.0;
      final cDiff = avgCarbs - targetCarbs;
      if (cPct > 1.12) {
        insights.add((
          color: AppColors.warning,
          label: 'Углеводы',
          text:
              'выше нормы на +${cDiff.round()} г/день (${avgCarbs.round()} г).',
        ));
      } else if (cPct < 0.78) {
        insights.add((
          color: AppColors.primary,
          label: 'Углеводы',
          text:
              'ниже цели на ${(-cDiff).round()} г/день (${avgCarbs.round()} из ${targetCarbs.round()} г).',
        ));
      } else {
        insights.add((
          color: AppColors.success,
          label: 'Углеводы',
          text:
              'в балансе (${avgCarbs.round()} из ${targetCarbs.round()} г/день).',
        ));
      }

      // 5. Самый сбалансированный день (если >= 2 активных дней)
      if (activeCount >= 2) {
        double bestScore = double.infinity;
        for (final d in loggedDays) {
          final sCal = targetCalories > 0
              ? ((d.calories - targetCalories).abs() / targetCalories)
              : 0.0;
          final sProt = targetProtein > 0
              ? ((d.protein - targetProtein).abs() / targetProtein)
              : 0.0;
          final sFat =
              targetFat > 0 ? ((d.fat - targetFat).abs() / targetFat) : 0.0;
          final sCarb = targetCarbs > 0
              ? ((d.carbs - targetCarbs).abs() / targetCarbs)
              : 0.0;
          final score = sCal + sProt + sFat + sCarb;
          if (score < bestScore) {
            bestScore = score;
            bestDay = d;
          }
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Заголовок блока "Анализ недели"
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.insights_rounded,
                  size: 19,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Анализ недели',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
              ),
              if (activeCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkCard
                        : AppColors.lightBorderSubtle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _activeDaysText(activeCount),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          if (activeCount == 0)
            Text(
              'Пока нет записей за этот период. Добавьте приемы пищи, чтобы получить автоматический анализ КБЖУ и рекомендации.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: textSecondary,
              ),
            )
          else ...[
            // Локальный моментальный анализ по КБЖУ
            ...insights.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: item.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: textSecondary,
                          ),
                          children: [
                            TextSpan(
                              text: '${item.label}: ',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            TextSpan(text: item.text),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (bestDay != null) ...[
              const SizedBox(height: 2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.success.withOpacity(0.28),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.emoji_events_outlined,
                      size: 16,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Самый ровный день — ${_formatShortDayLabel(bestDay)} (${bestDay.calories.round()} ккал)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Персональный ИИ-отчет по реальным блюдам (по запросу)
            if (_aiReport != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(isDark ? 0.12 : 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.30),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _aiReport!.headline,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: _isGeneratingReport
                              ? null
                              : () => _generateAiReport(
                                    targetCalories: targetCalories,
                                    targetProtein: targetProtein,
                                    targetFat: targetFat,
                                    targetCarbs: targetCarbs,
                                  ),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.refresh_rounded,
                              size: 17,
                              color: textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_aiReport!.summary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _aiReport!.summary,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: textSecondary,
                        ),
                      ),
                    ],
                    if (_aiReport!.strengths.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ..._aiReport!.strengths.map(
                        (sItem) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            '✓ $sItem',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFF6EE7B7)
                                  : const Color(0xFF047857),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (_aiReport!.recommendations.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ..._aiReport!.recommendations.map(
                        (rec) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            '• $rec',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              if (_aiReportError != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _aiReportError!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
              OutlinedButton.icon(
                onPressed: _isGeneratingReport
                    ? null
                    : () => _generateAiReport(
                          targetCalories: targetCalories,
                          targetProtein: targetProtein,
                          targetFat: targetFat,
                          targetCarbs: targetCarbs,
                        ),
                icon: _isGeneratingReport
                    ? SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : Icon(
                        Icons.auto_awesome,
                        size: 17,
                        color: AppColors.primary,
                      ),
                label: Text(
                  _isGeneratingReport
                      ? 'ИИ анализирует рацион...'
                      : 'Подробный разбор блюд от ИИ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  side: BorderSide(
                    color: AppColors.primary.withOpacity(0.45),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMacroCard({
    required String title,
    required String unit,
    required double avgValue,
    required double targetValue,
    required Color macroColor,
    required Color macroColorLight,
    required List<WeeklyMacroDay> days,
    required double Function(WeeklyMacroDay) getValue,
    required bool isDark,
  }) {
    const double barHeight = 76.0;
    const double barWidth = 20.0;

    double maxRatioInWeek = 0.0;
    for (final d in days) {
      if (targetValue > 0) {
        final r = getValue(d) / targetValue;
        if (r > maxRatioInWeek) maxRatioInWeek = r;
      }
    }

    // Потолок шкалы минимум 1.35x от цели (~74% высота цели), чтобы всегда оставалась зона перелива
    final double maxScaleRatio =
        math.max(1.35, (maxRatioInWeek * 1.08).clamp(1.35, 2.5));
    final double goalLineFraction = (1.0 / maxScaleRatio).clamp(0.35, 0.78);
    final double goalLineFromBottom = barHeight * goalLineFraction;
    final bool isAvgOver = targetValue > 0 && avgValue > targetValue;

    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Верхняя строка: название + среднее / цель
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: macroColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: RichText(
                      maxLines: 1,
                      text: TextSpan(
                        style: TextStyle(fontSize: 12.5, color: textSecondary),
                        children: [
                          const TextSpan(text: 'Ср. '),
                          TextSpan(
                            text: avgValue.toStringAsFixed(0),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: isAvgOver ? AppColors.error : textPrimary,
                            ),
                          ),
                          TextSpan(
                            text: ' / ${targetValue.toStringAsFixed(0)} $unit',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 1. Подписи значений над каждым столбиком
          Row(
            children: days.map((day) {
              final val = getValue(day);
              final isOver = targetValue > 0 && val > targetValue;
              final label = val > 0 ? val.toStringAsFixed(0) : '–';
              return Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight:
                            val > 0 ? FontWeight.w700 : FontWeight.w500,
                        color: isOver
                            ? const Color(0xFFF87171)
                            : (val > 0
                                ? textPrimary
                                : textSecondary.withOpacity(0.5)),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 5),

          // 2. График из 7 широких капсул с пунктирной линией цели 100%
          SizedBox(
            height: barHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 7 столбиков
                Row(
                  children: days.map((day) {
                    final val = getValue(day);
                    final valRatio = targetValue > 0 ? (val / targetValue) : 0.0;
                    final totalFraction =
                        (valRatio / maxScaleRatio).clamp(0.0, 1.0);
                    final double totalHeight = totalFraction > 0
                        ? (barHeight * totalFraction).clamp(5.0, barHeight)
                        : 0.0;
                    final bool isOver = targetValue > 0 && val > targetValue;
                    final double normalHeight = isOver
                        ? math.min(totalHeight, goalLineFromBottom)
                        : totalHeight;
                    final double overflowHeight = isOver
                        ? math
                            .max(3.0, totalHeight - goalLineFromBottom)
                            .clamp(0.0, barHeight - goalLineFromBottom)
                        : 0.0;

                    final isSelectedDay = day.date == _selectedDayDate;

                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() {
                            _selectedDayDate = day.date;
                          });
                        },
                        child: Tooltip(
                          message:
                              '${day.dayName}: ${val.toStringAsFixed(0)} / ${targetValue.toStringAsFixed(0)} $unit',
                          child: Center(
                            child: _CapsuleDayBar(
                              barWidth: barWidth,
                              barHeight: barHeight,
                              normalHeight: normalHeight,
                              overflowHeight: overflowHeight,
                              goalLineFromBottom: goalLineFromBottom,
                              isSelected: isSelectedDay,
                              macroColor: macroColor,
                              macroColorLight: macroColorLight,
                              isDark: isDark,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // Горизонтальная пунктирная линия цели 100% поверх треков
                Positioned(
                  left: 4,
                  right: 4,
                  bottom: goalLineFromBottom - 0.75,
                  height: 1.5,
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _DashedGoalLinePainter(
                        color: isDark
                            ? Colors.white.withOpacity(0.45)
                            : const Color(0xFF475569).withOpacity(0.45),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // 3. Буквы дней недели под столбиками
          Row(
            children: days.map((day) {
              final isSelectedDay = day.date == _selectedDayDate;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      _selectedDayDate = day.date;
                    });
                  },
                  child: Center(
                    child: Text(
                      day.dayLetter,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: (day.isToday || isSelectedDay)
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: day.isToday
                            ? AppColors.primary
                            : (isSelectedDay ? textPrimary : textSecondary),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _CapsuleDayBar extends StatelessWidget {
  final double barWidth;
  final double barHeight;
  final double normalHeight;
  final double overflowHeight;
  final double goalLineFromBottom;
  final bool isSelected;
  final Color macroColor;
  final Color macroColorLight;
  final bool isDark;

  const _CapsuleDayBar({
    required this.barWidth,
    required this.barHeight,
    required this.normalHeight,
    required this.overflowHeight,
    required this.goalLineFromBottom,
    required this.isSelected,
    required this.macroColor,
    required this.macroColorLight,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final Color trackColor =
        isDark ? const Color(0xFF131A29) : const Color(0xFFE2E8F0);
    final double radius = barWidth / 2;

    return Container(
      width: barWidth,
      height: barHeight,
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(radius),
        border: isSelected
            ? Border.all(color: AppColors.primary.withOpacity(0.85), width: 1.5)
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isSelected ? radius - 1 : radius),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Основная заливка до 100% нормы
            if (normalHeight > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: normalHeight,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [macroColor, macroColorLight],
                    ),
                    borderRadius: overflowHeight > 0
                        ? BorderRadius.zero
                        : BorderRadius.vertical(top: Radius.circular(radius)),
                  ),
                ),
              ),

            // Красная зона перелива выше линии цели (100%+)
            if (overflowHeight > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: goalLineFromBottom,
                height: overflowHeight,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xFFEF4444), Color(0xFFF87171)],
                    ),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(radius)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DashedGoalLinePainter extends CustomPainter {
  final Color color;

  const _DashedGoalLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const double dashWidth = 4.0;
    const double dashSpace = 3.5;
    double startX = 0;
    final y = size.height / 2;

    while (startX < size.width) {
      final endX = math.min(startX + dashWidth, size.width);
      canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedGoalLinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
