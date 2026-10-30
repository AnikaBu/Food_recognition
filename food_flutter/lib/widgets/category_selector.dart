import 'package:flutter/material.dart';
import '../models/meal_models.dart';
import '../theme/app_colors.dart';

class CategorySelector extends StatelessWidget {
  final MealType selected;
  final ValueChanged<MealType> onSelected;

  const CategorySelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedBg = isDark ? AppColors.darkInput : AppColors.lightInput;
    final unselectedBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final unselectedTextColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF334155);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: MealType.values.map((type) {
          final isChosen = type == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                type.labelRu,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isChosen ? FontWeight.bold : FontWeight.w500,
                  color: isChosen ? Colors.white : unselectedTextColor,
                ),
              ),
              selected: isChosen,
              selectedColor: AppColors.primary,
              backgroundColor: unselectedBg,
              side: BorderSide(
                color: isChosen ? AppColors.primary : unselectedBorder,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (_) => onSelected(type),
            ),
          );
        }).toList(),
      ),
    );
  }
}
