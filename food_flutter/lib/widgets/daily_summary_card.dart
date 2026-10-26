import 'package:flutter/material.dart';
import '../models/meal_models.dart';

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

  Widget _buildProgressBar({
    required BuildContext context,
    required String label,
    required double current,
    required double target,
    required Color color,
    required String unit,
  }) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final percent = (progress * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
            Text(
              '${current.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} $unit ($percent%)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final calProgress = targetCalories > 0 ? (summary.totalCalories / targetCalories).clamp(0.0, 1.0) : 0.0;
    final calRemaining = (targetCalories - summary.totalCalories).clamp(0.0, double.infinity);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                // Big Circular Progress for Calories
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 86,
                      height: 86,
                      child: CircularProgressIndicator(
                        value: calProgress,
                        strokeWidth: 9,
                        backgroundColor: const Color(0xFF10B981).withOpacity(0.15),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          summary.totalCalories.toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const Text(
                          'ккал',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                // Daily calorie stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Калории за день',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Осталось: ${calRemaining.toStringAsFixed(0)} из ${targetCalories.toStringAsFixed(0)} ккал',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Блюд: ${summary.mealsCount}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Вес: ${summary.totalWeightG.toStringAsFixed(0)} г',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 16),
            // Macro Bars (P / F / C)
            _buildProgressBar(
              context: context,
              label: 'Белки',
              current: summary.totalProtein,
              target: targetProtein,
              color: const Color(0xFF3B82F6),
              unit: 'г',
            ),
            const SizedBox(height: 10),
            _buildProgressBar(
              context: context,
              label: 'Жиры',
              current: summary.totalFat,
              target: targetFat,
              color: const Color(0xFFF59E0B),
              unit: 'г',
            ),
            const SizedBox(height: 10),
            _buildProgressBar(
              context: context,
              label: 'Углеводы',
              current: summary.totalCarbs,
              target: targetCarbs,
              color: const Color(0xFF8B5CF6),
              unit: 'г',
            ),
          ],
        ),
      ),
    );
  }
}
