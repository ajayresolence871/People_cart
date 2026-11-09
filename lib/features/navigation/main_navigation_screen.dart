import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/cart_provider.dart';
import '../home/screens/home_screen.dart';
import '../home/widgets/sticky_cart_bar.dart';
import '../categories/screens/categories_screen.dart';
import '../categories/screens/category_products_screen.dart';
import '../cart/screens/cart_checkout_screen.dart';
import '../household/screens/household_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    final screens = [
      HomeScreen(
        onNavigateToCategories: () => _onTabSelected(1),
        onNavigateToCart: () => _onTabSelected(3),
      ),
      // Categories Screen (matching Image 1 & Image 2)
      CategoriesScreen(
        onCategorySelected: (item) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoryProductsScreen(category: item),
            ),
          );
        },
      ),
      // Household Screen with Two Tabs (For me & family + Myself)
      HouseholdScreen(onNavigateToCategories: () => _onTabSelected(1)),
      // Full Cart & Checkout Screen (matching Screenshots 1-5)
      CartCheckoutScreen(
        onStartShopping: () => _onTabSelected(0),
        onBack: () => _onTabSelected(0),
      ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          // Current Tab Screen
          screens[_currentIndex],

          // Sticky Cart & Free Delivery Bar (Floating above bottom nav if in Home or Categories)
          if ((_currentIndex == 0 || _currentIndex == 1) &&
              cart.totalQuantity > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: StickyCartBar(onViewCartTap: () => _onTabSelected(3)),
            ),
        ],
      ),

      // Zepto-style Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 6.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  label: 'Home',
                  icon: Icons.home_rounded,
                ),
                _buildNavItem(
                  index: 1,
                  label: 'Categories',
                  icon: Icons.grid_view_rounded,
                ),
                _buildNavItem(
                  index: 2,
                  label: 'Household',
                  icon: Icons.groups_outlined,
                ),
                _buildNavItem(
                  index: 3,
                  label: 'Cart',
                  icon: Icons.shopping_basket_outlined,
                  badgeCount: cart.totalQuantity,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    int badgeCount = 0,
  }) {
    final isSelected = _currentIndex == index;

    return InkWell(
      onTap: () => _onTabSelected(index),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFEFF2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isSelected
                      ? AppColors.accentPink
                      : AppColors.textSecondary,
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.accentPink,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.accentPink
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
