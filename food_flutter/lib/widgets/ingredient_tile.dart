import 'package:flutter/material.dart';
import '../models/meal_models.dart';
import '../theme/app_colors.dart';

class IngredientTile extends StatelessWidget {
  final IngredientItem item;
  final ValueChanged<double> onWeightChanged;
  final VoidCallback? onDelete;

  const IngredientTile({
    super.key,
    required this.item,
    required this.onWeightChanged,
    this.onDelete,
  });

  void _showEditWeightDialog(BuildContext context) {
    final controller = TextEditingController(text: item.weightG.toStringAsFixed(0));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Вес: ${item.name}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: TextStyle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            labelText: 'Вес в граммах',
            suffixText: 'г',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Отмена', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final parsed = double.tryParse(controller.text.replaceAll(',', '.'));
              if (parsed != null && parsed > 0) {
                onWeightChanged(parsed);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Применить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final cardBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final stepperBg = isDark ? AppColors.darkSurface : AppColors.lightInput;
    final titleColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final calsPer100 = item.weightG > 0 ? (item.calories * 100.0 / item.weightG) : item.calories;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: Row(
        children: [
          // Ingredient info (name + per 100g calories & macros)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${calsPer100.toStringAsFixed(0)} ккал/100г • ${item.calories.toStringAsFixed(0)} ккал (${item.protein.toStringAsFixed(0)}Б / ${item.fat.toStringAsFixed(0)}Ж / ${item.carbs.toStringAsFixed(0)}У)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: subColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Stepper: [-] 120г [+]
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            decoration: BoxDecoration(
              color: stepperBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    final next = (item.weightG - 10).clamp(5.0, 5000.0);
                    onWeightChanged(next);
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      '-',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: subColor,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _showEditWeightDialog(context),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 42),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '${item.weightG.toStringAsFixed(0)}г',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    final next = (item.weightG + 10).clamp(5.0, 5000.0);
                    onWeightChanged(next);
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      '+',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: subColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (onDelete != null) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
