import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/grocery_loading_view.dart';
import '../../../core/widgets/catalog_image.dart';
import '../../../models/category.dart';
import '../../../models/product.dart';
import '../../../providers/cart_provider.dart';
import '../../../services/product_service.dart';
import '../../home/widgets/sticky_cart_bar.dart';
import '../../product_detail/screens/product_detail_screen.dart';
import '../../cart/screens/cart_checkout_screen.dart';
import '../../budget_guardian/utils/budget_dialog_helper.dart';
import '../../wishlist/screens/wishlist_screen.dart';
import '../../wishlist/widgets/wishlist_heart_button.dart';

class CategoryProductsScreen extends StatefulWidget {
  final Category category;
  final List<Product>? initialProducts;
  final ProductCatalogDataSource? dataSource;

  const CategoryProductsScreen({
    super.key,
    required this.category,
    this.initialProducts,
    this.dataSource,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  late final ProductCatalogDataSource _productService;
  int _selectedSubcategoryIndex = 0;
  List<Product> _allCategoryProducts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _productService = widget.dataSource ?? ProductService();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final categories = await _productService.getCategories();
      if (!categories.any(
        (category) => category.id == widget.category.id && category.isActive,
      )) {
        if (mounted) {
          setState(() {
            _allCategoryProducts = [];
            _errorMessage = 'This category is no longer available.';
            _isLoading = false;
          });
        }
        return;
      }

      final products =
          widget.initialProducts ??
          await _productService.getProducts(categoryId: widget.category.id);
      if (mounted) {
        setState(() {
          _allCategoryProducts = products
              .where((product) => product.categoryId == widget.category.id)
              .toList();
          _errorMessage = null;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load products: $error';
          _isLoading = false;
        });
      }
    }
  }

  List<Product> _getCategoryProducts() {
    return _allCategoryProducts;
  }

  String _getSubcategoryEmoji(String name) {
    final value = widget.category.name.toLowerCase();
    if (value.contains('fruit')) return '🍎';
    if (value.contains('vegetable')) return '🥦';
    if (value.contains('dairy')) return '🥛';
    return '🛒';
  }

  String _getProductEmoji(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('coconut')) return '🥥';
    if (lower.contains('orange')) return '🍊';
    if (lower.contains('coriander') || lower.contains('leaves')) return '🌿';
    if (lower.contains('dragon')) return '🐉';
    if (lower.contains('tomato')) return '🍅';
    if (lower.contains('banana')) return '🍌';
    if (lower.contains('milk')) return '🥛';
    if (lower.contains('bread')) return '🍞';
    if (lower.contains('egg')) return '🥚';
    if (lower.contains('paneer')) return '🧀';
    if (lower.contains('chip')) return '🥔';
    if (lower.contains('juice')) return '🧃';
    return '🥗';
  }

  @override
  Widget build(BuildContext context) {
    final products = _getCategoryProducts();
    const subcategories = ['All'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.category.name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Open wishlist',
            icon: const Icon(
              Icons.favorite_border_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WishlistScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.textPrimary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Search in this category coming soon!'),
                  duration: Duration(milliseconds: 800),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Left Sidebar: Subcategories Navigation (Matching Screenshot 2)
              Container(
                width: 82,
                decoration: BoxDecoration(
                  color: const Color(0xFFFBFBFB),
                  border: Border(
                    right: BorderSide(color: Colors.grey.shade200, width: 1.0),
                  ),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  itemCount: subcategories.length,
                  itemBuilder: (context, index) {
                    final sub = subcategories[index];
                    final isSelected = _selectedSubcategoryIndex == index;

                    return InkWell(
                      onTap: () {
                        setState(() => _selectedSubcategoryIndex = index);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFF3EAF8)
                              : Colors.transparent,
                          border: isSelected
                              ? const Border(
                                  left: BorderSide(
                                    color: Color(0xFF7E22CE),
                                    width: 3.5,
                                  ),
                                )
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Subcategory Icon
                            Text(
                              _getSubcategoryEmoji(sub),
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(height: 4),
                            // Subcategory Title
                            Text(
                              sub,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFF6B21A8)
                                    : AppColors.textSecondary,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 2. Right Side: 2-Column Product Grid or Honest Empty State
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: GroceryLoadingView(
                          size: 110,
                          compact: true,
                          message: 'Loading products…',
                        ),
                      )
                    : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _loadProducts,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Try again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : products.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 54,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No products in ${widget.category.name}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Explore other grocery categories or search directly',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 90),
                        itemCount: products.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 10,
                          childAspectRatio:
                              MediaQuery.sizeOf(context).width < 380
                              ? 0.54
                              : 0.62,
                        ),
                        itemBuilder: (context, index) {
                          final product = products[index];

                          return _buildZeptoCategoryProductCard(
                            context: context,
                            product: product,
                            hasSelectBadge: index % 2 == 1,
                          );
                        },
                      ),
              ),
            ],
          ),

          // 3. Sticky Bottom Delivery Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: StickyCartBar(onViewCartTap: () => _openCartModal(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildZeptoCategoryProductCard({
    required BuildContext context,
    required Product product,
    bool hasSelectBadge = false,
  }) {
    final cart = context.watch<CartProvider>();
    final quantity = cart.getQuantity(product.id);
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              product: product,
              similarProducts: _getCategoryProducts(),
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Container with ADD button & Heart Icon
            Stack(
              children: [
                Container(
                  height: 115,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF9F9FA),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: Center(
                    child: CatalogImage(
                      imageUrl: product.imageUrl,
                      fit: BoxFit.contain,
                      placeholder: Text(
                        _getProductEmoji(product.name),
                        style: const TextStyle(fontSize: 52),
                      ),
                    ),
                  ),
                ),

                Positioned(
                  top: 6,
                  right: 6,
                  child: WishlistHeartButton(
                    product: product,
                    diameter: 32,
                    iconSize: 18,
                  ),
                ),

                // Select Badge (Top-Left)
                if (hasSelectBadge)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9C4A11),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'select >',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // Zepto-style Centered "ADD" button overlay at bottom of image
                Positioned(
                  bottom: 6,
                  left: 12,
                  right: 12,
                  child: cart.isOutOfStock(product)
                      ? InkWell(
                          onTap: () {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${product.name} is currently out of stock.',
                                ),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1.0,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'OUT OF STOCK',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 9.5,
                                ),
                              ),
                            ),
                          ),
                        )
                      : quantity == 0
                      ? InkWell(
                          onTap: () {
                            BudgetDialogHelper.checkAndAdd(
                              context: context,
                              itemPrice: product.price,
                              onProceed: () => cart.addItem(product),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.accentPink,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentPink.withValues(
                                    alpha: 0.15,
                                  ),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'ADD',
                                style: TextStyle(
                                  color: AppColors.accentPink,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.accentPink,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: () => cart.removeSingleItem(product.id),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Icon(
                                    Icons.remove,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Text(
                                '$quantity',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  if (!cart.canIncrement(product)) {
                                    ScaffoldMessenger.of(context)
                                        .hideCurrentSnackBar();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Cannot add more. Only ${product.stockQuantity} in stock.',
                                        ),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                    return;
                                  }
                                  BudgetDialogHelper.checkAndAdd(
                                    context: context,
                                    itemPrice: product.price,
                                    onProceed: () => cart.addItem(product),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    size: 16,
                                    color: cart.canIncrement(product)
                                        ? Colors.white
                                        : Colors.white54,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),

            // Details Section
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price Pill & Strikethrough
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.badgeGreen,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '₹${product.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '₹${product.originalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // Discount Saved Text
                  Text(
                    '₹${product.discountAmount.toStringAsFixed(0)} OFF',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.badgeGreen,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Product Title
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Weight / Pack Info
                  Text(
                    product.description ?? '1 pc',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCartModal(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartCheckoutScreen()),
    );
  }
}
