import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/catalog_image.dart';
import '../../../models/category.dart';

class _CategorySpec {
  final String key;
  final String name;
  final String illustration;
  final List<String> matchKeywords;

  const _CategorySpec({
    required this.key,
    required this.name,
    required this.illustration,
    required this.matchKeywords,
  });
}

const List<_CategorySpec> _defaultCategories = [
  _CategorySpec(
    key: 'fruits_vegetables',
    name: 'Fruits &\nVegetables',
    illustration: 'assets/images/home/cat_fruits_vegetables.png',
    matchKeywords: ['fruit', 'veg', 'produce', 'apple', 'banana', 'fresh'],
  ),
  _CategorySpec(
    key: 'dairy_breakfast',
    name: 'Dairy &\nBreakfast',
    illustration: 'assets/images/home/cat_dairy_breakfast.png',
    matchKeywords: [
      'dairy',
      'milk',
      'breakfast',
      'butter',
      'paneer',
      'cheese',
      'egg',
    ],
  ),
  _CategorySpec(
    key: 'snacks_munchies',
    name: 'Snacks &\nMunchies',
    illustration: 'assets/images/home/cat_snacks_munchies.png',
    matchKeywords: ['snack', 'munch', 'chip', 'biscuit', 'cookie', 'namkeen'],
  ),
  _CategorySpec(
    key: 'staples',
    name: 'Staples',
    illustration: 'assets/images/home/cat_staples.png',
    matchKeywords: ['staple', 'grain', 'dal', 'atta', 'rice', 'flour', 'pulse'],
  ),
  _CategorySpec(
    key: 'cooking_essentials',
    name: 'Cooking\nEssentials',
    illustration: 'assets/images/home/cat_cooking_essentials.png',
    matchKeywords: ['cook', 'oil', 'masala', 'spice', 'ghee', 'salt', 'sugar'],
  ),
  _CategorySpec(
    key: 'personal_care',
    name: 'Personal\nCare',
    illustration: 'assets/images/home/cat_personal_care.png',
    matchKeywords: [
      'personal',
      'care',
      'skin',
      'bath',
      'beauty',
      'hair',
      'soap',
      'shampoo',
    ],
  ),
  _CategorySpec(
    key: 'home_cleaning',
    name: 'Home\nCleaning',
    illustration: 'assets/images/home/cat_home_cleaning.png',
    matchKeywords: [
      'clean',
      'home',
      'wash',
      'detergent',
      'spray',
      'floor',
      'dish',
    ],
  ),
  _CategorySpec(
    key: 'baby_care',
    name: 'Baby Care',
    illustration: 'assets/images/home/cat_baby_care.png',
    matchKeywords: ['baby', 'diaper', 'infant', 'toddler', 'wipes'],
  ),
  _CategorySpec(
    key: 'bakery',
    name: 'Bakery',
    illustration: 'assets/images/home/cat_bakery.png',
    matchKeywords: ['bakery', 'bread', 'cake', 'bun', 'toast', 'croissant'],
  ),
  _CategorySpec(
    key: 'more',
    name: 'More',
    illustration: 'assets/images/home/cat_more.png',
    matchKeywords: [],
  ),
];

class ShopByCategorySection extends StatelessWidget {
  final List<Category> categories;
  final ValueChanged<Category> onCategoryTap;
  final VoidCallback? onSeeAllTap;

  const ShopByCategorySection({
    super.key,
    required this.categories,
    required this.onCategoryTap,
    this.onSeeAllTap,
  });

  Category? _findMatchingLiveCategory(_CategorySpec spec) {
    if (categories.isEmpty) return null;
    for (final cat in categories) {
      final lower = cat.name.toLowerCase();
      for (final kw in spec.matchKeywords) {
        if (lower.contains(kw)) {
          return cat;
        }
      }
    }
    return null;
  }

  void _handleTap(BuildContext context, _CategorySpec spec) {
    if (spec.key == 'more') {
      onSeeAllTap?.call();
      return;
    }

    final matched = _findMatchingLiveCategory(spec);
    if (matched != null) {
      onCategoryTap(matched);
    } else {
      // Fallback synthetic category so browsing always functions cleanly
      final fallback = Category(
        id: spec.key,
        name: spec.name.replaceAll('\n', ' '),
      );
      onCategoryTap(fallback);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header: 4-square grid icon + "Shop by Category" + "See All ->"
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.grid_view_rounded,
                          size: 22,
                          color: AppColors.accentPink,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Shop by Category',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 16 : 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: onSeeAllTap,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'See All',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accentPink,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: AppColors.accentPink,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        // 5-Column Responsive Category Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final int columns = constraints.maxWidth >= 900
                ? 6
                : constraints.maxWidth >= 600
                ? 5
                : constraints.maxWidth >= 360
                ? 4
                : 3;
            const double crossSpacing = 8.0;
            const double mainSpacing = 12.0;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _defaultCategories.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: crossSpacing,
                  mainAxisSpacing: mainSpacing,
                  mainAxisExtent: 112,
                ),
                itemBuilder: (context, index) {
                  final spec = _defaultCategories[index];
                  return _buildCategoryTile(
                    context,
                    spec,
                    _findMatchingLiveCategory(spec),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategoryTile(
    BuildContext context,
    _CategorySpec spec,
    Category? liveCategory,
  ) {
    return InkWell(
      onTap: () => _handleTap(context, spec),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Rounded rectangular image container
          Container(
            height: 58,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFFBF4FC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF3E5F5), width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2B0938).withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: CatalogImage(
                  imageUrl: liveCategory?.imageUrl,
                  fit: BoxFit.contain,
                  placeholder: Image.asset(
                    spec.illustration,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.shopping_bag_outlined,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Category Name Below
          Text(
            spec.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}
