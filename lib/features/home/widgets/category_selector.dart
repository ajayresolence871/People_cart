import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/category.dart';

class CategorySelector extends StatelessWidget {
  final List<Category> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelectCategory;

  const CategorySelector({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelectCategory,
  });

  // Helper for friendly icons/emojis when image is absent
  String _getCategoryEmoji(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('veg')) return '🥬';
    if (lower.contains('fruit')) return '🍎';
    if (lower.contains('dairy') ||
        lower.contains('milk') ||
        lower.contains('breakfast')) {
      return '🥛';
    }
    if (lower.contains('snack') || lower.contains('munch')) return '🍟';
    if (lower.contains('bever') ||
        lower.contains('drink') ||
        lower.contains('juice')) {
      return '🧃';
    }
    if (lower.contains('meat') || lower.contains('egg')) return '🥚';
    return '🛒';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fresh produce category selector.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'FRESH',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.badgeGreen,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD7F484), // Lime yellow badge
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'TOP OFFERS',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E3A1A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Fruits & vegetables, best offers first',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Horizontal Scrollable Category Circles
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: categories.length + 1, // +1 for "All" / "₹5 Zone"
            itemBuilder: (context, index) {
              final isAll = index == 0;
              final isSelected = isAll
                  ? selectedCategoryId == null
                  : selectedCategoryId == categories[index - 1].id;

              final category = isAll ? null : categories[index - 1];
              final title = isAll ? 'All Produce' : category!.name;
              final emoji = isAll ? '🏷️' : _getCategoryEmoji(title);

              return GestureDetector(
                onTap: () {
                  if (isAll) {
                    onSelectCategory(null);
                  } else {
                    onSelectCategory(categories[index - 1].id);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Circular Icon / Container
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isAll
                              ? (isSelected
                                    ? const Color(0xFFFFE8EE)
                                    : const Color(0xFFFFF0F5))
                              : (isSelected
                                    ? Colors.green.shade50
                                    : Colors.grey.shade100),
                          border: Border.all(
                            color: isSelected
                                ? (isAll
                                      ? AppColors.accentPink
                                      : AppColors.badgeGreen)
                                : Colors.transparent,
                            width: 2.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color:
                                        (isAll
                                                ? AppColors.accentPink
                                                : AppColors.badgeGreen)
                                            .withValues(alpha: 0.2),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: isAll
                              ? Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.accentPink,
                                  ),
                                  child: const Icon(
                                    Icons.local_offer_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                )
                              : category!.imageUrl != null &&
                                    category.imageUrl!.trim().isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    category.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) => Text(
                                          emoji,
                                          style: const TextStyle(fontSize: 28),
                                        ),
                                  ),
                                )
                              : Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 28),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Label
                      SizedBox(
                        width: 68,
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
