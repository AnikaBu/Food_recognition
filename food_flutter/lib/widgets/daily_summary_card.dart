import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/meal_models.dart';
import '../theme/app_colors.dart';

class DailySummaryCard extends StatelessWidget {
  final DailySummary summary;
  final double targetCalories;
  final double targetProtein;
  final double targetFat;
  final double targetCarbs;

  const DailySummaryCard({
    super.key,
    required this.summary,
    required this.targetCalories,
    required this.targetProtein,
    required this.targetFat,
    required this.targetCarbs,
  });

  Widget _buildMacroBar({
    required BuildContext context,
    required String label,
    required double current,
    required double target,
    required Color color,
    required bool isDark,
  }) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final trackColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: isDark
                        ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 6)]
                        : null,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
            Text(
              '${current.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} г',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: subColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 7,
            color: trackColor,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: isDark
                      ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)]
                      : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final calProgress = targetCalories > 0
        ? (summary.totalCalories / targetCalories).clamp(0.0, 1.0)
        : 0.0;
    final remaining = targetCalories - summary.totalCalories;
    final isOver = remaining < 0;

    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final cardBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final headerTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.4) : Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          // Header with pinging dot and status pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: AppColors.macroCalorie,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'СВОДКА БАЛАНСА ДНЯ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: headerTextColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isOver
                      ? (isDark ? AppColors.macroCalorie.withOpacity(0.18) : const Color(0xFFFFF1F2))
                      : (isDark ? AppColors.primary.withOpacity(0.15) : AppColors.primaryLight),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isOver
                        ? AppColors.macroCalorie.withOpacity(0.4)
                        : AppColors.primary.withOpacity(0.35),
                  ),
                ),
                child: Text(
                  isOver
                      ? 'Перебор +${(-remaining).toStringAsFixed(0)} ккал'
                      : 'Осталось ${remaining.toStringAsFixed(0)} ккал',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isOver ? AppColors.macroCalorie : AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Calorie Ring + Macros Bars
          Row(
            children: [
              // Custom Gradient Calorie Ring
              SizedBox(
                width: 104,
                height: 104,
                child: CustomPaint(
                  painter: _CalorieRingPainter(
                    progress: calProgress,
                    isDark: isDark,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department,
                          color: AppColors.macroCalorie,
                          size: 18,
                        ),
                        Text(
                          summary.totalCalories.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        Text(
                          'из ${targetCalories.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 18),

              // Macro Bars Breakdown
              Expanded(
                child: Column(
                  children: [
                    _buildMacroBar(
                      context: context,
                      label: 'Белки',
                      current: summary.totalProtein,
                      target: targetProtein,
                      color: AppColors.macroProtein,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _buildMacroBar(
                      context: context,
                      label: 'Жиры',
                      current: summary.totalFat,
                      target: targetFat,
                      color: AppColors.macroFat,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _buildMacroBar(
                      context: context,
                      label: 'Углеводы',
                      current: summary.totalCarbs,
                      target: targetCarbs,
                      color: AppColors.macroCarb,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalorieRingPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _CalorieRingPainter({
    required this.progress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;

    // Background track
    final trackPaint = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    // Progress arc with gradient
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      colors: const [
        AppColors.macroCalorieLight,
        AppColors.macroCalorieDark,
      ],
    );

    final progressPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10.0;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _CalorieRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}
