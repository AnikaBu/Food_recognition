import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';

class MacroCalculatorResult {
  final double calories;
  final double protein;
  final double fat;
  final double carbs;
  final String gender;
  final int age;
  final double heightCm;
  final double weightKg;
  final String activityLevel;
  final String goal;

  const MacroCalculatorResult({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.gender,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.activityLevel,
    required this.goal,
  });
}

class MacroCalculatorSheet extends StatefulWidget {
  final SettingsService settingsService;

  const MacroCalculatorSheet({
    super.key,
    required this.settingsService,
  });

  static Future<MacroCalculatorResult?> show(
    BuildContext context, {
    required SettingsService settingsService,
  }) {
    return showModalBottomSheet<MacroCalculatorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MacroCalculatorSheet(settingsService: settingsService),
    );
  }

  @override
  State<MacroCalculatorSheet> createState() => _MacroCalculatorSheetState();
}

class _MacroCalculatorSheetState extends State<MacroCalculatorSheet> {
  late String _gender;
  late final TextEditingController _ageController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late String _activity;
  late String _goal;

  double _calculatedCalories = 2000;
  double _calculatedProtein = 90;
  double _calculatedFat = 65;
  double _calculatedCarbs = 250;

  @override
  void initState() {
    super.initState();
    _gender = widget.settingsService.calcGender;
    _ageController = TextEditingController(text: widget.settingsService.calcAge.toString());
    _heightController = TextEditingController(text: widget.settingsService.calcHeight.toStringAsFixed(0));
    _weightController = TextEditingController(text: widget.settingsService.calcWeight.toStringAsFixed(1));
    _activity = widget.settingsService.calcActivity;
    _goal = widget.settingsService.calcGoal;

    _ageController.addListener(_onInputChanged);
    _heightController.addListener(_onInputChanged);
    _weightController.addListener(_onInputChanged);

    _recalculate();
  }

  @override
  void dispose() {
    _ageController.removeListener(_onInputChanged);
    _heightController.removeListener(_onInputChanged);
    _weightController.removeListener(_onInputChanged);
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    setState(() {
      _recalculate();
    });
  }

  void _recalculate() {
    final age = int.tryParse(_ageController.text.trim()) ?? 28;
    final height = double.tryParse(_heightController.text.replaceAll(',', '.').trim()) ?? 168.0;
    final weight = double.tryParse(_weightController.text.replaceAll(',', '.').trim()) ?? 62.0;

    if (age <= 0 || height <= 0 || weight <= 0) return;

    // 1. Формула Миффлина — Сан Жеора (BMR)
    double bmr;
    if (_gender == 'male') {
      bmr = 10.0 * weight + 6.25 * height - 5.0 * age + 5.0;
    } else {
      bmr = 10.0 * weight + 6.25 * height - 5.0 * age - 161.0;
    }

    // 2. Коэффициент физической активности
    double activityMult;
    switch (_activity) {
      case 'sedentary':
        activityMult = 1.2;
        break;
      case 'light':
        activityMult = 1.375;
        break;
      case 'high':
        activityMult = 1.725;
        break;
      case 'extreme':
        activityMult = 1.9;
        break;
      case 'moderate':
      default:
        activityMult = 1.55;
        break;
    }

    final tdee = bmr * activityMult;

    // 3. Коэффициент цели и распределение БЖУ
    double goalMult;
    double proteinPerKg;
    double fatPerKg;

    switch (_goal) {
      case 'lose_weight':
        goalMult = 0.85; // Дефицит 15%
        proteinPerKg = 1.8; // Защита мышц в дефиците
        fatPerKg = 0.9;
        break;
      case 'gain_weight':
        goalMult = 1.10; // Профицит 10%
        proteinPerKg = 2.0;
        fatPerKg = 1.1;
        break;
      case 'maintain':
      default:
        goalMult = 1.0; // Баланс
        proteinPerKg = 1.6;
        fatPerKg = 1.0;
        break;
    }

    final targetCal = (tdee * goalMult).roundToDouble();
    final targetProt = (weight * proteinPerKg).roundToDouble();
    final targetFat = (weight * fatPerKg).roundToDouble();

    // Калории от белков (4 ккал/г) и жиров (9 ккал/г)
    final calFromProtAndFat = (targetProt * 4.0) + (targetFat * 9.0);
    double remainingCal = targetCal - calFromProtAndFat;
    if (remainingCal < 200.0) {
      remainingCal = 200.0; // Минимальная граница углеводов ~50г
    }
    final targetCarbs = (remainingCal / 4.0).roundToDouble();

    _calculatedCalories = targetCal;
    _calculatedProtein = targetProt;
    _calculatedFat = targetFat;
    _calculatedCarbs = targetCarbs;
  }

  void _applyResult() {
    final age = int.tryParse(_ageController.text.trim()) ?? 28;
    final height = double.tryParse(_heightController.text.replaceAll(',', '.').trim()) ?? 168.0;
    final weight = double.tryParse(_weightController.text.replaceAll(',', '.').trim()) ?? 62.0;

    // Сохраняем введенный профиль в SharedPreferences
    widget.settingsService.saveCalculatorProfile(
      gender: _gender,
      age: age,
      height: height,
      weight: weight,
      activity: _activity,
      goal: _goal,
    );

    Navigator.of(context).pop(MacroCalculatorResult(
      calories: _calculatedCalories,
      protein: _calculatedProtein,
      fat: _calculatedFat,
      carbs: _calculatedCarbs,
      gender: _gender,
      age: age,
      heightCm: height,
      weightKg: weight,
      activityLevel: _activity,
      goal: _goal,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppColors.darkCard : Colors.white;
    final cardInnerBg = isDark ? AppColors.darkInput : const Color(0xFFF1F5F9);
    final cardBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.6 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Верхняя полоска-индикатор
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Заголовок
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.auto_awesome,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Калькулятор КБЖУ',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            'Формула Миффлина — Сан Жеора',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Прокручиваемое содержимое
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                children: [
                  // 1. Живой блок предпросмотра результата
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                AppColors.darkBgMiddle,
                                AppColors.darkInput,
                              ]
                            : [
                                const Color(0xFFF8FAFC),
                                const Color(0xFFF1F5F9),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(isDark ? 0.35 : 0.4),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'РАССЧИТАННАЯ СУТОЧНАЯ НОРМА',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              _calculatedCalories.toStringAsFixed(0),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: AppColors.macroCalorie,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'ккал/день',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMacroMiniCard(
                                title: 'Белки',
                                value: '${_calculatedProtein.toStringAsFixed(0)} г',
                                color: AppColors.macroProtein,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMacroMiniCard(
                                title: 'Жиры',
                                value: '${_calculatedFat.toStringAsFixed(0)} г',
                                color: AppColors.macroFat,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMacroMiniCard(
                                title: 'Углеводы',
                                value: '${_calculatedCarbs.toStringAsFixed(0)} г',
                                color: AppColors.macroCarb,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 2. Выбор пола
                  _buildSectionHeader('ПОЛ', textSecondary),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildChoiceChip(
                          label: '👨 Мужской',
                          isSelected: _gender == 'male',
                          onTap: () {
                            setState(() {
                              _gender = 'male';
                              _recalculate();
                            });
                          },
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildChoiceChip(
                          label: '👩 Женский',
                          isSelected: _gender == 'female',
                          onTap: () {
                            setState(() {
                              _gender = 'female';
                              _recalculate();
                            });
                          },
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 3. Параметры тела: Возраст, Рост, Вес
                  _buildSectionHeader('ПАРАМЕТРЫ ТЕЛА', textSecondary),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildParamInput(
                          label: 'Возраст (лет)',
                          controller: _ageController,
                          hint: '28',
                          isDark: isDark,
                          textPrimary: textPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildParamInput(
                          label: 'Рост (см)',
                          controller: _heightController,
                          hint: '168',
                          isDark: isDark,
                          textPrimary: textPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildParamInput(
                          label: 'Вес (кг)',
                          controller: _weightController,
                          hint: '62.0',
                          isDark: isDark,
                          textPrimary: textPrimary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 4. Физическая активность и спорт
                  _buildSectionHeader('ФИЗИЧЕСКАЯ АКТИВНОСТЬ И СПОРТ', textSecondary),
                  const SizedBox(height: 8),
                  _buildActivityTile(
                    id: 'sedentary',
                    title: 'Минимальная (1.2)',
                    subtitle: 'Сидячая работа, редкие прогулки, без спорта',
                    isSelected: _activity == 'sedentary',
                    isDark: isDark,
                    cardInnerBg: cardInnerBg,
                    cardBorder: cardBorder,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(height: 6),
                  _buildActivityTile(
                    id: 'light',
                    title: 'Легкая (1.375)',
                    subtitle: 'Прогулки, легкие тренировки 1–3 раза в неделю',
                    isSelected: _activity == 'light',
                    isDark: isDark,
                    cardInnerBg: cardInnerBg,
                    cardBorder: cardBorder,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(height: 6),
                  _buildActivityTile(
                    id: 'moderate',
                    title: 'Умеренная (1.55)',
                    subtitle: 'Спорт 3–5 раз в неделю, активный темп дня',
                    isSelected: _activity == 'moderate',
                    isDark: isDark,
                    cardInnerBg: cardInnerBg,
                    cardBorder: cardBorder,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(height: 6),
                  _buildActivityTile(
                    id: 'high',
                    title: 'Высокая (1.725)',
                    subtitle: 'Интенсивные тренировки 6–7 раз в неделю или физ. труд',
                    isSelected: _activity == 'high',
                    isDark: isDark,
                    cardInnerBg: cardInnerBg,
                    cardBorder: cardBorder,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(height: 6),
                  _buildActivityTile(
                    id: 'extreme',
                    title: 'Очень высокая (1.9)',
                    subtitle: 'Профессиональный спорт / тяжелый физический труд',
                    isSelected: _activity == 'extreme',
                    isDark: isDark,
                    cardInnerBg: cardInnerBg,
                    cardBorder: cardBorder,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),

                  const SizedBox(height: 18),

                  // 5. Цель
                  _buildSectionHeader('ВАША ЦЕЛЬ', textSecondary),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGoalCard(
                          id: 'lose_weight',
                          title: 'Похудение',
                          badge: '-15%',
                          color: const Color(0xFFEF4444),
                          isSelected: _goal == 'lose_weight',
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildGoalCard(
                          id: 'maintain',
                          title: 'Баланс',
                          badge: '0%',
                          color: AppColors.primary,
                          isSelected: _goal == 'maintain',
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildGoalCard(
                          id: 'gain_weight',
                          title: 'Набор',
                          badge: '+10%',
                          color: const Color(0xFF3B82F6),
                          isSelected: _goal == 'gain_weight',
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Нижняя фиксированная кнопка применения
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: _applyResult,
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text(
                    'Применить к суточным целям',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: color,
      ),
    );
  }

  Widget _buildMacroMiniCard({
    required String title,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final activeBg = AppColors.primary.withOpacity(0.18);
    final inactiveBg = isDark ? AppColors.darkInput : const Color(0xFFF1F5F9);
    final activeBorder = AppColors.primary;
    final inactiveBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeBorder : inactiveBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildParamInput({
    required String label,
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    required Color textPrimary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityTile({
    required String id,
    required String title,
    required String subtitle,
    required bool isSelected,
    required bool isDark,
    required Color cardInnerBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _activity = id;
          _recalculate();
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.12) : cardInnerBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: isSelected ? AppColors.primary : textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.primary : textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard({
    required String id,
    required String title,
    required String badge,
    required Color color,
    required bool isSelected,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _goal = id;
          _recalculate();
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : (isDark ? AppColors.darkInput : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? color : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
