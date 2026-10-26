import 'package:flutter/material.dart';

enum MacroType { calories, protein, fat, carbs, weight }

class MacroPill extends StatelessWidget {
  final String label;
  final String value;
  final MacroType type;
  final bool isSmall;

  const MacroPill({
    super.key,
    required this.label,
    required this.value,
    required this.type,
    this.isSmall = false,
  });

  Color _getPrimaryColor() {
    switch (type) {
      case MacroType.calories:
        return const Color(0xFF10B981); // Emerald
      case MacroType.protein:
        return const Color(0xFF3B82F6); // Blue
      case MacroType.fat:
        return const Color(0xFFF59E0B); // Amber
      case MacroType.carbs:
        return const Color(0xFF8B5CF6); // Purple
      case MacroType.weight:
        return const Color(0xFF64748B); // Slate
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getPrimaryColor();
    final bg = color.withOpacity(0.12);

    if (isSmall) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: color.withOpacity(0.85),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
