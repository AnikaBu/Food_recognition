import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/meal_models.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import 'macro_calculator_sheet.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
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

  Future<void> _openGoalsManager() async {
    final result = await MacroCalculatorSheet.show(
      context,
      settingsService: widget.settingsService,
    );
    if (result != null && mounted) {
      widget.onGoalsChanged?.call();
      _loadSummary();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.90),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Динамика',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Макро',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      if (_summary != null)
                        Text(
                          _formatDateRange(_summary!.startDate, _summary!.endDate),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      // Переключатель режима (Неделя / 7 дней)
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.lightBorderSubtle,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            _buildModeTab('ПН–ВС', 'week', isDark),
                            _buildModeTab('7 дней', 'trailing', isDark),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
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
                                Icon(Icons.error_outline_rounded, size: 42, color: Colors.red.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadSummary,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildMacroCards(bool isDark) {
    final s = _summary!;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // 1. Углеводы (мятно-бирюзовый)
        _buildMacroRow(
          title: 'Углев.',
          fullName: 'Углеводы',
          avgGrams: s.avgCarbs,
          targetGrams: s.targetCarbs,
          macroColor: AppColors.macroCarb,
          macroColorLight: AppColors.macroCarbLight,
          days: s.days,
          getValue: (d) => d.carbs,
          isDark: isDark,
        ),
        const SizedBox(height: 12),

        // 2. Жиры (янтарно-золотой)
        _buildMacroRow(
          title: 'Жиры',
          fullName: 'Жиры',
          avgGrams: s.avgFat,
          targetGrams: s.targetFat,
          macroColor: AppColors.macroFat,
          macroColorLight: AppColors.macroFatLight,
          days: s.days,
          getValue: (d) => d.fat,
          isDark: isDark,
        ),
        const SizedBox(height: 12),

        // 3. Белки (индиго-сапфировый)
        _buildMacroRow(
          title: 'Белок',
          fullName: 'Белки',
          avgGrams: s.avgProtein,
          targetGrams: s.targetProtein,
          macroColor: AppColors.macroProtein,
          macroColorLight: AppColors.macroProteinLight,
          days: s.days,
          getValue: (d) => d.protein,
          isDark: isDark,
        ),
        const SizedBox(height: 20),

        // 4. Кнопка "Управлять моими целями"
        InkWell(
          onTap: _openGoalsManager,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightBorderSubtle,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Управлять моими целями',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Калькулятор КБЖУ и суточные нормы',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMacroRow({
    required String title,
    required String fullName,
    required double avgGrams,
    required double targetGrams,
    required Color macroColor,
    required Color macroColorLight,
    required List<WeeklyMacroDay> days,
    required double Function(WeeklyMacroDay) getValue,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Левая колонка: Название, среднее за 7 дней, суточная цель
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
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
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Ср. за 7 дней: ${avgGrams.toStringAsFixed(0)} г',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Цель: ${targetGrams.toStringAsFixed(0)} г / день',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)
                        .withOpacity(0.75),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Правая колонка: 7 вертикальных капсульных столбцов (Capsules)
          Expanded(
            flex: 7,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.map((day) {
                final val = getValue(day);
                final ratio = targetGrams > 0 ? (val / targetGrams).clamp(0.0, 1.0) : 0.0;
                final isSelectedDay = day.date == DateFormat('yyyy-MM-dd').format(widget.selectedDate);

                return _CapsuleDayBar(
                  dayLetter: day.dayLetter,
                  isToday: day.isToday,
                  isSelected: isSelectedDay,
                  fillRatio: ratio,
                  valueGrams: val,
                  macroColor: macroColor,
                  macroColorLight: macroColorLight,
                  isDark: isDark,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CapsuleDayBar extends StatelessWidget {
  final String dayLetter;
  final bool isToday;
  final bool isSelected;
  final double fillRatio;
  final double valueGrams;
  final Color macroColor;
  final Color macroColorLight;
  final bool isDark;

  const _CapsuleDayBar({
    required this.dayLetter,
    required this.isToday,
    required this.isSelected,
    required this.fillRatio,
    required this.valueGrams,
    required this.macroColor,
    required this.macroColorLight,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    const double barWidth = 14.0;
    const double barHeight = 56.0;

    // Высота заполнения: если есть граммы, делаем минимальную высоту 4px для видимости
    final double fillHeight = fillRatio > 0 ? (barHeight * fillRatio).clamp(4.0, barHeight) : 0.0;

    final Color trackColor = isDark
        ? const Color(0xFF131A29)
        : const Color(0xFFE2E8F0);

    return Tooltip(
      message: '${dayLetter}: ${valueGrams.toStringAsFixed(1)} г',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Буква дня недели
          Text(
            dayLetter,
            style: TextStyle(
              fontSize: 11,
              fontWeight: (isToday || isSelected) ? FontWeight.w800 : FontWeight.w600,
              color: isToday
                  ? AppColors.primary
                  : (isSelected
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
            ),
          ),
          const SizedBox(height: 6),

          // Капсула
          Container(
            width: barWidth,
            height: barHeight,
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(barWidth / 2),
              border: isSelected
                  ? Border.all(color: AppColors.primary.withOpacity(0.6), width: 1.5)
                  : null,
            ),
            alignment: Alignment.bottomCenter,
            child: fillHeight > 0
                ? Container(
                    width: barWidth,
                    height: fillHeight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [macroColor, macroColorLight],
                      ),
                      borderRadius: BorderRadius.circular(barWidth / 2),
                      boxShadow: [
                        BoxShadow(
                          color: macroColor.withOpacity(0.35),
                          blurRadius: 4,
                          offset: const Offset(0, -1),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
