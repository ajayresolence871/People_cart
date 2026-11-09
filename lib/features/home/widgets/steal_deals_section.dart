import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/product.dart';
import 'product_card.dart';

class StealDealsSection extends StatefulWidget {
  final List<Product> baseProducts;

  const StealDealsSection({
    super.key,
    required this.baseProducts,
  });

  @override
  State<StealDealsSection> createState() => _StealDealsSectionState();
}

class _StealDealsSectionState extends State<StealDealsSection> {
  int _selectedStoreIndex = 0; // 0: Trending, 1: ₹9, 2: ₹19, 3: ₹29, 4: ₹49
  int _selectedSubcategoryIndex = 0; // 0: ALL, 1: Munchies, 2: Frozen Food, 3: Skincare, etc.

  final List<Map<String, dynamic>> _stores = [
    {'title': 'Trending', 'icon': '🔥', 'isFlame': true},
    {'price': '₹9', 'subtitle': 'Store'},
    {'price': '₹19', 'subtitle': 'Store'},
    {'price': '₹29', 'subtitle': 'Store'},
    {'price': '₹49', 'subtitle': 'Store'},
  ];

  final List<Map<String, String>> _subcategories = [
    {'name': 'ALL', 'emoji': '🔲'},
    {'name': 'Munchies', 'emoji': '🍟'},
    {'name': 'Frozen Food', 'emoji': '🧊'},
    {'name': 'Skincare', 'emoji': '🧴'},
    {'name': 'Beverages', 'emoji': '🧃'},
    {'name': 'Bakery', 'emoji': '🍞'},
  ];

  // Filter products strictly from the real catalog passed from Supabase (widget.baseProducts).
  // Synthetic IDs (deal_1 to deal_6) are completely removed, and prices are NEVER mutated in-memory.
  List<Product> _getDealProducts() {
    final List<Product> dealList = List<Product>.from(widget.baseProducts);
    if (dealList.isEmpty) return [];

    List<Product> filtered = dealList;

    // Filter by Price Store if selected (0: Trending, 1: ₹9 Store, 2: ₹19 Store, 3: ₹29 Store, 4: ₹49 Store)
    if (_selectedStoreIndex == 1) {
      filtered = filtered.where((p) => p.price <= 10.0).toList();
    } else if (_selectedStoreIndex == 2) {
      filtered = filtered.where((p) => p.price <= 20.0).toList();
    } else if (_selectedStoreIndex == 3) {
      filtered = filtered.where((p) => p.price <= 30.0).toList();
    } else if (_selectedStoreIndex == 4) {
      filtered = filtered.where((p) => p.price <= 50.0).toList();
    }

    // Subcategory filtering by keyword
    if (_selectedSubcategoryIndex == 1) { // Munchies
      filtered = filtered.where((p) =>
        p.name.toLowerCase().contains('turn') ||
        p.name.toLowerCase().contains('mix') ||
        p.name.toLowerCase().contains('chip') ||
        p.name.toLowerCase().contains('biscuit') ||
        p.name.toLowerCase().contains('snack')
      ).toList();
    } else if (_selectedSubcategoryIndex == 2) { // Frozen Food
      filtered = filtered.where((p) =>
        p.name.toLowerCase().contains('ice cream') ||
        p.name.toLowerCase().contains('cup') ||
        p.name.toLowerCase().contains('frozen') ||
        p.name.toLowerCase().contains('pea')
      ).toList();
    } else if (_selectedSubcategoryIndex == 3) { // Skincare
      filtered = filtered.where((p) =>
        p.name.toLowerCase().contains('spot') ||
        p.name.toLowerCase().contains('asaya') ||
        p.name.toLowerCase().contains('lotion') ||
        p.name.toLowerCase().contains('cream') ||
        p.name.toLowerCase().contains('skin')
      ).toList();
    } else if (_selectedSubcategoryIndex == 4) { // Beverages
      filtered = filtered.where((p) =>
        p.name.toLowerCase().contains('juice') ||
        p.name.toLowerCase().contains('milk') ||
        p.name.toLowerCase().contains('tea') ||
        p.name.toLowerCase().contains('coffee') ||
        p.name.toLowerCase().contains('drink')
      ).toList();
    } else if (_selectedSubcategoryIndex == 5) { // Bakery
      filtered = filtered.where((p) =>
        p.name.toLowerCase().contains('bread') ||
        p.name.toLowerCase().contains('toast') ||
        p.name.toLowerCase().contains('bun') ||
        p.name.toLowerCase().contains('cake')
      ).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final products = _getDealProducts();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header: "Steal Deals" + Subtitle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Steal Deals',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Add Any 10 Items',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 4),

        // 2. Horizontal Store Tabs (Trending, ₹9 Store, ₹19 Store, ₹29 Store...)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: List.generate(_stores.length, (index) {
              final store = _stores[index];
              final isSelected = _selectedStoreIndex == index;
              final isFlame = store['isFlame'] == true;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedStoreIndex = index;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFFEFF2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.accentPink : Colors.grey.shade300,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isFlame)
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🔥', style: TextStyle(fontSize: 14)),
                            SizedBox(width: 4),
                            Text(
                              'Trending',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accentPink,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        Text(
                          store['price']!,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: isSelected ? AppColors.accentPink : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          store['subtitle']!,
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? AppColors.accentPink : AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 12),

        // 3. Sub-category Pills ("ALL", "Munchies", "Frozen Food", "Skincare"...)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: List.generate(_subcategories.length, (index) {
              final sub = _subcategories[index];
              final isSelected = _selectedSubcategoryIndex == index;
              final isAll = index == 0;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedSubcategoryIndex = index;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFFEFF2) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.accentPink : Colors.grey.shade300,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isAll)
                        const Icon(
                          Icons.grid_view_rounded,
                          size: 15,
                          color: AppColors.accentPink,
                        )
                      else
                        Text(sub['emoji']!, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Text(
                        sub['name']!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppColors.accentPink : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 14),

        // 4. Two-Row Horizontally Scrolling Product Grid (matching Zepto Steal Deals!)
        SizedBox(
          height: products.isEmpty ? 140 : 456,
          child: products.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_offer_outlined, size: 36, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        const Text(
                          'No products matching this deal filter in the current catalog.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  // Each column displays 2 stacked ProductCards
                  itemCount: (products.length / 2).ceil(),
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, colIndex) {
                    final topIndex = colIndex * 2;
                    final bottomIndex = topIndex + 1;

                    final topProduct = products[topIndex];
                    final bottomProduct =
                        bottomIndex < products.length ? products[bottomIndex] : null;

                    return Column(
                      children: [
                        // Top Product Card
                        ProductCard(
                          product: topProduct,
                          badgeText: (topIndex % 2 == 1 || topIndex == 1) ? 'Select' : null,
                        ),
                        const SizedBox(height: 12),
                        // Bottom Product Card
                        if (bottomProduct != null)
                          ProductCard(
                            product: bottomProduct,
                            badgeText: (bottomIndex == 3 || bottomIndex == 5) ? 'Select' : null,
                          )
                        else
                          const SizedBox(width: 125, height: 210),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}
