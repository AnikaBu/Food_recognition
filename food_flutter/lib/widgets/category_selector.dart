import 'package:flutter/material.dart';
import '../models/meal_models.dart';

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
                  color: isChosen ? Colors.white : const Color(0xFF334155),
                ),
              ),
              selected: isChosen,
              selectedColor: const Color(0xFF10B981),
              backgroundColor: const Color(0xFFF1F5F9),
              side: BorderSide(
                color: isChosen ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
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
