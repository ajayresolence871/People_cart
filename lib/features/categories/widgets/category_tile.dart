import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/category.dart';

class CategoryTile extends StatelessWidget {
  final Category item;
  final VoidCallback onTap;

  const CategoryTile({super.key, required this.item, required this.onTap});

  String get _emoji {
    final name = item.name.toLowerCase();
    if (name.contains('fruit')) return '🍎';
    if (name.contains('vegetable') || name.contains('produce')) return '🥦';
    if (name.contains('dairy') || name.contains('milk')) return '🥛';
    if (name.contains('drink') || name.contains('beverage')) return '🧃';
    if (name.contains('snack')) return '🍟';
    if (name.contains('meat') || name.contains('egg')) return '🥚';
    return '🛒';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Rounded container holding category visual
          Container(
            height: 72,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF6F6F8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200, width: 0.8),
            ),
            child: Center(
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        item.imageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            Text(_emoji, style: const TextStyle(fontSize: 34)),
                      ),
                    )
                  : Text(_emoji, style: const TextStyle(fontSize: 34)),
            ),
          ),
          const SizedBox(height: 6),
          // Category Title Text (Centered, 2 lines max)
          Text(
            item.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}
