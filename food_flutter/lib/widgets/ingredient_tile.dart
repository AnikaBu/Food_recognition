import 'package:flutter/material.dart';
import '../models/meal_models.dart';
import 'macro_pill.dart';

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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Вес: ${item.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Вес в граммах',
            suffixText: 'г',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onDelete,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Gram adjustment controls
            Row(
              children: [
                // Decrement button
                _buildWeightButton(
                  icon: Icons.remove,
                  onTap: () {
                    final next = (item.weightG - 10).clamp(5.0, 5000.0);
                    onWeightChanged(next);
                  },
                ),
                const SizedBox(width: 8),
                // Weight badge - tap to edit
                InkWell(
                  onTap: () => _showEditWeightDialog(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${item.weightG.toStringAsFixed(0)} г',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, size: 13, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Increment button
                _buildWeightButton(
                  icon: Icons.add,
                  onTap: () {
                    final next = (item.weightG + 10).clamp(5.0, 5000.0);
                    onWeightChanged(next);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Mini macros
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                MacroPill(
                  label: 'ккал',
                  value: item.calories.toStringAsFixed(0),
                  type: MacroType.calories,
                  isSmall: true,
                ),
                MacroPill(
                  label: 'Б',
                  value: '${item.protein.toStringAsFixed(1)}г',
                  type: MacroType.protein,
                  isSmall: true,
                ),
                MacroPill(
                  label: 'Ж',
                  value: '${item.fat.toStringAsFixed(1)}г',
                  type: MacroType.fat,
                  isSmall: true,
                ),
                MacroPill(
                  label: 'У',
                  value: '${item.carbs.toStringAsFixed(1)}г',
                  type: MacroType.carbs,
                  isSmall: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF334155)),
      ),
    );
  }
}
