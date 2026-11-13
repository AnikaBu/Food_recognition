import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/meal_models.dart';
import '../theme/app_colors.dart';
import '../theme/theme_palette.dart';

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

  Widget _buildMacroCard({
    required String label,
    required double current,
    required double target,
    required Color accentColor,
    required Color bgColor,
    required Color borderColor,
    required bool isDark,
  }) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${current.toStringAsFixed(0)}г',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Container(
              height: 3,
              width: double.infinity,
              color: accentColor.withOpacity(0.2),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final calProgress = targetCalories > 0
        ? (summary.totalCalories / targetCalories).clamp(0.0, 1.0)
        : 0.0;
    final remaining = targetCalories - summary.totalCalories;
    final isOver = remaining < 0;

    final cardBg = isDark ? tokens.cardBg : AppColors.lightCard;
    final cardBorder = isDark ? tokens.cardBorder : AppColors.lightBorder;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.35) : Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          // Left: Calorie Ring with Remaining kcal
          SizedBox(
            width: 86,
            height: 86,
            child: CustomPaint(
              painter: _CalorieRingPainter(
                progress: calProgress,
                isDark: isDark,
                calorieLight: tokens.macroCalorieLight,
                calorieDark: tokens.macroCalorieDark,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isOver ? 'Перебор' : 'Осталось',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: isOver
                            ? tokens.macroCalorie
                            : (isDark ? tokens.textSecondary : AppColors.lightTextSecondary),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      remaining.abs().toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        color: isDark ? tokens.textPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      'ккал',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: isDark ? tokens.textSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Right: 3 Macro Cards in a horizontal row
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildMacroCard(
                    label: 'Белки',
                    current: summary.totalProtein,
                    target: targetProtein,
                    accentColor: tokens.macroProtein,
                    bgColor: isDark ? tokens.macroProtein.withOpacity(0.16) : const Color(0xFFEEF2FF),
                    borderColor: tokens.macroProtein.withOpacity(isDark ? 0.35 : 0.25),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMacroCard(
                    label: 'Углеводы',
                    current: summary.totalCarbs,
                    target: targetCarbs,
                    accentColor: tokens.macroCarb,
                    bgColor: isDark ? tokens.macroCarb.withOpacity(0.16) : const Color(0xFFECFDF5),
                    borderColor: tokens.macroCarb.withOpacity(isDark ? 0.35 : 0.25),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMacroCard(
                    label: 'Жиры',
                    current: summary.totalFat,
                    target: targetFat,
                    accentColor: tokens.macroFat,
                    bgColor: isDark ? tokens.macroFat.withOpacity(0.16) : const Color(0xFFFEF3C7),
                    borderColor: tokens.macroFat.withOpacity(isDark ? 0.35 : 0.25),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalorieRingPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final Color calorieLight;
  final Color calorieDark;

  _CalorieRingPainter({
    required this.progress,
    required this.isDark,
    required this.calorieLight,
    required this.calorieDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 10) / 2;

    // Background track
    final trackPaint = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.5;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    // Progress arc with gradient
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      colors: [
        calorieLight,
        calorieDark,
      ],
    );

    final progressPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7.5;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _CalorieRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.calorieLight != calorieLight ||
        oldDelegate.calorieDark != calorieDark;
  }
}
