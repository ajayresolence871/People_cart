import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/category.dart';
import 'category_tile.dart';

class CategoryGroupsWidget extends StatelessWidget {
  final List<Category> categories;
  final ValueChanged<Category> onCategoryTap;

  const CategoryGroupsWidget({
    super.key,
    required this.categories,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No active categories are available right now.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 6
            : constraints.maxWidth >= 600
            ? 5
            : constraints.maxWidth >= 400
            ? 4
            : 3;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: categories.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 14,
              crossAxisSpacing: 10,
              childAspectRatio: 0.72,
            ),
            itemBuilder: (context, index) {
              final item = categories[index];
              return CategoryTile(item: item, onTap: () => onCategoryTap(item));
            },
          ),
        );
      },
    );
  }
}
